. $PSScriptRoot\InitializeCIScript.ps1

# Sourcing VM management functions
. $PSScriptRoot\VMUtils.ps1

# Setting all variables needed for New-TestbedVMs from Environment
. $PSScriptRoot\SetCommonVariablesForNewVMsFromEnv.ps1

$VMNames = $Env:VM_NAMES.Split(",")
for ($i = 0; $i -lt $VMNames.Count; $i++) {
    $VMNames[$i] = Get-SanitizedOrGeneratedVMName -VMName $VMNames[$i] -RandomNamePrefix "Test-"
}

Write-Host "Starting Testbeds:"
$VMNames.ForEach({ Write-Host $_ })

if ($ReleaseModeBuild) {
    $Sessions = New-TestbedVMs -VMNames $VMNames -InstallArtifacts $true -VIServerAccessData $VIServerAccessData `
        -VMCreationSettings $VMCreationSettings -VMCredentials $VMCredentials -ArtifactsDir $ArtifactsDir `
        -DumpFilesLocation $DumpFilesLocation -DumpFilesBaseName $DumpFilesBaseName -MaxWaitVMMinutes $MaxWaitVMMinutes
} else {
    $Sessions = New-TestbedVMs -VMNames $VMNames -InstallArtifacts $true -VIServerAccessData $VIServerAccessData `
        -VMCreationSettings $VMCreationSettings -VMCredentials $VMCredentials -ArtifactsDir $ArtifactsDir `
        -DumpFilesLocation $DumpFilesLocation -DumpFilesBaseName $DumpFilesBaseName -MaxWaitVMMinutes $MaxWaitVMMinutes `
        -CopyMsvcDebugDlls -MsvcDebugDllsDir $Env:MSVC_DEBUG_DLLS_DIR
}

Write-Host "Started Testbeds:"
$Sessions.ForEach({ Write-Host $_.ComputerName })
