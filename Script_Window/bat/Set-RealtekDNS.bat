@echo off
:: 强制切换控制台为GBK编码，解决不同系统代码页不一致导致的乱码
>nul chcp 936
setlocal enabledelayedexpansion

:: ==============================================
:: 配置参数
:: ==============================================
set "dns_primary=172.16.0.128"
set "dns_backup=114.114.114.114"
set "keyword=Realtek"

:: ==============================================
:: 自动申请管理员权限
:: ==============================================
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo 正在请求管理员权限...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
    pushd "%~dp0"
    cls

:: ==============================================
:: 查找 Realtek 硬件网卡
:: ==============================================
echo.
echo 正在查找硬件名称包含 %keyword% 的已启用网卡...
echo ==============================================

set /a count=0
set "adapter_list="

:: 筛选：已启用 + 硬件名称包含Realtek → 取系统连接名
for /f "tokens=2 delims==" %%a in (
    'wmic nic where "NetEnabled=true and Name like '%%%keyword%%%'" get NetConnectionID /value 2^>nul'
) do (
    for /f "delims=" %%b in ("%%a") do (
        if not "%%b"=="" (
            set /a count+=1
            set "adapter_list=!adapter_list! "%%b""
            echo 找到网卡：%%b
        )
    )
)

if %count%==0 (
    echo.
    echo 错误：未找到 %keyword% 品牌的已启用网卡
    echo ==============================================
    pause
    exit /b 1
)

echo.
echo 共找到 %count% 个符合条件的网卡，开始设置DNS...
echo ==============================================

:: ==============================================
:: 批量设置DNS
:: ==============================================
set /a success=0
for %%i in (%adapter_list%) do (
    echo.
    echo 正在处理网卡：%%~i

    :: 设置主DNS
    netsh interface ipv4 set dns name=%%~i static %dns_primary% primary >nul 2>&1
    if !errorlevel! equ 0 (
        :: 添加备用DNS
        netsh interface ipv4 add dns name=%%~i %dns_backup% index=2 >nul 2>&1
        echo 设置成功
        set /a success+=1
    ) else (
        echo 设置失败
    )
)

:: ==============================================
:: 刷新DNS缓存
:: ==============================================
echo.
echo 正在刷新本地DNS缓存...
ipconfig /flushdns >nul

:: ==============================================
:: 结果输出
:: ==============================================
echo.
echo ==============================================
echo 执行完成：成功设置 !success! / %count% 个网卡
echo 主DNS：%dns_primary%
echo 备用DNS：%dns_backup%
echo ==============================================

:: 验证DNS配置
echo.
echo 当前生效DNS：
for %%i in (%adapter_list%) do (
    echo [%%~i]
    netsh interface ipv4 show dns "%%~i" | findstr /c:"服务器地址"
)

echo.
pause