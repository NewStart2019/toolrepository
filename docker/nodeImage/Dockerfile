FROM ubuntu:25.10

LABEL org.opencontainers.image.authors="zqh"
WORKDIR /app
ARG NODE_VERSION=22.17.0

# 备份原有的 sources.list 文件（可选）
RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak
# 替换为阿里云镜像源
RUN echo "deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse" >> /etc/apt/sources.list

# 更新软件包索引
RUN apt-get update
RUN apt-get install -y curl git

# 安装nvm
COPY nvm_install.sh /app
COPY nvm_version_change.sh /app
RUN sh nvm_install.sh
ENV NVM_DIR=/root/.nvm
RUN echo "export NVM_DIR=\"$NVM_DIR\" && [ -s \"$NVM_DIR/nvm.sh\" ] && \. \"$NVM_DIR/nvm.sh\"" >> /root/.bashrc
RUN . /root/.bashrc
RUN /app/nvm_version_change.sh $NODE_VERSION

# 安装sshpass https://sourceforge.net/projects/sshpass/files/latest/download
RUN apt-get install sshpass

RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts
COPY id_rsa /root/.ssh/id_rsa
RUN apt-get install dos2unix
RUN dos2unix /root/.ssh/id_rsa
RUN chmod 700 ~/.ssh
RUN chmod 600 /root/.ssh/id_rsa

RUN apt-get remove -y dos2unix
RUN apt-get clean
RUN git --version