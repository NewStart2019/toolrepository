# 定义输出文件路径
$outputFile = "$env:USERPROFILE\Desktop\ServicesInfo.txt"

# 获取所有正在运行的服务信息
$services = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE State='Running'" | Select-Object Name, DisplayName, State, StartMode

# 格式化输出内容
$outputContent = $services | ForEach-Object {
    [PSCustomObject]@{
        名称      = $_.Name
        描述      = $_.DisplayName
        状态      = $_.State
        启动类型   = $_.StartMode
    }
}

# 将结果导出到文本文件
$outputContent | Format-Table -AutoSize | Out-String | Set-Content -Path $outputFile

Write-Host "服务信息已成功导出到 $outputFile"