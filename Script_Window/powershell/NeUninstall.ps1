# -----------------------------
# 1. 强制加载程序集
# -----------------------------
try
{
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
}
catch
{
    Write-Error "无法加载 Windows Forms 组件: $_"
    Write-Error "请确保已安装 .NET Framework 4.5+ 并以管理员身份运行"
    exit 1
}

# -----------------------------
# 2. 全局变量（护眼颜色常量）
# -----------------------------
$Global:AllSoftware = @()
$Global:FilteredSoftware = @()
$Color = @{
    Dark_BgMain = [System.Drawing.Color]::FromArgb(35, 38, 41)
    Dark_BgPanel = [System.Drawing.Color]::FromArgb(44, 47, 51)
    Dark_BgInput = [System.Drawing.Color]::FromArgb(54, 57, 63)
    Dark_BgGrid = [System.Drawing.Color]::FromArgb(44, 47, 51)
    Dark_BgGridAlt = [System.Drawing.Color]::FromArgb(50, 53, 56)
    Dark_TextMain = [System.Drawing.Color]::FromArgb(240, 235, 225)
    Dark_TextLight = [System.Drawing.Color]::FromArgb(220, 215, 205)
    Dark_GridLine = [System.Drawing.Color]::FromArgb(65, 68, 71)

    Light_BgMain = [System.Drawing.Color]::FromArgb(245, 245, 243)
    Light_BgPanel = [System.Drawing.Color]::FromArgb(235, 235, 233)
    Light_BgInput = [System.Drawing.Color]::FromArgb(250, 250, 248)
    Light_BgGrid = [System.Drawing.Color]::FromArgb(250, 250, 248)
    Light_BgGridAlt = [System.Drawing.Color]::FromArgb(240, 240, 238)
    Light_TextMain = [System.Drawing.Color]::FromArgb(38, 40, 42)
    Light_TextLight = [System.Drawing.Color]::FromArgb(68, 70, 72)
    Light_GridLine = [System.Drawing.Color]::FromArgb(220, 220, 218)
}

# -----------------------------
# 3. 初始化主窗口（核心修复：表格列添加逻辑）
# -----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "软件卸载管理工具"
$form.Size = New-Object System.Drawing.Size(1000, 600)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.MinimumSize = New-Object System.Drawing.Size(800, 500)
$form.FormBorderStyle = "Sizable"
$form.BackColor = $Color.Light_BgMain
$form.ForeColor = $Color.Light_TextMain

# 顶部面板
$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Name = "topPanel"
$topPanel.Dock = "Top"
$topPanel.Height = 80
$topPanel.Padding = New-Object System.Windows.Forms.Padding(10)
$topPanel.BackColor = $Color.Light_BgPanel

# 搜索框
$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.PlaceholderText = "搜索软件...（支持名称/版本/发布者）"
$searchBox.Dock = "Top"
$searchBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
$searchBox.Height = 32
$searchBox.BorderStyle = "Fixed3D"
$searchBox.BackColor = $Color.Light_BgInput
$searchBox.ForeColor = $Color.Light_TextMain

# 按钮面板
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Name = "buttonPanel"
$buttonPanel.Dock = "Top"
$buttonPanel.Height = 40
$buttonPanel.BackColor = $Color.Light_BgPanel

# 卸载按钮
$uninstallButton = New-Object System.Windows.Forms.Button
$uninstallButton.Text = "批量卸载选中项"
$uninstallButton.Size = New-Object System.Drawing.Size(120, 32)
$uninstallButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$uninstallButton.BackColor = $Color.Light_BgInput
$uninstallButton.ForeColor = $Color.Light_TextMain
$uninstallButton.FlatStyle = "Flat"
$uninstallButton.Location = New-Object System.Drawing.Point(0, 4)

# 备份注册表按钮
$backupRegButton = New-Object System.Windows.Forms.Button
$backupRegButton.Text = "备份注册表"
$backupRegButton.Size = New-Object System.Drawing.Size(100, 32)
$backupRegButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$backupRegButton.BackColor = $Color.Light_BgInput
$backupRegButton.ForeColor = $Color.Light_TextMain
$backupRegButton.FlatStyle = "Flat"
$backupRegButton.Location = New-Object System.Drawing.Point(130, 4)

# 导出 CSV 按钮
$exportCSVButton = New-Object System.Windows.Forms.Button
$exportCSVButton.Text = "导出CSV"
$exportCSVButton.Size = New-Object System.Drawing.Size(100, 32)
$exportCSVButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$exportCSVButton.BackColor = $Color.Light_BgInput
$exportCSVButton.ForeColor = $Color.Light_TextMain
$exportCSVButton.FlatStyle = "Flat"
$exportCSVButton.Location = New-Object System.Drawing.Point(240, 4)

# 复选框
$cleanupDirCheck = New-Object System.Windows.Forms.CheckBox
$cleanupDirCheck.Text = "清理残留目录"
$cleanupDirCheck.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$cleanupDirCheck.ForeColor = $Color.Light_TextMain
$cleanupDirCheck.AutoSize = $true
$cleanupDirCheck.Location = New-Object System.Drawing.Point(350, 8)

$showSystemCheck = New-Object System.Windows.Forms.CheckBox
$showSystemCheck.Text = "显示系统组件"
$showSystemCheck.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$showSystemCheck.ForeColor = $Color.Light_TextMain
$showSystemCheck.AutoSize = $true
$showSystemCheck.Location = New-Object System.Drawing.Point(460, 8)
$showSystemCheck.Checked = $false

$darkModeCheck = New-Object System.Windows.Forms.CheckBox
$darkModeCheck.Text = "护眼暗黑模式"
$darkModeCheck.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$darkModeCheck.ForeColor = $Color.Light_TextMain
$darkModeCheck.AutoSize = $true
$darkModeCheck.Location = New-Object System.Drawing.Point(580, 8)

# 添加按钮到面板
$buttonPanel.Controls.AddRange(@($uninstallButton, $backupRegButton, $exportCSVButton,
$cleanupDirCheck, $showSystemCheck, $darkModeCheck))
$topPanel.Controls.AddRange(@($searchBox, $buttonPanel))

# --------------------------
# 核心修复：表格列创建与添加（确保纯DataGridViewColumn类型）
# --------------------------
$softwareGrid = New-Object System.Windows.Forms.DataGridView
$softwareGrid.Dock = "Fill"
$softwareGrid.ReadOnly = $true
$softwareGrid.SelectionMode = "FullRowSelect"
$softwareGrid.MultiSelect = $true
$softwareGrid.AutoSizeColumnsMode = "None"
$softwareGrid.ColumnHeadersHeightSizeMode = "AutoSize"
$softwareGrid.RowHeadersVisible = $false
$softwareGrid.AllowUserToOrderColumns = $true
$softwareGrid.BackgroundColor = $Color.Light_BgGrid
$softwareGrid.ForeColor = $Color.Light_TextMain
$softwareGrid.GridColor = $Color.Light_GridLine
$softwareGrid.RowTemplate.Height = 28
$softwareGrid.AlternatingRowsDefaultCellStyle.BackColor = $Color.Light_BgGridAlt
$softwareGrid.AllowUserToResizeColumns = $false

# 表格列标题样式
$softwareGrid.ColumnHeadersDefaultCellStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
$softwareGrid.ColumnHeadersDefaultCellStyle.BackColor = $Color.Light_BgPanel
$softwareGrid.ColumnHeadersDefaultCellStyle.ForeColor = $Color.Light_TextMain
$softwareGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# --------------------------
# 表格列定义（仅保留MinimumWidth，通过权重控制最大宽度）
# --------------------------
# 1. 软件名称：高权重+最小宽度，优先分配空间
[System.Windows.Forms.DataGridViewTextBoxColumn]$col1 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$col1.HeaderText = "软件名称"
$col1.DataPropertyName = "DisplayName"
$col1.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
$col1.MinimumWidth = 200
$col1.FillWeight = 35

# 2. 版本列
[System.Windows.Forms.DataGridViewTextBoxColumn]$col2 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$col2.HeaderText = "版本"
$col2.DataPropertyName = "DisplayVersion"
$col2.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
$col2.MinimumWidth = 80
$col2.FillWeight = 8
$col2.DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter

# 3. 发布者列
[System.Windows.Forms.DataGridViewTextBoxColumn]$col3 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$col3.HeaderText = "发布者"
$col3.DataPropertyName = "Publisher"
$col3.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
$col3.MinimumWidth = 150
$col3.FillWeight = 25

# 4. 安装路径列
[System.Windows.Forms.DataGridViewTextBoxColumn]$col4 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$col4.HeaderText = "安装路径"
$col4.DataPropertyName = "InstallLocation"
$col4.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
$col4.MinimumWidth = 220
$col4.FillWeight = 25

# 5. 注册表位置列
[System.Windows.Forms.DataGridViewTextBoxColumn]$col5 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$col5.HeaderText = "注册表位置"
$col5.DataPropertyName = "RegistryPath"
$col5.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
$col5.MinimumWidth = 100
$col5.FillWeight = 7

# 修复2：先创建纯列类型数组，再调用AddRange（避免类型转换错误）
$columnsArray = @($col1, $col2, $col3, $col4, $col5 )

$softwareGrid.Columns.AddRange($columnsArray)

# 状态栏
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.Height = 26
$statusStrip.BackColor = $Color.Light_BgPanel
$statusStrip.ForeColor = $Color.Light_TextMain
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "就绪 - 请等待软件扫描完成"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$statusStrip.Items.Add($statusLabel)

# 添加控件到主窗口
$form.Controls.AddRange(@($softwareGrid, $topPanel, $statusStrip))

# -----------------------------
# 4. 功能函数
# -----------------------------
function Resize-GridColumns
{
    param($grid)
    if ($grid.Columns.Count -eq 0)
    {
        return
    }

    $availableWidth = $grid.ClientSize.Width - 20
    $totalWeight = 0
    foreach ($col in $grid.Columns)
    {
        $totalWeight += $col.FillWeight
    }

    $columnWidths = @()
    foreach ($col in $grid.Columns)
    {
        $baseWidth = [int]($availableWidth * ($col.FillWeight / $totalWeight))
        $finalWidth = [Math]::Max($baseWidth, $col.MinimumWidth)
        $columnWidths += @{ Column = $col; Width = $finalWidth }
    }

    $totalCalculatedWidth = ($columnWidths | Measure-Object -Property Width -Sum).Sum
    if ($totalCalculatedWidth -gt $availableWidth)
    {
        $excessWidth = $totalCalculatedWidth - $availableWidth
        $sortedColumns = $columnWidths | Sort-Object -Property @{ Expression = { $_.Column.FillWeight } }
        foreach ($item in $sortedColumns)
        {
            if ($excessWidth -le 0)
            {
                break
            }
            $maxReduce = $item.Width - $item.Column.MinimumWidth
            if ($maxReduce -le 0)
            {
                continue
            }
            $reduceWidth = [Math]::Min($excessWidth, $maxReduce)
            $item.Width -= $reduceWidth
            $excessWidth -= $reduceWidth
        }
    }

    foreach ($item in $columnWidths)
    {
        $item.Column.Width = $item.Width
    }
}

function Load-SoftwareData
{
    $statusLabel.Text = "正在扫描已安装软件...（共3个注册表位置）"
    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $softwareList = @()

    $registryPaths | ForEach-Object -Parallel {
        $path = $_
        if (Test-Path $path)
        {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($item in $items)
            {
                if (-not [string]::IsNullOrEmpty($item.DisplayName) -and $item.DisplayName -notmatch "^$|^Unknown$")
                {
                    [PSCustomObject]@{
                        DisplayName = $item.DisplayName.Trim()
                        DisplayVersion = if (-not [string]::IsNullOrEmpty($item.DisplayVersion))
                        {
                            $item.DisplayVersion.Trim()
                        }
                        else
                        {
                            "未知"
                        }
                        Publisher = if (-not [string]::IsNullOrEmpty($item.Publisher))
                        {
                            $item.Publisher.Trim()
                        }
                        else
                        {
                            "未知"
                        }
                        InstallLocation = if (-not [string]::IsNullOrEmpty($item.InstallLocation))
                        {
                            $item.InstallLocation.Trim()
                        }
                        else
                        {
                            "未知"
                        }
                        UninstallString = $item.UninstallString
                        RegistryPath = $item.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", ""
                        IsSystemComponent = $item.SystemComponent -eq 1 -or
                            $item.DisplayName -match "^Microsoft .NET|^Visual C\+\+|^Windows |^SQL Server|^Office [0-9]"
                    }
                }
            }
        }
    } | ForEach-Object { $softwareList += $_ }

    $Global:AllSoftware = $softwareList | Group-Object -Property DisplayName -AsString | ForEach-Object { $_.Group | Select-Object -First 1 }
    Filter-Software
    Resize-GridColumns $softwareGrid
    $statusLabel.Text = "扫描完成 - 显示 $( $FilteredSoftware.Count ) 个软件（共 $( $AllSoftware.Count ) 个）"
}

function Filter-Software
{
    $searchText = $searchBox.Text.Trim().ToLower()
    $showSystem = $showSystemCheck.Checked

    $Global:FilteredSoftware = $AllSoftware | Where-Object {
        ($showSystem -or -not $_.IsSystemComponent) -and
            ($searchText -eq "" -or
                $_.DisplayName.ToLower().Contains($searchText) -or
                $_.Publisher.ToLower().Contains($searchText) -or
                $_.DisplayVersion.ToLower().Contains($searchText))
    }

    $dataTable = New-Object System.Data.DataTable
    if ($FilteredSoftware.Count -gt 0)
    {
        $properties = $FilteredSoftware[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($prop in $properties)
        {
            $dataTable.Columns.Add($prop) | Out-Null
        }
        $FilteredSoftware | ForEach-Object {
            $row = $dataTable.NewRow()
            foreach ($prop in $properties)
            {
                $row[$prop] = $_.$prop
            }
            $dataTable.Rows.Add($row)
        }
    }

    $softwareGrid.DataSource = $null
    $softwareGrid.DataSource = $dataTable
    Resize-GridColumns $softwareGrid
    $softwareGrid.Columns["DisplayName"].DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
    $softwareGrid.Columns["InstallLocation"].DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
    $softwareGrid.AutoResizeRows()

    $statusLabel.Text = if ($searchText -ne "")
    {
        "搜索过滤 - 显示 $( $FilteredSoftware.Count ) 个匹配结果"
    }
    else
    {
        "显示 $( $FilteredSoftware.Count ) 个软件（共 $( $AllSoftware.Count ) 个）"
    }
}

function Uninstall-Software
{
    param($software)
    $statusLabel.Text = "正在卸载：$( $software.DisplayName )..."
    $uninstallSuccess = $true

    try
    {
        if (-not [string]::IsNullOrEmpty($software.UninstallString))
        {
            $uninstallCmd = $software.UninstallString
            if ($uninstallCmd -match '^"([^"]+)"(.*)')
            {
                $exePath = $matches[1]
                $arguments = $matches[2].Trim() + " /quiet /qn /norestart"
            }
            else
            {
                $exePath = $uninstallCmd
                $arguments = "/quiet /qn /norestart"
            }

            if (Test-Path $exePath)
            {
                Start-Process -FilePath $exePath -ArgumentList $arguments -Wait -NoNewWindow -NoNewWindow
            }
            else
            {
                throw "卸载程序路径不存在：$exePath"
            }
        }
        else
        {
            if (Test-Path $software.RegistryPath)
            {
                Remove-Item -Path $software.RegistryPath -Recurse -Force -ErrorAction Stop
                $statusLabel.Text = "无卸载程序，已清理注册表：$( $software.DisplayName )"
            }
            else
            {
                throw "无卸载程序且注册表项不存在"
            }
        }

        if ($cleanupDirCheck.Checked -and $software.InstallLocation -ne "未知" -and (Test-Path $software.InstallLocation))
        {
            $confirmClean = [System.Windows.Forms.MessageBox]::Show(
                "是否删除残留目录：`n$( $software.InstallLocation )`n`n注意：此操作不可恢复！",
                "确认清理残留",
                "YesNo",
                "Warning"
            )
            if ($confirmClean -eq "Yes")
            {
                Remove-Item -Path $software.InstallLocation -Recurse -Force -ErrorAction Stop
                $statusLabel.Text = "卸载完成并清理目录：$( $software.DisplayName )"
            }
            else
            {
                $statusLabel.Text = "卸载完成，未清理目录：$( $software.DisplayName )"
            }
        }
        else
        {
            $statusLabel.Text = "卸载完成：$( $software.DisplayName )"
        }
    }
    catch
    {
        $uninstallSuccess = $false
        $errorMsg = $_.Exception.Message.Substring(0,[Math]::Min($_.Exception.Message.Length, 100))
        $statusLabel.Text = "卸载失败：$( $software.DisplayName ) - $errorMsg"
        [System.Windows.Forms.MessageBox]::Show(
            "卸载失败：$errorMsg`n`n建议手动卸载该软件。",
            "卸载错误",
            "OK",
            "Error"
        )
    }

    return $uninstallSuccess
}

function Uninstall-Selected
{
    $selectedRows = $softwareGrid.SelectedRows
    if ($selectedRows.Count -eq 0)
    {
        [System.Windows.Forms.MessageBox]::Show(
            "请先在表格中选择要卸载的软件（可按住Ctrl多选）",
            "选择提示",
            "OK",
            "Information"
        )
        return
    }

    $selectedNames = $selectedRows | ForEach-Object { $_.Cells["DisplayName"].Value } -Join "`n"
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "确定要卸载以下 $( $selectedRows.Count ) 个软件吗？`n`n$selectedNames`n`n卸载过程中请耐心等待...",
        "批量卸载确认",
        "YesNo",
        "Warning"
    )

    if ($confirm -eq "Yes")
    {
        $successCount = 0
        $failCount = 0
        foreach ($row in $selectedRows)
        {
            $software = $row.DataBoundItem
            if (Uninstall-Software $software)
            {
                $successCount++
            }
            else
            {
                $failCount++
            }
        }
        Load-SoftwareData
        [System.Windows.Forms.MessageBox]::Show(
            "批量卸载完成！`n`n成功：$successCount 个`n失败：$failCount 个",
            "卸载结果",
            "OK",
            "Information"
        )
    }
}

function Backup-Registry
{
    $statusLabel.Text = "正在准备注册表备份..."
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "注册表文件 (*.reg)|*.reg|所有文件 (*.*)|*.*"
    $saveDialog.FileName = "Uninstall_Registry_Backup_$( Get-Date -Format 'yyyyMMdd_HHmmss' ).reg"
    $saveDialog.Title = "选择注册表备份保存位置"
    $saveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

    if ($saveDialog.ShowDialog() -eq "OK")
    {
        try
        {
            reg export "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" "$( $saveDialog.FileName )" /y | Out-Null
            reg export "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" "$( $saveDialog.FileName )" /y /a | Out-Null
            reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall" "$( $saveDialog.FileName )" /y /a | Out-Null

            $statusLabel.Text = "注册表备份成功：$( $saveDialog.SafeFileName )"
            [System.Windows.Forms.MessageBox]::Show(
                "注册表备份成功！`n`n保存路径：$( $saveDialog.FileName )`n`n恢复时双击.reg文件即可。",
                "备份成功",
                "OK",
                "Information"
            )
        }
        catch
        {
            $statusLabel.Text = "注册表备份失败"
            [System.Windows.Forms.MessageBox]::Show(
                "备份失败：$( $_.Exception.Message )",
                "备份错误",
                "OK",
                "Error"
            )
        }
    }
    else
    {
        $statusLabel.Text = "注册表备份已取消"
    }
}

function Export-ToCSV
{
    if ($FilteredSoftware.Count -eq 0)
    {
        [System.Windows.Forms.MessageBox]::Show(
            "当前没有可导出的软件数据（请确保已扫描且过滤后有结果）",
            "导出提示",
            "OK",
            "Information"
        )
        return
    }

    $statusLabel.Text = "正在准备导出CSV..."
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "CSV文件 (*.csv)|*.csv|所有文件 (*.*)|*.*"
    $saveDialog.FileName = "Software_List_$( Get-Date -Format 'yyyyMMdd_HHmmss' ).csv"
    $saveDialog.Title = "选择软件列表导出位置"
    $saveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

    if ($saveDialog.ShowDialog() -eq "OK")
    {
        try
        {
            $FilteredSoftware | Select-Object `
                @{ Name = "软件名称"; Expression = { $_.DisplayName } },
            @{ Name = "版本"; Expression = { $_.DisplayVersion } },
            @{ Name = "发布者"; Expression = { $_.Publisher } },
            @{ Name = "安装路径"; Expression = { $_.InstallLocation } },
            @{ Name = "注册表位置"; Expression = { $_.RegistryPath } } |
                Export-Csv -Path $saveDialog.FileName -Encoding UTF8 -NoTypeInformation -ErrorAction Stop

            $statusLabel.Text = "CSV导出成功：$( $saveDialog.SafeFileName )"
            [System.Windows.Forms.MessageBox]::Show(
                "软件列表导出成功！`n`n保存路径：$( $saveDialog.FileName )`n`n可用Excel或记事本打开。",
                "导出成功",
                "OK",
                "Information"
            )
        }
        catch
        {
            $statusLabel.Text = "CSV导出失败"
            [System.Windows.Forms.MessageBox]::Show(
                "导出失败：$( $_.Exception.Message )",
                "导出错误",
                "OK",
                "Error"
            )
        }
    }
    else
    {
        $statusLabel.Text = "CSV导出已取消"
    }
}

function Apply-Theme
{
    if ($darkModeCheck.Checked)
    {
        $form.BackColor = $Color.Dark_BgMain
        $form.ForeColor = $Color.Dark_TextMain
        $topPanel.BackColor = $Color.Dark_BgPanel
        $buttonPanel.BackColor = $Color.Dark_BgPanel
        $searchBox.BackColor = $Color.Dark_BgInput
        $searchBox.ForeColor = $Color.Dark_TextMain
        $searchBox.BorderStyle = "FixedSingle"
        $uninstallButton.BackColor = $Color.Dark_BgInput
        $uninstallButton.ForeColor = $Color.Dark_TextMain
        $backupRegButton.BackColor = $Color.Dark_BgInput
        $backupRegButton.ForeColor = $Color.Dark_TextMain
        $exportCSVButton.BackColor = $Color.Dark_BgInput
        $exportCSVButton.ForeColor = $Color.Dark_TextMain
        $cleanupDirCheck.ForeColor = $Color.Dark_TextMain
        $showSystemCheck.ForeColor = $Color.Dark_TextMain
        $darkModeCheck.ForeColor = $Color.Dark_TextMain
        $softwareGrid.BackgroundColor = $Color.Dark_BgGrid
        $softwareGrid.ForeColor = $Color.Dark_TextMain
        $softwareGrid.GridColor = $Color.Dark_GridLine
        $softwareGrid.AlternatingRowsDefaultCellStyle.BackColor = $Color.Dark_BgGridAlt
        $softwareGrid.ColumnHeadersDefaultCellStyle.BackColor = $Color.Dark_BgPanel
        $softwareGrid.ColumnHeadersDefaultCellStyle.ForeColor = $Color.Dark_TextMain
        $statusStrip.BackColor = $Color.Dark_BgPanel
        $statusStrip.ForeColor = $Color.Dark_TextMain
        $statusLabel.ForeColor = $Color.Dark_TextLight
    }
    else
    {
        $form.BackColor = $Color.Light_BgMain
        $form.ForeColor = $Color.Light_TextMain
        $topPanel.BackColor = $Color.Light_BgPanel
        $buttonPanel.BackColor = $Color.Light_BgPanel
        $searchBox.BackColor = $Color.Light_BgInput
        $searchBox.ForeColor = $Color.Light_TextMain
        $searchBox.BorderStyle = "Fixed3D"
        $uninstallButton.BackColor = $Color.Light_BgInput
        $uninstallButton.ForeColor = $Color.Light_TextMain
        $backupRegButton.BackColor = $Color.Light_BgInput
        $backupRegButton.ForeColor = $Color.Light_TextMain
        $exportCSVButton.BackColor = $Color.Light_BgInput
        $exportCSVButton.ForeColor = $Color.Light_TextMain
        $cleanupDirCheck.ForeColor = $Color.Light_TextMain
        $showSystemCheck.ForeColor = $Color.Light_TextMain
        $darkModeCheck.ForeColor = $Color.Light_TextMain
        $softwareGrid.BackgroundColor = $Color.Light_BgGrid
        $softwareGrid.ForeColor = $Color.Light_TextMain
        $softwareGrid.GridColor = $Color.Light_GridLine
        $softwareGrid.AlternatingRowsDefaultCellStyle.BackColor = $Color.Light_BgGridAlt
        $softwareGrid.ColumnHeadersDefaultCellStyle.BackColor = $Color.Light_BgPanel
        $softwareGrid.ColumnHeadersDefaultCellStyle.ForeColor = $Color.Light_TextMain
        $statusStrip.BackColor = $Color.Light_BgPanel
        $statusStrip.ForeColor = $Color.Light_TextMain
        $statusLabel.ForeColor = $Color.Light_TextLight
    }
    Resize-GridColumns $softwareGrid
}

# -----------------------------
# 5. 绑定事件
# -----------------------------
$searchTimer = New-Object System.Windows.Forms.Timer
$searchTimer.Interval = 300
$searchTimer.Add_Tick({
    $searchTimer.Stop()
    Filter-Software
})
$searchBox.Add_TextChanged({ $searchTimer.Start() })

$showSystemCheck.Add_CheckedChanged({ Filter-Software })
$uninstallButton.Add_Click({ Uninstall-Selected })
$backupRegButton.Add_Click({ Backup-Registry })
$exportCSVButton.Add_Click({ Export-ToCSV })
$darkModeCheck.Add_CheckedChanged({ Apply-Theme })

$form.Add_Resize({
    if (-not $script:resizeTimer)
    {
        $script:resizeTimer = New-Object System.Windows.Forms.Timer
        $script:resizeTimer.Interval = 100
        $script:resizeTimer.Add_Tick({
            $script:resizeTimer.Stop()
            Resize-GridColumns $softwareGrid
            $softwareGrid.AutoResizeRows()
        })
    }
    $script:resizeTimer.Start()
})

$softwareGrid.Add_CellDoubleClick({
    param($sender, $e)
    if ($e.RowIndex -ge 0)
    {
        $row = $softwareGrid.Rows[$e.RowIndex]
        $installPath = $row.Cells["InstallLocation"].Value
        if ($installPath -and $installPath -ne "未知" -and (Test-Path $installPath))
        {
            $statusLabel.Text = "正在打开目录：$installPath"
            Start-Process $installPath
        }
        else
        {
            [System.Windows.Forms.MessageBox]::Show(
                "安装路径不存在或未知`n`n路径：$installPath",
                "路径提示",
                "OK",
                "Information"
            )
        }
    }
})

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.BackColor = if ($darkModeCheck.Checked)
{
    $Color.Dark_BgPanel
}
else
{
    $Color.Light_BgPanel
}
$contextMenu.ForeColor = if ($darkModeCheck.Checked)
{
    $Color.Dark_TextMain
}
else
{
    $Color.Light_TextMain
}
$contextMenu.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$uninstallMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$uninstallMenuItem.Text = "卸载此软件"
$uninstallMenuItem.Add_Click({
    if ($softwareGrid.SelectedRows.Count -gt 0)
    {
        $software = $softwareGrid.SelectedRows[0].DataBoundItem
        Uninstall-Software $software
        Load-SoftwareData
    }
})

$openDirMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openDirMenuItem.Text = "打开安装目录"
$openDirMenuItem.Add_Click({
    if ($softwareGrid.SelectedRows.Count -gt 0)
    {
        $software = $softwareGrid.SelectedRows[0].DataBoundItem
        if ($software.InstallLocation -ne "未知" -and (Test-Path $software.InstallLocation))
        {
            Start-Process $software.InstallLocation
            $statusLabel.Text = "已打开目录：$( $software.InstallLocation )"
        }
        else
        {
            [System.Windows.Forms.MessageBox]::Show(
                "安装路径不存在或未知",
                "路径提示",
                "OK",
                "Information"
            )
        }
    }
})

$contextMenu.Items.AddRange(@($uninstallMenuItem, $openDirMenuItem))
$softwareGrid.ContextMenuStrip = $contextMenu

# -----------------------------
# 6. 启动程序
# -----------------------------
$form.Add_Shown({
    Load-SoftwareData
    Apply-Theme
    Resize-GridColumns $softwareGrid
})

$form.ShowDialog() | Out-Null
$searchTimer.Dispose()
if ($script:resizeTimer)
{
    $script:resizeTimer.Dispose()
}
$form.Dispose()