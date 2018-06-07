Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(ValueFromRemainingArguments=$true)] $AdditionalParams
)

. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1
. $PSScriptRoot\..\Testenv\Testbed.ps1
. $PSScriptRoot\PesterLogger\PesterLogger.ps1

$NetworkName = "nat"

Describe "Remove-AllContainers" {
    It "Removes single container if exists" {
        New-Container -Session $Session -NetworkName $NetworkName
        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -aq
        } | Should Not BeNullOrEmpty

        Remove-AllContainers -Session $Session

        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -aq
        } | Should BeNullOrEmpty
    }

    It "Removes mutliple containers if exist" {
        New-Container -Session $Session -NetworkName $NetworkName
        New-Container -Session $Session -NetworkName $NetworkName
        New-Container -Session $Session -NetworkName $NetworkName
        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -aq
        } | Should Not BeNullOrEmpty

        Remove-AllContainers -Session $Session

        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -aq
        } | Should BeNullOrEmpty
    }

    It "Does nothing if list of containers is empty" {
        Remove-AllContainers -Session $Session

        Invoke-Command -Session $Session -ScriptBlock {
            docker ps -aq
        } | Should BeNullOrEmpty
    }

    AfterEach {
        Clear-TestConfiguration -Session $Session -SystemConfig $SystemConfig
    }

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
        $SystemConfig = Read-SystemConfig -Path $TestenvConfFile

        Initialize-PesterLogger -OutDir $LogDir
    }

    AfterAll {
        if (-not (Get-Variable Sessions -ErrorAction SilentlyContinue)) { return }
        Remove-PSSession $Sessions
    }
}
