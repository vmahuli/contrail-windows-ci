Param (
    [Parameter(Mandatory=$true)] [string] $TestbedAddr
)

. $PSScriptRoot\..\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\PesterHelpers\PesterHelpers.ps1

. $PSScriptRoot\..\GetTestConfigurationCodiLegacy.ps1
$TestConf = Get-TestConfiguration
$Session = New-PSSession -ComputerName $TestbedAddr -Credential (Get-VMCreds)

Describe "vRouter Agent MSI installer" {
    Context "installation and uninstallation" {
        It "registers/unregisters agent service and never enables" {
            Install-Agent -Session $Session
            Eventually {
                Get-AgentServiceStatus -Session $Session | Should Be "Stopped"
            } -Duration 3

            Uninstall-Agent -Session $Session
            Eventually {
                {Get-AgentServiceStatus -Session $Session} | Should Throw
            } -Duration 3
        }
    }

    BeforeEach {
        Initialize-DriverAndExtension -Session $Session -TestConfiguration $TestConf
    }

    AfterEach {
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConf
    }
}
