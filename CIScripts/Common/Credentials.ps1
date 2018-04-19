. $PSScriptRoot\Aliases.ps1

# Create PSCredentialT alias
$AccelPSCredentialT = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$AccelPSCredentialT::add("PSCredentialT", "System.Management.Automation.PSCredential")

function Get-UsernameInWorkgroup {
    Param ([Parameter(Mandatory = $true)] [string] $Username)
    return "WORKGROUP\{0}" -f $Username
}

function Get-MgmtCreds {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText",
    "", Justification="This env var is injected by Jenkins.")]
    param()
    $Username = Get-UsernameInWorkgroup -Username $Env:WINCIDEV_USR
    $Password = $Env:WINCIDEV_PSW | ConvertTo-SecureString -asPlainText -Force
    return New-Object PSCredentialT ($Username, $Password)
}
