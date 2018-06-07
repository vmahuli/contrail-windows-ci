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

$DetailedLogsDir = Join-Path $TestReportDir "detailed_logs"
$DDriverJUnitLogsOutputDir = Join-Path $TestReportDir "ddriver_junit_test_logs"
$NUnitsDir = Join-Path $TestReportDir "raw_NUnit"

Invoke-IntegrationAndFunctionalTests -TestenvConfFile $TestenvConfFile `
    -PesterLogsOutputDir $NUnitsDir `
    -DetailedLogsOutputDir $DetailedLogsDir `
    -AdditionalJUnitsDir $DDriverJUnitLogsOutputDir

$Job.Done()
