Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "."
)

. $PSScriptRoot\..\..\Common\VMUtils.ps1
. $PSScriptRoot\DockerImageBuild.ps1

. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1
Initialize-PesterLogger -OutDir $LogDir

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
