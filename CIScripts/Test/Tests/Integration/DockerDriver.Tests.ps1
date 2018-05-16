Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\..\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\Common\Invoke-NativeCommand.ps1
. $PSScriptRoot\..\..\..\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

$TestsPath = "C:\Artifacts\"

function Invoke-DockerDriverUnitTest {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [string] $TestModulePath
    )

    $Command = @($TestModulePath, "--ginkgo.noisyPendings", "--ginkgo.failFast", "--ginkgo.progress", "--ginkgo.v", "--ginkgo.trace")
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
        [Parameter(Mandatory=$true)] [string] $TestModulePath
    )

    # TODO Where are these files copied to?
    # TODO2: Fix JUnit reporters first....
    # Copy-Item -FromSession $Session -Path ($TestsPath + $TestModulePath + "_junit.xml") -ErrorAction SilentlyContinue
}

Describe "Docker Driver" {
    BeforeAll {
        $Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "Session", Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $Session = $Sessions[0]

        Initialize-PesterLogger -OutDir $LogDir

        $TestModules = Get-ChildItem -Recurse -Filter "*.test.exe"
        Write-Log "Discovered test modules: $TestModules"
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }
        Remove-PSSession $Sessions
    }

    foreach ($TestModule in $TestModules) {
        Context "Tests for module $TestModule" {
            It "Tests are invoked" {
                $TestResult = Invoke-DockerDriverUnitTest -Session $Session -TestModulePath $TestModule
                $TestResult | Should Be 0
            }

            AfterEach {
                Save-DockerDriverUnitTestReport -Session $Session -TestModulePath $TestModule
            }
        }
    }

    AfterEach {
        Merge-Logs -LogSources (New-FileLogSource -Path (Get-ComputeLogsPath) -Sessions $Session)
    }
}
