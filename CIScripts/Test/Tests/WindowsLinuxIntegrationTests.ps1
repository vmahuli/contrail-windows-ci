$Accel = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$Accel::add("PSSessionT", "System.Management.Automation.Runspaces.PSSession")

function Test-WindowsLinuxIntegration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\..\Utils\CommonTestCode.ps1

    $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS = 15
    #
    # Private functions of Test-WindowsLinuxIntegration
    #
    function Test-TcpLinuxWindowsConnectivity {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: TcpLinuxWindowsConnectivity"

            Write-Host "======> Given controller for Windows-Linux integration"
            $NetworkName = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Name

            Write-Host "======> Given running compute services"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> Given Windows container"
            $ClientID = New-Container -Session $Session -NetworkName $NetworkName

            Write-Host "======> When tcp (http) request is send to Linux server"
            $LinuxServerIp = $TestConfiguration.LinuxVirtualMachineIp
            $Res = Invoke-Command -Session $Session -ScriptBlock {
                $ServerIP = $Using:LinuxServerIp
                docker exec $Using:ClientID powershell "Invoke-WebRequest -Uri http://${ServerIP}:8080/" | Write-Host
                return $LASTEXITCODE
            }
            
            Remove-Container -Session $Session -NameOrId $ClientID
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Write-Host "======> Then there is correct response from Linux server  "
            if($Res -ne 0) {
                throw "===> TCP test failed!"
            }

            Write-Host "===> PASSED: TcpLinuxWindowsConnectivity"
        })
    }

    function Test-IcmpLinuxWindowsConnectivity {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: IcmpLinuxWindowsConnectivity"
            
            Write-Host "======> Given controller for Windows-Linux integration"
            Write-Host "======> Given running compute services"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS
            
            Write-Host "======> Given Windows container"
            $NetworkName = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Name
            $Container = New-Container -Session $Session -NetworkName $NetworkName
            
            Write-Host "======> When icmp packet is send to Linux server"
            try {
                Write-Host "======> Then there is correct response from Linux server"
                Ping-Container -Session $Session -ContainerName $Container -IP $TestConfiguration.LinuxVirtualMachineIp
            } 
            Finally {
                Remove-Container -Session $Session -NameOrId $Container
                Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            }
            Write-Host "===> PASSED: IcmpLinuxWindowsConnectivity"
        })
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        $TestConfigurationWinLinux = $TestConfiguration.ShallowCopy()
        $TestConfigurationWinLinux.DockerDriverConfiguration = $TestConfiguration.DockerDriverConfiguration.ShallowCopy()
        $TestConfigurationWinLinux.ControllerIP = $Env:CONTROLLER_IP_LINUX_WINDOWS
        $TestConfigurationWinLinux.DockerDriverConfiguration.AuthUrl = $Env:DOCKER_DRIVER_AUTH_URL_LINUX_WINDOWS

        Test-IcmpLinuxWindowsConnectivity -Session $Session -TestConfiguration $TestConfigurationWinLinux
        Test-TcpLinuxWindowsConnectivity -Session $Session -TestConfiguration $TestConfigurationWinLinux
    })
}
