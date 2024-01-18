FROM centos:8
LABEL org.opencontainers.image.authors="zqh"

WORKDIR /app
RUN touch ~/.bashrc

COPY CentOS-Base.repo /etc/yum.repos.d/
RUN rm -f /etc/yum.repos.d/AppStream.repo
RUN sed -i 's/$releasever/8/g' /etc/yum.repos.d/CentOS-Base.repo
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
RUN dnf update

# 安装nvm
COPY nvm_install.sh /app
COPY nvm_version_change.sh /app

# 安装nvm
RUN sh nvm_install.sh

# 安装ssh、sshpass、git
RUN dnf install -y epel-release
RUN dnf install -y sshpass
RUN dnf install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel git

RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts
