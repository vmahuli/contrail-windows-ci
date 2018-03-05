. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1

function Get-NonZuulRepos {
    Param(
        [Parameter(Mandatory = $true)] [string] $DriverSrcPath,
        [Parameter(Mandatory = $true)] [string] $DriverBranch,
        [Parameter(Mandatory = $true)] [string] $WindowsStubsRepositoryPath,
        [Parameter(Mandatory = $true)] [string] $WindowsStubsBranch
    )

    $Job.Step("Cloning additional repositories", {
        $DriverClonePath = $DriverSrcPath -replace "github.com/", "github.com:"

        # TODO: When contrail-windows-docker-driver will be on Gerrit, fetch it with zull-cloner
        Invoke-NativeCommand -ScriptBlock {
            git clone "contrail-windows-docker-driver.$DriverClonePath.git" -b $DriverBranch src/$DriverSrcPath
        }
        Write-Host "Cloned docker driver"

        # TODO: Use Juniper repo: git clone contrail-windows.github.com:Juniper/contrail-windows.git
        # TODO: When contrail-windows will be on Gerrit, fetch it with zull-cloner
        Invoke-NativeCommand -ScriptBlock {
            git clone $WindowsStubsRepositoryPath -b $WindowsStubsBranch windows/
        }
        Write-Host "Cloned Windows stubs"
    })
}
