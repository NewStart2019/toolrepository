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

  # 获取所有与 repository 匹配的镜像列表
  images=$(docker images | grep "${repository} " | awk '{print $0}')

  # 使用 echo 和管道传递字符串给循环
  echo "$images" | while read -r image; do
    image_tag=$(echo "$image" | awk '{print $2}')
    image_id=$(echo "$image" | awk '{print $3}')
    if [ "${image_tag}" != "${VERSION}" ]; then
      if [ "${image_tag}" = "<none>" ]; then
        docker rmi $image_id
      else
        # 非当前版本的镜像，删除之
        docker rmi "${repository}:${image_tag}" -f
      fi
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
