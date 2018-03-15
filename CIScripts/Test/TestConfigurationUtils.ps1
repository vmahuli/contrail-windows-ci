. $PSScriptRoot\..\Common\Invoke-UntilSucceeds.ps1

class TestConfiguration {
    [string] $AdapterName;
    [string] $VHostName;
    [string] $VMSwitchName;
    [string] $ForwardingExtensionName;
    [string] $AgentConfigFilePath;
}

$MAX_WAIT_TIME_FOR_AGENT_IN_SECONDS = 60
$TIME_BETWEEN_AGENT_CHECKS_IN_SECONDS = 2

function Stop-ProcessIfExists {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ProcessName)

    Invoke-Command -Session $Session -ScriptBlock {
        $Proc = Get-Process $Using:ProcessName -ErrorAction SilentlyContinue
        if ($Proc) {
            $Proc | Stop-Process -Force -PassThru | Wait-Process -ErrorAction SilentlyContinue
        }
    }
}

function Test-IsProcessRunning {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ProcessName)

    $Proc = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-Process $Using:ProcessName -ErrorAction SilentlyContinue)
    }

    return $(if ($Proc) { $true } else { $false })
}

function Enable-VRouterExtension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName,
           [Parameter(Mandatory = $false)] [string] $ContainerNetworkName = "testnet")

    Write-Host "Enabling Extension"

    Invoke-Command -Session $Session -ScriptBlock {
        New-ContainerNetwork -Mode Transparent -NetworkAdapterName $Using:AdapterName -Name $Using:ContainerNetworkName | Out-Null
        $Extension = Get-VMSwitch | Get-VMSwitchExtension -Name $Using:ForwardingExtensionName | Where-Object Enabled
        if ($Extension) {
            Write-Warning "Extension already enabled on: $($Extension.SwitchName)"
        }
        $Extension = Enable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName
        if ((-not $Extension.Enabled) -or (-not ($Extension.Running))) {
            throw "Failed to enable extension (not enabled or not running)"
        }
    }
}

function Disable-VRouterExtension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName)

    Write-Host "Disabling Extension"

    Invoke-Command -Session $Session -ScriptBlock {
        Disable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue | Out-Null
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -Force
    }
}

function Test-IsVRouterExtensionEnabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName)

    $Ext = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue)
    }

    return $($Ext.Enabled -and $Ext.Running)
}

function Enable-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [Hashtable] $ControllerConfig,
           [Parameter(Mandatory = $false)] [int] $WaitTime = 60)

    Write-Host "Enabling Docker Driver"

    $OSCreds = $ControllerConfig.OS_Credentials
    $ControllerIP = $ControllerConfig.Rest_API.Address

    Invoke-Command -Session $Session -ScriptBlock {

        $LogDir = "$Env:ProgramData/ContrailDockerDriver"

        if (Test-Path $LogDir) {
            Push-Location $LogDir

            if (Test-Path log.txt) {
                Move-Item -Force log.txt log.old.txt
            }

            Pop-Location
        }

        # Nested ScriptBlock variable passing workaround
        $OSCreds = $Using:OSCreds
        $AdapterName = $Using:AdapterName
        $ControllerIP = $Using:ControllerIP

        Start-Job -ScriptBlock {
            Param ($OpenStack, $ControllerIP, $Adapter)

            $AuthUrl = "http://$( $OpenStack.Address ):$( $OpenStack.Port )/v2.0"

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification="The env variable is read by contrail-windows-docker.exe")]
            $Env:OS_USERNAME = $OpenStack.Username

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification="The env variable is read by contrail-windows-docker.exe")]
            $Env:OS_PASSWORD = $OpenStack.Password

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification="The env variable is read by contrail-windows-docker.exe")]
            $Env:OS_AUTH_URL = $AuthUrl

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification="The env variable is read by contrail-windows-docker.exe")]
            $Env:OS_TENANT_NAME = $OpenStack.Project

            & "C:\Program Files\Juniper Networks\contrail-windows-docker.exe" -forceAsInteractive -controllerIP $ControllerIP -adapter "$Adapter" -vswitchName "Layered <adapter>" -logLevel "Debug"
        } -ArgumentList $OSCreds, $ControllerIP, $AdapterName | Out-Null
    }

    Start-Sleep -s $WaitTime
}

function Disable-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Disabling Docker Driver"

    Stop-ProcessIfExists -Session $Session -ProcessName "contrail-windows-docker"

    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service docker | Out-Null
        Get-NetNat | Remove-NetNat -Confirm:$false
        Get-ContainerNetwork | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Remove-ContainerNetwork -Force
        Start-Service docker | Out-Null
    }
}

function Test-IsDockerDriverEnabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    function Test-IsDockerDriverListening {
        return Invoke-Command -Session $Session -ScriptBlock {
            return Test-Path //./pipe/Contrail
        }
    }

    function Test-IsDockerPluginRegistered {
        return Invoke-Command -Session $Session -ScriptBlock {
            return Test-Path $Env:ProgramData/docker/plugins/Contrail.spec
        }
    }

    function Test-IsDockerDriverProcessRunning {
        return Test-IsProcessRunning -Session $Session -ProcessName "contrail-windows-docker"
    }

    return (Test-IsDockerDriverListening) -And `
        (Test-IsDockerPluginRegistered) -And `
        (Test-IsDockerDriverProcessRunning)
}

function Enable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Starting Agent"
    Invoke-Command -Session $Session -ScriptBlock {
        Start-Service ContrailAgent | Out-Null
    }
}

function Disable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Stopping Agent"
    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service ContrailAgent -ErrorAction SilentlyContinue | Out-Null
    }
}

function Get-AgentServiceStatus {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)
    $Service = Invoke-Command -Session $Session -ScriptBlock {
        Get-Service "ContrailAgent" -ErrorAction SilentlyContinue
    }
    if ($Service -and $Service.Status) {
        return $Service.Status.ToString()
    } else {
        return $null
    }
}

function Assert-IsAgentServiceEnabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)
    $Status = Invoke-UntilSucceeds { Get-AgentServiceStatus -Session $Session } `
            -Interval $TIME_BETWEEN_AGENT_CHECKS_IN_SECONDS `
            -Duration $MAX_WAIT_TIME_FOR_AGENT_IN_SECONDS
    if ($Status -eq "Running") {
        return
    } else {
        throw "Agent service is not enabled. EXPECTED: Agent service is enabled"
    }
}

function Assert-IsAgentServiceDisabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)
    $Status = Invoke-UntilSucceeds { Get-AgentServiceStatus -Session $Session } `
            -Interval $TIME_BETWEEN_AGENT_CHECKS_IN_SECONDS `
            -Duration $MAX_WAIT_TIME_FOR_AGENT_IN_SECONDS
    if ($Status -eq "Stopped") {
        return
    } else {
        throw "Agent service is not disabled. EXPECTED: Agent service is disabled"
    }
}

function Read-SyslogForAgentCrash {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [DateTime] $After)
    Invoke-Command -Session $Session -ScriptBlock {
        Get-EventLog -LogName "System" -EntryType "Error" `
            -Source "Service Control Manager" `
            -Message "The ContrailAgent service terminated unexpectedly*" `
            -After ($Using:After).addSeconds(-1)
    }
}

function New-DockerNetwork {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $false)] [string] $Network,
           [Parameter(Mandatory = $false)] [string] $Subnet)

    if (!$Network) {
        $Network = $Name
    }

    Write-Host "Creating network $Name"

    $NetworkID = Invoke-Command -Session $Session -ScriptBlock {
        if ($Using:Subnet) {
            return $(docker network create --ipam-driver windows --driver Contrail -o tenant=$Using:TenantName -o network=$Using:Network --subnet $Using:Subnet $Using:Name)
        }
        else {
            return $(docker network create --ipam-driver windows --driver Contrail -o tenant=$Using:TenantName -o network=$Using:Network $Using:Name)
        }
    }

    return $NetworkID
}

function Remove-AllUnusedDockerNetworks {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Removing all docker networks"

    Invoke-Command -Session $Session -ScriptBlock {
        docker network prune --force | Out-Null
    }
}

function Wait-RemoteInterfaceIP {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [Int] $ifIndex)

    Invoke-Command -Session $Session -ScriptBlock {
        $WAIT_TIME_FOR_DHCP_IN_SECONDS = 60

        foreach ($i in 1..$WAIT_TIME_FOR_DHCP_IN_SECONDS) {
            $Address = Get-NetIPAddress -InterfaceIndex $Using:ifIndex -ErrorAction SilentlyContinue `
                | Where-Object AddressFamily -eq IPv4 `
                | Where-Object { ($_.SuffixOrigin -eq "Dhcp") -or ($_.SuffixOrigin -eq "Manual") }
            if ($Address) {
                return
            }
            Start-Sleep -Seconds 1
        }

        throw "Waiting for IP on interface $($Using:ifIndex) timed out after $WAIT_TIME_FOR_DHCP_IN_SECONDS seconds"
    }
}

function Initialize-DriverAndExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
        [Parameter(Mandatory = $true)] [Hashtable] $ControllerConfig
    )

    Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration `
        -ControllerConfig $ControllerConfig -NoNetwork $true
}

function Initialize-TestConfiguration {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
        [Parameter(Mandatory = $true)] [Hashtable] $ControllerConfig,
        [Parameter(Mandatory = $false)] [bool] $NoNetwork = $false
    )

    Write-Host "Initializing Test Configuration"

    $NRetries = 3;
    foreach ($i in 1..$NRetries) {
        # DockerDriver automatically enables Extension, so there is no need to enable it manually

        Enable-DockerDriver -Session $Session `
            -AdapterName $TestConfiguration.AdapterName `
            -ControllerConfig $ControllerConfig `
            -WaitTime 0

        $WaitForSeconds = $i * 600 / $NRetries;
        $SleepTimeBetweenChecks = 10;
        $MaxNumberOfChecks = $WaitForSeconds / $SleepTimeBetweenChecks

        # Wait for DockerDriver to start
        $Res = $false
        for ($RetryNum = $MaxNumberOfChecks; $RetryNum -gt 0; $RetryNum--) {
            $Res = Test-IsDockerDriverEnabled -Session $Session
            if ($Res -eq $true) {
                break;
            }

            Start-Sleep -s $SleepTimeBetweenChecks
        }

        if ($Res -ne $true) {
            if ($i -eq $NRetries) {
                throw "Docker driver was not enabled."
            } else {
                Write-Host "Docker driver was not enabled, retrying."
                Stop-ProcessIfExists -Session $Session -ProcessName "contrail-windows-docker"
            }
        } else {
            break;
        }
    }

    $HNSTransparentAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $TestConfiguration.VHostName
    Wait-RemoteInterfaceIP -Session $Session -ifIndex $HNSTransparentAdapter.ifIndex

    if (!$NoNetwork) {
        throw "Creating network in Initialize-TestConfiguration is deprecated"
    }
}

function Clear-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    Write-Host "Cleaning up test configuration"

    Remove-AllUnusedDockerNetworks -Session $Session
    Disable-AgentService -Session $Session
    Disable-DockerDriver -Session $Session
    Disable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName `
        -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
}

function New-AgentConfigFile {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    # Gather information about testbed's network adapters
    $HNSTransparentAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $TestConfiguration.VHostName

    $PhysicalAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $TestConfiguration.AdapterName

    # Prepare parameters for script block
    $ControllerIP = $TestConfiguration.ControllerIP
    $VHostIfName = $HNSTransparentAdapter.ifName
    $VHostIfIndex = $HNSTransparentAdapter.ifIndex

    $TEST_NETWORK_GATEWAY = "10.7.3.1"
    $VHostGatewayIP = $TEST_NETWORK_GATEWAY
    $PhysIfName = $PhysicalAdapter.ifName

    $AgentConfigFilePath = $TestConfiguration.AgentConfigFilePath

    Invoke-Command -Session $Session -ScriptBlock {
        $ControllerIP = $Using:ControllerIP
        $VHostIfName = $Using:VHostIfName
        $VHostIfIndex = $Using:VHostIfIndex
        $PhysIfName = $Using:PhysIfName

        $VHostIP = (Get-NetIPAddress -ifIndex $VHostIfIndex -AddressFamily IPv4).IPAddress
        $VHostGatewayIP = $Using:VHostGatewayIP

        $ConfigFileContent = @"
[DEFAULT]
platform=windows

[CONTROL-NODE]
servers=$ControllerIP

[DISCOVERY]
server=$ControllerIP

[VIRTUAL-HOST-INTERFACE]
name=$VHostIfName
ip=$VHostIP/24
gateway=$VHostGatewayIP
physical_interface=$PhysIfName
"@

        # Save file with prepared config
        [System.IO.File]::WriteAllText($Using:AgentConfigFilePath, $ConfigFileContent)
    }
}

function Initialize-ComputeServices {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $false)] [Boolean] $NoNetwork = $false)

        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $NoNetwork
        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration
        Enable-AgentService -Session $Session
}

function Remove-DockerNetwork {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
           [Parameter(Mandatory = $false)] [string] $Name)

    if (!$Name) {
        $Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.DefaultNetworkName
    }

    Invoke-Command -Session $Session -ScriptBlock {
        docker network rm $Using:Name | Out-Null
    }
}

function New-Container {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $NetworkName,
           [Parameter(Mandatory = $false)] [string] $Name)

    $ContainerID = Invoke-Command -Session $Session -ScriptBlock {
        if ($Using:Name) {
            return $(docker run --name $Using:Name --network $Using:NetworkName -id microsoft/nanoserver powershell)
        }
        else {
            return $(docker run --network $Using:NetworkName -id microsoft/nanoserver powershell)
        }
    }

    return $ContainerID
}

function Remove-Container {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $false)] [string] $NameOrId)

    Invoke-Command -Session $Session -ScriptBlock {
        docker rm -f $Using:NameOrId | Out-Null
    }
}
