# 获取当前操作系统的版本信息
$osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
# 分割版本字符串
$versionParts = $osVersion -split '\.'
# 获取主版本号
$majorVersion = [int]$versionParts[0]

# 判断主版本号是否等于 10
if ($majorVersion -eq 10)
{
    Write-Host "当前操作系统的主要版本号是 10“
    # 定义要检查和可能停止的服务列表
    $services = @("edgeupdate", "edgeupdatem", "wuauserv", "WaaSMedicSvc")

    # 遍历每个服务
    foreach ($service in $services)
    {
        # 获取服务对象
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue

        # 检查服务是否存在
        if ($null -ne $svc)
        {
            # 检查服务是否正在运行
            if ($svc.Status -eq 'Running')
            {
                # 停止服务
                try
                {
                    Stop-Service -Name $service -Force
                    Write-Host "服务 $service 已成功停止。"
                }
                catch
                {
                    Write-Host "无法停止服务 $service"
                }
            }
            else
            {
                Write-Host "服务 $service 当前状态是已停止。"
            }
        }
        else
        {
            Write-Host "服务 $service 不存在。"
        }
    }
}
else
{
    Write-Host "当前操作系统的主要版本号是 $osVersion 暂不支持关闭window和edge更新服务"
}

Pause

# 转exe命令
#  Invoke-PS2EXE -InputFile D:\Java\project\toolrepository\window\CloseService.ps1 -OutputFile "close_update.exe" -iconFile "image.ico"