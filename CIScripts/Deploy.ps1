# Deploy installs required artifacts onto already provisioned machines.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Deploy\Deployment.ps1

$Job = [Job]::new("Deploy")

$ArtifactsDir = $Env:ARTIFACTS_DIR

$Sessions = New-RemoteSessionsToTestbeds
Deploy-Testbeds -Sessions $Sessions -ArtifactsDir $Env:ARTIFACTS_DIR

$Job.Done()
