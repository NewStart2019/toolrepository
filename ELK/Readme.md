# 解决elasticsearch启动挂载目录无权限问题

查看用户：docker run --rm docker.elastic.co/elasticsearch/elasticsearch:8.12.0 id
uid=1000(elasticsearch) gid=0(root)

## 修改目录权限

mkdir -p es_data
mkdir -p es_log

sudo chown -R 1000:0 es_data
sudo chown -R 1000:0 es_log

#   Kibana 配置密钥
先启动容器，然后执行生成密钥命令
```shell
# Docker 环境
docker exec -it <kibana_container_name> bin/kibana-encryption-keys generate

# 非 Docker 环境
./bin/kibana-encryption-keys generate
```
该命令会输出三行配置，将其全部复制到 kibana.yml 即可：
```yaml
xpack.encryptedSavedObjects.encryptionKey: "..."
xpack.reporting.encryptionKey: "..."
xpack.security.encryptionKey: "..."

```

# 创建服务token
## 在 Elasticsearch 中创建 Token
bin/elasticsearch-service-tokens create elastic/kibana kibana-token

. 修改 kibana.yml
```yaml
# ❌ 删除这两行
# elasticsearch.username: "elastic"
# elasticsearch.password: "xxx"

# ✅ 替换为 Service Token
elasticsearch.serviceAccountToken: "AAEAAWVsYXN0aWMva2liYW5hL2tpYmFuYS10b2tlbjp..."

```


