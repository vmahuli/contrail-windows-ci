Param(
    [Parameter(Mandatory = $true)] [string] $RawNUnitPath,
    [Parameter(Mandatory = $true)] [string] $OutputDir
)

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Report\GenerateTestReport.ps1

if ((Test-Path $RawNUnitPath) -and (Get-ChildItem $RawNUnitPath)) {
    Convert-TestReportsToHtml -RawNUnitPath $RawNUnitPath -OutputDir $OutputDir
} else {
    Write-Warning "No report generated, directory $RawNUnitPath doesn't exist or is empty"
}
