# TODO Dependencies should be cleaned up once this repository is
# refactored and common utility functions are no longer in Test directory.
. $PSScriptRoot\..\Test\Utils\ComponentsInstallation.ps1

$Session = New-PSSession 

Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root\ "C:\Artifacts\vRouter.cer" | Out-Null # TODO: Remove after JW-798
Import-Certificate -CertStoreLocation Cert:\LocalMachine\TrustedPublisher\ "C:\Artifacts\vRouter.cer" | Out-Null # TODO: Remove after JW-798

Install-Extension -Session $Session
Install-DockerDriver -Session $Session
Install-Agent -Session $Session
Install-Utils -Session $Session

