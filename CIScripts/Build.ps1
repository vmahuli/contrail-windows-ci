# Build builds all Windows Compute components.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Build\BuildFunctions.ps1

$Repos = @(
    [Repo]::new($Env:DRIVER_REPO_URL, $Env:DRIVER_BRANCH, "src/github.com/codilime/contrail-windows-docker", "master"),
    [Repo]::new($Env:TOOLS_REPO_URL, $Env:TOOLS_BRANCH, "tools/build/", "windows"),
    [Repo]::new($Env:SANDESH_REPO_URL, $Env:SANDESH_BRANCH, "tools/sandesh/", "windows"),
    [Repo]::new($Env:GENERATEDS_REPO_URL, $Env:GENERATEDS_BRANCH, "tools/generateDS/", "windows"),
    [Repo]::new($Env:VROUTER_REPO_URL, $Env:VROUTER_BRANCH, "vrouter/", "windows"),
    [Repo]::new($Env:WINDOWSSTUBS_REPO_URL, $Env:WINDOWSSTUBS_BRANCH, "windows/", "windows"),
    [Repo]::new($Env:CONTROLLER_REPO_URL, $Env:CONTROLLER_BRANCH, "controller/", "windows3.1")
)

$Job = [Job]::new("Build")

Clone-Repos -Repos $Repos
Prepare-BuildEnvironment -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH

$IsReleaseMode = [bool]::Parse($Env:BUILD_IN_RELEASE_MODE)

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
