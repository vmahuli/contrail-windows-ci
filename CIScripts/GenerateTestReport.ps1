Param(
    [Parameter(Mandatory = $true)] [string] $XmlsDir,
    [Parameter(Mandatory = $true)] [string] $OutputDir
)

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Report\GenerateTestReport.ps1

if ((Test-Path $XmlsDir) -and (Get-ChildItem $XmlsDir)) {
    Convert-TestReportsToHtml -XmlReportsDir $XmlsDir -OutputDir $OutputDir
} else {
    Write-Warning "No report generated, directory $XmlsDir doesn't exist or is empty"
}
