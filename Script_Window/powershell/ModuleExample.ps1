# 创建一个动态模块
$module1 = New-Module -Name UserManagementModule {
    # 内部状态变量
    $loggedInUser = $null
    $logMessages = @()

    # 登录功能的闭包
    $loginClosure = {
        param ($username)
        if (-not [string]::IsNullOrWhiteSpace($username))
        {
            $script:loggedInUser = $username
            $script:logMessages += "$( Get-Date ): 用户 $username 登录成功"
            return "用户 $username 登录成功"
        }
        else
        {
            return "登录失败：用户名不能为空"
        }
    }

    # 注销功能的闭包
    $logoutClosure = {
        if ($script:loggedInUser)
        {
            $script:logMessages += "$( Get-Date ): 用户 $( $script:loggedInUser ) 注销成功"
            $script:loggedInUser = $null
            return "注销成功"
        }
        else
        {
            return "注销失败：没有用户登录"
        }
    }

    # 获取日志功能的闭包
    $getLogClosure = {
        return $script:logMessages
    }

    # 导出函数
    function Login-User
    {
        param ($username)
        return & $loginClosure $username
    }

    function Logout-User
    {
        return & $logoutClosure
    }

    function Get-Logs
    {
        return & $getLogClosure
    }

    Export-ModuleMember -Function Login-User, Logout-User, Get-Logs
} -PassThru

# 导入模块
Import-Module $module1  -DisableNameChecking

# 使用模块中的功能
Login-User -username "Alice"  # 输出：用户 Alice 登录成功
Get-Logs                      # 输出：[日志列表]
Logout-User                   # 输出：注销成功
Get-Logs                      # 输出：[更新后的日志列表]

function GetName
{
    Write-Host "lisi"
}

$v = "2","3"
# 创建一个动态模块，并使用 -PassThru 返回模块对象
$module = New-Module -Name MyDynamicModule -ArgumentList ${function:GetName}, $v  -ScriptBlock {

    param($GetNameFunc, $v)

    $moduleVarivale = "moduleVarivale"
    function Get-Greeting
    {
        param (
            [string]$Name = "World"
        )
        & $GetNameFunc
        Write-Host $v
        return "Hello, $Name!"
    }
    Write-Host "我是模块中执行的脚本呢……"
    Export-ModuleMember -Function Get-Greeting
    Export-ModuleMember -Variable moduleVarivale
}

# 查看返回的模块对象
#$module | Format-List *
## 使用模块中的函数
#& $module { Get-Greeting -Name "Alice" }

Import-Module $module -DisableNameChecking
Get-Greeting -Name "Alice"
Write-Host $moduleVarivale