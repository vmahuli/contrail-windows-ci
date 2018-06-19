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
$PesterOutReportPath = Join-Path $TestReportDir "report.xml"

Invoke-IntegrationAndFunctionalTests -TestenvConfFile $TestenvConfFile `
    -PesterOutReportPath $PesterOutReportPath `
    -DetailedLogsOutputDir $DetailedLogsDir `
    -AdditionalJUnitsDir $DDriverJUnitLogsOutputDir

$Job.Done()
