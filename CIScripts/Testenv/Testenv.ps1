class OpenStackConfig {
    [string] $Username
    [string] $Password
    [string] $Project
    [string] $Address
    [int] $Port

    [string] AuthUrl() {
        return "http://$( $this.Address ):$( $this.Port )/v2.0"
    }
}

class ControllerConfig {
    [string] $Address
    [int] $RestApiPort
    [string] $DefaultProject

    [string] RestApiUrl() {
        return "http://$( $this.Address ):$( $this.RestApiPort )"
    }
}

class SystemConfig {
    [string] $AdapterName;
    [string] $VHostName;
    [string] $ForwardingExtensionName;
    [string] $AgentConfigFilePath;

    [string] VMSwitchName() {
        return "Layered " + $this.AdapterName
    }
}

function Read-OpenStackConfig {
    Param ([Parameter(Mandatory=$true)] [string] $Path)
    $FileContents = Get-Content -Path $Path -Raw
    $Parsed = ConvertFrom-Yaml $FileContents
    return [OpenStackConfig] $Parsed.OpenStack
}

function Read-ControllerConfig {
    Param ([Parameter(Mandatory=$true)] [string] $Path)
    $FileContents = Get-Content -Path $Path -Raw
    $Parsed = ConvertFrom-Yaml $FileContents
    return [ControllerConfig] $Parsed.Controller
}

function Read-SystemConfig {
    Param ([Parameter(Mandatory=$true)] [string] $Path)
    $FileContents = Get-Content -Path $Path -Raw
    $Parsed = ConvertFrom-Yaml $FileContents
    return [SystemConfig] $Parsed.System
}

function Read-TestbedsConfig {
    Param ([Parameter(Mandatory=$true)] [string] $Path)
    $FileContents = Get-Content -Path $Path -Raw
    $Parsed = ConvertFrom-Yaml $FileContents
    $Testbeds = $Parsed.Testbeds
    # The comma forces return value to always be array
    return ,$Testbeds
}
