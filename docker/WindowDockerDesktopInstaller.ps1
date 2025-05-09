<#
    Docker Desktop Installer.exe 软件包安装，至少版本在 4.xx以上
    1、手动下载地址：https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
    2、此脚本优势：手动指定安装的位置
#>
cd $env:USERPROFILE\Desktop
Rename-Item -Path "Docker Desktop Installer.exe" -NewName "DockerDesktopInstaller.exe"
$installationDir = "D:\docker"
$containerDataRoot = "$installationDir\container"
$wslDataRoot = "$installationDir\wsl"
.\DockerDesktopInstaller.exe install --always-run-service --installation-dir=$installationDir --windows-containers-default-data-root=$containerDataRoot --wsl-default-data-root=$wslDataRoot
