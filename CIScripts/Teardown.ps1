. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Provision\ProvisionPowerCLI.ps1

$Job = [Job]::new("Teardown")

# TODO: TestVMNames

Teardown-PowerCLI -VMNames $TestbedVMNames

$Job.Done()
