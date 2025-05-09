FROM openjdk:8-jdk-alpine

WORKDIR /app

# 设置阿里云镜像仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
# 设置时区
ENV TimeZone=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/$TimeZone /etc/localtime && echo $TimeZone > /etc/timezone
# 安装必要的软件包以及依赖 字体
RUN apk update && apk add --no-cache fontconfig ttf-dejavu
