#!/bin/bash

# 一、功能说明：
#       1、自动备份数据库数据，并删除指定天数前的备份文件
#       2、自动计算磁盘使用情况，并写入到mysql数据库中
# 二、参数说明：其他参数自行扩展
#       第一个参数指定：数据库名称                           DB_NAME
#       第二个参数指定：保留天数                             RESERVE_DAY
#       第三个参数指定：备份路径                             BASE_DIR
#       第四个参数指定：用户密码                             MYSQL_PASSWORD
#       第五个参数指定：是否解析磁盘空间 true| false           IS_WRITE_DISK
# 三、使用示例：
#      执行示例：sh backupData.sh stc-jcgl 15
#      定时器使用示例：crontab -e（设置） -l(查看)
#           0 * * * * /app/mysql/backupData.sh stc-jcgl 15
# 四、注意事项：
#      1、自行配置MYSQL_USER）、MYSQL_PASSWORD、BASE_DIR（备份数据路径）
#      2、备份文件存储目录：BASE_DIR/DB_NAME/
#      3、上传到linux服务器上之后，必须要添加可执行权限：chmod +x backupData.sh (*****)
#      4、执行MySQL的sql语句之前设置编码：SET NAMES utf8mb4。否则会产生乱码 (*****)
#      5、函数里面定义的变量也是全局变量

checkParam(){
  # 检查是否有参数传递给脚本
  if [ $# -lt 1 ]; then
    DB_NAME="stc-jcgl"
    echo -e "\e[31m警告：您没有输入第一个参数数据库名称，默认数据库名称是${DB_NAME}\e[0m"
  else
    DB_NAME="$1"
  fi

  if [ $# -lt 2 ]; then
    RESERVE_DAY=15
    echo -e "\e[31m警告：您没有输入第二个参数保留天数，默认保留天数是${RESERVE_DAY}\e[0m"
  else
    RESERVE_DAY=$2
  fi

  if [ $# -lt 3 ]; then
    BASE_DIR="/app/mysql/backup"
    echo -e "\e[31m警告：您没有输入第三个参数备份路径，默认保留天路径是${BASE_DIR}\e[0m"
  else
    BASE_DIR=$3
  fi

  if [ $# -lt 4 ]; then
    MYSQL_PASSWORD="R_qNhdi5vo"
    echo -e "\e[31m警告：您没有输入第四个参数密码，使用默认密码\e[0m"
  else
    MYSQL_PASSWORD=$4
  fi

  if [ $# -lt 5 ]; then
    IS_WRITE_DISK=true
    echo -e "\e[31m警告：您没有输入第五个参数是否解析磁盘空间，默认解析磁盘空间\e[0m"
  else
    IS_WRITE_DISK=$5
  fi
}

initConfig(){
  # 设置MySQL用户名和密码
  MYSQL_USER="root"

  # 获取当前日期
  CURRENT_DATE=$(date +"%Y-%m-%d")
  # 获取当前月份
  CURRENT_MONTH=$(date +"%Y-%m")
  # 当前月的第一天
  LAST_DAY_OF_MONTH=$(date -d "$(date +%Y-%m-01)" "+%Y-%m-%d")
  # 获取当前月份的最后一天
  LAST_DAY_OF_MONTH=$(date -d "$(date +'%Y-%m-01') +1 month -1 day" +"%Y-%m-%d")

  # 设置备份文件存储目录
  BACKUP_DIR="${BASE_DIR}/${DB_NAME}/temp"

  # 使用if语句检查目录是否存在
  if [ ! -d "${BACKUP_DIR}" ]; then
    mkdir -p "${BACKUP_DIR}"
  fi
}

backData(){
  # 创建当天的备份文件
  BACKUP_FILE="${BACKUP_DIR}/${CURRENT_DATE}.sql"

  # 使用 mysqldump 备份数据库: 默认锁住所有表进行数据备份
  docker exec -i mysql8 mysqldump -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DB_NAME}" >"${BACKUP_FILE}"

  # 如果今天是每月第一天，将当天备份文件保存为上月底备份文件
  if [ "${CURRENT_DATE}" = "${LAST_DAY_OF_MONTH}" ]; then
    cp "${BACKUP_FILE}" "${BASE_DIR}/${DB_NAME}/${CURRENT_MONTH}.sql"
  fi

  # 删除 RESERVE_DAY天前的文件
  find "${BACKUP_DIR}" -name '*.sql' -type f -mtime +"${RESERVE_DAY}" -exec rm {} \;

  # 输出备份完成消息
  echo "${CURRENT_DATE}数据库备份完成：${BACKUP_FILE}"
}

snowFlow() {
  # 定义机器ID和序列号位数
  machine_id=1
  sequence=0
  # 定义位移和偏移量
  timestamp_left_shift=22
  machine_id_shift=17
  sequence_mask=$((2 ** 5 - 1)) # 序列号占用5位，最大为31
  # 定义时间戳的起始时间
  twepoch=1288834974657
  # 获取当前时间戳（毫秒级）
  timestamp=$(date +%s%3N)
  # 计算生成的 ID
  current_timestamp=$((timestamp - twepoch))
  result_id=$(((current_timestamp << timestamp_left_shift) | (machine_id << machine_id_shift) | (sequence & sequence_mask)))
  echo $result_id
}

writeDisk(){
  if [ "${IS_WRITE_DISK}" != "true" ]; then
    return 0
  fi
  # 获取 /dev/sda 磁盘的总空间 GB (定时任务的执行环境中没有设置正确的 PATH 变量，注意这里fdisk全路径)
  all=$(/usr/sbin/fdisk -l | grep "Disk /dev/sda" | awk '{print $3}')
  if [ -z "$all" ]; then
    all=0
  fi
  #all=$(/usr/sbin/fdisk -l | grep "Disk /dev/sda" | awk '{print $2}' | awk -F\： '{print $2}')
  # 获取数据目录下面所占空间大小 MB
  data=$(du -sm /app | awk '{print $1}')
  # 获取操作系统名称
  os="运维服务器$(uname -s)"
  id=$(snowFlow)
  CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
  COMMAND="SET NAMES utf8mb4;INSERT INTO \`stc-jcgl\`.\`sys_space\` (\`id\`,\`os_name\`, \`use_size\`, \`all_size\`, \`create_time\`) VALUES ('${id}','${os}', ${data}, ${all}, '${CURRENT_TIME}');"
  echo "$COMMAND"
  # 将数据存储到 MySQL 数据库
  docker exec -i mysql8 mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DB_NAME}" -e "${COMMAND}"
}

checkParam "$@"
initConfig
backData
writeDisk
