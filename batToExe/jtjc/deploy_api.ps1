#本地自动化部署脚本
#前提条件本地安装 docker、docker-compose
#实现目标：
#   1. 本地打包最新的 jar包 ，右侧gradle插件 → stc-jtjc → Tasks → build → bootJar
#   2. 构建 docker 镜像, 永久配置登录信息 在用户目录下/.docker/config 添加
#   4. 推送镜像到镜像仓库172.16.0.197:8083。需要提前登录镜像仓库。
#   5. 目标服务器启动 docker 容器
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'pro')]
    [string]$target = 'dev',

    [Parameter(Mandatory = $false)]
    [ValidateSet('jar', 'image', 'deploy')]
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

function Get_InitVariable
{
    $Global:target_server = Get-Input -Info "Please input the target server 'dev' or 'pro' for deployment (default is dev)" -Value "$target"
    $Global:operate = Get-Input -Info "Please input operate(jar, image, deploy) (default is deploy)" -Value "$operate"
    [string]$Global:PROJECT_NAME = "stcjc"
    [string]$Global:currentIP = Get-IPAddress "172.16.0"
    [string]$Global:current_path = Get-Location
    [string]$Global:PROJECT_VERSION = Get-CurrentVersion -file "..\VERSION"
    [string]$Global:target_file = "build\libs\$PROJECT_NAME-$PROJECT_VERSION.jar"
    [string]$Global:PORT = Get-Input -Info "Please input port(default is 8605)" -Value "8605"
    [string]$Global:JAR_FILE = "$PROJECT_NAME-$PROJECT_VERSION.jar"
    [string]$Global:DOCKER_REPOSITORY = "172.16.0.197:8083"
    [string]$Global:IMAGE_NAME = "csatc/$PROJECT_NAME"
    [string]$Global:IMAGE_FULL_NAME = "$DOCKER_REPOSITORY/$IMAGE_NAME`:$PROJECT_VERSION"
    [string]$Global:CONTAINER_NAME = $PROJECT_NAME

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
        [string]$Global:username = "root"
        [string]$Global:ip = "172.16.0.226"
        [string]$Global:password = "JKgTh4bPyyput9j8"
        [string]$Global:PROFILES_ACTIVE = "prod"
    }
    else
    {
        Write-ColoredText -Text ">>>>>>>>>Step: Initialization......"
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
        Write-ColoredText -Text "  -target <String>: deploy target server, value is 'dev' or pro. default is 'dev'"
        Write-ColoredText -Text "  -operate <String>: deploy operate, value is jar or image or deploy. default is 'deploy'"
        Write-ColoredText -Text "  -help: Display this help message."
        Write-ColoredText -Text "  -interactive: Open interactive mode."
        Write-ColoredText -Text "Example: deploy.bat -t pro -o deploy."
        Set-Location $current_path
        exit 0
    }
}

function Get-Jar
{
    Write-ColoredText -Text ">>>>>>>>>Step1: Gradle start building......"
    Set-Location (Join-Path $current_path "..")
    $temp = Get-Location
    $command = "$temp\gradlew.bat"
    & $command clean bootJar -x test -Pversion="$PROJECT_VERSION"
    $temp = "$temp\$target_file"
    if (Test-Path -Path $temp)
    {
        Write-ColoredText -Text ">>>>>>>>>Step1: Gradle build success!"
    }
    else
    {
        Write-ColoredText -Text ">>>>>>>>>Step1: Gradle build failed!" -Color 'Red'
        Set-Location $current_path
        exit 1
    }
    Set-Location $current_path
}

function Get-Image
{
    Write-ColoredText -Text ">>>>>>>>>Step2: Image start building......"
    Set-Location (Join-Path $current_path "..")
    try
    {
        Move-Item -Path $target_file -Destination $current_path -Force
    }
    catch
    {
        Write-ColoredText -Text ">>>>>>>>>Step2: Move jar file failed!" -Color 'Red'
    }
    Set-Location "bin"

    $processName = "docker"
    $processExists = (Get-Process | Where-Object { $_.Name -eq $processName }).Count -ne 0
    if (-not $processExists)
    {
        # 运维服务器构建镜像、上传镜像
        # 上传 bin目录下的Dockerfile、docker-compose.yml、jar文件
        sshpass -p $password scp -p "docker-compose.yml" "$username@$ip`:/app/$PROJECT_NAME"
        sshpass -p $password scp -p "Dockerfile" "$username@$ip`:/app/$PROJECT_NAME"
        sshpass -p $password scp -p "$JAR_FILE" "$username@$ip`:/app/$PROJECT_NAME"

        # 构建上传镜像
        $cm_build = "cd /app/$PROJECT_NAME;export PROJECT_VERSION=`"$PROJECT_VERSION`"; export PORT=`"$PORT`"; export PROFILES_ACTIVE=`"$PROFILES_ACTIVE`"; export PROJECT_NAME=`"$PROJECT_NAME`"; export JAR_FILE=`"$JAR_FILE`"; export DOCKER_REPOSITORY=`"$DOCKER_REPOSITORY`"; export IMAGE_NAME=`"$IMAGE_NAME`"; export IMAGE_FULL_NAME=`"$IMAGE_FULL_NAME`"; export CONTAINER_NAME=`"$CONTAINER_NAME`"; export CONTAINER_NAME=`"$CONTAINER_NAME`"; docker-compose -f docker-compose.yml config > docker-compose-$PROJECT_NAME.yml; docker-compose -f docker-compose-$PROJECT_NAME.yml build; docker-compose -f docker-compose-$PROJECT_NAME.yml push -q;"
        sshpass -p $password ssh $username@$ip "$cm_build"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step2: Remote Image build failed!" -Color 'Red'
            Set-Location $current_path
            exit 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step2: Remote image build success!"
        }
    }
    else
    {
        # 本地构建镜像、上传镜像
        $env:PORT = $PORT
        $env:PROJECT_VERSION = $PROJECT_VERSION
        $env:PROJECT_NAME = $PROJECT_NAME
        $env:JAR_FILE = $JAR_FILE
        $env:DOCKER_REPOSITORY = $DOCKER_REPOSITORY
        $env:IMAGE_NAME = $IMAGE_NAME
        $env:IMAGE_FULL_NAME = $IMAGE_FULL_NAME
        $env:CONTAINER_NAME = $CONTAINER_NAME
        $env:PROFILES_ACTIVE = $PROFILES_ACTIVE
        docker-compose -f docker-compose.yml config > "docker-compose-$PROJECT_NAME.yml"
        docker-compose -f "docker-compose-$PROJECT_NAME.yml" build
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step2: docker-compose build failed!" -Color 'Red'
            Set-Location $current_path
            exit 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step2: Build images success!"
        }
        docker-compose -f "docker-compose-$PROJECT_NAME.yml" push -q
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: Docker push build failed! Network fluctuation, please try again" -Color 'Red'
            Set-Location $current_path
            exit 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step3: Push images success!"
        }
        # 移除本地的 none 镜像
        Remove-None-Images
    }
    # 移除本地的jar包
    Remove-Item -Path (Join-Path $current_path "/$PROJECT_NAME-$PROJECT_VERSION.jar")
}

function Get-Deploy
{
    if ((-not (Test-Path -Path "variable:Global:target_server")) -or ($null -eq $target_server) -or ($target_server -eq ""))
    {
        $target_server = "dev"
        Write-ColoredText -Text "No specific target server parameter 'dev' or 'prod' was provided. Please pass the parameter and rerun the script."
        Write-ColoredText -Text "Warning: No specific target server parameter 'dev' or 'prod' was provided, defaulting to 'dev'."
    }

    $processName = "docker"
    $processExists = (Get-Process | Where-Object { $_.Name -eq $processName }).Count -ne 0
    if (-not $processExists)
    {
        Write-ColoredText -Text ">>>>>>>>>Step3: Staring deploy......"
        $cm_build = " cd /app/$PROJECT_NAME; if [ ! -d `"/app/'$PROJECT_NAME'/log`" ]; then mkdir -p /app/$PROJECT_NAME/log; fi; docker-compose -f /app/$PROJECT_NAME/docker-compose-$PROJECT_NAME.yml pull -q; docker-compose -f /app/$PROJECT_NAME/docker-compose-$PROJECT_NAME.yml up -d; docker image prune -a -f;"
        sshpass -p $password ssh $username@$ip "$cm_build"
        Write-ColoredText -Text ">>>>>>>>>Step3: Deployed success!"
    }
    else
    {
        # 发布代码：判断是测试环境还是正式环境，然后设置ip
        sshpass -p $password scp -p "docker-compose-$PROJECT_NAME.yml" "$username@$ip`:/app/$PROJECT_NAME"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step4: Upload file failed!" -Color 'Red'
            Set-Location $current_path
            exit 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step4: Upload file success!"
        }

        $temp = "if [ ! -d `"/app/'$PROJECT_NAME'/log`" ]; then mkdir -p /app/$PROJECT_NAME/log; fi"
        sshpass -p $password ssh $username@$ip "$temp"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step4: ssh init failed!" -Color 'Red'
            Set-Location $current_path
            exit 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step4: Init success!"
        }
        $temp = 'docker-compose -f /app/' + $PROJECT_NAME + '/docker-compose-' + $PROJECT_NAME + '.yml pull -q; docker-compose -f /app/' + $PROJECT_NAME + '/docker-compose-' + $PROJECT_NAME + '.yml up -d;'
        sshpass -p $password ssh $username@$ip "$temp"
        if (!$?)
        {
            Write-ColoredText -Text ">>>>>>>>>Step4: Start docker container failed!" -Color 'Red'
            Set-Location $current_path
            exit 1
        }
        else
        {
            Write-ColoredText -Text ">>>>>>>>>Step4: Start docker container success!"
        }
    }
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
    "jar"
    {
        Get-Jar
    }
    "image"
    {
        Get-Jar
        Get-Image
    }
    "deploy"
    {
        Get-Jar
        Get-Image
        Get-Deploy
    }
    default
    {
        Write-ColoredText -Text "$operate is not supported. Supported operate parameter 'jar' or 'image' or 'deploy'
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
