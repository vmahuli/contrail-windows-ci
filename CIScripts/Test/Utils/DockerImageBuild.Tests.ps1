Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\DockerImageBuild.ps1

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

    It "Builds iis-tcptest image" {
        Initialize-DockerImage -Session $Session -DockerImageName $DockerImageName
        
        Invoke-Command -Session $Session {
            docker inspect $Using:DockerImageName
        } | Should Not BeNullOrEmpty
    }

    BeforeEach {
        # Invoke-Command used as a workaround for temporary ErrorActionPreference modification
        Invoke-Command -Session $Session {
            Invoke-Command {
                $ErrorActionPreference = "SilentlyContinue"
                docker image rm $Using:DockerImageName -f 2>$null
            }
        }
    }
}

Remove-PSSession $Sessions
