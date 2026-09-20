@echo off
rem ============================================================================
rem  硬件检测脚本：采集【全部硬件】信息（概览/主板/CPU/硬盘/内存/显卡/显示器/其他）
rem  - 纯 Windows 自带能力实现（批处理引导 PowerShell，走 WMI）
rem  - 无需安装任何第三方软件；普通用户权限即可运行（部分寿命/通电数据需管理员）
rem  - 输出三处：
rem      1) 控制台直接打印（仿"鲁大师详细报表"的 字段:值 排版）
rem      2) 脚本同目录生成 TXT  报告：硬件检测报告_时间戳.txt
rem      3) 脚本同目录生成 HTML 报告：硬件检测报告_时间戳.html
rem  - 兼容 Windows 7 / 8 / 10 / 11（PowerShell 2.0 及以上）
rem  - Win7 无 Storage 模块时自动回退 WMI（Win32_DiskDrive + 关联查询）
rem  - 用法：双击运行，或在 CMD 中执行本脚本
rem ============================================================================
setlocal
chcp 65001 >nul
title 硬件信息采集
rem 说明：#PS_BEGIN# 之后的内容是 PowerShell 脚本，由 PowerShell 以 UTF-8 读取，
rem       从而彻底规避批处理中文乱码问题；cmd 执行到 exit /b 后不会再解析后面的行。
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$all=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8) -split '#PS_BEGIN#'; $code=$all[$all.Count-1]; $script:OutDir='%~dp0'; Invoke-Expression $code"
echo.
echo 脚本执行结束，报告文件已生成到脚本所在目录。
pause
endlocal
exit /b 0

#PS_BEGIN#
# ============================================================================
#  PowerShell 部分：全硬件信息采集
#  兼容 PowerShell 2.0+（Windows 7 及以上）
#  注意：本部分刻意避免使用 PS3.0+ 语法（如 [pscustomobject]、Get-CimInstance、
#        Add-Member -NotePropertyName、Get-CimAssociatedInstance 等）
# ============================================================================
$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# ----------------------------------------------------------------------------
# 0. 通用工具函数
# ----------------------------------------------------------------------------

function Get-Clean([object]$v) {
    if ($null -eq $v) { return '' }
    return ([string]$v).Trim()
}

function Format-Capacity([long]$bytes) {
    if (-not $bytes -or $bytes -le 0) { return '未知' }
    $gb = $bytes / 1GB
    if ($gb -ge 1000) { return ('{0:0.##} TB' -f ($bytes / 1TB)) }
    return ('{0:0.#} GB' -f $gb)
}

function Get-DdrType([int]$code) {
    switch ($code) {
        20 { 'DDR' }
        21 { 'DDR2' }
        22 { 'DDR2 FB-DIMM' }
        24 { 'DDR3' }
        25 { 'LPDDR3' }
        26 { 'DDR4' }
        27 { 'LPDDR4' }
        28 { 'LPDDR4X' }
        30 { 'LPDDR5' }
        34 { 'DDR5' }
        default { "未知(类型代码 $code)" }
    }
}

function Get-FormFactor([int]$code) {
    switch ($code) {
        8  { 'DIMM（台式机内存）' }
        12 { 'SODIMM（笔记本内存）' }
        13 { 'SRIMM' }
        11 { 'RIMM' }
        7  { 'SIMM' }
        default { "其他(代码 $code)" }
    }
}

function Get-MediaText([string]$m) {
    switch ($m) {
        'SSD'         { '固态硬盘(SSD)' }
        'HDD'         { '机械硬盘(HDD)' }
        'SCM'         { '存储级内存(SCM)' }
        'Unspecified' { '未指定' }
        default       { if ($m) { $m } else { '未知' } }
    }
}

function Get-BusInfo([string]$bus) {
    switch ($bus) {
        'SATA' { @('SATA（串行ATA）', 'SATA III 理论 600 MB/秒') }
        'NVMe' { @('NVMe（PCIe 通道）', '理论速率取决于 PCIe 代次与通道数（如 PCIe3.0 x4 ≈ 4000 MB/秒）') }
        'USB'  { @('USB（外接移动盘）', '实际速率取决于 USB 接口版本（2.0≈40MB/s，3.0≈400MB/s）') }
        'SAS'  { @('SAS', 'SAS 理论 6/12 Gbps') }
        'IDE'  { @('PATA/IDE', 'IDE 理论 133 MB/秒') }
        'RAID' { @('RAID 阵列', '速率取决于阵列卡') }
        default {
            if ($bus) { return @($bus, '未知') } else { return @('未知', '未知') }
        }
    }
}

function Get-HealthText([string]$s) {
    switch ($s) {
        'Healthy'   { '健康(Healthy)' }
        'Warning'   { '警告(Warning)' }
        'Unhealthy' { '异常(Unhealthy)' }
        default     { if ($s) { $s } else { '未知' } }
    }
}

# 手动 HTML 转义（兼容 .NET 2.0+，不依赖 System.Web / Net.WebUtility）
function Html-Escape([object]$s) {
    $str = [string]$s
    if ($null -eq $str) { return '' }
    $str = $str -replace '&', '&amp;'
    $str = $str -replace '<', '&lt;'
    $str = $str -replace '>', '&gt;'
    $str = $str -replace '"', '&quot;'
    return $str
}

# 控制台对齐
function Get-DisplayLen([string]$s) {
    $n = 0
    foreach ($ch in $s.ToCharArray()) {
        if ([int]$ch -gt 127) { $n += 2 } else { $n += 1 }
    }
    return $n
}
function Align-Pad([string]$s, [int]$width) {
    $s = [string]$s
    $diff = $width - (Get-DisplayLen $s)
    if ($diff -gt 0) { return $s + (' ' * $diff) }
    return $s
}

# 文本报告收集器
$script:ReportLines = New-Object System.Collections.Generic.List[string]
function Write-Report([string]$s = '') {
    $script:ReportLines.Add($s) | Out-Null
    Write-Host $s
}
function Write-Header([string]$s) {
    $script:ReportLines.Add($s) | Out-Null
    Write-Host $s -ForegroundColor Cyan
}
function Write-KV([string]$key, [object]$value, [int]$keyWidth = 12) {
    if ($null -eq $value -or ([string]$value).Trim() -eq '') { $value = '未知 / 不支持' }
    Write-Report ('  ' + (Align-Pad $key $keyWidth) + ' : ' + [string]$value)
}

# 设备小节数据结构（PS2.0 兼容）
function New-Section([string]$title, [string]$headKey, [string]$headValue) {
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name Title     -Value $title
    $obj | Add-Member -MemberType NoteProperty -Name HeadKey   -Value $headKey
    $obj | Add-Member -MemberType NoteProperty -Name HeadValue -Value $headValue
    $obj | Add-Member -MemberType NoteProperty -Name Rows      -Value (New-Object System.Collections.Generic.List[object])
    $obj | Add-Member -MemberType NoteProperty -Name Subs      -Value (New-Object System.Collections.Generic.List[string])
    return $obj
}

$memSections    = New-Object System.Collections.Generic.List[object]
$diskSections   = New-Object System.Collections.Generic.List[object]
$boardSections  = New-Object System.Collections.Generic.List[object]
$cpuSections    = New-Object System.Collections.Generic.List[object]
$gpuSections    = New-Object System.Collections.Generic.List[object]
$monitorSections= New-Object System.Collections.Generic.List[object]
$otherSections  = New-Object System.Collections.Generic.List[object]

# ----------------------------------------------------------------------------
# 1. 采集内存信息
# ----------------------------------------------------------------------------
Write-Report '正在采集内存信息 ...'
$memSticks = @(Get-WmiObject Win32_PhysicalMemory | Sort-Object DeviceLocator)
$memArray  = Get-WmiObject Win32_PhysicalMemoryArray
$cs        = Get-WmiObject Win32_ComputerSystem

$stickIndex = 0
[long]$memCapacitySum = 0
foreach ($stick in $memSticks) {
    $stickIndex++
    $capacity  = Format-Capacity $stick.Capacity
    $memCapacitySum += [long]$stick.Capacity
    $ddrType   = Get-DdrType ([int]$stick.SMBIOSMemoryType)
    $speed     = [int]$stick.Speed
    $cfgSpeed  = [int]$stick.ConfiguredClockSpeed
    $maker     = Get-Clean $stick.Manufacturer; if (-not $maker) { $maker = '未知' }
    $partNo    = Get-Clean $stick.PartNumber
    $serial    = Get-Clean $stick.SerialNumber
    $locator   = Get-Clean $stick.DeviceLocator
    $bank      = Get-Clean $stick.BankLabel
    $dataWidth = [int]$stick.DataWidth
    $totWidth  = [int]$stick.TotalWidth

    $volt = [int]$stick.ConfiguredVoltage
    if ($volt -le 0) { $volt = [int](($stick.MinVoltage + $stick.MaxVoltage) / 2) }
    if ($volt -gt 0) { $voltText = ('{0:0.##} V' -f ($volt / 1000.0)) } else { $voltText = '未知' }

    $widthText = "$dataWidth Bits"
    if ($totWidth -gt $dataWidth) { $widthText += "（总位宽 $totWidth Bits，带 ECC 校验）" }

    $sec = New-Section ("内存条 $stickIndex") $locator ("$maker $ddrType ${speed}MHz $capacity")
    $sec.Rows.Add(@('容量',           $capacity))
    $sec.Rows.Add(@('内存类型',       $ddrType))
    $sec.Rows.Add(@('标称频率',       "$speed MHz"))
    if ($cfgSpeed -gt 0) { $sec.Rows.Add(@('当前配置频率', "$cfgSpeed MHz")) }
    $sec.Rows.Add(@('制造日期',       'WMI 不提供（该数据存储于 SPD 芯片，需专用工具读取）'))
    $sec.Rows.Add(@('型号(PartNumber)', $partNo))
    $sec.Rows.Add(@('序列号',         $serial))
    $sec.Rows.Add(@('厂商',           $maker))
    $sec.Rows.Add(@('插槽位置',       $(if ($bank) { "$locator（$bank）" } else { $locator })))
    $sec.Rows.Add(@('模块位宽',       $widthText))
    $sec.Rows.Add(@('模块电压',       $voltText))
    $sec.Rows.Add(@('外形规格',       (Get-FormFactor ([int]$stick.FormFactor))))
    $memSections.Add($sec)
}

$slotTotal  = [int]$memArray.MemoryDevices
$slotUsed   = $memSticks.Count
$osVisible  = Format-Capacity ([long]$cs.TotalPhysicalMemory)
$memSummary = "物理内存合计 $(Format-Capacity $memCapacitySum)，操作系统可见 $osVisible，" +
              "共 $slotUsed 条内存条 / 主板内存插槽总数 $slotTotal 个（空闲 $($slotTotal-$slotUsed) 个）"

# 概览用的内存简描述
$memBrief = ''
if ($memSticks.Count -gt 0) {
    $firstStick = $memSticks[0]
    $memBrief = ("{0} ( {1} {2} {3}MHz {4} x {5} )" -f `
        (Format-Capacity $memCapacitySum),
        (Get-Clean $firstStick.Manufacturer),
        (Get-DdrType ([int]$firstStick.SMBIOSMemoryType)),
        [int]$firstStick.Speed,
        (Format-Capacity $firstStick.Capacity),
        $memSticks.Count)
}

# ----------------------------------------------------------------------------
# 2. 采集磁盘信息
# ----------------------------------------------------------------------------
Write-Report '正在采集磁盘信息 ...'
$diskIndex = 0

$hasStorageModule = $false
$storageCmd = Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue
if ($storageCmd) { $hasStorageModule = $true }

if ($hasStorageModule) {
    $physDisks = @(Get-PhysicalDisk | Sort-Object DeviceId)
    foreach ($pd in $physDisks) {
        $diskIndex++
        $media   = Get-MediaText ([string]$pd.MediaType)
        $bus     = Get-BusInfo ([string]$pd.BusType)
        $sizeTxt = Format-Capacity ([long]$pd.Size)
        $fw      = Get-Clean $pd.FirmwareVersion
        $sn      = Get-Clean $pd.SerialNumber
        $model   = Get-Clean $pd.FriendlyName

        $subLines = New-Object System.Collections.Generic.List[string]
        $partStyle = '未知'
        $diskNo = '-'
        try {
            $msDisk = @($pd | Get-Disk)
            if ($msDisk.Count -gt 0) {
                $msDisk = $msDisk[0]
                $diskNo = [string]$msDisk.Number
                $partStyle = [string]$msDisk.PartitionStyle
                $parts = @($msDisk | Get-Partition)
                foreach ($p in $parts) {
                    $vols = @($p | Get-Volume)
                    foreach ($v in $vols) {
                        $letter = if ($v.DriveLetter) { "$($v.DriveLetter):" } else { '无盘符' }
                        $fs = if ($v.FileSystem) { $v.FileSystem } else { '未格式化/保留分区' }
                        $vSize = Format-Capacity ([long]$v.Size)
                        $vFree = Format-Capacity ([long]$v.SizeRemaining)
                        if ($v.Size -gt 0) {
                            $usedPct = [math]::Round(100 * ($v.Size - $v.SizeRemaining) / $v.Size, 1)
                        } else { $usedPct = 0 }
                        $subLines.Add(("分区 {0} [{1}] 总容量 {2}，可用 {3}，已用 {4}%（分区大小 {5}）" -f `
                            $letter, $fs, $vSize, $vFree, $usedPct, (Format-Capacity ([long]$p.Size))))
                    }
                }
            }
        } catch {
            $subLines.Add('分区/卷信息读取失败：' + $_.Exception.Message)
        }

        $powerOn = '不支持 / 需管理员权限'
        $cycle   = '不支持'
        $tempC   = '不支持'
        $wear    = '不支持'
        try {
            $rc = $pd | Get-StorageReliabilityCounter
            if ($rc) {
                if ($rc.PowerOnHours -gt 0)      { $powerOn = "累计 $([int]$rc.PowerOnHours) 小时" }
                if ($rc.LoadUnloadCycleCount)    { $cycle  = "$([int]$rc.LoadUnloadCycleCount) 次（加载/卸载循环）" }
                if ($rc.Temperature)             { $tempC  = "$([int]$rc.Temperature) ℃" }
                if ($null -ne $rc.Wear -and $rc.Wear -ge 0) { $wear = "$([int]$rc.Wear)%" }
            }
        } catch {}

        $sec = New-Section ("硬盘 $diskIndex") '产品' ("$model（$media）")
        $sec.Rows.Add(@('大小',         $sizeTxt))
        $sec.Rows.Add(@('固件版本',     $fw))
        $sec.Rows.Add(@('序列号',       $sn))
        $sec.Rows.Add(@('磁盘编号',     "磁盘 $diskNo"))
        $sec.Rows.Add(@('接口',         $bus[0]))
        $sec.Rows.Add(@('数据传输率',   $bus[1]))
        $sec.Rows.Add(@('介质类型',     $media))
        $sec.Rows.Add(@('分区形式',     $(if ($partStyle -eq 'GPT') { 'GPT' } elseif ($partStyle -eq 'MBR') { 'MBR' } else { $partStyle })))
        $sec.Rows.Add(@('健康状态',     (Get-HealthText ([string]$pd.HealthStatus))))
        $sec.Rows.Add(@('运行状态',     [string]$pd.OperationalStatus))
        $sec.Rows.Add(@('硬盘已使用',   $powerOn))
        $sec.Rows.Add(@('启停/循环次数',$cycle))
        $sec.Rows.Add(@('温度',         $tempC))
        $sec.Rows.Add(@('SSD磨损度',    $wear))
        foreach ($sl in $subLines) { $sec.Subs.Add($sl) }
        $diskSections.Add($sec)
    }
} else {
    $oldDisks = @(Get-WmiObject Win32_DiskDrive)
    foreach ($dd in $oldDisks) {
        $diskIndex++
        $model   = Get-Clean $dd.Model
        $ifType  = Get-Clean $dd.InterfaceType
        $sizeTxt = Format-Capacity ([long]$dd.Size)
        $fw      = Get-Clean $dd.FirmwareRevision
        $sn      = Get-Clean $dd.SerialNumber

        $sec = New-Section ("硬盘 $diskIndex") '产品' ("$model（$ifType）")
        $sec.Rows.Add(@('大小',       $sizeTxt))
        $sec.Rows.Add(@('固件版本',   $fw))
        $sec.Rows.Add(@('序列号',     $sn))
        $sec.Rows.Add(@('接口',       $ifType))
        $sec.Rows.Add(@('分区数量',   [string]$dd.Partitions))
        $sec.Rows.Add(@('状态',       [string]$dd.Status))

        try {
            $diskDevId = $dd.DeviceID -replace '\\', '\\'
            $parts = @(Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$diskDevId'} WHERE ResultClass=Win32_DiskPartition")
            foreach ($pt in $parts) {
                $ptDevId = $pt.DeviceID -replace '\\', '\\'
                $logs = @(Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$ptDevId'} WHERE ResultClass=Win32_LogicalDisk")
                foreach ($lg in $logs) {
                    $lgSize = Format-Capacity ([long]$lg.Size)
                    $lgFree = Format-Capacity ([long]$lg.FreeSpace)
                    $fs = if ($lg.FileSystem) { $lg.FileSystem } else { '未格式化' }
                    $sec.Subs.Add(("分区 {0} [{1}] 总容量 {2}，可用 {3}" -f $lg.DeviceID, $fs, $lgSize, $lgFree))
                }
            }
        } catch {
            $sec.Subs.Add('分区信息读取失败：' + $_.Exception.Message)
        }
        $diskSections.Add($sec)
    }
}

# 概览用主硬盘
$mainDiskText = '未知'
if ($diskSections.Count -gt 0) {
    $mainDiskText = $diskSections[0].HeadValue
}

# ----------------------------------------------------------------------------
# 3. 采集主板信息（Win32_BaseBoard + Win32_BIOS + 芯片组推断）
# ----------------------------------------------------------------------------
Write-Report '正在采集主板信息 ...'
$baseboard = Get-WmiObject Win32_BaseBoard
$bios      = Get-WmiObject Win32_BIOS

# 芯片组：从 PnP 设备中推断（WMI 无专用芯片组类）
$chipsetName = '未知'
try {
    $pnpDevices = @(Get-WmiObject Win32_PnPEntity)
    foreach ($dev in $pnpDevices) {
        $dn = Get-Clean $dev.Name
        if ($dn -match 'chipset|LPC|PCI Express Root Complex|ISA Bridge|Server Management') {
            $chipsetName = $dn
            break
        }
    }
} catch {}

# BIOS 发布日期转换（WMI 返回格式如 20220715000000.000000+000）
$biosDateText = '未知'
try {
    if ($bios.ReleaseDate) {
        $biosDateText = ([Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)).ToString('yyyy/MM/dd')
    }
} catch {}

# BIOS 大小（KB）
$biosSizeText = '未知'
if ($bios.BIOSVersion -is [array]) {
    $biosVerText = Get-Clean $bios.SMBIOSBIOSVersion
    if (-not $biosVerText) { $biosVerText = $bios.BIOSVersion[-1] }
} else {
    $biosVerText = Get-Clean $bios.SMBIOSBIOSVersion
    if (-not $biosVerText) { $biosVerText = Get-Clean $bios.Version }
}

$boardSec = New-Section '主板' '主板型号' ((Get-Clean $baseboard.Manufacturer) + ' ' + (Get-Clean $baseboard.Product))
$boardSec.Rows.Add(@('芯片组',     $chipsetName))
$boardSec.Rows.Add(@('序列号',     (Get-Clean $baseboard.SerialNumber)))
$boardSec.Rows.Add(@('主板版本',   (Get-Clean $baseboard.Version)))
$boardSec.Rows.Add(@('BIOS',       ((Get-Clean $bios.Manufacturer) + ' ' + $biosVerText + '  /  BIOS程序发布日期: ' + $biosDateText)))
$boardSections.Add($boardSec)

# 概览用主板简描述
$boardBrief = (Get-Clean $baseboard.Manufacturer) + ' ' + (Get-Clean $baseboard.Product)
if ($chipsetName -ne '未知') { $boardBrief += "（$chipsetName）" }

# ----------------------------------------------------------------------------
# 4. 采集处理器信息（Win32_Processor）
# ----------------------------------------------------------------------------
Write-Report '正在采集处理器信息 ...'
$cpus = @(Get-WmiObject Win32_Processor)
$cpuIndex = 0
foreach ($cpu in $cpus) {
    $cpuIndex++
    $cpuName  = Get-Clean $cpu.Name
    $cpuSpeed = [int]$cpu.MaxClockSpeed
    $cores    = [int]$cpu.NumberOfCores
    $threads  = [int]$cpu.NumberOfLogicalProcessors
    $socket   = Get-Clean $cpu.SocketDesignation
    $l2cache  = [int]$cpu.L2CacheSize
    $l3cache  = [int]$cpu.L3CacheSize
    $manufacturer = Get-Clean $cpu.Manufacturer

    # 核心数中文描述
    $coreText = ''
    switch ($cores) {
        1  { $coreText = '单核' }
        2  { $coreText = '双核' }
        4  { $coreText = '四核' }
        6  { $coreText = '六核' }
        8  { $coreText = '八核' }
        12 { $coreText = '十二核' }
        16 { $coreText = '十六核' }
        default { $coreText = "$cores 核" }
    }

    $headValue = "$cpuName @ $($cpuSpeed/1000.0)GHz $coreText"
    $sec = New-Section ("处理器 $cpuIndex") '处理器' $headValue
    $sec.Rows.Add(@('速度',         ('{0:0.##} GHz' -f ($cpuSpeed / 1000.0))))
    $sec.Rows.Add(@('处理器数量',   "核心数：$cores / 线程数：$threads"))
    $sec.Rows.Add(@('插槽/插座',    $socket))
    # 一级缓存 WMI 不提供（需 CPUID 指令），如实标注
    $sec.Rows.Add(@('一级数据缓存', 'WMI 不提供（需 CPUID 指令读取）'))
    $sec.Rows.Add(@('一级代码缓存', 'WMI 不提供（需 CPUID 指令读取）'))
    if ($l2cache -gt 0) {
        $sec.Rows.Add(@('二级缓存', ("{0} x {1} KB" -f $cores, $l2cache)))
    } else { $sec.Rows.Add(@('二级缓存', '未知')) }
    if ($l3cache -gt 0) {
        $sec.Rows.Add(@('三级缓存', ("{0} MB" -f ($l3cache / 1024))))
    } else { $sec.Rows.Add(@('三级缓存', '未知')) }
    $sec.Rows.Add(@('特征',         'WMI 不提供 CPUID 指令集特征位（MMX/SSE/AVX 等需专用工具读取）'))
    $sec.Rows.Add(@('厂商',         $manufacturer))
    $cpuSections.Add($sec)
}

# 概览用 CPU 简描述
$cpuBrief = '未知'
if ($cpuSections.Count -gt 0) {
    $cpuBrief = $cpuSections[0].HeadValue
}

# ----------------------------------------------------------------------------
# 5. 采集显卡信息（Win32_VideoController）
# ----------------------------------------------------------------------------
Write-Report '正在采集显卡信息 ...'
$gpus = @(Get-WmiObject Win32_VideoController)
$gpuIndex = 0
foreach ($gpu in $gpus) {
    $gpuIndex++
    $gpuName  = Get-Clean $gpu.Name
    # AdapterRAM 是 UInt32，大于 4GB 可能溢出；直接转 long 处理
    [long]$vramBytes = 0
    try { $vramBytes = [long]$gpu.AdapterRAM } catch {}
    $vramText = Format-Capacity $vramBytes
    $driverVer = Get-Clean $gpu.DriverVersion
    $driverDate = '未知'
    try {
        if ($gpu.DriverDate) {
            $driverDate = ([Management.ManagementDateTimeConverter]::ToDateTime($gpu.DriverDate)).ToString('yyyyMMdd')
        }
    } catch {}
    $chipMaker = Get-Clean $gpu.AdapterCompatibility
    $videoProc = Get-Clean $gpu.VideoProcessor
    $refreshRate = [int]$gpu.CurrentRefreshRate
    $hRes = [int]$gpu.CurrentHorizontalResolution
    $vRes = [int]$gpu.CurrentVerticalResolution
    $bpp  = [int]$gpu.CurrentBitsPerPixel

    $sec = New-Section ("显卡 $gpuIndex") $(if ($gpuIndex -eq 1) { '主显卡' } else { '显卡' }) $gpuName
    $sec.Rows.Add(@('显存',         $vramText))
    if ($refreshRate -gt 0) {
        $sec.Rows.Add(@('频率',         "核心: 未知 / 显存: 未知（当前刷新率 ${refreshRate}Hz）"))
    } else {
        $sec.Rows.Add(@('频率',         'WMI 不提供核心/显存频率（需读取显卡 BIOS 或专用工具）'))
    }
    $sec.Rows.Add(@('显卡制造商',   'WMI 不提供板卡厂商（仅提供芯片厂商）'))
    $sec.Rows.Add(@('芯片制造商',   $chipMaker))
    if ($videoProc) { $sec.Rows.Add(@('视频处理器', $videoProc)) }
    $sec.Rows.Add(@('BIOS版本',     'WMI 不提供显卡 VBIOS 版本'))
    $sec.Rows.Add(@('驱动版本',     $driverVer))
    $sec.Rows.Add(@('驱动日期',     $driverDate))
    if ($hRes -gt 0 -and $vRes -gt 0) {
        $sec.Rows.Add(@('当前分辨率', "$hRes x $vRes $bpp 位真彩色"))
    }
    $gpuSections.Add($sec)
}

# 概览用显卡简描述
$gpuBrief = '未知'
if ($gpuSections.Count -gt 0) {
    $g = $gpuSections[0]
    $vram = '未知'
    foreach ($r in $g.Rows) { if ($r[0] -eq '显存') { $vram = $r[1] } }
    $gpuBrief = "$($g.HeadValue) ( $vram )"
}

# ----------------------------------------------------------------------------
# 6. 采集显示器信息（Win32_DesktopMonitor）
# ----------------------------------------------------------------------------
Write-Report '正在采集显示器信息 ...'
$monitors = @(Get-WmiObject Win32_DesktopMonitor)
$monIndex = 0
foreach ($mon in $monitors) {
    $monIndex++
    $monName  = Get-Clean $mon.Name
    $monMaker = Get-Clean $mon.MonitorManufacturer
    $monType  = Get-Clean $mon.MonitorType
    $screenH  = [int]$mon.ScreenHeight
    $screenW  = [int]$mon.ScreenWidth
    $monYear  = Get-Clean $mon.MonitorManufactureYear
    $monWeek  = Get-Clean $mon.MonitorManufactureWeek

    # 物理屏幕尺寸 WMI 不直接提供（需解析 EDID），标注说明
    $sizeText = 'WMI 不提供物理尺寸（需解析 EDID，可通过显示器型号推断）'

    $displayName = $monName
    if (-not $displayName) { $displayName = $monType }
    if (-not $displayName) { $displayName = '通用即插即用监视器' }

    $sec = New-Section ("显示器 $monIndex") '产品' $displayName
    $sec.Rows.Add(@('厂商',           $(if ($monMaker) { $monMaker } else { '未知' })))
    if ($monYear -and $monWeek) {
        $sec.Rows.Add(@('固件程序日期', "$monYear 年 $monWeek 周"))
    }
    $sec.Rows.Add(@('屏幕尺寸',       $sizeText))
    $sec.Rows.Add(@('显示比例',       'WMI 不提供（需 EDID 详细时序数据）'))
    if ($screenW -gt 0 -and $screenH -gt 0) {
        $sec.Rows.Add(@('分辨率',       "$screenW x $screenH"))
    } else {
        $sec.Rows.Add(@('分辨率',       '未知（当前未激活或 WMI 未返回）'))
    }
    $sec.Rows.Add(@('Gamma',          'WMI 不提供'))
    $sec.Rows.Add(@('电源管理',       'WMI 不提供'))
    $monitorSections.Add($sec)
}

# 概览用显示器简描述
$monitorBrief = '未知'
if ($monitorSections.Count -gt 0) {
    $monitorBrief = $monitorSections[0].HeadValue
}

# ----------------------------------------------------------------------------
# 7. 采集其他设备（网卡 / 声卡 / 键盘 / 鼠标）
# ----------------------------------------------------------------------------
Write-Report '正在采集其他设备信息 ...'

# 网卡：筛选物理适配器
$nics = @(Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true -and $_.MACAddress -and $_.Name -notmatch 'virtual|vpn|tap|wan|miniport|debug|kernel|rdma|storage|isatap|teredo|6to4|direct|packet|cisco|vmware|virtualbox|hyper-v|secTap|sangfor|easyconnect' })
foreach ($nic in $nics) {
    $nicName = Get-Clean $nic.Name
    if ($nicName) {
        $sec = New-Section '网卡' '网卡' $nicName
        $sec.Rows.Add(@('MAC地址', (Get-Clean $nic.MACAddress)))
        $sec.Rows.Add(@('连接状态', $(if ($nic.NetConnectionStatus -eq 2) { '已连接' } else { '未连接/禁用' })))
        $otherSections.Add($sec)
    }
}

# 声卡
$sounds = @(Get-WmiObject Win32_SoundDevice)
foreach ($snd in $sounds) {
    $sndName = Get-Clean $snd.Name
    if ($sndName) {
        $sec = New-Section '声卡' '声卡' $sndName
        $sec.Rows.Add(@('状态', (Get-Clean $snd.Status)))
        $otherSections.Add($sec)
    }
}

# 键盘
$keyboards = @(Get-WmiObject Win32_Keyboard)
foreach ($kb in $keyboards) {
    $kbName = Get-Clean $kb.Name
    if ($kbName) {
        $sec = New-Section '键盘' '键盘' $kbName
        $otherSections.Add($sec)
    }
}

# 鼠标
$mice = @(Get-WmiObject Win32_PointingDevice)
foreach ($mouse in $mice) {
    $mouseName = Get-Clean $mouse.Name
    if ($mouseName) {
        $sec = New-Section '鼠标' '鼠标' $mouseName
        $otherSections.Add($sec)
    }
}

# 概览用声卡/网卡简描述
$soundBrief = '未知'
foreach ($s in $otherSections) {
    if ($s.Title -eq '声卡') { $soundBrief = $s.HeadValue; break }
}
$nicBrief = '未知'
foreach ($s in $otherSections) {
    if ($s.Title -eq '网卡') { $nicBrief = $s.HeadValue; break }
}

# ----------------------------------------------------------------------------
# 8. 文本报告渲染
# ----------------------------------------------------------------------------
$os = Get-WmiObject Win32_OperatingSystem
$now = Get-Date
$line = ('=' * 72)
$computerModel = (Get-Clean $cs.Manufacturer) + ' ' + (Get-Clean $cs.Model)
$osText = (Get-Clean $os.Caption) + ' ' + (Get-Clean $os.OSArchitecture) + '（内部版本 ' + $os.Version + '）'
$timeText = $now.ToString('yyyy-MM-dd HH:mm:ss')

Write-Header $line
Write-Header '                    硬件详细报表'
Write-Header $line
Write-KV '计算机名'  $cs.Name
Write-KV '电脑型号'  ((Get-Clean $cs.Manufacturer) + ' ' + (Get-Clean $cs.Model))
Write-KV '操作系统'  ((Get-Clean $os.Caption) + ' ' + (Get-Clean $os.OSArchitecture) + '（内部版本 ' + $os.Version + '）')
Write-KV '检测时间'  ($now.ToString('yyyy-MM-dd HH:mm:ss'))
Write-Report ''

Write-Header $line
Write-Header ' 概览'
Write-Header $line
Write-KV '电脑型号'  $computerModel 14
Write-KV '操作系统'  $osText 14
Write-KV '处理器'    $cpuBrief 14
Write-KV '主板'      $boardBrief 14
Write-KV '显卡'      $gpuBrief 14
Write-KV '内存'      $memBrief 14
Write-KV '主硬盘'    $mainDiskText 14
Write-KV '显示器'    $monitorBrief 14
Write-KV '声卡'      $soundBrief 14
Write-KV '网卡'      $nicBrief 14
Write-Report ''

function Write-SectionGroup([string]$title, $sections) {
    Write-Header $line
    Write-Header (" $title（共 $($sections.Count) 项）")
    Write-Header $line
    Write-Report ''
    foreach ($s in $sections) {
        Write-Header ('  [' + $s.Title + '] ' + $s.HeadKey + ' : ' + $s.HeadValue)
        foreach ($r in $s.Rows) { Write-KV $r[0] $r[1] 14 }
        if ($s.Subs.Count -gt 0) {
            Write-Report '  -- 分区与卷 --'
            foreach ($sub in $s.Subs) { Write-Report ('     ' + $sub) }
        }
        Write-Report ''
    }
}

Write-SectionGroup '主板'   $boardSections
Write-SectionGroup '处理器' $cpuSections
Write-SectionGroup '硬盘'   $diskSections
Write-SectionGroup '内存'   $memSections
Write-SectionGroup '显卡'   $gpuSections
Write-SectionGroup '显示器' $monitorSections
Write-SectionGroup '其他设备' $otherSections

Write-Header $line
Write-Report '说明：制造日期、CPU一级缓存/指令集特征、显卡核心频率、显示器物理尺寸等信息'
Write-Report '      烧录在设备固件/SPD/EDID 中，WMI 不提供，脚本只输出系统可读取的真实数据。'
Write-Header $line

# ----------------------------------------------------------------------------
# 9. HTML 报告渲染（完全对齐 硬件检测报告.html 的行内样式格式）
# ----------------------------------------------------------------------------
$pStyle    = 'margin: 2px 0;display: flex;justify-content: flex-start;align-items: center;'
$spanStyle = 'width: 300px'
$h3Style   = 'border-bottom:1px solid #000;line-height: 50px'

function Render-HtmlRow([string]$key, [string]$value) {
    return '  <p style="' + $pStyle + '"><span style="' + $spanStyle + '">' + (Html-Escape $key) + '</span><span>' + (Html-Escape $value) + '</span></p>' + "`r`n"
}

function Render-HtmlSection($sec) {
    $h = Render-HtmlRow $sec.HeadKey $sec.HeadValue
    foreach ($r in $sec.Rows) {
        $h += Render-HtmlRow $r[0] $r[1]
    }
    if ($sec.Subs.Count -gt 0) {
        foreach ($sub in $sec.Subs) {
            $h += Render-HtmlRow '分区/卷' $sub
        }
    }
    return $h
}

function Render-HtmlSections($sections) {
    $h = ''
    $count = $sections.Count
    $i = 0
    foreach ($s in $sections) {
        $i++
        $h += Render-HtmlSection $s
        if ($i -lt $count) {
            $h += '  <p style="' + $pStyle + '"><span style="' + $spanStyle + '">&nbsp;</span><span>&nbsp;</span></p>' + "`r`n"
        }
        $h += "`r`n"
    }
    return $h
}

$computerModel = (Get-Clean $cs.Manufacturer) + ' ' + (Get-Clean $cs.Model)
$osText = (Get-Clean $os.Caption) + ' ' + (Get-Clean $os.OSArchitecture) + '（内部版本 ' + $os.Version + '）'
$timeText = $now.ToString('yyyy-MM-dd HH:mm:ss')
$reportId = [guid]::NewGuid().ToString()

$htmlDoc = @"
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1" />
    <title>硬件详细报表</title>
    <style>
      body{font-family: "Microsoft YaHei", 微软雅黑;}
    </style>
  </head>
  <body>
    <div class="container">
      <h3 style="$h3Style"> 硬件详细报表</h3>
$(Render-HtmlRow '软件版本' '硬件检测脚本 v3.0（Win7+ 兼容版）')
$(Render-HtmlRow '检测时间' $timeText)
$(Render-HtmlRow '计算机名' $cs.Name)
$(Render-HtmlRow '报告ID' $reportId)

 <h3 style="$h3Style"> 概览</h3>
$(Render-HtmlRow '电脑型号' $computerModel)
$(Render-HtmlRow '操作系统' $osText)
$(Render-HtmlRow '处理器' $cpuBrief)
$(Render-HtmlRow '主板' $boardBrief)
$(Render-HtmlRow '显卡' $gpuBrief)
$(Render-HtmlRow '内存' $memBrief)
$(Render-HtmlRow '主硬盘' $mainDiskText)
$(Render-HtmlRow '显示器' $monitorBrief)
$(Render-HtmlRow '声卡' $soundBrief)
$(Render-HtmlRow '网卡' $nicBrief)

 <h3 style="$h3Style"> 主板</h3>
$(Render-HtmlSections $boardSections)
 <h3 style="$h3Style"> 处理器</h3>
$(Render-HtmlSections $cpuSections)
 <h3 style="$h3Style"> 硬盘</h3>
$(Render-HtmlSections $diskSections)
 <h3 style="$h3Style"> 内存</h3>
$(Render-HtmlSections $memSections)
 <h3 style="$h3Style"> 显卡</h3>
$(Render-HtmlSections $gpuSections)
 <h3 style="$h3Style"> 显示器</h3>
$(Render-HtmlSections $monitorSections)
 <h3 style="$h3Style"> 其他设备</h3>
$(Render-HtmlSections $otherSections)
    </div>
  </body>
</html>
"@

# ----------------------------------------------------------------------------
# 10. 落盘保存
# ----------------------------------------------------------------------------
if (-not $script:OutDir) { $script:OutDir = $PWD.Path + '\' }
$stamp = $now.ToString('yyyyMMdd_HHmmss')
$txtPath  = Join-Path $script:OutDir ("硬件检测报告_{0}.txt"  -f $stamp)
$htmlPath = Join-Path $script:OutDir ("硬件检测报告_{0}.html" -f $stamp)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$txtContent = ($script:ReportLines -join "`r`n")
[IO.File]::WriteAllText($txtPath, $txtContent, $utf8NoBom)
[IO.File]::WriteAllText($htmlPath, $htmlDoc, $utf8NoBom)

Write-Host ''
Write-Host ('TXT  报告已保存: ' + $txtPath)  -ForegroundColor Green
Write-Host ('HTML 报告已保存: ' + $htmlPath) -ForegroundColor Green
Write-Host '提示：以管理员身份运行可额外读取硬盘通电时长、温度、磨损度等可靠性计数。' -ForegroundColor Yellow
