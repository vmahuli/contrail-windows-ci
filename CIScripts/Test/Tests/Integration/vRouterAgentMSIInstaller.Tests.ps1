# TODO: remove after these tests are fixed and TestConf is used again.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
    "", Justification="Issue #804 from PSScriptAnalyzer GitHub")]

Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$true)] [string] $ConfigFile
)

. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1

. $ConfigFile
$TestConf = Get-TestConfiguration
$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

Describe "vRouter Agent MSI installer" {

    function Test-AgentMSIBehaviourCorrect {
        Install-Agent -Session $Session
        Eventually {
            Get-AgentServiceStatus -Session $Session | Should Be "Stopped"
        } -Duration 15

        Uninstall-Agent -Session $Session
        Eventually {
            Get-AgentServiceStatus -Session $Session | Should BeNullOrEmpty
        } -Duration 15
    }

    Context "when vRouter Forwarding Extension is not running" {
        It "registers/unregisters Agent service and never enables" {
            Test-AgentMSIBehaviourCorrect
        }
    }

    Context "when vRouter Forwarding Extension is running" {
        It "registers/unregisters Agent service and never enables" {
            Test-AgentMSIBehaviourCorrect
        }

        BeforeEach {
            Install-Extension -Session $Session
            Enable-VRouterExtension -Session $Session -AdapterName $TestConf.AdapterName `
                -VMSwitchName $TestConf.VMSwitchName `
                -ForwardingExtensionName $TestConf.ForwardingExtensionName
        }

        AfterEach {
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConf
            Uninstall-Extension -Session $Session
        }
    }

    AfterEach {
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConf
    }
}
