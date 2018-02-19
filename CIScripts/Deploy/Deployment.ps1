. $PSScriptRoot\..\Common\Aliases.ps1
. $PSScriptRoot\..\Common\Components.ps1

function Deploy-Testbeds {
    Param ([Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
           [Parameter(Mandatory = $true)] [string] $ArtifactsDir)
    $Job.Step("Deploying testbeds", {
        $Sessions.ForEach({
            $Job.Step("Deploying testbed...", {
                Install-Artifacts -Session $_ -ArtifactsDir $ArtifactsDir
            })
        })
    })
}

function Install-Artifacts {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ArtifactsDir)

    Push-Location $ArtifactsDir

    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Force C:\Artifacts | Out-Null
    }

    $ComponentsToBuild = Get-ComponentsToBuild

    if ("DockerDriver" -In $ComponentsToBuild) {
        Write-Host "Copying Docker driver installer"
        Copy-Item -ToSession $Session -Path "docker_driver\docker-driver.msi" -Destination C:\Artifacts\

        Write-Host "Copying Docker driver tests"
        $TestFiles = @("controller", "hns", "hnsManager", "driver")
        $TestFiles.ForEach({
            Copy-Item -ToSession $Session -Path "docker_driver\$_.test" -Destination "C:\Artifacts\$_.test.exe"
        })
    }

    if ("Agent" -In $ComponentsToBuild) {
        Write-Host "Copying Agent and Contrail vRouter API"
        Copy-Item -ToSession $Session -Path "agent\contrail-vrouter-agent.msi" -Destination C:\Artifacts\
        Copy-Item -ToSession $Session -Path "agent\contrail-vrouter-api-1.0.tar.gz" -Destination C:\Artifacts\

        Invoke-Command -Session $Session -ScriptBlock {
            Write-Host "Installing Contrail vRouter API"
            pip2 install C:\Artifacts\contrail-vrouter-api-1.0.tar.gz | Out-Null
        }
    }

    if ("Extension" -In $ComponentsToBuild) {
        Write-Host "Copying vRouter and Utils MSIs"
        Copy-Item -ToSession $Session -Path "vrouter\vRouter.msi" -Destination C:\Artifacts\
        Copy-Item -ToSession $Session -Path "vrouter\utils.msi" -Destination C:\Artifacts\
        Copy-Item -ToSession $Session -Path "vrouter\*.cer" -Destination C:\Artifacts\ # TODO: Remove after JW-798

        Write-Host "Copying vtest scenarios"
        Copy-Item -ToSession $Session -Path "vtest" -Destination C:\Artifacts\ -Recurse -Force

        Invoke-Command -Session $Session -ScriptBlock {
            Write-Host "Installing certificates"
            Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root\ "C:\Artifacts\vRouter.cer" | Out-Null # TODO: Remove after JW-798
            Import-Certificate -CertStoreLocation Cert:\LocalMachine\TrustedPublisher\ "C:\Artifacts\vRouter.cer" | Out-Null # TODO: Remove after JW-798
        }
    }

    Write-Host "Copying dlls"
    Copy-Item -ToSession $Session -Path "dlls\*" -Destination "C:\Windows\System32\"

    Invoke-Command -Session $Session -ScriptBlock {
        # Refresh Path
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }

    Pop-Location
}

