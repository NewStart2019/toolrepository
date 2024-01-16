FROM docker:git
LABEL org.opencontainers.image.authors="zqh"

WORKDIR /app
# 设置阿里云镜像仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

ENV JAVE_VERSION=21
# 安装jdk
RUN apk add --no-cache openjdk21

RUN ssh -v
# 安装ssh、sshpass
RUN apk add --no-cache sshpass
