# Build builds all Windows Compute components.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Build\BuildFunctions.ps1
. $PSScriptRoot\Build\StagingCI.ps1
. $PSScriptRoot\Build\Zuul.ps1

$Job = [Job]::new("Build")

$IsTriggeredByZuul = Test-Path Env:ZUUL_PROJECT
if($IsTriggeredByZuul) {
    # Build is triggered by Zuul, when someone submits a pull
    # request to review.opencontrail.org.

    Clone-ZuulRepos -GerritUrl $Env:GERRIT_URL `
                    -ZuulProject $Env:ZUUL_PROJECT `
                    -ZuulRef $Env:ZUUL_REF `
                    -ZuulUrl $Env:ZUUL_URL `
                    -ZuulBranch $Env:ZUUL_BRANCH

    Clone-NonZuulRepos -DriverSrcPath $Env:DRIVER_SRC_PATH
} else {
    # Build is triggered by Jenkins GitHub plugin, when someone submits a pull
    # request to select github.com/codilime/* repos.

    $Repos = Get-StagingRepos -DriverBranch $ENV:DRIVER_BRANCH `
                              -WindowsstubsBranch $ENV:WINDOWSSTUBS_BRANCH `
                              -ToolsBranch $Env:TOOLS_BRANCH `
                              -SandeshBranch $Env:SANDESH_BRANCH `
                              -GenerateDSBranch $Env:GENERATEDS_BRANCH `
                              -VRouterBranch $Env:VROUTER_BRANCH `
                              -ControllerBranch $Env:CONTROLLER_BRANCH

    Clone-Repos -Repos $Repos
}

$IsReleaseMode = [bool]::Parse($Env:BUILD_IN_RELEASE_MODE)
Prepare-BuildEnvironment -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH

$DockerDriverOutputDir = "output/docker_driver"
$vRouterOutputDir = "output/vrouter"
$AgentOutputDir = "output/agent"
$LogsDir = "logs"

New-Item -ItemType directory -Path $DockerDriverOutputDir
New-Item -ItemType directory -Path $vRouterOutputDir
New-Item -ItemType directory -Path $AgentOutputDir
New-Item -ItemType directory -Path $LogsDir

$ComponentsToBuild = if (Test-Path Env:COMPONENTS_TO_BUILD) {
    $Env:COMPONENTS_TO_BUILD.Split(",")
} else {
    @("DockerDriver", "Extension", "Agent")
}

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

$Job.Done()

exit 0
