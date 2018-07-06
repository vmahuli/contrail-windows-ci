. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1

function Get-ZuulRepos {
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
        $GerritUrl
    )

    # TODO(sodar): Get project list from clonemap.yml
    $ProjectList = @(
        "Juniper/contrail-api-client",
        "Juniper/contrail-build",
        "Juniper/contrail-controller",
        "Juniper/contrail-vrouter",
        "Juniper/contrail-third-party",
        "Juniper/contrail-common",
        "Juniper/contrail-windows-docker-driver",
        "Juniper/contrail-windows"
    )

    $Job.Step("Cloning zuul repositories", {
        Invoke-NativeCommand -ScriptBlock {
            zuul-cloner.exe @ZuulClonerOptions @ProjectList
        }
    })
}
