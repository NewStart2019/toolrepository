#!/bin/bash
export LC_ALL=C
export LANG=en_US.UTF-8

TARGET_VERSION=$1

if [ -z "$TARGET_VERSION" ]; then
  echo -e "\e[31m 请输入第一个参数指定目标版本参数！\e[0m"
  exit 1
fi

if [[ "${TARGET_VERSION:0:1}" != "v" ]]; then
  TARGET_VERSION="v"$TARGET_VERSION
fi

source $HOME/.bashrc

# 获取 nvm ls 的输出
NVM_OUTPUT=$(nvm ls)
# 检查慕目标版本是否安装
if echo "$NVM_OUTPUT" | grep "     " | grep -q "$TARGET_VERSION"; then
  echo "Node.js version $TARGET_VERSION is installed."
  current_version=$(nvm current)
  # 检查当前使用的版本是否是目标版本，不是则切换
  if [ "$current_version" != "$TARGET_VERSION" ]; then
    nvm use $TARGET_VERSION
  fi
else
  echo "Node.js version $TARGET_VERSION is not installed."
  nvm install $TARGET_VERSION
  nvm use $TARGET_VERSION
fi
