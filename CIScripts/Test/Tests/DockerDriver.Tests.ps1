Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$true)] [string] $ConfigFile
)

. $PSScriptRoot\..\..\Common\Aliases.ps1

. $ConfigFile
$TestConf = Get-TestConfiguration
$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

$TestsPath = "C:\Artifacts\"

function Start-DockerDriverUnitTest {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $Component
    )

    $TestFilePath = ".\" + $Component + ".test.exe"
    $Command = @($TestFilePath, "--ginkgo.noisyPendings", "--ginkgo.failFast", "--ginkgo.progress", "--ginkgo.v", "--ginkgo.trace")
    $Command = $Command -join " "

    $Res = Invoke-Command -Session $Session -ScriptBlock {
        Push-Location $Using:TestsPath

        # Invoke-Command used as a workaround for temporary ErrorActionPreference modification
        $Res = Invoke-Command -ScriptBlock {
            if (Test-Path $Using:TestFilePath) {
                $ErrorActionPreference = "SilentlyContinue"
                Invoke-Expression -Command $Using:Command | Write-Host
                return $LASTEXITCODE
            } else {
                return 1
            }
        }

        Pop-Location

        return $Res
    }

    return $Res
}

function Save-DockerDriverUnitTestReport {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $Component
    )

    Copy-Item -FromSession $Session -Path ($TestsPath + $Component + "_junit.xml") -ErrorAction SilentlyContinue
}

# TODO: these modules should also be tested: controller, hns, hnsManager, driver
$modules = @("agent")

Describe "Docker Driver" {
    $modules | ForEach-Object {
        Context "Tests for module $_" {
            It "Tests are invoked" {
                $TestResult = Start-DockerDriverUnitTest -Session $Session -Component $_
                $TestResult | Should Be 0
            }

            AfterEach {
                Save-DockerDriverUnitTestReport -Session $Session -Component $_
            }
        }
    }
}
