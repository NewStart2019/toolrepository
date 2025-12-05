# nginx代理

## docker-compose.yml 
 是手动构建的镜像，添加了nginx_upstream_check_module 模块 upstream 检测。自动断开和连接负载均很的服务
 docker-bake.hcl 是 构建多架构镜像脚本（构建失败）

```shell
docker buildx bake -f docker-bake.hcl --push
```
