FROM centos:centos7.9.2009
LABEL org.opencontainers.image.authors="zqh"

# 安装wget
RUN yum install -y wget
RUN mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
RUN wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
RUN sed -i 's/$releasever/7/g' /etc/yum.repos.d/CentOS-Base.repo
RUN yum clean all
# 安装GPG 密钥
RUN yum install -y gpg
RUN yum makecache
RUN yum install -y deltarpm
RUN yum -y update

WORKDIR /app

# 安装nvm
COPY nvm_install.sh /app
COPY nvm_gcc_environment_deal.sh /app
COPY nvm_version_change.sh /app

# 安装nvm
RUN sh nvm_install.sh
RUN sh nvm_gcc_environment_deal.sh

# 安装ssh、sshpass、git
RUN yum -y install openssh-clients sshpass \
    curl-devel expat-devel gettext-devel openssl-devel zlib-devel git
