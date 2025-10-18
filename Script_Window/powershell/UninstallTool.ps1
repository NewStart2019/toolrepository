<#
.SYNOPSIS
Windows 卸载软件

.DESCRIPTION
所有用户（系统级）	64位程序	HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
所有用户（系统级）	32位程序（在64位系统上）	HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
当前用户（个人安装）	任意位数	HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
#>

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
# 2. 全局变量
# -----------------------------
$Global:AllSoftware = @()
$Global:FilteredSoftware = @()
$Global:DarkMode = $false

# -----------------------------
# 3. 初始化主窗口
# -----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "软件卸载管理工具"
$form.Size = New-Object System.Drawing.Size(1000, 600)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.MinimumSize = New-Object System.Drawing.Size(800, 500)

# 顶部面板
$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Name = "topPanel"
$topPanel.Dock = "Top"
$topPanel.Height = 80
$topPanel.Padding = New-Object System.Windows.Forms.Padding(10)
$topPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)

# 搜索框
$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.PlaceholderText = "搜索软件..."
$searchBox.Dock = "Top"
$searchBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
$searchBox.Height = 30

# 按钮面板
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Name = "buttonPanel"
$buttonPanel.Dock = "Top"
$buttonPanel.Height = 40

# 卸载按钮
$uninstallButton = New-Object System.Windows.Forms.Button
$uninstallButton.Text = "批量卸载选中项"
$uninstallButton.Size = New-Object System.Drawing.Size(120, 30)
$uninstallButton.Location = New-Object System.Drawing.Point(0, 5)

# 备份注册表按钮
$backupRegButton = New-Object System.Windows.Forms.Button
$backupRegButton.Text = "备份注册表"
$backupRegButton.Size = New-Object System.Drawing.Size(100, 30)
$backupRegButton.Location = New-Object System.Drawing.Point(130, 5)

# 导出 CSV
$exportCSVButton = New-Object System.Windows.Forms.Button
$exportCSVButton.Text = "导出CSV"
$exportCSVButton.Size = New-Object System.Drawing.Size(100, 30)
$exportCSVButton.Location = New-Object System.Drawing.Point(240, 5)

# 清理残留目录
$cleanupDirCheck = New-Object System.Windows.Forms.CheckBox
$cleanupDirCheck.Text = "清理残留目录"
$cleanupDirCheck.Location = New-Object System.Drawing.Point(350, 10)

# 显示系统组件
$showSystemCheck = New-Object System.Windows.Forms.CheckBox
$showSystemCheck.Text = "显示系统组件"
$showSystemCheck.Location = New-Object System.Drawing.Point(460, 10)
$showSystemCheck.Checked = $false

# 深色模式
$darkModeCheck = New-Object System.Windows.Forms.CheckBox
$darkModeCheck.Text = "深色模式"
$darkModeCheck.Location = New-Object System.Drawing.Point(580, 10)

# 添加按钮到面板
$buttonPanel.Controls.AddRange(@($uninstallButton, $backupRegButton, $exportCSVButton,
$cleanupDirCheck, $showSystemCheck, $darkModeCheck))
$topPanel.Controls.AddRange(@($searchBox, $buttonPanel))

# 软件表格
$softwareGrid = New-Object System.Windows.Forms.DataGridView
$softwareGrid.Dock = "Fill"
$softwareGrid.ReadOnly = $true
$softwareGrid.SelectionMode = "FullRowSelect"
$softwareGrid.MultiSelect = $true
$softwareGrid.AutoSizeColumnsMode = "Fill"
$softwareGrid.RowHeadersVisible = $false
# 允许排序
$softwareGrid.AllowUserToOrderColumns = $true
$softwareGrid.BackgroundColor = [System.Drawing.Color]::White
# 字体颜色黑色
$softwareGrid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
$softwareGrid.GridColor = [System.Drawing.Color]::LightGray

# 状态栏
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "就绪"
$statusStrip.Items.Add($statusLabel)

# 创建列
$softwareGrid.Columns.AddRange(
    (New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
        HeaderText = "软件名称";
        DataPropertyName = "DisplayName";
        SortMode = "Automatic";
        MinimumWidth = 200;
        FillWeight = 35
    }),
    (New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
        HeaderText = "版本";
        DataPropertyName = "DisplayVersion";
        SortMode = "Automatic";
        MinimumWidth = 50;
        FillWeight = 4
    }),
    (New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
        HeaderText = "发布者";
        DataPropertyName = "Publisher";
        SortMode = "Automatic";
        MinimumWidth = 150;
        FillWeight = 25
    }),
    (New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
        HeaderText = "安装路径";
        DataPropertyName = "InstallLocation";
        SortMode = "Automatic";
        MinimumWidth = 220;
        FillWeight = 25
    }),
    (New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
        HeaderText = "注册表位置";
        DataPropertyName = "RegistryPath";
        SortMode = "Automatic";
        MinimumWidth = 100;
        FillWeight = 7
    })
)

# 添加控件到主窗口
$form.Controls.AddRange(@($softwareGrid, $topPanel, $statusStrip))

# -----------------------------
# 4. 功能函数
# -----------------------------
function Load-SoftwareData
{
    $statusLabel.Text = "正在扫描已安装软件..."
    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $softwareList = @()
    foreach ($path in $registryPaths)
    {
        if (Test-Path $path)
        {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($item in $items)
            {
                if (-not [string]::IsNullOrEmpty($item.DisplayName))
                {
                    $software = [PSCustomObject]@{
                        DisplayName = $item.DisplayName
                        DisplayVersion = if (-not [string]::IsNullOrEmpty($item.DisplayVersion))
                        {
                            $item.DisplayVersion
                        }
                        else
                        {
                            "未知"
                        }
                        Publisher = if (-not [string]::IsNullOrEmpty($item.Publisher))
                        {
                            $item.Publisher
                        }
                        else
                        {
                            "未知"
                        }
                        InstallLocation = if (-not [string]::IsNullOrEmpty($item.InstallLocation))
                        {
                            $item.InstallLocation
                        } elseif (-not [string]::IsNullOrEmpty($item.installDir)) {
                            $item.installDir
                        }
                        else
                        {
                            "未知"
                        }
                        UninstallString = $item.UninstallString
                        RegistryPath = $item.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", ""
                        IsSystemComponent = $item.SystemComponent -eq 1 -or
                            $item.DisplayName -match "Microsoft|Windows|Visual C\+\+|.NET Framework|SQL Server|Office"
                    }
                    $softwareList += $software
                }
            }
        }
    }
    $Global:AllSoftware = $softwareList | Group-Object DisplayName | ForEach-Object { $_.Group | Select-Object -First 1 }
    Filter-Software
}

function Filter-Software
{
    $searchText = $searchBox.Text.Trim().ToLower()
    $showSystem = $showSystemCheck.Checked

    # 过滤数据
    $Global:FilteredSoftware = $AllSoftware | Where-Object {
        ($showSystem -or -not $_.IsSystemComponent) -and
            ($searchText -eq "" -or $_.DisplayName.ToLower().Contains($searchText) -or
                $_.Publisher.ToLower().Contains($searchText) -or $_.DisplayVersion.ToLower().Contains($searchText))
    }

    # 关键修复：将PSCustomObject转换为DataTable
    $dataTable = New-Object System.Data.DataTable
    if ($FilteredSoftware.Count -gt 0)
    {
        # 添加列
        # 显示的列
        $properties = @("DisplayName", "DisplayVersion", "Publisher", "InstallLocation", "UninstallString", "RegistryPath")
#        $properties = $FilteredSoftware[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($prop in $properties)
        {
            $dataTable.Columns.Add($prop) | Out-Null
        }
        # 添加行
        foreach ($item in $FilteredSoftware)
        {
            $row = $dataTable.NewRow()
            foreach ($prop in $properties)
            {
                $row[$prop] = $item.$prop
            }
            $dataTable.Rows.Add($row)
        }
    }

    # 绑定DataTable到表格
    #    $softwareGrid.DataSource = $null  # 清空旧数据
    $softwareGrid.DataSource = $dataTable
    $softwareGrid.AutoResizeColumns()
    $statusLabel.Text = "显示 $( $FilteredSoftware.Count ) 个软件 (共 $( $AllSoftware.Count ) 个)"
}

function Uninstall-Software
{
    param($software)
    $statusLabel.Text = "正在卸载: $( $software.DisplayName )..."
    try
    {
        if (-not [string]::IsNullOrEmpty($software.UninstallString))
        {
            $cmd = $software.UninstallString
            Start-Process -FilePath $cmd -ArgumentList '/quiet /qn' -Wait -NoNewWindow
        }
        elseif (Test-Path $software.RegistryPath)
        {
            Remove-Item -Path $software.RegistryPath -Recurse -Force
        }

        if ($cleanupDirCheck.Checked -and $software.InstallLocation -ne "未知" -and (Test-Path $software.InstallLocation))
        {
            Remove-Item -Path $software.InstallLocation -Recurse -Force -ErrorAction SilentlyContinue
        }
        $statusLabel.Text = "已卸载: $( $software.DisplayName )"
    }
    catch
    {
        $statusLabel.Text = "卸载失败: $( $software.DisplayName ) - $( $_.Exception.Message )"
        [System.Windows.Forms.MessageBox]::Show("卸载失败: $( $_.Exception.Message )", "错误", "OK", "Error")
    }
}

function Uninstall-Selected
{
    if ($softwareGrid.SelectedRows.Count -eq 0)
    {
        [System.Windows.Forms.MessageBox]::Show("请先选择要卸载的软件", "提示", "OK", "Information")
        return
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "确定要卸载选中的 $( $softwareGrid.SelectedRows.Count ) 个软件吗？",
        "确认卸载", "YesNo", "Warning"
    )
    if ($confirm -eq "Yes")
    {
        foreach ($row in $softwareGrid.SelectedRows)
        {
            Uninstall-Software $row.DataBoundItem
        }
        Load-SoftwareData
    }
}

function Backup-Registry
{
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Registry Files (*.reg)|*.reg|All Files (*.*)|*.*"
    $saveDialog.FileName = "UninstallRegistryBackup_$( Get-Date -Format 'yyyyMMdd_HHmmss' ).reg"
    if ($saveDialog.ShowDialog() -eq "OK")
    {
        reg export "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" "$( $saveDialog.FileName )" /y | Out-Null
        reg export "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" "$( $saveDialog.FileName )" /y /a | Out-Null
        reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall" "$( $saveDialog.FileName )" /y /a | Out-Null
        [System.Windows.Forms.MessageBox]::Show("注册表备份成功`n保存路径: $( $saveDialog.FileName )", "成功", "OK", "Information")
    }
}

function Export-ToCSV
{
    if ($FilteredSoftware.Count -eq 0)
    {
        [System.Windows.Forms.MessageBox]::Show("没有可导出的软件数据", "提示", "OK", "Information")
        return
    }
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $saveDialog.FileName = "SoftwareList_$( Get-Date -Format 'yyyyMMdd_HHmmss' ).csv"
    if ($saveDialog.ShowDialog() -eq "OK")
    {
        $FilteredSoftware | Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation, RegistryPath |
            Export-Csv -Path $saveDialog.FileName -Encoding UTF8 -NoTypeInformation
        [System.Windows.Forms.MessageBox]::Show("导出成功`n保存路径: $( $saveDialog.FileName )", "成功", "OK", "Information")
    }
}

function Apply-Theme
{
    if ($darkModeCheck.Checked)
    {
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        $softwareGrid.BackgroundColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $softwareGrid.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        $softwareGrid.GridColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
        $softwareGrid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 55)
        $topPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
        $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
        $searchBox.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 55)
        $searchBox.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        $statusStrip.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
        $statusStrip.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    }
    else
    {
        $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        $form.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $softwareGrid.BackgroundColor = [System.Drawing.Color]::White
        $softwareGrid.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $softwareGrid.GridColor = [System.Drawing.Color]::LightGray
        $softwareGrid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
        $topPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
        $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
        $searchBox.BackColor = [System.Drawing.Color]::White
        $searchBox.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $statusStrip.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
        $statusStrip.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    }
}

function Show-SoftwareDetailAndUninstall
{
    param($software)
    # 创建详情弹窗
    $detailForm = New-Object System.Windows.Forms.Form
    $detailForm.Text = "软件详情 - 确认卸载"
    $detailForm.Size = New-Object System.Drawing.Size(500, 400)
    $detailForm.StartPosition = "CenterScreen"
    $detailForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $detailForm.FormBorderStyle = "FixedDialog"
    $detailForm.MaximizeBox = $false
    $detailForm.MinimizeBox = $false

    # 创建文本框用于展示详情（不可编辑）
    $detailTextBox = New-Object System.Windows.Forms.TextBox
    $detailTextBox.Dock = "Fill"
    $detailTextBox.ReadOnly = $true
    $detailTextBox.Multiline = $true
    $detailTextBox.ScrollBars = "Vertical"
    $detailTextBox.WordWrap = $true
    # 拼接软件详情信息
    $detailText = @"
软件名称: $( $software.DisplayName )
版本: $( $software.DisplayVersion )
发布者: $( $software.Publisher )
安装路径: $( $software.InstallLocation )
注册表位置: $( $software.RegistryPath )

提示: 点击"确认卸载"将开始移除该软件，若勾选了"清理残留目录"，会同时删除安装文件夹。
"@
    $detailTextBox.Text = $detailText

    # 创建按钮面板
    $btnPanel = New-Object System.Windows.Forms.Panel
    $btnPanel.Dock = "Bottom"
    $btnPanel.Height = 40
    $btnPanel.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)

    # 确认卸载按钮
    $confirmBtn = New-Object System.Windows.Forms.Button
    $confirmBtn.Text = "确认卸载"
    $confirmBtn.Size = New-Object System.Drawing.Size(100, 30)
    $confirmBtn.Location = New-Object System.Drawing.Point(280, 5)
    $confirmBtn.BackColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
    $confirmBtn.ForeColor = [System.Drawing.Color]::White
    $confirmBtn.Add_Click({
        # 关闭详情弹窗，执行卸载
        $detailForm.Close()
        Uninstall-Software $software
        Load-SoftwareData  # 重新加载软件列表，刷新界面
    })

    # 取消按钮
    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = "取消"
    $cancelBtn.Size = New-Object System.Drawing.Size(100, 30)
    $cancelBtn.Location = New-Object System.Drawing.Point(170, 5)
    $cancelBtn.Add_Click({ $detailForm.Close() })

    # 添加控件到弹窗
    $btnPanel.Controls.AddRange(@($confirmBtn, $cancelBtn))
    $detailForm.Controls.AddRange(@($detailTextBox, $btnPanel))

    # 显示弹窗（阻塞模式，直到用户操作）
    $detailForm.ShowDialog() | Out-Null
}

function Open-SoftwareRegistry
{
    param($RegistryPath)
    try
    {
        # 验证注册表路径是否有效
        if ([string]::IsNullOrEmpty($RegistryPath) -or (-not (Test-Path $RegistryPath)))
        {
            [System.Windows.Forms.MessageBox]::Show("该软件的注册表路径无效或不存在`n路径: $RegistryPath", "提示", "OK", "Information")
            return
        }

        # 转换路径格式：regedit需要“计算机\”前缀（PowerShell的Registry路径默认不带）
        $regEditPath = "计算机\$RegistryPath"
        # 启动regedit并定位到指定路径（/e 参数用于导出，/s 用于静默，这里用 /select 直接定位）
        Start-Process -FilePath "regedit.exe" -ArgumentList "/select, `"$regEditPath`"" -ErrorAction Stop

        $statusLabel.Text = "已打开注册表位置: $RegistryPath"
    }
    catch
    {
        $errorMsg = "打开注册表失败: $( $_.Exception.Message )"
        $statusLabel.Text = $errorMsg
        [System.Windows.Forms.MessageBox]::Show($errorMsg, "错误", "OK", "Error")
    }
}

# -----------------------------
# 5. 绑定事件
# -----------------------------
$searchBox.Add_TextChanged({ Filter-Software })
$showSystemCheck.Add_CheckedChanged({ Filter-Software })
$uninstallButton.Add_Click({ Uninstall-Selected })
$backupRegButton.Add_Click({ Backup-Registry })
$exportCSVButton.Add_Click({ Export-ToCSV })
$darkModeCheck.Add_CheckedChanged({ Apply-Theme })

$form.Add_Resize({ $softwareGrid.AutoResizeColumns() })

# 双击打开安装目录
$softwareGrid.Add_CellDoubleClick({
    param($sender, $e)
    if ($e.RowIndex -ge 0)
    {
        $software = $softwareGrid.Rows[$e.RowIndex].DataBoundItem
        if ($software.InstallLocation -and (Test-Path $software.InstallLocation))
        {
            Start-Process $software.InstallLocation
        }
        else
        {
            [System.Windows.Forms.MessageBox]::Show("安装路径不存在或未知", "提示", "OK", "Information")
        }
    }
})

# -----------------------------
# 6. 右键菜单
# -----------------------------
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$uninstallMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$uninstallMenuItem.Text = "卸载此软件"
$uninstallMenuItem.Add_Click({
    if ($softwareGrid.SelectedRows.Count -gt 0)
    {
        # 获取当前选中行的软件数据，调用详情弹窗函数
        $selectedSoftware = $softwareGrid.SelectedRows[0].DataBoundItem
        Show-SoftwareDetailAndUninstall $selectedSoftware
    }
})

#$uninstallMenuItem.Add_Click({
#    if ($softwareGrid.SelectedRows.Count -gt 0)
#    {
#        Uninstall-Software $softwareGrid.SelectedRows[0].DataBoundItem
#        Load-SoftwareData
#    }
#})
$contextMenu.Items.Add($uninstallMenuItem)

# 新增：打开注册表位置菜单项
$openRegMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openRegMenuItem.Text = "打开注册表位置"
# 绑定点击事件
$openRegMenuItem.Add_Click({
    if ($softwareGrid.SelectedRows.Count -gt 0)
    {
        # 获取当前选中行的软件注册表路径
        $selectedSoftware = $softwareGrid.SelectedRows[0].DataBoundItem
        Open-SoftwareRegistry -RegistryPath $selectedSoftware.RegistryPath
    }
})
# 将菜单项添加到右键菜单（可调整顺序，这里放在“卸载”之后）
$contextMenu.Items.Add($openRegMenuItem)


$softwareGrid.ContextMenuStrip = $contextMenu

# -----------------------------
# 7. 启动程序
# -----------------------------
Load-SoftwareData
Apply-Theme
$form.ShowDialog() | Out-Null
