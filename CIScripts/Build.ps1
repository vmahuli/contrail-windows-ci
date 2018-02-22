# Build builds selected Windows Compute components.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\Components.ps1
. $PSScriptRoot\Build\BuildFunctions.ps1


$Job = [Job]::new("Build")

$IsReleaseMode = [bool]::Parse($Env:BUILD_IN_RELEASE_MODE)
Initialize-BuildEnvironment -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH

$DockerDriverOutputDir = "output/docker_driver"
$vRouterOutputDir = "output/vrouter"
$vtestOutputDir = "output/vtest"
$AgentOutputDir = "output/agent"
$DllsOutputDir = "output/dlls"
$LogsDir = "logs"

$Directories = @(
    $DockerDriverOutputDir,
    $vRouterOutputDir,
    $vtestOutputDir,
    $AgentOutputDir,
    $DllsOutputDir,
    $LogsDir
)

foreach ($Directory in $Directories) {
    if (-not (Test-Path $Directory)) {
        New-Item -ItemType directory -Path $Directory | Out-Null
    }
}

$ComponentsToBuild = Get-ComponentsToBuild


if ("DockerDriver" -In $ComponentsToBuild) {
    Invoke-DockerDriverBuild -DriverSrcPath $Env:DRIVER_SRC_PATH `
        -SigntoolPath $Env:SIGNTOOL_PATH `
        -CertPath $Env:CERT_PATH `
        -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
        -OutputPath $DockerDriverOutputDir `
        -LogsPath $LogsDir
}

if ("Extension" -In $ComponentsToBuild) {
    Invoke-ExtensionBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
        -SigntoolPath $Env:SIGNTOOL_PATH `
        -CertPath $Env:CERT_PATH `
        -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
        -ReleaseMode $IsReleaseMode `
        -OutputPath $vRouterOutputDir `
        -LogsPath $LogsDir

    Copy-VtestScenarios -OutputPath $vtestOutputDir
}

if ("Agent" -In $ComponentsToBuild) {
    Invoke-AgentBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
        -SigntoolPath $Env:SIGNTOOL_PATH `
        -CertPath $Env:CERT_PATH `
        -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
        -ReleaseMode $IsReleaseMode `
        -OutputPath $AgentOutputDir `
        -LogsPath $LogsDir
}

if ("AgentTests" -In $ComponentsToBuild) {
    Invoke-AgentTestsBuild -LogsPath $LogsDir `
        -ReleaseMode $IsReleaseMode
}

if (-not $isReleaseMode) {
    Copy-DebugDlls -OutputPath $DllsOutputDir
}

$Job.Done()

exit 0
