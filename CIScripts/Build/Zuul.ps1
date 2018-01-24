. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1

function Clone-ZuulRepos {
    Param (
        [Parameter(Mandatory = $true)] [string] $GerritUrl,
        [Parameter(Mandatory = $true)] [string] $ZuulProject,
        [Parameter(Mandatory = $true)] [string] $ZuulRef,
        [Parameter(Mandatory = $true)] [string] $ZuulUrl,
        [Parameter(Mandatory = $true)] [string] $ZuulBranch
    )

    $ZuulClonerOptions = @(
        "--zuul-project=$ZuulProject",
        "--zuul-ref=$ZuulRef",
        "--zuul-url=$ZuulUrl",
        "--zuul-branch=$ZuulBranch",
        "--map=./CIScripts/clonemap.yml",
        "--verbose",
        $GerritUrl
    )

    # TODO(sodar): Get project list from clonemap.yml
    $ProjectList = @(
        "Juniper/contrail-build",
        "Juniper/contrail-controller",
        "Juniper/contrail-vrouter",
        "Juniper/contrail-generateDS",
        "Juniper/contrail-third-party",
        "Juniper/contrail-sandesh",
        "Juniper/contrail-common"
    )

    $Job.Step("Cloning zuul repositories", {
        Invoke-NativeCommand -ScriptBlock {
            zuul-cloner.exe @ZuulClonerOptions @ProjectList
        }
    })
}

function Clone-NonZuulRepos {
    Param(
        [Parameter(Mandatory = $true)] [string] $DriverSrcPath
    )

    $Job.Step("Cloning additional repositories", {
        $DriverClonePath = $DriverSrcPath -replace "github.com/", "github.com:"

        # TODO: When contrail-windows-docker-driver will be on Gerrit, fetch it with zull-cloner
        Invoke-NativeCommand -ScriptBlock {
            git clone -q "contrail-windows-docker-driver.$DriverClonePath.git" src/$DriverSrcPath
        }
        Write-Host "Cloned docker driver"

        # TODO: Use Juniper repo: git clone contrail-windows.github.com:Juniper/contrail-windows.git
        # TODO: When contrail-windows will be on Gerrit, fetch it with zull-cloner
        Invoke-NativeCommand -ScriptBlock {
            git clone -q https://github.com/codilime/contrail-windowsstubs.git windows/
        }
        Write-Host "Cloned Windows stubs"
    })
}
