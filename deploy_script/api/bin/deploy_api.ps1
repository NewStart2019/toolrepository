<#
    前提条件本地安装 docker、docker-compose
    实现目标：
       1. 本地打包最新的 jar包 ，右侧gradle插件 → stc-jtjc → Tasks → build → bootJar
       2. 构建 docker 镜像, 永久配置登录信息 在用户目录下/.docker/config 添加
       3. 推送镜像到镜像仓库172.16.0.197:8083。需要提前登录镜像仓库。
       4. 目标服务器启动 docker 容器
       5. 用户目录路径下有项目自动化部署的配置和日志文件deploy.json
    TODO docker服务器启动没用，必须启动docker-desktop，可能是缺少关联的启动如wsl等检查。所以docker管理需要改进
#>
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'pro')]
    [string]$target = 'dev',

    [Parameter(Mandatory = $false)]
    [ValidateSet('list-server', 'jar', 'image', 'deploy')]
    [string]$operate = "deploy",

    [Parameter(Mandatory = $false)]
    [switch]$help,

    [Parameter(Mandatory = $false)]
    [switch]$interactive
)
chcp 65001 > $null
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

#region script_variables

# 每次执行脚本前主动加载环境变量
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$ErrorActionPreference = "Stop"
# 记录命令执行的位置
$current_path = $PSScriptRoot
# 项目名称
$PROJECT_NAME = "stcjc"
$PROJECT_PORT = 8605
$DOCKER_REPOSITORY = "172.16.0.197:8083"
$PROJECT_VERSION = $null
$target_file = $null
$JAR_FILE = $null
$IMAGE_NAME = "csatc/$PROJECT_NAME"
$IMAGE_FULL_NAME = $null
$CONTAINER_NAME = $PROJECT_NAME

# 当前用户ip
$currentIP = $null
# 当前分支
$current_branch = git symbolic-ref --short HEAD
$currentCachedData = $null
$username = $null
$ip = $null
$password = $null
$port = 22
$operator = $null

#endregion

#region common_functions

function Test-NetworkConnectivity
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Target
    )
    return Test-Connection -ComputerName $Target -Count 1 -Quiet
}

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

# 管理员权限打开脚本
# 注意：
#   1、这里的参数处理在不同的脚本中的处理方式是不同的，【注意修改】
#   2、Start-Process 启动的是一个与原来进程没有任何关联的进程，所以它不会继承任何环境变量，包括 PATH 变量
#   3、原来的进程直接离开
function Get-Administror
{
    if (-not (Test-Admin))
    {
        Write-Host "当前未以管理员权限运行，正在尝试以管理员权限重新启动脚本..." -ForegroundColor Yellow
        # 参数处理
        $scriptArgs = "-target $target -operate $operate"
        # 拼接全局传入的参数 Param
        if ($help)
        {
            $scriptArgs += " -help"
        }
        if ($interactive)
        {
            $scriptArgs += " -interactive"
        }

        # 获取当前脚本的完整路径
        # 获取当前脚本路径
        $scriptPath = $PSCommandPath
        # Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $scriptArgs"
        if (Get-CommandExists pwsh)
        {
            Start-Process pwsh.exe -Verb RunAs -ArgumentList "-File `"$scriptPath`" $scriptArgs"
        }
        else
        {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$scriptPath`" $scriptArgs"
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
    if ($InputObject -is [System.Collections.IEnumerable])
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

# 获取指定前缀的 IP 地址
function Get-IPAddress($prefix)
{
    # 获取所有有效的 IPv4 地址
    $ipv4Addresses = Get-CimInstance -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | Select-Object -ExpandProperty IPAddress
    # 筛选出以指定前缀开头的 IP 地址
    $filteredIpAddresses = $ipv4Addresses | Where-Object { $_ -like "$prefix*" }
    return $filteredIpAddresses
}

# 获取指定格式的日期
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

# 指定字体输出颜色
function Write-ColoredText
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White')]
        [string]$Color = 'Green'
    )

    # 获取当前的前景色
    $originalForegroundColor = $host.UI.RawUI.ForegroundColor

    try
    {
        # 设置新的前景色
        $host.UI.RawUI.ForegroundColor = $Color

        # 使用 Write-Host 输出彩色文本
        Write-Host $Text
    }
    finally
    {
        # 恢复原始的前景色
        $host.UI.RawUI.ForegroundColor = $originalForegroundColor
    }
}

function Get-CurrentVersion($file)
{
    # 读取文件的第一行
    $firstLine = Get-Content -Path $file -First 1
    # 去除首尾的空白字符
    $trimmedVersion = $firstLine.Trim()
    # 输出结果
    return $trimmedVersion
}

function Remove-None-Images
{
    # 列出所有标签为 <none> 的镜像
    $noneImages = docker images --filter "dangling=true" --format "{{.ID}}"

    # 遍历并删除这些镜像
    foreach ($imageId in $noneImages)
    {
        docker rmi -f $imageId
    }
}

function Get-InputPasspard
{
    # 接收用户输入密码
    $securePassword = Read-Host -Prompt "Please input password" -AsSecureString
    # 将安全字符串转换为明文（可选，仅用于演示）
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    return $plainPassword
}

function Get-Input
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string]$Info,

        [Parameter(Mandatory = $false)]
        [string]$Value
    )

    if (-not $interactive)
    {
        return $Value
    }
    else
    {
        $inputValue = Read-Host -Prompt "$Info"
        if ( [string]::IsNullOrEmpty($inputValue))
        {
            return $Value
        }
        else
        {
            return $inputValue
        }
    }
}

function Get-Username
{
    $usernameKey = "username"
    if ( $cachedManagement.cachedData.ContainsKey($usernameKey))
    {
        return $cachedManagement.cachedData[$usernameKey]
    }
    $temp = $null
    $userList = @("黄紫阳", "王刚", "何小风", "詹啟华", "钱坤", "袁盛辉", "管祖睿", "杨彪")
    while ($temp -notin $userList)
    {
        $temp = Read-Host -Prompt "请输入您的姓名: $( $userList -join ', ' )"
        $temp = $temp.Trim()
    }
    $cachedManagement.cachedData[$usernameKey] = $temp
    return $temp
}

function Exit_Operate($status)
{
    if ($null -eq $staus)
    {
        $status = 0
    }
    Set-Location $current_path
    exit $status
}

#endregion

#region tool_class

# 导入加密解密类
class SecretClass
{
    [byte[]]$key
    [byte[]]$iv

    SecretClass()
    {
        # 必须是16, 24, 或32字节长以匹配AES-128, AES-192, 或 AES-256
        $this.key = [System.Text.Encoding]::UTF8.GetBytes("jracf88vCEBeRNdtNr3SnPkCrzepBcjt")
        # 必须是16字节长
        $this.iv = [System.Text.Encoding]::UTF8.GetBytes("aDKHDA2uAdwdetWz")
    }

    [string]
    EncryptString([string]$plainText)
    {
        # 创建 AES 算法实例
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $this.key
        $aes.IV = $this.is

        # 创建加密器
        $encryptor = $aes.CreateEncryptor($aes.Key, $aes.IV)

        # 转换字符串为字节数组
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plainText)

        # 使用内存流和加密转换器加密数据
        $msEncrypt = New-Object System.IO.MemoryStream
        $csEncrypt = New-Object System.Security.Cryptography.CryptoStream($msEncrypt, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $csEncrypt.Write($plainBytes, 0, $plainBytes.Length)
        $csEncrypt.FlushFinalBlock()

        # 获取加密后的字节数组并转换为 Base64 字符串
        $cipherBytes = $msEncrypt.ToArray()
        return [System.Convert]::ToBase64String($cipherBytes)
    }

    [string]
    DecryptString([string]$cipherText)
    {
        # 创建 AES 算法实例
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $this.key
        $aes.IV = $this.iv

        # 创建解密器
        $decryptor = $aes.CreateDecryptor($aes.Key, $aes.IV)

        # 将 Base64 编码的字符串转换回字节数组
        $cipherBytes = [System.Convert]::FromBase64String($cipherText)

        # 使用内存流和解密转换器解密数据
        $msDecrypt = New-Object System.IO.MemoryStream
        $csDecrypt = New-Object System.Security.Cryptography.CryptoStream($msDecrypt, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $csDecrypt.Write($cipherBytes, 0, $cipherBytes.Length)
        $csDecrypt.FlushFinalBlock()

        # 将解密后的字节数组转换回字符串
        $decryptedBytes = $msDecrypt.ToArray()
        return [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
    }
}
$secretClass = [SecretClass]::new()

# sshpass管理类
class SshpassClass
{
    # 存放文件位置
    $target_directory = "C:\Windows\System32"
    $command_name = "sshpass"

    [Void]
    install()
    {
        $temp = Get-CommandExists -commandName $this.command_name
        if ($temp)
        {
            Write-ColoredText -Text "sshpass命令已经安装."
            return
        }
        else
        {
            Write-ColoredText -Text "sshpass未安装，开始下载并安装..."
        }
        # 如果不是管理员权限，则重新以管理员权限启动脚本
        Get-Administror

        $download_url = $null
        $target_ip = "172.16.0.227"
        $github_ip = "github.com"

        # 执行 ping 命令测试连接目标主机
        $temp = Test-NetworkConnectivity -Target $target_ip
        if ($temp)
        {
            $download_url = "http://$( $target_ip ):84/sshpass/sshpass.exe"
        }
        else
        {
            $temp = Test-NetworkConnectivity -Target $github_ip
            if ($temp)
            {
                $download_url = "https://github.com/xhcoding/sshpass-win32/releases/download/v1.0.3/sshpass.exe"
            }
            else
            {
                Write-ColoredText -Text "目标服务器和github.com均不可达，请手动安装.地址：https://github.com/xhcoding/sshpass-win32/releases/download/v1.0.3/sshpass.exe" -Color "Red"
                exit 1
            }
        }

        # 使用 curl 命令下载文件到目标目录
        Write-ColoredText -Text "开始下载$download_url..."
        Invoke-WebRequest -Uri $download_url -OutFile "$( $this.target_directory )\sshpass.exe"

        if ($?)
        {
            Write-ColoredText -Text "sshpass安装成功."
        }
        else
        {
            Write-ColoredText -Text "sshpass安装失败."
            exit 1
        }
    }

    [Void]
    uninstall()
    {
        $temp = Get-CommandExists -commandName "sshpass"
        if ($temp)
        {
            # 如果不是管理员权限，则重新以管理员权限启动脚本
            Get-Administror
            Remove-Item -Path "$( $this.target_directory )\sshpass.exe" -Force
            Write-ColoredText -Text "sshpass已卸载."
        }
        else
        {
            Write-ColoredText -Text "sshpass未安装."
        }
    }

    [Void]
    init([Hashtable]$currentCachedData)
    {
        $dockerKey = "sshpass_install"
        if ( $currentCachedData.ContainsKey($dockerKey))
        {
            return
        }
        $currentCachedData[$dockerKey] = $true
        $this.install()
    }
}
$sshpassClass = [SshpassClass]::new()

class KnowHostsManagement
{
    [String]
    GetKnownHostsFile()
    {
        # 获取 known_hosts 文件路径
        $sshDir = "$env:USERPROFILE\.ssh"
        if (!(Test-Path $sshDir))
        {
            New-Item -ItemType Directory -Path $sshDir -Force
        }
        return "$sshDir\known_hosts"
    }

    [Boolean]
    GetKnownHost([string]$ip, [int]$Port = 22)
    {
        $knownHostsFile = $this.GetKnownHostsFile()
        if (!(Test-Path $knownHostsFile))
        {
            return $false
        }
        # 生成匹配格式（支持自定义端口）  \b 表示 单词边界  ; \s 确保匹配后面有空格
        # -Pattern 默认匹配整行，不需要 ^ 开头
        $pattern = if ($Port -eq 22)
        {
            "\b$ip\b"
        }
        else
        {
            "^\[$ip\]:$Port\s"
        }
        return Select-String -Path $knownHostsFile -Pattern $pattern -Quiet
    }

    [Void]
    AddKnownHost([string]$ip, [int]$Port = 22)
    {
        $knownHostsFile = $this.GetKnownHostsFile()

        # 先检查是否已存在
        if ( $this.GetKnownHost($ip, $Port))
        {
            Write-Host "✅ $ip`:$Port 指纹已存在，跳过添加." -ForegroundColor Yellow
            return
        }

        $sshKey = ssh-keyscan -t rsa -p $Port $ip 2> $null

        if (-not $sshKey)
        {
            Write-Host "❌ 无法获取 $ip`:$Port 指纹." -ForegroundColor Red
            return
        }

        # 追加指纹
        $sshKey | Out-File -Append -Encoding utf8 $knownHostsFile
        Write-Host "✅ 已添加 $ip`:$Port 指纹到 known_hosts." -ForegroundColor Green
    }
}
$knowHostsManagement = [KnowHostsManagement]::new()

# 服务器管理
class ServerManagement
{
    $servers = $null

    # 获取服务器信息
    [Void]
    Init_Server()
    {
        $url = "http://172.16.0.227:84/server/Server.json"
        # 下载json文件转换为Hashtable数据
        $this.servers = Get_JSON_TO_Hashtable($url)
        $this.servers.Keys | ForEach-Object {
            $temp_key = $_
            $value = $this.servers[$temp_key]
            $value.ssh_passwd = $secretClass.DecryptString($value.ssh_passwd)
        }
    }

    [Hashtable]
    Get_Server()
    {
        return $this.servers
    }

    [Void]
    Print_Server_Info()
    {
        # $servers 不为空 则输出服务器信息
        if ($null -ne $this.servers)
        {
            $showList = "dev", "jtjc_web", "jtjc_data"
            $this.servers.Keys | ForEach-Object {
                $temp_key = $_
                $value = $this.servers[$temp_key]
                # 左对齐，宽度为 10；右对齐，宽度为 5
                if ($temp_key -in $showList)
                {
                    $output = "服务器名称: {0,-15} ip: {1,-15} 密码: {2,-20} 描述: {3,-20}" -f $temp_key, $value.ip, $value.ssh_passwd, $value.desc
                    Write-ColoredText -Text $output
                }
            }
        }
    }
}
$serverManage = [ServerManagement]::new()

class CachedManagement
{
    $cacheFile = "$env:USERPROFILE\deploy.json"
    $cachedData = @{ }
    $isReaded = $false

    # 定义模块脚本
    [Hashtable]
    Read_CachedData($projectName)
    {
        if ($this.isReaded)
        {
            return $this.cachedData[$projectName]
        }
        if (-Not (Test-Path $this.cacheFile))
        {
            $this.cachedData[$projectName] = @{ }
            return $this.cachedData[$projectName]
        }
        $this.cachedData = Get-Content -Path $this.cacheFile -Raw -Encoding UTF8
        if ($null -eq $this.cachedData)
        {
            $this.cachedData = @{ }
            $this.cachedData[$projectName] = @{ }
            return $this.cachedData[$projectName]
        }
        $this.cachedData = $this.cachedData | ConvertFrom-Json
        $this.cachedData = ConvertTo_Hashtable -InputObject $this.cachedData
        if ( $this.cachedData.ContainsKey($projectName))
        {
            return $this.cachedData[$projectName]
        }
        $this.cachedData[$projectName] = @{ }
        $this.isReaded = $true
        return $this.cachedData[$projectName]
    }

    [Void]
    Write_CachedData()
    {
        $this.cachedData | ConvertTo-Json -Depth 100 | Set-Content -Path $this.cacheFile -Encoding UTF8
    }
}
$cachedManagement = [CachedManagement]::new()

# docker-desktop 自动安装 docker28.0.1安装时已经包含了docker-compose
class DockerClass
{
    [String]$dockerServiceName = "com.docker.service"
    [String]$dockerCommand = "docker"
    [String]$dockerConfigPath = "$env:USERPROFILE\.docker"
    [string]$dockerRepository
    $cachedManagement

    DockerClass([string]$dockerRepository, $cachedManagement)
    {
        $this.dockerRepository = $dockerRepository
        $this.cachedManagement = $cachedManagement
    }

    # 检测 Windows 系统是否满足 Docker 安装要求
    [Boolean]
    CheckWindowsVersion()
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

    [Boolean]
    CheckSystemArchitecture()
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

    [Boolean]
    TestWindowsFeature([string]$FeatureName)
    {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        return ($feature.State -eq "Enabled")
    }

    [Void]
    install()
    {
        $temp = Get-CommandExists -commandName $this.dockerCommand
        if ($temp)
        {
            Write-ColoredText -Text "$( $this.dockerCommand )命令已经安装."
            return
        }
        # 获取管理员权限
        Get-Administror
        if ((-not $($this.CheckWindowsVersion() )) -or (-not $($this.CheckSystemArchitecture() )))
        {
            return
        }

        $download_url = $null
        $target_ip = "172.16.0.227"
        $github_ip = "desktop.docker.com"

        # 执行 ping 命令测试连接目标主机
        $temp = Test-NetworkConnectivity -Target $target_ip
        if ($temp)
        {
            $download_url = "http://$( $target_ip ):84/docker/Docker%20Desktop%20Installer.exe"
        }
        else
        {
            $temp = Test-NetworkConnectivity -Target $github_ip
            if ($temp)
            {
                $download_url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
            }
            else
            {
                Write-ColoredText -Text "目标服务器和github.com均不可达，请手动安装.地址：https://github.com/tech-shrimp/docker_installer/releases/download/latest/docker_desktop_installer_windows_x86_64.exe" -Color "Red"
                exit 1
            }
        }
        Write-ColoredText -Text "$( $this.dockerCommand )下载地址：$download_url"

        # 检查 WSL 是否已启用
        if (-not ($this.TestWindowsFeature("Microsoft-Windows-Subsystem-Linux")))
        {
            Write-Host "正在启用 WSL 功能..." -ForegroundColor Green
            dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        }
        else
        {
            Write-Host "WSL 功能已启用，跳过此步骤。" -ForegroundColor Yellow
        }

        # 检查虚拟机平台是否已启用
        if (-not ($this.TestWindowsFeature("VirtualMachinePlatform")))
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
        $dockerInstallerPath = "$env:TEMP\DockerDesktopInstaller.exe"

        Write-Host "正在下载 Docker Desktop 安装程序..." -ForegroundColor Green
        Invoke-WebRequest -Uri $download_url -OutFile $dockerInstallerPath

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
        Write-ColoredText -Text "正在安装 Docker Desktop . 请注意交互界面需要点击确认安装的配置……" -Color "Red"
        try
        {
            Start-Process -FilePath $dockerInstallerPath -Args @("install --always-run-service --installation-dir=$installationDir --windows-containers-default-data-root=$containerDataRoot --wsl-default-data-root=$wslDataRoot") -Wait
        }
        catch
        {
            Write-ColoredText -Text $_.Exception.Message -Color "Red"
        }

        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $temp = Get-CommandExists -commandName $this.dockerCommand
        if ($temp)
        {
            Write-ColoredText -Text "Docker Desktop 安装完成！" -Color "Green"
        }
        else
        {
            Write-ColoredText -Text "Docker Desktop 安装失败！" -Color "Red"
        }
        # 清理安装文件
        Remove-Item -Path $dockerInstallerPath -Force
    }

    [Void]
    uninstall()
    {
        Write-ColoredText -Text "$( $this.dockerCommand )不支持卸载."
    }

    [Void]
    config([Hashtable]$currentCachedData)
    {
        $dockerKey = "docker_config"
        if ( $currentCachedData.ContainsKey($dockerKey))
        {
            return
        }
        Write-ColoredText -Text "正在加载配置……"
        $currentCachedData[$dockerKey] = $true
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

        # docker login -u admin -p s9AGdzFaSLXyQrD "$($this.dockerRepository)"
        Write-ColoredText -Text "加载配置完成！"
        $this.restartService()
        $this.cachedManagement.Write_CachedData()
    }

    [Boolean]
    isStartSerivice()
    {
        $service = Get-Service -Name $this.dockerServiceName -ErrorAction SilentlyContinue
        if ($service)
        {
            if ($service.Status -eq "Running")
            {
                return $true
            }
        }
        return $false
    }

    [Void]
    startService()
    {
        Get-Administror
        # 检测docker服务存在与否，存在则检测状态是否开启没有开启则自动启动docker服务
        $service = Get-Service -Name $this.dockerServiceName -ErrorAction SilentlyContinue
        if ($service)
        {
            if ($service.Status -eq "Stopped")
            {
                Write-ColoredText -Text "$( $this.dockerServiceName )服务未开启，正在自动开启..."
                Get-Administror
                Start-Service -Name $this.dockerServiceName
                $service = Get-Service -Name $this.dockerServiceName -ErrorAction SilentlyContinue
                if ($service)
                {
                    if ($service.Status -eq "Running")
                    {
                        Write-ColoredText -Text "$( $this.dockerServiceName )服务启动成功."
                    }
                    else
                    {
                        Write-ColoredText -Text "$( $this.dockerServiceName )服务启动失败，请手动开启." -Color "Red"
                        exit 1
                    }
                }
            }
            else
            {
                Write-ColoredText -Text "$( $this.dockerServiceName )服务已开启."
            }
        }
    }

    [Void]
    restartService()
    {
        Get-Administror
        $service = Get-Service -Name $this.dockerServiceName -ErrorAction SilentlyContinue
        if ($service)
        {
            Restart-Service -Name $this.dockerServiceName
            $service = Get-Service -Name $this.dockerServiceName -ErrorAction SilentlyContinue
            if ($service.Status -eq "Running")
            {
                Write-ColoredText -Text "$( $this.dockerServiceName )服务重启成功."
            }
            else
            {
                Write-ColoredText -Text "$( $this.dockerServiceName )服务重启失败，请手动重启." -Color "Red"
                Exit_Operate
            }
        }
    }

    [Void]
    init([Hashtable]$currentCachedData)
    {
        $dockerKey = "docker_install"
        if (-not $currentCachedData.ContainsKey($dockerKey))
        {
            $currentCachedData[$dockerKey] = $true
            $this.install()
        }
        $this.cachedManagement.Write_CachedData()
        $this.config($currentCachedData)
    }
}
$dockerManage = [DockerClass]::new($DOCKER_REPOSITORY, $cachedManagement)

#endregion

#region flow_function

function Get-ReadProjectInfo
{
    $Script:PROJECT_VERSION = Get-CurrentVersion -file "$PSScriptRoot\..\VERSION"
    $Script:target_file = "build\libs\$PROJECT_NAME-$PROJECT_VERSION.jar"
    $Script:JAR_FILE = "$PROJECT_NAME-$PROJECT_VERSION.jar"
    $Script:IMAGE_FULL_NAME = "$DOCKER_REPOSITORY/$IMAGE_NAME`:$PROJECT_VERSION"
}

function Get_InitVariable
{
    $Script:target_server = Get-Input -Info "Please input the target server 'dev' or 'pro' for deployment (default is dev)" -Value "$target"
    $Script:operate = Get-Input -Info "Please input operate(jar, image, deploy) (default is deploy)" -Value "$operate"
    $Script:currentIP = Get-IPAddress "172.16.0"
    $Script:PORT = Get-Input -Info "Please input port(default is 8605)" -Value "8605"

    $server_name = "dev"
    if ($target_server -eq "pro")
    {
        #        请确认它是否已发布到“pro”环境（是/否）（defalut为n）
        $inputValue = Read-Host -Prompt ">>>>>>>>>Step1: 请确认是否已发布到pro环境(y/n)(默认为n)"
        if ( [string]::IsNullOrEmpty($inputValue))
        {
            $inputValue = "n"
        }
        if ($inputValue -like "*n*")
        {
            Write-ColoredText -Text ">>>>>>>>>Step1: 离开部署!" -Color 'Red'
            . Exit_Operate
            exit 1
        }
        if ($current_branch -ne "master")
        {
            try
            {
                Write-ColoredText -Text ">>>>>>>>>Step1: 开始切换到master分支……" -Color 'Green'
                git checkout master
                git -c core.quotepath=false -c log.showSignature=false fetch origin --recurse-submodules=no --progress --prune
                git -c core.quotepath=false -c log.showSignature=false merge origin/master --no-stat -v
                if (!$?)
                {
                    throwrow ">>>>>>>>Step1: 切换到master分支并拉取合并最新代码失败!"
                }
                Write-ColoredText -Text ">>>>>>>>>Step1: 切换到master分支并拉取合并最新代码成功!" -Color 'Green'
            }
            catch
            {
                Write-ColoredText -Text $_.Exception.Message -Color "Red"
                Pause
                Exit_Operate
            }
        }
        if (-not $?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step1: 离开部署!" -Color 'Red'
            . Exit_Operate
            exit 1
        }

        $server_name = "jtjc_web"
        [string]$Global:PROFILES_ACTIVE = "prod"
    }
    else
    {
        [string]$Global:PROFILES_ACTIVE = "dev"
    }

    # 提取所有键并转换为数组（方便检查）
    $validKeys = $serverManage.servers.Keys
    # 循环提示用户输入
    while ($true)
    {
        $server_name = Get-Input -Info "请输入有效的服务器 (服务器名: $( $validKeys -join ', ' )).默认是$server_name" -Value "$server_name"
        # 检查输入是否是有效的键
        if ($validKeys -contains $server_name)
        {
            break  # 输入正确，退出循环
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step1: 输入错误！请重新输入!" -Color 'Red'
        }
    }
    $Script:username = $serverManage.servers[$server_name].ssh_user
    $Script:ip = $serverManage.servers[$server_name].ip
    $Script:password = $serverManage.servers[$server_name].ssh_passwd
    $Script:port = $serverManage.servers[$server_name].ssh_port
}

function Get-Help-Info
{
    if ($help)
    {
        Write-ColoredText -Text "参数:"
        Write-ColoredText -Text "`t-t`t-target `t<String>`t部署的目标服务器, 值是 'dev' 或 'pro'. 默认是 'dev'"
        Write-ColoredText -Text "`t-o`t-operate`t<String>`t部署操作, 值是：'jar', 'image', 'deploy' 或 'list-server'. 默认值是'deploy'"
        Write-ColoredText -Text "`t-h`t-help`t  `t显示帮助文档."
        Write-ColoredText -Text "`t-i`t-interactive`t开启交互模式."
        Write-ColoredText -Text "示例1:部署到测试服务器 .\deploy_api.ps1 -t dev -o deploy."
        Write-ColoredText -Text "示例2:部署到正式服务器 .\deploy_api.ps1 -t pro -o deploy."
        Write-ColoredText -Text "示例3:查看服务器信息 .\deploy_api.ps1 -o list-server."
        exit 0
    }
}

function Get-Jar
{
    Write-ColoredText -Text ">>>>>>>>>Step1: Gradle开始打包......"
    Set-Location (Join-Path $current_path "..")
    $temp = Get-Location
    $command = "$temp\gradlew.bat"
    try
    {
        & $command clean bootJar -x test -Pversion="$PROJECT_VERSION"
        $temp = "$temp\$target_file"
        if ($? -and (Test-Path -Path $temp))
        {
            Write-ColoredText -Text "Gradle打包成功!"
        }
        else
        {
            throw "Gradle打包失败!";
        }
    }
    catch
    {
        Write-ColoredText -Text $_.Exception.Message -Color "Red"
        Pause
        Exit_Operate 1
    }
    Set-Location $current_path
}

function Get-Image
{
    Write-ColoredText -Text ">>>>>>>>>Step2: 开始构建镜像......"
    Set-Location (Join-Path $current_path "..")
    try
    {
        Move-Item -Path $target_file -Destination $current_path -Force
        if (!$?)
        {
            throw ">>>>>>>>>Step2: 移动jar文件失败!"
        }
    }
    catch
    {
        Write-ColoredText -Text $_.Message -Color 'Red'
        Pause
        Exit_Operate 1
    }
    Set-Location "bin"

    # 本地没有安装docker则远程构建镜像并上传到服务器
    if (-not $dockerManage.isStartSerivice())
    {
        # 运维服务器构建镜像、上传镜像
        # 上传 bin目录下的Dockerfile、docker-compose.yml、jar文件
        sshpass -p $password scp -p "docker-compose.yml" "$username@$ip`:/app/$PROJECT_NAME"
        sshpass -p $password scp -p "Dockerfile" "$username@$ip`:/app/$PROJECT_NAME"
        sshpass -p $password scp -p "$JAR_FILE" "$username@$ip`:/app/$PROJECT_NAME"

        # 构建上传镜像
        $cm_build = "cd /app/$PROJECT_NAME;export PROJECT_VERSION=`"$PROJECT_VERSION`"; export PORT=`"$PROJECT_PORT`"; export PROFILES_ACTIVE=`"$PROFILES_ACTIVE`"; export PROJECT_NAME=`"$PROJECT_NAME`"; export JAR_FILE=`"$JAR_FILE`"; export DOCKER_REPOSITORY=`"$DOCKER_REPOSITORY`"; export IMAGE_NAME=`"$IMAGE_NAME`"; export IMAGE_FULL_NAME=`"$IMAGE_FULL_NAME`"; export CONTAINER_NAME=`"$CONTAINER_NAME`"; export CONTAINER_NAME=`"$CONTAINER_NAME`"; docker-compose -f docker-compose.yml config > docker-compose-$PROJECT_NAME.yml; docker-compose -f docker-compose-$PROJECT_NAME.yml build; docker-compose -f docker-compose-$PROJECT_NAME.yml push -q;"
        sshpass -p $password ssh $username@$ip "$cm_build"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step2: 远程镜像构建失败!" -Color 'Red'
            Set-Location $current_path
            exit 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step2: 构建镜像成功!"
        }
    }
    else
    {
        # 本地构建镜像、上传镜像
        $env:PORT = $PROJECT_PORT
        $env:PROJECT_VERSION = $PROJECT_VERSION
        $env:PROJECT_NAME = $PROJECT_NAME
        $env:JAR_FILE = $JAR_FILE
        $env:DOCKER_REPOSITORY = $DOCKER_REPOSITORY
        $env:IMAGE_NAME = $IMAGE_NAME
        $env:IMAGE_FULL_NAME = $IMAGE_FULL_NAME
        $env:CONTAINER_NAME = $CONTAINER_NAME
        $env:PROFILES_ACTIVE = $PROFILES_ACTIVE
        docker-compose -f docker-compose.yml config > "docker-compose-$PROJECT_NAME.yml"
        try
        {
            docker login -u admin -p s9AGdzFaSLXyQrD "$DOCKER_REPOSITORY"
            docker-compose -f "docker-compose-$PROJECT_NAME.yml" build
            if (!$?)
            {
                throw  ">>>>>>>>>Step2: docker-compose 构建失败!"
            }
        }
        catch
        {
            Write-ColoredText -Text $_.Message -Color 'Red'
            Pause
            Exit_Operate 1
        }
        Write-ColoredText -Text ">>>>>>>>>Step2: ocker-compose 构建成功!"
        Write-ColoredText -Text ">>>>>>>>>Step2: 开始推送镜像......"
        try
        {
            docker-compose -f "docker-compose-$PROJECT_NAME.yml" push -q
            if (!$?)
            {
                throw  ">>>>>>>>>Step2: docker推送镜像失败! 请再试一次"
            }
        }
        catch
        {
            Write-ColoredText -Text $_.Message 'Red'
            Pause
            Exit_Operate 1
        }
        Write-ColoredText -Text ">>>>>>>>>Step2: 推送镜像成功!"
        # 移除本地的 none 镜像
        Remove-None-Images
    }
    # 移除本地的jar包
    Remove-Item -Path (Join-Path $current_path "/$PROJECT_NAME-$PROJECT_VERSION.jar")
    Set-Location $current_path
}

function Get-Deploy
{
    if (-not $dockerManage.isStartSerivice())
    {
        Write-ColoredText -Text ">>>>>>>>>Step3: 开始部署启动......"
        $cm_build = " cd /app/$PROJECT_NAME; if [ ! -d `"/app/'$PROJECT_NAME'/log`" ]; then mkdir -p /app/$PROJECT_NAME/log; fi; docker-compose -f /app/$PROJECT_NAME/docker-compose-$PROJECT_NAME.yml pull -q; docker-compose -f /app/$PROJECT_NAME/docker-compose-$PROJECT_NAME.yml up -d; docker image prune -a -f;"
        sshpass -p $password ssh $username@$ip "$cm_build"
        Write-ColoredText -Text ">>>>>>>>>Step3: 部署成功!"
    }
    else
    {
        $temp = "if [ ! -d `"/app/'$PROJECT_NAME'/log`" ]; then mkdir -p /app/$PROJECT_NAME/log; fi"
        sshpass -p $password ssh $username@$ip "$temp"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: ssh初始化操作失败!" -Color 'Red'
            Exit_Operate 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: 服务器文件初始化操作成功!"
        }

        # 发布代码：判断是测试环境还是正式环境，然后设置ip
        sshpass -p $password scp -p "docker-compose-$PROJECT_NAME.yml" "$username@$ip`:/app/$PROJECT_NAME"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: 上传docker-compose-$PROJECT_NAME.yml失败!" -Color 'Red'
            Exit_Operate 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: 上传docker-compose-$PROJECT_NAME.yml成功!"
        }

        $temp = 'docker-compose -f /app/' + $PROJECT_NAME + '/docker-compose-' + $PROJECT_NAME + '.yml pull -q; docker-compose -f /app/' + $PROJECT_NAME + '/docker-compose-' + $PROJECT_NAME + '.yml up -d;'
        sshpass -p $password ssh $username@$ip "$temp"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: 启动$CONTAINER_NAME 失败!" -Color 'Red'
            Exit_Operate 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: 启动$CONTAINER_NAME 成功!"
        }
        # 移除本地的yml文件
        Remove-Item -Path "docker-compose-$PROJECT_NAME.yml"
        try
        {
            shpass -p $password ssh $username@$ip "docker image prune -a -f"
            if (!$?)
            {
                throw "清理服务器多余的镜像参与失败"
            }
            Write-ColoredText -Text ">>>>>>>>>Step3: 清理服务器多余的镜像成功!"
        }
        catch
        {
            Write-ColoredText -Text $_.Message -Color 'Red'
        }
    }
    $git_log = git log --oneline -n 1 HEAD
    $cm_log = 'echo "部署成功. ' + $operator + ' 用户ip是:' + $currentIP + ',部署时间是: ' + $currentDatetime + '. 当前部署的git日志是: ' + $git_log + '" >> /app/' + $PROJECT_NAME + '/log/deploy.log'
    sshpass -p $password ssh $username@$ip "$cm_log"
    Set-Location $current_path
}

#endregion

#region main

# 获取服务器信息
$serverManage.Init_Server()
$is_pause = $true
$currentCachedData = $cachedManagement.Read_CachedData($PROJECT_NAME)
$operator = Get-Username

$currentDatetime = Get-FormattedDate -Format "yyyy-MM-dd HH:mm:ss"
$startDateTime = Get-Date

Get-ReadProjectInfo
Get-Help-Info
switch ($operate)
{
    "list-server"
    {
        $serverManage.Print_Server_Info()
        $is_pause = $false
    }
    "jar"
    {
        Get-Jar
    }
    "image"
    {
        Write-ColoredText -Text ">>>>>>>>>Step0: 初始化......"
        Get_InitVariable
        $knowHostsManagement.AddKnownHost($ip, $port)
        $sshpassClass.init($cachedManagement.cachedData)
        $knowHostsManagement.AddKnownHost()
        # docker安装检测
        $dockerManage.init($cachedManagement.cachedData)
        # docker服务启动
        $dockerManage.startService()
        Get-Jar
        Get-Image
    }
    "deploy"
    {
        Write-ColoredText -Text ">>>>>>>>>Step0: 初始化......"
        Get_InitVariable
        $knowHostsManagement.AddKnownHost($ip, $port)
        $sshpassClass.init($cachedManagement.cachedData)
        # docker安装检测
        $dockerManage.init($cachedManagement.cachedData)
        # docker服务启动
        $dockerManage.startService()
        Get-Jar
        Get-Image
        Get-Deploy
    }
    default
    {
        Write-ColoredText -Text "$operate is not supported. Supported operate parameter 'jar' or 'image' or 'deploy'
            was provided. Please pass the parameter and rerun the script." -Color 'Red'
        Get-Help-Info
    }
}

Set-Location $current_path
$endDateTime = Get-Date
$timeDifference = $endDateTime - $startDateTime

$hours = $timeDifference.Hours
$minutes = $timeDifference.Minutes
$seconds = $timeDifference.Seconds

# 格式化输出部署时间
$currentCachedData["timne"] = $endDateTime.ToString("yyyy-MM-dd HH:mm:ss")
$currentCachedData["server"] = $ip
$currentCachedData["operate"] = $operate
$msg = "$( $currentCachedData["timne"] ) 部署到 $ip 服务器总共花费的时间是: $hours hours, $minutes minutes, $seconds seconds"
$currentCachedData["status"] = $msg
$currentCachedData["interactive"] = $interactive
$cachedManagement.Write_CachedData()

if ($is_pause)
{
    Write-ColoredText -Text $msg
    Pause
}

#endregion