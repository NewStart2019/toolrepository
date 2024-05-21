#!/bin/sh

if [ ! -d "/app/minio" ]; then
  mkdir -p /app/minio
fi

# shellcheck disable=SC2164
cd /app/minio
filename=linux-arm64/minio-20240510014138.0.0-1.aarch64.rpm
wget https://dl.min.io/server/minio/release/linux-arm64/${filename}
yum install -y $filename
firewall-cmd --zone=public --add-port=9000/tcp --permanent
firewall-cmd --zone=public --add-port=9001/tcp --permanent
systemctl restart firewalld
echo "MINIO_VOLUMES=/app/minio
      MINIO_OPTS=\"--address :9000 --console-address :9001 --json\"
      MINIO_ACCESS_KEY=minioadmin
      MINIO_SECRET_KEY=2%#Fbh7e" > /etc/default/minio

# 设置 minio.service 文件 TimeoutStopSec超时停止启用禁止
sed -i 's/TimeoutSec=infinity/TimeoutStopSec=infinity/g; s/User=minio-user/User=root/g; s/Group=minio-user/Group=root/g' /usr/lib/systemd/system/minio.service

systemctl daemon-reload
systemctl enable minio
systemctl start minio
systemctl status minio
