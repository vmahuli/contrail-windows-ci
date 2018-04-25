Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\DockerImageBuild.ps1
. $PSScriptRoot\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\Testenv\Testbed.ps1

Describe "Initialize-DockerImage" -Tags CI, Systest {
    BeforeAll {
        $Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $Session = $Sessions[0]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $DockerImageName = "iis-tcptest"
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }
        Remove-PSSession $Sessions
    }

    It "Builds iis-tcptest image" {
        $DockerOutput = Initialize-DockerImage -Session $Session -DockerImageName $DockerImageName
        $DockerOutput | Should -Contain "Successfully tagged $( $DockerImageName ):latest"
        $DockerOutput -Join "" | Should -BeLike "*Successfully built*"
        
        Invoke-Command -Session $Session {
            docker inspect $Using:DockerImageName
        } | Should -Not -BeNullOrEmpty
    }
}
