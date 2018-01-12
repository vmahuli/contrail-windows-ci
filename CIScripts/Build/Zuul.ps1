. $PSScriptRoot\..\Common\DeferExcept.ps1

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

    $Job.Step("Cloning repositories", {
        DeferExcept({
            zuul-cloner.exe @ZuulClonerOptions @ProjectList
        })
        
        # TODO: Use Juniper repo
        # TODO: When contrail-windows-docker-driver will be on Gerrit, fetch it with zull-cloner
        DeferExcept({
            git clone -q https://github.com/codilime/contrail-windows-docker.git src/github.com/codilime/contrail-windows-docker
        })
        Write-Host "Cloned docker driver"

        # TODO: Use Juniper repo
        # TODO: When contrail-windows will be on Gerrit, fetch it with zull-cloner
        DeferExcept({
            git clone -q https://github.com/codilime/contrail-windowsstubs.git windows/
        })
        Write-Host "Cloned Windows stubs"
    })
}