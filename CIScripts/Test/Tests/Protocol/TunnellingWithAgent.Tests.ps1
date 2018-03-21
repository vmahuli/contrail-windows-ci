Describe "Tunnelling with Agent tests" {

    Context "MPLSoGRE" {
        It "ICMP" -Pending {
            # Test-ICMPoMPLSoGRE
        }

        It "TCP" -Pending {
            # Test-MultihostTcpTraffic
            # TODO: Is this actually correct test for MPLSoGRE?
        }

        It "UDP" -Pending {
            # Test-MultihostUdpTraffic
            # TODO: Is this actually correct test for MPLSoGRE?
        }
    }

    Context "MPLSoUDP" {
        It "ICMP" -Pending {
            # Test-ICMPoMPLSoUDP
        }
    }
}
