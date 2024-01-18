FROM centos:8
LABEL org.opencontainers.image.authors="zqh"
WORKDIR /app
RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts

RUN rm -f /etc/yum.repos.d/*.repo
# https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
COPY CentOS-Base.repo /etc/yum.repos.d/
RUN yum clean all
RUN yum makecache

# 安装nvm
COPY nvm_install.sh /app
COPY nvm_version_change.sh /app
RUN sh nvm_install.sh

# 安装git
RUN yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel git

# 安装sshpass https://sourceforge.net/projects/sshpass/files/latest/download
RUN curl http://172.16.0.97:84/sshpass/sshpass-1.10.tar.gz -o sshpass-1.10.tar.gz
RUN tar -xvf sshpass-1.10.tar.gz
RUN cd sshpass-1.10 && ./configure && make && make install

