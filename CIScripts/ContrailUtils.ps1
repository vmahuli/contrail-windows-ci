function Get-AccessTokenFromKeyStone {
    Param ([Parameter(Mandatory = $true)] [string] $AuthUrl,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $UserName,
           [Parameter(Mandatory = $true)] [string] $Password)

    $Request = @{
        auth = @{
            tenantName          = $TenantName
            passwordCredentials = @{
                username = $UserName
                password = $Password
            }
        }
    }

    $AuthUrl += "/v2.0/tokens"
    $Response = Invoke-RestMethod -Uri $AuthUrl -Method Post -ContentType "application/json" `
        -Body (ConvertTo-Json $Request)
    return $Response.access.token.id
}

class SubnetConfiguration {
    [string] $IpPrefix;
    [int] $IpPrefixLen;
    [string] $DefaultGateway;
    [string] $AllocationPoolsStart;
    [string] $AllocationPoolsEnd;

    SubnetConfiguration([string] $IpPrefix, [int] $IpPrefixLen,
        [string] $DefaultGateway, [string] $AllocationPoolsStart,
        [string] $AllocationPoolsEnd) {
        $this.IpPrefix = $IpPrefix
        $this.IpPrefixLen = $IpPrefixLen
        $this.DefaultGateway = $DefaultGateway;
        $this.AllocationPoolsStart = $AllocationPoolsStart;
        $this.AllocationPoolsEnd = $AllocationPoolsEnd;
    }
}

function Add-OpenContrailNetwork {
    Param ([Parameter(Mandatory = $true)] [string] $OpenContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $TenantName,
           [Parameter(Mandatory = $true)] [string] $NetworkName,
           [Parameter(Mandatory = $false)] [SubnetConfiguration] $SubnetConfig `
               = [SubnetConfiguration]::new("10.0.0.0", 24, "10.0.0.1", "10.0.0.100", "10.0.0.200"))

    $Subnet = @{
        subnet           = @{
            ip_prefix     = $SubnetConfig.IpPrefix
            ip_prefix_len = $SubnetConfig.IpPrefixLen
        }
        addr_from_start  = $true
        enable_dhcp      = $true
        default_gateway  = $SubnetConfig.DefaultGateway
        allocation_pools = @(@{
                start = $SubnetConfig.AllocationPoolsStart
                end   = $SubnetConfig.AllocationPoolsEnd
            })
    }

    $NetworkImap = @{
        attr = @{
            ipam_subnets = @($Subnet)
        }
        to   = @("default-domain", "default-project", "default-network-ipam")
    }

    $Request = @{
        "virtual-network" = @{
            parent_type       = "project"
            fq_name           = @("default-domain", $TenantName, $NetworkName)
            network_ipam_refs = @($NetworkImap)
        }
    }

    $RequestUrl = $OpenContrailUrl + "/virtual-networks"
    $Response = Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} `
        -Method Post -ContentType "application/json" -Body (ConvertTo-Json -Depth 10 $Request) `

    return $Response.'virtual-network'.'uuid'
}

function Remove-OpenContrailNetwork {
    Param ([Parameter(Mandatory = $true)] [string] $OpenContrailUrl,
           [Parameter(Mandatory = $true)] [string] $AuthToken,
           [Parameter(Mandatory = $true)] [string] $NetworkUuid)

    $RequestUrl = $OpenContrailUrl + "/virtual-network/" + $NetworkUuid
    Invoke-RestMethod -Uri $RequestUrl -Headers @{"X-Auth-Token" = $AuthToken} -Method Delete
}
