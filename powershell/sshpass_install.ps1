Param (
    [switch]$install,
    [switch]$uninstall
)

chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 存放文件位置
$target_directory = "C:\Windows\System32"

. "$PSScriptRoot\NetworkManage.ps1"

# 测试是否是管理员
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 判断指定的命令是否存在，存在则返回true，不存在则返回false
# $commandName: 命令名称
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

function install()
{
    Pause
    # 如果不是管理员权限，则重新以管理员权限启动脚本
    if (-not (Test-Admin)) {
        Write-Host "当前未以管理员权限运行，正在尝试以管理员权限重新启动脚本..." -ForegroundColor Yellow

        # 获取当前脚本的完整路径
        # 获取当前脚本路径
        $scriptPath = $PSCommandPath

        # 获取传递给脚本的参数
        $scriptArgs = $MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }
        $scriptArgs += $MyInvocation.UnboundArguments | ForEach-Object { "`"$_`"" }

        # 使用 Start-Process 以管理员权限重新启动脚本，并传递参数
        #  Start-Process 进程行为
        #当使用 Start-Process 以管理员权限 (-Verb RunAs) 启动新进程时：
        #原来的 PowerShell 进程不会等待新进程完成，而是会继续执行或直接退出（如果 exit 被调用）。
        #新的进程是独立的，不会受原进程的生命周期影响，因此不会因为原进程退出而自动终止。
        #如果需要传递参数，必须通过 -ArgumentList 明确传递。
#        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $scriptArgs"
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$scriptPath`" $scriptArgs"
        # 退出当前实例
        exit 0
    }

    $temp = Get-CommandExists -commandName "sshpass"
    if ($temp)
    {
        Write-ColoredText -Text "sshpass命令已经安装。"
        Exit 0
    }
    else
    {
        Write-ColoredText -Text "sshpass未安装，开始下载并安装..."
    }

    $download_url = $null
    $target_ip = "172.16.0.227"
    $github_ip = "github.com"

    # 执行 ping 命令测试连接目标主机
    $temp = Test-NetworkConnectivity -Target $target_ip
    if ($temp)
    {
        $download_url = "http://$($target_ip):84/sshpass/sshpass.exe"
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
            Write-ColoredText -Text "目标服务器和github.com均不可达，请手动安装。地址：https://github.com/xhcoding/sshpass-win32/releases/download/v1.0.3/sshpass.exe" -Color "Red"
            exit 1
        }
    }

    # 使用 curl 命令下载文件到目标目录
    Write-ColoredText -Text "开始下载$download_url..."
    Invoke-WebRequest -Uri $download_url -OutFile "$target_directory\sshpass.exe"

    if ($?)
    {
        Write-ColoredText -Text "sshpass安装成功。"
    }
    else
    {
        Write-ColoredText -Text "sshpass安装失败。"
    }
}

function uninstall()
{
    $temp = Get-CommandExists -commandName "sshpass"
    if ($temp)
    {
        Remove-Item -Path "$target_directory\sshpass.exe" -Force
        Write-ColoredText -Text "sshpass已卸载。"
    }
    else
    {
        Write-ColoredText -Text "sshpass未安装。"
    }
}

# 默认安装，如果指定了 -uninstall 则卸载
if ($uninstall)
{
    uninstall
}
else
{
    install
}

Pause