# 目录说明
此文件夹下面构建特定功能的操作系统镜像

# 构建ubuntu
## 构建镜像
```powershell
$env:ROOT_PASSWORD="123456"
docker buildx bake -f docker-bake.hcl --push --builder mybuilder
```