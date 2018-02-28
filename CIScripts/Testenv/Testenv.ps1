function Read-ControllerConfig {
    Param ([Parameter(Mandatory=$true)] [string] $Path)
    $FileContents = Get-Content -Path $Path -Raw
    $Parsed = ConvertFrom-Yaml $FileContents
    return $Parsed["Controller"]
}

function Read-TestbedsConfig {
    Param ([Parameter(Mandatory=$true)] [string] $Path)
    $FileContents = Get-Content -Path $Path -Raw
    $Parsed = ConvertFrom-Yaml $FileContents
    $Testbeds = $Parsed["Testbeds"]
    # The comma forces return value to always be array
    return ,$Testbeds
}