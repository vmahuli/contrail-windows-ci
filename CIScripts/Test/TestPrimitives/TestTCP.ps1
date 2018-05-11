. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1

function Test-TCP {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $SrcContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerIP
    )

    Write-Log "Container $SrcContainerName is sending HTTP request to $DstContainerName..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:SrcContainerName powershell "Invoke-WebRequest -Uri http://${Using:DstContainerIP}:8080/ -UseBasicParsing -ErrorAction Continue; `$LASTEXITCODE"
    }
    $Output = $Res[0..($Res.length - 2)]
    Write-Log "Web request output: $Output"
    return $Res[-1]
}
