rem powershell 执行删除 标签为 none 的镜像
docker images --filter "dangling=true" --format "{{.ID}}" | ForEach-Object { docker rmi $_ }

rem linux 删除 标签为 none 的镜像
docker images --filter "dangling=true" -q | xargs -r docker rmi
