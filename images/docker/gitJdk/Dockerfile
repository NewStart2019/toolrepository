FROM docker:git
LABEL org.opencontainers.image.authors="zqh"

WORKDIR /app
# 设置阿里云镜像仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

ENV JAVE_VERSION=21
# 安装jdk
RUN /bin/sh -c set -eux; apkArch="$(apk --print-arch)"; case "$apkArch" in 'aarch64') url='http://172.16.0.97:84/jdk/Linux/jdk-${JAVE_VERSION}_linux-aarch64_bin.rpm'; ;; \
    *) url='http://172.16.0.97:84/jdk/Linux/jdk-${JAVE_VERSION}_linux-x64_bin.rpm' ;; esac; wget -O 'openjdk.rpm' "$url"; PACKAGE_NAME="openjdk.rpm";  \
    chmod +x $PACKAGE_NAME ; rpm -ivh $PACKAGE_NAME; rm $PACKAGE_NAME; java -version

# 安装ssh、sshpass、git
RUN RUN /bin/sh -c apk add --no-cache sshpass
