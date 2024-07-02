@rem 本地自动化部署脚本
@rem 实现目标：
@rem 1. 本地下载依赖打包
@rem 2. 自动部署到目标服务器

@echo off
chcp 65001 > nul

set startTime=%TIME%

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
set DEVOPS_IP=172.16.0.197
set PROJECT_NAME=stc-jtjc-web

call npm install --registry=https://registry.npmmirror.com/
call npm run build
rem 检查上一条命令的执行结果
if %ERRORLEVEL% neq 0 (
    color 4
    echo Build failed, please fix the errors and retry!
)



call :find_IP currentIP

rem 判断变量是否等于字符串 "dev"
if "%target%"=="dev" (
    set username=root
    set ip=172.16.0.227
    set password=Zjzx123!
) else (
    set username=root
    set ip=172.16.0.226
    set password=JKgTh4bPyyput9j8
)

call sshpass -p %password% ssh %username%@%ip% "if [ ! -d \"/app/%PROJECT_NAME%/log\" ]; then mkdir -p /app/%PROJECT_NAME%/log; fi;"
@rem 发布代码：判断时测试环境还是正式环境，然后设置ip
call sshpass -p %password% scp -rp dist/* %username%@%ip%:/app/%PROJECT_NAME%/dist

call :get_time datetime
call sshpass -p %password% ssh  %username%@%ip% "echo Deployment for user with %currentIP% was successful\, deployment time is：%datetime% >> /app/%PROJECT_NAME%/log/deploy.log;"

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
