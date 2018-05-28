. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1

function Get-NonZuulRepos {
    Param(
        [Parameter(Mandatory = $true)] [string] $DriverSrcPath,
        [Parameter(Mandatory = $true)] [string] $DriverBranch,
        [Parameter(Mandatory = $true)] [string] $WindowsStubsRepositoryPath,
        [Parameter(Mandatory = $true)] [string] $WindowsStubsBranch
    )

    $Job.Step("Cloning additional repositories", {
        # TODO: Use Juniper repo: git clone contrail-windows.github.com:Juniper/contrail-windows.git
        # TODO: When contrail-windows will be on Gerrit, fetch it with zull-cloner
        Invoke-NativeCommand -ScriptBlock {
            git clone $WindowsStubsRepositoryPath -b $WindowsStubsBranch windows/
        }
        Write-Host "Cloned Windows stubs"
    })
}
