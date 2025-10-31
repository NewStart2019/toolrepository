<#
.SYNOPSIS
在Windows 11上创建并启动Wi-Fi热点

.DESCRIPTION
此脚本用于在Windows 11系统上配置并启动一个Wi-Fi热点，
允许其他设备通过该热点连接到网络。
#>

# 配置参数 - 根据需要修改以下值
$hotspotName = "MyWindowsHotspot"  # 热点名称
$hotspotPassword = "StrongPassword123"  # 热点密码（至少8个字符）
$interfaceName = "WLAN"  # 无线网卡名称，通常是"WLAN"

# 检查管理员权限
#Requires -RunAsAdministrator

try {
    # 检查是否已安装必要的组件
    Write-Host "检查Wi-Fi热点支持..." -ForegroundColor Cyan
    $checkResult = netsh wlan show drivers | Select-String "支持的承载网络"

    if (-not $checkResult -or $checkResult.ToString() -notmatch "是") {
        throw "您的无线网卡不支持创建热点功能"
    }

    # 检查并停止已存在的热点
    Write-Host "检查并停止已存在的热点..." -ForegroundColor Cyan
    netsh wlan stop hostednetwork | Out-Null

    # 配置新的热点
    Write-Host "配置Wi-Fi热点 '$hotspotName'..." -ForegroundColor Cyan
    $configResult = netsh wlan set hostednetwork mode=allow ssid=$hotspotName key=$hotspotPassword

    if ($configResult -match "成功") {
        Write-Host "热点配置成功" -ForegroundColor Green
    }
    else {
        throw "热点配置失败: $configResult"
    }

    # 启动热点
    Write-Host "启动Wi-Fi热点..." -ForegroundColor Cyan
    $startResult = netsh wlan start hostednetwork

    if ($startResult -match "已启动") {
        Write-Host "`nWi-Fi热点启动成功！" -ForegroundColor Green
        Write-Host "热点名称: $hotspotName" -ForegroundColor Cyan
        Write-Host "热点密码: $hotspotPassword" -ForegroundColor Cyan

        # 显示当前热点状态
        Write-Host "`n热点状态：" -ForegroundColor Yellow
        netsh wlan show hostednetwork | Select-String "状态|SSID|信道|客户端"
    }
    else {
        throw "热点启动失败: $startResult"
    }

    # 提示网络共享设置
    Write-Host "`n请确保已正确设置网络共享：" -ForegroundColor Yellow
    Write-Host "1. 打开控制面板 -> 网络和Internet -> 网络连接"
    Write-Host "2. 右键点击您当前连接互联网的网络适配器"
    Write-Host "3. 选择'属性' -> '共享'选项卡"
    Write-Host "4. 勾选'允许其他网络用户通过此计算机的Internet连接来连接'"
    Write-Host "5. 在下拉菜单中选择您的热点适配器（通常名为'本地连接* XXX'）"
}
catch {
    Write-Host "`n操作失败: $_" -ForegroundColor Red
    Write-Host "尝试解决方法：" -ForegroundColor Yellow
    Write-Host "1. 确保无线网卡驱动已更新"
    Write-Host "2. 检查是否有其他程序占用Wi-Fi功能"
    Write-Host "3. 重启电脑后再试"
}