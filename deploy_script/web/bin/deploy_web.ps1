Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'pro')]
    [string]$target = 'dev',

    [Parameter(Mandatory = $false)]
    [ValidateSet('build', 'deploy', 'list-server')]
    [string]$operate = "deploy",

    [Parameter(Mandatory = $false)]
    [switch]$help, [Parameter(Mandatory = $false)]

    [switch]$interactive
)

chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Security

############################### 全局变量定义 ################################
$ErrorActionPreference = "Stop"
# 记录命令执行的位置
$current_path = Get-Location
# 项目名称
$PROJECT_NAME = "stcjc-web"
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

############################### 通用函数函数定义####################################
# 检查网络能够到达服务器，能够到达返回true，否则返回false
# 示例： $result = Test-NetworkConnectivity -Target "8.8.8.8"
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
        [Parameter(Mandatory = $true)]
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

function Git-Return-Branch
{
    $temp_branch = git symbolic-ref --short HEAD
    if ($temp_branch -ne $current_branch)
    {
        git checkout $current_branch
    }
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

############################### 类定义####################################
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
        if ( $currentCachedData.ContainsKey("sshpass_install"))
        {
            return
        }
        $currentCachedData["sshpass_install"] = $true
        $this.install()
    }
}
$sshpassClass = [SshpassClass]::new()

class NpmClass
{
    $command_name = "npm"

    [Void]
    install()
    {
        $temp = Get-CommandExists -commandName $this.command_name
        if (-not $temp)
        {
            Write-ColoredText -Text "npm未安装,请手动安装https://www.npmjs.com/package/npm"
        }
    }

    [Void]
    uninstall()
    {
        Write-ColoredText -Text "npm不支持卸载若要卸载请手动卸载"
    }

    [Void]
    init([Hashtable]$currentCachedData)
    {
        $npmKey = "npm_install"
        if ( $currentCachedData.ContainsKey($npmKey))
        {
            return
        }
        $currentCachedData[$npmKey] = $true
        $this.install()
    }
}
$npmManage = [NpmClass]::new()

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

function Get_InitVariable
{
    $Script:target_server = Get-Input -Info "请输入部署的目标服务器dev或pro(默认为dev)" -Value "$target"
    $Script:operate = Get-Input -Info "请输入操作，值是'build', 'deploy'或'list-server'(默认为deploy)" -Value "$operate"
    $Script:currentIP = Get-IPAddress "172.16.0"
    [string]$Script:DOCKER_REPOSITORY = "172.16.0.197:8083"

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
            Exit_Operate 1
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
                    throw "切换到master分支并拉取合并最新代码失败!"
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
        Write-ColoredText -Text "`t-o`t-operate`t<String>`t部署操作, 值是：'build'、'deploy' 或 'list-server'. 默认值是'deploy'"
        Write-ColoredText -Text "`t-h`t-help`t  `t显示帮助文档."
        Write-ColoredText -Text "`t-i`t-interactive`t开启交互模式."
        Write-ColoredText -Text "示例1:部署到测试服务器 deploy_web.ps1 -t dev -o deploy."
        Write-ColoredText -Text "示例2:部署到正式服务器 deploy_web.ps1 -t pro -o deploy."
        Write-ColoredText -Text "示例2:查看服务器信息 deploy_web.ps1 -o list-server."
        exit 0
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

function build
{
    Set-Location "..\"
    try
    {
        Write-ColoredText -Text "开始安装依赖包……"
        npm install --registry=https://registry.npmmirror.com/
        if (!$?)
        {
            throw "安装依赖包失败!"
        }
        Write-ColoredText -Text "成功安装依赖包!"
    }
    catch
    {
        Write-ColoredText -Text $_.Exception.Message -Color "Red"
        Pause
        Exit_Operate
    }
    try
    {
        Write-ColoredText -Text "开始打包……"
        npm run build
        if (!$?)
        {
            throw "打包失败!"
        }
        Write-ColoredText -Text "成功安打包!"
    }
    catch
    {
        Write-ColoredText -Text "打包失败!"
        Write-ColoredText -Text $_.Exception.Message -Color "Red"
        Pause
        Exit_Operate
    }
    Set-Location $current_path
}

function deploy
{
    Set-Location "..\"
    try
    {
        Write-ColoredText -Text "初始化目录……"
        $cmd = "if [ ! -d `"/app/$PROJECT_NAME/log`" ]; then mkdir -p /app/$PROJECT_NAME/log; fi;"
        sshpass -p $password ssh $username@$ip "$cmd"
        if (!$?)
        {
            throw "初始化目录失败!"
        }
        Write-ColoredText -Text "初始化目录成功!"
    }
    catch
    {
        Write-ColoredText -Text "初始化目录失败!" -Color "Red"
        Write-ColoredText -Text $_.Exception.Message -Color "Red"
        Pause
        Exit_Operate
    }
    try
    {
        Write-ColoredText -Text "上传文件开始……"
        sshpass -p $password scp -rp "dist/*"  "$username@$ip`:/app/$PROJECT_NAME/dist"
        if (!$?)
        {
            throw "上传文件失败!"
        }
        Write-ColoredText -Text "上传文件成功!"
    }
    catch
    {
        Write-ColoredText -Text "上传文件失败!" -Color "Red"
        Write-ColoredText -Text $_.Exception.Message -Color "Red"
    }

    try
    {
        Write-ColoredText -Text "记录操作日志……"
        $git_log = git log --oneline -n 1 HEAD
        $cm_log = 'echo "部署成功. ' + $operator + ' 用户ip是:' + $currentIP + ',部署时间是: ' + $currentDatetime + '. 当前部署的git日志是: ' + $git_log + '" >> /app/' + $PROJECT_NAME + '/log/deploy.log'
        sshpass -p $password ssh $username@$ip "$cm_log"
        if (!$?)
        {
            throw "记录操作日志失败!"
        }
        Write-ColoredText -Text "记录操作日志成功!"
    }
    catch
    {
        Write-ColoredText -Text "记录操作日志失败!" -Color "Red"
        Write-ColoredText -Text $_.Exception.Message -Color "Red"
    }
    Set-Location $current_path
}

################################ main ############################################
# 获取服务器信息
$serverManage.Init_Server()
$is_pause = $true
$currentCachedData = $cachedManagement.Read_CachedData($PROJECT_NAME)
$operator = Get-Username

$currentDatetime = Get-FormattedDate -Format "yyyy-MM-dd HH:mm:ss"
$startDateTime = Get-Date

Get-Help-Info
switch ($operate)
{
    "list-server"
    {
        $serverManage.Print_Server_Info()
        $is_pause = $false
    }
    "build"
    {
        Write-ColoredText -Text ">>>>>>>>>Step0: 准备阶段......"
        $sshpassClass.init($cachedManagement.cachedData)
        $npmManage.init($cachedManagement.cachedData)
        Write-ColoredText -Text ">>>>>>>>>Step1: 初始化......"
        Get_InitVariable
        Write-ColoredText -Text ">>>>>>>>>Step2: 构建项目......"
        build
    }
    "deploy"
    {
        Write-ColoredText -Text ">>>>>>>>>Step0: 准备阶段......"
        $sshpassClass.init($cachedManagement.cachedData)
        $npmManage.init($cachedManagement.cachedData)
        Write-ColoredText -Text ">>>>>>>>>Step1: 初始化......"
        Get_InitVariable
        # ssh 指纹检查，若是不存在则直接安装
        $knowHostsManagement.AddKnownHost($ip, $port)
        Write-ColoredText -Text ">>>>>>>>>Step2: 构建项目......"
        build
        Write-ColoredText -Text ">>>>>>>>>Step3: 开始部署......"
        deploy
    }
    default
    {
        Write-ColoredText -Text "$operate is not supported. Supported operate parameter 'build' or 'deploy'
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
