Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\..\..\..\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

$TestbedConfig = Read-TestbedConfig -Path $TestenvConfFile

Describe "vTest scenarios" {
    It "passes all vtest scenarios" {
        $VMSwitchName = $TestbedConfig.VMSwitchName()
        {
            Invoke-Command -Session $Session -ScriptBlock {
                Push-Location C:\Artifacts\
                .\vtest\all_tests_run.ps1 -VMSwitchName $Using:VMSwitchName `
                    -TestsFolder vtest\tests
                Pop-Location
            }
        } | Should Not Throw
    }

    BeforeAll {
        Install-Extension -Session $Session
        Install-Utils -Session $Session
        Enable-VRouterExtension -Session $Session -TestbedConfig $TestbedConfig
    }

    AfterAll {
        Clear-TestConfiguration -Session $Session -TestbedConfig $TestbedConfig
        Uninstall-Utils -Session $Session
        Uninstall-Extension -Session $Session
    }
}
