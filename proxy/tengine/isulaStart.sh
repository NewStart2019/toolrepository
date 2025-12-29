#!/bin/bash

CONTAINER_NAME="tengine"
IMAGE="sungyism/tengine:latest"
# 获取第一个参数
force=$1

# force变量 不等于 --force字符串 和 不等于 -f  时 检查容器是否存在（包括已停止的），存在则重启容器
if [ "$force" != "--force" ] && [ "$force" != "-f" ] && isula ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" ; then
    echo "容器 '${CONTAINER_NAME}' 已存在，正在重启..."
    isula restart "${CONTAINER_NAME}"
    isula exec -it ${CONTAINER_NAME} ip a
else
    isula stop $CONTAINER_NAME || true
    isula rm $CONTAINER_NAME || true
    isula run -d \
      --net bridge \
      -p 80:80 \
      -p 443:443 \
      --name ${CONTAINER_NAME} \
      ${IMAGE}

    if [ $? -eq 0 ]; then
        echo "✅ 容器 '${CONTAINER_NAME}' 创建并启动成功！"
    else
        echo "❌ 容器启动失败！"
        exit 1
    fi
fi