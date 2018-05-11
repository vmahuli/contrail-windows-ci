Context "Tunneling" {
    $IisTcpTestDockerImage = "iis-tcptest"
    $Container1ID = "jolly-lumberjack"
    $Container2ID = "juniper-tree"
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
            -SrcContainerName $Container1ID `
            -DstContainerName $Container2ID `
            -DstContainerIP $Container2NetInfo.IPAddress | Should Be 0

        Test-Ping `
            -Session $Sessions[1] `
            -SrcContainerName $Container2ID `
            -DstContainerName $Container1ID `
            -DstContainerIP $Container1NetInfo.IPAddress | Should Be 0
    }

    It "TCP - HTTP connection between containers on separate compute nodes succeeds" {
        Test-TCP `
            -Session $Sessions[1] `
            -SrcContainerName $Container2ID `
            -DstContainerName $Container1ID `
            -DstContainerIP $Container1NetInfo.IPAddress | Should Be 0
    }

    It "UDP" {
        $MyMessage = "We are Tungsten Fabric. We come in peace."
        $UDPServerPort = 1905
        $UDPClientPort = 1983

        Test-UDP `
            -Session1 $Sessions[0] `
            -Session2 $Sessions[1] `
            -Container1Name $Container1ID `
            -Container2Name $Container2ID `
            -Container1IP $Container1NetInfo.IPAddress `
            -Container2IP $Container2NetInfo.IPAddress `
            -Message $MyMessage `
            -UDPServerPort $UDPServerPort `
            -UDPClientPort $UDPClientPort | Should Be $true
    }

    BeforeEach {
        Write-Log "Creating virtual network: $NetworkName"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNetwork",
            Justification="It's actually used."
        )]
        #$ContrailNetwork = $ContrailNM.AddNetwork($null, $NetworkName, $Subnet)

        $NetworkID = New-DockerNetwork -Session $Sessions[0] `
            -TenantName $ControllerConfig.DefaultProject `
            -Name $NetworkName `
            -Subnet "$( $Subnet.IpPrefix )/$( $Subnet.IpPrefixLen )"

        Write-Log "Created network id: $NetworkID"
        $NetworkID = New-DockerNetwork -Session $Sessions[1] `
            -TenantName $ControllerConfig.DefaultProject `
            -Name $NetworkName `
            -Subnet "$( $Subnet.IpPrefix )/$( $Subnet.IpPrefixLen )"

        Write-Log "Created network id: $NetworkID"

        Write-Log "Creating containers"
        Write-Log "Creating container: $Container1ID"
        New-Container `
            -Session $Sessions[0] `
            -NetworkName $NetworkName `
            -Name $Container1ID `
            -Image $IisTcpTestDockerImage
        Write-Log "Creating container: $Container2ID"
        New-Container `
            -Session $Sessions[1] `
            -NetworkName $NetworkName `
            -Name $Container2ID `
            -Image "microsoft/windowsservercore"

        Write-Log "Getting containers' NetAdapter Information"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container1NetInfo",
            Justification="It's actually used."
        )]
        $Container1NetInfo = Get-RemoteContainerNetAdapterInformation `
            -Session $Sessions[0] -ContainerID $Container1ID
        $IP = $Container1NetInfo.IPAddress
        Write-Log "IP of ${Container1ID}: $IP"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "Container2NetInfo",
            Justification="It's actually used."
        )]
        $Container2NetInfo = Get-RemoteContainerNetAdapterInformation `
            -Session $Sessions[1] -ContainerID $Container2ID
            $IP = $Container2NetInfo.IPAddress
            Write-Log "IP of ${Container2ID}: $IP"
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