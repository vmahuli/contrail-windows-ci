Param (
    [Parameter(Mandatory=$true)] [string] $TestenvConfFile
)

. $PSScriptRoot\DockerImageBuild.ps1

$Sessions = New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
$Session = $Sessions[0]
$DockerImageName = "iis-tcptest"

Describe "Initialize-DockerImage" {
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
