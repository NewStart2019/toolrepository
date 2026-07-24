<#
.SYNOPSIS
为名称包含 Realtek 的网卡设置自定义DNS
#>

# ========== 1. 管理员权限检测 ==========
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "检测到未使用管理员权限运行，正在请求提权..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ========== 2. 配置参数 ==========
$dnsPrimary = "172.16.0.197"
$dnsSecondary = "114.114.114.114"
$keyword = "Realtek"

# ========== 3. 查找符合条件的网卡 ==========
Write-Host "`n正在查找名称包含 '$keyword' 的已启用网卡..." -ForegroundColor Cyan
$targetAdapters = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -like "*$keyword*" -and $_.Status -eq "Up"
}

if (-not $targetAdapters) {
    Write-Host "错误：未找到名称包含 '$keyword' 的已启用网卡，请检查网卡名称。" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "找到 $($targetAdapters.Count) 个符合条件的网卡：" -ForegroundColor Green
$targetAdapters | ForEach-Object { Write-Host " - $($_.Name)" }

# ========== 4. 批量设置DNS ==========
Write-Host "`n开始设置DNS..." -ForegroundColor Cyan
$successCount = 0

foreach ($adapter in $targetAdapters) {
    try {
        Set-DnsClientServerAddress -InterfaceAlias $adapter.Name `
            -ServerAddresses @($dnsPrimary, $dnsSecondary) `
            -AddressFamily IPv4 -ErrorAction Stop
        Write-Host "✅ 网卡 [$($adapter.Name)] DNS设置成功" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "❌ 网卡 [$($adapter.Name)] 设置失败：$($_.Exception.Message)" -ForegroundColor Red
    }
}

# ========== 5. 刷新DNS缓存 ==========
Write-Host "`n正在刷新本地DNS缓存..." -ForegroundColor Cyan
ipconfig /flushdns | Out-Null

# ========== 6. 结果输出 ==========
Write-Host "`n=================== 执行完成 ===================" -ForegroundColor Cyan
Write-Host "成功设置：$successCount / $($targetAdapters.Count) 个网卡" -ForegroundColor White
Write-Host "主DNS：$dnsPrimary"
Write-Host "备用DNS：$dnsSecondary"
Write-Host "================================================" -ForegroundColor Cyan

# 验证当前DNS配置
Write-Host "`n当前生效的DNS配置：" -ForegroundColor Yellow
foreach ($adapter in $targetAdapters) {
    $dns = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4
    Write-Host "[$($adapter.Name)]: $($dns.ServerAddresses -join ', ')"
}

pause