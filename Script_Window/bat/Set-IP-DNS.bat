@echo off
:: 强制切换控制台为GBK编码，解决不同系统代码页不一致导致的乱码
>nul chcp 936
setlocal enabledelayedexpansion

:: ==============================================
:: 固定配置参数
:: ==============================================
set "mask=255.255.255.0"
set "gateway=172.16.0.1"
set "dns_primary=172.16.0.128"
set "dns_backup=114.114.114.114"
set "keyword=Realtek"
set "network_prefix=172.16.0"

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
:: 第一步：查找 Realtek 硬件网卡
:: ==============================================
echo.
echo ============== 网卡检测 ==============
echo 正在查找硬件名称包含 %keyword% 的已启用网卡...

set /a count=0
set "adapter_list="

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
    echo ========================================
    pause
    exit /b 1
)
echo 共检测到 %count% 个符合条件的网卡，将统一配置
echo ========================================

:: ==============================================
:: 第二步：交互输入IP并校验合法性
:: ==============================================
:input_ip
echo.
set "input_ip="
set /p "input_ip=请输入静态IP地址（格式：%network_prefix%.x，范围2-254）："

:: 校验非空
if "%input_ip%"=="" (
    echo 输入不能为空，请重新输入！
    goto input_ip
)

:: 拆分IP为4段并校验格式
set "ip_valid=1"
for /f "tokens=1-4 delims=." %%a in ("%input_ip%") do (
    :: 检查是否刚好4段
    if "%%d"=="" set "ip_valid=0"
    :: 检查每段都是纯数字
    echo %%a| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    echo %%b| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    echo %%c| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    echo %%d| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    :: 检查网段是否匹配
    if not "%%a.%%b.%%c"=="%network_prefix%" set "ip_valid=0"
    :: 检查最后一段范围 2-254
    if %%d lss 2 set "ip_valid=0"
    if %%d gtr 254 set "ip_valid=0"
    :: 排除网关地址冲突
    if %%d equ 1 set "ip_valid=0"
)

if "%ip_valid%"=="0" (
    echo 输入不合法！必须是 %network_prefix%.2 ~ %network_prefix%.254 之间的有效IP
    echo 示例：172.16.0.100
    goto input_ip
)

echo.
echo 已确认IP：%input_ip%，开始配置...
echo ========================================

:: ==============================================
:: 第三步：批量配置网卡（IP+网关+DNS）
:: ==============================================
set /a success_ip=0
set /a success_dns=0

for %%i in (%adapter_list%) do (
    echo.
    echo 正在配置网卡：%%~i

    :: 1. 设置静态IP、掩码、网关
    netsh interface ipv4 set address name=%%~i static %input_ip% %mask% %gateway% >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [1/2] IP/网关配置成功
        set /a success_ip+=1
    ) else (
        echo   [1/2] IP/网关配置失败
    )

    :: 2. 设置主备DNS
    netsh interface ipv4 set dns name=%%~i static %dns_primary% primary >nul 2>&1
    netsh interface ipv4 add dns name=%%~i %dns_backup% index=2 >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [2/2] DNS配置成功
        set /a success_dns+=1
    ) else (
        echo   [2/2] DNS配置失败
    )
)

:: ==============================================
:: 第四步：刷新缓存并输出结果
:: ==============================================
echo.
echo 正在刷新网络缓存...
ipconfig /flushdns >nul
arp -d * >nul

echo.
echo ============== 配置完成 ==============
echo 配置网卡数：%count% 个
echo IP地址：%input_ip%
echo 子网掩码：%mask%
echo 网关：%gateway%
echo 主DNS：%dns_primary%
echo 备用DNS：%dns_backup%
echo ========================================

:: 显示当前生效配置
echo.
echo 当前网卡生效配置：
for %%i in (%adapter_list%) do (
    echo.
    echo 【%%~i】
    netsh interface ipv4 show address "%%~i" | findstr /c:"IP 地址" /c:"子网前缀" /c:"默认网关"
    netsh interface ipv4 show dns "%%~i" | findstr /c:"服务器地址"
)

echo.
pause