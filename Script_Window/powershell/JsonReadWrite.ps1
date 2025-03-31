# 定义模块脚本
function Read-StudentData {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    if (-Not (Test-Path $FilePath)) {
        throw "文件不存在: $FilePath"
    }
    return Get-Content -Path $FilePath -Raw | ConvertFrom-Json
}

function Write-StudentData {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        $Data
    )
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
}

function Add-Student {
    param (
        [Parameter(Mandatory = $true)]
        $ClassData,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [int]$Age,

        [Parameter(Mandatory = $true)]
        [string[]]$Subjects,

        [Parameter(Mandatory = $true)]
        [hashtable]$Grades
    )

    # 创建新学生对象
    $newStudent = @{
        Name     = $Name
        Age      = $Age
        Subjects = $Subjects
        Grades   = $Grades
    }

    # 添加到班级数据
    $ClassData.Students += $newStudent
}

function Find-Student {
    param (
        [Parameter(Mandatory = $true)]
        $ClassData,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return $ClassData.Students | Where-Object { $_.Name -eq $Name }
}

# 定义 JSON 文件路径
$jsonFile = ".\students.json"

# 读取现有数据
$studentData = Read-StudentData -FilePath $jsonFile

# 查询学生信息
$student = Find-Student -ClassData $studentData -Name "Alice"
Write-Output "查询结果:"
$student | Format-List

# 添加新学生
Add-Student -ClassData $studentData `
    -Name "Charlie" `
    -Age 16 `
    -Subjects @("Math", "Biology") `
    -Grades @{ Math = 90; Biology = 85 }

# 写回更新后的数据到 JSON 文件
Write-StudentData -FilePath $jsonFile -Data $studentData

$studentData
Write-Output "更新完成！新数据已保存到文件。"