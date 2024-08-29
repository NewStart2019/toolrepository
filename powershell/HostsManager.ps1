# HostsManager.ps1
Param (
    [Parameter(Mandatory = $false)]
    [switch]$help, [Parameter(Mandatory = $false)]
    [switch]$interactive
)

$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

$PathFile = if ($PSEdition -eq 'Desktop' -or $IsWindows)
{
    "$( $env:SystemRoot )\System32\drivers\etc\hosts"
}
elseif ($PSEdition -eq 'Core' -and $IsLinux)
{
    '/etc/hosts'
}

# 读取 hosts 文件内容
$hostsContent = Get-Content $PathFile
# 创建一个数组来存储解析后的数据
$global:hostEntries = @()

# 遍历每一行内容
foreach ($line in $hostsContent)
{
    # 使用正则表达式来匹配 IP 地址和域名
    if ($line -match "^(?<!\s)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(.+)$")
    {
        # 提取 IP 地址和域名
        $ipAddress = $Matches[1]
        $domains = $Matches[2].Split(" ")

        # 遍历每个域名
        foreach ($domain in $domains)
        {
            # 创建一个新的 PSObject 实例
            $hostEntry = New-Object PSObject
            $hostEntry | Add-Member NoteProperty IPAddress $ipAddress
            $hostEntry | Add-Member NoteProperty Domain $domain.Trim()

            # 将对象添加到数组中
            $global:hostEntries += $hostEntry
        }
    }
}

function Get-Admin
{
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FormattedDate
{
    [CmdletBinding()]
    Param (
        [string]$Format
    )

    #     获取当前日期和时间
    $currentDateTime = Get-Date

    #     返回格式化的日期和时间字符串
    $currentDateTime.ToString($Format)
}

function Test-IsAdmin
{
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Validate Hostname is exists
function Get-HostnameValidation
{
    Param(
        [String][Parameter(Mandatory = $True)] $Hostname
    )
    foreach ($hostEntry in $global:hostEntries)
    {
        if ($hostEntry.Domain -eq $Hostname.Trim())
        {
            return $true
        }
    }
    return $false
}

function Get-HostnameMapping
{
    Param(
        [String] $Hostname
    )
    if ($null -eq $Hostname -or ($Hostname -eq ""))
    {
        $global:hostEntries | Format-Table -AutoSize
    }
    else
    {
        $global:hostEntries | Where-Object { $_.Domain -eq $Hostname.Trim() } | Format-Table -AutoSize
    }
}

function New-HostnameMapping
{
    Param(
        [String][Parameter(Mandatory = $True)]$Hostname,
        [String] $IPAddress = '127.0.0.1'
    )

    $existed = Get-HostnameValidation -Hostname $Hostname
    if ($existed)
    {
        Write-Host "domain $Hostname already exists, skipping..."
    }
    else
    {
        # 如果不存在，追加到hosts文件
        If (Get-Admin)
        {
            $hostEntry = New-Object PSObject
            $hostEntry | Add-Member NoteProperty IPAddress $IPAddress
            $hostEntry | Add-Member NoteProperty Domain $Hostname.Trim()

            # 将对象添加到数组中
            $global:hostEntries += $hostEntry
            Save-HostsFile
        }
        Else
        {
            Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList "-Command New-HostnameMapping -Hostname $Hostname -IPAddress $IPAddress"
        }
    }
}

function Set-HostnameMapping
{
    Param(
        [String][Parameter(Mandatory = $True)] $Hostname,
        [String] $IPAddress
    )
    $existed = Get-HostnameValidation -Hostname $Hostname
    if ($existed)
    {
        foreach ($hostEntry in $global:hostEntries)
        {
            if ($hostEntry.Domain -eq $Hostname.Trim() -and ($hostEntry.IPAddress -ne $IPAddress))
            {
                $hostEntry.IPAddress = $IPAddress
            }
        }
        Save-HostsFile
    }
    else
    {
        # 如果不存在，追加到hosts文件
        If (Get-Admin)
        {
            $hostEntry = New-Object PSObject
            $hostEntry | Add-Member NoteProperty IPAddress $IPAddress
            $hostEntry | Add-Member NoteProperty Domain $Hostname.Trim()

            # 将对象添加到数组中
            $global:hostEntries += $hostEntry
            Save-HostsFile
        }
        Else
        {
            Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList "-Command New-HostnameMapping -Hostname $Hostname -IPAddress $IPAddress"
        }
    }
}

function Remove-HostnameMapping
{
    Param(
        [String][Parameter(Mandatory = $True)] $Hostname
    )
    If (Get-Admin)
    {
        $global:hostEntries = $global:hostEntries | Where-Object { $_.Domain -notin $Hostname }
        Save-HostsFile
    }
    Else
    {
        Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList "-Command Remove-HostnameMapping -Hostname $Hostname"
    }
}

function Save-HostsFile
{
    $global:hostEntriesText = $global:hostEntries | ForEach-Object {
        "{0,-15} {1}" -f $_.IPAddress, $_.Domain
    }

    # 写入到 hosts 文件
    $hostEntriesText | Out-File -FilePath $PathFile -Encoding ASCII -Force
}

function help
{
    Write-Host "manager local dns mapping"
    $cmd = @()
    $cmd_help = New-Object PSObject
    $cmd_help | Add-Member NoteProperty Command "validate <hostname> <ip>"
    $cmd_help | Add-Member NoteProperty Desc "validate hostname"
    $cmd += $cmd_help

    $cmd_help = New-Object PSObject
    $cmd_help | Add-Member NoteProperty Command "look <hostname>" -Force
    $cmd_help | Add-Member NoteProperty Desc "look hostname mapping" -Force
    $cmd += $cmd_help

    $cmd_help = New-Object PSObject
    $cmd_help | Add-Member NoteProperty Command "add <hostname> <ip>" -Force
    $cmd_help | Add-Member NoteProperty Desc "add hostname mapping" -Force
    $cmd += $cmd_help

    $cmd_help = New-Object PSObject
    $cmd_help | Add-Member NoteProperty Command "update <hostname> <ip>" -Force
    $cmd_help | Add-Member NoteProperty Desc "update hostname mapping" -Force
    $cmd += $cmd_help

    $cmd_help = New-Object PSObject
    $cmd_help | Add-Member NoteProperty Command "rm <hostname>" -Force
    $cmd_help | Add-Member NoteProperty Desc "rm hostname" -Force
    $cmd += $cmd_help

    $cmd_help = New-Object PSObject
    $cmd_help | Add-Member NoteProperty Command "help" -Force
    $cmd_help | Add-Member NoteProperty Desc "show help" -Force
    $cmd += $cmd_help

    $cmd_help = New-Object PSObject
    $cmd_help | Add-Member NoteProperty Command "exit" -Force
    $cmd_help | Add-Member NoteProperty Desc "exit command" -Force
    $cmd += $cmd_help

    $cmd | Format-Table -AutoSize
}

function Is-ValidIPv4
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )

    if ($IPAddress -eq "" -or ($null -eq $IPAddress))
    {
        return $false
    }

    $regexIPv4 = '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    if ($IPAddress -match $regexIPv4)
    {
        return $true
    }
    else
    {
        Write-Host "$IPAddress is not a valid IPv4 address." -ForegroundColor Red
        return $false
    }
}

function Is-ValidDomain
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DomainName
    )
    if ($DomainName -eq "" -or ($null -eq $DomainName))
    {
        return $false
    }
    $regexDomain = '^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
    if ($DomainName -match $regexDomain)
    {
        return $true
    }
    else
    {
        Write-Host "$DomainName is not a valid domain name." -ForegroundColor Red
        return $false
    }
}

$currentDatetime = Get-FormattedDate -Format "yyyy-MM-dd-HH-mm-ss"
Copy-Item -Path $PathFile -Destination "$PathFile-$currentDatetime.bak" -Force

# 添加默认的自定义dns
$devop_zone = "devops.com"
$devop_ip = "172.16.0.197"
$test_zone = "develop.com"
$test_ip = "172.16.0.227"
# 正式系统 zone
$jdjczx_zone = "jdjczx.com"
$svn_ip = "172.16.0.47"
$tool = @(
    @{
        Hostname = "gitlab.$devop_zone"
        IPAddress = $devop_ip
        URL = "gitlab.$devop_zone`:8929"
    }
    @{
        Hostname = "nexus.$devop_zone"
        IPAddress = $devop_ip
        URL = "nexus.$devop_zone`:5001"
    }
    @{
        Hostname = "minio.$devop_zone"
        IPAddress = $devop_ip
        URL = "minio.$devop_zone`:9000"
    }
    @{
        Hostname = "svn.$devop_zone"
        IPAddress = $svn_ip
        URL = "svn.$devop_zone`:7080"
    }
)

$test = @(
    @{
        Hostname = "fjxt.$test_zone"
        IPAddress = $test_ip
        URL = "fjxt.$test_zone`:85"
    }
    @{
        Hostname = "shxt.$test_zone"
        IPAddress = $test_ip
        URL = "shxt.$test_zone`:83"
    }

    @{
        Hostname = "jzqy.$test_zone"
        IPAddress = $test_ip
        URL = "jzqy.$test_zone`:8606"
    }
)

$pro = @(
    @{
        Hostname = "fjxt.$jdjczx_zone"
        IPAddress = "172.16.0.226"
        URL = "fjxt.$jdjczx_zone"
    }
    @{
        Hostname = "shxt.$jdjczx_zone"
        IPAddress = "172.16.0.83"
        URL = "shxt.$jdjczx_zone`:83"
    }
)
if ($interactive)
{
    while ($true)
    {
        $inputValue = Read-Host -Prompt "hosts-manager>"
        $items = $inputValue -split "\s"
        switch ($items[0])
        {
            "help"{
                help
            }
            "exit"{
                exit 0
            }
            "validate" {
                if (Is-ValidDomain -DomainName $items[1])
                {
                    Get-HostnameValidation -Hostname $items[1]
                }
            }
            "look" {
                if ($items.Length -lt 2)
                {
                    Get-HostnameMapping
                }
                else
                {
                    if (Is-ValidDomain -DomainName $items[1])
                    {
                        Get-HostnameMapping -Hostname $items[1]
                    }
                }
            }
            "add" {
                $h = Is-ValidDomain -DomainName $items[1]
                $i = Is-ValidIPv4 -IPAddress $items[2]
                if ($h -and $i)
                {
                    New-HostnameMapping -Hostname $items[1] -IPAddress $items[2]
                }
            }
            "update" {
                $h = Is-ValidDomain -DomainName $items[1]
                $i = Is-ValidIPv4 -IPAddress $items[2]
                if ($h -and $i)
                {
                    Set-HostnameMapping -Hostname $items[1] -IPAddress $items[2]
                }
            }
            "rm" {
                if (Is-ValidDomain -DomainName $items[1])
                {
                    Remove-HostnameMapping -Hostname $items[1]
                }
            }
            "url" {
                Write-Host "devops tool domain list" -ForegroundColor Green
                $hostEntriesText = $tool | ForEach-Object {
                    "{0}`n" -f $_.URL
                }
                Write-Host $hostEntriesText -ForegroundColor Green

                Write-Host "test system domain list" -ForegroundColor Green
                $hostEntriesText = $test | ForEach-Object {
                    "{0}`n" -f $_.URL
                }
                Write-Host $hostEntriesText -ForegroundColor Green

                Write-Host "production system domain list" -ForegroundColor Green
                $hostEntriesText = $pro | ForEach-Object {
                    "{0}`n" -f $_.URL
                }
                Write-Host $hostEntriesText -ForegroundColor Green
            }
            default{
                if (($null -eq $inputValue) -or ($inputValue -eq ""))
                {
                    continue
                }
                & $inputValue
                if (!$?)
                {
                    Write-Host "unknown command"
                }
            }
        }
        $inputValue = $null
    }
}
else
{
    foreach ($item in $tool)
    {
        $flag = $true
        foreach ($hostEntry in $global:hostEntries)
        {
            if ($hostEntry.Domain -eq $item.Hostname.Trim())
            {
                $hostEntry.IPAddress = $item.IPAddress.Trim()
                $flag = $false
            }
        }
        if ($flag)
        {
            $hostEntry = New-Object PSObject
            $hostEntry | Add-Member NoteProperty IPAddress $item.IPAddress.Trim()
            $hostEntry | Add-Member NoteProperty Domain $item.Hostname.Trim()

            $global:hostEntries += $hostEntry
        }
    }

    foreach ($item in $test)
    {
        $flag = $true
        foreach ($hostEntry in $global:hostEntries)
        {
            if ($hostEntry.Domain -eq $item.Hostname.Trim())
            {
                $hostEntry.IPAddress = $item.IPAddress.Trim()
                $flag = $false
            }
        }
        if ($flag)
        {
            $hostEntry = New-Object PSObject
            $hostEntry | Add-Member NoteProperty IPAddress $item.IPAddress.Trim()
            $hostEntry | Add-Member NoteProperty Domain $item.Hostname.Trim()

            $global:hostEntries += $hostEntry
        }
    }

    foreach ($item in $pro)
    {
        $flag = $true
        foreach ($hostEntry in $global:hostEntries)
        {
            if ($hostEntry.Domain -eq $item.Hostname.Trim())
            {
                $hostEntry.IPAddress = $item.IPAddress.Trim()
                $flag = $false
            }
        }
        if ($flag)
        {
            $hostEntry = New-Object PSObject
            $hostEntry | Add-Member NoteProperty IPAddress $item.IPAddress.Trim()
            $hostEntry | Add-Member NoteProperty Domain $item.Hostname.Trim()

            $global:hostEntries += $hostEntry
        }
    }

    Save-HostsFile
    Write-Host "devops tool domain list" -ForegroundColor Green
    $hostEntriesText = $tool | ForEach-Object {
        "{0}`n" -f $_.URL
    }
    Write-Host $hostEntriesText -ForegroundColor Green

    Write-Host "test system domain list" -ForegroundColor Green
    $hostEntriesText = $test | ForEach-Object {
        "{0}`n" -f $_.URL
    }
    Write-Host $hostEntriesText -ForegroundColor Green

    Write-Host "production system domain list" -ForegroundColor Green
    $hostEntriesText = $pro | ForEach-Object {
        "{0}`n" -f $_.URL
    }
    Write-Host $hostEntriesText -ForegroundColor Green

    Pause
}

# 转 exe
#  Invoke-PS2EXE -InputFile HostsManager.ps1 -OutputFile "add-domain.exe"  -iconFile "D:\Java\project\toolrepository\batToExe\deploy.ico"

# Copyright (c) 1993-2009 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
# This file contains the mappings of IP addresses to host names. Each
# entry should be kept on an individual line. The IP address should
# be placed in the first column followed by the corresponding host name.
# The IP address and the host name should be separated by at least one
# space.
#
# Additionally, comments (such as these) may be inserted on individual
# lines or following the machine name denoted by a '#' symbol.
#
# For example:
#
#      102.54.94.97     rhino.acme.com          # source server
#       38.25.63.10     x.acme.com              # x client host

# localhost name resolution is handled within DNS itself.
#	127.0.0.1       localhost
#	::1             localhost

#172.16.0.227    test.cqjdjc.com
#127.0.0.1         ieonline.Microsoft.com
#127.0.0.1         example.com
#127.0.0.1         ieonline.Microsoft.com
#127.0.0.1        abc.cn
#172.16.0.227   test.cqjdjc.com
#172.16.0.170   host.docker.internal
#172.16.0.170   gateway.docker.internal
#127.0.0.1        kubernetes.docker.internal
