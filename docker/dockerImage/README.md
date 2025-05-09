镜像说明文件：
 构建镜像命令：docker-compose build -f /path/to/Dockerfile <service-name1> <service-name2>

# 1、maven镜像
## 1.1 适用于场景：
  * 需要git取代码，docker镜像操作，使用maven工具构建项目
  * sshpass可以无密码传输文件scp、远程执行命令ssh
  * maven11、maven17、maven21服务对应的jdk11、17、21，自行选择对应的环境
## 1.2 镜像说明
 * 系统 alpine:3.19 apk安装，以及配置国内镜像源
 * 工具版本：docker24.7.0，docker-compose 2.24.0，git 2.24、maven3.9.5
 * 安装了jdk、sshpass
 * maven配置私有仓库地址 http://172.16.0.145:5001/repository/maven-public/ 包括私有仓库、代理阿里云仓库

# 2、gradle镜像
## 2.1 适用于场景：
  * 需要git取代码，docker镜像操作，使用maven工具构建项目
  * sshpass可以无密码传输文件scp、远程执行命令ssh
  * gradle11、gradle17、gradle21服务对应的jdk11、17、21，自行选择对应的环境
## 2.2 镜像说明
 * 系统 alpine:3.19 apk安装，以及配置国内镜像源
 * 工具版本：docker24.7.0，docker-compose 2.24.0，git 2.24、maven3.9.5
 * 安装了jdk、sshpass
 * gradle配置私有仓库地址 http://172.16.0.145:5001/repository/maven-public/ 包括私有仓库、代理阿里云仓库
