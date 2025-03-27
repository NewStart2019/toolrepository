chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 指定字体输出颜色
function Write-ColoredText
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White')]
        [string]$Color = 'Green'
    )

    # 获取当前的前景色
    $originalForegroundColor = $host.UI.RawUI.ForegroundColor

    try
    {
        # 设置新的前景色
        $host.UI.RawUI.ForegroundColor = $Color

        # 使用 Write-Host 输出彩色文本
        Write-Host $Text
    }
    finally
    {
        # 恢复原始的前景色
        $host.UI.RawUI.ForegroundColor = $originalForegroundColor
    }
}

function ConvertTo-Hashtable {
    param (
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject
    }

    $hashTable = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.Value -is [System.Management.Automation.PSCustomObject]) {
            # 递归处理嵌套对象
            $hashTable[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        } else {
            $hashTable[$property.Name] = $property.Value
        }
    }
    return $hashTable
}

# 示例 PSObject
#$psObject = [PSCustomObject]@{
#    Name  = "Alice"
#    Age   = 30
#    Address = [PSCustomObject]@{
#        City  = "New York"
#        State = "NY"
#    }
#}

# 下载json文件转换为Hashtable数据
# Get-请求示例 使用示例：
#$hashtable = Get_Server -Url "http://xxxx.json"
function Get_JSON_TO_Hashtable
{
    param (
        [Parameter(Mandatory = $true)]
        $Url
    )

    # Invoke-RestMethod 是专门用于处理 REST API 的命令，可以直接将 JSON 数据解析为 PowerShell 对象。
    # 如果你只需要原始的 JSON 字符串，可以改用  Invoke-WebRequest
    $response = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json; charset=utf-8"

    if ($null -eq $response) { return $null }

    if ($response -is [System.Collections.IEnumerable] -and $response -isnot [string]) {
        $collection = @{}
        foreach ($item in $response.GetEnumerator()) {
            $collection[$item.Key] = ConvertTo-Hashtable -InputObject $item.Value
        }
        return $collection
    } elseif ($response -is [psobject]) {
        $hash = @{}
        foreach ($property in $response.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        return $hash
    } else {
        return $response
    }
}

. "$PSScriptRoot\EncryptAndDecrypt.ps1"

$url = "http://172.16.0.227:84/server/Server.json"
$hashtable = Get_JSON_TO_Hashtable -Url $url
$hashtable.Keys | ForEach-Object {
    $temp_key = $_
    $value = $hashtable[$temp_key]
    $value.ssh_passwd = Decrypt-String -cipherText $value.ssh_passwd -key $key -iv $iv
}

function Print_Server_Info
{
    # $servers 不为空 则输出服务器信息
    if ($hashtable -ne $null)
    {
        $hashtable.Keys | ForEach-Object {
            $temp_key = $_
            $value = $hashtable[$temp_key]
            # 左对齐，宽度为 10；右对齐，宽度为 5
            $output = "服务器名称: {0,-15} ip: {1,-15} 密码: {2,-20} 描述: {3,-20}" -f $temp_key, $value.ip, $value.ssh_passwd, $value.desc
            Write-ColoredText -Text $output
        }
    }
}

Print_Server_Info

$keysOutput = ($hashTable.Keys -join ", ")
Write-ColoredText -Text "服务器名称: $keysOutput"

$response = Invoke-WebRequest -Uri $Url -Method Get -ContentType "application/json; charset=utf-8"
$utf8Response = [System.Text.Encoding]::UTF8.GetString($response.Content)
Write-Output $utf8Response
