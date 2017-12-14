. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

$Creds = Get-VMCreds

$Sessions = New-RemoteSessionsToTestbeds
Run-Tests -Sessions $Sessions

$Job.Done()
