function GetName{
    Write-Host "Manoj" -ForegroundColor Green
}

$m = New-Module -ScriptBlock {
    function Hello($Name)
    {
        return "Hello, $Name"
    }
    function Goodbye($Name)
    {
        return "Goodbye, $Name"
    }
} -AsCustomObject

$m.Goodbye("Jane")
$m.Hello("Manoj")
