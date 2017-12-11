# Build builds all Windows Compute components.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Build\BuildFunctions.ps1
. $PSScriptRoot\Build\StagingCI.ps1
. $PSScriptRoot\Build\ProdCI.ps1

$Job = [Job]::new("Build")

$IsTriggeredByGerrit = Test-Path Env:GERRIT_CHANGE_ID
if($IsTriggeredByGerrit) {
    # Build is triggered by Jenkins Gerrit plugin, when someone submits a pull
    # request to review.opencontrail.org.

    $TriggeredProject = Get-GerritProjectName -ProjectString $ENV:GERRIT_PROJECT
    $TriggeredBranch = $ENV:GERRIT_BRANCH
    $Repos = Get-ProductionRepos -TriggeredProject $TriggeredProject `
                                 -TriggeredBranch $TriggeredBranch `
                                 -GerritHost $Env:GERRIT_HOST
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
}

Clone-Repos -Repos $Repos

if($IsTriggeredByGerrit) {
    # Gerrit is different from GitHub, because it operates on patches. We need
    # to merge the downloaded patch with triggered repo.
    
    Merge-GerritPatchset -TriggeredProject $TriggeredProject `
                         -Repos $Repos `
                         -Refspec $Env:GERRIT_REFSPEC
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

Invoke-DockerDriverBuild -DriverSrcPath $Env:DRIVER_SRC_PATH `
                         -SigntoolPath $Env:SIGNTOOL_PATH `
                         -CertPath $Env:CERT_PATH `
                         -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
                         -OutputPath $DockerDriverOutputDir `
                         -LogsPath $LogsDir

Invoke-ExtensionBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
                      -SigntoolPath $Env:SIGNTOOL_PATH `
                      -CertPath $Env:CERT_PATH `
                      -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
                      -ReleaseMode $IsReleaseMode `
                      -OutputPath $vRouterOutputDir `
                      -LogsPath $LogsDir

Invoke-AgentBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH `
                  -SigntoolPath $Env:SIGNTOOL_PATH `
                  -CertPath $Env:CERT_PATH `
                  -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH `
                  -ReleaseMode $IsReleaseMode `
                  -OutputPath $AgentOutputDir `
                  -LogsPath $LogsDir

$Job.Done()
