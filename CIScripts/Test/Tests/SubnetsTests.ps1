function Test-MultipleSubnetsSupport {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    function Join-ContainerNetworkNamePrefix {
        Param ([Parameter(Mandatory = $true)] [string] $Tenant,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        $Prefix = "{0}:{1}:{2}" -f @("Contrail", $Tenant, $Network)

        if ($Subnet) {
            $Prefix = "{0}:{1}" -f @($Prefix, $Subnet)
        }

        return $Prefix
    }

    function Get-SpecificTransparentContainerNetwork {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        $Networks = Invoke-Command -Session $Session -ScriptBlock {
            return $(Get-ContainerNetwork | Where-Object Mode -EQ "Transparent")
        }

        $ContainerNetworkPrefix = Join-ContainerNetworkNamePrefix `
            -Tenant $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.Name -Network $Network -Subnet $Subnet

        return $($Networks | Where-Object { $_.Name.StartsWith($ContainerNetworkPrefix) })
    }

    function Convert-IPAddressToBinary {
        Param ([Parameter(Mandatory = $true)] [string] $IPAddress)

        [uint32] $BinIPAddress = 0
        $([uint32[]] $IPAddress.Split(".")).ForEach({ $BinIPAddress = ($BinIPAddress -shl 8) + $_ })

        return $BinIPAddress
    }

    function Convert-SubnetToBinaryNetmask {
        Param ([Parameter(Mandatory = $true)] [string] $SubnetLen)
        return $((-bnot [uint32] 0) -shl (32 - $SubnetLen))
    }

    function Test-IPAddressInSubnet {
        Param ([Parameter(Mandatory = $true)] [string] $IPAddress,
               [Parameter(Mandatory = $true)] [string] $Subnet)

        $NetworkIP, $SubnetLen = $Subnet.Split("/")

        $BinIPAddress = Convert-IPAddressToBinary -IPAddress $IPAddress
        $BinNetworkIP = Convert-IPAddressToBinary -IPAddress $NetworkIP
        $BinNetmask = Convert-SubnetToBinaryNetmask -SubnetLen $SubnetLen

        return $(($BinIPAddress -band $BinNetmask) -eq ($BinNetworkIP -band $BinNetmask))
    }

    function Assert-NetworkExistence {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $Name,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet,
               [Parameter(Mandatory = $true)] [bool] $ShouldExist)

        $Networks = Invoke-Command -Session $Session -ScriptBlock {
            $Networks = @($(docker network ls --filter 'driver=Contrail'))
            return $Networks[1..($Networks.length - 1)]
        }

        $Res = $Networks | Where-Object { $_.Split("", [System.StringSplitOptions]::RemoveEmptyEntries)[1] -eq $Name }
        if ($ShouldExist -and !$Res) {
            throw "Network $Name not found in docker network list"
        }
        if (!$ShouldExist -and $Res) {
            throw "Network $Name has been found in docker network list"
        }

        $Res = Get-SpecificTransparentContainerNetwork -Session $Session -TestConfiguration $TestConfiguration -Network $Network -Subnet $Subnet
        if ($ShouldExist -and !$Res) {
            throw "Network $Name not found in container network list"
        }
        if (!$ShouldExist -and $Res) {
            throw "Network $Name has been found in container network list"
        }

        if ($ShouldExist -and $Subnet -and ($Res.SubnetPrefix -ne $Subnet)) {
            throw "Invalid subnet: ${Res.SubnetPrefix}. Should be: $Subnet"
        }
    }

    function Assert-NetworkExists {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $Name,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        Assert-NetworkExistence -Session $Session -TestConfiguration $TestConfiguration -Name $Name -Network $Network -Subnet $Subnet -ShouldExist:$true
    }

    function Assert-NetworkDoesNotExist {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $Name,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        Assert-NetworkExistence -Session $Session -TestConfiguration $TestConfiguration -Name $Name -Network $Network -Subnet $Subnet -ShouldExist:$false
    }

    function Assert-ContainerHasValidIPAddress {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $ContainerName,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        $IPAddress = Invoke-Command -Session $Session -ScriptBlock {
            return $(docker exec $Using:ContainerName powershell "(Get-NetIpAddress -AddressFamily IPv4 | Where-Object IPAddress -NE 127.0.0.1).IPAddress")
        }
        if (!$IPAddress) {
            throw "IP Address not found"
        }

        if (!$Subnet) {
            $Subnet = $(Get-SpecificTransparentContainerNetwork -Session $Session -TestConfiguration $TestConfiguration -Network $Network).SubnetPrefix
        }

        $Res = Test-IPAddressInSubnet -IPAddress $IPAddress -Subnet $Subnet
        if (!$Res) {
            throw "IP Address $IPAddress does not match subnet $Subnet"
        }
    }

    function Assert-NetworkCannotBeCreated {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $false)] [string] $NetworkName,
               [Parameter(Mandatory = $false)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        $NetworkCannotBeCreated = $false

        try {
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet | Out-Null
        }
        catch { $NetworkCannotBeCreated = $true }

        if (!$NetworkCannotBeCreated) {
            throw "Network $NetworkName has been created when it should not"
        }
    }

    function Test-SingleNetworkSingleSubnetDefault {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleNetworkSingleSubnetDefault"

            $ContainerName = "SingleNetworkSingleSubnetDefaultTest"
            $NetworkName = "Testnet"
            $Network = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Name;

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> When network is created"
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network | Out-Null

            Write-Host "======> When container is started"
            New-Container -Session $Session -Name $ContainerName -NetworkName $NetworkName | Out-Null

            Write-Host "======> Then valid network exists"
            Assert-NetworkExists -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network

            Write-Host "======> Then container has valid IP address"
            Assert-ContainerHasValidIPAddress -Session $Session -TestConfiguration $TestConfiguration -ContainerName $ContainerName -Network $Network

            Write-Host "======> Cleanup"
            Remove-Container -Session $Session -Name $ContainerName
            Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-SingleNetworkSingleSubnetDefault"
        })
    }

    function Test-SingleNetworkSingleSubnetExplicit {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleNetworkSingleSubnetExplicit"

            $ContainerName = "SingleNetworkSingleSubnetExplicitTest"
            $NetworkName = "Testnet"
            $Network = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Name;
            $Subnet = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Subnets[0];

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> When network is created"
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet | Out-Null

            Write-Host "======> When container is started"
            New-Container -Session $Session -Name $ContainerName -NetworkName $NetworkName | Out-Null

            Write-Host "======> Then valid network exists"
            Assert-NetworkExists -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet

            Write-Host "======> Then container has valid IP address"
            Assert-ContainerHasValidIPAddress -Session $Session -TestConfiguration $TestConfiguration -ContainerName $ContainerName -Network $Network -Subnet $Subnet

            Write-Host "======> Cleanup"
            Remove-Container -Session $Session -Name $ContainerName
            Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-SingleNetworkSingleSubnetExplicit"
        })
    }

    function Test-SingleNetworkSingleSubnetInvalid {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleNetworkSingleSubnetInvalid"

            $NetworkName = "Testnet"
            $Network = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Name;
            $Subnet = "11.12.13.0/24" # Invalid subnet

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> Then network with invalid subnet cannot be created"
            Assert-NetworkCannotBeCreated -Session $Session -TestConfiguration $TestConfiguration -NetworkName $NetworkName -Network $Network -Subnet $Subnet | Out-Null

            Write-Host "======> Then network should not exist"
            Assert-NetworkDoesNotExist -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet

            Write-Host "======> Cleanup"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-SingleNetworkSingleSubnetInvalid"
        })
    }

    function Test-SingleNetworkMultipleSubnetsDefault {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsDefault"

            $NetworkName = "Testnet"
            $Network = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Name;

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> Then network with invalid subnet cannot be created"
            Assert-NetworkCannotBeCreated -Session $Session -TestConfiguration $TestConfiguration -NetworkName $NetworkName -Network $Network | Out-Null

            Write-Host "======> Then network should not exist"
            Assert-NetworkDoesNotExist -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network

            Write-Host "======> Cleanup"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsDefault"
        })
    }

    function Test-SingleNetworkMultipleSubnetsExplicitFirst {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsExplicitFirst"

            $ContainerName = "SingleNetworkMultipleSubnetsExplicitFirstTest"
            $NetworkName = "Testnet"
            $Network = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Name
            $Subnet = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Subnets[0]

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> When network is created"
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet | Out-Null

            Write-Host "======> When container is started"
            New-Container -Session $Session -Name $ContainerName -NetworkName $NetworkName | Out-Null

            Write-Host "======> Then valid network exists"
            Assert-NetworkExists -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet

            Write-Host "======> Then container has valid IP address"
            Assert-ContainerHasValidIPAddress -Session $Session -TestConfiguration $TestConfiguration -ContainerName $ContainerName -Network $Network -Subnet $Subnet

            Write-Host "======> Cleanup"
            Remove-Container -Session $Session -Name $ContainerName
            Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsExplicitFirst"
        })
    }

    function Test-SingleNetworkMultipleSubnetsExplicitSecond {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsExplicitSecond"

            $ContainerName = "SingleNetworkMultipleSubnetsExplicitSecondTest"
            $NetworkName = "Testnet"
            $Network = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Name
            $Subnet = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Subnets[1]

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> When network is created"
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet | Out-Null

            Write-Host "======> When container is started"
            New-Container -Session $Session -Name $ContainerName -NetworkName $NetworkName | Out-Null

            Write-Host "======> Then valid network exists"
            Assert-NetworkExists -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet

            Write-Host "======> Then container has valid IP address"
            Assert-ContainerHasValidIPAddress -Session $Session -TestConfiguration $TestConfiguration -ContainerName $ContainerName -Network $Network -Subnet $Subnet

            Write-Host "======> Cleanup"
            Remove-Container -Session $Session -Name $ContainerName
            Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsExplicitSecond"
        })
    }

    function Test-SingleNetworkMultipleSubnetsInvalid {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsInvalid"

            $NetworkName = "Testnet"
            $Network = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Name
            $Subnet = "192.168.10.0/24" # Invalid subnet

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> Then network with invalid subnet cannot be created"
            Assert-NetworkCannotBeCreated -Session $Session -TestConfiguration $TestConfiguration -NetworkName $NetworkName -Network $Network -Subnet $Subnet | Out-Null

            Write-Host "======> Then network should not exist"
            Assert-NetworkDoesNotExist -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkName -Network $Network -Subnet $Subnet

            Write-Host "======> Cleanup"
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsInvalid"
        })
    }

    function Test-MultipleNetworksMultipleSubnetsAllSimultaneously {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-MultipleNetworksMultipleSubnetsAllSimultaneously"

            $ContainerNameSingle = "TestS"
            $ContainerNameMultiple1 = "TestM1"
            $ContainerNameMultiple2 = "TestM2"

            $NetworkNameSingle = "TestnetSingle"
            $NetworkNameMultiple1 = "TestnetMulti1"
            $NetworkNameMultiple2 = "TestnetMulti2"

            $NetworkSingle = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.SingleSubnetNetwork.Name
            $NetworkMultiple = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Name

            $SubnetMultiple1 = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Subnets[0]
            $SubnetMultiple2 = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.MultipleSubnetsNetwork.Subnets[1]

            Write-Host "======> Given Docker Driver is running"
            Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $true

            Write-Host "======> When networks are created"
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameSingle -Network $NetworkSingle | Out-Null
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameMultiple1 -Network $NetworkMultiple -Subnet $SubnetMultiple1 | Out-Null
            New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameMultiple2 -Network $NetworkMultiple -Subnet $SubnetMultiple2 | Out-Null

            Write-Host "======> When containers are started"
            New-Container -Session $Session -Name $ContainerNameSingle -NetworkName $NetworkNameSingle | Out-Null
            New-Container -Session $Session -Name $ContainerNameMultiple1 -NetworkName $NetworkNameMultiple1 | Out-Null
            New-Container -Session $Session -Name $ContainerNameMultiple2 -NetworkName $NetworkNameMultiple2 | Out-Null

            Write-Host "======> Then valid network exists"
            Assert-NetworkExists -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameSingle -Network $NetworkSingle
            Assert-NetworkExists -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameMultiple1 -Network $NetworkMultiple -Subnet $SubnetMultiple1
            Assert-NetworkExists -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameMultiple2 -Network $NetworkMultiple -Subnet $SubnetMultiple2

            Write-Host "======> Then containers have valid IP addresses"
            Assert-ContainerHasValidIPAddress -Session $Session -TestConfiguration $TestConfiguration -ContainerName $ContainerNameSingle -Network $NetworkSingle
            Assert-ContainerHasValidIPAddress -Session $Session -TestConfiguration $TestConfiguration -ContainerName $ContainerNameMultiple1 -Network $NetworkMultiple -Subnet $SubnetMultiple1
            Assert-ContainerHasValidIPAddress -Session $Session -TestConfiguration $TestConfiguration -ContainerName $ContainerNameMultiple2 -Network $NetworkMultiple -Subnet $SubnetMultiple2

            Write-Host "======> Cleanup"
            Remove-Container -Session $Session -Name $ContainerNameSingle
            Remove-Container -Session $Session -Name $ContainerNameMultiple1
            Remove-Container -Session $Session -Name $ContainerNameMultiple2
            Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameSingle
            Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameMultiple1
            Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $NetworkNameMultiple2
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "===> PASSED: Test-MultipleNetworksMultipleSubnetsAllSimultaneously"
        })
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        Test-SingleNetworkSingleSubnetDefault -Session $Session -TestConfiguration $TestConfiguration
        Test-SingleNetworkSingleSubnetExplicit -Session $Session -TestConfiguration $TestConfiguration
        Test-SingleNetworkSingleSubnetInvalid -Session $Session -TestConfiguration $TestConfiguration

        Test-SingleNetworkMultipleSubnetsDefault -Session $Session -TestConfiguration $TestConfiguration
        Test-SingleNetworkMultipleSubnetsExplicitFirst -Session $Session -TestConfiguration $TestConfiguration
        Test-SingleNetworkMultipleSubnetsExplicitSecond -Session $Session -TestConfiguration $TestConfiguration
        Test-SingleNetworkMultipleSubnetsInvalid -Session $Session -TestConfiguration $TestConfiguration

        Test-MultipleNetworksMultipleSubnetsAllSimultaneously -Session $Session -TestConfiguration $TestConfiguration
    })
}
