#!/bin/bash

# 检查是否有参数传递给脚本
if [ $# -lt 1 ]; then
    DB_NAME="stc-jcgl"
    echo -e "\e[31m警告：您没有输入第一个参数数据库名称，默认数据库名称是${DB_NAME}\e[0m"
else
    DB_NAME="$1"
fi

# 获取当前日期
CURRENT_DATE=$(date +"%Y-%m-%d")
# 获取当前月份
CURRENT_MONTH=$(date +"%Y-%m")
# 获取当前月份的最后一天
LAST_DAY_OF_MONTH=$(date -d "$(date +'%Y-%m-01') +1 month -1 day" +"%Y-%m-%d")

BASE_DIR="/app/mysql/backup"
# 设置备份文件存储目录
BACKUP_DIR="${BASE_DIR}/${DB_NAME}/${CURRENT_MONTH}"

# 使用if语句检查目录是否存在
if [ ! -d "${BACKUP_DIR}" ]; then
  mkdir -p "${BACKUP_DIR}"
fi

# 设置MySQL用户名和密码
MYSQL_USER="root"
MYSQL_PASSWORD="R_qNhdi5vo"

# 创建当天的备份文件
BACKUP_FILE="${BACKUP_DIR}/${CURRENT_DATE}.sql"

# 使用 mysqldump 备份数据库
mysqldump -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DB_NAME}" >"${BACKUP_FILE}"

# 如果今天是每月月底，将当天备份文件保存为月底备份文件，然后删除当月其他文件
if [ "${CURRENT_DATE}" = "${LAST_DAY_OF_MONTH}" ]; then
  mv "${BACKUP_FILE}" "${BASE_DIR}/${DB_NAME}/${CURRENT_MONTH}.sql"
  rm -rf ${BACKUP_DIR}
fi

# 输出备份完成消息
echo "数据库备份完成：${BACKUP_FILE}"
