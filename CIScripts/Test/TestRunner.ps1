. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\Utils\ContrailUtils.ps1

. $PSScriptRoot\Tests\ExtensionLongLeakTest.ps1
. $PSScriptRoot\Tests\MultiEnableDisableExtensionTest.ps1
. $PSScriptRoot\Tests\DockerDriverTest.ps1
. $PSScriptRoot\Tests\TCPCommunicationTest.ps1
. $PSScriptRoot\Tests\ICMPoMPLSoGRETest.ps1
. $PSScriptRoot\Tests\TCPoMPLSoGRETest.ps1
. $PSScriptRoot\Tests\SNATTest.ps1
. $PSScriptRoot\Tests\VRouterAgentTests.ps1
. $PSScriptRoot\Tests\ComputeControllerIntegrationTests.ps1
. $PSScriptRoot\Tests\SubnetsTests.ps1
. $PSScriptRoot\Tests\DockerDriverMultitenancyTest.ps1
. $PSScriptRoot\Tests\WindowsLinuxIntegrationTests.ps1

function Invoke-TestScenarios {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    # Temporary (remove after pesterizing tests)
    . $TestConfigurationFile
    $TestConf = Get-TestConfiguration
    $DDConf = $TestConf.DockerDriverConfiguration
    $TenantConf = $DDConf.TenantConfiguration

    $AuthToken = Get-AccessTokenFromKeystone `
        -AuthUrl $DDConf.AuthUrl `
        -Username $DDConf.Username `
        -Password $DDConf.Password `
        -TenantName $TenantConf.Name

    Add-ContrailVirtualNetwork `
        -ContrailUrl "http://$( $TestConf.ControllerIP ):$( $TestConf.ControllerRestPort )" `
        -AuthToken $AuthToken `
        -TenantName $TenantConf.Name `
        -NetworkName $TenantConf.DefaultNetworkName

    $TestConfiguration = $TestConf

    $Job.Step("Running all integration tests", {
        # $SNATConfiguration = Get-SnatConfiguration

        # Test-ExtensionLongLeak -Session $Sessions[0] -TestDurationHours $Env:LEAK_TEST_DURATION -TestConfiguration $TestConfiguration
        # Test-MultiEnableDisableExtension -Session $Sessions[0] -EnableDisableCount $Env:MULTI_ENABLE_DISABLE_EXTENSION_COUNT -TestConfiguration $TestConfiguration
        Test-TCPCommunication -Session $Sessions[0] -TestConfiguration $TestConfiguration
        # Test-ICMPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
        # Test-TCPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
        # # TODO: Uncomment after JW-1129
        # # Test-SNAT -Session $Sessions[0] -SNATConfiguration $SNATConfiguration -TestConfiguration $TestConfiguration
        # Test-VRouterAgentIntegration -Session1 $Sessions[0] -Session2 $Sessions[1] `
        #     -TestConfiguration $TestConfiguration -TestConfigurationUdp (Get-TestConfigurationUdp)
        # Test-ComputeControllerIntegration -Session $Sessions[0] -TestConfiguration $TestConfiguration
        # Test-MultipleSubnetsSupport -Session $Sessions[0] -TestConfiguration $TestConfiguration
        # Test-DockerDriverMultiTenancy -Session $Sessions[0] -TestConfiguration $TestConfiguration
        # Test-WindowsLinuxIntegration -Session $Sessions[0] -TestConfiguration (Get-TestConfigurationWindowsLinux)

        # if($Env:RUN_DRIVER_TESTS -eq "1") {
        #     Test-DockerDriver -Session $Sessions[0] -TestConfiguration $TestConfiguration
        # }
    })

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
                TestenvConfFile=$TestenvConfFile
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
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    try {
        Invoke-TestScenarios -Sessions $Sessions `
            -TestenvConfFile $TestenvConfFile `
            -TestConfigurationFile $TestConfigurationFile `
            -TestReportOutputDirectory $TestReportOutputDirectory
    }
    catch {
        Write-Host $_

        Get-Logs -Sessions $Sessions

        throw
    }
}
