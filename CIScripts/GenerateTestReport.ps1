Param([Parameter(Mandatory = $true)] [string] $XmlsDir)

. $PSScriptRoot\NUnitReportFixup\Repair-NUnitReport.ps1

function Convert-TestReportToHtml {
    param ([Parameter(Mandatory = $true)] [String[]] $XmlReportDir)

    $XmlReports = Get-ChildItem -Filter "$XmlReportDir/*.xml"
    $XmlReports | ForEach-Object {
        if (Test-Path $_) {
            [string] $Content = Get-Content $_
            $FixedContent = Repair-NUnitReport -InputData $Content
            $FixedContent | Out-File $_ -Encoding "utf8"
        }
    }
    ReportUnit.exe $XmlsDir
}

if (Test-Path $XmlsDir) {
    Convert-TestReportToHtml -XmlReportDir $XmlsDir
} else {
    Write-Warning "No report generated, directory $XmlsDir doesn't exist"
}
