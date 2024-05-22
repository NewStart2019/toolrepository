#!/bin/bash

# 安装epel
if [[ ! -e /etc/yum.repos.d/epel.repo ]]; then
  yum install -y epel-release
fi

# 检查redis是否安装
if [[ -e /usr/bin/redis-server ]]; then
  echo redis已经安装
  exit 0
fi

sudo yum install -y redis

# 处理配置文件
sudo sed -i 's#bind 127.0.0.1#bind 0.0.0.0#g' /etc/redis.conf
sudo sed -i 's#dir /var/lib/redis#dir /app/redis/data#g' /etc/redis.conf
sudo sed -i 's#logfile /var/log/redis/redis.log#logfile /app/redis/log/redis.log#g' /etc/redis.conf
# TODO 需要自己修改成自己的密码
sudo sed -i 's/#requirepass foobared/requirepass oXvq2wWJkMC8IjCK/g' /etc/redis.conf

if [ ! -d "/app/redis/data" ]; then
  mkdir -p /app/redis/data
fi

if [ ! -d "/app/redis/log" ]; then
  mkdir -p /app/redis/log
fi

sudo systemctl start redis
sudo systemctl enable redis
sudo systemctl status redis

