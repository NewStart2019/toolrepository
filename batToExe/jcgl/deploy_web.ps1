Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'pro')]
    [string]$target = 'dev',

    [Parameter(Mandatory = $false)]
    [ValidateSet('build', 'deploy')]
    [string]$operate = "deploy",

    [Parameter(Mandatory = $false)]
    [switch]$help, [Parameter(Mandatory = $false)]

    [switch]$interactive
)

chcp 65001  # 设置为 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

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

function Exit_Operate
{
    Set-Location $current_path
    $temp_branch = git symbolic-ref --short HEAD
    if ($temp_branch -ne $current_branch){
        git checkout $current_branch
    }
}

function Get_InitVariable
{
    $Global:target_server = Get-Input -Info "Please input the target server 'dev' or 'pro' for deployment (default is dev)" -Value "$target"
    $Global:operate = Get-Input -Info "Please input operate(jar, image, deploy) (default is deploy)" -Value "$operate"
    [string]$Global:PROJECT_NAME = "stc-jcgl-web"
    [string]$Global:currentIP = Get-IPAddress "172.16.0"
    [string]$Global:current_path = Get-Location
    #    [string]$Global:PORT = Get-Input -Info "Please input port(default is 85)" -Value "85"
    [string]$Global:DOCKER_REPOSITORY = "172.16.0.197:8083"
    [string]$Global:current_branch = git symbolic-ref --short HEAD

    if ($target_server -eq "pro")
    {
        $inputValue = Read-Host -Prompt "Please confirm if it has been released to the 'pro' environment(y/n)(defalut is n)"
        if ( [string]::IsNullOrEmpty($inputValue))
        {
            $inputValue="n"
        }
        if ($inputValue -like "*n*")
        {
            Write-ColoredText -Text ">>>>>>>>>Step1: Exit deploy!" -Color 'Red'
            Exit_Operate
            exit 1
        }
        Write-ColoredText -Text ">>>>>>>>>Step: Initialization......"
        if ($current_branch -ne "master")
        {
            git checkout master
            # 拉取最新代码
            git -c core.quotepath=false -c log.showSignature=false fetch origin --recurse-submodules=no --progress --prune
        }
        [string]$Global:username = "root"
        [string]$Global:ip = "172.16.0.83"
        [string]$Global:password = "94whI23VucJWqqBm"
        [string]$Global:PROFILES_ACTIVE = "prod"
    }
    else
    {
        Write-ColoredText -Text ">>>>>>>>>Step1: Initialization......"
        [string]$Global:username = "root"
        [string]$Global:ip = "172.16.0.227"
        [string]$Global:password = "Zjzx123!"
        [string]$Global:PROFILES_ACTIVE = "dev"
    }
}

function Get-Help
{
    if ($help)
    {
        Write-ColoredText -Text "Parameters:"
        Write-ColoredText -Text "   -t -target <String>: deploy target server, value is 'dev' or pro. default is 'dev'"
        Write-ColoredText -Text "   -o -operate <String>: deploy operate, value is jar or image or deploy. default is 'deploy'"
        Write-ColoredText -Text "  -h -help: Display this help message."
        Write-ColoredText -Text "  -i -interactive: Open interactive mode."
        Write-ColoredText -Text "Example: deploy_web.ps1 -t pro -o deploy."
        exit 0
    }
}

function build
{
    Write-ColoredText -Text ">>>>>>>>>Step2: Build......"
    Set-Location "..\"
    npm install --registry=https://registry.npmmirror.com/
    if (!$?)
    {
        Write-ColoredText -Text ">>>>>>>>>Step2: Install package failed!" -Color 'Red'
        Exit_Operate
        exit 1
    }
    else
    {
        Write-ColoredText -Text ">>>>>>>>>Step2: Install package success!"
    }
    npm run build
    if (!$?)
    {
        Write-ColoredText -Text ">>>>>>>>>Step2: Package failed!" -Color 'Red'
        Exit_Operate
        exit 1
    }
    else
    {
        Write-ColoredText -Text ">>>>>>>>>Step2: Package success!"
    }
    Set-Location $current_path
}


function deploy
{
    Set-Location "..\"
    $cmd = "if [ ! -d `"/app/$PROJECT_NAME/log`" ]; then mkdir -p /app/$PROJECT_NAME/log; fi;"
    sshpass -p $password ssh $username@$ip "$cmd"
    sshpass -p $password scp -rp "dist/*"  "$username@$ip`:/app/$PROJECT_NAME/dist"

    $git_log = git log --oneline -n 1 HEAD
    $cm_log = 'echo "Deployment for user with ' + $currentIP + ' was successful, deployment time is: ' + $currentDatetime + '. The Git log for the deployment is: ' + $git_log + '" >> /app/' + $PROJECT_NAME + '/log/deploy.log'
    sshpass -p $password ssh $username@$ip "$cm_log"
}

Get_InitVariable
$currentDatetime = Get-FormattedDate -Format "yyyy-MM-dd HH:mm:ss"
$startDateTime = Get-Date

Get-Help
switch ($operate)
{
    "build"
    {
        build
    }
    "deploy"
    {
        build
        deploy
    }
    default
    {
        Write-ColoredText -Text "$operate is not supported. Supported operate parameter 'build' or 'deploy'
            was provided. Please pass the parameter and rerun the script." -Color 'Red'
        Get-Help
    }
}

Set-Location $current_path
$endDateTime = Get-Date
$timeDifference = $endDateTime - $startDateTime

$hours = $timeDifference.Hours
$minutes = $timeDifference.Minutes
$seconds = $timeDifference.Seconds

Write-ColoredText -Text "Total time spent: $hours hours, $minutes minutes, $seconds seconds"
Pause
