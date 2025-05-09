FROM docker:git
LABEL org.opencontainers.image.authors="zqh"
ARG VERSION=11
WORKDIR /app
# 设置阿里云镜像仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
# 安装jdk
RUN apk add openjdk$VERSION
# 安装ssh、sshpass
RUN apk add sshpass
# 安装mvn
RUN apk add maven
# 创建目录
RUN mkdir -p $HOME/.docker/
RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts

# 设置maven仓库配置文件
COPY settings.xml /app/conf/
COPY dockerDelete.sh /app/
