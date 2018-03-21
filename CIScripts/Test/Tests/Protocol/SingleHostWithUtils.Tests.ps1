Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\..\..\..\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1 # Get-RemoteNetAdapterInformation

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

$OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
$ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
$SystemConfig = Read-SystemConfig -Path $TestenvConfFile

Describe "Single compute node protocol tests with utils" {

    Context "TCP" {
        It "TCP connection works" -Pending {
            # TCPCommunicationTest.ps1
        }
    }

    Context "ICMP" {
        It "Ping between containers succeeds" -Pending {
            Invoke-Command -Session $Session -ScriptBlock {
                $Container2IP = $Using:Container2NetInfo.IPAddress
                docker exec $Using:Container1ID powershell "ping $Container2IP > null 2>&1; `$LASTEXITCODE;"
            } | Should Be 0

            Invoke-Command -Session $Session -ScriptBlock {
                $Container1IP = $Using:Container1NetInfo.IPAddress
                docker exec $Using:Container2ID powershell "ping $Container1IP > null 2>&1; `$LASTEXITCODE;"
            } | Should Be 0
        }

        BeforeEach {
            Write-Host "Creating containers"
            $Container1ID, $Container2ID = Invoke-Command -Session $Session -ScriptBlock {
                docker run --network $Using:NetworkName -d microsoft/nanoserver ping -t localhost
                docker run --network $Using:NetworkName -d microsoft/nanoserver ping -t localhost
            }

            Write-Host "Getting VM NetAdapter Information"
            $VMNetInfo = Get-RemoteNetAdapterInformation -Session $Session `
                -AdapterName $SystemConfig.AdapterName

            Write-Host "Getting vHost NetAdapter Information"
            $VHostInfo = Get-RemoteNetAdapterInformation -Session $Session `
                -AdapterName $SystemConfig.VHostName

            Write-Host "Getting Containers NetAdapter Information"
            $Container1NetInfo = Get-RemoteContainerNetAdapterInformation `
                -Session $Session -ContainerID $Container1ID
            $Container2NetInfo = Get-RemoteContainerNetAdapterInformation `
                -Session $Session -ContainerID $Container2ID

            Write-Host $("Setting a connection between " + $Container1NetInfo.MACAddress + `
                " and " + $Container2NetInfo.MACAddress + "...")

            Invoke-Command -Session $Session -ScriptBlock {
                vif.exe --add $Using:VMNetInfo.IfName --mac $Using:VMNetInfo.MACAddress --vrf 0 --type physical
                vif.exe --add $Using:VHostInfo.IfName --mac $Using:VHostInfo.MACAddress --vrf 0 --type vhost --xconnect $Using:VMNetInfo.IfName

                vif.exe --add $Using:Container1NetInfo.IfName --mac $Using:Container1NetInfo.MACAddress --vrf 1 --type virtual
                vif.exe --add $Using:Container2NetInfo.IfName --mac $Using:Container2NetInfo.MACAddress --vrf 1 --type virtual

                try {
                    Invoke-Command {
                        $ErrorActionPreference = "Continue"
                        nh.exe --create 1 --vrf 1 --type 2 --l2 --oif $Using:Container1NetInfo.IfIndex 2> $null
                        if ($LastExitCode -ne 0) {
                            throw "old utils do not support --l2 flag"
                        }
                        nh.exe --create 2 --vrf 1 --type 2 --l2 --oif $Using:Container2NetInfo.IfIndex
                        nh.exe --create 3 --vrf 1 --type 6 --l2 --cen --cni 1 --cni 2
                    }
                }
                catch {
                    nh.exe --create 1 --vrf 1 --type 2 --el2 --oif $Using:Container1NetInfo.IfIndex
                    nh.exe --create 2 --vrf 1 --type 2 --el2 --oif $Using:Container2NetInfo.IfIndex
                    nh.exe --create 3 --vrf 1 --type 6 --cen --cni 1 --cni 2
                }

                rt.exe -c -v 1 -f 1 -e ff:ff:ff:ff:ff:ff -n 3
                rt.exe -c -v 1 -f 1 -e $Using:Container1NetInfo.MACAddress -n 1
                rt.exe -c -v 1 -f 1 -e $Using:Container2NetInfo.MACAddress -n 2
            }

        }

        AfterEach {
            Write-Host "Removing containers"
            if (Get-Variable Container1ID -ErrorAction SilentlyContinue) {
                Invoke-Command -Session $Session -ScriptBlock { docker rm -f $Using:Container1ID } | Out-Null
                Invoke-Command -Session $Session -ScriptBlock { docker rm -f $Using:Container2ID } | Out-Null
            }
        }
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
        $NetworkName = "testnet"

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
        if (Get-Variable ContrailNetwork -ErrorAction SilentlyContinue) {
            $ContrailNM.RemoveNetwork($ContrailNetwork)
        }
    }


    BeforeAll {
        Install-DockerDriver -Session $Session
        Install-Extension -Session $Session
        Install-Utils -Session $Session

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
        Uninstall-Utils -Session $Session
    }
}
