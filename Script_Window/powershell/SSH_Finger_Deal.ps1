function Get-KnownHostsFile
{
    # 获取 known_hosts 文件路径
    $sshDir = "$env:USERPROFILE\.ssh"
    if (!(Test-Path $sshDir))
    {
        New-Item -ItemType Directory -Path $sshDir -Force
    }
    return "$sshDir\known_hosts"
}

function Get-KnownHost
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$ip,

        [Parameter(Mandatory=$false)]
        [int]$Port = 22
    )
    $knownHostsFile = Get-KnownHostsFile
    if (!(Test-Path $knownHostsFile))
    {
        return $false
    }
    # 生成匹配格式（支持自定义端口）  \b 表示 单词边界  ; \s 确保匹配后面有空格
    # -Pattern 默认匹配整行，不需要 ^ 开头
    $pattern = if ($Port -eq 22) { "\b$ip\b" } else { "^\[$ip\]:$Port\s" }
    return Select-String -Path $knownHostsFile -Pattern $pattern -Quiet
}

function Add-KnownHost
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$ip,

        [int]$Port = 22
    )
    $knownHostsFile = Get-KnownHostsFile

    # 先检查是否已存在
    if (Get-KnownHost -ip $ip -Port $Port)
    {
        Write-Host "✅ $ip\: $Port 指纹已存在，跳过添加。" -ForegroundColor Yellow
        return
    }

    # 获取 SSH 指纹
    $hostFormat = if ($Port -eq 22) { $ip } else { "[$ip]:$Port" }
    $sshKey = ssh-keyscan -t rsa -p $Port $ip 2> $null

    if (-not $sshKey)
    {
        Write-Host "❌ 无法获取 $ip : $Port 指纹。" -ForegroundColor Red
        return
    }

    # 追加指纹
    $sshKey | Out-File -Append -Encoding utf8 $knownHostsFile
    Write-Host "✅ 已添加 $ip : $Port 指纹到 known_hosts。" -ForegroundColor Green
}

function Remove-KnownHost
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$ip,

        [int]$Port = 22
    )
    $knownHostsFile = Get-KnownHostsFile
    if (!(Test-Path $knownHostsFile))
    {
        return
    }

    # 读取文件内容
    $content = Get-Content $knownHostsFile

    # 生成匹配格式（支持自定义端口）
    $pattern = if ($Port -eq 22) { "^$ip " } else { "^\[$ip\]:$Port " }

    # 过滤掉目标行
    $filteredContent = $content | Where-Object { $_ -notmatch $pattern }

    # 只有当行数减少时才进行写入（避免无意义写入）
    if ($filteredContent.Count -lt $content.Count)
    {
        $filteredContent | Set-Content -Encoding utf8 $knownHostsFile
        Write-Host "✅ 已删除 $ip : $Port 的指纹。" -ForegroundColor Green
    }
    else
    {
        Write-Host "⚠️ 未找到 $ip : $Port 的指纹，无需删除。" -ForegroundColor Yellow
    }
}

function Update-KnownHost
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$ip,

        [int]$Port = 22
    )

    # 先删除旧指纹
    Remove-KnownHost -Host $ip -Port $Port
    # 重新添加新指纹
    Add-KnownHost -Host $ip -Port $Port
}

function Test{
    $ip = "172.16.0.197"
    $port = 22
    Add-KnownHost -ip $ip -Port $port
}

Test

# 坑：
# ssh-keyscan -H 这个 -H 选项的作用是强制使用哈希格式输出主机名/IP，和 SSH 配置中的 HashKnownHosts no 无关。