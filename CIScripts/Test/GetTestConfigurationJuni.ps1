function Get-TestConfiguration {
    [TestConfiguration] @{
        AdapterName = "Ethernet1";
        VMSwitchName = "Layered Ethernet1";
        VHostName = "vEthernet (HNSTransparent)"
        ForwardingExtensionName = "vRouter forwarding extension";
        AgentConfigFilePath = "C:\ProgramData\Contrail\etc\contrail\contrail-vrouter-agent.conf";
    }
}
