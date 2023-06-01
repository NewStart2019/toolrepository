FROM alpine:latest

# 替换阿里云仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 更新系统并安装必要的依赖项
RUN apk update && apk add --no-cache \
    bash \
    build-base \
    ca-certificates \
    curl \
    zip \
    zlib-dev

# 下载 OpenJDK 17 源代码
RUN curl -L https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz -o /tmp/openjdk.tar.gz

# 解压源代码并进入目录
RUN tar -xzf /tmp/openjdk.tar.gz -C /opt && \
    rm -rf /tmp/openjdk.tar.gz && \
    mv /opt/jdk-17* /opt/jdk

# 配置环境变量
ENV JAVA_HOME=/opt/jdk
ENV PATH=$PATH:$JAVA_HOME/bin

# 设置工作目录
WORKDIR /opt/jdk

# 容器启动命令
CMD ["bash"]
