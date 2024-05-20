@rem 本地自动化部署脚本
@rem 前提条件本地安装 docker、docker-compose
@rem 实现目标：
@rem 1. 本地打包最新的 jar包 ，右侧gradle插件 → stc-jtjc → Tasks → build → bootJar
@rem 2. 构建 docker 镜像, 永久配置登录信息 在用户目录下/.docker/config 添加
@rem 4. 推送镜像到镜像仓库172.16.0.197:8083。需要提前登录镜像仓库。
@rem 5. 目标服务器启动 docker 容器

@echo off
chcp 65001 > nul

set startTime=%TIME%
set PROJECT_NAME=stc-jcgl

set target=%1
@rem 检查第一个参数是否存在
if "%1"=="" (
    echo No specific target server parameter 'dev' or 'prod' was provided. Please pass the parameter and rerun the script.
    color 4
    echo Warning: No specific target server parameter 'dev' or 'prod' was provided, defaulting to 'dev'.
    echo Example: deploy.bat dev
    color
    set target=dev
)

@rem 执行你的命令
if "%OS%"=="Windows_NT" @setlocal
set current_path=%~dp0
cd "%current_path%.."
call gradlew.bat clean bootJar -x test
move build\libs\%PROJECT_NAME%-latest.jar %current_path%..\bin
call docker-compose -f bin\docker-compose-%PROJECT_NAME%.yml build
call docker-compose -f bin\docker-compose-%PROJECT_NAME%.yml push -q

call :find_IP currentIP

rem 判断变量是否等于字符串 "dev"
if "%target%"=="dev" (
    set username=root
    set ip=172.16.0.227
    set password=Zjzx123!
) else (
    set username=root
    set ip=172.16.0.83
    set password=94whI23VucJWqqBm
)

@rem 默认发布正式环境分支都是master，其他分支默认都是发布测试环境
if "%target%"=="prod" (
    git checkout master
    git pull origin master
)

@rem 发布代码：判断时测试环境还是正式环境，然后设置ip
call sshpass -p %password% scp -p bin\docker-compose-%PROJECT_NAME%.yml %username%@%ip%:/app/%PROJECT_NAME%
call sshpass -p %password% ssh  %username%@%ip% "if [ ! -d \"/app/%PROJECT_NAME%/log\" ]; then mkdir -p /app/%PROJECT_NAME%/log; fi;"
call sshpass -p %password% ssh  %username%@%ip% "docker-compose -f /app/%PROJECT_NAME%/docker-compose-%PROJECT_NAME%.yml pull -q; docker-compose -f /app/%PROJECT_NAME%/docker-compose-%PROJECT_NAME%.yml up -d;"

call :get_time datetime
for /f "tokens=*" %%i in ('git log --oneline -n 1 HEAD') do set git_log=%%i
call sshpass -p %password% ssh  %username%@%ip% "echo Deployment for user with " %currentIP% " was successful, deployment time is: " %datetime% ". The Git log for the deployment is: " %git_log% ">> /app/%PROJECT_NAME%/log/deploy.log;"
@rem call docker image prune -a -f
set endTime=%TIME%

@rem 计算时间差
call :GetTimeDiff startTime endTime totalTime

echo Total time spent: %totalTime%
pause
exit /b

:GetTimeDiff start end diff
    setlocal enabledelayedexpansion
    set "start_h=!%1:~0,2!"
    set "start_m=!%1:~3,2!"
    set "start_s=!%1:~6,2!"
    set "end_h=!%2:~0,2!"
    set "end_m=!%2:~3,2!"
    set "end_s=!%2:~6,2!"

    set /a "start_seconds = ((start_h * 60 + start_m) * 60) + start_s"
    set /a "end_seconds = ((end_h * 60 + end_m) * 60) + end_s"

    set /a "diff_seconds = end_seconds - start_seconds"
    if !diff_seconds! lss 0 set /a "diff_seconds += 24*60*60"

    set /a "hours = diff_seconds / 3600"
    set /a "remainder = diff_seconds %% 3600"
    set /a "minutes = remainder / 60"
    set /a "seconds = remainder %% 60"

    if %hours% lss 10 set hours=0%hours%
    if %minutes% lss 10 set minutes=0%minutes%
    if %seconds% lss 10 set seconds=0%seconds%

    endlocal & (
        set "%3=%hours%:%minutes%:%seconds%"
    )
exit /b

:find_IP
setlocal enabledelayedexpansion
set lastIP=
set index=0

for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    rem 移除IP地址中的空格
    set "ip=!ip: =!"
    rem 将IP地址添加到数组
    set /a index+=1
    set "IPArray[!index!]=!ip!"
)

for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 地址"') do (
    set "ip=%%a"
    rem 移除IP地址中的空格
    set "ip=!ip: =!"
    rem 将IP地址添加到数组
    set /a index+=1
    set "IPArray[!index!]=!ip!"
)

@rem  遍历数组，查找以"192.168.1"开头的IP地址
for /l %%i in (1, 1, %index%) do (
    set "currentIP=!IPArray[%%i]!"
    rem 检查IP地址是否以"192.168.1"开头
    if "!currentIP:~0,8!"=="172.16.0" (
        set "lastIP=!currentIP!"
    )
)
endlocal  & ( set "%1=%lastIP%" )
exit /b

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
set datetime=%year%-%month:~-2%-%day:~-2% %hour:~-2%:%minute:~-2%:%second:~-2%
endlocal  & ( set "%1=%datetime%" )
exit /b
