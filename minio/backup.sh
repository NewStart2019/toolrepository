# 先给本地和远程备份的目标设置别名
# 新增修改： mc alias set <别名名称> <S3端点URL> <AccessKey> <SecretKey> [API版本]
mc alias set local http://localhost:9000 minioadmin minioadmin
mc alias set backup http://172.16.0.107:9000 minioadmin minioadmin
# 查看所有已配置别名	mc alias list
# 查看某个别名详情	mc alias list mycloud
# 删除别名	mc alias remove mycloud

# 完整镜像（含删除，适合灾备切换前的最终同步）
mc mirror --preserve --overwrite --remove  --md5 local/stcjcgl  backup/stcjcgl