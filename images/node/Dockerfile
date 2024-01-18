FROM centos:8
LABEL org.opencontainers.image.authors="zqh"

WORKDIR /app
RUN touch ~/.bashrc

RUN rm -f /etc/yum.repos.d/*.repo
# https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
COPY CentOS-Base.repo /etc/yum.repos.d/

RUN yum clean all
RUN yum makecache


# 安装nvm
COPY nvm_install.sh /app
COPY nvm_version_change.sh /app

# 安装nvm
RUN sh nvm_install.sh

# 安装ssh、sshpass、git
RUN yum install -y epel-release
RUN yum install -y sshpass
RUN yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel git

RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts
