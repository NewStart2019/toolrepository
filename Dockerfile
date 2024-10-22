FROM docker.m.daocloud.io/busybox
ADD target/ROOT.jar /
CMD "tail" "-f" "/dev/null"
