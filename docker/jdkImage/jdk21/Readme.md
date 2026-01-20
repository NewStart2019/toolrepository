

# Alpine-jdk21 描述
# Mirror Description
* A multi **architecture** image built based on **Alpine-3.23.0**, the **smallest image** built to run **Java applications**
* Using OpenJDK21-JRE
* The **jar** file is **mounted into the container** for **easy manual and quick modification and publishing**
# Example usage
## docker-compose运行
```yaml
name: vote
services:
  vote:
    image: zqh2021/alpine-jdk21:1.0
    container_name: vote-1.0
    restart: always
    entrypoint:
      - java
      - -jar
      - -Djava.awt.headless=true
      - -Dfile.encoding=UTF-8
      - -Duser.timezone=Asia/Shanghai
      - /app/app.jar
    ports:
      - 8095:8080
    volumes:
      - ./app.jar:/app/app.jar
      # 挂在上传文件目录
      # 挂载日志目录
```
## docker运行
```shell
docker run -d \
  --name vote-1.0 \
  --restart always \
  -p 8095:8080 \
  -v "$(pwd)/app.jar:/app/app.jar" \
  zqh2021/alpine-jdk21:1.0 \
  java -jar \
    -Djava.awt.headless=true \
    -Dfile.encoding=UTF-8 \
    -Duser.timezone=Asia/Shanghai \
    /app/app.jar
```

# 镜像说明
* 基于**alpine-3.23.**0构建的**多架构**镜像，为了运行**java应用**而构建的**最小镜像**
* 使用的是openjdk21-jre 
* jar文件通过**挂载进入容器**使用，目的是**便于手动快速修改发布**
# 使用示例
参考上面的示例
