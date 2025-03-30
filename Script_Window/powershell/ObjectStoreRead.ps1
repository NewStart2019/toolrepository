[System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

# 浅层序列化
function Get-SerializedObjectFrom-Simple()
{
    # 将对象转换为字节数组（序列化）
    $memoryStream = New-Object System.IO.MemoryStream
    $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $binaryFormatter.Serialize($memoryStream, $originalObject)
    $serializedBytes = $memoryStream.ToArray()

    # 从字节数组反序列化为对象
    $memoryStream = New-Object System.IO.MemoryStream(,$serializedBytes)
    $Global:deserializedObject = $binaryFormatter.Deserialize($memoryStream)
}

# 复杂杜祥转xml
function Get-SerializedObjectFrom-Clixml()
{
    # 序列化到文件
    $filePath = "object.xml"
    $originalObject | Export-Clixml -Path $filePath

    # 从文件反序列化
    $Global:deserializedObject = Import-Clixml -Path $filePath
}

# 创建一个示例对象
$originalObject = @{
    Name = "Alice Johnson"
    Age = 28
    IsActive = $true
    Skills = @("PowerShell", "SQL")
}


Get-SerializedObjectFrom-Simple

#Get-SerializedObjectFrom-Clixml


# 通过键访问值
Write-Output "Name: $( $deserializedObject['Name'] )"
Write-Output "Age: $( $deserializedObject.Age )"  # 点符号也可以访问值
Write-Output "IsActive: $( $deserializedObject['IsActive'] )"
Write-Output "Skills: $( $deserializedObject['Skills'] )"