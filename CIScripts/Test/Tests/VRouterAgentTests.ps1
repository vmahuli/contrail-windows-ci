$Accel = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$Accel::add("PSSessionT", "System.Management.Automation.Runspaces.PSSession")

function Test-VRouterAgentIntegration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session1,
           [Parameter(Mandatory = $true)] [PSSessionT] $Session2,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\..\Utils\CommonTestCode.ps1
    . $PSScriptRoot\..\Utils\ContrailUtils.ps1

    $MAX_WAIT_TIME_FOR_AGENT_PROCESS_IN_SECONDS = 60
    $TIME_BETWEEN_AGENT_PROCESS_CHECKS_IN_SECONDS = 5
    $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS = 15
    $WAIT_TIME_FOR_FLOW_TABLE_UPDATE_IN_SECONDS = 5

    $TEST_NETWORK_GATEWAY = "10.7.3.1"

    $AGENT_INSPECTOR_PROTO = "http"
    $AGENT_INSPECTOR_PORT = 8085
    $AGENT_ITF_REQ_PATH = "Snh_ItfReq"
    $AGENT_ARP_REQ_PATH = "Snh_NhListReq?type=arp"

    #
    # Private functions of Test-VRouterAgentIntegration
    #

    function Get-TestbedIpAddressFromDns {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        $testbedHostname = $Session.ComputerName
        $dnsEntries = Resolve-DnsName -Name $testbedHostname -Type A -ErrorVariable dnsError
        if ($dnsError) {
            Throw "Resolving testbed's IP address failed"
        }

        $dnsEntry = $dnsEntries | Where-Object IPAddress -Match "^10.7.0"
        if ($dnsEntry.Count -ne 1) {
            Throw "Expected testbed ${testbedHostname} to have only one IP address"
        }

        return $dnsEntry[0].IPAddress
    }

    function Out-AgentInspectorUri {
        Param ([Parameter(Mandatory = $true)] [string] $IpAddress)

        return "${AGENT_INSPECTOR_PROTO}://${IpAddress}:${AGENT_INSPECTOR_PORT}"
    }

    function Out-AgentInterfaceRequestUri {
        Param ([Parameter(Mandatory = $true)] [string] $IpAddress)

        return "$(Out-AgentInspectorUri $IpAddress)/${AGENT_ITF_REQ_PATH}"
    }

    function Out-AgentArpRequestUri {
        Param ([Parameter(Mandatory = $true)] [string] $IpAddress)

        return "$(Out-AgentInspectorUri $IpAddress)/${AGENT_ARP_REQ_PATH}"
    }

    function Get-PktInterfaceIndexFromAgent {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        $testbedIpAddress = Get-TestbedIpAddressFromDns -Session $Session
        $uri = Out-AgentInterfaceRequestUri -IpAddress $testbedIpAddress

        # Invoke-RestMethod and Select-XML throw exceptions on error
        $output = Invoke-RestMethod $uri
        $indexNode = $output | Select-XML -XPath "//ItfSandeshData//index[..//type//text() = 'pkt']//text()"
        if (!$indexNode) {
            Throw "No pkt interface in Agent. EXPECTED: pkt interface in Agent"
        }
        $indexValue = [int]$indexNode.Node.Value;

        return $indexValue;
    }

    function Assert-ExtensionIsRunning {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $isEnabled = Test-IsVRouterExtensionEnabled `
            -Session $Session `
            -VMSwitchName $TestConfiguration.VMSwitchName `
            -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        if (!$isEnabled) {
            throw "Hyper-V Extension is not running. EXPECTED: Hyper-V Extension is running"
        }
    }

    function Assert-NoVifs {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        if ($vifOutput -Match "vif") {
            throw "There are vifs registered in vRouter. EXPECTED: no vifs in vRouter"
        }
    }

    function Assert-IsPkt0Injected {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        $match = $($vifOutput -Match "Type:Agent")
        if (!$match) {
            throw "pkt0 interface is not injected. EXPECTED: pkt0 injected in vRouter"
        }
    }

    function Assert-IsOnlyOnePkt0Injected {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        $match = $($vifOutput -Match "Type:Agent")
        if (!$match) {
            throw "pkt0 interface is not injected. EXPECTED: pkt0 injected in vRouter"
        }
        if ($match.Count > 1) {
            throw "more than 1 pkt0 interfaces were injected. EXPECTED: only one pkt0 interface in vRouter"
        }
    }

    function Assert-IsGatewayArpResolvedInAgent {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        $testbedIpAddress = Get-TestbedIpAddressFromDns -Session $Session
        $uri = Out-AgentArpRequestUri -IpAddress $testbedIpAddress

        $xpath = "//NhSandeshData//valid[..//sip//text() = '${TEST_NETWORK_GATEWAY}']//text()"
        $output = Invoke-RestMethod $uri
        $gateway = $output | Select-Xml -XPath $xpath
        if (!$gateway) {
            throw "Agent does not expect ARP from gateway, please check Agent config"
        }
        $resolveStatus = $gateway.Node.Value
        if ($resolveStatus -ne "true") {
            throw "ARP to gateway was not resolved. EXPECTED: ARP to gateway resolved by the Agent"
        }
    }

    function Assert-Pkt0HasTraffic {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        Assert-IsPkt0Injected -Session $Session

        $pktIfIndex = Get-PktInterfaceIndexFromAgent -Session $Session
        $vifOutput = Invoke-Command -Session $Session -ScriptBlock {
            vif.exe --get $Using:pktIfIndex
        }

        $rxPacketsMatch = [regex]::Match($vifOutput, "RX packets:(\d+)")
        if (!$rxPacketsMatch.Success) {
            throw "RX packets metric not visible in vif output. EXPECTED: RX packets visible"
        }
        $rxPackets = [int]$rxPacketsMatch.groups[1].Value
        if ($rxPackets -eq 0) {
            throw "Registered RX packets equal to zero. EXPECTED: Registered RX packets greater than zero"
        }

        $txPacketsMatch = [regex]::Match($vifOutput, "TX packets:(\d+)")
        if (!$txPacketsMatch.Success) {
            throw "TX packets metric not visible in vif output. EXPECTED: TX packets visible"
        }
        $txPackets = [int]$txPacketsMatch.groups[1].Value
        if ($txPackets -eq 0) {
            throw "Registered TX packets equal to zero. EXPECTED: Registered TX packets greater than zero"
        }
    }

    function Assert-FlowReturnedSomeFlows {
        Param ([Parameter(Mandatory = $true)] [Object[]] $Output)
        $ErrorMessage = "There are no flows. EXPECTED: Some flow(s) exist."
        Foreach ($Line in $Output) {
            if ($Line -match "Entries: Created (?<NumOfFlowsCreated>[\d]+) Added (?<NumOfFlowsAdded>[\d]+)[.]*") {
                if ($matches.NumOfFlowsCreated -gt 0 -or $matches.NumOfFlowsAdded -gt 0) {
                    return
                } else {
                    Write-Host "Flow output: $Output"
                    throw $ErrorMessage
                }
            }
        }
        Write-Host "Flow output: $Output"
        throw $ErrorMessage
    }

    function Create-ContainerInRemoteSession {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [string] $NetworkName,
               [Parameter(Mandatory = $true)] [string] $ContainerName,
               [Parameter(Mandatory = $false)] [string] $DockerImage)
        if (!$DockerImage) {
            $DockerImage = "microsoft/nanoserver"
        }

        Write-Host "Creating container: name = $ContainerName; network = $NetworkName; image = $DockerImage."

        $Output = Invoke-Command -Session $Session -ScriptBlock {
            $DockerOutput = (& docker run -id --name $Using:ContainerName --network $Using:NetworkName $Using:DockerImage powershell 2>&1) | Out-String
            $LASTEXITCODE
            $DockerOutput
        }
        $ExitCode = $Output[0]
        $Message = $Output[1]
        if ($ExitCode -ne 0) {
            Write-Host "    Exit code: $ExitCode"
            Write-Host "    Docker output: $Message"
        }
        return $ExitCode
    }

    function Remove-ContainerInRemoteSession {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [string] $ContainerName)
        $ExitCode = Invoke-Command -Session $Session -ScriptBlock {
            & docker rm --force $Using:ContainerName | Out-Null
            $LASTEXITCODE
        }
        return $ExitCode
    }

    function Assert-PingSucceeded {
        Param ([Parameter(Mandatory = $true)] [Object[]] $Output)
        $ErrorMessage = "Ping failed. EXPECTED: Ping succeeded."
        Foreach ($Line in $Output) {
            if ($Line -match ", Received = (?<NumOfReceivedPackets>[\d]+),[.]*") {
                if ($matches.NumOfReceivedPackets -gt 0) {
                    return
                } else {
                    throw $ErrorMessage
                }
            }
        }
        throw $ErrorMessage
    }

    function Ping-Container {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [string] $ContainerName,
               [Parameter(Mandatory = $true)] [string] $IP)
        $PingOutput = Invoke-Command -Session $Session -ScriptBlock {
            & docker exec $Using:ContainerName ping $Using:IP -n 10 -w 500
        }
        Assert-PingSucceeded -Output $PingOutput
    }

    function Send-UDPPacket {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [string] $ContainerName,
               [Parameter(Mandatory = $true)] [string] $IP,
               [Parameter(Mandatory = $false)] [string] $Port,
               [Parameter(Mandatory = $false)] [string] $Message)
        if (!$Port) {
            $Port = "1337"
        }

        if (!$Message) {
            $Message = "Is anyone there!?"
        }

        $Command = (`
            '$IpAddress = [System.Net.IPAddress]::Parse(\"{0}\");' +`
            '$IpEndPoint = New-Object System.Net.IPEndPoint($IpAddress, {1});' +`
            '$UdpClient = New-Object System.Net.Sockets.UdpClient;' +`
            '$Data = [System.Text.Encoding]::UTF8.GetBytes(\"{2}\");' +`
            'Foreach ($num in 1..10) {{$UdpClient.SendAsync($Data, $Data.length, $IpEndPoint); Start-Sleep -Seconds 1}}') -f $IP, $Port, $Message
        Invoke-Command -Session $Session -ScriptBlock {
            & docker exec $Using:ContainerName powershell -Command $Using:Command | Out-Null
        }
    }

    function Test-Ping {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session1,
               [Parameter(Mandatory = $true)] [PSSessionT] $Session2,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $Container1Name,
               [Parameter(Mandatory = $true)] [string] $Container2Name)
        Write-Host "======> Given Docker Driver and Extension are running"

        # 1st compute node
        Clear-TestConfiguration -Session $Session1 -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session1 -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session1 -TestConfiguration $TestConfiguration

        # 2nd compute node (if there actually is more than 1 compute node)
        if ($Session1 -ne $Session2) {
            Clear-TestConfiguration -Session $Session2 -TestConfiguration $TestConfiguration
            Initialize-TestConfiguration -Session $Session2 -TestConfiguration $TestConfiguration
            Assert-ExtensionIsRunning -Session $Session2 -TestConfiguration $TestConfiguration
        }

        Write-Host "======> Given Agent is running"

        # 1st compute node
        New-AgentConfigFile -Session $Session1 -TestConfiguration $TestConfiguration
        Enable-AgentService -Session $Session1
        Assert-IsAgentServiceEnabled -Session $Session1

        # 2nd compute node (if there actually is more than 1 compute node)
        if ($Session1 -ne $Session2) {
           New-AgentConfigFile -Session $Session2 -TestConfiguration $TestConfiguration
           Enable-AgentService -Session $Session2
           Assert-IsAgentServiceEnabled -Session $Session2
        }

        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

        Write-Host "======> When 2 containers belonging to the same network are running"
        $NetworkName = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.DefaultNetworkName

        $CreateContainer1Success = Create-ContainerInRemoteSession `
            -Session $Session1 `
            -NetworkName $NetworkName `
            -ContainerName $Container1Name
        $CreateContainer2Success = Create-ContainerInRemoteSession `
            -Session $Session2 `
            -NetworkName $NetworkName `
            -ContainerName $Container2Name

        if ($CreateContainer1Success -ne 0 -or $CreateContainer2Success -ne 0) {
            throw "Container creation failed. EXPECTED: succeeded."
        }
        $Container2IP = Invoke-Command -Session $Session2 -ScriptBlock {
            & docker exec $Using:Container2Name powershell -Command "(Get-NetAdapter | Select-Object -First 1 | Get-NetIPAddress).IPv4Address"
        }

        Write-Host "======> Then ping between them succeeds"
        Write-Host "$Container1Name is going to ping $Container2Name (IP: $Container2IP)."
        Ping-Container -Session $Session1 -ContainerName $Container1Name -IP $Container2IP

        Write-Host "Removing containers: $Container1Name and $Container2Name."
        Invoke-Command -Session $Session1 -ScriptBlock {
            & docker rm --force $Using:Container1Name | Out-Null
        }

        Invoke-Command -Session $Session2 -ScriptBlock {
            & docker rm --force $Using:Container2Name | Out-Null
        }
    }

    function Initialize-ComputeNodeForFlowTests {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration
        New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration `
            -Name $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Name `
            -Network $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Name `
            -Subnet $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Subnets[0]
        New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration `
            -Name $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Name `
            -Network $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Name `
            -Subnet $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Subnets[0]
        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS
    }

    function Initialize-ComputeNodeForMultihostUDPTests {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [NetworkConfiguration] $NetworkConfiguration)

        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration
        New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration `
            -Name $NetworkConfiguration.Name `
            -Network $NetworkConfiguration.Name `
            -Subnet $NetworkConfiguration.Subnets[0]
    }

    #
    # Tests definitions
    #

    function Test-InitialPkt0Injection {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-InitialPkt0Injection"

            Write-Host "======> Given Extension is running"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

            New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given clean vRouter"
            Assert-NoVifs -Session $Session

            Write-Host "======> When Agent is started"
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> Then pkt0 appears in vRouter"
            Assert-IsPkt0Injected -Session $Session

            Write-Host "===> PASSED: Test-InitialPkt0Injection"
        })
    }

    function Test-Pkt0RemainsInjectedAfterAgentStops {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-Pkt0RemainsInjectedAfterAgentStops"

            Write-Host "======> Given Extension is running"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

            New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given Agent is running"
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> Given pkt0 is injected"
            Assert-IsPkt0Injected -Session $Session

            Write-Host "======> When Agent is stopped"
            Disable-AgentService -Session $Session
            Assert-IsAgentServiceDisabled -Session $Session

            Write-Host "======> Then pk0 exists in vRouter"
            Assert-IsPkt0Injected -Session $Session

            Write-Host "===> PASSED: Test-Pkt0RemainsInjectedAfterAgentStops"
        })
    }

    function Test-OnePkt0ExistsAfterAgentIsRestarted {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-OnePkt0ExistsAfterAgentIsRestarted"

            Write-Host "======> Given Extension is running"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

            New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given Agent is running"
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> Given pkt0 is injected"
            Assert-IsPkt0Injected -Session $Session

            Write-Host "======> When Agent is Restarted"
            Disable-AgentService -Session $Session
            Assert-IsAgentServiceDisabled -Session $Session
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> Then pkt0 exists in vRouter"
            Assert-IsOnlyOnePkt0Injected -Session $Session
        })
    }

    function Test-Pkt0ReceivesTrafficAfterAgentIsStarted {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"

            Write-Host "======> Given Extension is running"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> When Agent is started"
            New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS  # Wait for KSync

            Write-Host "======> Then Pkt0 has traffic"
            Assert-Pkt0HasTraffic -Session $Session

            Write-Host "===> PASSED: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"
        })
    }

    function Test-GatewayArpIsResolvedInAgent {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"

            Write-Host "======> Given Extension is running"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> When Agent is started"
            New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS  # Wait for KSync

            Write-Host "======> Then Gateway ARP was resolved through Pkt0"
            Assert-IsGatewayArpResolvedInAgent -Session $Session

            Write-Host "===> PASSED: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"
        })
    }

    function Test-SingleComputeNodePing {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleComputeNodePing"
            Test-Ping -Session1 $Session -Session2 $Session -TestConfiguration $TestConfiguration -Container1Name "container1" -Container2Name "container2"
            Write-Host "===> PASSED: Test-SingleComputeNodePing"
        })
    }

    function Get-VrfStats {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        $VrfStats = Invoke-Command -Session $Session -ScriptBlock {
            $vrfstatsOutput = $(vrfstats --get 1)
            $mplsUdpPktCount = [regex]::new("Udp Mpls Tunnels ([0-9]+)").Match($vrfstatsOutput[3]).Groups[1].Value
            $mplsGrePktCount = [regex]::new("Gre Mpls Tunnels ([0-9]+)").Match($vrfstatsOutput[3]).Groups[1].Value
            $vxlanPktCount = [regex]::new("Vxlan Tunnels ([0-9]+)").Match($vrfstatsOutput[3]).Groups[1].Value
            return @{
                MplsUdpPktCount = $mplsUdpPktCount
                MplsGrePktCount = $mplsGrePktCount
                VxlanPktCount = $vxlanPktCount
            }
        }
        return $VrfStats
    }

    function Test-ICMPoMPLSoGRE {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session1,
               [Parameter(Mandatory = $true)] [PSSessionT] $Session2,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ICMPoMPLSoGRE"

            Write-Host "======> Given Controller with default (MPLSoGRE) configuration"
            Test-Ping -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfiguration -Container1Name "container1" -Container2Name "container2"

            Write-Host "======> Then GRE tunnel is used"
            $VrfStats = Get-VrfStats -Session $Session1
            if ($VrfStats.MplsGrePktCount -eq 0 -or $VrfStats.MplsUdpPktCount -ne 0 -or $VrfStats.VxlanPktCount -ne 0) {
                throw "Containers pinged themselves correctly but used the wrong type of tunnel (VrfStats: Udp = {0}, Gre = {1}, Vxlan = {2})" `
                    -f $VrfStats.MplsUdpPktCount, $VrfStats.MplsGrePktCount, $VrfStats.VxlanPktCount
            }

            Write-Host "===> PASSED: Test-ICMPoMPLSoGRE"
        })
    }

    function Test-ICMPoMPLSoUDP {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session1,
               [Parameter(Mandatory = $true)] [PSSessionT] $Session2,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ICMPoMPLSoUDP"

            Write-Host "======> Given Controller with MPLSoUPD configuration"
            $TestConfigurationTemp = $TestConfiguration.ShallowCopy()
            $TestConfigurationTemp.DockerDriverConfiguration = $TestConfiguration.DockerDriverConfiguration.ShallowCopy()
            $TestConfigurationTemp.ControllerIP = $Env:CONTROLLER_IP_UDP
            $TestConfigurationTemp.DockerDriverConfiguration.AuthUrl = $Env:DOCKER_DRIVER_AUTH_URL_UDP

            $ContrailUrl = $TestConfigurationTemp.ControllerIP + ":" + $TestConfigurationTemp.ControllerRestPort
            $ContrailCredentials = $TestConfigurationTemp.DockerDriverConfiguration
            $AuthToken = Get-AccessTokenFromKeystone -AuthUrl $ContrailCredentials.AuthUrl -TenantName $ContrailCredentials.TenantConfiguration.Name `
                -Username $ContrailCredentials.Username -Password $ContrailCredentials.Password
            $RouterIp1 = Invoke-Command -Session $Session1 -ScriptBlock {
                return $((Get-NetIPAddress -InterfaceAlias $Using:TestConfigurationTemp.VHostName -AddressFamily IPv4).IpAddress)
            }
            $RouterIp2 = Invoke-Command -Session $Session2 -ScriptBlock {
                return $((Get-NetIPAddress -InterfaceAlias $Using:TestConfigurationTemp.VHostName -AddressFamily IPv4).IpAddress)
            }
            $RouterUuid1 = Add-ContrailVirtualRouter -ContrailUrl $ContrailUrl -AuthToken $AuthToken -RouterName $Session1.ComputerName -RouterIp RouterIp1
            $RouterUuid2 = Add-ContrailVirtualRouter -ContrailUrl $ContrailUrl -AuthToken $AuthToken -RouterName $Session2.ComputerName -RouterIp RouterIp2

            Try {
                Test-Ping -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfigurationTemp -Container1Name "container1" -Container2Name "container2"
            } Finally {
                Remove-ContrailVirtualRouter -ContrailUrl $ContrailUrl -AuthToken $AuthToken -RouterUuid $RouterUuid1
                Remove-ContrailVirtualRouter -ContrailUrl $ContrailUrl -AuthToken $AuthToken -RouterUuid $RouterUuid2
            }
            Write-Host "======> Then UDP tunnel is used"
            $VrfStats = Get-VrfStats -Session $Session1
            if ($VrfStats.MplsUdpPktCount -eq 0 -or $VrfStats.MplsGrePktCount -ne 0 -or $VrfStats.VxlanPktCount -ne 0) {
                throw "Containers pinged themselves correctly but used the wrong type of tunnel (VrfStats: Udp = {0}, Gre = {1}, Vxlan = {2})" `
                    -f $VrfStats.MplsUdpPktCount, $VrfStats.MplsGrePktCount, $VrfStats.VxlanPktCount
            }

            Write-Host "===> PASSED: Test-ICMPoMPLSoUDP"
        })
    }

    function Test-FlowsAreInjectedOnIcmpTraffic {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session1,
               [Parameter(Mandatory = $true)] [PSSessionT] $Session2,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-FlowsAreInjectedOnIcmpTraffic"

            Write-Host "======> Given: Contrail compute services are started"
            Clear-TestConfiguration -Session $Session1 -TestConfiguration $TestConfiguration
            Initialize-ComputeServices -Session $Session1 -TestConfiguration $TestConfiguration
            Clear-TestConfiguration -Session $Session2 -TestConfiguration $TestConfiguration
            Initialize-ComputeServices -Session $Session2 -TestConfiguration $TestConfiguration
            New-DockerNetwork -Session $Session1 -TestConfiguration $TestConfiguration `
                -Name $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Name `
                -Network $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Name `
                -Subnet $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Subnets[0]
            New-DockerNetwork -Session $Session2 -TestConfiguration $TestConfiguration `
                -Name $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Name `
                -Network $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Name `
                -Subnet $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Subnets[0]
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> When 2 containers belonging to different networks are running"
            $Network1Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Name
            $Network2Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Name
            $Container1Name = "jolly-lumberjack"
            $Container2Name = "juniper-tree"

            $CreateContainer1Success = Create-ContainerInRemoteSession `
                -Session $Session1 `
                -NetworkName $Network1Name `
                -ContainerName $Container1Name
            $CreateContainer2Success = Create-ContainerInRemoteSession `
                -Session $Session2 `
                -NetworkName $Network2Name `
                -ContainerName $Container2Name

            if ($CreateContainer1Success -ne 0 -or $CreateContainer2Success -ne 0) {
                throw "Container creation failed. EXPECTED: succeeded."
            }

            $Container2IP = Invoke-Command -Session $Session2 -ScriptBlock {
                & docker exec $Using:Container2Name powershell -Command "(Get-NetAdapter | Select-Object -First 1 | Get-NetIPAddress).IPv4Address"
            }

            Write-Host "======> When: Container $Container1Name (network: $Network1Name)"
            Write-Host "        pings container $Container2Name (network: $Network2Name, IP: $Container2IP)"
            Ping-Container -Session $Session1 -ContainerName $Container1Name -IP $Container2IP

            Write-Host "======> Then: Flow should be created for ICMP protocol"
            $FlowOutput = Invoke-Command -Session $Session1 -ScriptBlock {
                & flow -l --match "proto icmp"
            }
            Write-Host "Flow output: $FlowOutput"
            Assert-FlowReturnedSomeFlows -Output $FlowOutput
            Write-Host "        Successfully created."

            Write-Host "Removing containers: $Container1Name and $Container2Name."
            Remove-ContainerInRemoteSession -Session $Session1 -ContainerName $Container1Name | Out-Null
            Remove-ContainerInRemoteSession -Session $Session2 -ContainerName $Container2Name | Out-Null

            Write-Host "===> PASSED: Test-FlowsAreInjectedOnIcmpTraffic"
        })
    }

    function Test-FlowsAreInjectedOnTcpTraffic {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-FlowsAreInjectedOnTcpTraffic"

            Write-Host "======> Given: Contrail compute services are started"
            Initialize-ComputeNodeForFlowTests -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> When 2 containers belonging to different networks are running"
            $Network1Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Name
            $Network2Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Name
            $Container1Name = "jolly-lumberjack"
            $Container2Name = "juniper-tree"

            $CreateContainer1Success = Create-ContainerInRemoteSession `
                -Session $Session `
                -NetworkName $Network1Name `
                -ContainerName $Container1Name
            $CreateContainer2Success = Create-ContainerInRemoteSession `
                -Session $Session `
                -NetworkName $Network2Name `
                -ContainerName $Container2Name

            if ($CreateContainer1Success -ne 0 -or $CreateContainer2Success -ne 0) {
                throw "Container creation failed. EXPECTED: succeeded."
            }

            $Container2IP = Invoke-Command -Session $Session -ScriptBlock {
                & docker exec $Using:Container2Name powershell -Command "(Get-NetAdapter | Select-Object -First 1 | Get-NetIPAddress).IPv4Address"
            }

            Write-Host "======> When: Container $Container1Name (network: $Network1Name) is trying to"
            Write-Host "        open TCP connection to $Container2Name (network: $Network2Name, IP: $Container2IP)"
            Write-Host

            $Port = "1905"
            $Message = "Even diamonds require polishing."

            Write-Host "        Setting up TCP sender and listener on containers..."

            $ReceivedMessage = Invoke-Command -Session $Session -ScriptBlock {
                $Port = $Using:Port
                $Container1Name = $Using:Container1Name
                $Container2Name = $Using:Container2Name
                $Container2IP = $Using:Container2IP
                $Message = $Using:Message

                $JobListener = Start-Job -ScriptBlock {
                    $Command = (`
                        '$ErrorActionPreference = \"SilentlyContinue\";' +`
                        '$Server = New-Object System.Net.Sockets.TcpListener({0});' +`
                        '$Server.Start();' +`
                        '$Socket = $Server.AcceptTcpClient();' +`
                        '$StreamReader = New-Object System.IO.StreamReader($Socket.GetStream());' +`
                        '$Input = $StreamReader.ReadLine();' +`
                        'return $Input;') -f $Using:Port

                    $Output = & docker exec $Using:Container2Name powershell -Command $Command
                    return $Output
                }

                Start-Sleep -Seconds 2

                $JobSender = Start-Job -ScriptBlock {
                    $Command = (`
                        '$ErrorActionPreference = \"SilentlyContinue\";' +`
                        '$IpAddress = [System.Net.IPAddress]::Parse(\"{0}\");' +`
                        '$TcpClient = New-Object System.Net.Sockets.TcpClient;' +`
                        '$TaskConnect = $TcpClient.ConnectAsync($IpAddress, {1});' +`
                        '$TaskConnect.Wait(2000);' +`
                        '$StreamWriter = New-Object System.IO.StreamWriter($TcpClient.GetStream());' +`
                        '$StreamWriter.WriteLine(\"{2}\");' +`
                        '$StreamWriter.Flush();') -f $Using:Container2IP, $Using:Port, $Using:Message

                    & docker exec $Using:Container1Name powershell -Command $Command
                }

                $JobSender | Wait-Job -Timeout 5 | Out-Null
                $JobListener | Wait-Job -Timeout 5 | Out-Null
                $ReceivedMessage = $JobListener | Receive-Job
                return $ReceivedMessage
            }

            # TODO: Enable this test once it is actually expected to pass.
            # .NET in microsoft/nanoserver docker image doesn't have TCPServer
            #Write-Host "        Sent message: $Message"
            #Write-Host "        Received message: $ReceivedMessage"

            #if ($Message -ne $ReceivedMessage) {
            #    throw "Sent and received messages do not match."
            #} else {
            #    Write-Host "        Match!"
            #}

            Start-Sleep -Seconds $WAIT_TIME_FOR_FLOW_TABLE_UPDATE_IN_SECONDS

            Write-Host "======> Then: Flow should be created for TCP protocol"
            $FlowOutput = Invoke-Command -Session $Session -ScriptBlock {
                & flow -l --match "proto tcp"
            }
            Write-Host "Flow output: $FlowOutput"
            Assert-FlowReturnedSomeFlows -Output $FlowOutput
            Write-Host "        Successfully created."

            Write-Host "Removing containers: $Container1Name and $Container2Name."
            Remove-ContainerInRemoteSession -Session $Session -ContainerName $Container1Name | Out-Null
            Remove-ContainerInRemoteSession -Session $Session -ContainerName $Container2Name | Out-Null

            Write-Host "===> PASSED: Test-FlowsAreInjectedOnTcpTraffic"
        })
    }

    function Test-FlowsAreInjectedOnUdpTraffic {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-FlowsAreInjectedOnUdpTraffic"

            Write-Host "======> Given: Contrail compute services are started"
            Initialize-ComputeNodeForFlowTests -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> When 2 containers belonging to different networks are running"
            $Network1Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1.Name
            $Network2Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy2.Name
            $Container1Name = "jolly-lumberjack"
            $Container2Name = "juniper-tree"

            $CreateContainer1Success = Create-ContainerInRemoteSession `
                -Session $Session `
                -NetworkName $Network1Name `
                -ContainerName $Container1Name
            $CreateContainer2Success = Create-ContainerInRemoteSession `
                -Session $Session `
                -NetworkName $Network2Name `
                -ContainerName $Container2Name

            if ($CreateContainer1Success -ne 0 -or $CreateContainer2Success -ne 0) {
                throw "Container creation failed. EXPECTED: succeeded."
            }

            $Container2IP = Invoke-Command -Session $Session -ScriptBlock {
                & docker exec $Using:Container2Name powershell -Command "(Get-NetAdapter | Select-Object -First 1 | Get-NetIPAddress).IPv4Address"
            }

            Write-Host "======> When: Container $Container1Name (network: $Network1Name) is sending UDP"
            Write-Host "        packets to container $Container2Name (network: $Network2Name, IP: $Container2IP)"
            Send-UDPPacket -Session $Session -ContainerName $Container1Name -IP $Container2IP
            Start-Sleep -Seconds $WAIT_TIME_FOR_FLOW_TABLE_UPDATE_IN_SECONDS

            Write-Host "======> Then: Flow should be created for UDP protocol"
            $FlowOutput = Invoke-Command -Session $Session -ScriptBlock {
                & flow -l --match "proto udp"
            }
            Assert-FlowReturnedSomeFlows -Output $FlowOutput
            Write-Host "        Successfully created."
            Write-Host "Flow output: $FlowOutput"

            Write-Host "Removing containers: $Container1Name and $Container2Name."
            Remove-ContainerInRemoteSession -Session $Session -ContainerName $Container1Name | Out-Null
            Remove-ContainerInRemoteSession -Session $Session -ContainerName $Container2Name | Out-Null

            Write-Host "===> PASSED: Test-FlowsAreInjectedOnUdpTraffic"
        })
    }

    function Test-MultihostUdpTraffic {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session1,
               [Parameter(Mandatory = $true)] [PSSessionT] $Session2,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-MultihostUdpTraffic"

            Write-Host "======> Given: Contrail compute services are started on two compute nodes"
            Initialize-ComputeNodeForMultihostUDPTests `
                -Session $Session1 `
                -TestConfiguration $TestConfiguration `
                -NetworkConfiguration $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1
            Initialize-ComputeNodeForMultihostUDPTests `
                -Session $Session2 `
                -TestConfiguration $TestConfiguration `
                -NetworkConfiguration $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.NetworkWithPolicy1
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> When 2 containers belonging to different networks are running"
            # TODO: Two separate networks with policies should eventually be used instead of
            # one network without a policy.
            $Network1Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.DefaultNetworkName
            $Network2Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.DefaultNetworkName

            $Container1Name = "jolly-lumberjack"
            $Container2Name = "juniper-tree"

            $CreateContainer1Success = Create-ContainerInRemoteSession `
                -Session $Session1 `
                -NetworkName $Network1Name `
                -ContainerName $Container1Name `
                -DockerImage "microsoft/windowsservercore"
            $CreateContainer2Success = Create-ContainerInRemoteSession `
                -Session $Session2 `
                -NetworkName $Network2Name `
                -ContainerName $Container2Name `
                -DockerImage "microsoft/windowsservercore"

            if ($CreateContainer1Success -ne 0 -or $CreateContainer2Success -ne 0) {
                throw "Container creation failed. EXPECTED: succeeded."
            }

            $Container2IP = Invoke-Command -Session $Session2 -ScriptBlock {
                & docker exec $Using:Container2Name powershell -Command "(Get-NetAdapter | Select-Object -First 1 | Get-NetIPAddress).IPv4Address"
            }

            Write-Host "======> When: Container $Container1Name (network: $Network1Name) is sending UDP"
            Write-Host "        packets to container $Container2Name (network: $Network2Name, IP: $Container2IP)"

            $Port = "1905"
            $Message = "Even diamonds require polishing."

            Write-Host "    Setting up a listener on container $Container2Name..."
            $JobListener = Invoke-Command -Session $Session2 -AsJob -ScriptBlock {
                $Command = (`
                    '$IpEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, {0});' +`
                    '$UdpClient = New-Object System.Net.Sockets.UdpClient {0};' +`
                    '$Task = $UdpClient.ReceiveAsync();' +`
                    '$Task.Wait();' +`
                    '$ReceivedMessage = [System.Text.Encoding]::UTF8.GetString($Task.Result.Buffer);' +`
                    'return $ReceivedMessage;') -f $Using:Port
    
                & docker exec $Using:Container2Name powershell -Command $Command
            }

            Start-Sleep -Seconds 8
            Write-Host "    Sending a message from container $Container1Name..."
            Send-UDPPacket -Session $Session1 -ContainerName $Container1Name -IP $Container2IP -Port $Port -Message $Message
            $JobListener | Wait-Job -Timeout 20 | Out-Null
            $JobListener | Stop-Job | Out-Null
            $ReceivedMessage = $JobListener | Receive-Job
            $ReceivedMessage

            Start-Sleep -Seconds $WAIT_TIME_FOR_FLOW_TABLE_UPDATE_IN_SECONDS
            Write-Host "======> Then: Flow should be created for UDP protocol on the compute node of $Container1Name"
            Write-Host "        and container $Container2Name should receive the message."
            $FlowOutput = Invoke-Command -Session $Session1 -ScriptBlock {
                & flow -l --match "proto udp"
            }
            # TODO: Flows should be checked once networks with policies are used.
            # Assert-FlowReturnedSomeFlows -Output $FlowOutput
            # Write-Host "        Flow successfully created."

            Write-Host "        Message sent: $Message"
            Write-Host "        Message received: $ReceivedMessage"

            if ($Message -ne $ReceivedMessage) {
                throw "Sent and received messages do not match!"
            } else {
                Write-Host "        Match!"
            }

            Write-Host "Removing containers: $Container1Name and $Container2Name."
            Remove-ContainerInRemoteSession -Session $Session1 -ContainerName $Container1Name | Out-Null
            Remove-ContainerInRemoteSession -Session $Session2 -ContainerName $Container2Name | Out-Null

            Write-Host "===> PASSED: Test-MultihostUdpTraffic"
        })
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        Test-InitialPkt0Injection -Session $Session1 -TestConfiguration $TestConfiguration
        Test-Pkt0RemainsInjectedAfterAgentStops -Session $Session1 -TestConfiguration $TestConfiguration
        Test-OnePkt0ExistsAfterAgentIsRestarted -Session $Session1 -TestConfiguration $TestConfiguration
        Test-Pkt0ReceivesTrafficAfterAgentIsStarted -Session $Session1 -TestConfiguration $TestConfiguration
        Test-GatewayArpIsResolvedInAgent -Session $Session1 -TestConfiguration $TestConfiguration
        Test-SingleComputeNodePing -Session $Session1 -TestConfiguration $TestConfiguration
        Test-ICMPoMPLSoGRE -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfiguration
        Test-ICMPoMPLSoUDP -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfiguration
        Test-FlowsAreInjectedOnIcmpTraffic -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfiguration
        Test-FlowsAreInjectedOnTcpTraffic -Session $Session1 -TestConfiguration $TestConfiguration
        Test-FlowsAreInjectedOnUdpTraffic -Session $Session1 -TestConfiguration $TestConfiguration
        Test-MultihostUdpTraffic -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfiguration
    })

    # Test cleanup
    Clear-TestConfiguration -Session $Session1 -TestConfiguration $TestConfiguration
    Clear-TestConfiguration -Session $Session2 -TestConfiguration $TestConfiguration
}
