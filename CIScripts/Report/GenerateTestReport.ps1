. $PSScriptRoot\Repair-NUnitReport.ps1
. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\Common\Invoke-CommandInLocation.ps1

function Convert-TestReportsToHtml {
    param (
        [Parameter(Mandatory = $true)] [String] $XmlReportsDir,
        [Parameter(Mandatory = $true)] [string] $OutputDir,
        [Parameter(Mandatory = $false)] $GeneratorFunc = (Get-Item function:Invoke-RealReportunit)
    )

    if (-not (Get-ChildItem $XmlReportsDir -Filter *.xml)) {
        throw "No xml files in reports dir, aborting"
    }

    $FixedReportsDir = "$OutputDir/raw_NUnit"
    $PrettyDir = "$OutputDir/pretty_test_report"

    New-Item -Type Directory -Force $FixedReportsDir | Out-Null
    New-FixedTestReports -OriginalReportsDir $XmlReportsDir -FixedReportsDir $FixedReportsDir

    & $GeneratorFunc -NUnitDir $FixedReportsDir
    New-Item -Type Directory -Force $PrettyDir | Out-Null
    Move-Item "$FixedReportsDir/*.html" $PrettyDir

    $GeneratedHTMLFiles = Get-ChildItem $PrettyDir -File
    
    if (-not (Test-IndexHtmlExists -Files $GeneratedHTMLFiles)) {
        Repair-LackOfIndexHtml -Files $GeneratedHTMLFiles
    }

    New-ReportsLocationsJson -OutputDir $OutputDir
}

function Invoke-RealReportunit {
    param([Parameter(Mandatory = $true)] [string] $NUnitDir)
    Invoke-NativeCommand -ScriptBlock {
        ReportUnit.exe $NUnitDir
    }
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

function Test-IndexHtmlExists {
    param([Parameter(Mandatory = $true)] [System.IO.FileSystemInfo[]] $Files)
    $JustFilenames = $Files | Select-Object -ExpandProperty Name
    return $JustFilenames -contains "Index.html"
}

function Repair-LackOfIndexHtml {
    param([Parameter(Mandatory = $true)] [System.IO.FileSystemInfo[]] $Files)
    # ReportUnit 1.5.0 won't generate Index.html if there is only one input xml file.
    # We need Index.html to use in Monitoring to provide link to logs.
    # To fix this, rename a file to Index.html

    if ($Files.Length -Gt 1) {
        throw "More than one html file found, but no Index.html. Don't know how to fix that."
    }

    $RenameFrom = $Files[0].FullName
    $BaseDir = Split-Path $RenameFrom
    $RenameTo = Join-Path $BaseDir "Index.html"
    Write-Host "Index.html not found, renaming $RenameFrom to $RenameTo"
    Rename-Item $RenameFrom $RenameTo
}

function New-ReportsLocationsJson {
    param(
        [Parameter(Mandatory = $true)] [string] $OutputDir
    )

    Invoke-CommandInLocation $OutputDir {
        function ConvertTo-RelativePath([string] $FullPath) {
            (Resolve-Path -Relative $FullPath).split('\') -join '/'
        }

        $Xmls = Get-ChildItem -Recurse -Filter '*.xml'
        [String[]] $XmlPaths = $Xmls | Foreach-Object { ConvertTo-RelativePath $_.FullName }

        $IndexHtml = Get-ChildItem -Recurse -Filter 'Index.html'

        @{
            xml_reports = $XmlPaths
            html_report = ConvertTo-RelativePath $IndexHtml.FullName
        } | ConvertTo-Json -Depth 10 | Out-File "reports-locations.json" -Encoding "utf8"
    }
}
