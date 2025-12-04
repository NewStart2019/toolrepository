# 说明

构建docker builder 的容器，为了跨平台构建镜像

# 命令构建容器
直接拉取镜像构建容器
```shell
docker buildx create --name mybuilder --use --driver docker-container --bootstrap  --config ./buildkitd.toml 
```

# docker-compsoe 创建容器（**挂载配置失败**）
```shell
## 启动容器
docker compose up -d

## 使用容器作为构建环境 （失败）
docker buildx use mybuilder
docker buildx inspect --bootstrap
```

