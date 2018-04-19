Param(
    [Parameter(Mandatory = $true)] [string] $TestReportDir,
    [Parameter(Mandatory = $true)] [string] $TestenvConfFile
)

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

if (-not (Test-Path $TestReportDir)) {
    New-Item -ItemType Directory -Path $TestReportDir | Out-Null
}

Invoke-IntegrationAndFunctionalTests -TestenvConfFile $TestenvConfFile `
    -TestReportOutputDirectory $TestReportDir

$Job.Done()
