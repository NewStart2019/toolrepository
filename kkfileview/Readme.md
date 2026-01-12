# 自己构建镜像说明

## 项目打包jar包
下载项目[kkFileView](https://github.com/kekingcn/kkFileView)，构建jar包放在**Dockerfile-new**统计目录下面。

## 构建镜像

使用**KkFileView.yml**文件构建当前操作系统对应架构的镜像
使用docker-bake.hcl构建多架构镜像 **docker buildx bake -f docker-bake.hcl --push**

## 运行
直接拉取docker hub的镜像或者根据上面的描述构建镜像

```shell
docker-compose -f KkFileView.yml up -d 
```