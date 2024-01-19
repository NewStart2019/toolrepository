FROM docker:git
LABEL org.opencontainers.image.authors="zqh"
WORKDIR /app
# 设置阿里云镜像仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装jdk
RUN apk add openjdk17
# 安装sshpass
RUN apk add --no-cache sshpass

# 创建目录
RUN mkdir -p $HOME/.docker/
RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts

RUN apk add curl zip unzip
RUN curl -o ./sdkman-init.sh http://172.16.0.97:84/gradle/sdkman-init.sh
RUN . /app/sdkman-init.sh
RUN sdk install gradle 7.6
