

# 检查网络能够到达服务器，能够到达返回true，否则返回false
# 示例： $result = Test-NetworkConnectivity -Target "8.8.8.8"
function Test-NetworkConnectivity {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Target
    )
    return Test-Connection -ComputerName $Target -Count 1 -Quiet
}