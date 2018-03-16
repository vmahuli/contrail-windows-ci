. $PSScriptRoot\ContrailUtils.ps1
. $PSScriptRoot\..\TestConfigurationUtils.ps1

class ContrailNetworkManager {
    [String] $AuthToken;
    [String] $ContrailUrl;
    [String] $DefaultTenantName;

    # We cannot add a type to the parameters,
    # because the class is parsed before the files are sourced.
    ContrailNetworkManager($OpenStackConfig, $ControllerConfig) {
        
        $this.ContrailUrl = $ControllerConfig.RestApiUrl()
        $this.DefaultTenantName = $ControllerConfig.DefaultProject

        $this.AuthToken = Get-AccessTokenFromKeystone `
            -AuthUrl $OpenStackConfig.AuthUrl() `
            -Username $OpenStackConfig.Username `
            -Password $OpenStackConfig.Password `
            -Tenant $OpenStackConfig.Project
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
