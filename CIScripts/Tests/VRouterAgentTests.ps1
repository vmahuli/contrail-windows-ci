function Test-VRouterAgentIntegration {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session1,
           [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session2,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\CommonTestCode.ps1
    . $PSScriptRoot\..\Job.ps1

    $AgentIntegrationTestsTimeTracker = [Job]::new("Test-VRouterAgentIntegration")

    $MAX_WAIT_TIME_FOR_AGENT_PROCESS_IN_SECONDS = 60
    $TIME_BETWEEN_AGENT_PROCESS_CHECKS_IN_SECONDS = 5
    $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS = 15

    $TEST_NETWORK_GATEWAY = "10.7.3.1"

    $AGENT_INSPECTOR_PROTO = "http"
    $AGENT_INSPECTOR_PORT = 8085
    $AGENT_ITF_REQ_PATH = "Snh_ItfReq"
    $AGENT_ARP_REQ_PATH = "Snh_NhListReq?type=arp"

    #
    # Private functions of Test-VRouterAgentIntegration
    #

    function Get-TestbedIpAddressFromDns {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

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
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

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
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $isEnabled = Test-IsVRouterExtensionEnabled `
            -Session $Session `
            -VMSwitchName $TestConfiguration.VMSwitchName `
            -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        if (!$isEnabled) {
            throw "Hyper-V Extension is not running. EXPECTED: Hyper-V Extension is running"
        }
    }

    function Assert-AgentIsRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $MaxWaitTimeInSeconds = $MAX_WAIT_TIME_FOR_AGENT_PROCESS_IN_SECONDS
        $TimeBetweenChecksInSeconds = $TIME_BETWEEN_AGENT_PROCESS_CHECKS_IN_SECONDS
        $MaxNumberOfChecks = [Math]::Ceiling($MaxWaitTimeInSeconds / $TimeBetweenChecksInSeconds)

        for ($RetryNum = $MaxNumberOfChecks; $RetryNum -gt 0; $RetryNum--) {
            if (Test-IsVRouterAgentEnabled -Session $Session) {
                return
            }

            Start-Sleep -s $TimeBetweenChecksInSeconds
        }

        throw "vRouter Agent is not running. EXPECTED: vRouter Agent is running"
    }

    function Assert-AgentIsNotRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $MaxWaitTimeInSeconds = $MAX_WAIT_TIME_FOR_AGENT_PROCESS_IN_SECONDS
        $TimeBetweenChecksInSeconds = $TIME_BETWEEN_AGENT_PROCESS_CHECKS_IN_SECONDS
        $MaxNumberOfChecks = [Math]::Ceiling($MaxWaitTimeInSeconds / $TimeBetweenChecksInSeconds)

        for ($RetryNum = $MaxNumberOfChecks; $RetryNum -gt 0; $RetryNum--) {
            if (!(Test-IsVRouterAgentEnabled -Session $Session)) {
                return
            }

            Start-Sleep -s $TimeBetweenChecksInSeconds
        }

        throw "vRouter Agent is running. EXPECTED: vRouter Agent is not running"
    }

    function Assert-NoVifs {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        if ($vifOutput -Match "vif") {
            throw "There are vifs registered in vRouter. EXPECTED: no vifs in vRouter"
        }
    }

    function Assert-IsPkt0Injected {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        $match = $($vifOutput -Match "Type:Agent")
        if (!$match) {
            throw "pkt0 interface is not injected. EXPECTED: pkt0 injected in vRouter"
        }
    }

    function Assert-IsOnlyOnePkt0Injected {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

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
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

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
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

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

    function Create-ContainerInRemoteSession {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [string] $NetworkName,
               [Parameter(Mandatory = $true)] [string] $ContainerName)
        Write-Host "Creating container: name = $ContainerName; network = $NetworkName."
        $Output = Invoke-Command -Session $Session -ScriptBlock {
            $DockerOutput = (& docker run -id --name $Using:ContainerName --network $Using:NetworkName microsoft/nanoserver powershell 2>&1) | Out-String
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
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)] [string] $ContainerName,
        [Parameter(Mandatory = $true)] [string] $IP)
        $PingOutput = Invoke-Command -Session $Session -ScriptBlock {
            & docker exec $Using:ContainerName ping $Using:IP -n 10 -w 500
        }
        Assert-PingSucceeded -Output $PingOutput
    }

    function Test-Ping {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session1,
               [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session2,
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
        Enable-VRouterAgent -Session $Session1 -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Assert-AgentIsRunning -Session $Session1

        # 2nd compute node (if there actually is more than 1 compute node)
        if ($Session1 -ne $Session2) {
           New-AgentConfigFile -Session $Session2 -TestConfiguration $TestConfiguration
           Enable-VRouterAgent -Session $Session2 -ConfigFilePath $TestConfiguration.AgentConfigFilePath
           Assert-AgentIsRunning -Session $Session2
        }

        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

        Write-Host "======> When 2 containers belonging to the same network are running"
        $NetworkName = $TestConfiguration.DockerDriverConfiguration.NetworkConfiguration.NetworkName

        $CreateContainer1Success = Create-ContainerInRemoteSession -Session $Session1 -NetworkName $NetworkName -ContainerName $Container1Name
        $CreateContainer2Success = Create-ContainerInRemoteSession -Session $Session2 -NetworkName $NetworkName -ContainerName $Container2Name

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

    #
    # Tests definitions
    #

    function Test-InitialPkt0Injection {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-InitialPkt0Injection"

        Write-Host "======> Given Extension is running"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> Given clean vRouter"
        Assert-NoVifs -Session $Session

        Write-Host "======> When Agent is started"
        Enable-VRouterAgent -Session $Session -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

        Write-Host "======> Then pkt0 appears in vRouter"
        Assert-IsPkt0Injected -Session $Session

        Write-Host "===> PASSED: Test-InitialPkt0Injection"
    }

    function Test-Pkt0RemainsInjectedAfterAgentStops {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-Pkt0RemainsInjectedAfterAgentStops"

        Write-Host "======> Given Extension is running"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> Given Agent is running"
        Enable-VRouterAgent -Session $Session -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

        Write-Host "======> Given pkt0 is injected"
        Assert-IsPkt0Injected -Session $Session

        Write-Host "======> When Agent is stopped"
        Disable-VRouterAgent -Session $Session
        Assert-AgentIsNotRunning -Session $Session

        Write-Host "======> Then pk0 exists in vRouter"
        Assert-IsPkt0Injected -Session $Session

        Write-Host "===> PASSED: Test-Pkt0RemainsInjectedAfterAgentStops"
    }

    function Test-OnePkt0ExistsAfterAgentIsRestarted {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-OnePkt0ExistsAfterAgentIsRestarted"

        Write-Host "======> Given Extension is running"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> Given Agent is running"
        Enable-VRouterAgent -Session $Session -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Test-IsVRouterAgentEnabled -Session $Session
        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

        Write-Host "======> Given pkt0 is injected"
        Assert-IsPkt0Injected -Session $Session

        Write-Host "======> When Agent is Restarted"
        Disable-VRouterAgent -Session $Session
        Assert-AgentIsNotRunning -Session $Session
        Enable-VRouterAgent -Session $Session -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

        Write-Host "======> Then pkt0 exists in vRouter"
        Assert-IsOnlyOnePkt0Injected -Session $Session
    }

    function Test-Pkt0ReceivesTrafficAfterAgentIsStarted {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"

        Write-Host "======> Given Extension is running"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> When Agent is started"
        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration
        Enable-VRouterAgent -Session $Session -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS  # Wait for KSync

        Write-Host "======> Then Pkt0 has traffic"
        Assert-Pkt0HasTraffic -Session $Session

        Write-Host "===> PASSED: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"
    }

    function Test-GatewayArpIsResolvedInAgent {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"

        Write-Host "======> Given Extension is running"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> When Agent is started"
        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration
        Enable-VRouterAgent -Session $Session -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS  # Wait for KSync

        Write-Host "======> Then Gateway ARP was resolved through Pkt0"
        Assert-IsGatewayArpResolvedInAgent -Session $Session

        Write-Host "===> PASSED: Test-Pkt0ReceivesTrafficAfterAgentIsStarted"
    }

    function Test-SingleComputeNodePing {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)
        Write-Host "===> Running: Test-SingleComputeNodePing"
        Test-Ping -Session1 $Session -Session2 $Session -TestConfiguration $TestConfiguration -Container1Name "container1" -Container2Name "container2"
        Write-Host "===> PASSED: Test-SingleComputeNodePing"
    }

    function Test-MultiComputeNodesPing {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session1,
               [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session2,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)
        Write-Host "===> Running: Test-MultiComputeNodesPing"
        Test-Ping -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfiguration -Container1Name "container1" -Container2Name "container2"
        Write-Host "===> PASSED: Test-MultiComputeNodesPing"
    }

    $AgentIntegrationTestsTimeTracker.StepQuiet("Test-InitialPkt0Injection", {
        Test-InitialPkt0Injection -Session $Session1 -TestConfiguration $TestConfiguration
    })

    $AgentIntegrationTestsTimeTracker.StepQuiet("Test-Pkt0RemainsInjectedAfterAgentStops", {
        Test-Pkt0RemainsInjectedAfterAgentStops -Session $Session1 -TestConfiguration $TestConfiguration
    })

    $AgentIntegrationTestsTimeTracker.StepQuiet("Test-OnePkt0ExistsAfterAgentIsRestarted", {
        Test-OnePkt0ExistsAfterAgentIsRestarted -Session $Session1 -TestConfiguration $TestConfiguration
    })

    $AgentIntegrationTestsTimeTracker.StepQuiet("Test-Pkt0ReceivesTrafficAfterAgentIsStarted", {
        Test-Pkt0ReceivesTrafficAfterAgentIsStarted -Session $Session1 -TestConfiguration $TestConfiguration
    })

    $AgentIntegrationTestsTimeTracker.StepQuiet("Test-GatewayArpIsResolvedInAgent", {
        Test-GatewayArpIsResolvedInAgent -Session $Session1 -TestConfiguration $TestConfiguration
    })

    $AgentIntegrationTestsTimeTracker.StepQuiet("Test-SingleComputeNodePing", {
        Test-SingleComputeNodePing -Session $Session1 -TestConfiguration $TestConfiguration
    })

    # TODO: Enable this test once it is actually expected to pass.
    # Currently, when two containers on separate compute nodes communicate,
    # removing those containers takes infinite time to complete.
    #$AgentIntegrationTestsTimeTracker.StepQuiet("Test-MultiComputeNodesPing", {
    #    Test-MultiComputeNodesPing -Session1 $Session1 -Session2 $Session2 -TestConfiguration $TestConfiguration
    #})

    # Test cleanup
    Clear-TestConfiguration -Session $Session1 -TestConfiguration $TestConfiguration
    Clear-TestConfiguration -Session $Session2 -TestConfiguration $TestConfiguration

    $AgentIntegrationTestsTimeTracker.Done()
}
