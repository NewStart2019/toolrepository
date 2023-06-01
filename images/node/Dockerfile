FROM alpine:3
MAINTAINER zqh
 
# 替换阿里云仓库
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk update
# 安装ssh
RUN apk add --no-cache openssh
# 安装sshpass
RUN apk add --upgrade sshpass
# 安装node、npm
RUN apk add nodejs npm
CMD ["/etc/init.d/sshd", "-D"]