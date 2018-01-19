. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Provision\ProvisionPowerCLI.ps1

$Job = [Job]::new("Teardown")

Teardown-PowerCLI -VMNames (Get-TestbedHostnamesFromEnv)

$Job.Done()

exit 0
