Param(
    [Parameter(Mandatory = $true)] [string] $XmlsDir,
    [Parameter(Mandatory = $true)] [string] $OutputDir
)

. $PSScriptRoot\NUnitReportFixup\Repair-NUnitReport.ps1

function Convert-TestReportToHtml {
    param (
        [Parameter(Mandatory = $true)] [String] $XmlReportDir,
        [Parameter(Mandatory = $true)] [string] $OutputDir
    )

    $RawDir = "$OutputDir/raw_NUnit"
    $PrettyDirName = "pretty_test_report"
    $PrettyDir = "$OutputDir/$PrettyDirName"

    foreach ($ReportFile in Get-ChildItem $XmlReportDir -Filter *.xml) {
        [string] $Content = Get-Content $ReportFile.FullName
        $FixedContent = Repair-NUnitReport -InputData $Content
        $FixedContent | Out-File "$RawDir/$($ReportFile.Name)" -Encoding "utf8"
    }
    ReportUnit.exe $RawDir

    New-Item -Type Directory -Force $RawDir | Out-Null
    New-Item -Type Directory -Force $PrettyDir | Out-Null

    Move-Item "$XmlReportDir/*.html" $PrettyDir

    $Xmls = Get-ChildItem $RawDir | Foreach-Object { $_.FullName.split('\')[-2 .. -1] -join "/" }
    @{
        xml_reports = $Xmls
        html_report = "$PrettyDirName/index.html"
    } | ConvertTo-Json -Depth 10 | Out-File "$OutputDir/reports-locations.json"
}

if (Test-Path $XmlsDir) {
    Convert-TestReportToHtml -XmlReportDir $XmlsDir -OutputDir $OutputDir
} else {
    Write-Warning "No report generated, directory $XmlsDir doesn't exist"
}
