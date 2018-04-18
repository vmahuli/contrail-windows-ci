. $PSScriptRoot\..\Testenv\Testenv.ps1
. $PSScriptRoot\Utils\CommonTestCode.ps1
. $PSScriptRoot\..\Common\Invoke-UntilSucceeds.ps1

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
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $false)] [string] $ContainerNetworkName = "testnet"
    )

    Write-Host "Enabling Extension"

    $AdapterName = $SystemConfig.AdapterName
    $ForwardingExtensionName = $SystemConfig.ForwardingExtensionName
    $VMSwitchName = $SystemConfig.VMSwitchName()

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
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    Write-Host "Disabling Extension"

    $AdapterName = $SystemConfig.AdapterName
    $ForwardingExtensionName = $SystemConfig.ForwardingExtensionName
    $VMSwitchName = $SystemConfig.VMSwitchName()

    Invoke-Command -Session $Session -ScriptBlock {
        Disable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue | Out-Null
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -Force
    }
}

function Test-IsVRouterExtensionEnabled {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    $ForwardingExtensionName = $SystemConfig.ForwardingExtensionName
    $VMSwitchName = $SystemConfig.VMSwitchName()

    $Ext = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue)
    }

    return $($Ext.Enabled -and $Ext.Running)
}

function Start-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [OpenStackConfig] $OpenStackConfig,
           [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig,
           [Parameter(Mandatory = $false)] [int] $WaitTime = 60)

    Write-Host "Starting Docker Driver"

    $Arguments = @(
        "-forceAsInteractive",
        "-controllerIP", $ControllerConfig.Address,
        "-os_username", $OpenStackConfig.Username,
        "-os_password", $OpenStackConfig.Password,
        "-os_auth_url", $OpenStackConfig.AuthUrl(),
        "-os_tenant_name", $OpenStackConfig.Project,
        "-adapter", $AdapterName,
        "-vswitchName", "Layered <adapter>",
        "-logLevel", "Debug"
    )

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
        $Arguments = $Using:Arguments

        Start-Job -ScriptBlock {
            Param($Arguments)
            & "C:\Program Files\Juniper Networks\contrail-windows-docker.exe" $Arguments

            # The `, $null` below is used to force passing $Arguments as an arguments'
            # list element instead of an arguments list itself.
            # @($Arguments) looks like it should work, but does not.
        } -ArgumentList $Arguments, $null
    }

    Start-Sleep -s $WaitTime
}

function Stop-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Stopping Docker Driver"

    Stop-ProcessIfExists -Session $Session -ProcessName "contrail-windows-docker"

    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service docker | Out-Null
        Get-NetNat | Remove-NetNat -Confirm:$false
        Get-ContainerNetwork | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Remove-ContainerNetwork -Force
        Start-Service docker | Out-Null
    }
}

function Test-IsDockerDriverProcessRunning {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    return Test-IsProcessRunning -Session $Session -ProcessName "contrail-windows-docker"
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

    return (Test-IsDockerDriverListening) -And `
        (Test-IsDockerPluginRegistered)
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

    Invoke-Command -Session $Session -ScriptBlock {
        $Service = Get-Service "ContrailAgent" -ErrorAction SilentlyContinue

        if ($Service -and $Service.Status) {
            return $Service.Status.ToString()
        } else {
            return $null
        }
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
           [Parameter(Mandatory = $true)] [String] $AdapterName)

    Invoke-UntilSucceeds -Name "Waiting for IP on interface $AdapterName" -Duration 60 {
        Invoke-Command -Session $Session {
            Get-NetAdapter -Name $Using:AdapterName `
                | Get-NetIPAddress -ErrorAction SilentlyContinue `
                | Where-Object AddressFamily -eq IPv4 `
                | Where-Object { ($_.SuffixOrigin -eq "Dhcp") -or ($_.SuffixOrigin -eq "Manual") }
        }
    } | Out-Null
}

function Initialize-DriverAndExtension {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
        [Parameter(Mandatory = $true)] [OpenStackConfig] $OpenStackConfig,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig
    )

    Write-Host "Initializing Test Configuration"

    $NRetries = 3;
    foreach ($i in 1..$NRetries) {
        # DockerDriver automatically enables Extension, so there is no need to enable it manually

        Start-DockerDriver -Session $Session `
            -AdapterName $SystemConfig.AdapterName `
            -OpenStackConfig $OpenStackConfig `
            -ControllerConfig $ControllerConfig `
            -WaitTime 0

        try {
            $TestProcessRunning = { Test-IsDockerDriverProcessRunning -Session $Session }

            $TestProcessRunning | Invoke-UntilSucceeds -Duration 15

            {
                Test-IsDockerDriverEnabled -Session $Session
            } | Invoke-UntilSucceeds -Duration 600 -Interval 5 -Precondition $TestProcessRunning

            Wait-RemoteInterfaceIP -Session $Session -AdapterName $SystemConfig.VHostName

            break
        }
        catch {
            Write-Host $_

            if ($i -eq $NRetries) {
                throw "Docker driver was not enabled."
            } else {
                Write-Host "Docker driver was not enabled, retrying."
                Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
            }
        }
    }
}

function Clear-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig)

    Write-Host "Cleaning up test configuration"

    Remove-AllUnusedDockerNetworks -Session $Session
    Disable-AgentService -Session $Session
    Stop-DockerDriver -Session $Session
    Disable-VRouterExtension -Session $Session -SystemConfig $SystemConfig
}

function New-AgentConfigFile {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig,
        [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig
    )

    # Gather information about testbed's network adapters
    $HNSTransparentAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $SystemConfig.VHostName

    $PhysicalAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $SystemConfig.AdapterName

    # Prepare parameters for script block
    $ControllerIP = $ControllerConfig.Address
    $VHostIfName = $HNSTransparentAdapter.ifName
    $VHostIfIndex = $HNSTransparentAdapter.ifIndex
    $PhysIfName = $PhysicalAdapter.ifName

    $AgentConfigFilePath = $SystemConfig.AgentConfigFilePath

    Invoke-Command -Session $Session -ScriptBlock {
        $ControllerIP = $Using:ControllerIP
        $VHostIfName = $Using:VHostIfName
        $VHostIfIndex = $Using:VHostIfIndex
        $PhysIfName = $Using:PhysIfName

        $VHostIP = (Get-NetIPAddress -ifIndex $VHostIfIndex -AddressFamily IPv4).IPAddress

        $ConfigFileContent = @"
[DEFAULT]
platform=windows

[CONTROL-NODE]
servers=$ControllerIP

[DISCOVERY]
servers=$ControllerIP

[VIRTUAL-HOST-INTERFACE]
name=$VHostIfName
ip=$VHostIP/24
physical_interface=$PhysIfName
"@

        # Save file with prepared config
        [System.IO.File]::WriteAllText($Using:AgentConfigFilePath, $ConfigFileContent)
    }
}

function Initialize-ComputeServices {
        Param (
            [Parameter(Mandatory = $true)] [PSSessionT] $Session,
            [Parameter(Mandatory = $true)] [SystemConfig] $SystemConfig,
            [Parameter(Mandatory = $true)] [OpenStackConfig] $OpenStackConfig,
            [Parameter(Mandatory = $true)] [ControllerConfig] $ControllerConfig
        )

        Initialize-DriverAndExtension -Session $Session `
            -SystemConfig $SystemConfig `
            -OpenStackConfig $OpenStackConfig `
            -ControllerConfig $ControllerConfig

        New-AgentConfigFile -Session $Session `
            -ControllerConfig $ControllerConfig `
            -SystemConfig $SystemConfig

        Enable-AgentService -Session $Session
}

function Remove-DockerNetwork {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $Name
    )

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

function Remove-AllContainers {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Invoke-Command -Session $Session -ScriptBlock {
        $Containers = docker ps -q
        if($Containers) {
            docker rm -f $Containers | Out-Null
        }
        Remove-Variable "Containers"
    }
}

