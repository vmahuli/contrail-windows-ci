Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\..\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\Common\VMUtils.ps1
. $PSScriptRoot\..\..\..\Common\Invoke-NativeCommand.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
Initialize-PesterLogger -OutDir $LogDir

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]

$TestsPath = "C:\Artifacts\"

function Invoke-DockerDriverUnitTest {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $Component
    )

    $TestFilePath = ".\" + $Component + ".test.exe"
    $Command = @($TestFilePath, "--ginkgo.noisyPendings", "--ginkgo.failFast", "--ginkgo.progress", "--ginkgo.v", "--ginkgo.trace")
    $Command = $Command -join " "

    $Res = Invoke-NativeCommand -CaptureOutput -AllowNonZero -Session $Session {
        Push-Location $Using:TestsPath
        try {
            Invoke-Expression -Command $Using:Command
        } finally {
            Pop-Location
        }
    }

    Write-Log $Res.Output

    return $Res.ExitCode
}

function Save-DockerDriverUnitTestReport {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $Component
    )

    # TODO Where are these files copied to?
    Copy-Item -FromSession $Session -Path ($TestsPath + $Component + "_junit.xml") -ErrorAction SilentlyContinue
}

# TODO: these modules should also be tested: controller, hns, hnsManager, driver
$Modules = @("agent")

Describe "Docker Driver" {
    foreach ($Module in $Modules) {
        Context "Tests for module $Module" {
            It "Tests are invoked" {
                $TestResult = Invoke-DockerDriverUnitTest -Session $Session -Component $Module
                $TestResult | Should Be 0
            }

            AfterEach {
                Save-DockerDriverUnitTestReport -Session $Session -Component $Module
            }
        }
    }
}

Remove-PSSession $Sessions
