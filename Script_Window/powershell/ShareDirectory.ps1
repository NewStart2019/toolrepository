# 定义共享文件夹路径
$sharedFolderPath = "C:\Users\Administrator\Desktop\test"

# 检查共享文件夹是否存在，如果不存在则创建
if (-Not (Test-Path $sharedFolderPath)) {
    New-Item -ItemType Directory -Path $sharedFolderPath
    Write-Host "共享文件夹已创建: $sharedFolderPath"
}

# 配置共享权限（需要管理员权限运行）
$shareName = "SharedFolder"
$shareDescription = "共享文件夹及子目录"

Write-Host "文件夹已共享: $sharedFolderPath"

# 创建只读用户 read，并生成随机密码
$username = "read"
$password = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})

# 创建本地用户
New-LocalUser -Name $username -Password (ConvertTo-SecureString $password -AsPlainText -Force) -FullName "Read Only User" -Description "只读用户用于访问共享文件夹"

# 将用户添加到 Guests 组以限制权限
Add-LocalGroupMember -Group "Guests" -Member $username

# 使用Net Share命令共享文件夹
net share shareName=$sharedFolderPath /GRANT:$username,READ /REMARK:$shareDescription

Write-Host "只读用户已创建: 用户名=$username, 密码=$password"

# 设置NTFS权限为只读
$acl = Get-Acl $sharedFolderPath
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($username, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl $sharedFolderPath $acl

Write-Host "已设置只读权限给用户: $username"

# 输出只读用户的账号和密码
Write-Host "只读用户信息:"
Write-Host "用户名: $username"
Write-Host "密码: $password"

# 查询本地用户  Get-LocalUser
# 查询本地组  Get-LocalGroup
# 查询本地组成员  Get-LocalGroupMember
Pause

# read \ o7PduREt