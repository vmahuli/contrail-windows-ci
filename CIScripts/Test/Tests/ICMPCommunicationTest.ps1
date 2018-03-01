. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\Utils\ComponentsInstallation.ps1

function Test-ICMPCommunication {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\..\Utils\CommonTestCode.ps1

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        Write-Host "===> Running ICMP Communication test"


        Install-Extension -Session $Session
        Install-Utils -Session $Session
        Install-DockerDriver -Session $Session

        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        $NetworkName = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.DefaultNetworkName

        Write-Host "Creating containers"
        $Container1ID, $Container2ID = Invoke-Command -Session $Session -ScriptBlock {
            docker run --network $Using:NetworkName -d microsoft/nanoserver ping -t localhost
            docker run --network $Using:NetworkName -d microsoft/nanoserver ping -t localhost
        }

        Write-Host "Getting VM NetAdapter Information"
        $VMNetInfo = Get-RemoteNetAdapterInformation -Session $Session -AdapterName $TestConfiguration.AdapterName

        Write-Host "Getting vHost NetAdapter Information"
        $VHostInfo = Get-RemoteNetAdapterInformation -Session $Session -AdapterName $TestConfiguration.VHostName

        Write-Host "Getting Containers NetAdapter Information"
        $Container1NetInfo = Get-RemoteContainerNetAdapterInformation -Session $Session -ContainerID $Container1ID
        $Container2NetInfo = Get-RemoteContainerNetAdapterInformation -Session $Session -ContainerID $Container2ID

        Write-Host $("Setting a connection between " + $Container1NetInfo.MACAddress + " and " + $Container2NetInfo.MACAddress + "...")
        Invoke-Command -Session $Session -ScriptBlock {
            vif.exe --add $Using:VMNetInfo.IfName --mac $Using:VMNetInfo.MACAddress --vrf 0 --type physical
            vif.exe --add $Using:VHostInfo.IfName --mac $Using:VHostInfo.MACAddress --vrf 0 --type vhost --xconnect $Using:VMNetInfo.IfName

            vif.exe --add $Using:Container1NetInfo.IfName --mac $Using:Container1NetInfo.MACAddress --vrf 1 --type virtual
            vif.exe --add $Using:Container2NetInfo.IfName --mac $Using:Container2NetInfo.MACAddress --vrf 1 --type virtual

            nh.exe --create 1 --vrf 1 --type 2 --el2 --oif $Using:Container1NetInfo.IfIndex
            nh.exe --create 2 --vrf 1 --type 2 --el2 --oif $Using:Container2NetInfo.IfIndex
            nh.exe --create 3 --vrf 1 --type 6 --cen --cni 1 --cni 2

            rt.exe -c -v 1 -f 1 -e ff:ff:ff:ff:ff:ff -n 3
            rt.exe -c -v 1 -f 1 -e $Using:Container1NetInfo.MACAddress -n 1
            rt.exe -c -v 1 -f 1 -e $Using:Container2NetInfo.MACAddress -n 2
        }

        Write-Host "Testing ping"
        $Res1 = Invoke-Command -Session $Session -ScriptBlock {
            $Container2IP = $Using:Container2NetInfo.IPAddress
            docker exec $Using:Container1ID powershell "ping $Container2IP > null 2>&1; `$LASTEXITCODE;"
        }
        $Res2 = Invoke-Command -Session $Session -ScriptBlock {
            $Container1IP = $Using:Container1NetInfo.IPAddress
            docker exec $Using:Container2ID powershell "ping $Container1IP > null 2>&1; `$LASTEXITCODE;"
        }

        Write-Host "Removing containers"
        Invoke-Command -Session $Session -ScriptBlock { docker rm -f $Using:Container1ID } | Out-Null
        Invoke-Command -Session $Session -ScriptBlock { docker rm -f $Using:Container2ID } | Out-Null

        if (($Res1 -ne 0) -or ($Res2 -ne 0)) {
            throw "===> Ping test failed!"
        }

        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        Uninstall-Extension -Session $Session
        Uninstall-Utils -Session $Session
        Uninstall-DockerDriver -Session $Session

        Write-Host "===> Success!"
    })
}
