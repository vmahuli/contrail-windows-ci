. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1

function Invoke-TestScenarios {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
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
    $WhitelistedTestPaths | ForEach-Object {
        $PesterScript = @{
            Path=$_.FullName;
            Parameters= @{
                TestenvConfFile=$TestenvConfFile;
                LogDir=$DetailedLogDir
            };
            Arguments=@()
        }
        $Basename = $_.Basename
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

function Get-Logs {
    Param ([Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions)

    foreach ($Session in $Sessions) {
        if ($Session.State -eq "Opened") {
            Write-Host
            Write-Host "Displaying logs from $($Session.ComputerName)"

            Invoke-Command -Session $Session {
                $LogPaths = @(
                    "$Env:ProgramData/ContrailDockerDriver/log.txt",
                    "$Env:ProgramData/ContrailDockerDriver/log.old.txt"
                )

                foreach ($Path in $LogPaths) {
                    if (Test-Path $Path) {
                        Write-Host
                        Write-Host "Contents of ${Path}:"
                        Get-Content $Path
                    }
                }
            }
        }
    }
}

function Invoke-IntegrationAndFunctionalTests {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
    $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
    $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
    $ContrailNM.EnsureProject($null)

    Invoke-TestScenarios -Sessions $Sessions `
        -TestenvConfFile $TestenvConfFile `
        -TestReportOutputDirectory $TestReportOutputDirectory
}
