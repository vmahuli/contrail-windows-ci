. $PSScriptRoot\..\Build\Repository.ps1

function Get-StagingRepos {
    Param ([Parameter(Mandatory = $true)] [string] $DriverBranch,
           [Parameter(Mandatory = $true)] [string] $WindowsstubsBranch,
           [Parameter(Mandatory = $true)] [string] $ToolsBranch,
           [Parameter(Mandatory = $true)] [string] $SandeshBranch,
           [Parameter(Mandatory = $true)] [string] $GenerateDSBranch,
           [Parameter(Mandatory = $true)] [string] $VRouterBranch,
           [Parameter(Mandatory = $true)] [string] $ControllerBranch)

    # $Repos = @{
    #     "contrail-windows-docker" = [Repo]::new("https://github.com/codilime/contrail-windows-docker/",
    #                                             $DriverBranch, "master", "src/github.com/codilime/contrail-windows-docker");
    #     "contrail-windowsstubs" = [Repo]::new("https://github.com/codilime/contrail-windowsstubs/",
    #                                           $WindowsstubsBranch, "windows", "windows/");
    #     "contrail-build" = [Repo]::new("https://github.com/codilime/contrail-build",
    #                                    $ToolsBranch, "windows", "tools/build/");
    #     "contrail-sandesh" = [Repo]::new("https://github.com/codilime/contrail-sandesh",
    #                                      $SandeshBranch, "windows", "tools/sandesh/");
    #     "contrail-generateDS" = [Repo]::new("https://github.com/codilime/contrail-generateDS",
    #                                         $GenerateDSBranch, "windows", "tools/generateDS/");
    #     "contrail-vrouter" = [Repo]::new("https://github.com/codilime/contrail-vrouter",
    #                                      $VRouterBranch, "windows", "vrouter/");
    #     "contrail-controller" = [Repo]::new("https://github.com/codilime/contrail-controller",
    #                                         $ControllerBranch, "windows3.1", "controller/")
    # }

    # Temporary workaround for GitHub connectivity issues.
    $Repos = @{
        "contrail-windows-docker" = [Repo]::new("http://10.7.0.91/codilime/contrail-windows-docker.git",
                                                $DriverBranch, "master", "src/github.com/codilime/contrail-windows-docker");
        "contrail-windowsstubs" = [Repo]::new("http://10.7.0.91/codilime/contrail-windowsstubs.git",
                                              $WindowsstubsBranch, "windows", "windows/");
        "contrail-build" = [Repo]::new("http://10.7.0.91/codilime/contrail-build.git",
                                       $ToolsBranch, "windows", "tools/build/");
        "contrail-sandesh" = [Repo]::new("http://10.7.0.91/codilime/contrail-sandesh.git",
                                         $SandeshBranch, "windows", "tools/sandesh/");
        "contrail-generateDS" = [Repo]::new("http://10.7.0.91/codilime/contrail-generateDS.git",
                                            $GenerateDSBranch, "windows", "tools/generateDS/");
        "contrail-vrouter" = [Repo]::new("http://10.7.0.91/codilime/contrail-vrouter.git",
                                         $VRouterBranch, "windows", "vrouter/");
        "contrail-controller" = [Repo]::new("http://10.7.0.91/codilime/contrail-controller.git",
                                            $ControllerBranch, "windows3.1", "controller/")
    }
    
    return $Repos
}
