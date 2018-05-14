. $PSScriptRoot\..\..\Utils\Container.ps1

. $PSScriptRoot\..\..\TestPrimitives\TestTCP.ps1
. $PSScriptRoot\..\..\TestPrimitives\TestUDP.ps1
. $PSScriptRoot\..\..\TestPrimitives\TestPing.ps1
. $PSScriptRoot\..\..\TestPrimitives\TestEncapsulation.ps1

Context "Tunneling with Agent" {
    $IisTcpTestDockerImage = "iis-tcptest"
    $Container1Name = "jolly-lumberjack"
    $Container2Name = "juniper-tree"
    $NetworkName = "testnet12"
    $Subnet = [SubnetConfiguration]::new(
        "10.0.5.0",
        24,
        "10.0.5.1",
        "10.0.5.19",
        "10.0.5.83"
    )

    It "ICMP - Ping between containers on separate compute nodes succeeds" {
        Test-Ping `
            -Session $Sessions[0] `
            -SrcContainerName $Container1.GetName() `
            -DstContainerName $Container2.GetName() `
            -DstContainerIP $Container2.GetIPAddress() | Should Be 0

        Test-Ping `
            -Session $Sessions[1] `
            -SrcContainerName $Container2.GetName() `
            -DstContainerName $Container1.GetName() `
            -DstContainerIP $Container1.GetIPAddress() | Should Be 0
    }

    It "TCP - HTTP connection between containers on separate compute nodes succeeds" {
        Test-TCP `
            -Session $Sessions[1] `
            -SrcContainerName $Container2.GetName() `
            -DstContainerName $Container1.GetName() `
            -DstContainerIP $Container1.GetIPAddress() | Should Be 0
    }

    It "UDP" {
        $MyMessage = "We are Tungsten Fabric. We come in peace."
        $UDPServerPort = 1905
        $UDPClientPort = 1983

        Test-UDP `
            -Session1 $Sessions[0] `
            -Session2 $Sessions[1] `
            -Container1Name $Container1.GetName() `
            -Container2Name $Container2.GetName() `
            -Container1IP $Container1.GetIPAddress() `
            -Container2IP $Container2.GetIPAddress() `
            -Message $MyMessage `
            -UDPServerPort $UDPServerPort `
            -UDPClientPort $UDPClientPort | Should Be $true
    }

    BeforeEach {
        Write-Log "Creating virtual network: $NetworkName"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNetwork",
            Justification = "It's actually used."
        )]
        $ContrailNetwork = $ContrailNM.AddNetwork($null, $NetworkName, $Subnet)

        foreach ($Session in $Sessions) {
            $NetworkID = New-DockerNetwork -Session $Session `
                -TenantName $ControllerConfig.DefaultProject `
                -Name $NetworkName `
                -Subnet "$( $Subnet.IpPrefix )/$( $Subnet.IpPrefixLen )"
            Write-Log "Created network id: $NetworkID"
        }

        Write-Log "Creating containers"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container1",
            Justification = "It's actually used."
        )]
        $Container1 = [Container]::new($Sessions[0], $Container1Name, $NetworkName, $IisTcpTestDockerImage)

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container2",
            Justification = "It's actually used."
        )]
        $Container2 = [Container]::new($Sessions[1], $Container2Name, $NetworkName, $IisTcpTestDockerImage)
    }

    AfterEach {
        Write-Log "Removing all containers"
        Remove-AllContainers -Sessions $Sessions
        foreach ($Session in $Sessions) {
            Remove-AllUnusedDockerNetworks -Session $Session
        }

        Write-Log "Deleting virtual network"
        if (Get-Variable ContrailNetwork -ErrorAction SilentlyContinue) {
            $ContrailNM.RemoveNetwork($ContrailNetwork)
        }
    }
}
