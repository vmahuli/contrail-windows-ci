# Provision spawns testbeds using PowerCLI from prepared templates.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Provision\ProvisionPowerCLI.ps1

$Job = [Job]::new("Provision")

$VMNames = [System.Collections.ArrayList] @()
if($Env:VM_NAMES) {
    $VMNames = $Env:VM_NAMES.Split(",").ForEach({ Get-SanitizedOrGeneratedVMName -VMName $_ -RandomNamePrefix "Test-" })
} else {
    $VMBaseName = Get-SanitizedOrGeneratedVMName -VMName $Env:VM_NAME -RandomNamePrefix "Core-"
    $VMsNeeded = 2
    1..$VMsNeeded | ForEach-Object {
        $VMNames += $VMBaseName + "-" + $_.ToString()
    }
}

$TestbedSessions, $TestbedVMNames = Provision-PowerCLI -VMNames $VMNames -IsReleaseMode $ReleaseModeBuild

$Job.Done()
