. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

$Sessions = New-RemoteSessionsToTestbeds
Invoke-IntegrationAndFunctionalTests -Sessions $Sessions `
    -TestConfigurationFile $PSScriptRoot\Test\$Env:TEST_CONFIGURATION_FILE `
    -TestReportOutputDirectory $Env:WORKSPACE

$Job.Done()
