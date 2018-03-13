function Convert-TestReportToHtml {
    param (
        [Parameter(Mandatory = $true)] [String[]] $XmlReports
    )

    $XmlReports | ForEach-Object {
        if (Test-Path $_) {
            ReportUnit.exe $_
        }
    }
}

Convert-TestReportToHtml -XmlReports @('testReport.xml')
