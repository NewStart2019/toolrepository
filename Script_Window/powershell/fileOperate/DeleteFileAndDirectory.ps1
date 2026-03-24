function Remove-File-By-Age
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$directoryPath, # 扫描的目录
        [string]$daysOldToDelete = 30 # 删除修改时间大于最近n天的文件
    )

    # 设置参数
    $directoryPath = 'C:\path\to\your\directory' # 替换为你的目录路径
    $daysOldToDelete = 30                       # 替换为你希望删除的文件的最小年龄（天）

    # 获取当前日期
    $now = Get-Date

    # 获取指定目录下所有的文件
    $files = Get-ChildItem $directoryPath -File

    # 遍历每个文件，检查其最后修改日期
    foreach ($file in $files)
    {
        # 计算文件的年龄（以天为单位）
        $fileAgeInDays = New-TimeSpan -Start $file.LastWriteTime -End $now

        # 如果文件年龄大于指定的天数，则删除该文件
        if ($fileAgeInDays.Days -gt $daysOldToDelete)
        {
            Write-Host "Deleting file: $( $file.FullName )"
            Remove-Item $file.FullName -Force
        }
    }
}


function Remove-EmptyFolders
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Get all subdirectories
    $subDirectories = Get-ChildItem -Directory $Path

    foreach ($subDirectory in $subDirectories)
    {
        # Recursively call this function on each subdirectory
        Remove-EmptyFolders -Path $subDirectory.FullName

        # Check if the directory is now empty
        if ((Get-ChildItem -Path $subDirectory.FullName -Force).Count -eq 0)
        {
            # Remove the empty directory
            Remove-Item -Path $subDirectory.FullName -Force
        }
    }
}

function Add-FileSuffix
{
    <#
    .SYNOPSIS
        给指定目录下的文件批量添加统一后缀。

    .DESCRIPTION
        遍历指定目录（可选递归），给所有文件添加指定的后缀。
        支持“强制模式”，即使文件已包含该后缀也会再次添加。
        默认情况下，如果文件已包含该后缀，则会跳过以避免重复（如 .txt.txt）。

    .PARAMETER Path
        目标目录路径。默认为当前目录。

    .PARAMETER Suffix
        要添加的后缀字符串（例如 ".bak", "_old", ".archive"）。
        建议以点号 "." 或下划线 "_" 开头。

    .PARAMETER Recurse
        [开关] 是否递归搜索子目录。

    .PARAMETER Force
        [开关] 强制添加。
        如果不加此参数：检测到文件名末尾已存在该后缀时，将跳过该文件。
        如果加此参数：无论文件名是否已包含后缀，都会强行添加（可能导致 .txt.txt）。

    .PARAMETER WhatIf
        [开关] 显示如果运行命令会发生什么，但不实际执行重命名（干跑模式）。

    .EXAMPLE
        # 给当前目录下所有文件添加 .bak 后缀 (不递归，自动跳过已有 .bak 的文件)
        Add-FileSuffix -Suffix ".bak"

    .EXAMPLE
        # 递归给 D:\Logs 下所有文件添加 _archived 后缀，即使已有也强制添加
        Add-FileSuffix -Path "D:\Logs" -Suffix "_archived" -Recurse -Force

    .EXAMPLE
        # 预览模式：看看会给哪些文件改名，但不实际执行
        Add-FileSuffix -Suffix ".old" -Recurse -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Path = ".",

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Suffix,

        [switch]$Recurse,
        [switch]$Force
    )

    # 1. 准备获取文件的参数
    $getChildrenParams = @{
        Path = $Path
        File = $true
    }
    if ($Recurse)
    {
        $getChildrenParams['Recurse'] = $true
    }

    if (-not (Test-Path -Path $Path))
    {
        Write-Error "路径不存在: $Path"
        return
    }

    $files = Get-ChildItem @getChildrenParams

    if ($null -eq $files -or $files.Count -eq 0)
    {
        Write-Host "在路径 '$Path' 下未找到任何文件。" -ForegroundColor Yellow
        return
    }

    $countProcessed = 0
    $countSkipped = 0

    foreach ($file in $files)
    {
        $originalName = $file.Name
        $newName = "$originalName$Suffix"

        $shouldSkip = $false

        # --- 核心逻辑判断开始 ---
        if (-not $Force)
        {
            # 逻辑：判断文件是否【已经存在任何后缀】
            # 定义：如果文件名中包含点号 '.'，则认为它已有后缀。
            # 注意：这会跳过像 ".gitignore" 这样的文件吗？
            # 通常 ".gitignore" 被视为无扩展名的特殊文件，但在字符串层面它包含点。
            # 为了符合大多数用户直觉（给 README 加后缀，不给 file.txt 加）：
            # 我们判断：文件名中是否包含 '.'

            # 特殊情况处理：如果文件以 '.' 开头且没有其他 '.' (如 .bashrc)，通常视为无扩展名文件。
            # 但为了简单稳健，这里采用通用标准：只要名字里有 '.' 就算有后缀。
            # 如果您希望 .bashrc 也被加上后缀，目前的逻辑会跳过它。
            # 如果需要更精确（排除隐藏文件点），可以使用下面的逻辑：

            $hasExtension = $originalName.Contains('.')

            # (可选优化) 如果想排除纯隐藏文件 (如 .gitignore) 被视为"有后缀"，可以用下面这行替换上面那行：
            # $hasExtension = ($originalName.LastIndexOf('.') -gt 0)

            if ($hasExtension)
            {
                $shouldSkip = $true
                Write-Verbose "跳过 (已存在后缀): $originalName"
            }
        }
        # --- 核心逻辑判断结束 ---

        if ($shouldSkip)
        {
            $countSkipped++
            continue
        }

        # 执行重命名
        if ( $PSCmdlet.ShouldProcess($file.FullName, "Rename to $newName"))
        {
            try
            {
                Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                Write-Host "已添加后缀: $originalName -> $newName" -ForegroundColor Green
                $countProcessed++
            }
            catch
            {
                Write-Error "无法重命名文件 '$( $file.FullName )': $_"
            }
        }
    }

    Write-Host "`n操作完成:" -ForegroundColor Cyan
    Write-Host "  - 成功添加: $countProcessed 个文件 (原无后缀)"
    Write-Host "  - 自动跳过: $countSkipped 个文件 (原已有后缀)"
    if (-not $Force)
    {
        Write-Host "  (提示: 使用 -Force 可强制给已有后缀的文件再次添加)"
    }
}