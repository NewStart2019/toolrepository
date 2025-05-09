FROM alpine:3
MAINTAINER ee900222 [email protected]

# install sshpass
ADD ./download.sh /run/
# 替换阿里云仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk update
# 安装ssh
RUN apk add --no-cache openssh
# 安装sshpass
RUN apk add --upgrade sshpass
RUN mkdir /root/.ssh && touch /root/.ssh/known_hosts
CMD ["/etc/init.d/sshd", "-D"]
