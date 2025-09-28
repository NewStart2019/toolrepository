@echo off
chcp 65001 > nul

:: 设置变量（注意：等号前后不能有空格）
set ip=172.16.0.175
set password=infocenter2024
set user=administrator

ping -n 1 %ip% | findstr "TTL" >nul
if %errorlevel% neq 0 (
    echo 主机 %ip% 不可达。
    exit /b 1
)

echo 正在清理旧连接...
:: 删除指定凭据（忽略是否不存在）
cmdkey /delete:\\%ip% >nul 2>&1
:: 断开可能存在的 IPC$ 和 ShareDirectory 连接（忽略错误）
net use \\%ip%\IPC$ /delete /y >nul 2>&1

echo 正在连接共享目录...
net use \\%ip%\ShareDirectory %password% /user:%ip%\%user% /persistent:yes

:: 检查最后一条命令的执行结果
if %errorlevel% == 0 (
    echo 共享连接成功
) else (
    echo 共享连接失败。错误代码：%errorlevel%
    echo 可能原因：
    echo   1. 用户名或密码错误
    echo   2. 账户被锁定或禁用
    echo   3. 共享路径不存在或权限不足
    echo   4. 防火墙阻止 445 端口
)

pause