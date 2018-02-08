# Test-Integration job consolidates Provision, Deploy, Test and Teardown into
# one job. It will be removed in the future, but for now we support it.


$ShouldTeardown = $false
if (-not $Env:TESTBED_HOSTNAMES) {
    . $PSScriptRoot\Provision.ps1
    . $PSScriptRoot\Deploy.ps1
    $ShouldTeardown = $true
}

. $PSScriptRoot\Test.ps1

if ($ShouldTeardown) {
    . $PSScriptRoot\Teardown.ps1
}
