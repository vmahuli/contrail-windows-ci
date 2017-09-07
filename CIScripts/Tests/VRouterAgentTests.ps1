function Test-VRouterAgentIntegration {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\CommonTestCode.ps1

    $MAX_WAIT_TIME_FOR_AGENT_PROCESS_IN_SECONDS = 60
    $TIME_BETWEEN_AGENT_PROCESS_CHECKS_IN_SECONDS = 5

    #
    # Private functions of Test-VRouterAgentIntegration
    #

    function New-AgentConfigFile {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        # Gather information about testbed's network adapters
        $HNSTransparentAdapter = Get-RemoteNetAdapterInformation `
                -Session $Session `
                -AdapterName $TestConfiguration.VHostName

        $PhysicalAdapter = Get-RemoteNetAdapterInformation `
                -Session $Session `
                -AdapterName $TestConfiguration.AdapterName

        # Prepare parameters for script block
        $ControllerIP = $TestConfiguration.DockerDriverConfiguration.ControllerIP
        $VHostIfName = $HNSTransparentAdapter.ifName
        $PhysIfName = $PhysicalAdapter.ifName

        $SourceConfigFilePath = $TestConfiguration.AgentSampleConfigFilePath
        $DestConfigFilePath = $TestConfiguration.AgentConfigFilePath

        Invoke-Command -Session $Session -ScriptBlock {
            $ControllerIP = $Using:ControllerIP
            $VHostIfName = $Using:VHostIfName
            $PhysIfName = $Using:PhysIfName

            $SourceConfigFilePath = $Using:SourceConfigFilePath
            $DestConfigFilePath = $Using:DestConfigFilePath

            $ConfigFileContent = [System.IO.File]::ReadAllText($SourceConfigFilePath)

            # Insert server IP only in [CONTROL-NODE] and [DISCOVERY] (first 2 occurrences of "server=")
            [regex] $ServerIpPattern = "# server=.*"
            $ServerIpString = "server=$ControllerIP"
            $ConfigFileContent = $ServerIpPattern.replace($ConfigFileContent, $ServerIpString, 2)

            # Insert ifName of HNSTransparent interface
            $ConfigFileContent = $ConfigFileContent -Replace "# name=vhost0", "name=$VHostIfName"

            # Insert ifName of Ethernet1 interface
            $ConfigFileContent = $ConfigFileContent `
                                    -Replace "# physical_interface=vnet0", "physical_interface=$PhysIfName"

            # Save file with prepared config
            [System.IO.File]::WriteAllText($DestConfigFilePath, $ConfigFileContent)
        }
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
        Start-Sleep -Seconds 15

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
        Start-Sleep -Seconds 15

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
        Start-Sleep -Seconds 15

        Write-Host "======> Given pkt0 is injected"
        Assert-IsPkt0Injected -Session $Session

        Write-Host "======> When Agent is Restarted"
        Disable-VRouterAgent -Session $Session
        Assert-AgentIsNotRunning -Session $Session
        Enable-VRouterAgent -Session $Session -ConfigFilePath $TestConfiguration.AgentConfigFilePath
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds 15

        Write-Host "======> Then pkt0 exists in vRouter"
        Assert-IsOnlyOnePkt0Injected -Session $Session
    }

    Test-InitialPkt0Injection -Session $Session -TestConfiguration $TestConfiguration
    Test-Pkt0RemainsInjectedAfterAgentStops -Session $Session -TestConfiguration $TestConfiguration
    Test-OnePkt0ExistsAfterAgentIsRestarted -Session $Session -TestConfiguration $TestConfiguration

    # Test cleanup
    Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
}
