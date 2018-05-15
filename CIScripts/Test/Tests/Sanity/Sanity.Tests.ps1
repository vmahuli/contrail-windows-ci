Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs"
)

. $PSScriptRoot\..\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\Common\Init.ps1
. $PSScriptRoot\..\..\Utils\ComponentsInstallation.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\..\..\Testenv\Testbed.ps1
. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\Utils\CommonTestCode.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

Describe "Sanity tests" {

    $TestPaths = Get-ChildItem -Recurse -Filter "*.SanityTest.ps1"
    foreach ($TestPath in $TestPaths) {
        Invoke-Expression $PSScriptRoot\$TestPath
    }

    BeforeAll {
        $VMs = Read-TestbedsConfig -Path $TestenvConfFile
        $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
        $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "ContrailNetwork",
            Justification="It's actually used."
        )]
        $SystemConfig = Read-SystemConfig -Path $TestenvConfFile
        $Sessions = New-RemoteSessions -VMs $VMs
        Initialize-PesterLogger -OutDir $LogDir
        Write-Log "Installing components on testbeds..."
        foreach ($Session in $Sessions) {
            Install-Components -Session $Session
        }

        $ContrailNM = [ContrailNetworkManager]::new($OpenStackConfig, $ControllerConfig)
        $ContrailNM.EnsureProject($ControllerConfig.DefaultProject)

        $Testbed1Address = $VMs[0].Address
        $Testbed1Name = $VMs[0].Name
        Write-Log "Creating virtual router. Name: $Testbed1Name; Address: $Testbed1Address"
        $VRouter1Uuid = $ContrailNM.AddVirtualRouter($Testbed1Name, $Testbed1Address)
        Write-Log "Reported UUID of new virtual router: $VRouter1Uuid"

        $Testbed2Address = $VMs[1].Address
        $Testbed2Name = $VMs[1].Name
        Write-Log "Creating virtual router. Name: $Testbed2Name; Address: $Testbed2Address"
        $VRouter2Uuid = $ContrailNM.AddVirtualRouter($Testbed2Name, $Testbed2Address)
        Write-Log "Reported UUID of new virtual router: $VRouter2Uuid"

        foreach ($Session in $Sessions) {
            Initialize-ComputeServices -Session $Session `
                -SystemConfig $SystemConfig `
                -OpenStackConfig $OpenStackConfig `
                -ControllerConfig $ControllerConfig
        }
    }

    AfterAll {
        try {
            foreach ($Session in $Sessions) {
                Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
            }
        } finally {
            Merge-Logs -LogSources (New-FileLogSource -Path (Get-ComputeLogsPath) -Sessions $Sessions)
        }

        if(Get-Variable "VRouter1Uuid" -ErrorAction SilentlyContinue) {
            Write-Log "Removing virtual router: $VRouter1Uuid"
            $ContrailNM.RemoveVirtualRouter($VRouter1Uuid)
            Remove-Variable "VRouter1Uuid"
        }
        if(Get-Variable "VRouter2Uuid" -ErrorAction SilentlyContinue) {
            Write-Log "Removing virtual router: $VRouter2Uuid"
            $ContrailNM.RemoveVirtualRouter($VRouter2Uuid)
            Remove-Variable "VRouter2Uuid"
        }

        Write-Log "Uninstalling components from testbeds..."
        foreach ($Session in $Sessions) {
            Uninstall-Components -Session $Session
        }

        Remove-PSSession $Sessions
    }
}
