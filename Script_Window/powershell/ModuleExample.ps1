# 创建一个动态模块
$module = New-Module -Name UserManagementModule {
    # 内部状态变量
    $loggedInUser = $null
    $logMessages = @()

    # 登录功能的闭包
    $loginClosure = {
        param ($username)
        if (-not [string]::IsNullOrWhiteSpace($username)) {
            $script:loggedInUser = $username
            $script:logMessages += "$(Get-Date): 用户 $username 登录成功"
            return "用户 $username 登录成功"
        } else {
            return "登录失败：用户名不能为空"
        }
    }

    # 注销功能的闭包
    $logoutClosure = {
        if ($script:loggedInUser) {
            $script:logMessages += "$(Get-Date): 用户 $($script:loggedInUser) 注销成功"
            $script:loggedInUser = $null
            return "注销成功"
        } else {
            return "注销失败：没有用户登录"
        }
    }

    # 获取日志功能的闭包
    $getLogClosure = {
        return $script:logMessages
    }

    # 导出函数
    function Login-User {
        param ($username)
        return & $loginClosure $username
    }

    function Logout-User {
        return & $logoutClosure
    }

    function Get-Logs {
        return & $getLogClosure
    }

    Export-ModuleMember -Function Login-User, Logout-User, Get-Logs
} -PassThru

# 导入模块
Import-Module $module

# 使用模块中的功能
Login-User -username "Alice"  # 输出：用户 Alice 登录成功
Get-Logs                      # 输出：[日志列表]
Logout-User                   # 输出：注销成功
Get-Logs                      # 输出：[更新后的日志列表]