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
