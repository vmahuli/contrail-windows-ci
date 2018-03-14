. $PSScriptRoot\TestConfigurationUtils.ps1

function Invoke-TestScenarios {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $TestsBlacklist = @(
        # Put filenames of blacklisted tests here.
        "vRouterAgentService.Tests.ps1"
    )

    $TestPaths = Get-ChildItem -Recurse -Filter "*.Tests.ps1"
    $WhitelistedTestPaths = $TestPaths | Where-Object { !($_.Name -in $TestsBlacklist) }
    $PesterScripts = $WhitelistedTestPaths | ForEach-Object {
        @{
            Path=$_.FullName;
            Parameters= @{
                TestbedAddr=$Sessions[0].ComputerName;
                ConfigFile=$TestConfigurationFile
            }; 
            Arguments=@()
        }
    }
    $TestReportOutputPath = "$TestReportOutputDirectory\testReport.xml"
    $Results = Invoke-Pester -PassThru -Script $PesterScripts `
        -OutputFormat NUnitXml -OutputFile $TestReportOutputPath
    Write-Host "Number of passed tests: $($Results.PassedCount)"
    Write-Host "Number of failed tests: $($Results.FailedCount)"
    Write-Host "Report written to $TestReportOutputPath"
    if ($Results.FailedCount -gt 0) {
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
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    try {
        Invoke-TestScenarios -Sessions $Sessions -TestConfigurationFile $TestConfigurationFile `
            -TestReportOutputDirectory $TestReportOutputDirectory
    }
    catch {
        Write-Host $_

        Get-Logs -Sessions $Sessions

        throw
    }
}
