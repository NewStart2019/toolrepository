#!/bin/bash

# ./check_springboot_ready.sh http://172.16.0.170:8001/actuator/health 120 3

# ================== 默认配置 ==================
DEFAULT_HEALTH_URL="http://172.16.0.227:8001/"
DEFAULT_MAX_WAIT_SECONDS=300    # 5 分钟
DEFAULT_CHECK_INTERVAL=5        # 每 5 秒检查一次
# ==============================================

# 读取命令行参数，使用默认值兜底
HEALTH_URL="${1:-$DEFAULT_HEALTH_URL}"
MAX_WAIT_SECONDS="${2:-$DEFAULT_MAX_WAIT_SECONDS}"
CHECK_INTERVAL="${3:-$DEFAULT_CHECK_INTERVAL}"

# 参数校验：确保数值合法
if ! [[ "$MAX_WAIT_SECONDS" =~ ^[0-9]+$ ]] || [ "$MAX_WAIT_SECONDS" -le 0 ]; then
    echo "错误: MAX_WAIT_SECONDS 必须是正整数。"
    exit 1
fi

if ! [[ "$CHECK_INTERVAL" =~ ^[0-9]+$ ]] || [ "$CHECK_INTERVAL" -le 0 ]; then
    echo "错误: CHECK_INTERVAL 必须是正整数。"
    exit 1
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

is_app_ready() {
    if command -v curl >/dev/null 2>&1; then
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$HEALTH_URL" 2>/dev/null)
        [[ "$http_code" == "200" ]] || [[ "$http_code" == "206" ]]
        return $?
    elif command -v wget >/dev/null 2>&1; then
        wget --quiet --timeout=10 --tries=1 --spider "$HEALTH_URL" >/dev/null 2>&1
        return $?
    else
        log "错误: curl 或 wget 未安装，无法检查应用状态。"
        exit 1
    fi
}

log "开始检查应用是否就绪"
log "HEALTH_URL: $HEALTH_URL"
log "MAX_WAIT_SECONDS: ${MAX_WAIT_SECONDS} 秒"
log "CHECK_INTERVAL: ${CHECK_INTERVAL} 秒"

elapsed=0
while [ $elapsed -lt $MAX_WAIT_SECONDS ]; do
    if is_app_ready; then
        log "✅ 应用已成功启动并就绪！"
        exit 0
    fi

    log "⏳ 应用尚未就绪，已等待 $elapsed 秒..."
    sleep $CHECK_INTERVAL
    elapsed=$((elapsed + CHECK_INTERVAL))
done

log "❌ 超时！在 $MAX_WAIT_SECONDS 秒内应用仍未就绪。"
exit 1