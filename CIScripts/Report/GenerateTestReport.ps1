. $PSScriptRoot\Repair-NUnitReport.ps1
. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1

function Convert-TestReportsToHtml {
    param (
        [Parameter(Mandatory = $true)] [String] $XmlReportsDir,
        [Parameter(Mandatory = $true)] [string] $OutputDir
    )

    $FixedReportsDir = "$OutputDir/raw_NUnit"
    $PrettyDir = "$OutputDir/pretty_test_report"

    New-Item -Type Directory -Force $FixedReportsDir | Out-Null
    New-FixedTestReports -OriginalReportsDir $XmlReportsDir -FixedReportsDir $FixedReportsDir

    Invoke-NativeCommand -ScriptBlock {
        ReportUnit.exe $FixedReportsDir
    }
    New-Item -Type Directory -Force $PrettyDir | Out-Null
    Move-Item "$FixedReportsDir/*.html" $PrettyDir

    New-ReportsLocationsJson -OutputDir $OutputDir
}

function New-FixedTestReports {
    param(
        [Parameter(Mandatory = $true)] [string] $OriginalReportsDir,
        [Parameter(Mandatory = $true)] [string] $FixedReportsDir
    )

    foreach ($ReportFile in Get-ChildItem $OriginalReportsDir -Filter *.xml) {
        [string] $Content = Get-Content $ReportFile.FullName
        $FixedContent = Repair-NUnitReport -InputData $Content
        $FixedContent | Out-File "$FixedReportsDir/$($ReportFile.Name)" -Encoding "utf8"
    }
}

function New-ReportsLocationsJson {
    param(
        [Parameter(Mandatory = $true)] [string] $OutputDir
    )

    Push-Location $OutputDir

    try {
        function ConvertTo-RelativePath([string] $FullPath) {
            (Resolve-Path -Relative $FullPath).split('\') -join '/'
        }

        $Xmls = Get-ChildItem -Recurse -Filter '*.xml'
        $XmlPaths = $Xmls | Foreach-Object { ConvertTo-RelativePath $_.FullName }

        $IndexHtml = Get-ChildItem -Recurse -Filter 'Index.html'

        @{
            xml_reports = , $XmlPaths
            html_report = ConvertTo-RelativePath $IndexHtml.FullName
        } | ConvertTo-Json -Depth 10 | Out-File "reports-locations.json" -Encoding "utf8"
    }
    finally {
        Pop-Location
    }
}