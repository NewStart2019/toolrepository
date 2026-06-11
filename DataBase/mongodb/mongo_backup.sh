#!/bin/bash
# 定时执行
# 执行命令：crontab -e
# 添加一行： 每日 03:00 执行
#      0 3 * * * /home/mongodb_backup/mongo_backup.sh >> /home/mongodb_backup/backup.log 2>&1


set -o errexit   # 命令出错直接退出脚本
set -o nounset   # 使用未定义变量直接报错退出
set -o pipefail  # 管道命令出错也判定为失败

# ==================== MongoDB 容器备份脚本 ====================
# 备份目录
BACKUP_DIR="/home/mongodb_backup/data"
# MongoDB 容器名称/容器ID
MONGO_CONTAINER="mongodb"
# MongoDB 连接信息（无密码则清空）
MONGO_USER="fRDTebsTWaCRpDbs"
MONGO_PASS='EsjVTh%}MWA=Z77+v!|e837vWm)>]Kf'
MONGO_AUTH_DB="admin"
# 保留天数
RETENTION_DAYS=30
# 备份文件名（时间戳）
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mongo_backup_${DATE}.tar.gz"
# 日志文件
LOG_FILE="${BACKUP_DIR}/mongo_backup.log"

# 统一日志输出函数
log() {
#    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $1" >> "${LOG_FILE}"
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $1"
}

# 错误退出函数
error_exit() {
    log "ERROR: $1"
    exit 1
}

log "========== 开始执行 MongoDB 备份 =========="

# 1. 创建备份目录
log "创建备份目录 ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}" || error_exit "创建备份目录失败"

# 2. 容器内执行 mongodump 备份（环境变量传参，兼容特殊密码）
log "执行容器内 mongodump 备份"
docker exec \
    -e MONGO_USER="${MONGO_USER}" \
    -e MONGO_PASS="${MONGO_PASS}" \
    -e MONGO_AUTH_DB="${MONGO_AUTH_DB}" \
    "${MONGO_CONTAINER}" \
    sh -c 'mongodump -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase "$MONGO_AUTH_DB" -o /tmp/mongo_dump' \
|| error_exit "mongodump 数据库备份失败"

# 3. 从容器拷贝备份文件到宿主机
log "拷贝容器备份文件到宿主机"
docker cp "${MONGO_CONTAINER}:/tmp/mongo_dump" "${BACKUP_DIR}/" \
|| error_exit "拷贝备份文件到宿主机失败"

# 4. 压缩备份文件
log "压缩备份文件"
cd "${BACKUP_DIR}" || error_exit "进入备份目录失败"
tar -zcvf "${BACKUP_FILE}" mongo_dump/ \
|| error_exit "压缩备份文件失败"

# 5. 清理临时文件
log "清理临时目录"
rm -rf "${BACKUP_DIR}/mongo_dump" || log "警告：删除宿主机临时目录失败"
docker exec "${MONGO_CONTAINER}" rm -rf /tmp/mongo_dump || log "警告：删除容器临时目录失败"

# 6. 删除30天前旧备份
log "清理 ${RETENTION_DAYS} 天前的旧备份"
find "${BACKUP_DIR}" -name "mongo_backup_*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null

log "MongoDB 备份完成: ${BACKUP_DIR}/${BACKUP_FILE}"
log "========== 本次备份执行结束 ==========
"