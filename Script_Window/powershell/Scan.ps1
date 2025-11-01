Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, PresentationFramework.Aero
Add-Type -AssemblyName System.Xaml

# 主窗口
$window = New-Object System.Windows.Window
$window.Title = "Windows 文件安全管理工具"
$window.Width = 1300
$window.Height = 800
$window.MinWidth = 1100
$window.MinHeight = 700
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
$window.Background = [System.Windows.Media.Brush]::White

# 创建资源字典，用于样式定义
$resources = New-Object System.Windows.ResourceDictionary

# 定义主色调
$primaryColor = [System.Windows.Media.Color]::FromArgb(255, 26, 102, 192) # #1A66C0
$primaryBrush = New-Object System.Windows.Media.SolidColorBrush($primaryColor)
$secondaryColor = [System.Windows.Media.Color]::FromArgb(255, 45, 125, 219) # #2D7DDB
$accentColor = [System.Windows.Media.Color]::FromArgb(255, 110, 190, 245) # #6EBCF5
$textColor = [System.Windows.Media.Color]::FromArgb(255, 51, 51, 51) # #333333
$lightGray = [System.Windows.Media.Color]::FromArgb(255, 240, 240, 240) # #F0F0F0
$borderColor = [System.Windows.Media.Color]::FromArgb(255, 220, 220, 220) # #DCDCDC

function New-Setter
{
    param(
        [System.Windows.DependencyProperty]$Property,
        $Value
    )
    if (-not $Property)
    {
        throw "Property cannot be null."
    }
    return New-Object System.Windows.Setter -ArgumentList $Property, $Value
}

# 定义按钮样式
$buttonStyle = New-Object System.Windows.Style([System.Windows.Controls.Button])
$buttonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BackgroundProperty $primaryBrush))
$buttonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::ForegroundProperty [System.Windows.Media.Brushes]::White))
$buttonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::PaddingProperty (New-Object System.Windows.Thickness(12, 6, 12, 6))))
$buttonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BorderThicknessProperty (New-Object System.Windows.Thickness(0))))
$buttonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::MarginProperty (New-Object System.Windows.Thickness(5))))
$buttonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontWeightProperty [System.Windows.FontWeights]::Normal))
$buttonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontSizeProperty ([double]14)))

# 创建悬停颜色画笔
$hoverColor = [System.Windows.Media.ColorConverter]::ConvertFromString("#007ACC")
$hoverBrush = New-Object System.Windows.Media.SolidColorBrush($hoverColor)

# 创建选中按钮样式
$selectedButtonStyle = New-Object System.Windows.Style -ArgumentList ([System.Windows.Controls.Button])
$selectedButtonStyle.BasedOn = $buttonStyle  # 基于基础样式

# 添加 Setters（使用正确的参数传递方式）
$selectedButtonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BackgroundProperty $hoverBrush))
$selectedButtonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontWeightProperty [System.Windows.FontWeights]::Bold))
$selectedButtonStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontSizeProperty ([double]14)))

# 添加到资源字典
$resources.Add("SelectedButtonStyle", $selectedButtonStyle)
$resources.Add("ButtonStyle", $buttonStyle)

# 输入框样式
$inputStyle = New-Object System.Windows.Style([System.Windows.Controls.TextBox])
$inputStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BackgroundProperty [System.Windows.Media.Brushes]::White))
$inputStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BorderBrushProperty (New-Object System.Windows.Media.SolidColorBrush($borderColor))))
$inputStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BorderThicknessProperty (New-Object System.Windows.Thickness(1))))
$inputStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::PaddingProperty (New-Object System.Windows.Thickness(8, 4, 8, 4))))
$inputStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontSizeProperty ([double]12)))
$inputStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::VerticalAlignmentProperty [System.Windows.VerticalAlignment]::Center))
$inputStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::MarginProperty (New-Object System.Windows.Thickness(5))))
$resources.Add("InputStyle", $inputStyle)

# 下拉框样式
$comboStyle = New-Object System.Windows.Style([System.Windows.Controls.ComboBox])
$comboStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BackgroundProperty [System.Windows.Media.Brushes]::White))
$comboStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BorderBrushProperty (New-Object System.Windows.Media.SolidColorBrush($borderColor))))
$comboStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BorderThicknessProperty (New-Object System.Windows.Thickness(1))))
$comboStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::PaddingProperty (New-Object System.Windows.Thickness(8, 4, 8, 4))))
$comboStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontSizeProperty ([double]12)))
$comboStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::VerticalAlignmentProperty [System.Windows.VerticalAlignment]::Center))
$comboStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::MarginProperty (New-Object System.Windows.Thickness(5))))
$resources.Add("ComboStyle", $comboStyle)

# 标签样式
$labelStyle = New-Object System.Windows.Style([System.Windows.Controls.Label])
$labelStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::ForegroundProperty (New-Object System.Windows.Media.SolidColorBrush($textColor))))
$labelStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontSizeProperty ([double]12)))
$labelStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::VerticalAlignmentProperty [System.Windows.VerticalAlignment]::Center))
$labelStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::MarginProperty (New-Object System.Windows.Thickness(5, 0, 5, 0))))
$resources.Add("LabelStyle", $labelStyle)

# 卡片样式
$cardStyle = New-Object System.Windows.Style([System.Windows.Controls.Border])
$cardStyle.Setters.Add((New-Setter [System.Windows.Controls.Border]::BackgroundProperty [System.Windows.Media.Brushes]::White))
$cardStyle.Setters.Add((New-Setter [System.Windows.Controls.Border]::BorderBrushProperty (New-Object System.Windows.Media.SolidColorBrush($borderColor))))
$cardStyle.Setters.Add((New-Setter [System.Windows.Controls.Border]::BorderThicknessProperty (New-Object System.Windows.Thickness(1))))
$cardStyle.Setters.Add((New-Setter [System.Windows.Controls.Border]::CornerRadiusProperty (New-Object System.Windows.CornerRadius(8))))
$cardStyle.Setters.Add((New-Setter [System.Windows.Controls.Border]::PaddingProperty (New-Object System.Windows.Thickness(15))))
$cardStyle.Setters.Add((New-Setter [System.Windows.Controls.Border]::MarginProperty (New-Object System.Windows.Thickness(15))))
$resources.Add("CardStyle", $cardStyle)

# 数据网格样式
$dataGridStyle = New-Object System.Windows.Style([System.Windows.Controls.DataGrid])
$dataGridStyle.Setters.Add((New-Setter [System.Windows.Controls.DataGrid]::BackgroundProperty [System.Windows.Media.Brushes]::White))
$dataGridStyle.Setters.Add((New-Setter [System.Windows.Controls.DataGrid]::BorderBrushProperty (New-Object System.Windows.Media.SolidColorBrush($borderColor))))
$dataGridStyle.Setters.Add((New-Setter [System.Windows.Controls.DataGrid]::BorderThicknessProperty (New-Object System.Windows.Thickness(1))))
$dataGridStyle.Setters.Add((New-Setter [System.Windows.Controls.DataGrid]::RowHeightProperty 32))
$dataGridStyle.Setters.Add((New-Setter [System.Windows.Controls.DataGrid]::AlternatingRowBackgroundProperty [System.Windows.Media.Colors]::White))

$headerStyle = New-Object System.Windows.Style([System.Windows.Controls.Primitives.DataGridColumnHeader])
$headerStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::BackgroundProperty $primaryBrush))
$headerStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::ForegroundProperty [System.Windows.Media.Brushes]::White))
$headerStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontSizeProperty ([double]12)))
$headerStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::FontWeightProperty [System.Windows.FontWeights]::SemiBold))
$headerStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::PaddingProperty (New-Object System.Windows.Thickness(10, 5, 10, 5))))

# 应用到 DataGrid 的 HeaderStyle
$dataGridStyle = New-Object System.Windows.Style([System.Windows.Controls.DataGrid])
$dataGridStyle.Setters.Add((New-Setter [System.Windows.Controls.DataGrid]::ColumnHeaderStyleProperty $headerStyle))

# 创建 DataGridCell 的样式
$cellStyle = New-Object System.Windows.Style([System.Windows.Controls.DataGridCell])
$cellStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::PaddingProperty (New-Object System.Windows.Thickness(10, 5, 10, 5))))
$cellStyle.Setters.Add((New-Setter [System.Windows.Controls.Control]::VerticalAlignmentProperty [System.Windows.VerticalAlignment]::Center))

# 应用到 DataGrid
$dataGridStyle.Setters.Add((New-Setter [System.Windows.Controls.DataGrid]::CellStyleProperty $cellStyle))

$resources.Add("DataGridStyle", $dataGridStyle)

$window.Resources = $resources

# 创建主布局容器
$mainGrid = New-Object System.Windows.Controls.Grid
$mainGrid.Margin = 10

# 定义网格列和行
$mainGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))

$row1 = New-Object System.Windows.Controls.RowDefinition
$row1.Height = 60
$mainGrid.RowDefinitions.Add($row1)  # 标题行

$row2 = New-Object System.Windows.Controls.RowDefinition
$row2.Height = 50
$mainGrid.RowDefinitions.Add($row2)  # 功能切换栏

$row3 = New-Object System.Windows.Controls.RowDefinition
$row3.Height = 200
$mainGrid.RowDefinitions.Add($row3)  # 查询条件栏

$row4 = New-Object System.Windows.Controls.RowDefinition
$row4.Height = "*"
$mainGrid.RowDefinitions.Add($row4)  # 内容区域

$row5 = New-Object System.Windows.Controls.RowDefinition
$row5.Height = 60
$mainGrid.RowDefinitions.Add($row5)  # 底部按钮

$window.Content = $mainGrid

# 标题
$titleText = New-Object System.Windows.Controls.TextBlock
$titleText.Text = "Windows 文件安全管理工具"
$titleText.FontSize = 20
$titleText.FontWeight = [System.Windows.FontWeights]::Bold
$titleText.Foreground = [System.Windows.Media.SolidColorBrush]$textColor
$titleText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$titleText.Margin = 5
[System.Windows.Controls.Grid]::SetRow($titleText, 0)
$mainGrid.Children.Add($titleText)

# 功能切换栏
$toggleBar = New-Object System.Windows.Controls.StackPanel
$toggleBar.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$toggleBar.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
$toggleBar.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
[System.Windows.Controls.Grid]::SetRow($toggleBar, 1)
$mainGrid.Children.Add($toggleBar)

# 切换按钮
$btnRecent = New-Object System.Windows.Controls.Button
$btnRecent.Content = "最近文档"
$btnRecent.Style = $window.Resources["SelectedButtonStyle"]
$btnRecent.Tag = "Recent"
$btnRecent.Width = 90

$btnTempLogs = New-Object System.Windows.Controls.Button
$btnTempLogs.Content = "临时日志文件"
$btnTempLogs.Style = $window.Resources["ButtonStyle"]
$btnTempLogs.Tag = "TempLogs"
$btnTempLogs.Width = 130

$toggleBar.Children.Add($btnRecent)
$toggleBar.Children.Add($btnTempLogs)

# 查询条件卡
$filterCard = New-Object System.Windows.Controls.Border
$filterCard.Style = $window.Resources["CardStyle"]
[System.Windows.Controls.Grid]::SetRow($filterCard, 2)
$mainGrid.Children.Add($filterCard)

# 查询条件布局
$filterGrid = New-Object System.Windows.Controls.Grid
$filterGrid.Margin = 0
$filterCard.Child = $filterGrid

# 定义查询条件网格
$filterGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
$filterGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
$filterGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
$filterGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
$filterGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
$filterGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))

$filterGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
$filterGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
$filterGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
$filterGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))

# 文件名搜索
$searchLabel = New-Object System.Windows.Controls.Label
$searchLabel.Content = "文件名:"
$searchLabel.Style = $window.Resources["LabelStyle"]
[System.Windows.Controls.Grid]::SetRow($searchLabel, 0)
[System.Windows.Controls.Grid]::SetColumn($searchLabel, 0)
$filterGrid.Children.Add($searchLabel)

$inputLength = 200
$searchBox = New-Object System.Windows.Controls.TextBox
$searchBox.Width = $inputLength
$searchBox.Style = $window.Resources["InputStyle"]
$searchBox.ToolTip = "输入文件名进行搜索..."
[System.Windows.Controls.Grid]::SetRow($searchBox, 0)
[System.Windows.Controls.Grid]::SetColumn($searchBox, 1)
$filterGrid.Children.Add($searchBox)

# 开始时间
$startLabel = New-Object System.Windows.Controls.Label
$startLabel.Content = "开始时间:"
$startLabel.Style = $window.Resources["LabelStyle"]
[System.Windows.Controls.Grid]::SetRow($startLabel, 1)
[System.Windows.Controls.Grid]::SetColumn($startLabel, 0)
$filterGrid.Children.Add($startLabel)

$startDateTimeBox = New-Object System.Windows.Controls.TextBox
$startDateTimeBox.Width = $inputLength
$startDateTimeBox.Style = $window.Resources["InputStyle"]
$startDateTimeBox.ToolTip = "格式: yyyy-MM-dd HH:mm:ss"
$startDateTimeBox.Text = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd HH:mm:ss")
[System.Windows.Controls.Grid]::SetRow($startDateTimeBox, 1)
[System.Windows.Controls.Grid]::SetColumn($startDateTimeBox, 1)
$filterGrid.Children.Add($startDateTimeBox)

# 结束时间
$endLabel = New-Object System.Windows.Controls.Label
$endLabel.Content = "结束时间:"
$endLabel.Style = $window.Resources["LabelStyle"]
[System.Windows.Controls.Grid]::SetRow($endLabel, 1)
[System.Windows.Controls.Grid]::SetColumn($endLabel, 3)
$filterGrid.Children.Add($endLabel)

$endDateTimeBox = New-Object System.Windows.Controls.TextBox
$endDateTimeBox.Width = $inputLength
$endDateTimeBox.Style = $window.Resources["InputStyle"]
$endDateTimeBox.ToolTip = "格式: yyyy-MM-dd HH:mm:ss"
$endDateTimeBox.Text = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
[System.Windows.Controls.Grid]::SetRow($endDateTimeBox, 1)
[System.Windows.Controls.Grid]::SetColumn($endDateTimeBox, 4)
$filterGrid.Children.Add($endDateTimeBox)

# 最小大小
$minSizeLabel = New-Object System.Windows.Controls.Label
$minSizeLabel.Content = "最小大小:"
$minSizeLabel.Style = $window.Resources["LabelStyle"]
[System.Windows.Controls.Grid]::SetRow($minSizeLabel, 2)
[System.Windows.Controls.Grid]::SetColumn($minSizeLabel, 0)
$filterGrid.Children.Add($minSizeLabel)

$minSizeBox = New-Object System.Windows.Controls.TextBox
$minSizeBox.Width = $inputLength
$minSizeBox.Style = $window.Resources["InputStyle"]
$minSizeBox.ToolTip = "输入最小文件大小"
[System.Windows.Controls.Grid]::SetRow($minSizeBox, 2)
[System.Windows.Controls.Grid]::SetColumn($minSizeBox, 1)
$filterGrid.Children.Add($minSizeBox)

$minSizeUnit = New-Object System.Windows.Controls.ComboBox
$minSizeUnit.Width = 60
$minSizeUnit.Style = $window.Resources["ComboStyle"]
$minSizeUnit.Items.Add("B")
$minSizeUnit.Items.Add("KB")
$minSizeUnit.Items.Add("MB")
$minSizeUnit.Items.Add("GB")
$minSizeUnit.SelectedItem = "KB"
[System.Windows.Controls.Grid]::SetRow($minSizeUnit, 2)
[System.Windows.Controls.Grid]::SetColumn($minSizeUnit, 2)
$filterGrid.Children.Add($minSizeUnit)

# 最大大小
$maxSizeLabel = New-Object System.Windows.Controls.Label
$maxSizeLabel.Content = "最大大小:"
$maxSizeLabel.Style = $window.Resources["LabelStyle"]
[System.Windows.Controls.Grid]::SetRow($maxSizeLabel, 2)
[System.Windows.Controls.Grid]::SetColumn($maxSizeLabel, 3)
$filterGrid.Children.Add($maxSizeLabel)

$maxSizeBox = New-Object System.Windows.Controls.TextBox
$maxSizeBox.Width = $inputLength
$maxSizeBox.Style = $window.Resources["InputStyle"]
$maxSizeBox.ToolTip = "输入最大文件大小"
[System.Windows.Controls.Grid]::SetRow($maxSizeBox, 2)
[System.Windows.Controls.Grid]::SetColumn($maxSizeBox, 4)
$filterGrid.Children.Add($maxSizeBox)

$maxSizeUnit = New-Object System.Windows.Controls.ComboBox
$maxSizeUnit.Width = 60
$maxSizeUnit.Style = $window.Resources["ComboStyle"]
$maxSizeUnit.Items.Add("B")
$maxSizeUnit.Items.Add("KB")
$maxSizeUnit.Items.Add("MB")
$maxSizeUnit.Items.Add("GB")
$maxSizeUnit.SelectedItem = "MB"
[System.Windows.Controls.Grid]::SetRow($maxSizeUnit, 2)
[System.Windows.Controls.Grid]::SetColumn($maxSizeUnit, 5)
$filterGrid.Children.Add($maxSizeUnit)

# 查询和重置按钮
$queryPanel = New-Object System.Windows.Controls.StackPanel
$queryPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$queryPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
[System.Windows.Controls.Grid]::SetRow($queryPanel, 3)
[System.Windows.Controls.Grid]::SetColumn($queryPanel, 0)
$filterGrid.Children.Add($queryPanel)

$btnQuery = New-Object System.Windows.Controls.Button
$btnQuery.Content = "查询"
$btnQuery.Style = $window.Resources["ButtonStyle"]
$btnQuery.Width = 70
$queryPanel.Children.Add($btnQuery)

$btnReset = New-Object System.Windows.Controls.Button
$btnReset.Content = "重置"
$btnReset.Style = $window.Resources["ButtonStyle"]
$btnReset.Width = 70
$queryPanel.Children.Add($btnReset)

# 内容区域容器
$contentContainer = New-Object System.Windows.Controls.Border
$contentContainer.Style = $window.Resources["CardStyle"]
[System.Windows.Controls.Grid]::SetRow($contentContainer, 3)
$mainGrid.Children.Add($contentContainer)

# 内容区域布局
$contentGrid = New-Object System.Windows.Controls.Grid
$contentContainer.Child = $contentGrid

$contentRow = New-Object System.Windows.Controls.RowDefinition
$contentRow.Height = "*"
$contentGrid.RowDefinitions.Add($contentRow)

# 创建数据表格
$fileDataGrid = New-Object System.Windows.Controls.DataGrid
$fileDataGrid.AutoGenerateColumns = $false
$fileDataGrid.CanUserAddRows = $false
$fileDataGrid.CanUserDeleteRows = $false
$fileDataGrid.IsReadOnly = $true
$fileDataGrid.SelectionMode = [System.Windows.Controls.DataGridSelectionMode]::Single
$fileDataGrid.Margin = 5
$fileDataGrid.GridLinesVisibility = [System.Windows.Controls.DataGridGridLinesVisibility]::Horizontal
$fileDataGrid.Background = [System.Windows.Media.Brushes]::White
$fileDataGrid.Style = $window.Resources["DataGridStyle"]
[System.Windows.Controls.Grid]::SetRow($fileDataGrid, 0)
$contentGrid.Children.Add($fileDataGrid)

# 定义表格列
$colName = New-Object System.Windows.Controls.DataGridTextColumn
$colName.Header = "文件名称"
$colName.Binding = [System.Windows.Data.Binding]"Name"
$colName.Width = 200
$fileDataGrid.Columns.Add($colName)

$colSize = New-Object System.Windows.Controls.DataGridTextColumn
$colSize.Header = "大小(字节)"
$colSize.Binding = [System.Windows.Data.Binding]"Size"
$colSize.Width = 120
$colSize.ElementStyle = New-Object System.Windows.Style([System.Windows.Controls.TextBlock])
$colSize.ElementStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Right)))
$colSize.ElementStyle.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::ToolTipProperty, [System.Windows.Data.Binding]"FormattedSize")))
$fileDataGrid.Columns.Add($colSize)

$colLastModified = New-Object System.Windows.Controls.DataGridTextColumn
$colLastModified.Header = "更新时间"
$colLastModified.Binding = [System.Windows.Data.Binding]"LastModified"
$colLastModified.Width = 180
$fileDataGrid.Columns.Add($colLastModified)

$colPath = New-Object System.Windows.Controls.DataGridTextColumn
$colPath.Header = "路径"
$colPath.Binding = [System.Windows.Data.Binding]"Path"
$colPath.Width = "*"
$fileDataGrid.Columns.Add($colPath)

# 底部按钮区域
$bottomPanel = New-Object System.Windows.Controls.StackPanel
$bottomPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$bottomPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
$bottomPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
[System.Windows.Controls.Grid]::SetRow($bottomPanel, 4)
$mainGrid.Children.Add($bottomPanel)

# 刷新按钮
$btnRefresh = New-Object System.Windows.Controls.Button
$btnRefresh.Content = "刷新"
$btnRefresh.Style = $window.Resources["ButtonStyle"]
$btnRefresh.Width = 70
$bottomPanel.Children.Add($btnRefresh)

# 退出按钮
$btnExit = New-Object System.Windows.Controls.Button
$btnExit.Content = "退出"
$btnExit.Style = $window.Resources["ButtonStyle"]
$btnExit.Width = 70
$bottomPanel.Children.Add($btnExit)

# 创建右键菜单
$contextMenu = New-Object System.Windows.Controls.ContextMenu

# 删除文件菜单项
$miDelete = New-Object System.Windows.Controls.MenuItem
$miDelete.Header = "删除文件"
$miDelete.Add_Click({
    if ($fileDataGrid.SelectedItem)
    {
        $path = $fileDataGrid.SelectedItem.Path
        if (-not [string]::IsNullOrEmpty($path) -and (Test-Path -Path $path))
        {
            $result = [System.Windows.MessageBox]::Show(
                    "确定要删除文件 '$path' 吗？`n此操作不可恢复！",
                    "确认删除",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning
            )

            if ($result -eq [System.Windows.MessageBoxResult]::Yes)
            {
                try
                {
                    Remove-Item -Path $path -Force -ErrorAction Stop
                    [System.Windows.MessageBox]::Show("文件已成功删除", "操作成功", "OK", "Information")
                    Apply-Filters  # 刷新列表
                }
                catch
                {
                    [System.Windows.MessageBox]::Show("删除文件失败: $( $_.Exception.Message )", "错误", "OK", "Error")
                }
            }
        }
        else
        {
            [System.Windows.MessageBox]::Show("文件路径无效或不存在", "错误", "OK", "Error")
        }
    }
})
$contextMenu.Items.Add($miDelete)

# 属性菜单项
$miProperties = New-Object System.Windows.Controls.MenuItem
$miProperties.Header = "属性"
$miProperties.Add_Click({
    if ($fileDataGrid.SelectedItem)
    {
        $path = $fileDataGrid.SelectedItem.Path
        if (-not [string]::IsNullOrEmpty($path) -and (Test-Path -Path $path))
        {
            # 使用Windows资源管理器显示文件属性
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "explorer.exe"
            $psi.Arguments = "/select,`"$path`""
            [System.Diagnostics.Process]::Start($psi)

            # 等待资源管理器打开
            Start-Sleep -Milliseconds 500

            # 发送Alt+Enter快捷键打开属性窗口
            Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            public class Keyboard {
                [DllImport("user32.dll")]
                public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
            }
"@
            # Alt键按下
            [Keyboard]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
            # Enter键按下并释放
            [Keyboard]::keybd_event(0x0D, 0, 0, [UIntPtr]::Zero)
            [Keyboard]::keybd_event(0x0D, 0, 2, [UIntPtr]::Zero)
            # Alt键释放
            [Keyboard]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
        }
        else
        {
            [System.Windows.MessageBox]::Show("文件路径无效或不存在", "错误", "OK", "Error")
        }
    }
})
$contextMenu.Items.Add($miProperties)

# 为数据表格添加右键菜单
$fileDataGrid.ContextMenu = $contextMenu

# 格式化文件大小
function Format-FileSize
{
    param([long]$size)
    if ($size -ge 1GB)
    {
        return "{0:N2} GB" -f ($size / 1GB)
    }
    elseif ($size -ge 1MB)
    {
        return "{0:N2} MB" -f ($size / 1MB)
    }
    elseif ($size -ge 1KB)
    {
        return "{0:N2} KB" -f ($size / 1KB)
    }
    else
    {
        return "$size B"
    }
}

# 转换大小单位为字节
function Convert-ToBytes
{
    param(
        [double]$value,
        [string]$unit
    )
    switch ($unit)
    {
        "B"  { return $value }
        "KB" { return $value * 1KB }
        "MB" { return $value * 1MB }
        "GB" { return $value * 1GB }
        default { return $value }
    }
}

# 验证并转换日期时间字符串
function Convert-ToDateTime
{
    param(
        [string]$InputString,
        [string]$Format = "yyyy-MM-dd HH:mm:ss"
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $dateTime = Get-Date

    $result = [DateTime]::TryParseExact(
            $InputString,
            $Format,
            $culture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$dateTime
    )

    if ($result)
    {
        return $dateTime
    }
    else
    {
        return $null
    }
}

# 获取最近文档
function Get-RecentDocuments
{
    $recentDocsPath = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\Recent"

    if ([string]::IsNullOrEmpty($recentDocsPath) -or (-not (Test-Path -Path $recentDocsPath)))
    {
        Write-Verbose "最近文档路径无效或不存在: $recentDocsPath"
        return
    }

    Get-ChildItem -Path $recentDocsPath -Filter *.lnk -File -ErrorAction SilentlyContinue | ForEach-Object {
        try
        {
            $shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
            $shortcut = $shell.CreateShortcut($_.FullName)

            if (-not [string]::IsNullOrEmpty($shortcut.TargetPath) -and (Test-Path -Path $shortcut.TargetPath -PathType Leaf))
            {
                $fileInfo = Get-Item -Path $shortcut.TargetPath -ErrorAction Stop
                [PSCustomObject]@{
                    Name = $fileInfo.Name
                    Size = $fileInfo.Length
                    FormattedSize = Format-FileSize $fileInfo.Length
                    LastModified = $fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                    Path = $fileInfo.FullName
                    RawSize = $fileInfo.Length
                    RawDate = $fileInfo.LastWriteTime
                }
            }
        }
        catch
        {
            Write-Verbose "处理快捷方式时出错: $( $_.Exception.Message )"
        }
    } | Sort-Object -Property RawDate -Descending
}

# 获取临时日志文件
$tempPaths = @(
    $env:TEMP,
    "C:\Windows\Temp",
    (Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\Temp")
)

function Get-TempLogFiles
{
    $logFiles = @()
    foreach ($path in $tempPaths)
    {
        if ([string]::IsNullOrEmpty($path) -or (-not (Test-Path -Path $path -ErrorAction SilentlyContinue)))
        {
            Write-Verbose "临时路径无效或不存在: $path"
            continue
        }

        try
        {
            $logFiles += Get-ChildItem -Path $path -Include *.log, *.txt -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Size = $_.Length
                    FormattedSize = Format-FileSize $_.Length
                    LastModified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                    Path = $_.FullName
                    RawSize = $_.Length
                    RawDate = $_.LastWriteTime
                }
            }
        }
        catch
        {
            Write-Verbose "获取日志文件时出错: $( $_.Exception.Message )"
        }
    }
    $logFiles | Sort-Object -Property RawDate -Descending
}

# 应用所有筛选条件
function Apply-Filters
{
    $currentType = if ($btnRecent.Style -eq $window.Resources["SelectedButtonStyle"])
    {
        "Recent"
    }
    else
    {
        "TempLogs"
    }
    $allData = if ($currentType -eq "Recent")
    {
        Get-RecentDocuments
    }
    else
    {
        Get-TempLogFiles
    }

    # 文本搜索筛选
    $filterText = $searchBox.Text.Trim().ToLower()
    if (-not [string]::IsNullOrEmpty($filterText))
    {
        $allData = $allData | Where-Object {
            $_.Name.ToLower().Contains($filterText) -or $_.Path.ToLower().Contains($filterText)
        }
    }

    # 时间范围筛选
    $startDate = Convert-ToDateTime $startDateTimeBox.Text
    $endDate = Convert-ToDateTime $endDateTimeBox.Text

    if ($startDate)
    {
        $allData = $allData | Where-Object { $_.RawDate -ge $startDate }
    }
    if ($endDate)
    {
        $allData = $allData | Where-Object { $_.RawDate -le $endDate }
    }

    # 文件大小筛选
    if ($minSizeBox.Text -and ([double]::TryParse($minSizeBox.Text, [ref]$minValue)))
    {
        $minBytes = Convert-ToBytes -value $minValue -unit $minSizeUnit.SelectedItem
        $allData = $allData | Where-Object { $_.RawSize -ge $minBytes }
    }

    if ($maxSizeBox.Text -and ([double]::TryParse($maxSizeBox.Text, [ref]$maxValue)))
    {
        $maxBytes = Convert-ToBytes -value $maxValue -unit $maxSizeUnit.SelectedItem
        $allData = $allData | Where-Object { $_.RawSize -le $maxBytes }
    }

    # 设置数据源
    $fileDataGrid.ItemsSource = $allData
}

# 重置按钮事件
$btnReset.Add_Click({
    $searchBox.Text = ""
    $startDateTimeBox.Text = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd HH:mm:ss")
    $endDateTimeBox.Text = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $minSizeBox.Text = ""
    $maxSizeBox.Text = ""
    $minSizeUnit.SelectedItem = "KB"
    $maxSizeUnit.SelectedItem = "MB"
    Apply-Filters
})

# 查询按钮事件
$btnQuery.Add_Click({ Apply-Filters })

# 搜索框事件
$searchBox.Add_TextChanged({ Apply-Filters })

# 切换按钮事件
$btnRecent.Add_Click({
    $btnRecent.Style = $window.Resources["SelectedButtonStyle"]
    $btnTempLogs.Style = $window.Resources["ButtonStyle"]
    Apply-Filters
})

$btnTempLogs.Add_Click({
    $btnTempLogs.Style = $window.Resources["SelectedButtonStyle"]
    $btnRecent.Style = $window.Resources["ButtonStyle"]
    Apply-Filters
})

# 刷新按钮事件
$btnRefresh.Add_Click({ Apply-Filters })

# 退出按钮事件
$btnExit.Add_Click({ $window.Close() })

# 双击表格行打开文件
$fileDataGrid.Add_MouseDoubleClick({
    if ($fileDataGrid.SelectedItem)
    {
        $path = $fileDataGrid.SelectedItem.Path
        if (-not [string]::IsNullOrEmpty($path) -and (Test-Path -Path $path))
        {
            Start-Process -FilePath $path
        }
        else
        {
            [System.Windows.MessageBox]::Show("文件路径无效或不存在: $path", "错误", "OK", "Error")
        }
    }
})

# 单位选择框事件
$minSizeUnit.Add_SelectionChanged({ Apply-Filters })
$maxSizeUnit.Add_SelectionChanged({ Apply-Filters })

# 初始加载最近文档
Apply-Filters

# 显示窗口
if (-not ([System.Windows.Application]::Current))
{
    $app = New-Object System.Windows.Application
}
else
{
    $app = [System.Windows.Application]::Current
}
$app.Run($window)