#!/bin/bash

# 要压缩的目录
TARGET_DIR=$1
# 输出压缩包目录
OUT_DIR=$2
# 并发数，没有输入，则设置默认值
MAX_JOBS=$3

# 分别检测以上三个参数是否有值
if [ -z "$TARGET_DIR" ] || [ -z "$OUT_DIR" ]; then
    echo "Usage: $0 <target_dir> <out_dir> <max_jobs>"
    exit 1
fi

if [ -z "$MAX_JOBS" ]; then
    MAX_JOBS=4
fi

mkdir -p "$OUT_DIR"
export OUT_DIR

find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | \
sort -r | \
xargs -I {} -P "$MAX_JOBS" bash -c '
dir="{}"
name=$(basename "$dir")
tarfile="$OUT_DIR/${name}.tar.gz"
# 已存在则跳过
if [ -f "$tarfile" ]; then
    echo "跳过: $tarfile 已存在"
    exit 0
fi
echo "开始压缩: $dir"
tar -zcf "$tarfile" -C "$(dirname "$dir")" "$name"
if [ $? -eq 0 ]; then
    echo "完成: $tarfile"
else
    echo "失败: $dir"
fi
'

# 解压缩 10519
# tar -xvf xx.tar.gz