. $PSScriptRoot\..\Common\DeferExcept.ps1

function Clone-ZuulRepos {
    $ZuulClonerOptions = @(
        "-m",
        "./CIScripts/clonemap.yml",
        "--verbose",
        $Env:GERRIT_URL
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
        
        # TODO: Uncomment when repo becomes accessible
        # TODO: When contrail-windows-docker-driver will be on Gerrit, fetch it with zull-cloner
        #DeferExcept({
            #git clone -q https://github.com/Juniper/contrail-windows-docker-driver.git src/github.com/codilime/contrail-windows-docker
        #})
        
        # TODO: Uncomment when repo becomes accessible
        # TODO: When contrail-windows will be on Gerrit, fetch it with zull-cloner
        #DeferExcept({
            #git clone -q https://github.com/Juniper/contrail-windows.git windows/
        #})
    })
}