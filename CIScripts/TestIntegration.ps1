# Test-Integration job consolidates Provision, Deploy, Test and Teardown into
# one job. It will be removed in the future, but for now we support it.

. $PSScriptRoot\Provision.ps1
. $PSScriptRoot\Deploy.ps1
. $PSScriptRoot\Test.ps1
. $PSScriptRoot\Teardown.ps1
