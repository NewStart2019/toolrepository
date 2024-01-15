FROM centos:centos7.9.2009
MAINTAINER zqh

# 替换阿里云仓库
RUN mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
RUN wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
RUN sed -i 's/$releasever/7/g' /etc/yum.repos.d/CentOS-Base.repo
RUN yum clean all
RUN yum makecache
RUN yum update

WORKDIR /app

# 安装nvm
COPY nvm_install.sh /app
COPY nvm_gcc_environment_deal.sh /app

# 安装sshpass
RUN sh nvm_install.sh
RUN sh nvm_gcc_environment_deal.sh
