Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [switch] $SkipUnit,
    [switch] $SkipStaticAnalysis
)

# NOTE TO DEVELOPERS
# ------------------
# The idea behind this tool is that anyone can run the basic set of tests without ANY preparation 
# (except Pester).
# A new developer should be able to run `.\Invoke-Selfcheck.ps1` and it should pass 100% of the time,
# without any special requirements, like libraries, testbed machines etc.
# Special flags may be passed to invoke more complicated tests (that have requirements), but
# the default should require nothing.


$nl = [Environment]::NewLine

function Write-VisibleMessage {
    param([string] $Message)
    Write-Host "$('='*80)$nl [Selfcheck] $Message$nl$('='*80)"
}

$IncludeTags = @("CI")
$ExcludeTags = @()

if ($SkipUnit) {
    Write-VisibleMessage "-SkipUnit flag set, skipping unit tests"
    $ExcludeTags += "Unit"
}

if (-not $TestenvConfFile) {
    Write-VisibleMessage "testenvconf file not provided, skipping system tests"
    $ExcludeTags += "Systest"
}

Write-VisibleMessage "Including tags: $IncludeTags; Excluding tags: $ExcludeTags"
Invoke-Pester -Tags $IncludeTags -ExcludeTag $ExcludeTags -Script @{Path="."; Parameters=@{TestenvConfFile=$TestenvConfFile};}

if ($SkipStaticAnalysis) {
    Write-VisibleMessage "-SkipStaticAnalysis switch set, skipping static analysis"
} elseif (-not (Get-Module PSScriptAnalyzer)) {
    Write-VisibleMessage "PSScriptAnalyzer module not found. Skipping static analysis.
        You can install it by running `Install-Module -Name PSScriptAnalyzer`."
} else {
    Write-VisibleMessage "running static analysis, this might take a while"
    .\StaticAnalysis\Invoke-StaticAnalysisTools.ps1 -RootDir . -ConfigDir $pwd/StaticAnalysis
}

Write-VisibleMessage "done"
