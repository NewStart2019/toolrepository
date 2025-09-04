#!/bin/bash

# 用法
# 服务器上定时器: crontab -e
#           1 0  * * * /bin/bash /app/mysql/batchBack.sh >> /app/mysql/backup/run.log 2>&1
back_database=("stc_fjjc" "stc-auth" "stc-iot" "stc-jcgl" "stc-jtjc")

# 遍历方式一：
#for i in "${back_database[@]}"; do
#  /bin/bash backupData.sh "$i" 15 /app/mysql/backup "R_qNhdi5vo" true >> /app/mysql/backup/run.log 2>&1
#done

array_length=${#back_database[@]}
# 遍历方式二：
for ((i = 0; i < "${array_length}"; i++))
do
  if [ "$i" -eq "$((array_length - 1))" ]; then
    flag=true
  else
    flag=false
  fi
  echo "开始备份：${back_database[i]}"
  /bin/bash backupData.sh "${back_database[i]}" 15 /app/mysql/backup "R_qNhdi5vo" true
    echo "${back_database[i]}数据库备份完成！"
done

exit 0
