#!/bin/bash
echo '======MYSQL DOCKER BUILD======'
mysql_pwd=$1
if [ ! $mysql_pwd ];then
  echo 'mysql password can not be null! exiting...'
  exit 1
fi
mysql_pid=`/usr/sbin/lsof -i :3306|grep -v "PID" | awk '{print $2}'`
if [ "$mysql_pid" != "" ];
then
   echo 'port 3306 is in use, exiting...'
   exit 1
fi
docker > /dev/null 2>&1
if [[ $? -ne 0 ]];then
	echo 'can not find docker, exiting...'
	exit 1
fi
rm -rf /tmp/cs_docker_mysqlinstall;mkdir /tmp/cs_docker_mysqlinstall;cd /tmp/cs_docker_mysqlinstall;
curl -O http://install.cornerstone365.cn/github/db/db_cornerstone.sql
mysql_image_id=`docker images -q mysql:5.7`
if [ ! $mysql_image_id ];then
  curl -O http://install.cornerstone365.cn/docker/mysql_5.7.tar
  docker load -i mysql_5.7.tar
fi
docker run -d --name mysql_5.7 -v /cornerstone/mysql/data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=${mysql_pwd} -p 3306:3306 mysql:5.7
sleep 30
docker exec mysql_5.7 mkdir -p /cornerstone/db
docker cp db_cornerstone.sql mysql_5.7:/cornerstone/db
docker exec mysql_5.7 bash -c 'mysql -h 127.0.0.1 -P 3306 -uroot -p'${mysql_pwd}' --connect-expired-password <<EOF
create database db_cornerstone;
use db_cornerstone;
source /cornerstone/db/db_cornerstone.sql;
EOF'
echo '======MYSQL DOCKER BUILD SUCCESS======'
