function Invoke-PesterTests {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestRootDir,
        [Parameter(Mandatory = $false)] [String] $ReportDir,
        [Parameter(Mandatory = $false)] [String[]] $IncludeTags,
        [Parameter(Mandatory = $false)] [String[]] $ExcludeTags,
        [Parameter(Mandatory = $false)] [System.Collections.Hashtable] $AdditionalParams
    )
    if ($ReportDir) {
        if (-not (Test-Path $ReportDir)) {
            New-Item -ItemType Directory -Path $ReportDir | Out-Null
        }
    }

    $TestPaths = Get-ChildItem -Path $TestRootDir -Recurse -Filter "*.Tests.ps1"
    $TotalResults = @{
        PassedCount = 0;
        FailedCount = 0;
    }
    foreach ($TestPath in $TestPaths) {
        $PesterScript = @{
            Path=$TestPath.FullName;
            Parameters=($Params + $AdditionalParams);
            Arguments=@();
        }
        $Basename = $TestPath.Basename
        if ($ReportDir) {
            $TestReportOutputPath = "$ReportDir\$Basename.xml"
            $Results = Invoke-Pester -PassThru -Script $PesterScript -Tags $IncludeTags -ExcludeTag $ExcludeTags `
                -OutputFormat NUnitXml -OutputFile $TestReportOutputPath
        } else {
            $Results = Invoke-Pester -PassThru -Script $PesterScript -Tags $IncludeTags -ExcludeTag $ExcludeTags
        }

        $TotalResults.PassedCount += $Results.PassedCount
        $TotalResults.FailedCount += $Results.FailedCount
    }
    return $TotalResults
}
