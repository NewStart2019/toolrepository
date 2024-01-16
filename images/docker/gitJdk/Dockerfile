FROM docker:git
LABEL org.opencontainers.image.authors="zqh"

WORKDIR /app

# 写入docker
RUN /bin/sh -c set -eux; file="/etc/docker/daemon.json"; \
  writeConfig() { if [ ! -f "$file" ]; then \
    mkdir -p "/etc/docker"; touch $file; \
    echo '{ "log-driver":"json-file", "log-opts": {"max-size":"500m", "max-file":"3"}, "insecure-registries": ["172.16.0.145:8083","172.16.0.145:8929"], \
     "registry-mirrors": ["http://172.16.0.145:8083/","http://172.16.0.145:8929/","https://registry.cn-hangzhou.aliyuncs.com/"] }' | tee "$file" >/dev/null;  \
    echo "File $file created and content written."; else echo "File $file already exists."; fi; \
    systemctl start docker; docker login -u admin -p s9AGdzFaSLXyQrD 172.16.0.145:8083;  \
  }; writeConfig;

ENV JAVE_VERSION=21
# 安装jdk
RUN /bin/sh -c set -eux; apkArch="$(apk --print-arch)"; case "$apkArch" in 'aarch64') url='http://172.16.0.97:84/jdk/Linux/jdk-${JAVE_VERSION}_linux-aarch64_bin.rpm'; ;; \
    *) url='http://172.16.0.97:84/jdk/Linux/jdk-${JAVE_VERSION}_linux-x64_bin.rpm' ;; esac; wget -O 'openjdk.rpm' "$url"; PACKAGE_NAME="openjdk.rpm";  \
    chmod +x $PACKAGE_NAME ; rpm -ivh $PACKAGE_NAME; rm $PACKAGE_NAME; java -version

# 安装ssh、sshpass、git
RUN RUN /bin/sh -c apk add --no-cache sshpass
