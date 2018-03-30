. $PSScriptRoot\..\..\Common\Aliases.ps1
$DockerfilesPath = "$PSScriptRoot\..\..\DockerFiles\"

function Initialize-DockerImage  {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $DockerImageName
    )

    $DockerfilePath = $DockerfilesPath + $DockerImageName
    $TestbedDockerfilesDir = "C:\DockerFiles\"
    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force $Using:TestbedDockerfilesDir | Out-Null
    }

    Write-Log "Copying directory with Dockerfile"
    Copy-Item -ToSession $Session -Path $DockerfilePath -Destination $TestbedDockerfilesDir -Recurse -Force

    Write-Log "Building Docker image"
    $TestbedDockerfilePath = $TestbedDockerfilesDir + $DockerImageName
    Invoke-Command -Session $Session -ScriptBlock {
        docker build -t $Using:DockerImageName $Using:TestbedDockerfilePath
    }
}
