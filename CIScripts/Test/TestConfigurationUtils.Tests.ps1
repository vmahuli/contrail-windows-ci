. $PSScriptRoot\..\Common\Init.ps1
. $PSScriptRoot\TestConfigurationUtils.ps1

Describe "Select-ValidNetIPInterface unit tests" -Tags CI, Unit {
    Context "Single valid/invalid Get-NetIPAddress output" {
        It "Both AddressFamily and SuffixOrigin match" {
            $ValidGetNetIPAddress = @{ AddressFamily = "IPv4"; SuffixOrigin = @("Dhcp", "Manual") } 
            $ValidGetNetIPAddress | Select-ValidNetIPInterface | Should Be $ValidGetNetIPAddress
        }
        It "One or all attributes don't match" {
            $InvalidCases = @( 
                @{ AddressFamily = "IPv4"; SuffixOrigin = @("WellKnown", "Link", "Random") },
                @{ AddressFamily = "IPv6"; SuffixOrigin = @("Dhcp", "Manual") }, 
                @{ AddressFamily = "IPv6"; SuffixOrigin = @("WellKnown", "Link", "Random") }
            )

            foreach($InvalidCase in $InvalidCases) {
                $InvalidCase | Select-ValidNetIPInterface | Should BeNullOrEmpty
            }
        }
    }
    Context "Get-NetIPAddress returns an array" {
        It "Pass valid/invalid object combinations into pipeline" {
            $InvalidGetNetIPAddress = @{
                AddressFamily = "IPv4";
                SuffixOrigin = @("WellKnown", "Link", "Random")
            }
            $ValidGetNetIPAddress = @{
                AddressFamily = "IPv4";
                SuffixOrigin = @("Dhcp", "Manual")
            }

            @( $InvalidGetNetIPAddress, $ValidGetNetIPAddress ) | `
            Select-ValidNetIPInterface | Should Be $ValidGetNetIPAddress

            @( $ValidGetNetIPAddress, $InvalidGetNetIPAddress ) | `
            Select-ValidNetIPInterface | Should Be $ValidGetNetIPAddress

            @( $InvalidGetNetIPAddress, $InvalidGetNetIPAddress ) | `
            Select-ValidNetIPInterface | Should BeNullOrEmpty
        }
    }
}
