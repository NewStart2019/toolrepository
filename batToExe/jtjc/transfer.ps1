function Get-CommandExists($commandName)
{
    try
    {
        $null = Get-Command -Name $commandName -ErrorAction Stop
        return $true
    }
    catch
    {
        return $false
    }
}

$command = 'ps2exe'
if (Get-CommandExists -commandName $command)
{
    #    ps2exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScriptGUI.exe -iconFile C:\Data\Icon.ico -noConsole -title "MyScript" -version 0.0.0.1
    Invoke-PS2EXE -InputFile deploy_api.ps1 -OutputFile "deploy_api.exe"  -iconFile "../deploy.ico"
}
