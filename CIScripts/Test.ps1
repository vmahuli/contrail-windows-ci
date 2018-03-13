. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

$TestenvConfFile = "$PSScriptRoot\..\$Env:TESTENV_CONF_FILE"
$Sessions = New-RemoteSessionsToTestbeds -TestenvConfFile $TestenvConfFile

Invoke-IntegrationAndFunctionalTests -Sessions $Sessions `
    -TestenvConfFile $TestenvConfFile `
    -TestConfigurationFile "$PSScriptRoot\Test\$Env:TEST_CONFIGURATION_FILE"


$Job.Done()
