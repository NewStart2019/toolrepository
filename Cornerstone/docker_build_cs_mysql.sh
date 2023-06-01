#!/bin/bash
echo '======CORNERSTONE & MYSQL BUILD DOCKER======'
cs_mysql_pwd=$1
if [ ! $cs_mysql_pwd ];then
  cs_mysql_pwd=`cat /proc/sys/kernel/random/uuid`
fi
rm -rf /tmp/cs_docker_install;mkdir /tmp/cs_docker_install;cd /tmp/cs_docker_install;
curl -O http://install.cornerstone365.cn/github/script/docker_build_cs.sh
curl -O http://install.cornerstone365.cn/github/script/docker_build_mysql.sh
source ./docker_build_mysql.sh $cs_mysql_pwd
cd /tmp/cs_docker_install;
source ./docker_build_cs.sh
docker run -d --name cornerstone_72 --link mysql_5.7  -p 8888:8888 -e TZ="Asia/Shanghai" -e JAZMIN_DB_USER=root -e JAZMIN_DB_PWD=$cs_mysql_pwd -e JAZMIN_DB_HOST=mysql_5.7 -e JAZMIN_DB_PORT=3306 cornerstone:72
echo '======CORNERSTONE & MYSQL DOCKER BUILD SUCCESS======'
