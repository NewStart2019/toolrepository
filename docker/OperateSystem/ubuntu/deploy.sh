#!/usr/bin/env bash

# 使用示例
# git_manage.sh https://github.com/xxxx/xxxx.git repository_name master sha:22243  ……
ZIP_DIR=$1
WORK_DIR=$2
USER=$3
TARGET_SERVER=$4
PASSWORD=$5
ROOT_PATH=$6
DELETE_ZIP_FILE=${7:-true}
APK_NAME=${8:-""}
TARGET_PORT=${9:-22}

set -euo pipefail

function param_check() {
  if [ -z "$ZIP_DIR" ]; then
    ZIP_DIR="dist/"
    echo -e "\e[32m 构建生成文件默认地址是：$ZIP_DIR \e[0m"
  fi

  if [ -z "$WORK_DIR" ]; then
    echo -e "\e[31m 请输入第二个参数 工作目录！\e[0m"
    exit 1
  fi

  if [ -z "$USER" ]; then
    echo -e "\e[31m 请输入第三个参数 发布的目标服务器ssh用户名！\e[0m"
    exit 1
  fi

  if [ -z "$TARGET_SERVER" ]; then
    echo -e "\e[31m 请输入第四个参数 发布的目标服务器ssh地址！\e[0m"
    exit 1
  fi

  if [ -z "$PASSWORD" ]; then
      echo -e "\e[31m 请输入第五个参数 发布的目标服务器ssh密码！\e[0m"
      exit 1
  fi

  if [ -z "$ROOT_PATH" ]; then
    echo -e "\e[31m 请输入第六个参数 部署路径！\e[0m"
    exit 1
  fi

  if [ -z "$DELETE_ZIP_FILE" ]; then
    DELETE_ZIP_FILE=true
    echo -e "\e[32m 默认删除压缩包 \e[0m"
  fi
}

function delte_dist() {
    # 检查 APK_NAME 变量是否为空
    if [ -z "$APK_NAME" ]; then
        # 如果为空，则删除 dist 目录下的所有内容
        find ./dist -mindepth 1 -delete
    else
        # 如果不为空，则删除所有名称不等于 $APK_NAME 的文件/目录
        find ./dist -mindepth 1 ! -name "$APK_NAME" -delete
    fi
}

function upload() {
    DATE=$(date +%Y-%m-%d)
    ARCHIVE="dist_${DATE}.tar.gz"
    cd $WORK_DIR
    tar -czf "$ARCHIVE" $ZIP_DIR
    sshpass -p "$PASSWORD" ssh -p $TARGET_PORT $USER@$TARGET_SERVER "if [ ! -d '$ROOT_PATH/dist' ]; then mkdir -p '$ROOT_PATH/dist'; fi"
    sshpass -p "$PASSWORD" scp -rp "$ARCHIVE" $USER@$TARGET_SERVER:$ROOT_PATH
    commandStr="cd $ROOT_PATH;
      function delte_dist() {
          if [ -z \"$APK_NAME\" ]; then
              find ./dist -mindepth 1 -delete
          else
              find ./dist -mindepth 1 ! -name \"$APK_NAME\" -delete
          fi
      }
      rm -rf ./dist_new;
      mkdir -p ./dist_new;
      tar -xaf $ARCHIVE -C ./dist_new --strip-components=1 && delte_dist && mv -f ./dist_new/* ./dist/";
    if [ $DELETE_ZIP_FILE ]; then
      commandStr="$commandStr && rm $ARCHIVE";
    fi
    sshpass -p "$PASSWORD" ssh -p $TARGET_PORT $USER@$TARGET_SERVER "$commandStr";
}

param_check
ssh-keyscan -t rsa $TARGET_SERVER >> /root/.ssh/known_hosts
upload