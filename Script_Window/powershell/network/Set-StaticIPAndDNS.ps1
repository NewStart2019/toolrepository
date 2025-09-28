<#
.SYNOPSIS
设置Windows系统的静态IP地址和DNS服务器配置

.DESCRIPTION
此脚本用于将指定网络适配器的IP地址和DNS服务器设置为静态配置，
替代自动获取(DHCP)的方式。适用于需要固定局域网IP的场景。
#>

# 正确的子网掩码到前缀长度的转换函数
function Convert-SubnetMaskToPrefixLength
{
    param(
        [string]$SubnetMask
    )

    $octets = $SubnetMask -split '\.' | ForEach-Object { [byte]$_ }
    $prefixLength = 0

    foreach ($octet in $octets)
    {
        while ($octet -band 128)
        {
            $prefixLength++
            $octet = $octet -shl 1
        }
        if ($octet -ne 0)
        {
            throw "无效的子网掩码: $SubnetMask"
        }
    }

    return $prefixLength
}

Function Set-StaticIP
{
    # 配置参数 - 根据你的网络环境修改以下值
    # 网络适配器名称，通常是"以太网"或"WLAN"
    $adapterName = "以太网"
    # 你想要设置的静态IP地址
    $ipAddress = "172.16.0.170"
    # 子网掩码
    $subnetMask = "255.255.255.0"
    # 默认网关(路由器IP)
    $defaultGateway = "172.16.0.1"
    # 首选DNS服务器
    $primaryDns = "114.114.114.114"
    # 备用DNS服务器
    $secondaryDns = "8.8.8.8"

    # 检查管理员权限
    #    Requires -RunAsAdministrator

    try
    {
        # 获取网络适配器
        $adapter = Get-NetAdapter -Name $adapterName -ErrorAction Stop

        Write-Host "正在为适配器 '$adapterName' 配置静态IP和DNS..." -ForegroundColor Cyan

        # 计算子网前缀长度 (例如 255.255.255.0 对应 24)
        $prefixLength = Convert-SubnetMaskToPrefixLength -SubnetMask $subnetMask
        Write-Host "子网掩码 $subnetMask 对应的前缀长度为: $prefixLength" -ForegroundColor Yellow

        # 先清除现有IP配置
        Write-Host "清除现有IP配置..." -ForegroundColor Yellow
        $existingIp = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($existingIp)
        {
            Remove-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -Confirm:$false -ErrorAction Stop
        }

        # 清除现有默认网关
        Write-Host "清除现有默认网关..." -ForegroundColor Yellow
        $existingGateway = Get-NetRoute -InterfaceAlias $adapterName -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' }
        if ($existingGateway)
        {
            Remove-NetRoute -InterfaceAlias $adapterName -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction Stop
        }

        # 配置新的IP地址和默认网关
        Write-Host "应用新的IP配置..." -ForegroundColor Yellow
        New-NetIPAddress `
        -InterfaceAlias $adapterName `
        -IPAddress $ipAddress `
        -PrefixLength $prefixLength `
        -DefaultGateway $defaultGateway `
        -ErrorAction Stop

        # 配置DNS服务器
        Write-Host "配置DNS服务器..." -ForegroundColor Yellow
        Set-DnsClientServerAddress `
        -InterfaceAlias $adapterName `
        -ServerAddresses @($primaryDns, $secondaryDns) `
        -ErrorAction Stop

        Write-Host "`n配置成功！当前网络配置：" -ForegroundColor Green

        # 显示当前IP配置
        Get-NetIPAddress -InterfaceAlias $adapterName | Where-Object AddressFamily -eq IPv4 | Format-List IPAddress, SubnetMask, InterfaceAlias

        # 显示当前DNS配置
        Write-Host "`nDNS服务器：" -ForegroundColor Cyan
        Get-DnsClientServerAddress -InterfaceAlias $adapterName | Select-Object -ExpandProperty ServerAddresses
    }
    catch
    {
        Write-Host "`n配置失败: $_" -ForegroundColor Red
    }

}

function Set-DynamicIP
{
    # 以管理员身份运行
    Set-NetIPInterface -InterfaceAlias "以太网" -Dhcp Enabled
    Set-DnsClientServerAddress -InterfaceAlias "以太网" -ResetServerAddresses
}