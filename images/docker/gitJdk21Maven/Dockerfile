FROM docker:git
LABEL org.opencontainers.image.authors="zqh"
WORKDIR /app
# 设置阿里云镜像仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
ENV JAVE_VERSION=21

# 安装jdk
RUN apk add --no-cache openjdk21
# 安装sshpass
RUN apk add --no-cache sshpass
# 安装mvn
RUN apk add --no-cache maven

# 创建目录
RUN mkdir -p $HOME/.docker/
RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts

# 设置maven仓库配置文件
COPY settings.xml /app/conf/
