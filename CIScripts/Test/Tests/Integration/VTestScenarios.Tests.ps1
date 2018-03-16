Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$true)] [string] $ConfigFile   
)

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

function Test-IsScenarioOutdated {
    Param ([Parameter(Mandatory=$true)] [string] $TestData)

    $NH_FLAG_ENCAP_L2 = 4

    [xml] $Xml = $TestData

    $BadFlags = $Xml | Select-Xml -Xpath //test/message/vr_nexthop_req/nhr_flags `
        | Where-Object { $_.Node.InnerText -BAnd $NH_FLAG_ENCAP_L2 }

    return [bool] $BadFlags
}

$TestsDir = "C:\Artifacts\vtest\tests\"

$Tests = Invoke-Command -Session $Session {
    Get-ChildItem -Path $Using:TestsDir -Filter *.xml -Recurse
} | Foreach-Object {
    @{
        Name = $_.FullName.Substring($TestsDir.Length)
        Path = $_.FullName
    }
}

Describe "vTest scenarios" {
    It "passes <Name>" -TestCases $Tests {
        param($Name, $Path)

        $TestData = Invoke-Command -Session $Session {
            Get-Content $Using:Path -Raw
        }

        if (Test-IsScenarioOutdated $TestData) {
            Set-TestInconclusive -Message "The test is using removed NH_FLAG_ENCAP_L2"
            return
        }

        $ExitCode = Invoke-Command -Session $Session -ScriptBlock {

            $Ret = Start-Process -File vtest.exe `
                -RedirectStandardOutput $Using:OutFile `
                -RedirectStandardError $Using:ErrFile `
                -Wait -PassThru -WindowStyle Hidden -ArgumentList $Using:Path

            Get-Content $Using:OutFile | Write-Host
            Get-Content $Using:ErrFile | Write-Warning

            $Ret.ExitCode
        }
        $ExitCode | Should Be 0
    }

    BeforeEach {
        Enable-VRouterExtension -Session $Session -AdapterName $TestConf.AdapterName `
            -VMSwitchName $TestConf.VMSwitchName `
            -ForwardingExtensionName $TestConf.ForwardingExtensionName
    }

    AfterEach {
        Disable-VRouterExtension -Session $Session -AdapterName $TestConf.AdapterName `
            -VMSwitchName $TestConf.VMSwitchName `
            -ForwardingExtensionName $TestConf.ForwardingExtensionName
    }

    BeforeAll {
        Invoke-Command -Session $Session { Push-Location C:\Artifacts }
        Install-Extension -Session $Session
        Install-Utils -Session $Session

        $OutFile, $ErrFile = Invoke-Command -Session $Session {
            "$Env:Temp/vtest-stdout.log"
            "$Env:Temp/vtest-stderr.log"
        }
    }

    AfterAll {
        Invoke-Command -Session $Session { Pop-Location }
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConf
        Uninstall-Utils -Session $Session
        Uninstall-Extension -Session $Session
    }
}
