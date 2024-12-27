# 用法说明：通过指定管道符号 过滤出指定文件的名称被进程占用的信息（文件名称 或 进程名称）
## .\ProcessUseFile.ps1 | findstr exe
## 使用场景：软件卸载不干净时

# 获取所有进程及其加载的模块（DLL）
$allDlls = Get-Process
# 获取第一个元素
$allDlls = Get-Process | ForEach-Object {
    $id = $_.Id
    $name = $_.Name
    $_.Modules | Select-Object FileName, @{ Name = 'ProcessId'; Expression = { $id } }, @{ Name = 'Name'; Expression = { $name } }
}

# 将结果去重并排序
$dllList = $allDlls | Sort-Object FileName -Unique

# 输出结果
$dllList | Format-Table -AutoSize