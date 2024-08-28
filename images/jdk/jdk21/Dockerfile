FROM openjdk:21-ea-17-oraclelinux7
LABEL maintainer=zqh
WORKDIR /app

ENV TimeZone=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/$TimeZone /etc/localtime && echo $TimeZone > /etc/timezone

# stc-jcgl resources/fonts 下面有字体文件
RUN curl -o /usr/share/fonts/msyh.ttc http://172.16.0.227:84/fonts/msyh.ttc
RUN curl -o /usr/share/fonts/msyhbd.ttc http://172.16.0.227:84/fonts/msyhbd.ttc
RUN curl -o /usr/share/fonts/msyhl.ttc http://172.16.0.227:84/fonts/msyhl.ttc
RUN curl -o /usr/share/fonts/simhei.ttf http://172.16.0.227:84/fonts/simhei.ttf
RUN curl -o /usr/share/fonts/simsun.ttc http://172.16.0.227:84/fonts/simsun.ttc
RUN curl -o /usr/share/fonts/stsong.ttf http://172.16.0.227:84/fonts/stsong.ttf
RUN curl -o /usr/share/fonts/simsun.ttf http://172.16.0.227:84/fonts/simsun.ttf
RUN curl -o /usr/share/fonts/times.ttf http://172.16.0.227:84/fonts/times.ttf
RUN curl -o /usr/share/fonts/Times_New_Roman.ttf http://172.16.0.227:84/fonts/Times_New_Roman.ttf
RUN curl -o /usr/share/fonts/timesbd.ttf http://172.16.0.227:84/fonts/timesbd.ttf
RUN curl -o /usr/share/fonts/timesbi.ttf http://172.16.0.227:84/fonts/timesbi.ttf
RUN curl -o /usr/share/fonts/timesi.ttf http://172.16.0.227:84/fonts/timesi.ttf

RUN chmod +x /usr/share/fonts/*
