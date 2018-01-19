# Spawn-Testbed job consolidates Provision and Deploy. It's a utility job to
# ease the development process.
# This will likely be replaced with once whole test env blocks are implemented
# fully.

. $PSScriptRoot\Provision.ps1
. $PSScriptRoot\Deploy.ps1

exit 0
