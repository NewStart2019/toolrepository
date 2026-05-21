#!/bin/sh

# 接收命令
command=$1
#镜像(容器)名称
NAME=$2
# 镜像标签（容器版本）
VERSION=$3

# 打印帮助文档
print_help() {
  echo "Usage: ./dockerDelete.sh <command> param1 param2"
  echo "Available commands: images, container"
  echo "example: ./dockerDelete.sh images <image_name> <image_tag>"
  echo "         ./dockerDelete.sh container <container_name> <container_version>"
}

# 如果没有传递任何参数，打印帮助文档并退出
if [ $# -eq 0 ]; then
  print_help
  exit 1
fi

# 删除非当前版本的镜像: 根据镜像名称:版本删除
delete_images() {
  repository="${NAME}"

  # 1. 使用 Go 模板直接提取完整的镜像名(Repository:Tag)和镜像ID，不包含表头
  # 注意：这里过滤掉了标签为 <none> 的悬空镜像，如果你需要处理悬空镜像，可以去掉 grep -v "<none>"
  images=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "${repository}" | grep -v "<none>")

  # 2. 增加空值检查：如果没有匹配到任何镜像，直接返回，避免执行后续命令报错
  if [ -z "$images" ]; then
    echo "未找到需要清理的镜像: ${repository}"
    return 0
  fi

  # 3. 循环处理提取出的镜像
  echo "$images" | while read -r line; do
    # 提取完整的镜像名 (例如 my-app:v1.0)
    image_name=$(echo "$line" | awk '{print $1}')
    # 提取镜像ID
    image_id=$(echo "$line" | awk '{print $2}')
    # 从完整镜像名中提取 Tag (例如从 my-app:v1.0 中提取 v1.0)
    current_tag=$(echo "$image_name" | awk -F: '{print $2}')

    # 如果提取的 tag 不等于当前指定的 VERSION，则执行删除
    if [ "${current_tag}" != "${VERSION}" ]; then
      echo "正在删除旧版本镜像: ${image_name}"
      # 直接使用提取出的完整镜像名进行删除，避免手动拼接出错
      docker rmi "${image_name}" -f
    fi
  done
}

# 删除指定容器名称的 容器
delete_container(){
  # 判断容器是否存在存在则移除
  NAME="${NAME}-${VERSION}"
  if [ "$(docker ps -a | grep ${NAME} | awk '{print $3}')" != "" ]; then
    docker stop $(docker ps -a | grep ${NAME} | awk '{print $NF}')
    docker rm $(docker ps -a | grep ${NAME} | awk '{print $NF}') -f
  fi
}

case $command in
"images")
  delete_images
  ;;
"container")
  delete_container
  ;;
*)
   print_help
  ;;
esac
