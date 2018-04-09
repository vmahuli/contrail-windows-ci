Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\..\..\..\Common\Invoke-UntilSucceeds.ps1
. $PSScriptRoot\..\..\..\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\..\..\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1 # Get-RemoteNetAdapterInformation
. $PSScriptRoot\..\..\Utils\DockerImageBuild.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

$ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
$OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
$SystemConfig = Read-SystemConfig -Path $TestenvConfFile

Describe "Single compute node protocol tests with Agent" {

    BeforeAll {
        Install-DockerDriver -Session $Session
        Install-Agent -Session $Session
        Install-Extension -Session $Session
        Install-Utils -Session $Session
        
        $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
        $Subnet = [SubnetConfiguration]::new(
            "10.0.0.0",
            24,
            "10.0.0.1",
            "10.0.0.100",
            "10.0.0.200"
        )

        Write-Host "Creating ContrailNetwork"
        $NetworkName = "testnetxxd"

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNetwork",
            Justification="It's used in AfterEach. Perhaps https://github.com/PowerShell/PSScriptAnalyzer/issues/804"
        )]
        $ContrailNetwork = $ContrailNM.AddNetwork($null, $NetworkName, $Subnet)
    }

    AfterAll {
        Uninstall-DockerDriver -Session $Session
        Uninstall-Agent -Session $Session
        Uninstall-Extension -Session $Session
        Uninstall-Utils -Session $Session

        if (Get-Variable ContrailNetwork -ErrorAction SilentlyContinue) {
            $ContrailNM.RemoveNetwork($ContrailNetwork)
        }
    }

    BeforeEach {
        Initialize-DriverAndExtension -Session $Session `
            -SystemConfig $SystemConfig `
            -OpenStackConfig $OpenStackConfig `
            -ControllerConfig $ControllerConfig

        New-DockerNetwork -Session $Session `
            -TenantName $ControllerConfig.DefaultProject `
            -Name $NetworkName `
            -Subnet "$( $Subnet.IpPrefix )/$( $Subnet.IpPrefixLen )"

        New-AgentConfigFile -Session $Session `
            -ControllerConfig $ControllerConfig `
            -SystemConfig $SystemConfig
    }

    AfterEach {
        Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
        if ((Get-AgentServiceStatus -Session $Session) -eq "Running") {
            Disable-AgentService -Session $Session
        }
    }

    It "Stress test" {
        Enable-AgentService -Session $Session

        while ($true) {
            Write-Host "Creating containers"
            Start-Sleep -Seconds 1
            $BeforeCrash = Invoke-Command -Session $Session -ScriptBlock { Get-Date }
            $Container = (Invoke-NativeCommand -Session $Session -CaptureOutput -ScriptBlock {
                docker run --network $Using:NetworkName -d microsoft/nanoserver ping -t localhost
            }).Output

            Consistently {
                Read-SyslogForAgentCrash -Session $Session -After $BeforeCrash | Should BeNullOrEmpty
                Write-Host "No crash"
            } -Duration 13

            Get-AgentServiceStatus -Session $Session | Should Be "Running"
            
            Write-Host "Removing containers"
            Invoke-Command -Session $Session -ScriptBlock { docker rm -f $Using:Container } | Out-Null
        }
    }
}
