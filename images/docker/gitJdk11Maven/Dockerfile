FROM docker:git
LABEL org.opencontainers.image.authors="zqh"
WORKDIR /app
# 设置阿里云镜像仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
ENV JAVE_VERSION=21
# 安装jdk
RUN apk add --no-cache openjdk11
# 安装ssh、sshpass
RUN apk add --no-cache sshpass
# 安装mvn
RUN apk add --no-cache maven
# 创建目录
RUN mkdir -p $HOME/.docker/

# 设置maven仓库配置文件
RUN rm -f /usr/share/maven/conf/settings.xml
COPY ../settings.xml /usr/share/maven/conf/