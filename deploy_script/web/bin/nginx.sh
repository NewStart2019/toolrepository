#!/bin/sh

TARGET_IP=$1

nginxLocation=$(command -v nginx)
if [ -z "$nginxLocation" ]; then
  echo "目标服务器${TARGET_IP}没有安装nginx,请联系运维人员！"
  exit 0
fi

nginx -t
if [ $? -ne 0 ]; then  # 检查命令执行的返回状态
    echo "Nginx 配置文件存在错误，请检查配置文件"
    exit 1    # 退出脚本，返回状态码 1 表示错误
else
    echo "Nginx 配置文件测试通过。下面将重启nginx"
    sudo systemctl restart nginx
fi
