#!/bin/bash


root_dir=/app/mongodb

if [[ -e /etc/yum.repos.d/mongodb-org-7.repo ]]; then
# Add MongoDB repository
echo "[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc" | sudo tee /etc/yum.repos.d/mongodb-org-7.repo
fi

# Install MongoDB
sudo yum install -y mongodb-org

sudo sed -i 's#path: /var/log/mongodb/mongod.log#path: /app/mongodb/mongod.log#g' /etc/mongod.conf
sudo sed -i 's#dbPath: /var/lib/mongo#dbPath: /app/mongodb/data#g' /etc/mongod.conf
sudo sed -i 's#bindIp: 127.0.0.1#bindIp: 0.0.0.0#g' /etc/mongod.conf
sudo sed -i 's##security:##security:\n  authorization: enabled#g' /etc/mongod.conf
sudo sed -i 's#User=mongod#User=root#g; s#Group=mongod#Group=root#g' /usr/lib/systemd/system/minio.service

if [ ! -d "$root_dir/data" ]; then
  mkdir -p $root_dir/data
fi

sudo systemctl daemon-reload
# Start MongoDB
sudo systemctl start mongod
# Enable MongoDB to start on system boot
sudo systemctl enable mongod
# Check MongoDB status
sudo systemctl status mongod
