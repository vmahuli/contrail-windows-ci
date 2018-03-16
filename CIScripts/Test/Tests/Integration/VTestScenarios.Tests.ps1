Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$true)] [string] $ConfigFile   
)

. $PSScriptRoot\..\..\..\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1

. $ConfigFile
$TestConf = Get-TestConfiguration
$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

Describe "vTest scenarios" {
    It "passes all vtest scenarios" {
        $VMSwitchName = $TestConf.VMSwitchName
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
        Enable-VRouterExtension -Session $Session -AdapterName $TestConf.AdapterName `
            -VMSwitchName $TestConf.VMSwitchName `
            -ForwardingExtensionName $TestConf.ForwardingExtensionName
    }

    AfterAll {
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConf
        Uninstall-Utils -Session $Session
        Uninstall-Extension -Session $Session
    }
}
