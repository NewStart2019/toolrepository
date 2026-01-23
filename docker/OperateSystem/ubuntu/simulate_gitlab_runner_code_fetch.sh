#!/usr/bin/env bash

# 脚本名称: simulate_gitlab_runner_code_fetch.sh
# 描述: 模拟 GitLab Runner 的代码拉取 + 使用 git checkout -q 切换 commit
#       优先切换到 CI_COMMIT_SHA（精确 commit），fallback 到 CI_COMMIT_REF_NAME

set -euo pipefail

# 默认环境变量（可通过 export 覆盖）
: "${GITLAB_REPO_URL:="http://172.16.0.197:8929/emcp/emcp-web.git"}"
: "${GITLAB_TOKEN:=""}"                          # PAT 或空（SSH/无认证）
: "${CI_COMMIT_REF_NAME:="master"}"              # 分支或标签
: "${CI_COMMIT_SHA:="d212a12203af4e4655c106a152b8a5e2d9162086"}"                         # 优先使用的精确 commit SHA
: "${WORK_DIR:="./workspace"}"
: "${RECURSIVE_CLONE:="1"}"
: "${FETCH_DEPTH:="50"}"

# ──────────────────────────────────────────────────────────────────────────────
# 函数：构建带认证的 URL
# ──────────────────────────────────────────────────────────────────────────────
build_auth_url() {
    if [ -n "$GITLAB_TOKEN" ]; then
        local base="${GITLAB_REPO_URL#https://}"
        base="${base#http://}"
        echo "https://oauth2:${GITLAB_TOKEN}@${base}"
    else
        echo "$GITLAB_REPO_URL"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# 函数：准备仓库（克隆或更新）
# ──────────────────────────────────────────────────────────────────────────────
prepare_repository() {
    local repo_url=$(build_auth_url)
    local dir="$WORK_DIR"

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
    prepare_repository

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
    echo "最近提交      : $(git log -1 --pretty=%s)"
}

main