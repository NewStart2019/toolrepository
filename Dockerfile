FROM busybox
ADD target/ROOT.jar /
CMD "tail" "-f" "/dev/null"
