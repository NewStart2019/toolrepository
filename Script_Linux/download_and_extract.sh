#!/usr/bin/env bash

set -euo pipefail

# ================= 配置区域 =================
REMOTE_USER="root"                      # 远程服务器用户名
REMOTE_HOST="192.168.8.116"               # 远程服务器IP地址
REMOTE_DIR="/mydata/minio/stcjcgl_zip/" # 远程指定扫描目录
LOCAL_DIR="/app/minio/data/"             # 本地下载保存目录
DEZIP_DIR="/app/minio/data/stcjcgl"     # 解压缩保存目录
CONCURRENT_JOBS=5                       # 并发下载进程数（建议不超过10）
# ===========================================

# 确保本地目录存在
mkdir -p "$LOCAL_DIR"
mkdir -p "$DEZIP_DIR"

log() {
    echo "[$(date '+%F %T')] $*"
}

check_parallel() {
    if ! command -v parallel >/dev/null 2>&1; then
        log "GNU parallel 未安装"

        if [ -f /etc/debian_version ]; then
            sudo apt update
            sudo apt install -y parallel
        elif [ -f /etc/rocky-release ]; then
            sudo dnf install -y parallel
        else
            log "无法自动安装 GNU parallel"
            exit 1
        fi
    fi
}

# 定义单个文件的处理函数（下载 -> 删除远程 -> 解压 -> 覆盖）
process_file() {
    local remote_file="$1"

    local filename=$(basename "$remote_file")
    local local_file="$LOCAL_DIR/$filename"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始处理: $filename"
#    下载远程的文件目录。如果本地存在这个文件则忽略
#    rsync -av --ignore-existing -e ssh root@192.168.8.116:/mydata/minio/stcjcgl/202411 /app/minio/data/stcjcgl
    # 下载（远程文件暂不删除）
    rsync -azP \
        "${REMOTE_USER}@${REMOTE_HOST}:$remote_file" \
        "$local_file"
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 下载失败: $filename，跳过后续操作。"
        return 1
    fi

    # 3. 检查是否是压缩包并解压到指定目录，强制覆盖
    # 使用 file 命令检查文件的真实 MIME 类型，比单纯看后缀更安全
    local mime_type=$(file --mime-type -b "$local_file")
    case "$mime_type" in
        application/zip)
            log "ZIP 解压: $filename"
            unzip -o "$local_file" -d "$DEZIP_DIR" >/dev/null \
                && unzip_success=1
            ;;
        application/gzip|application/x-gzip|application/x-tar|application/x-bzip2|application/x-xz)
            log "TAR 解压: $filename"
            tar -xf "$local_file" -C "$DEZIP_DIR" \
                && unzip_success=1
            ;;
        *)
            log "未知压缩格式: $filename ($mime_type)"
            unzip_success=0
            ;;
    esac

    # 解压成功
    if [ "$unzip_success" -eq 1 ]; then
        log "解压成功: $filename"
        # 删除本地压缩包
        rm -f "$local_file"
        # 删除远程压缩包
        ssh "${REMOTE_USER}@${REMOTE_HOST}" \
            "rm -f '$remote_file'"
        log "已删除本地与远程压缩包: $filename"
    else
        log "解压失败: $filename"
        # 保留本地和远程文件
        return 1
    fi
}

export -f process_file
export -f log

export REMOTE_USER
export REMOTE_HOST
export LOCAL_DIR
export DEZIP_DIR

check_parallel

echo "正在扫描远程目录: $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR ..."
REMOTE_FILES=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "find $REMOTE_DIR -type f")
echo $REMOTE_FILES

ssh "${REMOTE_USER}@${REMOTE_HOST}" \
    "find '$REMOTE_DIR' -type f -print0" |
parallel -0 --will-cite -j "$CONCURRENT_JOBS" process_file
parallel -0 --will-cite -j "$CONCURRENT_JOBS" process_file

log "全部任务完成"