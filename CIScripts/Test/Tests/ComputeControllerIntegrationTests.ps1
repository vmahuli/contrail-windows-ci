. $PSScriptRoot\..\..\Common\Aliases.ps1

function Test-ComputeControllerIntegration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\..\Utils\CommonTestCode.ps1

    $WAIT_TIME_SEC = 15

    #
    # Private functions
    #

    function Get-PSHostname {
        Param([Parameter(Mandatory = $true)] [PSSessionT] $Session)
        return Invoke-Command -Session $Session -ScriptBlock { hostname }
    }

    function Get-PSIPAddress {
        Param([Parameter(Mandatory = $true)] [PSSessionT] $Session)
        return Invoke-Command -Session $Session -ScriptBlock { Get-NetIPAddress |
            Where-Object InterfaceAlias -like "Ethernet0*" |
            Where-Object AddressFamily -eq IPv4 |
            Select-Object -ExpandProperty IPAddress
        }
    }

    function Connect-ToController {
        Param ([Parameter(Mandatory = $true)] [string] $IP,
               [Parameter(Mandatory = $true)] [string] $Username,
               [Parameter(Mandatory = $true)] [string] $Password)
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
        return New-SSHSession -IPAddress $IP -Credential $Credentials -AcceptKey
    }

    function Test-ComputeInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)
        $Out = Invoke-RestMethod ("http://" + $DnsIP + ":8092/Snh_ShowAgentList?")
        $OurNode = $Out.DnsAgentListResponse.agent.list.AgentData.peer | Where-Object "#text" -Like "$ComputeHostname*"
        if($OurNode) {
            return $true
        }
        return $false
    }

    function Test-ComputeInXMPPDnsData {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeIP)
        $Out = Invoke-RestMethod ("http://" + $DnsIP + ":8092/Snh_ShowAgentXmppDnsData?")
        $OurNode = $Out.AgentXmppDnsDataResponse.data.list.AgentDnsData.agent | Where-Object "#text" -Like "$ComputeIP"
        if($OurNode) {
            return $true
        }
        return $false
    }

    function Test-ComputeInShowCollectorServer {
        Param ([Parameter(Mandatory = $true)] [string] $CollectorIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)
        $Out = Invoke-RestMethod ("http://" + $CollectorIP + ":8089/Snh_ShowCollectorServerReq?")
        $OurNode = $Out.ShowCollectorServerResp.generators.list.GeneratorSummaryInfo.source | Where-Object "#text" -Like "$ComputeHostname"
        if($OurNode) {
            return $true
        }
        return $false
    }

    function Assert-ComputeInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)

        if(!(Test-ComputeInDnsAgentList -DnsIP $DnsIP -ComputeHostname $ComputeHostname)) {
            throw "$ComputeHostname not found anywhere in DnsAgentList! EXPECTED: it's in DnsAgentList."
        }
    }

    function Assert-ComputeNotInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)

        if(Test-ComputeInDnsAgentList -DnsIP $DnsIP -ComputeHostname $ComputeHostname) {
            throw "$ComputeHostname found in DnsAgentList! EXPECTED: it's not in DnsAgentList."
        }
    }

    function Assert-ComputeInXMPPDnsData {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeIP)

        if(!(Test-ComputeInXMPPDnsData -DnsIP $DnsIP -ComputeIP $ComputeIP)) {
            throw "$ComputeIP not found anywhere in XMPPDnsData! EXPECTED: it's in XMPPDnsData."
        }
    }

    function Assert-ComputeNotInXMPPDnsData {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeIP)

        if(Test-ComputeInXMPPDnsData -DnsIP $DnsIP -ComputeIP $ComputeIP) {
            throw "$ComputeIP found in XMPPDnsData! EXPECTED: it's not in XMPPDnsData."
        }
    }

    function Assert-ComputeInShowCollectorServer {
        Param ([Parameter(Mandatory = $true)] [string] $CollectorIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)

        if(!(Test-ComputeInShowCollectorServer -CollectorIP $CollectorIP -ComputeHostname $ComputeHostname)) {
            throw "$ComputeHostname not found anywhere in ShowCollectorServer! EXPECTED: it's in ShowCollectorServer."
        }
    }

    function Assert-ComputeNotInShowCollectorServer {
        Param ([Parameter(Mandatory = $true)] [string] $CollectorIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)

        if(Test-ComputeInShowCollectorServer -CollectorIP $CollectorIP -ComputeHostname $ComputeHostname) {
            throw "$ComputeIP found in ShowCollectorServer! EXPECTED: it's not in ShowCollectorServer."
        }
    }

    #
    # Tests definitions
    #

    function Test-ComputeNodeAppearsInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ComputeNodeAppearsInDnsAgentList"
            $ComputeHostname = Get-PSHostname -Session $Session
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given our compute node is not in DnsAgentList"
            Assert-ComputeNotInDnsAgentList -ComputeHostname $ComputeHostname -DnsIP $TestConfiguration.ControllerIP

            Write-Host "======> When all compute services are started"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Then our compute node appears in DnsAgentList after a while"
            Start-Sleep -Seconds $WAIT_TIME_SEC
            Assert-ComputeInDnsAgentList -ComputeHostname $ComputeHostname -DnsIP $TestConfiguration.ControllerIP
        })
    }

    function Test-ComputeNodeAppearsInXMPPDnsData {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ComputeNodeAppearsInXMPPDnsData"
            $ComputeIP = Get-PSIPAddress -Session $Session
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given our compute node is not in XMPPDnsData"
            Assert-ComputeNotInXMPPDnsData -ComputeIP $ComputeIP -DnsIP $TestConfiguration.ControllerIP

            Write-Host "======> When all compute services are started"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Then our compute node appears in XMPPDnsData after a while"
            Start-Sleep -Seconds $WAIT_TIME_SEC
            Assert-ComputeInXMPPDnsData -ComputeIP $ComputeIP -DnsIP $TestConfiguration.ControllerIP
        })
    }

    function Test-ComputeNodeAppearsInShowCollectorServer {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ComputeNodeAppearsInShowCollectorServer"
            $ComputeHostname = Get-PSHostname -Session $Session
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given our compute node is not in ShowCollectorServer"
            Assert-ComputeNotInShowCollectorServer -ComputeHostname $ComputeHostname -CollectorIP $TestConfiguration.ControllerIP

            Write-Host "======> When all compute services are started"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Then our compute node appears in ShowCollectorServer after a while"
            Start-Sleep -Seconds $WAIT_TIME_SEC
            Assert-ComputeInShowCollectorServer -ComputeHostname $ComputeHostname -CollectorIP $TestConfiguration.ControllerIP
        })
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {

        Test-ComputeNodeAppearsInDnsAgentList -Session $Session -TestConfiguration $TestConfiguration
        Test-ComputeNodeAppearsInXMPPDnsData -Session $Session -TestConfiguration $TestConfiguration
        Test-ComputeNodeAppearsInShowCollectorServer -Session $Session -TestConfiguration $TestConfiguration

        # Test cleanup
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
    })
}
