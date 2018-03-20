. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

$TestenvConfFile = "${Env:WORKSPACE}\${Env:TESTENV_CONF_FILE}"
$Sessions = New-RemoteSessionsToTestbeds -TestenvConfFile $TestenvConfFile

Invoke-IntegrationAndFunctionalTests -Sessions $Sessions `
    -TestenvConfFile $TestenvConfFile `
    -TestReportOutputDirectory $Env:WORKSPACE

$Job.Done()
