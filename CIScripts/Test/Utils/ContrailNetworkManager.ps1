. $PSScriptRoot\ContrailUtils.ps1
. $PSScriptRoot\..\TestConfigurationUtils.ps1

class ContrailNetworkManager {
    [String] $AuthToken;
    [String] $ContrailUrl;
    [String] $DefaultTenantName;

    # We cannot add a type to $Controller parameter,
    # because the class is parsed before the files are sourced.
    ContrailNetworkManager($Controller) {
        
        $this.ContrailUrl = "http://$( $Controller.Rest_API.Address ):$( $Controller.Rest_API.Port )"
        $this.DefaultTenantName = $Controller.Default_Project

        $OSCreds = $Controller.OS_credentials
        $AuthUrl = "http://$( $OSCreds.Address ):$( $OSCreds.Port )/v2.0"

        $this.AuthToken = Get-AccessTokenFromKeystone `
            -AuthUrl $AuthUrl `
            -Username $OSCreds.Username `
            -Password $OSCreds.Password `
            -Tenant 'admin'
    }

    [String] AddProject([String] $TenantName) {
        if (-not $TenantName) {
            $TenantName = $this.DefaultTenantName
        }

        return Add-ContrailProject `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -ProjectName $TenantName
    }

    # TODO support multiple subnets per network
    # TODO return a class (perhaps use the class from MultiTenancy test?)
    # We cannot add a type to $SubnetConfig parameter,
    # because the class is parsed before the files are sourced.
    [String] AddNetwork([String] $TenantName, [String] $Name, $SubnetConfig) {
        if (-not $TenantName) {
            $TenantName = $this.DefaultTenantName
        }

        return Add-ContrailVirtualNetwork `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -TenantName $TenantName `
            -NetworkName $Name `
            -SubnetConfig $SubnetConfig
    }

    RemoveNetwork([String] $Uuid) {
        
        Remove-ContrailVirtualNetwork `
            -ContrailUrl $this.ContrailUrl `
            -AuthToken $this.AuthToken `
            -NetworkUuid $Uuid
    }
}
