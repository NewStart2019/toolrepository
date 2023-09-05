FROM openjdk:20-ea-17-oraclelinux7
LABEL maintainer="zqh"

ENV TimeZone='Asia/Shanghai'

# 设置时区
RUN ln -sf /usr/share/zoneinfo/$TimeZone /etc/localtime && echo $TimeZone > /etc/timezone

COPY simsun.ttc /usr/share/fonts/
COPY simsun.ttf /usr/share/fonts/
COPY simhei.ttf /usr/share/fonts/
COPY "仿宋_GB2312.ttf" /usr/share/fonts/
COPY Times_New_Roman.ttf /usr/share/fonts/