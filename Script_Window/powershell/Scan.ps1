Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# 配置常量
$cacheFilePath = Join-Path $env:LOCALAPPDATA "FileSecurityManager\file_cache.dat"
$partialCachePath = Join-Path $env:LOCALAPPDATA "FileSecurityManager\partial_cache.dat"
$maxThreads = [Math]::Min(16, [Environment]::ProcessorCount * 2)
$scanDepth = 10

# 确保缓存目录存在
$cacheDir = Split-Path $cacheFilePath -Parent
if (-not (Test-Path $cacheDir)) {
    New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
}

# 全局变量
$script:allFiles = @()
$script:isScanning = $false
$script:scanJobs = @()
$script:totalDisks = 0
$script:completedDisks = 0
$script:scanTimer = $null
$script:currentFilesCount = 0
$script:stopRequested = $false

# 主窗口
$window = New-Object System.Windows.Window
$window.Title = "高速文件扫描工具"
$window.Width = 1300
$window.Height = 800
$window.MinWidth = 1100
$window.MinHeight = 700
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

# 资源字典与样式
$resources = New-Object System.Windows.ResourceDictionary
$buttonStyle = New-Object System.Windows.Style([System.Windows.Controls.Button])
$bgColor = [System.Windows.Media.Color]::FromArgb(255, 45, 125, 219)
$buttonStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty, [System.Windows.Media.SolidColorBrush]$bgColor)))
$buttonStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::White)))
$buttonStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::PaddingProperty, (New-Object System.Windows.Thickness(10, 5, 10, 5)))))
$buttonStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::MarginProperty, (New-Object System.Windows.Thickness(5)))))
$trigger = New-Object System.Windows.Trigger
$trigger.Property = [System.Windows.Controls.Button]::IsMouseOverProperty
$trigger.Value = $true
$hoverColor = [System.Windows.Media.Color]::FromArgb(255, 26, 102, 192)
$trigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty, [System.Windows.Media.SolidColorBrush]$hoverColor)))
$buttonStyle.Triggers.Add($trigger)
$resources.Add("ButtonStyle", $buttonStyle)
$window.Resources = $resources

# 主布局网格
$mainGrid = New-Object System.Windows.Controls.Grid
$mainGrid.Margin = 10
1..5 | ForEach-Object { $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) }
$mainGrid.RowDefinitions[0].Height = 50    # 标题
$mainGrid.RowDefinitions[1].Height = 60    # 控制栏
$mainGrid.RowDefinitions[2].Height = 120   # 筛选栏
$mainGrid.RowDefinitions[3].Height = "*"   # 内容区
$mainGrid.RowDefinitions[4].Height = 50    # 状态栏
$window.Content = $mainGrid

# 标题
$titleText = New-Object System.Windows.Controls.TextBlock
$titleText.Text = "高速文件扫描工具"
$titleText.FontSize = 18
$titleText.FontWeight = [System.Windows.FontWeights]::Bold
$titleText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$titleText.Margin = 5
[System.Windows.Controls.Grid]::SetRow($titleText, 0)
$mainGrid.Children.Add($titleText)

# 控制栏
$controlBar = New-Object System.Windows.Controls.StackPanel
$controlBar.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$controlBar.Margin = 5
[System.Windows.Controls.Grid]::SetRow($controlBar, 1)
$mainGrid.Children.Add($controlBar)

# 初始化按钮
$btnStartScan = New-Object System.Windows.Controls.Button
$btnStartScan.Content = "开始扫描"
$btnStartScan.Style = $window.Resources["ButtonStyle"]
$controlBar.Children.Add($btnStartScan)

$btnStopScan = New-Object System.Windows.Controls.Button
$btnStopScan.Content = "停止扫描"
$btnStopScan.Style = $window.Resources["ButtonStyle"]
$btnStopScan.IsEnabled = $false
$controlBar.Children.Add($btnStopScan)

$scanProgress = New-Object System.Windows.Controls.ProgressBar
$scanProgress.Width = 300
$scanProgress.Height = 20
$scanProgress.Margin = 5
$scanProgress.Visibility = [System.Windows.Visibility]::Hidden
$scanProgress.Value = 0
$controlBar.Children.Add($scanProgress)

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text = "就绪"
$statusText.Margin = 5
$statusText.MinWidth = 200
$controlBar.Children.Add($statusText)

# 筛选栏
$filterPanel = New-Object System.Windows.Controls.StackPanel
$filterPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$filterPanel.Margin = 5
[System.Windows.Controls.Grid]::SetRow($filterPanel, 2)
$mainGrid.Children.Add($filterPanel)

# 搜索框
$searchRow = New-Object System.Windows.Controls.StackPanel
$searchRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$filterPanel.Children.Add($searchRow)

$searchLabel = New-Object System.Windows.Controls.TextBlock
$searchLabel.Text = "文件名搜索:"
$searchLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$searchLabel.Margin = "0 0 5 0"
$searchLabel.Width = 80
$searchRow.Children.Add($searchLabel)

$searchBox = New-Object System.Windows.Controls.TextBox
$searchBox.Width = 200
$searchBox.Height = 28
$searchBox.Margin = 2
$searchBox.ToolTip = "输入文件名或路径关键字（留空则不过滤）"
$searchRow.Children.Add($searchBox)

# 时间范围
$dateRow = New-Object System.Windows.Controls.StackPanel
$dateRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$filterPanel.Children.Add($dateRow)

$startDateLabel = New-Object System.Windows.Controls.TextBlock
$startDateLabel.Text = "开始时间:"
$startDateLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$startDateLabel.Margin = "10 0 5 0"
$startDateLabel.Width = 70
$dateRow.Children.Add($startDateLabel)

$startDateTimeBox = New-Object System.Windows.Controls.TextBox
$startDateTimeBox.Width = 180
$startDateTimeBox.Height = 28
$startDateTimeBox.Margin = 2
$startDateTimeBox.Text = ""  # 初始为空
$startDateTimeBox.ToolTip = "格式: yyyy-MM-dd HH:mm:ss（留空则不过滤）"
$dateRow.Children.Add($startDateTimeBox)

$endDateLabel = New-Object System.Windows.Controls.TextBlock
$endDateLabel.Text = "结束时间:"
$endDateLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$endDateLabel.Margin = "10 0 5 0"
$endDateLabel.Width = 70
$dateRow.Children.Add($endDateLabel)

$endDateTimeBox = New-Object System.Windows.Controls.TextBox
$endDateTimeBox.Width = 180
$endDateTimeBox.Height = 28
$endDateTimeBox.Margin = 2
$endDateTimeBox.Text = ""  # 初始为空
$endDateTimeBox.ToolTip = "格式: yyyy-MM-dd HH:mm:ss（留空则不过滤）"
$dateRow.Children.Add($endDateTimeBox)

# 大小筛选
$sizeRow = New-Object System.Windows.Controls.StackPanel
$sizeRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$filterPanel.Children.Add($sizeRow)

$minSizeLabel = New-Object System.Windows.Controls.TextBlock
$minSizeLabel.Text = "最小大小:"
$minSizeLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$minSizeLabel.Margin = "10 0 5 0"
$minSizeLabel.Width = 70
$sizeRow.Children.Add($minSizeLabel)

$minSizeBox = New-Object System.Windows.Controls.TextBox
$minSizeBox.Width = 80
$minSizeBox.Height = 28
$minSizeBox.Margin = 2
$minSizeBox.Text = ""  # 初始为空
$minSizeBox.ToolTip = "留空则不过滤"
$sizeRow.Children.Add($minSizeBox)

$minSizeUnit = New-Object System.Windows.Controls.ComboBox
$minSizeUnit.Width = 60
$minSizeUnit.Height = 28
$minSizeUnit.Margin = 2
$minSizeUnit.Items.Add("B"); $minSizeUnit.Items.Add("KB"); $minSizeUnit.Items.Add("MB"); $minSizeUnit.Items.Add("GB")
$minSizeUnit.SelectedItem = "KB"
$sizeRow.Children.Add($minSizeUnit)

$maxSizeLabel = New-Object System.Windows.Controls.TextBlock
$maxSizeLabel.Text = "最大大小:"
$maxSizeLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$maxSizeLabel.Margin = "10 0 5 0"
$maxSizeLabel.Width = 70
$sizeRow.Children.Add($maxSizeLabel)

$maxSizeBox = New-Object System.Windows.Controls.TextBox
$maxSizeBox.Width = 80
$maxSizeBox.Height = 28
$maxSizeBox.Margin = 2
$maxSizeBox.Text = ""  # 初始为空
$maxSizeBox.ToolTip = "留空则不过滤"
$sizeRow.Children.Add($maxSizeBox)

$maxSizeUnit = New-Object System.Windows.Controls.ComboBox
$maxSizeUnit.Width = 60
$maxSizeUnit.Height = 28
$maxSizeUnit.Margin = 2
$maxSizeUnit.Items.Add("B"); $maxSizeUnit.Items.Add("KB"); $maxSizeUnit.Items.Add("MB"); $maxSizeUnit.Items.Add("GB")
$maxSizeUnit.SelectedItem = "MB"
$sizeRow.Children.Add($maxSizeUnit)

$btnSearch = New-Object System.Windows.Controls.Button
$btnSearch.Content = "搜索"
$btnSearch.Style = $window.Resources["ButtonStyle"]
$btnSearch.Margin = "20 0 0 0"
$sizeRow.Children.Add($btnSearch)

# 内容区域
$contentScroll = New-Object System.Windows.Controls.ScrollViewer
[System.Windows.Controls.Grid]::SetRow($contentScroll, 3)
$mainGrid.Children.Add($contentScroll)

$fileDataGrid = New-Object System.Windows.Controls.DataGrid
$fileDataGrid.AutoGenerateColumns = $false
$fileDataGrid.CanUserAddRows = $false
$fileDataGrid.IsReadOnly = $true
$fileDataGrid.SelectionMode = [System.Windows.Controls.DataGridSelectionMode]::Single
$fileDataGrid.Margin = 5
$contentScroll.Content = $fileDataGrid

# 数据表格列
$colName = New-Object System.Windows.Controls.DataGridTextColumn
$colName.Header = "文件名称"
$colName.Binding = [System.Windows.Data.Binding]"Name"
$colName.Width = 200
$fileDataGrid.Columns.Add($colName)

$colSize = New-Object System.Windows.Controls.DataGridTextColumn
$colSize.Header = "大小"
$colSize.Binding = [System.Windows.Data.Binding]"FormattedSize"
$colSize.Width = 120
$fileDataGrid.Columns.Add($colSize)

$colLastModified = New-Object System.Windows.Controls.DataGridTextColumn
$colLastModified.Header = "修改时间"
$colLastModified.Binding = [System.Windows.Data.Binding]"LastModified"
$colLastModified.Width = 180
$fileDataGrid.Columns.Add($colLastModified)

$colPath = New-Object System.Windows.Controls.DataGridTextColumn
$colPath.Header = "路径"
$colPath.Binding = [System.Windows.Data.Binding]"Path"
$colPath.Width = "*"
$fileDataGrid.Columns.Add($colPath)

# 状态栏
$statusBar = New-Object System.Windows.Controls.StackPanel
$statusBar.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$statusBar.Margin = 5
[System.Windows.Controls.Grid]::SetRow($statusBar, 4)
$mainGrid.Children.Add($statusBar)

$fileCountText = New-Object System.Windows.Controls.TextBlock
$fileCountText.Text = "已发现文件: 0"
$fileCountText.Margin = 5
$statusBar.Children.Add($fileCountText)

$scanInfoText = New-Object System.Windows.Controls.TextBlock
$scanInfoText.Text = "扫描状态: 未开始"
$scanInfoText.Margin = 5
$statusBar.Children.Add($scanInfoText)

# 工具函数 - 格式化文件大小
function Format-FileSize {
    param([long]$size)
    if ($size -ge 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    elseif ($size -ge 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    elseif ($size -ge 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    else { return "$size B" }
}

# 工具函数 - 转换为字节
function Convert-ToBytes {
    param([double]$value, [string]$unit)
    switch ($unit) {
        "B" { return $value }
        "KB" { return $value * 1KB }
        "MB" { return $value * 1MB }
        "GB" { return $value * 1GB }
        default { return $value }
    }
}

# 日期转换函数
function Convert-ToDateTime {
    param([string]$dateTimeString)
    # 如果为空直接返回null
    if ([string]::IsNullOrWhiteSpace($dateTimeString)) {
        return $null
    }
    $dateTime = $null
    try { $dateTime = [DateTime]$dateTimeString }
    catch {}
    return $dateTime
}

# 高速扫描核心函数
$script:fastScanScript = {
    param(
        [string]$driveLetter,
        [ref]$stopFlag
    )

    $results = New-Object System.Collections.Generic.List[PSObject]
    $excludePatterns = @(
        'System Volume Information', 'Program Files', 'Program Files (x86)',
        'Windows', 'AppData', 'Users\*\AppData', 'Recovery', 'OneDrive'
    )

    $queue = New-Object System.Collections.Queue
    $queue.Enqueue(@($driveLetter, 0))

    while ($queue.Count -gt 0 -and !$stopFlag.Value) {
        $current = $queue.Dequeue()
        $path = $current[0]
        $depth = $current[1]

        if ($depth -ge $using:scanDepth) { continue }

        try {
            $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue

            foreach ($item in $items) {
                if ($excludePatterns -contains $item.Name) { continue }

                if ($item.PSIsContainer) {
                    $queue.Enqueue(@($item.FullName, $depth + 1))
                }
                else {
                    $results.Add([PSCustomObject]@{
                        Name         = $item.Name
                        Path         = $item.FullName
                        RawSize      = $item.Length
                        FormattedSize = if ($item.Length -ge 1GB) { "{0:N2} GB" -f ($item.Length / 1GB) }
                        elseif ($item.Length -ge 1MB) { "{0:N2} MB" -f ($item.Length / 1MB) }
                        elseif ($item.Length -ge 1KB) { "{0:N2} KB" -f ($item.Length / 1KB) }
                        else { "$($item.Length) B" }
                        LastModified = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                        RawDate      = $item.LastWriteTime
                    })
                }
            }
        }
        catch {
            continue
        }
    }

    return @{
        Drive = $driveLetter
        Files = $results
        Count = $results.Count
        Success = !$stopFlag.Value
    }
}

# 实时合并扫描结果
function Merge-ScanResults {
    param(
        [PSObject[]]$newFiles,
        [string]$driveLetter,
        [int]$newFileCount
    )

    if (-not $newFiles -or $newFiles.Count -eq 0) { return }

    $script:allFiles = $script:allFiles + $newFiles | Select-Object -Unique
    $script:currentFilesCount = $script:allFiles.Count

    $window.Dispatcher.Invoke([Action]{
        $fileCountText.Text = "已发现文件: $($script:currentFilesCount)"
        $statusText.Text = "磁盘 $driveLetter 新增 $newFileCount 个文件"
        if ($fileDataGrid.ItemsSource) {
            $btnSearch.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        }
    }, [System.Windows.Threading.DispatcherPriority]::Normal)

    Save-PartialCache
}

# 缓存相关函数
function Save-PartialCache {
    try {
        $script:allFiles | ConvertTo-Json -Compress -Depth 1 | Out-File $partialCachePath -Encoding utf8
    }
    catch {
        Write-Error "保存临时缓存失败: $_"
    }
}

function Load-PartialCache {
    if (Test-Path $partialCachePath) {
        try {
            return Get-Content $partialCachePath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Error "加载临时缓存失败: $_"
            Remove-Item $partialCachePath -Force -ErrorAction SilentlyContinue
        }
    }
    return @()
}

function Save-FullCache {
    try {
        $script:allFiles | ConvertTo-Json -Compress -Depth 1 | Out-File $cacheFilePath -Encoding utf8
        if (Test-Path $partialCachePath) {
            Remove-Item $partialCachePath -Force
        }
        return $true
    }
    catch {
        Write-Error "保存完整缓存失败: $_"
        return $false
    }
}

# 【核心优化】搜索文件函数（支持空值跳过过滤）
function Search-Files {
    param(
        [string]$searchText,
        [DateTime]$startDate,
        [DateTime]$endDate,
        [double]$minSize,
        [double]$maxSize,
        [bool]$useMinSize,
        [bool]$useMaxSize
    )

    if ($script:allFiles.Count -eq 0) {
        return @()
    }

    $filtered = @()
    $searchText = $searchText.ToLower()
    $useSearch = -not [string]::IsNullOrWhiteSpace($searchText)
    $useDateFilter = $startDate -ne $null -or $endDate -ne $null

    foreach ($file in $script:allFiles) {
        # 文本筛选（为空则跳过）
        if ($useSearch) {
            if ($file.Name.ToLower() -notmatch $searchText -and
                    $file.Path.ToLower() -notmatch $searchText) {
                continue
            }
        }

        # 日期筛选（都为空则跳过）
        if ($useDateFilter) {
            $fileDate = [DateTime]$file.RawDate
            if (($startDate -ne $null -and $fileDate -lt $startDate) -or
                    ($endDate -ne $null -and $fileDate -gt $endDate)) {
                continue
            }
        }

        # 大小筛选（根据标志判断是否启用）
        if ($useMinSize -and $file.RawSize -lt $minSize) {
            continue
        }
        if ($useMaxSize -and $file.RawSize -gt $maxSize) {
            continue
        }

        $filtered += $file
    }

    return $filtered | Sort-Object -Property RawDate -Descending
}

# 开始扫描事件
$btnStartScan.Add_Click({
    if ($script:isScanning) {
        [System.Windows.MessageBox]::Show("扫描已在进行中", "提示", "OK", "Information")
        return
    }

    $script:isScanning = $true
    $script:stopRequested = $false
    $btnStartScan.IsEnabled = $false
    $btnStopScan.IsEnabled = $true
    $scanProgress.Visibility = [System.Windows.Visibility]::Visible
    $scanProgress.Value = 0

    $existingFiles = Load-PartialCache
    if ($existingFiles) {
        $script:allFiles = $existingFiles
        $script:currentFilesCount = $script:allFiles.Count
        $fileCountText.Text = "已发现文件: $($script:currentFilesCount) (包含缓存)"
    }

    $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
    if (-not $disks -or $disks.Count -eq 0) {
        [System.Windows.MessageBox]::Show("未发现可用磁盘", "错误", "OK", "Error")
        $script:isScanning = $false
        $btnStartScan.IsEnabled = $true
        $btnStopScan.IsEnabled = $false
        $scanProgress.Visibility = [System.Windows.Visibility]::Hidden
        return
    }

    $script:totalDisks = $disks.Count
    $script:completedDisks = 0
    $script:scanJobs = @()

    $statusText.Text = "开始扫描 $($script:totalDisks) 个磁盘..."
    $scanInfoText.Text = "扫描状态: 进行中 (0/$($script:totalDisks))"

    foreach ($disk in $disks) {
        $ps = [PowerShell]::Create().AddScript($script:fastScanScript).AddParameters(@{
            driveLetter = $disk.Root
            stopFlag    = [ref]$script:stopRequested
        })

        $asyncResult = $ps.BeginInvoke()
        $script:scanJobs += ,@{
            PowerShell = $ps
            AsyncResult = $asyncResult
            Drive = $disk.Root
        }
    }

    if ($script:scanTimer) { $script:scanTimer.Stop() }
    $script:scanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:scanTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $script:scanTimer.Add_Tick({
        if (-not $script:isScanning) {
            $this.Stop()
            return
        }

        foreach ($job in @($script:scanJobs)) {
            if ($job.AsyncResult.IsCompleted) {
                try {
                    $result = $job.PowerShell.EndInvoke($job.AsyncResult)
                    if ($result.Success -and $result.Count -gt 0) {
                        Merge-ScanResults -newFiles $result.Files -driveLetter $result.Drive -newFileCount $result.Count
                    }

                    $script:completedDisks++
                    $progressPercent = ($script:completedDisks / $script:totalDisks) * 100
                    $window.Dispatcher.Invoke([Action]{
                        $scanProgress.Value = $progressPercent
                        $scanInfoText.Text = "扫描状态: 进行中 ($($script:completedDisks)/$($script:totalDisks))"
                    })
                }
                catch {
                    $window.Dispatcher.Invoke([Action]{
                        $statusText.Text = "扫描 $($job.Drive) 出错: $($_.Exception.Message)"
                    })
                }
                finally {
                    $job.PowerShell.Dispose()
                    $script:scanJobs = $script:scanJobs | Where-Object { $_ -ne $job }
                }
            }
        }

        if ($script:scanJobs.Count -eq 0) {
            $this.Stop()
            $script:isScanning = $false
            $window.Dispatcher.Invoke([Action]{
                $scanProgress.Visibility = [System.Windows.Visibility]::Hidden
                $btnStartScan.IsEnabled = $true
                $btnStopScan.IsEnabled = $false
                $statusText.Text = "扫描完成，共发现 $($script:currentFilesCount) 个文件"
                $scanInfoText.Text = "扫描状态: 已完成"
            })
            Save-FullCache | Out-Null
        }
    })
    $script:scanTimer.Start()
})

# 停止扫描事件
$btnStopScan.Add_Click({
    if (-not $script:isScanning) { return }

    $result = [System.Windows.MessageBox]::Show(
            "确定要停止扫描吗？",
            "确认停止",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
    )

    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        $script:stopRequested = $true
        $script:isScanning = $false

        if ($script:scanTimer) { $script:scanTimer.Stop() }

        foreach ($job in @($script:scanJobs)) {
            if (-not $job.AsyncResult.IsCompleted) {
                $job.PowerShell.Stop()
            }
            $job.PowerShell.Dispose()
        }

        $script:scanJobs = @()
        $scanProgress.Visibility = [System.Windows.Visibility]::Hidden
        $btnStartScan.IsEnabled = $true
        $btnStopScan.IsEnabled = $false
        $statusText.Text = "扫描已停止"
        $scanInfoText.Text = "扫描状态: 已停止"
        Save-PartialCache | Out-Null
    }
})

# 【核心优化】搜索按钮事件（支持空值跳过过滤）
$btnSearch.Add_Click({
    if ($script:allFiles.Count -eq 0) {
        [System.Windows.MessageBox]::Show("尚未扫描到文件，请等待扫描开始后再试", "提示", "OK", "Information")
        return
    }

    # 日期处理（为空则不启用过滤）
    $startDate = Convert-ToDateTime $startDateTimeBox.Text
    $endDate = Convert-ToDateTime $endDateTimeBox.Text

    # 验证日期格式（如果填写了的话）
    if (($startDateTimeBox.Text -ne "" -and $startDate -eq $null) -or
            ($endDateTimeBox.Text -ne "" -and $endDate -eq $null)) {
        [System.Windows.MessageBox]::Show("日期时间格式错误`n请使用有效的日期时间格式（yyyy-MM-dd HH:mm:ss）", "错误", "OK", "Error")
        return
    }

    # 大小处理（为空则不启用过滤）
    $minSize = 0.0
    $maxSize = 0.0
    $useMinSize = -not [string]::IsNullOrWhiteSpace($minSizeBox.Text)
    $useMaxSize = -not [string]::IsNullOrWhiteSpace($maxSizeBox.Text)

    # 验证大小格式（如果填写了的话）
    if (($useMinSize -and -not [double]::TryParse($minSizeBox.Text, [ref]$minSize)) -or
            ($useMaxSize -and -not [double]::TryParse($maxSizeBox.Text, [ref]$maxSize))) {
        [System.Windows.MessageBox]::Show("文件大小格式错误，请输入有效的数字", "错误", "OK", "Error")
        return
    }

    # 转换大小单位（仅当启用了对应过滤时）
    $minBytes = if ($useMinSize) { Convert-ToBytes $minSize $minSizeUnit.SelectedItem } else { 0 }
    $maxBytes = if ($useMaxSize) { Convert-ToBytes $maxSize $maxSizeUnit.SelectedItem } else { [double]::MaxValue }
    $searchText = $searchBox.Text.Trim()

    $statusText.Text = "正在搜索... (共 $($script:allFiles.Count) 个文件)"
    $window.Dispatcher.Invoke([Action]{
        $results = Search-Files -searchText $searchText `
                               -startDate $startDate `
                               -endDate $endDate `
                               -minSize $minBytes `
                               -maxSize $maxBytes `
                               -useMinSize $useMinSize `
                               -useMaxSize $useMaxSize

        $fileDataGrid.ItemsSource = $results
        $statusText.Text = "搜索完成，找到 $($results.Count) 个文件"
    }, [System.Windows.Threading.DispatcherPriority]::Background)
})

# 双击打开文件
$fileDataGrid.Add_MouseDoubleClick({
    if ($fileDataGrid.SelectedItem) {
        $path = $fileDataGrid.SelectedItem.Path
        if (Test-Path $path) {
            Start-Process $path
        }
        else {
            [System.Windows.MessageBox]::Show("文件不存在: $path", "错误", "OK", "Error")
        }
    }
})

# 窗口关闭事件
$window.Add_Closing({
    if ($script:isScanning) {
        Save-PartialCache | Out-Null
        if ($script:scanTimer) {
            $script:scanTimer.Stop()
        }
    }
})

# 加载缓存
if (Test-Path $cacheFilePath) {
    try {
        $script:allFiles = Get-Content $cacheFilePath -Raw | ConvertFrom-Json
        $script:currentFilesCount = $script:allFiles.Count
        $fileCountText.Text = "已发现文件: $($script:currentFilesCount) (来自上次完整扫描)"
        $scanInfoText.Text = "扫描状态: 可继续扫描"
    }
    catch {
        Write-Error "加载缓存失败: $_"
        Remove-Item $cacheFilePath -Force -ErrorAction SilentlyContinue
    }
}

# 显示窗口
if (-not ([System.Windows.Application]::Current)) {
    $app = New-Object System.Windows.Application
}
else {
    $app = [System.Windows.Application]::Current
}
$app.Run($window)