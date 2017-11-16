class Repo {
    [string] $Url;
    [string] $Branch;
    [string] $Dir;
    [string] $DefaultBranch;

    Repo ([string] $Url, [string] $Branch, [string] $Dir, [string] $DefaultBranch) {
        $this.Url = $Url
        $this.Branch = $Branch
        $this.Dir = $Dir
        $this.DefaultBranch = $DefaultBranch
    }
}

function Copy-Repos {
    Param ([Parameter(Mandatory = $true, HelpMessage = "List of repos to clone")] [Repo[]] $Repos)

    $Job.Step("Cloning repositories", {
        $CustomBranches = @($Repos.Where({ $_.Branch -ne $_.DefaultBranch }) | Select-Object -ExpandProperty Branch -Unique)
        $Repos.ForEach({
            # If there is only one unique custom branch provided, at first try to use it for all repos.
            # Otherwise, use branch specific for this repo.
            $CustomMultiBranch = $(if ($CustomBranches.Count -eq 1) { $CustomBranches[0] } else { $_.Branch })

            Write-Host $("Cloning " +  $_.Url + " from branch: " + $CustomMultiBranch)
            git clone -b $CustomMultiBranch $_.Url $_.Dir

            if ($LASTEXITCODE -ne 0) {
                Write-Host $("Cloning " +  $_.Url + " from branch: " + $_.Branch)
                git clone -b $_.Branch $_.Url $_.Dir

                if ($LASTEXITCODE -ne 0) {
                    throw "Cloning from " + $_.Url + " failed"
                }
            }
        })
    })
}

function Invoke-ContrailCommonActions {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $VSSetupEnvScriptPath)
    $Job.Step("Sourcing VS environment variables", {
        Invoke-BatchFile "$VSSetupEnvScriptPath"
    })

    $Job.Step("Copying common third-party dependencies", {
        New-Item -ItemType Directory .\third_party
        Get-ChildItem "$ThirdPartyCache\common" -Directory |
            Where-Object{$_.Name -notlike "boost*"} |
            Copy-Item -Destination third_party\ -Recurse -Force
    })

    $Job.Step("Symlinking boost", {
        New-Item -Path "third_party\boost_1_62_0" -ItemType SymbolicLink -Value "$ThirdPartyCache\boost_1_62_0"
    })

    $Job.Step("Copying SConstruct from tools\build", {
        Copy-Item tools\build\SConstruct .
    })
}

function Set-MSISignature {
    Param ([Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $MSIPath)
    $Job.Step("Signing MSI", {
        $cerp = Get-Content $CertPasswordFilePath
        & $SigntoolPath sign /f $CertPath /p $cerp $MSIPath
        if ($LASTEXITCODE -ne 0) {
            throw "Signing $MSIPath failed"
        }
    })
}

function Invoke-DockerDriverBuild {
    Param ([Parameter(Mandatory = $true)] [string] $DriverSrcPath,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath)

    $Job.PushStep("Docker driver build")
    $Env:GOPATH=pwd
    $srcPath = "$Env:GOPATH/src/$DriverSrcPath"

    $Job.Step("Contrail-go-api source code generation", {
        python tools/generateds/generateDS.py -f -o $srcPath/vendor/github.com/Juniper/contrail-go-api/types/ -g golang-api controller/src/schema/vnc_cfg.xsd
    })

    New-Item -ItemType Directory ./bin
    Push-Location bin

    $Job.Step("Installing test runner", {
        go get -u -v github.com/onsi/ginkgo/ginkgo
    })

    $Job.Step("Building driver", {
        go build -v $DriverSrcPath
    })

    $Job.Step("Precompiling tests", {
        $modules = @("driver", "controller", "hns", "hnsManager")
        $modules.ForEach({
            .\ginkgo.exe build $srcPath/$_
            Move-Item $srcPath/$_/$_.test ./
        })
    })

    $Job.Step("Copying Agent API python script", {
        Copy-Item $srcPath/scripts/agent_api.py ./
    })

    $Job.Step("Intalling MSI builder", {
        go get -u -v github.com/mh-cbon/go-msi
    })

    $Job.Step("Building MSI", {
        Push-Location $srcPath
        & "$Env:GOPATH/bin/go-msi" make --msi docker-driver.msi --arch x64 --version 0.1 --src template --out $pwd/gomsi
        Pop-Location

        Move-Item $srcPath/docker-driver.msi ./
    })

    Set-MSISignature -SigntoolPath $SigntoolPath -CertPath $CertPath -CertPasswordFilePath $CertPasswordFilePath -MSIPath "docker-driver.msi"

    Pop-Location

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item bin/* $OutputPath
    })

    $Job.PopStep()
}

function Invoke-ExtensionBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $false)] [bool] $ReleaseMode = $false)

    $Job.PushStep("Extension build")

    $Job.Step("Copying Extension dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\extension\*" third_party\
        Copy-Item -Recurse third_party\cmocka vrouter\test\
    })

    $BuildMode = $(if ($ReleaseMode) { "production" } else { "debug" })

    $Job.Step("Building Extension and Utils", {
        $BuildModeOption = "--optimization=" + $BuildMode
        scons $BuildModeOption vrouter
        if ($LASTEXITCODE -ne 0) {
            throw "Building vRouter solution failed"
        }
    })

    $vRouterRoot = "build\{0}\vrouter" -f $BuildMode
    $vRouterMSI = "$vRouterRoot\extension\vRouter.msi"
    $utilsMSI = "$vRouterRoot\utils\utils.msi"
    $vTestPath = "$vRouterRoot\utils\vtest\"

    Write-Host "Signing utilsMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath -CertPath $CertPath -CertPasswordFilePath $CertPasswordFilePath -MSIPath $utilsMSI

    Write-Host "Signing vRouterMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath -CertPath $CertPath -CertPasswordFilePath $CertPasswordFilePath -MSIPath $vRouterMSI

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item $utilsMSI $OutputPath -Recurse -Container
        Copy-Item $vRouterMSI $OutputPath -Recurse -Container
        Copy-Item $CertPath $OutputPath -Recurse -Container
        Copy-Item $vTestPath "$OutputPath\utils\vtest" -Recurse -Container
    })

    $Job.PopStep()
}

function Invoke-AgentBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $false)] [bool] $ReleaseMode = $false)

    $Job.PushStep("Agent build")

    $Job.Step("Copying Agent dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\agent\*" third_party/
    })

    $BuildMode = $(if ($ReleaseMode) { "production" } else { "debug" })
    $BuildModeOption = "--optimization=" + $BuildMode

    $Job.Step("Building API", {
        scons $BuildModeOption controller/src/vnsw/contrail_vrouter_api:sdist
        if ($LASTEXITCODE -ne 0) {
            throw "Building API failed"
        }
    })

    $Job.Step("Building contrail-vrouter-agent.exe, .msi and tests", {
        $Tests = @(
            "agent:test_ksync",
            "src/ksync:ksync_test",
            "src/dns:dns_bind_test",
            "src/dns:dns_config_test",
            "src/dns:dns_mgr_test",
            "controller/src/schema:test",
            "src/xml:xml_test",
            "controller/src/xmpp:test",
            "agent:test_oper_xml",
            "agent:ifmap_dependency_manager_test",
            "agent:test_xmpp_discovery_non_hv",
            "src/base:libtask_test",
            "src/base:bitset_test",
            "src/base:index_allocator_test",
            "src/base:dependency_test",
            "src/base:label_block_test",
            "src/base:queue_task_test",
            "src/base:subset_test",
            "src/base:task_test",
            "src/base:patricia_test",
            "src/base:boost_US_test"
            # Marked as flaky in SCons
            # "src/base:timer_test"
        )

        $TestsString = ""
        if ($Tests.count -gt 0) {
            $TestsString = $Tests -join " "
        }
        $AgentAndTestsBuildCommand = "scons -j 4 {0} contrail-vrouter-agent.msi {1}" -f "$BuildModeOption", "$TestsString"
        Invoke-Expression $AgentAndTestsBuildCommand

        if ($LASTEXITCODE -ne 0) {
            throw "Building Agent and tests failed"
        }
    })

    $rootBuildDir = "build\{0}" -f $BuildMode
    $agentMSI = "$rootBuildDir\vnsw\agent\contrail\contrail-vrouter-agent.msi"

    Write-Host "Signing agentMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath -CertPath $CertPath -CertPasswordFilePath $CertPasswordFilePath -MSIPath $agentMSI

    $Job.Step("Copying artifacts to $OutputPath", {
        $vRouterApiPath = "build\noarch\contrail-vrouter-api\dist\contrail-vrouter-api-1.0.tar.gz"
        $testInisPath = "controller\src\vnsw\agent\test"
        $libxmlPath = "build\bin\libxml2.dll"

        Copy-Item $vRouterApiPath $OutputPath -Recurse -Container
        Copy-Item $agentMSI $OutputPath -Recurse -Container
        Copy-Item -Path $rootBuildDir -Recurse -Include "*.exe" -Destination $OutputPath -Container # This copies all test executables 
        Copy-Item -Path $testInisPath -Include "*.ini" -Destination $OutputPath
        Copy-Item $libxmlPath $OutputPath -Recurse -Container
    })

    $Job.PopStep()
}

