#!/bin/bash
echo '======CORNERSTONE BUILD DOCKER======'
docker > /dev/null 2>&1
if [[ $? -ne 0 ]];then
	echo 'can not find docker, exiting...'
	exit 1
fi
rm -rf /tmp/cs_docker_appinstall;mkdir /tmp/cs_docker_appinstall;cd /tmp/cs_docker_appinstall;
curl -O http://install.cornerstone365.cn/docker/cshome.tar.gz
curl -O http://install.cornerstone365.cn/github/package/CornerstoneBizSystem.jaz
curl -O http://install.cornerstone365.cn/github/package/CornerstoneWebSystem.war
curl -O http://install.cornerstone365.cn/docker/Dockerfile
docker build -t cornerstone:72 .

echo '======CORNERSTONE DOCKER BUILD SUCCESS======'
