# 解压缩gz 包 会删除原来的压缩包文件
gunzip 文件名称

ROOT_PATH="/root"
# shellcheck disable=SC2164
cd $ROOT_PATH;
mkdir -p ./dist_new;
tar -xzf $ARCHIVE -C ./dist_new --strip-components=1 && rm -rf ./dist && mv ./dist_new ./dist;
docker exec nginx-proxy nginx -s reload
