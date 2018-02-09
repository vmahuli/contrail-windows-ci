. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\Build\Repository.ps1

function Clone-Repos {
    Param ([Parameter(Mandatory = $true, HelpMessage = "Map of repos to clone")] [System.Collections.Hashtable] $Repos)

    $Job.Step("Cloning repositories", {
        $CustomBranches = @($Repos.Where({ $_.Branch -ne $_.DefaultBranch }) |
                            Select-Object -ExpandProperty Branch -Unique)
        $Repos.Values.ForEach({
            # If there is only one unique custom branch provided, at first try to use it for all repos.
            # Otherwise, use branch specific for this repo.
            $CustomMultiBranch = $(if ($CustomBranches.Count -eq 1) { $CustomBranches[0] } else { $_.Branch })

            Write-Host $("Cloning " +  $_.Url + " from branch: " + $CustomMultiBranch)

            # We must use -q (quiet) flag here, since git clone prints to stderr and tries to do some real-time
            # command line magic (like updating cloning progress). Powershell command in Jenkinsfile
            # can't handle it and throws a Write-ErrorException.
            $NativeCommandReturn = Invoke-NativeCommand -AllowNonZero $true -ScriptBlock {
                git clone -q -b $CustomMultiBranch $_.Url $_.Dir
            }
            $ExitCode = $NativeCommandReturn[-1]
            if ($ExitCode -ne 0) {
                Write-Host $("Cloning " +  $_.Url + " from branch: " + $_.Branch)

                Invoke-NativeCommand -ScriptBlock {
                    git clone -q -b $_.Branch $_.Url $_.Dir
                }
            }
        })
    })
}

function Prepare-BuildEnvironment {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache)
    $Job.Step("Copying common third-party dependencies", {
        if (!(Test-Path -Path .\third_party)) {
            New-Item -ItemType Directory .\third_party | Out-Null
        }
        Get-ChildItem "$ThirdPartyCache\common" -Directory |
            Where-Object{$_.Name -notlike "boost*"} |
            Copy-Item -Destination third_party\ -Recurse -Force
    })

    $Job.Step("Symlinking boost", {
        New-Item -Path "third_party\boost_1_62_0" -ItemType SymbolicLink -Value "$ThirdPartyCache\boost_1_62_0" | Out-Null
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
        Invoke-NativeCommand -ScriptBlock {
            & $SigntoolPath sign /f $CertPath /p $cerp $MSIPath
        }
    })
}

function Invoke-DockerDriverBuild {
    Param ([Parameter(Mandatory = $true)] [string] $DriverSrcPath,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath)

    $Job.PushStep("Docker driver build")
    $GoPath = if (Test-Path Env:GOPATH) { (pwd) + ";$Env:GOPATH" } else { pwd }
    $Env:GOPATH = $GoPath
    $srcPath = "$GoPath/src/$DriverSrcPath"

    New-Item -ItemType Directory ./bin | Out-Null

    Push-Location $srcPath
    $Job.Step("Fetch third party packages ", {
        Invoke-NativeCommand -ScriptBlock {
            & dep ensure -v
        }

        Invoke-NativeCommand -ScriptBlock {
            & dep prune -v
        }
    })
    Pop-Location

    $Job.Step("Contrail-go-api source code generation", {
        Invoke-NativeCommand -ScriptBlock {
            python tools/generateds/generateDS.py -q -f `
                                                  -o $srcPath/vendor/github.com/Juniper/contrail-go-api/types/ `
                                                  -g golang-api controller/src/schema/vnc_cfg.xsd
        }
    })

    Push-Location bin

    $Job.Step("Building driver", {
        # TODO: Handle new name properly
        Invoke-NativeCommand -ScriptBlock {
            go build -o contrail-windows-docker.exe -v $DriverSrcPath
        }
    })

    $Job.Step("Precompiling tests", {
        $modules = @("driver", "controller", "hns", "hnsManager")
        $modules.ForEach({
            Invoke-NativeCommand -ScriptBlock {
                ginkgo build $srcPath/$_
            }
            Move-Item $srcPath/$_/$_.test ./
        })
    })

    $Job.Step("Copying Agent API python script", {
        Copy-Item $srcPath/scripts/agent_api.py ./
    })

    $Job.Step("Building MSI", {
        Push-Location $srcPath
        Invoke-NativeCommand -ScriptBlock {
            & go-msi make --msi docker-driver.msi --arch x64 --version 0.1 `
                          --src template --out $pwd/gomsi
        }
        Pop-Location

        Move-Item $srcPath/docker-driver.msi ./
    })

    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath "docker-driver.msi"

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
           [Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [bool] $ReleaseMode = $false)

    $Job.PushStep("Extension build")

    $Job.Step("Copying Extension dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\extension\*" third_party\
        Copy-Item -Recurse third_party\cmocka vrouter\test\
    })

    $BuildMode = $(if ($ReleaseMode) { "production" } else { "debug" })

    $Job.Step("Building Extension and Utils", {
        $BuildModeOption = "--optimization=" + $BuildMode
        $Env:cerp = Get-Content $CertPasswordFilePath
        Invoke-NativeCommand -ScriptBlock {
            scons $BuildModeOption vrouter | Tee-Object -FilePath $LogsDir/vrouter_build.log
        }
    })

    $vRouterRoot = "build\{0}\vrouter" -f $BuildMode
    $vRouterMSI = "$vRouterRoot\extension\vRouter.msi"
    $vRouterCert = "$vRouterRoot\extension\vRouter.cer"
    $utilsMSI = "$vRouterRoot\utils\utils.msi"
    $vTestPath = "$vRouterRoot\utils\vtest\"

    Write-Host "Signing utilsMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $utilsMSI

    Write-Host "Signing vRouterMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $vRouterMSI

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item $utilsMSI $OutputPath -Recurse -Container
        Copy-Item $vRouterMSI $OutputPath -Recurse -Container
        Copy-Item $vRouterCert $OutputPath -Recurse -Container
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
           [Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [bool] $ReleaseMode = $false)

    $Job.PushStep("Agent build")

    $Job.Step("Copying Agent dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\agent\*" third_party/
    })

    $BuildMode = $(if ($ReleaseMode) { "production" } else { "debug" })
    $BuildModeOption = "--optimization=" + $BuildMode

    $Job.Step("Building API", {
        Invoke-NativeCommand -ScriptBlock {
            scons $BuildModeOption controller/src/vnsw/contrail_vrouter_api:sdist | Tee-Object -FilePath $LogsPath/build_api.log
        }
    })

    $Job.Step("Building contrail-vrouter-agent.exe and .msi", {
        $AgentBuildCommand = "scons -j 4 {0} contrail-vrouter-agent.msi" -f "$BuildModeOption"
        Invoke-NativeCommand -ScriptBlock {
            Invoke-Expression $AgentBuildCommand | Tee-Object -FilePath $LogsPath/build_agent.log
        }
    })

    $agentMSI = "build\$BuildMode\vnsw\agent\contrail\contrail-vrouter-agent.msi"

    Write-Host "Signing agentMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $agentMSI

    $Job.Step("Copying artifacts to $OutputPath", {
        $vRouterApiPath = "build\noarch\contrail-vrouter-api\dist\contrail-vrouter-api-1.0.tar.gz"

        Copy-Item $vRouterApiPath $OutputPath -Recurse -Container
        Copy-Item $agentMSI $OutputPath -Recurse -Container
    })

    $Job.PopStep()
}

function Test-IfGTestOutputSuggestsThatAllTestsHavePassed {
    Param ([Parameter(Mandatory = $true)] [Object[]] $TestOutput)
    $NumberOfTests = -1
    Foreach ($Line in $TestOutput) {
        if ($Line -match "\[==========\] (?<HowManyTests>[\d]+) test[s]? from [\d]+ test [\w]* ran[.]*") {
            $NumberOfTests = $matches.HowManyTests
        }
        if ($Line -match "\[  PASSED  \] (?<HowManyTestsHavePassed>[\d]+) test[.]*" -and $NumberOfTests -ge 0) {
            return $($matches.HowManyTestsHavePassed -eq $NumberOfTests)
        }
    }
    return $False
}

function Run-Test {
    Param ([Parameter(Mandatory = $true)] [String] $TestExecutable)
    Write-Host "===> Agent tests: running $TestExecutable..."
    $Res = Invoke-Command -ScriptBlock {
        $NativeCommandReturn = Invoke-NativeCommand -AllowNonZero $true -ScriptBlock {
            Invoke-Expression $TestExecutable
        }
        $ExitCode = $NativeCommandReturn[-1]
        $TestOutput = $NativeCommandReturn[0..($NativeCommandReturn.Length-2)]

        # This is a workaround for the following bug:
        # https://bugs.launchpad.net/opencontrail/+bug/1714205
        # Even if all tests actually pass, test executables can sometimes
        # return non-zero exit code.
        # TODO: It should be removed once the bug is fixed (JW-1110).
        $SeemsLegitimate = Test-IfGTestOutputSuggestsThatAllTestsHavePassed -TestOutput $TestOutput
        if ($ExitCode -eq 0 -or $SeemsLegitimate) {
            return 0
        } else {
            return $ExitCode
        }
    }

    if ($Res -eq 0) {
        Write-Host "        Succeeded."
    } else {
        Write-Host "        Failed (exit code: $Res)."
    }
    return $Res
}

function Invoke-AgentTestsBuild {
    Param ([Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [bool] $ReleaseMode = $false)

    $Job.PushStep("Agent Tests build")

    $BuildMode = $(if ($ReleaseMode) { "production" } else { "debug" })
    $BuildModeOption = "--optimization=" + $BuildMode

    $Job.Step("Building agent tests", {
        $Tests = @(
            "agent:test_ksync",
            "src/ksync:ksync_test",
            "src/dns:dns_bind_test",
            "src/dns:dns_config_test",
            "src/dns:dns_mgr_test",
            "controller/src/schema:test",
            "src/xml:xml_test",
            "controller/src/xmpp:test",
            "src/base:libtask_test",
            "src/base:bitset_test",
            "src/base:index_allocator_test",
            "src/base:dependency_test",
            "src/base:label_block_test",
            "src/base:queue_task_test",
            "src/base:subset_test",
            "src/base:patricia_test",
            "src/base:boost_US_test"

            # oper
            "agent:test_agent_sandesh",
            "agent:test_config_manager",
            "agent:test_intf",
            "agent:test_intf_policy",
            "agent:test_find_scale",
            "agent:test_logical_intf",
            "agent:test_vrf_assign",
            "agent:test_inet_interface",
            "agent:test_aap6",
            "agent:test_ipv6",
            "agent:test_forwarding_class",
            "agent:test_qos_config",
            "agent:test_oper_xml",
            "agent:ifmap_dependency_manager_test",
            "agent:test_physical_devices"
        )

        $TestsString = ""
        if ($Tests.count -gt 0) {
            $TestsString = $Tests -join " "
        }
        $TestsBuildCommand = "scons -j 4 {0} {1}" -f "$BuildModeOption", "$TestsString"
        Invoke-NativeCommand -ScriptBlock {
            Invoke-Expression $TestsBuildCommand | Tee-Object -FilePath $LogsPath/build_agent_tests.log
        }
    })

    $rootBuildDir = "build\$BuildMode"

    $Job.Step("Running agent tests", {
        $backupPath = $Env:Path
        $Env:Path += ";" + $(Get-Location).Path + "\build\bin"

        # Those env vars are used by agent tests for determining timeout's threshold
        # They were copied from Linux unit test job
        $Env:TASK_UTIL_WAIT_TIME = 10000
        $Env:TASK_UTIL_RETRY_COUNT = 6000

        $TestsFolders = @(
            "base\test",
            "dns\test",
            "ksync\test",
            "schema\test",
            "vnsw\agent\cmn\test",
            "vnsw\agent\oper\test",
            "vnsw\agent\test",
            "xml\test",
            "xmpp\test"
        ) | % { "$rootBuildDir\$_" }

        $AgentExecutables = Get-ChildItem -Recurse $TestsFolders | Where-Object {$_.Name -match '.*\.exe$'}
        Foreach ($TestExecutable in $AgentExecutables) {
            $TestRes = Run-Test -TestExecutable $TestExecutable.FullName
            if ($TestRes -ne 0) {
                throw "Running agent tests failed"
            }
        }

        $Env:Path = $backupPath
    })

    $Job.PopStep()
}
