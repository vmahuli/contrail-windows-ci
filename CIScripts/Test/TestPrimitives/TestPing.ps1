. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1

function Test-Ping {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $SrcContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerName,
        [Parameter(Mandatory=$true)] [String] $DstContainerIP
    )

    Write-Log "Container $SrcContainerName is pinging $DstContainerName..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:SrcContainerName powershell "ping $Using:DstContainerIP; `$LASTEXITCODE;"
    }
    $Output = $Res[0..($Res.length - 2)]
    Write-Log "Ping output: $Output"
    return $Res[-1]
}
