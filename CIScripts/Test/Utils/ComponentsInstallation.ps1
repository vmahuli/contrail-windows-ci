. $PSScriptRoot\..\..\Common\Aliases.ps1

function Invoke-MsiExec {
    Param (
        [Switch] $Uninstall,
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [String] $Path
    )

    $Action = if ($Uninstall) { "/x" } else { "/i" }

    Invoke-Command -Session $Session -ScriptBlock {
        $Result = Start-Process msiexec.exe -ArgumentList @($Using:Action, $Using:Path, "/quiet") `
            -Wait -PassThru
        if ($Result.ExitCode -ne 0) {
            throw "Installation of $Using:Path failed with $($Result.ExitCode)"
        }

        # Refresh Path
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }
}

function Install-Agent {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    # Get rid of all leftover handles to the Agent service
    Invoke-Command -Session $Session -ScriptBlock {
        [System.GC]::Collect()
    }

    Write-Host "Installing Agent"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\contrail-vrouter-agent.msi"
}

function Uninstall-Agent {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Uninstalling Agent"
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\contrail-vrouter-agent.msi"

    # Get rid of all leftover handles to the Agent service
    Invoke-Command -Session $Session -ScriptBlock {
        [System.GC]::Collect()
    }

}

function Install-Extension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Installing vRouter Forwarding Extension"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\vRouter.msi"
}

function Uninstall-Extension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Uninstalling vRouter Forwarding Extension"
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\vRouter.msi"
}

function Install-Utils {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Installing vRouter utility tools"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\utils.msi"
}

function Uninstall-Utils {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Uninstalling vRouter utility tools"
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\utils.msi"
}

function Install-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Installing Docker Driver"
    Invoke-MsiExec -Session $Session -Path "C:\Artifacts\docker-driver.msi"
}

function Uninstall-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Uninstalling Docker Driver"
    Invoke-MsiExec -Uninstall -Session $Session -Path "C:\Artifacts\docker-driver.msi"
}
