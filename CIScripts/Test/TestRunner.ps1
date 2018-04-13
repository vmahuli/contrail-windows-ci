. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1

function Invoke-TestScenarios {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $TestsBlacklist = @(
        # Put filenames of blacklisted tests here.
    )

    $TotalResults = @{
        PassedCount = 0;
        FailedCount = 0;
    }

    $DetailedLogDir = Join-Path $TestReportOutputDirectory "detailed"

    $TestPaths = Get-ChildItem -Recurse -Filter "*.Tests.ps1"
    $WhitelistedTestPaths = $TestPaths | Where-Object { !($_.Name -in $TestsBlacklist) }
    foreach ($TestPath in $WhitelistedTestPaths) {
        $PesterScript = @{
            Path=$TestPath.FullName;
            Parameters= @{
                TestenvConfFile=$TestenvConfFile;
                LogDir=$DetailedLogDir;
            };
            Arguments=@();
        }
        $Basename = $TestPath.Basename
        $TestReportOutputPath = "$TestReportOutputDirectory\$Basename.xml"
        $Results = Invoke-Pester -PassThru -Script $PesterScript `
            -OutputFormat NUnitXml -OutputFile $TestReportOutputPath

        $TotalResults.PassedCount += $Results.PassedCount
        $TotalResults.FailedCount += $Results.FailedCount
    }

    Write-Host "Number of passed tests: $($TotalResults.PassedCount)"
    Write-Host "Number of failed tests: $($TotalResults.FailedCount)"
    Write-Host "Report written to $TestReportOutputPath"
    if ($TotalResults.FailedCount -gt 0) {
        throw "Some tests failed"
    }
}

function Invoke-IntegrationAndFunctionalTests {
    Param (
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
    $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
    $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
    $ContrailNM.EnsureProject($null)

    Invoke-TestScenarios `
        -TestenvConfFile $TestenvConfFile `
        -TestReportOutputDirectory $TestReportOutputDirectory
}
