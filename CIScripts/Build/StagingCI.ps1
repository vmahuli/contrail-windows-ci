. $PSScriptRoot\..\Build\Repository.ps1

function Get-StagingRepos {
    Param ([Parameter(Mandatory = $true)] [string] $DriverBranch,
           [Parameter(Mandatory = $true)] [string] $WindowsstubsBranch,
           [Parameter(Mandatory = $true)] [string] $ToolsBranch,
           [Parameter(Mandatory = $true)] [string] $SandeshBranch,
           [Parameter(Mandatory = $true)] [string] $GenerateDSBranch,
           [Parameter(Mandatory = $true)] [string] $VRouterBranch,
           [Parameter(Mandatory = $true)] [string] $ControllerBranch)

    $Repos = @{
        "contrail-windows-docker" = [Repo]::new("https://github.com/CodiLime/contrail-windows-docker/",
                                                $DriverBranch, "master", "src/github.com/codilime/contrail-windows-docker");
        "contrail-windowsstubs" = [Repo]::new("https://github.com/CodiLime/contrail-windowsstubs/",
                                              $WindowsstubsBranch, "windows", "windows/");
        "contrail-build" = [Repo]::new("https://github.com/CodiLime/contrail-build",
                                       $ToolsBranch, "windows", "tools/build/");
        "contrail-sandesh" = [Repo]::new("https://github.com/CodiLime/contrail-sandesh",
                                         $SandeshBranch, "windows", "tools/sandesh/");
        "contrail-generateDS" = [Repo]::new("https://github.com/CodiLime/contrail-generateDS",
                                            $GenerateDSBranch, "windows", "tools/generateDS/");
        "contrail-vrouter" = [Repo]::new("https://github.com/CodiLime/contrail-vrouter",
                                         $VRouterBranch, "windows", "vrouter/");
        "contrail-controller" = [Repo]::new("https://github.com/CodiLime/contrail-controller",
                                            $ControllerBranch, "windows3.1", "controller/")
    }
    return $Repos
}
