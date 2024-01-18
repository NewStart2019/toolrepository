FROM centos:7
LABEL org.opencontainers.image.authors="zqh"

WORKDIR /app
RUN touch ~/.bashrc

# 安装nvm
COPY nvm_install.sh /app
COPY nvm_gcc_environment_deal.sh /app
COPY nvm_version_change.sh /app

# 安装nvm
RUN sh nvm_install.sh
RUN sh nvm_gcc_environment_deal.sh

# 安装ssh、sshpass、git
RUN yum install -y epel-release
RUN yum install -y sshpass
RUN yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel git

RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts
