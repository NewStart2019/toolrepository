FROM centos:centos8
ADD ./cshome.tar.gz /
COPY ./CornerstoneBizSystem.jaz /cshome/jazmin_server_jdk10/instance/CornerstoneBizSystem
COPY ./CornerstoneWebSystem.war /cshome/jazmin_server_jdk10/instance/CornerstoneWebSystem
RUN mkdir -p /cshome/jazmin_server_jdk10/log
RUN mkdir -p /cshome/jazmin_server_jdk10/file_storage

RUN dnf update && dnf install net-tools

RUN  chmod 755 -R /cshome/jdk10/bin \
	&& chmod -R 755 /cshome/jazmin_server_jdk10/file_storage \
	&& chmod 755 /cshome/jazmin_server_jdk10/log \
	&& chmod 755 /cshome/jazmin_server_jdk10/restartall.sh \
        && chmod 755 /cshome/jazmin_server_jdk10/cornerstone

#
WORKDIR /cshome/jazmin_server_jdk10
#启动命令
ENTRYPOINT ["/cshome/jazmin_server_jdk10/cornerstone","start"]
