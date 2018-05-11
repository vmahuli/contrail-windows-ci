. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1

function Test-MPLSoGRE {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $VrfStats = Get-VrfStats -Session $Session
    if (($VrfStats.MplsGrePktCount -eq 0) -or ($VrfStats.MplsUdpPktCount -ne 0) -or ($VrfStats.VxlanPktCount -ne 0)) {
        Write-Log "Tunnel usage statistics: Udp = $($VrfStats.MplsUdpPktCount), Gre = $($VrfStats.MplsGrePktCount), Vxlan = $($VrfStats.VxlanPktCount)"
        return $false
    } else {
        return $true
    }
}

function Test-MPLSoUDP {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $VrfStats = Get-VrfStats -Session $Session
    if (($VrfStats.MplsGrePktCount -ne 0) -or ($VrfStats.MplsUdpPktCount -eq 0) -or ($VrfStats.VxlanPktCount -ne 0)) {
        Write-Log "Tunnel usage statistics: Udp = $($VrfStats.MplsUdpPktCount), Gre = $($VrfStats.MplsGrePktCount), Vxlan = $($VrfStats.VxlanPktCount)"
        return $false
    } else {
        return $true
    }
}