# ==========================================
# 企业级 Sysmon 自动部署脚本
# 作者: Security Team
# 功能: 下载、配置、安装 Sysmon
# 环境: Windows 7+/Server 2008 R2+，PowerShell 3.0+
# 注意: 请以管理员身份运行
# ==========================================

param(
    [string]$SysmonInstallerPath = "$env:SystemRoot\Sysmon64.exe",
    [string]$ConfigPath = "$env:SystemRoot\sysmon-enterprise.xml",
    [string]$DownloadUrl = "https://download.sysinternals.com/files/Sysmon.zip",
    [string]$ZipPath = "$env:SystemRoot\Sysmon.zip",
    [switch]$ForceReinstall = $false
)

# -----------------------------
# 1. 检查管理员权限
# -----------------------------
function Test-Administrator
{
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator))
{
    Write-Error "此脚本必须以管理员身份运行。"
    exit 1
}

Write-Host "[+] 正在以管理员权限运行..." -ForegroundColor Green


# -----------------------------
# 2. 创建企业级 Sysmon 配置文件
# -----------------------------
function New-SysmonConfig
{
    $config = @'
<Sysmon schemaversion="4.82">
  <HashAlgorithms>sha256</HashAlgorithms>
  <EventFiltering>
    <!-- 进程创建监控 -->
    <ProcessCreate onmatch="include">
      <Image condition="end with">\\powershell.exe</Image>
      <Image condition="end with">\\pwsh.exe</Image>
      <Image condition="end with">\\cmd.exe</Image>
      <Image condition="end with">\\wscript.exe</Image>
      <Image condition="end with">\\cscript.exe</Image>
      <Image condition="end with">\\mshta.exe</Image>
      <Image condition="end with">\\rundll32.exe</Image>
      <Image condition="end with">\\regsvr32.exe</Image>
      <Image condition="end with">\\certutil.exe</Image>
      <Image condition="end with">\\bitsadmin.exe</Image>
      <Image condition="contains">\\Temp\\</Image>
      <Image condition="contains">\\AppData\\Local\\Temp\\</Image>
    </ProcessCreate>
    <ProcessCreate onmatch="exclude">
      <Image condition="begin with">C:\Program Files\</Image>
      <Image condition="begin with">C:\Program Files (x86)\</Image>
      <Image condition="begin with">C:\Windows\System32\</Image>
      <Image condition="begin with">C:\Windows\SysWOW64\</Image>
    </ProcessCreate>

    <!-- 网络连接 -->
    <NetworkConnect onmatch="include">
      <DestinationPort condition="is not">53</DestinationPort>
      <DestinationPort condition="is not">80</DestinationPort>
      <DestinationPort condition="is not">443</DestinationPort>
    </NetworkConnect>

    <!-- 文件创建 -->
    <FileCreate onmatch="include">
      <TargetFilename condition="end with">.exe</TargetFilename>
      <TargetFilename condition="end with">.dll</TargetFilename>
      <TargetFilename condition="end with">.ps1</TargetFilename>
      <TargetFilename condition="end with">.vbs</TargetFilename>
    </FileCreate>

    <!-- 注册表持久化 -->
    <RegistryEvent onmatch="include">
      <TargetObject condition="contains">\\CurrentVersion\\Run</TargetObject>
      <TargetObject condition="contains">\\CurrentVersion\\RunOnce</TargetObject>
      <TargetObject condition="contains">\\Start Menu\\Programs\\Startup</TargetObject>
    </RegistryEvent>
  </EventFiltering>
</Sysmon>
'@

    $config | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
    Write-Host "[+] 已生成配置文件: $ConfigPath" -ForegroundColor Green
}


# -----------------------------
# 3. 下载并解压 Sysmon
# -----------------------------
function Install-SysmonBinary
{
    if ((Test-Path $SysmonInstallerPath) -and (-not $ForceReinstall))
    {
        Write-Host "[*] Sysmon 已存在: $SysmonInstallerPath" -ForegroundColor Yellow
        return
    }

    Write-Host "[*] 正在下载 Sysmon 安装包..." -ForegroundColor Cyan
    try
    {
        $wc = New-Object Net.WebClient
        $wc.DownloadFile($DownloadUrl, $ZipPath)
        Write-Host "[+] 下载完成: $ZipPath" -ForegroundColor Green

        # 把 压缩包解压到 $env:SystemRoot/temp 目录下
        Expand-Archive -Path $ZipPath -DestinationPath "$env:SystemRoot/temp" -Force
        if (-not (Test-Path "$env:SystemRoot/temp/Sysmon64.exe"))
        {
            throw "解压后未找到 Sysmon64.exe"
        }
        # 把 Sysmon64.exe 文件复制到  $env:SystemRoot 目录下
        Copy-Item -Path "$env:SystemRoot/temp/Sysmon64.exe" -Destination $env:SystemRoot -Force
        Write-Host "[+] 已解压 Sysmon" -ForegroundColor Green
        # 清除 压缩包、$env:SystemRoot/temp 目录
        Remove-Item -Path $ZipPath, "$env:SystemRoot/temp" -Recurse -Force
    }
    catch
    {
        Write-Error "下载或解压失败: $_"
        exit 1
    }
}


# -----------------------------
# 4. 安装 Sysmon 服务
# -----------------------------
function Invoke-SysmonInstall
{
    Write-Host "[*] 正在安装 Sysmon..." -ForegroundColor Cyan

    $args = @(
        "-i", $ConfigPath,
        "-n", # 安装网络监控（可选）
        "-accepteula",
        "-h", "sha256"
    )

    $proc = Start-Process -FilePath $SysmonInstallerPath `
                          -ArgumentList $args `
                          -Wait `
                          -NoNewWindow `
                          -PassThru

    if ($proc.ExitCode -eq 0)
    {
        Write-Host "[+] Sysmon 安装成功！" -ForegroundColor Green
    }
    else
    {
        Write-Error "Sysmon 安装失败，退出码: $( $proc.ExitCode )"
        exit 1
    }
}


# -----------------------------
# 5. 验证服务状态
# -----------------------------
function Test-SysmonService
{
    $service = Get-Service -Name "Sysmon64" -ErrorAction SilentlyContinue
    if ($service -and ($service.Status -eq "Running"))
    {
        Write-Host "[+] Sysmon 服务正在运行" -ForegroundColor Green
    }
    else
    {
        Write-Error "Sysmon 服务未运行，请检查 eventvwr.msc"
    }

    Write-Host "[*] 日志位置: 事件查看器 → Applications and Services Logs → Microsoft → Windows → Sysmon → Operational"
}


# -----------------------------
# 主流程
# -----------------------------
try
{
    Write-Host "🚀 开始部署 Sysmon..." -ForegroundColor Magenta

    # 1. 生成配置
    New-SysmonConfig

    # 2. 下载二进制
    Install-SysmonBinary

    # 3. 安装服务
    if ($ForceReinstall)
    {
        Write-Host "[*] 强制重新安装..." -ForegroundColor Yellow
        & $SysmonInstallerPath -u -y  # 静默卸载
    }
    Invoke-SysmonInstall

    # 4. 验证
    Test-SysmonService

    Write-Host "✅ Sysmon 部署完成！" -ForegroundColor Green
}
catch
{
    Write-Error "部署过程中发生错误: $_"
    exit 1
}