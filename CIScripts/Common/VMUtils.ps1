. $PSScriptRoot\Aliases.ps1

function Get-TestbedCredential {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText",
        "", Justification="This are just credentials to a testbed VM.")]
    param()
    if(-not $Env:TESTBED_USR) {
        return Get-Credential # assume interactive mode
    } else {
        $VMUsername = Get-UsernameInWorkgroup -Username $Env:TESTBED_USR
        $VMPassword = $Env:TESTBED_PSW | ConvertTo-SecureString -AsPlainText -Force
        return New-Object PSCredentialT($VMUsername, $VMPassword)
    }
}

function Get-MgmtCreds {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText",
    "", Justification="This env var is injected by Jenkins.")]
    param()
    $Username = Get-UsernameInWorkgroup -Username $Env:WINCIDEV_USR
    $Password = $Env:WINCIDEV_PSW | ConvertTo-SecureString -asPlainText -Force
    return New-Object PSCredentialT ($Username, $Password)
}

function Get-UsernameInWorkgroup {
    Param ([Parameter(Mandatory = $true)] [string] $Username)
    return "WORKGROUP\{0}" -f $Username
}

function New-RemoteSessions {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "Creds",
        Justification="Complains that it's plaintext. It's not.")]
    Param ([Parameter(Mandatory = $true)] [string[]] $VMNames,
           [Parameter(Mandatory = $true)] [PSCredentialT] $Creds)

    $Sessions = [System.Collections.ArrayList] @()
    $VMNames.ForEach({
        $Sess = New-PSSession -ComputerName $_ -Credential $Creds

        Invoke-Command -Session $Sess -ScriptBlock {
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            # Refresh PATH
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification="We refresh PATH on remote machine, we don't use it here.")]
            $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        }

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="Issue #804 from PSScriptAnalyzer GitHub")]
        $Sessions += $Sess
    })
    return $Sessions
}

function New-RemoteSessionsToTestbeds {
    if(-not $Env:TESTBED_ADDRESSES) {
        throw "Cannot create remote sessions to testbeds: $Env:TESTBED_ADDRESSES not set"
    }
    $Creds = Get-TestbedCredential
    $Testbeds = Get-TestbedAddressesFromEnv
    return New-RemoteSessions -VMNames $Testbeds -Creds $Creds
}

function Get-TestbedAddressesFromEnv {
    return $Env:TESTBED_ADDRESSES.Split(",")
}
