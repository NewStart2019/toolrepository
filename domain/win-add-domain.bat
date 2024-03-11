@echo off
chcp 65001 > null
setlocal enabledelayedexpansion

rem 脚本存在问题：
rem  1、默认值变量没有输出
rem  2、设置的域名访问没有生效

rem 检查是否要显示帮助文档
if "%~1"=="/?" (
    echo 用法: %~nx0 [域名] [IP地址]
    echo.
    echo 添加一个局域网解析的IP到本地hosts文件中。
    echo.
    echo  参数:
    echo    域名         要添加的域名
    echo    IP地址       要添加的IP地址
    exit /b
)

rem 检查参数是否为空，如果为空则使用默认参数
if "%~1"=="" (
    set "domain=test.cqjdjc.com"
    echo 警告：未提供域名参数，默认使用 %domain%
) else (
    set "domain=%~1"
)

if "%~2"=="" (
    set "ip_address=172.16.0.97"
    echo 警告：未提供 IP 地址参数，默认使用 %ip_address%
) else (
    set "ip_address=%~2"
)

rem 检查是否有管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误：请以管理员权限运行此脚本
    goto eof
)

rem 检查本地主机文件路径
set "hosts_file=%windir%\System32\drivers\etc\hosts"
if not exist "%hosts_file%" (
    echo 错误：hosts 文件不存在
    exit /b 1
)

rem 检查是否已经存在相同的解析
findstr /c:"%domain%" "%hosts_file%" >nul 2>&1
if %errorlevel% equ 0 (
    echo 警告：%domain% 已经存在于 hosts 文件中
) else (
    rem 将域名和 IP 添加到 hosts 文件
    echo %ip_address%   %domain% >> "%hosts_file%"
    echo 成功：%domain% 添加到 hosts 文件中
)

rem 刷新 DNS 缓存
ipconfig /flushdns
echo DNS 缓存已刷新

:eof
rem 提示用户按下 Enter 键关闭窗口
echo.
echo 请按下 Enter 键关闭窗口...
pause >nul
