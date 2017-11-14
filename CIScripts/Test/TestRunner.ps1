. $PSScriptRoot\TestConfigurationUtils.ps1

. $PSScriptRoot\Tests\AgentServiceTests.ps1
. $PSScriptRoot\Tests\AgentTests.ps1
. $PSScriptRoot\Tests\ExtensionLongLeakTest.ps1
. $PSScriptRoot\Tests\MultiEnableDisableExtensionTest.ps1
. $PSScriptRoot\Tests\DockerDriverTest.ps1
. $PSScriptRoot\Tests\VTestScenariosTest.ps1
. $PSScriptRoot\Tests\TCPCommunicationTest.ps1
. $PSScriptRoot\Tests\ICMPoMPLSoGRETest.ps1
. $PSScriptRoot\Tests\TCPoMPLSoGRETest.ps1
. $PSScriptRoot\Tests\SNATTest.ps1
. $PSScriptRoot\Tests\VRouterAgentTests.ps1
. $PSScriptRoot\Tests\ComputeControllerIntegrationTests.ps1
. $PSScriptRoot\Tests\SubnetsTests.ps1
. $PSScriptRoot\Tests\Pkt0PipeImplementationTests.ps1
. $PSScriptRoot\Tests\DockerDriverMultitenancyTest.ps1

function Run-Tests {
    Param ([Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions)

    $Job.Step("Running all integration tests", {

        $SingleSubnetNetworkConfiguration = [NetworkConfiguration] @{
            Name = $Env:SINGLE_SUBNET_NETWORK_NAME
            Subnets = @($Env:SINGLE_SUBNET_NETWORK_SUBNET)
        }

        $MultipleSubnetsNetworkConfiguration = [NetworkConfiguration] @{
            Name = $Env:MULTIPLE_SUBNETS_NETWORK_NAME
            Subnets = @($Env:MULTIPLE_SUBNETS_NETWORK_SUBNET1, $Env:MULTIPLE_SUBNETS_NETWORK_SUBNET2)
        }

        $NetworkWithPolicy1Configuration = [NetworkConfiguration] @{
            Name = $Env:NETWORK_WITH_POLICY_1_NAME
            Subnets = @($Env:NETWORK_WITH_POLICY_1_SUBNET)
        }

        $NetworkWithPolicy2Configuration = [NetworkConfiguration] @{
            Name = $Env:NETWORK_WITH_POLICY_2_NAME
            Subnets = @($Env:NETWORK_WITH_POLICY_2_SUBNET)
        }

        $TenantConfiguration = [TenantConfiguration] @{
            Name = $Env:DOCKER_NETWORK_TENANT_NAME;
            DefaultNetworkName = $SingleSubnetNetworkConfiguration.Name;
            SingleSubnetNetwork = $SingleSubnetNetworkConfiguration;
            MultipleSubnetsNetwork = $MultipleSubnetsNetworkConfiguration;
            NetworkWithPolicy1 = $NetworkWithPolicy1Configuration;
            NetworkWithPolicy2 = $NetworkWithPolicy2Configuration;
        }

        $DockerDriverConfiguration = [DockerDriverConfiguration] @{
            Username = $Env:DOCKER_DRIVER_USERNAME;
            Password = $Env:DOCKER_DRIVER_PASSWORD;
            AuthUrl = $Env:DOCKER_DRIVER_AUTH_URL;
            TenantConfiguration = $TenantConfiguration;
        }

        $TestConfiguration = [TestConfiguration] @{
            ControllerIP = $Env:CONTROLLER_IP;
            ControllerRestPort = 8082
            ControllerHostUsername = $Env:CONTROLLER_HOST_USERNAME;
            ControllerHostPassword = $Env:CONTROLLER_HOST_PASSWORD;
            AdapterName = $Env:ADAPTER_NAME;
            VMSwitchName = "Layered " + $Env:ADAPTER_NAME;
            VHostName = "vEthernet (HNSTransparent)"
            ForwardingExtensionName = $Env:FORWARDING_EXTENSION_NAME;
            AgentConfigFilePath = "C:\ProgramData\Contrail\etc\contrail\contrail-vrouter-agent.conf";
            DockerDriverConfiguration = $DockerDriverConfiguration;
        }

        $SNATConfiguration = [SNATConfiguration] @{
            EndhostIP = $Env:SNAT_ENDHOST_IP;
            VethIP = $Env:SNAT_VETH_IP;
            GatewayIP = $Env:SNAT_GATEWAY_IP;
            ContainerGatewayIP = $Env:SNAT_CONTAINER_GATEWAY_IP;
            EndhostUsername = $Env:SNAT_ENDHOST_USERNAME;
            EndhostPassword = $Env:SNAT_ENDHOST_PASSWORD;
            DiskDir = $Env:SNAT_DISK_DIR;
            DiskFileName = $Env:SNAT_DISK_FILE_NAME;
            VMDir = $Env:SNAT_VM_DIR;
        }

        Test-AgentService -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-Agent -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-ExtensionLongLeak -Session $Sessions[0] -TestDurationHours $Env:LEAK_TEST_DURATION -TestConfiguration $TestConfiguration
        Test-MultiEnableDisableExtension -Session $Sessions[0] -EnableDisableCount $Env:MULTI_ENABLE_DISABLE_EXTENSION_COUNT -TestConfiguration $TestConfiguration
        Test-VTestScenarios -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-TCPCommunication -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-ICMPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
        Test-TCPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
        # TODO: Uncomment after JW-1129
        # Test-SNAT -Session $Sessions[0] -SNATConfiguration $SNATConfiguration -TestConfiguration $TestConfiguration
        Test-VRouterAgentIntegration -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
        Test-ComputeControllerIntegration -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-MultipleSubnetsSupport -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-DockerDriverMultiTenancy -Session $Sessions[0] -TestConfiguration $TestConfiguration
        Test-Pkt0PipeImplementation -Session $Sessions[0] -TestConfiguration $TestConfiguration

        if($Env:RUN_DRIVER_TESTS -eq "1") {
            Test-DockerDriver -Session $Sessions[0] -TestConfiguration $TestConfiguration
        }
    })
}
