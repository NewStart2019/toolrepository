FROM openjdk:21-ea-17-oraclelinux7
LABEL maintainer=zqh
WORKDIR /app

ENV TimeZone=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/$TimeZone /etc/localtime && echo $TimeZone > /etc/timezone

ADD fonts/* /usr/share/fonts
