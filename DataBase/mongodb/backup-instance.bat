@rem 备份单个节点的数据库所有数据为 bson文件

@echo off
chcp 65001 > nul

call :get_time datetime
set base_path=G:\mongodb\backupData
mongodump -h 172.16.0.197 --port 27017 --authenticationDatabase admin -u admin -p "123456" -d jtjc --out "%base_path%\%datetime%"

@rem 导入是目录需要指定到 数据库目录下面的bson文件
@rem mongorestore -h 172.16.0.175 --port 27017 --authenticationDatabase admin -u admin -p "123456" -d jtjc G:\mongodb\backupData\20240718140704\jtjc

@rem 方法二： mongoexport (必须指定集合名称)| mongoimport
@rem mongoexport -h 172.16.0.197 --port 27017 --authenticationDatabase admin -u admin -p "123456" --db jtjc --type=json --collection BM_1657945176121942018_record --out G:\mongodb\test\BM_1657945176121942018_record.json
@rem mongoimport -h 172.16.0.175 --port 27017 --authenticationDatabase admin -u admin -p "123456" --db jtjc --type=json --collection BM_1657945176121942018_record --file  G:\mongodb\test\BM_1657945176121942018_record.json

:get_time
setlocal enabledelayedexpansion
@rem  获取当前日期和时间
for /f "tokens=1-9 delims=/:. " %%a in ('wmic Path Win32_LocalTime Get Day^,Hour^,Minute^,Month^,Second^,Year /Format:table ^| findstr /r "."') do (
    set day=00%%a
    set hour=00%%b
    set minute=00%%c
    set month=00%%d
    set second=00%%e
    set year=%%f
)

@rem  格式化日期和时间为所需格式
set datetime=%year%%month:~-2%%day:~-2%%hour:~-2%%minute:~-2%%second:~-2%
endlocal  & ( set "%1=%datetime%" )
exit /b


mongodump  --port 27017 --authenticationDatabase admin -u admin -p 'Zjzx123!' -d jcgl-jbz --gzip --out=/root/mdb_backup
mongodump --uri='mongodb://admin:Zjzx123!@127.0.0.1:27017/jcgl-jbz?authSource=admin' --gzip --out=/root/mdb_backup

# 不带/ 结尾表示复制目录 /root/mdb_backup
# 带/ 结尾表示复制目录下面的文件
#-a：归档模式（Archive）。它会递归传输所有文件，并保留文件的权限、时间戳、软链接等所有属性。
# -v：显示详细输出（Verbose）。传输过程中会打印出正在传输的文件名，让你知道进度。
# -z：传输时进行压缩（Compress）。这能有效减少网络传输的数据量，提高传输速度。
# -P：等同于 --partial --progress。它会在传输时显示详细的进度条和剩余时间，并且支持断点续传。
#       如果网络突然中断，下次执行同样的命令会自动从断开的地方继续传，不用从头开始。
rsync -avzP root@192.168.8.116:/root/mdb_backup /app/mongdb
rsync -avzP root@192.168.8.136:/home/shjcxt /app

# --drop 参数（注意：这会先删除目标库中的现有数据
mongorestore --uri='mongodb://admin:KbJFJXEdKNjeDT4!@192.168.8.183:27017/' --gzip /root/mdb_backup --drop