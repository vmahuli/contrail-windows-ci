# Deploy copies required artifacts onto already provisioned machines.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Deploy\Deployment.ps1

$Job = [Job]::new("Deploy")

$Sessions = New-RemoteSessionsToTestbeds
Copy-ArtifactsToTestbeds -Sessions $Sessions -ArtifactsDir $Env:ARTIFACTS_DIR

$Job.Done()

exit 0
