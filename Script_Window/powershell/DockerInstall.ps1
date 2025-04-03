function Get-CommandExists($commandName)
{
    try
    {
        $null = Get-Command -Name $commandName -ErrorAction Stop
        return $true
    }
    catch
    {
        return $false
    }
}

# 测试是否是管理员
function Test-Admin
{
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 管理员权限打开此脚本
function Get-Admin
{
    if (-not (Test-Admin))
    {
        Write-Host "当前未以管理员权限运行，正在尝试以管理员权限重新启动脚本..." -ForegroundColor Yellow

        # 获取当前脚本的完整路径
        # 获取当前脚本路径
        $scriptPath = $PSCommandPath

        # 获取传递给脚本的参数
        $argsString = ""

        # 使用 Start-Process 以管理员权限重新启动脚本，并传递参数
        #  Start-Process 进程行为
        #当使用 Start-Process 以管理员权限 (-Verb RunAs) 启动新进程时：
        #原来的 PowerShell 进程不会等待新进程完成，而是会继续执行或直接退出（如果 exit 被调用）。
        #新的进程是独立的，不会受原进程的生命周期影响，因此不会因为原进程退出而自动终止。
        #如果需要传递参数，必须通过 -ArgumentList 明确传递。
        #        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $scriptArgs"
        if (Get-CommandExists pwsh)
        {
            Start-Process pwsh.exe -Verb RunAs -ArgumentList "-File `"$scriptPath`" $argsString"
        }
        else
        {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$scriptPath`" $argsString"
        }
        # 退出当前实例
        exit
    }
}

function ConvertTo_Hashtable
{
    param (
        $InputObject
    )
    if ($null -eq $InputObject)
    {
        return $null
    }

    # 如果输入已经是字典类型 或者 字符串对象，则直接返回
    if ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [string])
    {
        return $InputObject
    }

    # 如果输入是数组或集合，则递归处理每个元素 数组、列表、哈希表等可枚举对象
    if ($InputObject -is [System.Collections.IEnumerable] )
    {
        return ,@($InputObject | ForEach-Object { ConvertTo_Hashtable -InputObject $_ })
    }

    # 如果输入是 PSCustomObject 或其他对象，转换为哈希表
    if ($InputObject -is [System.Management.Automation.PSCustomObject])
    {
        $hashTable = @{ }
        foreach ($property in $InputObject.PSObject.Properties)
        {
            $hashTable[$property.Name] = ConvertTo_Hashtable -InputObject $property.Value
        }
        return $hashTable
    }

    # 如果输入是普通值（如字符串、数字等），直接返回
    return $InputObject
}

function Get_JSON_TO_Hashtable($Url)
{
    # Invoke-RestMethod 是专门用于处理 REST API 的命令，可以直接将 JSON 数据解析为 PowerShell 对象.
    # 如果你只需要原始的 JSON 字符串，可以改用  Invoke-WebRequest
    $response = Invoke-RestMethod -Uri $Url
    $hash = @{ }
    if ($null -eq $response)
    {
        return $hash
    }
    $hash = ConvertTo_Hashtable -InputObject $response
    return $hash
}

# 检测 Windows 系统是否满足 Docker 安装要求
function Check-WindowsVersion
{
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $caption = $os.Caption
    $version = [Version]$os.Version

    Write-Host "操作系统: $caption"
    Write-Host "版本: $($version.ToString() )"

    # Docker Desktop 至少需要 Windows 10 或更高版本
    if ($version.Major -lt 10)
    {
        Write-Host "错误: 不支持的操作系统版本。Docker Desktop 需要 Windows 10 或更高版本。" -ForegroundColor Red
        return $false
    }
    return $true
}

function Check-SystemArchitecture
{
    $architecture = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemType

    Write-Host "系统架构: $architecture"

    if ($architecture -notmatch "x64")
    {
        Write-Host "错误: 不支持的系统架构。Docker Desktop 需要 64 位系统。" -ForegroundColor Red
        return $false
    }

    return $true
}

function Install-Docker
{
    # 获取管理员权限
    Get-Admin

    if ((-not $( Check-WindowsVersion )) -or (-not $( Check-SystemArchitecture )))
    {
        exit 0
    }

    # 检查是否已启用 WSL 和 Hyper-V 功能
    function Test-WindowsFeature
    {
        param (
            [string]$FeatureName
        )
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        return ($feature.State -eq "Enabled")
    }

    # 检查 WSL 是否已启用
    if (-not (Test-WindowsFeature -FeatureName "Microsoft-Windows-Subsystem-Linux"))
    {
        Write-Host "正在启用 WSL 功能..." -ForegroundColor Green
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    }
    else
    {
        Write-Host "WSL 功能已启用，跳过此步骤。" -ForegroundColor Yellow
    }

    # 检查虚拟机平台是否已启用
    if (-not (Test-WindowsFeature -FeatureName "VirtualMachinePlatform"))
    {
        Write-Host "正在启用虚拟机平台功能..." -ForegroundColor Green
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    }
    else
    {
        Write-Host "虚拟机平台功能已启用，跳过此步骤。" -ForegroundColor Yellow
    }

    # 设置 WSL 2 为默认版本
    Write-Host "正在设置 WSL 2 为默认版本..." -ForegroundColor Green
    wsl --set-default-version 2

    # 下载并安装 Docker Desktop
    $dockerInstallerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    # 本地下载地址
    $dockerInstallerUrl = "http://172.16.0.227:84/docker/Docker%20Desktop%20Installer.exe"
    $dockerInstallerPath = "$env:TEMP\DockerDesktopInstaller.exe"

    Write-Host "正在下载 Docker Desktop 安装程序..." -ForegroundColor Green
    Invoke-WebRequest -Uri $dockerInstallerUrl -OutFile $dockerInstallerPath

    Write-Host "正在安装 Docker Desktop..." -ForegroundColor Green

    $installationDir = "D:\docker"
    $containerDataRoot = "$installationDir\container"
    $wslDataRoot = "$installationDir\wsl"
    if (-not $( Test-Path -Path $installationDir ))
    {
        #  嵌套创建文件夹
        New-Item -Path $installationDir -ItemType Directory
    }
    if (-not $( Test-Path -Path $containerDataRoot ))
    {
        #  嵌套创建文件夹
        New-Item -Path $containerDataRoot -ItemType Directory
    }
    if (-not $( Test-Path -Path $wslDataRoot ))
    {
        #  嵌套创建文件夹
        New-Item -Path $wslDataRoot -ItemType Directory
    }
    Start-Process -FilePath $dockerInstallerPath -Args @("install --always-run-service --installation-dir=$installationDir --windows-containers-default-data-root=$containerDataRoot --wsl-default-data-root=$wslDataRoot") -Wait

    Write-Host "Docker Desktop 安装完成！" -ForegroundColor Green

    # 清理安装文件
    Remove-Item -Path $dockerInstallerPath -Force
}

# TODO
#  问题1 ：读取数据数据有问题，数组只有一个元素读取的原始数据不是数组
function config()
{
    #  配置conifg文件
    $config_file = "$env:USERPROFILE\.docker\config.json"
    $remote_config_file = "http://172.16.0.227:84/docker/config.json"
    #        判断文件是否存在
    if (-not $( Test-Path -Path $config_file ))
    {
        New-Item -Path $config_file -ItemType File
    }
    # 读取本地的配置数据
    $localConfigData = Get-Content -Path $config_file -Raw
    $temp = $true
    if ($null -ne $localConfigData)
    {
        $localConfigData = $localConfigData | ConvertFrom-Json
        $localConfigData = ConvertTo_Hashtable -InputObject $localConfigData
        if ($localConfigData.ContainsKey("auths") -and $localConfigData.auths.ContainsKey("172.16.0.197:8083"))
        {
            $temp = $false
        }
    }
    if ($temp)
    {
        $configData = Get_JSON_TO_Hashtable($remote_config_file)
        Write-Host $($configData | ConvertTo-Json -Depth 100)
        $configData | ConvertTo-Json -Depth 100 | Set-Content -Path $config_file
    }

    # 配置daemon.json文件
    $daemon_file = "$env:USERPROFILE\.docker\daemon.json"
    $remote_daemon_file = "http://172.16.0.227:84/docker/daemon.json"
    if (-not $( Test-Path -Path $daemon_file ))
    {
        New-Item -Path $daemon_file -ItemType File
    }

    $localConfigData = Get-Content -Path $daemon_file -Raw
    $temp = $true
    if ($null -ne $localConfigData)
    {
        $localConfigData = $localConfigData | ConvertFrom-Json
        $localConfigData = ConvertTo_Hashtable -InputObject $localConfigData
        if ($localConfigData.ContainsKey("insecure-registries") -and ("172.16.0.197:8083" -in $localConfigData["insecure-registries"]) -and $localConfigData.ContainsKey("registry-mirrors") -and "http://172.16.0.197:8083" -in $localConfigData["registry-mirrors"])
        {
            $temp = $false
        }
    }
    if ($temp)
    {
        $configData = Get_JSON_TO_Hashtable($remote_daemon_file)
        $configData | ConvertTo-Json -Depth 100 | Set-Content -Path $daemon_file
    }
}

config
Pause