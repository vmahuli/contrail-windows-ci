. $PSScriptRoot\Common\Job.ps1

if ($Env:COMPONENTS_TO_BUILD -eq "None") {
    $Job = [Job]::new("Copying ready artifacts instead of building")

    $ArtifactsPath = "\\$Env:SHARED_DRIVE_IP\SharedFiles\WindowsCI-Artifacts"
    if (Test-Path Env:READY_ARTIFACTS_PATH) {
        $ArtifactsPath = $Env:READY_ARTIFACTS_PATH
    }

    $OutputRootDirectory = "output"
    $DiskName = [Guid]::newGuid().Guid
    $Password = $Env:WINCIDEV_PSW | ConvertTo-SecureString -asPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ($Env:WINCIDEV_USR, $Password)
    New-PSDrive -Name $DiskName -PSProvider "FileSystem" -Root $ArtifactsPath -Credential $Credentials
    Copy-Item ("$DiskName" + ":\*") -Destination $OutputRootDirectory -Recurse -Container

    $Job.Done()
} else {
    & $PSScriptRoot\Build.ps1
}

exit 0
