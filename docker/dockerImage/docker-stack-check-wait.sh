#!/usr/bin/env bash
# ==============================================================================
# Docker Stack 部署等待脚本
# 用途：docker stack deploy 之后执行，等待滚动更新完成并判断部署是否成功
# 兼容：Bash 4+，无需 jq / python 等额外依赖
# 适用：GitLab CI / Jenkins / 本地自动化部署
# ==============================================================================
set -o pipefail

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- 配置参数（命令行或环境变量覆盖） ----------
WAIT_TIMEOUT=${WAIT_TIMEOUT:-300}   # 最长等待秒数，默认 5 分钟
POLL_INTERVAL=${POLL_INTERVAL:-3}   # 轮询间隔秒数
STACK_NAME=""                        # Docker Stack 名称
START_TIME=0                         # 开始时间戳
EXIT_CODE=0                          # 0成功 1失败 2超时

# ---------- 关联数组：Service 元信息 ----------
declare -A SVC_EXPECTED        # 期望副本数
declare -A SVC_UPDATE_ORDER    # 滚动策略：start-first / stop-first
declare -A SVC_HAS_HEALTHCHECK # 是否配置健康检查：yes / no
declare -A SVC_NEED_WAIT       # 是否需要等待更新

# ==============================================================================
# 日志工具
# ==============================================================================
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[ OK ]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_fail()    { echo -e "${RED}[FAIL]${NC}  $*"; }
log_progress(){ echo -ne "\r${CYAN}[ .. ]${NC}  $*\033[K"; }
clr_progress(){ echo -ne "\r\033[K"; }
elapsed()     { echo $(( $(date +%s) - START_TIME )); }
is_timeout()  { [[ $(elapsed) -ge $WAIT_TIMEOUT ]]; }

# ==============================================================================
# Service 元信息采集（docker service inspect --format，无需 jq）
# ==============================================================================

# 获取 Stack 下所有 Service 名称
get_services() {
    docker stack services --format '{{.Name}}' "$1" 2>/dev/null
}

# 获取期望副本数（replicated 返回数字，global 返回 global）
# 注意：不能直接打印 .Spec.Mode（会输出 Go 结构体指针），需访问叶子字段判断
get_expected() {
    local replicas
    # 先尝试 Replicated 模式取副本数
    replicas=$(docker service inspect --format '{{.Spec.Mode.Replicated.Replicas}}' "$1" 2>/dev/null)
    if [[ -n "$replicas" && "$replicas" != "<nil>" ]]; then
        echo "$replicas"
        return
    fi
    # 再判断是否为 Global 模式（Global 字段非空即为 global 模式）
    local global_mode
    global_mode=$(docker service inspect --format '{{.Spec.Mode.Global}}' "$1" 2>/dev/null)
    if [[ -n "$global_mode" && "$global_mode" != "<nil>" ]]; then
        echo "global"
        return
    fi
    # 兜底返回 1
    echo "1"
}

# 获取滚动更新顺序（默认 stop-first）
get_update_order() {
    local order
    order=$(docker service inspect --format '{{.Spec.UpdateConfig.Order}}' "$1" 2>/dev/null)
    [[ -z "$order" || "$order" == "<nil>" ]] && echo "stop-first" || echo "$order"
}

# 判断是否配置了 HealthCheck
has_healthcheck() {
    local hc
    hc=$(docker service inspect --format '{{.Spec.TaskTemplate.ContainerSpec.Healthcheck.Test}}' "$1" 2>/dev/null)
    [[ -n "$hc" && "$hc" != "<nil>" && "$hc" != "[]" ]] && echo "yes" || echo "no"
}

# ==============================================================================
# 运行时状态采集（基于 docker service ps）
# 运行时状态CurrentState：Running / Starting / Preparing / Pending / Failed / Shutdown  / Complete
# ==============================================================================
count_status() {
    docker service ps --format '{{.Name}} {{.CurrentState}}' "$1" 2>/dev/null \
    | awk '{name=$1; if (!(name in seen)) { seen[name]=1; print; }}' | grep -c "$2";
}

# docker service ps 按时间倒序，每个副本 slot 的第一条是当前最新状态
# 用 awk 按 name 去重后再检查是否有 Failed / Rejected / Error
# 0 表示启动失败
# 1 表示 启动中
# 2 表示 启动完成
check_failed() {
    local latest_tasks bad
    # 第一步：按 slot 去重，只保留每个副本的最新任务（第一条）
    # 从 Name 字段（如 stcjc_server.1）提取 slot 编号
    latest_tasks=$(docker service ps --format '{{.Name}} {{.CurrentState}}' "$1" 2>/dev/null \
        | awk '{name=$1; if (!(name in seen)) { seen[name]=1; print; }}')

    # 第二步：在最新任务中筛选失败状态
    bad=$(echo "$latest_tasks" | grep -vE " (Starting|Preparing|Pending|Failed|Shutdown|Complete) ")
    if [[ -n "$bad" ]]; then
      bad=$(echo "$bad" | grep -qiE "Failed|Rejected|Error")
      if [[ -n "$bad" ]]; then
        echo "$bad"
        return 0
      fi
      return 1
    fi
    return 2
}

print_progress() {
    local svc="$1"
    healthy=$(count_status "$svc" "Running")
    starting=$(count_status "$svc" "Starting")
    preparing=$(count_status "$svc" "Preparing")
    pending=$(count_status "$svc" "Pending")
    failed=$(count_status "$svc" "Failed")
    shutdown=$(count_status "$svc" "Shutdown")
    complete=$(count_status "$svc" "Complete")

    # 以上变量不为0的状态输出在一行，用空格分隔
    print_str="Service $svc:"
    if [[ $healthy -gt 0 ]]; then
        print_str="$print_str $healthy 正在运行"
    fi
    if [[ $starting -gt 0 ]]; then
        print_str="$print_str $starting 正在启动"
    fi
    if [[ $preparing -gt 0 ]]; then
        print_str="$print_str $preparing 拉镜像/准备中"
    fi
    if [[ $pending -gt 0 ]]; then
        print_str="$print_str $pending 等待调度"
    fi
    if [[ $failed -gt 0 ]]; then
        print_str="$print_str $failed 启动失败"
    fi
    if [[ $shutdown -gt 0 ]]; then
        print_str="$print_str $shutdown 正常退出"
    fi
    if [[ $complete -gt 0 ]]; then
        print_str="$print_str $complete 一次性任务完成"
    fi
    log_progress "$print_str"
}

# ==============================================================================
# 核心：判断单个 Service 更新是否完成
# 返回：0=动失败  1=启动中  2=启动完成
# ==============================================================================
check_service() {
    local svc="$1"
    local expected="${SVC_EXPECTED[$svc]}"
    local order="${SVC_UPDATE_ORDER[$svc]}"
    # global 模式用节点数作为期望值
    [[ "$expected" == "global" ]] && expected=$(docker node ls -q 2>/dev/null | wc -l)
    # 1. 优先检查失败任务
    result=$(check_failed "$svc")
    # 3. 采集各状态数量 Running / Starting / Preparing / Pending / Failed / Shutdown  / Complete
    print_progress "$svc"
    if [[ $result -eq 0 ]]; then
        return 0
    elif [[ $result -eq 1 ]]; then
        return 1
    elif [[ $result -eq 2 ]]; then
        return 2
    fi
}

# ==============================================================================
# 主流程
# ==============================================================================

print_help() {
    cat <<EOF
用法: $0 <stack-name> [选项]

docker stack deploy 之后执行，等待滚动更新完成并判断部署是否成功。

选项:
  -t, --timeout SECONDS    最长等待时间（秒），默认 300
  -i, --interval SECONDS   轮询间隔（秒），默认 3
  -h, --help               显示帮助

环境变量: WAIT_TIMEOUT / POLL_INTERVAL
退出码:   0=全部成功  1=有服务失败  2=等待超时

示例:
  docker stack deploy -c app.yml mystack
  $0 mystack
  $0 mystack -t 600
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     print_help; exit 0 ;;
            -t|--timeout)  WAIT_TIMEOUT="$2"; shift 2 ;;
            -i|--interval) POLL_INTERVAL="$2"; shift 2 ;;
            -*) log_fail "未知选项: $1"; print_help; exit 1 ;;
            *)
                [[ -z "$STACK_NAME" ]] && STACK_NAME="$1" || { log_fail "多余参数: $1"; exit 1; }
                shift
                ;;
        esac
    done
    [[ -z "$STACK_NAME" ]] && { log_fail "请指定 Stack 名称"; print_help; exit 1; }
}

# 初始化：采集 Service 元信息，判断哪些需要等待
init_services() {
    log_info "采集 Stack '${BOLD}${STACK_NAME}${NC}' 的 Service 信息..."

    local services count=0
    services=$(get_services "$STACK_NAME")
    [[ -z "$services" ]] && { log_fail "未找到 Stack '${STACK_NAME}'"; exit 1; }

    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        SVC_EXPECTED["$svc"]=$(get_expected "$svc")
        SVC_UPDATE_ORDER["$svc"]=$(get_update_order "$svc")

        # 首次检查：已达期望状态且无失败则跳过
        check_service "$svc" >/dev/null 2>&1
        local rc=$?
        clr_progress
        if [[ $rc -eq 1 ]]; then
            SVC_NEED_WAIT["$svc"]="yes"
        else
            SVC_NEED_WAIT["$svc"]="no"
        fi
        count=$((count + 1))
    done <<< "$services"

    # 统计需等待的数量
    local wait_count=0
    for svc in "${!SVC_NEED_WAIT[@]}"; do
        [[ "${SVC_NEED_WAIT[$svc]}" == "yes" ]] && wait_count=$((wait_count + 1))
    done

    log_ok "共 ${count} 个 Service，其中 ${wait_count} 个需要等待更新完成"
    [[ $wait_count -eq 0 ]] && { log_warn "所有 Service 已稳定，无需等待"; exit 0; }
}

# 主循环：等待所有需更新的 Service 完成
wait_all() {
    log_info "开始等待，超时 ${WAIT_TIMEOUT}s，轮询间隔 ${POLL_INTERVAL}s"
    echo "---"

    # 构建待等待列表
    local pending=() completed=() failed=()
    for svc in "${!SVC_NEED_WAIT[@]}"; do
        [[ "${SVC_NEED_WAIT[$svc]}" == "yes" ]] && pending+=("$svc")
    done

    while true; do
        # 超时检查
        if is_timeout; then
            clr_progress; echo
            log_fail "超时（${WAIT_TIMEOUT}秒），未完成的 Service："
            for s in "${pending[@]}"; do
              echo -e "          ${YELLOW}- $s${NC}";
            done
            EXIT_CODE=2;
            return
        fi

        local still_pending=()
        for svc in "${pending[@]}"; do
            check_service "$svc"
            case $? in
                2) clr_progress; log_ok "$svc 更新完成"; completed+=("$svc") ;;
                0) failed+=("$svc") ;;
                1) still_pending+=("$svc") ;;
            esac
        done
        pending=("${still_pending[@]}")

        [[ ${#pending[@]} -eq 0 ]] && { clr_progress; break; }
        sleep "$POLL_INTERVAL"
    done

    echo "---"
    # 结果汇总
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_fail "失败 (${#failed[@]}):"
        for s in "${failed[@]}"; do
          echo -e "          ${RED}- $s${NC}";
        done
        EXIT_CODE=1
    fi
    if [[ ${#completed[@]} -gt 0 ]]; then
        log_ok "成功 (${#completed[@]}):"
        for s in "${completed[@]}"; do
          echo -e "          ${GREEN}- $s${NC}";
        done
    fi
}

main() {
    parse_args "$@"
    START_TIME=$(date +%s)

    echo
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  Docker Stack 部署等待脚本${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo

    init_services
    echo
    wait_all

    echo
    log_info "总耗时: ${BOLD}$(elapsed)${NC} 秒"
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_ok "所有 Service 部署成功！"
    else
        log_fail "部署未完全成功，请检查上述错误"
    fi
    echo
    exit $EXIT_CODE
}

main "$@"