. $PSScriptRoot\Common\Job.ps1

$OutputRootDirectory = "output"
$Password = $Env:WINCIDEV_PSW | ConvertTo-SecureString -asPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($Env:WINCIDEV_USR, $Password)

if ($Env:COMPONENTS_TO_BUILD -eq "None") {
    $Job = [Job]::new("Copying ready artifacts instead of building")

    $ArtifactsPath = "\\$Env:SHARED_DRIVE_IP\SharedFiles\WindowsCI-Artifacts"
    if (Test-Path Env:READY_ARTIFACTS_PATH) {
        $ArtifactsPath = $Env:READY_ARTIFACTS_PATH
    }

    $DiskName = [Guid]::newGuid().Guid
    New-PSDrive -Name $DiskName -PSProvider "FileSystem" -Root $ArtifactsPath -Credential $Credentials
    Copy-Item ("$DiskName" + ":\*") -Destination $OutputRootDirectory -Recurse -Container

    $Job.Done()
} else {
    & $PSScriptRoot\Build.ps1
}

if (Test-Path Env:UPLOAD_ARTIFACTS) {
    $ArtifactsPath = "\\$Env:SHARED_DRIVE_IP\SharedFiles\WindowsCI-UploadedArtifacts"
    $Subdir = "$Env:JOB_NAME\$Env:BUILD_NUMBER"
    $DiskName = [Guid]::newGuid().Guid
    New-PSDrive -Name $DiskName -PSProvider "FileSystem" -Root $ArtifactsPath -Credential $Credentials
    Push-Location
    Set-Location ($Diskname + ":\")
    New-Item -Name $Subdir -ItemType directory
    Pop-Location
    Copy-Item ($OutputRootDirectory + "\*") -Destination ("$DiskName" + ":\" + $Subdir) -Recurse -Container
}

exit 0
