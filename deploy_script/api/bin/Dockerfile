ARG DOCKER_REPOSITORY

FROM ${DOCKER_REPOSITORY}/tool/alpine_jdk21_special-jdk21:1.2
ARG PROJECT_VERSION
ARG PORT
ARG JAR_FILE
LABEL maintainer="zqh"

WORKDIR /app

EXPOSE ${PORT}
COPY ${JAR_FILE} /app/app.jar

ENTRYPOINT ["java","-jar","-Djava.awt.headless=true", "-Xmx2048m","-Dfile.encoding=UTF-8","--enable-preview","-Duser.timezone=Asia/Shanghai","/app/app.jar"]
