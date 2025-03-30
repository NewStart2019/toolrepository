# 测试是否是管理员
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-EnvironmentVariable
{
    #.Synopsis
    # Set an environment variable at the highest scope possible
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [String]$Name,

        [Parameter(Position = 1)]
        [String]$Value,

        [System.EnvironmentVariableTarget]
        $Scope = "Machine",

        [Switch]$FailFast
    )
    Write-Information "Set-EnvironmentVariable $Name $Value -Scope $Machine" -Tags "Trace", "Enter"

    Set-Content "ENV:$Name" $Value
    $Success = $False
    do
    {
        try
        {
            [System.Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
            Write-Verbose "Set $Scope environment variable $Name = $Value"
            $Success = $True
        }
        catch [System.Security.SecurityException]
        {
            if ($FailFast)
            {
                $PSCmdlet.ThrowTerminatingError((New-Object System.Management.Automation.ErrorRecord (
                New-Object AccessViolationException "Can't set environment variable in $Scope scope"
                ), "FailFast:$Scope", "PermissionDenied", $Scope))
            }
            else
            {
                Write-Warning "Cannot set environment variables in the $Scope scope"
            }
            $Scope = [int]$Scope - 1
        }
    } while (!$Success -and $Scope -gt "Process")

    Write-Information "Set-EnvironmentVariable $Name $Value -Scope $Machine" -Tags "Trace", "Exit"
}

# 环境变量中添加新的路径，并确保路径唯一且格式化正确
# 参数：
#  Name: "Path"（修改系统或用户的 PATH 环境变量）。
#  Append: 在现有路径后追加的新路径
#  Prepend: 现有路径前追加的新路径
#  Scope:  User：仅对当前用户生效。 Machine：对整个系统生效。Process：仅对当前进程生效。
#  Separator: 路径分隔符，默认为系统路径分隔符
# 示例：
#  Add-Path -Name "Path" -Prepend "C:\Custom\Scripts", "C:\Custom\Bin" -Append "C:\Extra\Tools" -Scope "Machine"
function Add-Path
{
    #.Synopsis
    #  Add a folder to a path environment variable
    #.Description
    #  Gets the existing content of the path variable, splits it with the PathSeparator,
    #  adds the specified paths, and then joins them and re-sets the EnvironmentVariable
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $True)]
        [String]$Name,

        [Parameter(Position = 1)]
        [String[]]$Append = @(),

        [String[]]$Prepend = @(),

        [System.EnvironmentVariableTarget]$Scope = "User",

        [Char]$Separator = [System.IO.Path]::PathSeparator
    )

    # 如果不是管理员权限，则重新以管理员权限启动脚本
    if (-not (Test-Admin)) {
        Write-Host "当前未以管理员权限运行，正在尝试以管理员权限重新启动脚本..." -ForegroundColor Yellow

        # 获取当前脚本的完整路径
        $scriptPath = $MyInvocation.MyCommand.Path

        # 获取传递给脚本的参数
        $scriptArgs = $MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }
        $scriptArgs += $MyInvocation.UnboundArguments | ForEach-Object { "`"$_`"" }

        # 使用 Start-Process 以管理员权限重新启动脚本，并传递参数
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $scriptArgs"
        # 退出当前实例
        exit 0
    }

    Write-Information "Add-Path $Name $Append | $Prepend" -Tags "Trace", "Enter"

    # Make the new thing as an array so we don't get duplicates
    $Path = @($Prepend -split "$Separator" | %{ $_.TrimEnd("\/") } | ?{ $_ })
    Write-Information ([Environment]::GetEnvironmentVariable($Name, $Scope)) -Tags "Debug", "Before", "Env:${Scope}:${Name}"
    $Path += $OldPath = @([Environment]::GetEnvironmentVariable($Name, $Scope) -split "$Separator" | %{ $_.TrimEnd("\/") }| ?{ $_ })
    $Path += @($Append -split "$Separator" | %{ $_.TrimEnd("\/") }| ?{ $_ })

    # Dedup path
    # If the path actually exists, use the actual case of the folder
    $Path = $( foreach ($Folder in $Path)
    {
        if (Test-Path $Folder)
        {
            Get-Item ($Folder -replace '(?<!:)(\\|/)', '*$1') | Where FullName -ieq $Folder | % FullName
        }
        else
        {
            $Folder
        }
    } ) | Select -Unique

    # Turn them back into strings
    $Path = $Path -join "$Separator"
    $OldPath = $OldPath -join "$Separator"

    # Path environment variables are kind-of a pain:
    # The current value in the process scope is a (potentially modified) combination of machine and user, with changes
    # We need to fix the CURRENT path instead of just setting it
    $OldEnvPath = @($( Get-Content "ENV:$Name" ) -split "$Separator" | %{ $_.TrimEnd("\/") }) -join "$Separator"
    if ("$OldPath".Trim().Length -gt 0)
    {
        Write-Verbose "Old $Name Path: $OldEnvPath"
        $OldEnvPath = $OldEnvPath -Replace ([regex]::escape($OldPath)), $Path
        Write-Verbose "New $Name Path: $OldEnvPath"
    }
    else
    {
        if ($Append)
        {
            $OldEnvPath = $OldEnvPath + "$Separator" + $Path
        }
        else
        {
            $OldEnvPath = $Path + "$Separator" + $OldEnvPath
        }
    }

    Write-Information $Path -Tags "Debug", "After", "Env:${Scope}:${Name}"
    Set-EnvironmentVariable $Name $( $Path -join "$Separator" ) -Scope $Scope -FailFast
    if ($?)
    {
        # Set the path back to the normalized value
        Set-Content "ENV:$Name" $OldEnvPath
    }
    Write-Information -Tags "Trace","Exit"
}

# 用于处理路径字符串（如 $Env:Path），并返回去重后的唯一路径列表
# Select-UniquePath -Path $Env:Path
function Select-UniquePath
{
    # 启用高级函数特性，例如支持 -Verbose 和 -Debug 参数
    [CmdletBinding()]
    # 定义了两个参数：$Delimiter 和 $Path
    param(
    # If non-full, split path by the delimiter. Defaults to '[IO.Path]::PathSeparator' so you can use this on $Env:Path
        [Parameter(Mandatory = $False)]
        [AllowNull()]
        [string]$Delimiter = [IO.Path]::PathSeparator,

    # Paths to folders 支持从剩余参数中获取值（ValueFromRemainingArguments）
        [Parameter(Position = 1, Mandatory = $true, ValueFromRemainingArguments = $true)]
        [AllowEmptyCollection()]    # 允许空集合
        [AllowEmptyString()]        # 允许空字符串
        [string[]]$Path
    )
    begin {
        #  记录函数进入的日志信息
        Write-Information "Select-UniquePath $Delimiter $Path" -Tags "Trace", "Enter"
        [string[]]$Output = @()
    }
    process {
        $Output += $(
        # 除路径末尾的斜杠（/ 或 \）；拆分路径字符串使用;
        $oldPaths = $Path -split $Delimiter -replace '[\\\/]$' -gt ""
        # Injecting wildcards causes Windows to figure out the actual case of the path
        $folders = $oldPaths -replace '(?<!(?::|\\\\))(\\|/)', '*$1' -replace '$', '*'
        #  获取文件夹的绝对路径
        $newPaths = Get-Item $folders -Force | Convert-Path
        # 确保只保留原始路径中存在的路径
        $newPaths | Where-Object { $_ -iin $oldPaths }
        )
    }
    end {
        if ($Delimiter)
        {
            [System.Linq.Enumerable]::Distinct($Output) -join $Delimiter
        }
        else
        {
            [System.Linq.Enumerable]::Distinct($Output)
        }
        Write-Information "Select-UniquePath $Delimiter $Path" -Tags "Trace", "Exit"
    }
}

function Get-SpecialFolder
{
    #.Synopsis
    #   Gets the current value for a well known special folder
    [CmdletBinding()]
    param(
    # The name of the Path you want to fetch (supports wildcards).
    #  From the list: AdminTools, ApplicationData, CDBurning, CommonAdminTools, CommonApplicationData, CommonDesktopDirectory, CommonDocuments, CommonMusic, CommonOemLinks, CommonPictures, CommonProgramFiles, CommonProgramFilesX86, CommonPrograms, CommonStartMenu, CommonStartup, CommonTemplates, CommonVideos, Cookies, Desktop, DesktopDirectory, Favorites, Fonts, History, InternetCache, LocalApplicationData, LocalizedResources, MyComputer, MyDocuments, MyMusic, MyPictures, MyVideos, NetworkShortcuts, Personal, PrinterShortcuts, ProgramFiles, ProgramFilesX86, Programs, PSHome, Recent, Resources, SendTo, StartMenu, Startup, System, SystemX86, Templates, UserProfile, Windows
        [ValidateScript({
            $Name = $_
            if (!$Script:SpecialFolders.Count -gt 0)
            {
                LoadSpecialFolders
            }
            if ($Script:SpecialFolders.Keys -like $Name)
            {
                return $true
            }
            else
            {
                throw "Cannot convert Path, with value: `"$Name`", to type `"System.Environment+SpecialFolder`": Error: `"The identifier name $Name is not one of $( $Script:SpecialFolders.Keys -join ', ' )"
            }
        })]
        [String]$Path = "*",

    # If not set, returns a hashtable of folder names to paths
        [Switch]$Value
    )
    Write-Information "Get-SpecialFolder $Path" -Tags "Trace", "Enter"

    $Names = $Script:SpecialFolders.Keys -like $Path
    if (!$Value)
    {
        $return = @{ }
    }

    foreach ($name in $Names)
    {
        $result = $(
        $id = $Script:SpecialFolders.$name
        if ($Id -is [string])
        {
            $Id
        }
        else
        {
            ($Script:SpecialFolders.$name = [Environment]::GetFolderPath([int]$Id))
        }
        )

        if ($result)
        {
            if ($Value)
            {
                Write-Output $result
            }
            else
            {
                $return.$name = $result
            }
        }
    }
    if (!$Value)
    {
        Write-Output $return
    }
    Write-Information "Get-SpecialFolder $Path" -Tags "Trace", "Exit"
}

function Trace-Message
{
    <#
        .Synopsis
            Wrap Verbose, Debug, or Warning output with command profiling trace showing script line and time elapsed
        .Description

            Creates a stopwatch that tracks the time elapsed while a script runs, and adds caller position and time to the output
        .Example
            foreach($i in 1..20) { sleep -m 50; Trace-Message "Progress $i" }

            Demonstrates the simplest use of Trace-Message to add a duration timestamp to the message.
        .Example
            function Test-Trace {
                [CmdletBinding()]param()
                foreach($i in 1..20) {
                    $i
                    Trace-Message {
                        sleep -m 50; # just to be sure you can tell this is slow
                        $ps = (Get-Process | sort PM -Desc | select -first 2)
                        "Memory hog {1} using {0:N2}GB more than next process" -f (($ps[0].WS -$ps[1].WS) / 1GB), $ps[0].Name
                    } @PSBoundParameters
                }
            }

            Demonstrates how using a scriptblock can avoid calculation of complicated output when -Verbose is not set.  In this example, "Test-Trace" by itself will output 1-20 in under 20 miliseconds, but with verbose output, it can take over 1.25 seconds
    #>
    [CmdletBinding(DefaultParameterSetName = "VerboseOutput")]
    param(
    # The message to write, or a scriptblock, which, when evaluated, will output a message to write
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "VerboseOutput", Position = 0)]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "WarningOutput", Position = 0)]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "DebugOutput", Position = 0)]
        [PSObject]$Message,

    # When set, output to the warning stream instead of verbose
        [Parameter(Mandatory = $true, ParameterSetName = "WarningOutput")]
        [Alias("AsWarning")]
        [switch]$WarningOutput,

    # When set, output to the debug stream instead of verbose
        [Parameter(Mandatory = $true, ParameterSetName = "DebugOutput")]
        [Alias("AsDebug")]
        [switch]$DebugOutput,

    # Reset the timer to time the next block from zero
        [switch]$ResetTimer,

    # Clear out the timer completely after this output
    # When you explicitly pass a Stopwatch, you can pass this flag (only once) to stop and remove it
        [switch]$KillTimer,

    # A custom string overrides the automatic formatting which changes depending on how long the duration is
        [string]$ElapsedFormat,

    # If set, show the time since last Trace-Message
        [switch]$ShowStepTime,

    # Supports passing in an existing Stopwatch (running or not)
        [Diagnostics.Stopwatch]$Stopwatch
    )
    begin {
        if ($Stopwatch)
        {
            ${Script:Trace Message Timer} = $Stopwatch
            ${Script:Trace Message Timer}.Start()
        }
        if (-not ${Trace Message Timer})
        {
            ${global:Trace Message Timer} = New-Object System.Diagnostics.Stopwatch
            ${global:Trace Message Timer}.Start()

            # When no timer is provided...
            # Assume the timer is for "run" and
            # Clean up automatically at the next prompt
            $PreTraceTimerPrompt = $function:prompt

            $function:prompt = {
                if (${global: Trace Message Timer })
                {
                    ${global: Trace Message Timer}.Stop()
                    Remove-Variable "Trace Message Timer" -Scope global -ErrorAction SilentlyContinue
                }
                & $PreTraceTimerPrompt
                ${function: global: prompt} = $PreTraceTimerPrompt
            }.GetNewClosure()
        }

        $Script:LastElapsed = $Script:Elapsed
        $Script:Elapsed = ${Trace Message Timer }.Elapsed.Duration()

        if ($ResetTimer -or -not ${Trace Message Timer}.IsRunning)
        {
            ${Trace Message Timer }.Restart()
        }

        # Note this requires a host with RawUi
        $w = $Host.UI.RawUi.BufferSize.Width
    }

    process {
        if (($WarningOutput -and $WarningPreference -eq "SilentlyContinue") -or
                ($DebugOutput -and $DebugPreference -eq "SilentlyContinue") -or
                ($PSCmdlet.ParameterSetName -eq "VerboseOutput" -and $VerbosePreference -eq "SilentlyContinue"))
        {
            return
        }

        [string]$Message = if ($Message -is [scriptblock])
        {
            ($Message.InvokeReturnAsIs(@()) | Out-String -Stream) -join "`n"
        }
        else
        {
            "$Message"
        }

        $Message = $Message.Trim()

        $Location = if ($MyInvocation.ScriptName)
        {
            $Name = Split-Path $MyInvocation.ScriptName -Leaf
            "${Name }:" + "$( $MyInvocation.ScriptLineNumber )".PadRight(4)
        }
        else
        {
            ""
        }

        $Tail = $( if ($ElapsedFormat)
        {
            "{0:$ElapsedFormat}" -f $Elapsed
        }
        elseif($Elapsed.TotalHours -ge 1.0)
        {
            "{0:h\:mm\:ss\.ffff}" -f $Elapsed
        }
        elseif($Elapsed.TotaMinutes -ge 1.0)
        {
            "{0:mm\m\ ss\.ffff\s}" -f $Elapsed
        }
        else
        {
            "{0:ss\.ffff\s}" -f $Elapsed
        } ).PadLeft(12)

        $Tail = $Location + $Tail

        # "WARNING:  ".Length = 10
        $Length = ($Message.Length + 10 + $Tail.Length)
        # Twenty-five is a minimum 15 character message...
        $PaddedLength = if ($Length -gt $w -and $w -gt (25 + $Tail.Length))
        {
            [string[]]$words = -split $message
            $short = 10 # "VERBOSE:  ".Length
            $count = 0  # Word count so far
            $lines = 0
            do
            {
                do
                {
                    $short += 1 + $words[$count++].Length
                } while (($words.Count -gt $count) -and ($short + $words[$count].Length) -lt $w)
                $Lines++
                if (($Message.Length + $Tail.Length) -gt ($w * $lines))
                {
                    $short = 0
                }
            } while ($short -eq 0)
            $Message.Length + ($w - $short) - $Tail.Length
        }
        else
        {
            $w - 10 - $Tail.Length
        }

        $Message = "$Message ".PadRight($PaddedLength, "$( [char]8331 )") + $Tail

        if ($WarningOutput)
        {
            Write-Warning $Message
        }
        elseif($DebugOutput)
        {
            Write-Debug $Message
        }
        else
        {
            Write-Verbose $Message
        }
    }

    end {
        if ($KillTimer -and ${Trace Message Timer })
        {
            ${Trace Message Timer }.Stop()
            Remove-Variable "Trace Message Timer" -Scope Script -ErrorAction Ignore
            Remove-Variable "Trace Message Timer" -Scope Global -ErrorAction Ignore
        }
    }
}

Add-Path -Name "Path" -Append "C:\Extra\Tools" -Scope "Machine"
Select-UniquePath -Path $Env:Path

Pause