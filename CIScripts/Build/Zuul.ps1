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

    $Job.Step("Cloning repositories", {
        Invoke-NativeCommand -ScriptBlock {
            zuul-cloner.exe @ZuulClonerOptions @ProjectList
        }
        
        # TODO: Use Juniper repo: git clone contrail-windows-docker-driver.github.com:Juniper/contrail-windows-docker-driver.git
        # TODO: When contrail-windows-docker-driver will be on Gerrit, fetch it with zull-cloner
        Invoke-NativeCommand -ScriptBlock {
            git clone -q https://github.com/codilime/contrail-windows-docker.git src/github.com/codilime/contrail-windows-docker
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
