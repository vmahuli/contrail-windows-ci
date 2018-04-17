$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "RemoteLogCollector" {
    It "appends collected logs to correct output file" {
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"
        Write-Log "first message"

        Merge-Logs -LogSources $Source1

        $Content = Get-Content "TestDrive:\RemoteLogCollector.appends collected logs to correct output file.log"
        "first message" | Should -BeIn $Content
        "remote log text" | Should -BeIn $Content
    }

    It "cleans logs in source directory" {
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        Test-Path $DummyLog1 | Should -Be $false
    }

    It "doesn't clean logs in source directory if DontCleanUp flag passed" {
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -DontCleanUp -LogSources $Source1

        Test-Path $DummyLog1 | Should -Be $true
    }

    It "adds a prefix describing source directory" {
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"
        Write-Log "first message"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.adds a prefix describing source directory.log"
        $ContentRaw | Should -BeLike "*$DummyLog1*"
        $ContentRaw | Should -BeLike "*localhost*"
    }

    It "works with multiple lines in remote logs" {
        "second line" | Add-Content $DummyLog1
        "third line" | Add-Content $DummyLog1
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works with multiple lines in remote logs.log"
        $ContentRaw | Should -BeLike "*remote log text*second line*third line*"
    }

    It "works when specifying a wildcard path" {
        $WildcardPath = ((Get-Item $TestDrive).FullName) + "\*.txt"
        $WildcardSource = New-LogSource -Sessions $Sess1 -Path $WildcardPath
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $WildcardSource

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works when specifying a wildcard path.log"
        $ContentRaw | Should -BeLike "*$DummyLog1*remote log*"
        $ContentRaw | Should -BeLike "*$DummyLog2*another file content*"
    }

    It "works with multiple sessions in single log source" {
        $Source2 = New-LogSource -Sessions @($Sess1, $Sess2) -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"
        Write-Log "first message"

        # We pass -DontCleanUp because in the tests, both sessions point at the same computer.
        Merge-Logs -DontCleanUp -LogSources $Source2

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works with multiple sessions in single log source.log"
        $ContentRaw | Should -BeLike "first message*$DummyLog1*$DummyLog1*"
        $ContentRaw | Should -BeLike "*remote log text*remote log text*"
        $ContentRaw | Should -BeLike "*localhost*localhost*"
    }

    It "works with multiple log sources" {
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        $Source2 = New-LogSource -Sessions $Sess1 -Path $DummyLog2
        Initialize-PesterLogger -OutDir "TestDrive:\"

        # We pass -DontCleanUp because in the tests, both sessions point at the same computer.
        Merge-Logs -DontCleanUp -LogSources @($Source1, $Source2)

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.works with multiple log sources.log"
        $ContentRaw | Should -BeLike "*$DummyLog1*$DummyLog2*"
        $ContentRaw | Should -BeLike "*remote log text*another file content*"
    }

    It "inserts warning message if filepath was not found" {
        Remove-Item $DummyLog1
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.inserts warning message if filepath was not found.log"
        $ContentRaw | Should -BeLike "*$DummyLog1*<FILE NOT FOUND>*"
    }

    It "inserts warning message if wildcard matched nothing" {
        Remove-Item $DummyLog1
        Remove-Item $DummyLog2
        $WildcardPath = ((Get-Item $TestDrive).FullName) + "\*.txt"
        $WildcardSource = New-LogSource -Sessions $Sess1 -Path $WildcardPath
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $WildcardSource

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.inserts warning message if wildcard matched nothing.log"
        $ContentRaw | Should -BeLike "*$WildcardPath*<FILE NOT FOUND>*"
    }

    It "inserts a message if log file was empty" {
        Clear-Content $DummyLog1
        $Source1 = New-LogSource -Sessions $Sess1 -Path $DummyLog1
        Initialize-PesterLogger -OutDir "TestDrive:\"

        Merge-Logs -LogSources $Source1

        $ContentRaw = Get-Content -Raw "TestDrive:\RemoteLogCollector.inserts a message if log file was empty.log"
        $ContentRaw | Should -BeLike "*$DummyLog1*<FILE WAS EMPTY>*"
    }

    BeforeEach {
        $DummyLog1 = ((Get-Item $TestDrive).FullName) + "\remotelog.txt"
        "remote log text" | Out-File $DummyLog1
        $DummyLog2 = ((Get-Item $TestDrive).FullName) + "\remotelog_second.txt"
        "another file content" | Out-File $DummyLog2
    }

    AfterEach {
        Remove-Item "TestDrive:/*" 
        if (Get-Item function:Write-Log -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-Log
        }
    }

    BeforeAll {
        $Sess1 = $null
        $Sess2 = $null
        $IntegrationTest=$false # TODO: Will change when selfcheck PR is merged.
        if ($IntegrationTest) {
            $Sess1 = New-PSSession -ComputerName localhost
            $Sess2 = New-PSSession -ComputerName localhost
        }
    }

    AfterAll {
        if ($IntegrationTest) {
            Remove-PSSession $Sess1
            Remove-PSSession $Sess2
        }
    }
}
