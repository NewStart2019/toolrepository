#!/bin/sh
# 参数
# 项目路径
ROOT_PATH=$1
# $1 分支名、标签
TAG=$2
#镜像名称
IMAGE_NAME=$3
# 容器名称
CONTAINER_NAME=$4
# 映射端口（默认相同）
PORT=$5

build_success=0
function build(){
  # 判断是否存在这个镜像,存在打个时间标签，删除镜像
  if [ "$(docker images | grep ${CONTAINER_NAME} | awk '{print $3}')" != "" ];then
    # 重新构建容器
    docker stop $(docker ps -a| grep ${CONTAINER_NAME} |awk '{print $NF}')
    docker rm $(docker ps -a| grep ${CONTAINER_NAME} |awk '{print $NF}') -f
    docker rmi $(docker images| grep ${CONTAINER_NAME} | grep latest|awk '{print $3}') -f
  fi
  cd $ROOT_PATH/code
  ./gradlew clean $CONTAINER_NAME:dockerBuildImage -x test -Pimage_name=$IMAGE_NAME
  build_success=$?
}

function start() {
  ACTIVE=prod
  if [ $TAG != "master" -a $TAG != "main" ]; then
    ACTIVE=dev
  fi
  if [ "$build_success" = 0 ]; then
    docker run -p $PORT:$PORT --name $CONTAINER_NAME -d --restart=always $IMAGE_NAME:latest --spring.profiles.active=$ACTIVE
  fi
  docker ps -a | grep $CONTAINER_NAME | awk '{print $NF}'
}

build
start