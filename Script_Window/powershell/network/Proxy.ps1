<#
.SYNOPSIS
    查看 Windows 当前的系统代理状态（WinINet + WinHTTP）
.DESCRIPTION
    - 显示系统代理是否启用
    - 显示代理服务器地址和端口（例如 Clash: 127.0.0.1:7890）
    - 显示绕过代理的地址列表
    - 显示 WinHTTP 代理配置（用于 PowerShell、Windows Update 等）
#>
function Get-WinProxy {
    Write-Host "==== 🛰 当前系统代理状态 (Clash / 系统代理) ====" -ForegroundColor Cyan
    Write-Host ""

    # --- WinINet (应用层代理) ---
    $inetKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $inet = Get-ItemProperty -Path $inetKey

    Write-Host "【WinINet 用户代理设置-普通应用、浏览器】" -ForegroundColor Yellow
    Write-Host "启用状态   :" ($inet.ProxyEnable -eq 1 ? "✅ 已启用" : "❌ 未启用")
    Write-Host "代理服务器 :" ($inet.ProxyServer -ne $null ? $inet.ProxyServer : "(未设置)")
    Write-Host "排除列表   :" ($inet.ProxyOverride -ne $null ? $inet.ProxyOverride : "(无)")
    Write-Host ""

    # --- WinHTTP (系统层代理) ---
    Write-Host "【WinHTTP 系统代理设置-系统服务、CLI】" -ForegroundColor Yellow
    $winhttp = netsh winhttp show proxy | Out-String
    Write-Host $winhttp

    # --- 判断是否可能为 Clash 代理 ---
    if ($inet.ProxyServer -match "127\.0\.0\.1|localhost") {
        Write-Host "检测到本地代理服务 (可能为 Clash / V2Ray / NekoRay 等)" -ForegroundColor Green
        if ($inet.ProxyServer -match "7890|7891|:25555") {
            Write-Host "✅ 端口匹配 Clash 默认端口 (7890/7891/25555)" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠️ 当前未检测到本地代理服务。" -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "============================================="
    Write-Host "提示："
    Write-Host " - WinINet 控制浏览器、Electron 应用等"
    Write-Host " - WinHTTP 控制系统服务、PowerShell、Windows Update"
    Write-Host " - Clash 的系统代理仅修改 WinINet 注册表"
    Write-Host " - 若需让 PowerShell 也走代理，请执行："
    Write-Host "   netsh winhttp import proxy source=ie" -ForegroundColor Cyan
    Write-Host "    source=ie 参数表示 源 是 Internet Explorer 或系统代理设置" -ForegroundColor Green
    Write-Host "============================================="
}

function Set-WinProxy {
    param(
        [string]$Server = "127.0.0.1:7890",
        [switch]$Both
    )
    Write-Host "设置 WinINet 代理为 $Server ..." -ForegroundColor Yellow
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 1
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value $Server
    rundll32 inetcpl.cpl,ClearMyTracksByProcess 8

    if ($Both) {
        Write-Host "同步设置 WinHTTP 代理 ..." -ForegroundColor Yellow
        netsh winhttp set proxy $Server
    }
    Write-Host "✅ 代理设置完成" -ForegroundColor Green
}

function Import-WinHTTPFromIE {
    Write-Host "同步 IE/系统代理设置到 WinHTTP ..." -ForegroundColor Yellow
    netsh winhttp import proxy source=ie
    Write-Host "✅ 已同步完成" -ForegroundColor Green
}

function Reset-WinProxy {
    Write-Host "清除 WinINet 代理 ..." -ForegroundColor Yellow
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -ErrorAction SilentlyContinue

    Write-Host "清除 WinHTTP 代理 ..." -ForegroundColor Yellow
    netsh winhttp reset proxy
    Write-Host "✅ 已重置所有代理设置" -ForegroundColor Green
}

function Get-Help {
    Write-Host "Usage: Get-WinProxy  # 查看代理状态" -ForegroundColor Cyan
    Write-Host "Usage: Set-WinProxy -Server <代理服务器地址> [-Both] # 同时设置两个层级" -ForegroundColor Cyan
    Write-Host "Usage: Import-WinHTTPFromIE # 同步代理配置" -ForegroundColor Cyan
    Write-Host "Usage: Reset-WinProxy # 清除所有代理设置" -ForegroundColor Cyan
}

