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
            Write-Host "======> Then there is correct response from Linux server"
            if($Res -ne 0) {
                throw "===> TCP test failed!"
            }

            Write-Host "===> PASSED: TcpLinuxWindowsConnectivity"
        })
    }

    function Test-UdpLinuxWindowsConnectivity {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: UdpLinuxWindowsConnectivity"

            Write-Host "======> Given controller for Windows-Linux integration"
            $NetworkName = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Name

            Write-Host "======> Given running compute services"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration
            Assert-IsAgentServiceEnabled -Session $Session
            Start-Sleep -Seconds $WAIT_TIME_FOR_AGENT_INIT_IN_SECONDS

            Write-Host "======> Given Windows container"
            $ClientID = New-Container -Session $Session -NetworkName $NetworkName

            Write-Host "======> When udp request is send to Linux server"
            $Port = "9090"
            $Message = "Lorem ipsum dolor sit amet, mundi zril epicuri nam no, eam et expetenda consulatu consequat."
            $Command = (`
                '$IpAddress = [System.Net.IPAddress]::Parse(\"{0}\");' +`
                '$IpEndPoint = New-Object System.Net.IPEndPoint($IpAddress, {1});' +`
                '$UdpClient = New-Object System.Net.Sockets.UdpClient(0);' +`
                '$ReceiveTask = $UdpClient.ReceiveAsync();' +`
                '$Data = [System.Text.Encoding]::UTF8.GetBytes(\"{2}\");' +`
                'Foreach ($num in 1..10) {{$UdpClient.SendAsync($Data, $Data.length, $IpEndPoint) | Out-Null; Start-Sleep -Seconds 1}};' +`
                '$GotMessage = $ReceiveTask.Wait(5000);' +`
                'if($GotMessage) {{$ReceivedMessage = [System.Text.Encoding]::UTF8.GetString($ReceiveTask.Result.Buffer)}};' +`
                'return $ReceivedMessage;'
                ) -f $TestConfigurationWinLinux.LinuxVirtualMachineIp, $Port, $Message
            $ReceivedMessage = Invoke-Command -Session $Session -ScriptBlock {
                return & docker exec $Using:ClientID powershell -Command $Using:Command
            }
            Remove-Container -Session $Session -NameOrId $ClientID

            Write-Host "======> Then there is correct response from Linux server"
            if ($Message -ne $ReceivedMessage) {
                throw "Received message: {0} is different from expected: {1}" -f $ReceivedMessage, $Message
            }
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
            Write-Host "===> PASSED: UdpLinuxWindowsConnectivity"
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
        Test-UdpLinuxWindowsConnectivity -Session $Session -TestConfiguration $TestConfigurationWinLinux
        Test-TcpLinuxWindowsConnectivity -Session $Session -TestConfiguration $TestConfigurationWinLinux
    })
}
