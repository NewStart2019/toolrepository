<#
.SYNOPSIS
全面获取并显示Windows系统的硬件信息，包含显卡类型和频率信息

.DESCRIPTION
此脚本收集并展示系统中主要硬件组件的详细信息，
特别增强了显卡信息展示，包括是否为独立显卡及处理频率。
#>

# 设置输出编码，确保中文正常显示
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "              系统硬件信息报告                " -ForegroundColor Cyan
Write-Host "             生成时间: $(Get-Date)             " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host

# 1. 处理器信息
Write-Host "【处理器信息】" -ForegroundColor Green
$processors = Get-CimInstance -ClassName Win32_Processor
foreach ($cpu in $processors) {
    Write-Host "  名称: $($cpu.Name)"
    Write-Host "  制造商: $($cpu.Manufacturer)"
    Write-Host "  核心数: $($cpu.NumberOfCores)"
    Write-Host "  线程数: $($cpu.NumberOfLogicalProcessors)"
    Write-Host "  基础频率: $($cpu.MaxClockSpeed) MHz"
    Write-Host "  插槽: $($cpu.SocketDesignation)"
    Write-Host "  状态: $($cpu.Status)"
    Write-Host
}

# 2. 内存信息
Write-Host "【内存信息】" -ForegroundColor Green
$totalRAM = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
$memorySlots = Get-CimInstance -ClassName Win32_PhysicalMemoryArray | Select-Object -ExpandProperty MemoryDevices
$memoryModules = Get-CimInstance -ClassName Win32_PhysicalMemory

Write-Host "  总内存: $($totalRAM.ToString('N2')) GB"
Write-Host "  内存插槽总数: $memorySlots"
Write-Host "  已使用插槽: $($memoryModules.Count)"
Write-Host "  内存模块详情:"
foreach ($module in $memoryModules) {
    $capacityGB = $module.Capacity / 1GB
    $speed = $module.Speed
    $manufacturer = if ($module.Manufacturer -ne "") { $module.Manufacturer } else { "未知" }
    Write-Host "    - 容量: $($capacityGB.ToString('N2')) GB, 速度: $speed MHz, 制造商: $manufacturer"
}
Write-Host

# 3. 主板信息
Write-Host "【主板信息】" -ForegroundColor Green
$motherboard = Get-CimInstance -ClassName Win32_BaseBoard
Write-Host "  制造商: $($motherboard.Manufacturer)"
Write-Host "  产品名称: $($motherboard.Product)"
Write-Host "  版本: $($motherboard.Version)"
Write-Host "  序列号: $($motherboard.SerialNumber)"
Write-Host

# 4.  BIOS信息
Write-Host "【BIOS信息】" -ForegroundColor Green
$bios = Get-CimInstance -ClassName Win32_BIOS
Write-Host "  制造商: $($bios.Manufacturer)"
Write-Host "  版本: $($bios.SMBIOSBIOSVersion)"
Write-Host "  发布日期: $($bios.ReleaseDate.ToString('yyyy-MM-dd'))"
Write-Host "  序列号: $($bios.SerialNumber)"
Write-Host

# 5. 存储设备信息
Write-Host "【存储设备信息】" -ForegroundColor Green
$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
foreach ($disk in $disks) {
    $sizeGB = if ($disk.Size) { $disk.Size / 1GB } else { 0 }
    $freeSpaceGB = if ($disk.FreeSpace) { $disk.FreeSpace / 1GB } else { 0 }
    Write-Host "  驱动器: $($disk.DeviceID)"
    Write-Host "    卷标: $($disk.VolumeName)"
    Write-Host "    文件系统: $($disk.FileSystem)"
    Write-Host "    总容量: $($sizeGB.ToString('N2')) GB"
    Write-Host "    可用空间: $($freeSpaceGB.ToString('N2')) GB"
    Write-Host "    使用率: $([math]::Round((1 - $freeSpaceGB/$sizeGB) * 100, 2))%"
}

# 物理磁盘信息（使用Get-PhysicalDisk判断磁盘类型）
Write-Host "`n  物理磁盘信息:"
$physicalDisks = Get-PhysicalDisk
$win32Disks = Get-CimInstance -ClassName Win32_DiskDrive

foreach ($pd in $physicalDisks) {
    # 关联Win32_DiskDrive获取更多信息
    $win32Disk = $win32Disks | Where-Object { $_.DeviceID -match "PhysicalDrive$($pd.DeviceId)" }

    $sizeGB = if ($pd.Size) { $pd.Size / 1GB } else { 0 }

    # 确定磁盘类型
    switch ($pd.MediaType) {
        "SSD" { $diskType = "是 (SSD)" }
        "HDD" { $diskType = "否 (HDD)" }
        default { $diskType = "未知 ($($pd.MediaType))" }
    }

    Write-Host "    设备ID: PhysicalDrive$($pd.DeviceId)"
    Write-Host "    型号: $($win32Disk.Model)"
    Write-Host "    接口类型: $($win32Disk.InterfaceType)"
    Write-Host "    总容量: $($sizeGB.ToString('N2')) GB"
    Write-Host "    健康状态: $($pd.HealthStatus)"
    Write-Host "    是否为SSD: $diskType"
    Write-Host "    分区样式: $($pd.PartitionStyle)"
    Write-Host
}

# 6. 显卡信息（增强版，包含是否独立显卡和频率）
Write-Host "【显卡信息】" -ForegroundColor Green
$gpus = Get-CimInstance -ClassName Win32_VideoController
$pnpDevices = Get-CimInstance -ClassName Win32_PnPEntity

foreach ($gpu in $gpus) {
    # 判断是否为独立显卡
    $isDedicated = $false
    $pnpDevice = $pnpDevices | Where-Object { $_.PNPDeviceID -eq $gpu.PNPDeviceID }

    # 通过多个特征判断是否为独立显卡
    if ($pnpDevice) {
        $isDedicated = $pnpDevice.Name -match "NVIDIA|AMD|RTX|GTX|Radeon|GeForce" -or
            ($pnpDevice.Manufacturer -notmatch "Intel|Microsoft")
    }

    $gpuType = if ($isDedicated) { "独立显卡" } else { "集成显卡" }

    # 获取显卡频率信息（基础频率）
    $gpuFrequency = "未知"
    if ($gpu.AdapterDACType -and $gpu.MaxRefreshRate) {
        # 尝试从WMI获取
        $gpuFreqInfo = Get-CimInstance -ClassName Win32_VideoSettings | Where-Object { $_.VideoControllerDeviceID -eq $gpu.DeviceID }
        if ($gpuFreqInfo) {
            $gpuFrequency = "$($gpuFreqInfo.RefreshRate) Hz (刷新率)"
        }
    }

    # 对于NVIDIA显卡，可以尝试通过命令行获取更多信息
    if ($gpu.Name -match "NVIDIA" -and -not $gpuFrequency -match "\d+") {
        try {
            $nvidiaInfo = nvidia-smi --query-gpu=clocks.sm --format=csv,noheader,nounits 2>&1
            if ($nvidiaInfo -match "\d+") {
                $gpuFrequency = "$nvidiaInfo MHz (核心频率)"
            }
        }
        catch {
            # 忽略nvidia-smi不存在的情况
        }
    }

    Write-Host "  名称: $($gpu.Name)"
    Write-Host "  制造商: $($gpu.AdapterCompatibility)"
    Write-Host "  显卡类型: $gpuType"
    Write-Host "  显存: $([math]::Round(($gpu.AdapterRAM / 1GB), 2)) GB"
    Write-Host "  处理频率: $gpuFrequency"
    Write-Host "  分辨率: $($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)"
    Write-Host "  驱动版本: $($gpu.DriverVersion)"
    Write-Host
}

# 7. 网络适配器信息
#Write-Host "【网络适配器信息】" -ForegroundColor Green
#$nics = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
#foreach ($nic in $nics) {
#    Write-Host "  名称: $($nic.Description)"
#    Write-Host "  MAC地址: $($nic.MACAddress)"
#    Write-Host "  IP地址: $($nic.IPAddress -join ', ')"
#    Write-Host "  子网掩码: $($nic.IPSubnet -join ', ')"
#    Write-Host "  网关: $($nic.DefaultIPGateway -join ', ')"
#    Write-Host "  DNS服务器: $($nic.DNSServerSearchOrder -join ', ')"
#    Write-Host
#}

# 8. 显示器信息
Write-Host "【显示器信息】" -ForegroundColor Green
$monitors = Get-CimInstance -ClassName Win32_DesktopMonitor
foreach ($monitor in $monitors) {
    Write-Host "  名称: $($monitor.Name)"
    Write-Host "  制造商: $($monitor.Manufacturer)"
    Write-Host "  屏幕尺寸: $($monitor.ScreenWidth) x $($monitor.ScreenHeight) 像素"
    Write-Host "  状态: $($monitor.Status)"
    Write-Host
}

# 9. 电池信息（针对笔记本）
Write-Host "【电池信息】" -ForegroundColor Green
$batteries = Get-CimInstance -ClassName Win32_Battery
if ($batteries) {
    foreach ($battery in $batteries) {
        Write-Host "  名称: $($battery.Name)"
        Write-Host "  制造商: $($battery.Manufacturer)"
        Write-Host "  设计容量: $($battery.DesignCapacity) mWh"
        Write-Host "  剩余容量: $($battery.RemainingCapacity) mWh"
        Write-Host "  电池状态: $($battery.Status)"
        Write-Host "  预计剩余时间: $($battery.EstimatedRunTime) 分钟"
        Write-Host
    }
}
else {
    Write-Host "  未检测到电池（可能是台式机）" -ForegroundColor Yellow
    Write-Host
}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "              硬件信息报告结束                " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
