1. **在alpine:3.22.2中没有jdk21**，只能手动下载.执行命令搜索： apk update && apk search openjdk 
2. 构建跨平台基础镜像
buildkitd.toml
```toml
debug = true

[registry."172.16.0.197:8083"]
http = true
insecure = true
 ```
```shell
docker run --privileged --rm tonistiigi/binfmt --install all 
docker buildx create --name mybuilder --use --driver docker-container --bootstrap  --config ./buildkitd.toml 
docker buildx bake -f docker-bake.hcl --push 
```