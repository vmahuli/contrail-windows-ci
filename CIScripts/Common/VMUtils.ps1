. $PSScriptRoot\Aliases.ps1

function Get-VMCreds {
    $VMUsername = $Env:VM_USERNAME
    $VMPassword = $Env:VM_PASSWORD | ConvertTo-SecureString -AsPlainText -Force
    return New-Object PSCredentialT($VMUsername, $VMPassword)
}

function New-RemoteSessions {
    Param ([Parameter(Mandatory = $true)] [string[]] $VMNames,
           [Parameter(Mandatory = $true)] [PSCredentialT] $Credentials)

    $Sessions = [System.Collections.ArrayList] @()
    $VMNames.ForEach({
        $Sess = New-PSSession -ComputerName $_ -Credential $Credentials

        Invoke-Command -Session $Sess -ScriptBlock {
            $ErrorActionPreference = "Stop"

            # Refresh PATH
            $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        }

        $Sessions += $Sess
    })

    return $Sessions
}

function New-RemoteSessionsToTestbeds {
    if(-not $Env:TESTBED_HOSTNAMES) {
        throw "Cannot create remote sessions to testbeds: $Env:TESTBED_HOSTNAMES not set"
    }

    # TODO: get IPs from Env
    $Creds = Get-VMCreds

    $Testbeds = Get-TestbedHostnamesFromEnv
    return New-RemoteSessions -VMNames $Testbeds -Credentials $Creds
}

function Get-TestbedHostnamesFromEnv {
    return $Env:TESTBED_HOSTNAMES.Split(",")
}
