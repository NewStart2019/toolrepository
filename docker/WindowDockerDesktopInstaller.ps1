<#
    Docker Desktop Installer.exe 软件包安装，至少版本在 4.xx以上
    1、手动下载地址：https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe?utm_source=docker&utm_medium=webreferral&utm_campaign=dd-smartbutton&utm_location=module&_gl=1*5gf36b*_gcl_au*MTY1Mzg3MTIwMy4xNzYxMjY3NjUz*_ga*MTI2OTI5NzQxOS4xNzYxMjY3NjUz*_ga_XJWPQMJYHQ*czE3NjEyNjc2NTMkbzEkZzEkdDE3NjEyNjc4MjgkajIxJGwwJGgw
    2、此脚本优势：手动指定安装的位置
#>
cd $env:USERPROFILE\Desktop
# "Docker Desktop Installer.exe" 文件是否存在
if (Test-Path "Docker Desktop Installer.exe") {
    Rename-Item -Path "Docker Desktop Installer.exe" -NewName "DockerDesktopInstaller.exe"
}
# DockerDesktopInstaller.exe 文件不存在则报错
if (!(Test-Path "DockerDesktopInstaller.exe")) {
    Write-Host "Docker Desktop Installer.exe 文件不存在"
    exit 1
}
$installationDir = "D:\docker"
$containerDataRoot = "$installationDir\container"
$wslDataRoot = "$installationDir\wsl"
.\DockerDesktopInstaller.exe install --always-run-service --installation-dir=$installationDir --windows-containers-default-data-root=$containerDataRoot --wsl-default-data-root=$wslDataRoot
