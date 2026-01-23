#!/usr/bin/env bash

# 使用示例
# git_manage.sh https://github.com/xxxx/xxxx.git repository_name master sha:22243  ……
# 已经是带认证的
CI_REPOSITORY_URL=$1
CI_COMMIT_REF_NAME=$2
CI_COMMIT_SHA=$3
REPO_NAME=$4
WORK_DIR="/app"
# 递归 clone
RECURSIVE_CLONE="1"
# 默认的 FETCH_DEPTH
FETCH_DEPTH="50"

set -euo pipefail

function param_check() {
  if [ -z "$CI_REPOSITORY_URL" ]; then
    echo -e "\e[31m 请输入第一个参数 仓库地址！\e[0m"
    exit 1
  fi

  if [ -z "$CI_COMMIT_REF_NAME" ]; then
    echo -e "\e[31m 请输入第二个参数 分支或标签！\e[0m"
    exit 1
  fi

  if [ -z "$CI_COMMIT_SHA" ]; then
    echo -e "\e[31m 请输入第三个参数需要切换的commit的sha值！\e[0m"
    exit 1
  fi

  if [ -z "$REPO_NAME" ]; then
    echo -e "\e[31m 请输入第四个参数 仓库名称！\e[0m"
    exit 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# 函数：构建带认证的 URL


# ──────────────────────────────────────────────────────────────────────────────
# 函数：准备仓库（克隆或更新）
# ──────────────────────────────────────────────────────────────────────────────
prepare_repository() {
    local repo_url=$CI_REPOSITORY_URL
    local dir="$WORK_DIR/$REPO_NAME/$CI_COMMIT_REF_NAME"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  GitLab 代码拉取"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "仓库     : $repo_url"
    echo "目录     : $dir"
    echo "REF_NAME : ${CI_COMMIT_REF_NAME}"
    echo "COMMIT_SHA : ${CI_COMMIT_SHA:-(未指定，使用 REF_NAME)}"
    echo "子模块递归 : ${RECURSIVE_CLONE:+是}${RECURSIVE_CLONE:-否}"
    echo "fetch 深度 : $FETCH_DEPTH"

    mkdir -p "$dir"
    cd "$dir" || exit 1

    local clone_opts=(--depth "$FETCH_DEPTH")
    [ "$RECURSIVE_CLONE" = "1" ] && clone_opts+=(--recursive)

    if [ -d ".git" ]; then
        echo "仓库已存在 → 更新..."
        git remote set-url origin "$repo_url" || true
        git fetch origin --depth="$FETCH_DEPTH" --tags --force -q
    else
        echo "全新克隆..."
        git clone "${clone_opts[@]}" "$repo_url" .
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# 函数：切换到 commit（使用 git checkout -q）
# ──────────────────────────────────────────────────────────────────────────────
switch_to_commit() {
    local target="$1"
    local is_sha=0

    # 判断是否是 SHA（40 位 hex）
    if [[ ${#target} -eq 40 && "$target" =~ ^[0-9a-f]{40}$ ]]; then
        is_sha=1
    fi

    echo "切换目标: $target ${is_sha:+(精确 SHA)}"

    # 确保目标可达（尤其是 SHA）
    if [ "$is_sha" -eq 1 ]; then
        git fetch origin "$target" --depth=1 2>/dev/null || true
    else
        git fetch origin "$target" --depth=1 2>/dev/null || true
    fi

    # 使用 -q 安静切换
    if git checkout -q "$target" 2>/dev/null; then
        # 如果是 SHA，强制 detached HEAD + reset
        if [ "$is_sha" -eq 1 ]; then
            git reset --hard "$target" >/dev/null 2>&1
        fi
        echo "切换成功: $target (当前 HEAD: $(git rev-parse --short HEAD))"
    else
        echo "错误：无法切换到 $target（可能不存在或不可达）"
        echo "建议检查："
        echo "  - SHA 是否正确"
        echo "  - FETCH_DEPTH 是否太小（可设为 0 测试）"
        return 1
    fi

    # 子模块更新
    if [ "$RECURSIVE_CLONE" = "1" ]; then
        git submodule update --init --recursive >/dev/null 2>&1 || echo "子模块更新有警告（部分可能失败）"
    fi

    return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# 主逻辑
# ──────────────────────────────────────────────────────────────────────────────
main() {
    # 准备仓库
    prepare_repository
    # 切换commit
    if [ -n "$CI_COMMIT_SHA" ]; then
        # 优先使用 CI_COMMIT_SHA
        if ! switch_to_commit "$CI_COMMIT_SHA"; then
            echo "切换到 CI_COMMIT_SHA 失败，退出"
            exit 1
        fi
    else
        # 回退到分支/标签
        if ! switch_to_commit "$CI_COMMIT_REF_NAME"; then
            echo "切换到 CI_COMMIT_REF_NAME 失败，退出"
            exit 1
        fi
    fi
    # 输出最近提交
    echo "最近提交: $(git log -1 --pretty=%s)"
}

param_check
main
