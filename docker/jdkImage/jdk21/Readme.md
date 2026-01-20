# Mirror Description
* A multi **architecture** image built based on **Alpine-3.23.0**, the **smallest image** built to run **Java applications**
* Using OpenJDK21-JRE
* The **jar** file is **mounted into the container** for **easy manual and quick modification and publishing**
* Downloaded commonly used fonts for generating reports, such as arial.ttf、arialnbi.ttfarial.ttf、arialnbi.ttf、calibrib.ttf、califi.ttf、dejavu、simsun.ttc、stsong.ttf、wingdings 2.ttf、arialbd.ttf、arialni.ttf、calibrii.ttf、califr.ttf、encodings、simsun.ttf、times.ttf
  arialbi.ttf、arialuni.ttf、calibril.ttf、calist.ttf、msyh.ttc、sjqy.ttf、times_new_roman.ttf
  ariali.ttf、ariblk.ttf、calibrili.ttf、calistb.ttf、msyhbd.ttc、sjqy1.ttf、timesbd.ttf
  arialn.ttf、arlrdbd.ttf、calibriz.ttf、calistbi.ttf、msyhl.ttc、sjqy2.ttf、timesbi.ttf
  arialnb.ttf、calibri.ttf、califb.ttf、calisti.ttf、simhei.ttf、sjqy3.ttf、timesi.ttf
# Example usage
## docker-compose运行
```yaml
name: emcp
services:
  emcp:
    image: zqh2021/alpine_jdk21_special_ocr:1.4
    container_name: emcp-1.0.0
    restart: unless-stopped
    network_mode: bridge
    entrypoint:
      - java
      - -Xshare:on
      - -jar
      - -Djava.awt.headless=true
      - -Xmx2048m
      - -Dfile.encoding=UTF-8
      - --enable-preview
      - -Duser.timezone=Asia/Shanghai
      - /app/app.jar
    ports:
      - 8001:8001
    environment:
      SPRING_PROFILES_ACTIVE: ${PROFILES_ACTIVE:-dev}
      TZ: Asia/Shanghai
    volumes:
      # 挂载日志目录
      - ./app.jar:/app/app.jar
```
## docker运行
```shell
docker run -d \
  --name emcp-1.0.0 \
  --restart unless-stopped \
  -p 8001:8001 \
  -v "$(pwd)/app.jar:/app/app.jar" \
  zqh2021/alpine_jdk21_special_ocr:1.4 \
  java -Xshare:on -jar \
    -Djava.awt.headless=true \
    -Xmx2048m \
    -Dfile.encoding=UTF-8 \
    --enable-preview \
    -Duser.timezone=Asia/Shanghai \
    /app/app.jar
```

# 镜像说明
* 基于**alpine-3.23.0**构建的**多架构**镜像，为了运行**java应用**而构建的**最小镜像**
* 使用的是openjdk21-jre
* 安装了**tesseract-ocr**支持**英文**和**简体中文**的图片识别文字
* jar文件通过**挂载进入容器**使用，目的是**便于手动快速修改发布**
* 下载了arial.ttf、arialnbi.ttf、calibrib.ttf、califi.ttf、dejavu、simsun.ttc、stsong.ttf、wingdings 2.ttf、arialbd.ttf、arialni.ttf、calibrii.ttf、califr.ttf、encodings、simsun.ttf、times.ttf
  arialbi.ttf、arialuni.ttf、calibril.ttf、calist.ttf、msyh.ttc、sjqy.ttf、times_new_roman.ttf
  ariali.ttf、ariblk.ttf、calibrili.ttf、calistb.ttf、msyhbd.ttc、sjqy1.ttf、timesbd.ttf
  arialn.ttf、arlrdbd.ttf、calibriz.ttf、calistbi.ttf、msyhl.ttc、sjqy2.ttf、timesbi.ttf
  arialnb.ttf、calibri.ttf、califb.ttf、calisti.ttf、simhei.ttf、sjqy3.ttf、timesi.ttf 等常用生成报告需要使用的字体
# 使用示例
参考上面的示例