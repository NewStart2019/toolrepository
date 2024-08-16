# 设置参数
$directoryPath = 'C:\path\to\your\directory' # 替换为你的目录路径
$daysOldToDelete = 30                       # 替换为你希望删除的文件的最小年龄（天）

# 获取当前日期
$now = Get-Date

# 获取指定目录下所有的文件
$files = Get-ChildItem $directoryPath -File

# 遍历每个文件，检查其最后修改日期
foreach ($file in $files) {
    # 计算文件的年龄（以天为单位）
    $fileAgeInDays = New-TimeSpan -Start $file.LastWriteTime -End $now

    # 如果文件年龄大于指定的天数，则删除该文件
    if ($fileAgeInDays.Days -gt $daysOldToDelete) {
        Write-Host "Deleting file: $($file.FullName)"
        Remove-Item $file.FullName -Force
    }
}
