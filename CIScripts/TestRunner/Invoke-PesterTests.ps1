function Invoke-PesterTests {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestRootDir,
        [Parameter(Mandatory = $false)] [String] $ReportPath,
        [Parameter(Mandatory = $false)] [String[]] $IncludeTags,
        [Parameter(Mandatory = $false)] [String[]] $ExcludeTags,
        [Parameter(Mandatory = $false)] [System.Collections.Hashtable] $AdditionalParams,
        [Parameter(Mandatory = $false)] [String[]] $CodeCovFiles = @()
    )

    $PesterScript = @{
        Path=$TestRootDir;
        Parameters=$AdditionalParams;
        Arguments=@();
    }
    if ($ReportPath) {
        $Results = Invoke-Pester -PassThru -Script $PesterScript -Tags $IncludeTags `
            -ExcludeTag $ExcludeTags -CodeCoverage $CodeCovFiles `
            -OutputFormat NUnitXml -OutputFile $ReportPath
    } else {
        $Results = Invoke-Pester -PassThru -Script $PesterScript -Tags $IncludeTags `
            -ExcludeTag $ExcludeTags -CodeCoverage $CodeCovFiles
    }

    return $Results
}
