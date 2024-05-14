@echo off
chcp 65001

rem 使用 where 命令检测是否安装了 sshpass
where sshpass > nul

rem 检查 where 命令的返回值
if %ERRORLEVEL% equ 0 (
    echo sshpass 已经安装。
    pause
    exit /b
) else (
    echo sshpass 未安装，开始下载并安装...
    rem 在这里添加安装 sshpass 的代码，例如通过 curl 或 wget 下载并安装
)


set doman_name=
set download_url=
set target_ip=172.16.0.227
set github_ip=github.com
rem 执行 ping 命令测试连接目标主机
ping -n 1 %target_ip% > nul && (
    rem 如果ping成功，设置下载地址为目标主机地址
    set download_url=http://%target_ip%:84/sshpass/sshpass.exe
) || (
    rem 如果ping失败，尝试ping github.com
    ping -n 1 %github_ip% > nul && (
        rem 如果ping成功，设置下载地址为GitHub地址
        set download_url=https://github.com/xhcoding/sshpass-win32/releases/download/v1.0.1/sshpass.exe
    ) || (
        rem 如果ping github.com 失败，输出错误信息并退出脚本
        echo %github_ip% 不可达，请手动安装。地址：https://github.com/xhcoding/sshpass-win32/releases/download/v1.0.1/sshpass.exe
        exit /b 1
    )
)

rem 定义下载链接和目标目录
set target_directory=C:\Windows\System32

rem 使用 curl 命令下载文件到目标目录
curl -o "%target_directory%\sshpass.exe" %download_url%

rem 检查下载是否成功
if %ERRORLEVEL% neq 0 (
    echo 文件下载失败。
) else (
    echo 文件下载成功。
)
