. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\TestConfigurationUtils.ps1
. $PSScriptRoot\CommonTestCode.ps1
. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1

class Container {
    [PSObject] $ContainerNetInfo;
    [String] $Name;

    # We cannot add a type to the parameters,
    # because the class is parsed before the files are sourced.
    Container($Session, $Name, $NetworkName, $Image) {
        Write-Log "Creating container: $Name"
        $ContainerID = New-Container -Session $Session -NetworkName $NetworkName `
            -Name $Name -Image $Image

        $this.Name = $Name

        Write-Log "Getting containers' NetAdapter Information"
        $this.ContainerNetInfo = Get-RemoteContainerNetAdapterInformation `
            -Session $Session -ContainerID $ContainerID

        Write-Log $("IP of " + $Name + ":" + $this.ContainerNetInfo.IPAddress)
    }

    [String] GetIPAddress() {
        return $this.ContainerNetInfo.IPAddress
    }

    [String] GetName() {
        return $this.Name
    }
}