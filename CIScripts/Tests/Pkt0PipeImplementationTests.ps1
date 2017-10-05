function Test-Pkt0PipeImplementation {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\CommonTestCode.ps1

    function Assert-ExtensionIsRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Running = Test-IsVRouterExtensionEnabled -Session $Session -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        if (!$Running) {
            throw "Extension is not running. EXPECTED: Extension is running"
        }
    }

    function Assert-ExtensionIsNotRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Running = Test-IsVRouterExtensionEnabled -Session $Session -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        if ($Running) {
            throw "Extension is running. EXPECTED: Extension is not running"
        }
    }

    function Test-StartingAgentWhenExtensionDisabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-StartingAgentWhenExtensionDisabled"

            Write-Host "======> Given Extension is not running"
            Assert-ExtensionIsNotRunning -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Then Agent should crash when started"
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceDisabled -Session $Session

            Write-Host "======> Cleanup"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-StartingAgentWhenExtensionDisabled"
        })
    }

    function Test-StartingAgentWhenExtensionEnabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-StartingAgentWhenExtensionEnabled"

            Write-Host "======> Given Extension is running"
            Enable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName -VMSwitchName $TestConfiguration.VMSwitchName `
                -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
            Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> When Agent is started"
            Enable-AgentService -Session $Session

            Write-Host "======> Then Agent should work"
            Assert-IsAgentServiceEnabled -Session $Session

            Write-Host "======> Cleanup"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-StartingAgentWhenExtensionEnabled"
        })
    }

    function Test-DisablingExtensionWhenAgentEnabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-DisablingExtensionWhenAgentEnabled"

            Write-Host "======> Given Extension and Agent are running"
            Enable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName -VMSwitchName $TestConfiguration.VMSwitchName `
                -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
            Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration
            Enable-AgentService -Session $Session
            Assert-IsAgentServiceEnabled -Session $Session

            Write-Host "======> When Extension is disabled"
            Disable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName -VMSwitchName $TestConfiguration.VMSwitchName `
                -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName

            Write-Host "======> Then Agent should crash"
            Assert-IsAgentServiceDisabled -Session $Session

            Write-Host "======> Cleanup"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-DisablingExtensionWhenAgentEnabled"
        })
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        # Initialize Agent Config used for all tests
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        # Run all tests
        Test-StartingAgentWhenExtensionDisabled -Session $Session -TestConfiguration $TestConfiguration
        Test-StartingAgentWhenExtensionEnabled -Session $Session -TestConfiguration $TestConfiguration
        Test-DisablingExtensionWhenAgentEnabled -Session $Session -TestConfiguration $TestConfiguration
    })
}
