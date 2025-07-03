# 加载必要的 .NET 程序集
Add-Type -AssemblyName System.Windows.Forms

# 创建一个 OpenFileDialog 对象
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog

# 配置对话框属性（可选）
$openFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop') # 初始目录为桌面
$openFileDialog.Filter = "*.apk||*.exe|所有文件 (*.*)|*.*|文本文件 (*.exe)"         # 文件过滤器
$openFileDialog.Title = "请选择一个文件"                                    # 对话框标题
$openFileDialog.Multiselect = $false                                        # 是否允许多选

# 显示对话框并获取结果
$result = $openFileDialog.ShowDialog()

# 检查用户是否选择了文件
if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    $selectedFile = $openFileDialog.FileName
    Write-Output "你选择的文件是：$selectedFile"
}
else
{
    Write-Output "未选择任何文件。"
    exit 1
}

Pause