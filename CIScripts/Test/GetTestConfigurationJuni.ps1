function Get-TestConfiguration {
    [TestConfiguration] @{
        ControllerIP = "172.16.0.1";
        ControllerRestPort = 8082;
        ControllerHostUsername = "ubuntu";
        ControllerHostPassword = "ubuntu";
        AdapterName = "Ethernet1";
        VMSwitchName = "Layered Ethernet1";
        VHostName = "vEthernet (HNSTransparent)"
        ForwardingExtensionName = "vRouter forwarding extension";
        AgentConfigFilePath = "C:\ProgramData\Contrail\etc\contrail\contrail-vrouter-agent.conf";
        LinuxVirtualMachineIp = "172.16.0.11";
        DockerDriverConfiguration = [DockerDriverConfiguration] @{
            Username = "admin";
            Password = "c0ntrail123";
            AuthUrl = "http://172.16.0.1:5000/v2.0";
            TenantConfiguration = [TenantConfiguration] @{
                Name = "admin";
                DefaultNetworkName = "testnet1";
                SingleSubnetNetwork = [NetworkConfiguration] @{
                    Name = "testnet1";
                    Subnets = @("10.0.0.0/24");
                }
                MultipleSubnetsNetwork = [NetworkConfiguration] @{
                    Name = "testnet2";
                    Subnets = @("192.168.1.0/24", "192.168.2.0/24");
                }
                NetworkWithPolicy1 = [NetworkConfiguration] @{
                    Name = "testnet3";
                    Subnets = @("10.0.1.0/24");
                }
                NetworkWithPolicy2 = [NetworkConfiguration] @{
                    Name = "testnet4";
                    Subnets = @("10.0.2.0/24");
                }
            }
        }
    }
}

function Get-TestConfigurationWindowsLinux {
    $Configuration = Get-TestConfiguration
    $Configuration.ControllerIP = "10.7.0.216"
    $Configuration.DockerDriverConfiguration.AuthUrl = "http://10.7.0.216:5000/v2.0"
    $Configuration
}

function Get-TestConfigurationUdp {
    $Configuration = Get-TestConfiguration
    $Configuration.ControllerIP = "10.7.0.200"
    $Configuration.DockerDriverConfiguration.AuthUrl = "http://10.7.0.200:5000/v2.0"
    $Configuration
}

function Get-SnatConfiguration {
    [SNATConfiguration] @{
        EndhostIP = "10.7.3.10";
        VethIP = "10.7.3.210";
        GatewayIP = "10.7.3.200";
        ContainerGatewayIP = "10.0.0.1";
        EndhostUsername = "ubuntu";
        EndhostPassword = "ubuntu";
        DiskDir = "C:\contrail-ci\snat-vm-image";
        DiskFileName = "snat-vm-image.vhdx";
        VMDir = "C:\contrail-ci\snat-vm";
    }
}
