Param (
    [Parameter(Mandatory = $false)]
    [string]$type = 'JS'
)

chcp 65001  # 设置为 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

# 定义URL
$url = "http://172.16.0.226/api/inspeItem/itemAllTree?bizKey=$type&current=1&pageSize=10"

# 设置请求头
$headers = @{
    'Content-Type' = 'application/json'
    'Accept-Charset' = 'utf-8'
    'accesstoken' = 'T6sCXvIRSZ707DqRL3XJyPmSjmCQj40ykRuMCEOGfMAwtnxoQ5nr2k6krpTgRmW1iBJQmP5o5AVlWn3xMIOZB0ILxd47QXtC8gCLathq9D1NEUmCqUhPNcIUQOin3XzL'
}

function Get-RepuestApi($url, $headers)
{
    # 发送GET请求
    $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get
    # 将响应内容转换为UTF-8编码
    $content = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($response.Content))
    # 将内容转换为JSON对象
    $jsonObject = ConvertFrom-Json -InputObject $content

    # 将JSON对象转换为字典对象
    $dictionary = @{}
    if ($jsonObject -is [System.Array]) {
        # 如果响应是数组，处理每个元素
        foreach ($item in $jsonObject) {
            foreach ($property in $item.PSObject.Properties) {
                $dictionary[$property.Name] = $property.Value
            }
        }
    } elseif ($jsonObject -is [PSCustomObject]) {
        # 如果响应是单个对象，处理其属性
        foreach ($property in $jsonObject.PSObject.Properties) {
            $dictionary[$property.Name] = $property.Value
        }
    } else {
        # 如果响应不是对象或数组，直接赋值
        $dictionary['Response'] = $jsonObject
    }
    return $dictionary
}

# 递归获取参数信息
function Get-Param($item)
{
    if ($item.type -eq "2")
    {
        $paramUrl = 'http://172.16.0.226/api/inspeItem/sortParamsList?inspeItemId=' + $item.id
        $paramResponse = Invoke-WebRequest -Uri $paramUrl -Headers $headers -Method Get
        $paramResponse = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($paramResponse.Content))
        $paramDictionary = ConvertFrom-Json -InputObject $paramResponse
        $item["paramData"] = $paramDictionary.data
    }
    else
    {
        foreach ($subItem in $item.children)
        {
            Get-Param -item $subItem
        }
    }
}


foreach ($item in $dictionary.data)
{
    Get-Param -item $item
}