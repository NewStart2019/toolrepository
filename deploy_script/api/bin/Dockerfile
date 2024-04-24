ARG DOCKER_REPOSITORY

FROM ${DOCKER_REPOSITORY}/tool/jdk21:1.2
LABEL maintainer="zqh"
ARG PORT=8605
WORKDIR /app

COPY stc-jtjc-latest.jar /app/app.jar

ENTRYPOINT ["java","-jar","-Djava.awt.headless=true", "-Xmx2048m","-Dfile.encoding=UTF-8","-Duser.timezone=Asia/Shanghai","/app/app.jar"]
