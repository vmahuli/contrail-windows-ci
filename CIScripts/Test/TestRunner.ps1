. $PSScriptRoot\TestConfigurationUtils.ps1

. $PSScriptRoot\Tests\AgentServiceTests.ps1
. $PSScriptRoot\Tests\ExtensionLongLeakTest.ps1
. $PSScriptRoot\Tests\MultiEnableDisableExtensionTest.ps1
. $PSScriptRoot\Tests\DockerDriverTest.ps1
. $PSScriptRoot\Tests\VTestScenariosTest.ps1
. $PSScriptRoot\Tests\TCPCommunicationTest.ps1
. $PSScriptRoot\Tests\ICMPoMPLSoGRETest.ps1
. $PSScriptRoot\Tests\TCPoMPLSoGRETest.ps1
. $PSScriptRoot\Tests\SNATTest.ps1
. $PSScriptRoot\Tests\VRouterAgentTests.ps1
. $PSScriptRoot\Tests\ComputeControllerIntegrationTests.ps1
. $PSScriptRoot\Tests\SubnetsTests.ps1
. $PSScriptRoot\Tests\Pkt0PipeImplementationTests.ps1
. $PSScriptRoot\Tests\DockerDriverMultitenancyTest.ps1
. $PSScriptRoot\Tests\WindowsLinuxIntegrationTests.ps1

function Run-TestScenarios {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile
    )

    $Job.Step("Running all integration tests", {

        . "$TestConfigurationFile"

        $TestConfiguration = Get-TestConfiguration

        # $SNATConfiguration = Get-SnatConfiguration

        Test-AgentService -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-ExtensionLongLeak -Session $Sessions[0] -TestDurationHours $Env:LEAK_TEST_DURATION -TestConfiguration $TestConfiguration
        Test-MultiEnableDisableExtension -Session $Sessions[0] -EnableDisableCount $Env:MULTI_ENABLE_DISABLE_EXTENSION_COUNT -TestConfiguration $TestConfiguration
        Test-VTestScenarios -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-TCPCommunication -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-ICMPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
        Test-TCPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
        # TODO: Uncomment after JW-1129
        # Test-SNAT -Session $Sessions[0] -SNATConfiguration $SNATConfiguration -TestConfiguration $TestConfiguration
        Test-VRouterAgentIntegration -Session1 $Sessions[0] -Session2 $Sessions[1] `
            -TestConfiguration $TestConfiguration -TestConfigurationUdp (Get-TestConfigurationUdp)
        Test-ComputeControllerIntegration -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-MultipleSubnetsSupport -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-DockerDriverMultiTenancy -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-WindowsLinuxIntegration -Session $Sessions[0] -TestConfiguration (Get-TestConfigurationWindowsLinux)
        Test-Pkt0PipeImplementation -Session $Sessions[0] -TestConfiguration $TestConfiguration

        if($Env:RUN_DRIVER_TESTS -eq "1") {
            Test-DockerDriver -Session $Sessions[0] -TestConfiguration $TestConfiguration
        }
    })
}

function Collect-Logs {
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

function Run-Tests {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile
    )

    try {
        Run-TestScenarios -Sessions $Sessions -TestConfigurationFile $TestConfigurationFile
    }
    catch {
        Write-Host $_

        Collect-Logs -Sessions $Sessions

        throw
    }
}
