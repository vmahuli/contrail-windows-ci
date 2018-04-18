Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\Common\VMUtils.ps1
. $PSScriptRoot\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\Utils\ContrailUtils.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

$OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
$ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
$SystemConfig = Read-SystemConfig -Path $TestenvConfFile

Describe "Remove-AllContainers" {
    It "Removes single container if exists" {
        New-Container -Session $Session -NetworkName $NetworkName
        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -q
        } | Should Not BeNullOrEmpty

        Remove-AllContainers -Session $Session

        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -q
        } | Should BeNullOrEmpty
    }

    It "Removes mutliple containers if exist" {
        New-Container -Session $Session -NetworkName $NetworkName
        New-Container -Session $Session -NetworkName $NetworkName
        New-Container -Session $Session -NetworkName $NetworkName
        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -q
        } | Should Not BeNullOrEmpty

        Remove-AllContainers -Session $Session

        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -q
        } | Should BeNullOrEmpty
    }

    It "Does nothing if list of containers is empty" {
        Remove-AllContainers -Session $Session

        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -q
        } | Should BeNullOrEmpty
    }

    BeforeEach {
        $Subnet = [SubnetConfiguration]::new(
            "10.0.0.0",
            24,
            "10.0.0.1",
            "10.0.0.100",
            "10.0.0.200"
        )

        Write-Host "Creating ContrailNetwork"
        $NetworkName = "Testnet"

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNetwork",
            Justification="It's used in AfterEach. Perhaps https://github.com/PowerShell/PSScriptAnalyzer/issues/804"
        )]
        $ContrailNetwork = $ContrailNM.AddNetwork($null, $NetworkName, $Subnet)

        Initialize-DriverAndExtension -Session $Session `
        -SystemConfig $SystemConfig `
        -OpenStackConfig $OpenStackConfig `
        -ControllerConfig $ControllerConfig

        New-DockerNetwork -Session $Session `
        -TenantName $ControllerConfig.DefaultProject `
        -Name $NetworkName `
        -Subnet "$( $Subnet.IpPrefix )/$( $Subnet.IpPrefixLen )"
    }

    AfterEach {
        Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
        if (Get-Variable "ContrailNetwork" -ErrorAction SilentlyContinue) {
            $ContrailNM.RemoveNetwork($ContrailNetwork)
            Remove-Variable "ContrailNetwork"
        }
    }

    BeforeAll {
        Install-DockerDriver -Session $Session
        Install-Extension -Session $Session

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNM",
            Justification="It's used in BeforeEach. Perhaps https://github.com/PowerShell/PSScriptAnalyzer/issues/804"
        )]
        $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
    }

    AfterAll {
        Uninstall-DockerDriver -Session $Session
        Uninstall-Extension -Session $Session
    }

}
Remove-PSSession $Sessions
