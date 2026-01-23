ARG UBUNTU_VERSION="24.04"

FROM ubuntu:${UBUNTU_VERSION}

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.aliyun.com/ubuntu|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com/ubuntu|http://mirrors.aliyun.com/ubuntu|g' /etc/apt/sources.list && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

# 安装 openssh-server 并清理缓存
RUN apt-get install -y openssh-server
# 生成主机密钥
RUN ssh-keygen -A
RUN apt-get install -y sshpass

# --mount=type=secret,id=rootpw \   # ← 挂载 secret 文件到 /run/secrets/rootpw
# rootpw: secret 的标识符（自定义名称）
# 作用：确保密码只在构建这个 RUN 步骤中可用，不会污染镜像的其他层或环境变量。构建结束后，这个挂载自动卸载，文件消失。
RUN --mount=type=secret,id=rootpw \
    echo "root:$(cat /run/secrets/rootpw)" | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 可选：创建普通用户（更安全）
# RUN useradd -m -s /bin/bash devuser && \
#     echo 'devuser:devpass123' | chpasswd && \
#     usermod -aG sudo devuser

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 暴露 22 端口
EXPOSE 22

# 启动 SSH 服务（-D 表示前台运行，这是 Docker 要求的）
CMD ["/usr/sbin/sshd", "-D"]