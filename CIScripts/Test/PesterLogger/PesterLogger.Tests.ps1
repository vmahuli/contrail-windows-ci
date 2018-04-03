$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "PesterLogger" {
    Context "Initialize-PesterLogger" {
        It "registers a new global Write-Log function" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Get-Item function:Write-Log -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "unregisters previous Write-Log function and registers a new one" {
            function OldImpl {}
            Mock OldImpl {}
            New-Item function:Write-Log -Value OldImpl
            Write-Log "test"

            Initialize-PesterLogger -OutDir "TestDrive:\"
            Get-Item function:Write-Log -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            Write-Log "test2"
            Assert-MockCalled OldImpl -Exactly -Times 1
        }

        It "creates output directory if it doesn't exist" {
            Initialize-PesterLogger -OutDir "TestDrive:\some_dir"
            "TestDrive:\some_dir" | Should -Exist
        }

    }

    Context "Write-Log" {
        It "writes to correct file" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Write-Log "msg"
            Test-Path "TestDrive:\PesterLogger.Write-Log.writes to correct file.log" | Should -Be $true
        }

        It "changing location doesn't change the output directory" {
            # try-finally block is here because we change working directory to temporary TestDrive. 
            # If something fails during test, we must ensure that we go back to original working 
            # directory. Otherwise, following tests will run in the temporary TestDrive directory.
            # There is a possiblity that they would break. We need to isolate them.
            try {
                Push-Location TestDrive:\
                Initialize-PesterLogger -OutDir "."
    
                New-Item -ItemType directory TestDrive:\abcd
                Push-Location TestDrive:\abcd
    
                Write-Log "msg"
            } finally {
                Pop-Location
                Pop-Location
                "TestDrive:\PesterLogger.Write-Log.changing location doesn't change the output directory.log" `
                    | Should -Exist
            }
        }

        It "writes correct messages" {
            Initialize-PesterLogger -OutDir "TestDrive:\"
            Write-Log "msg1"
            Write-Log "msg2"
            Get-Content "TestDrive:\PesterLogger.Write-Log.writes correct messages.log" | Should -Be @("msg1", "msg2")
        }
    }

    Context "Move-Logs" {
        It "appends collected logs to correct output file" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions $Sessions
            Write-Log "first message"
            Move-Logs -From $SourcePath
            $Content = Get-Content "TestDrive:\PesterLogger.Move-Logs.appends collected logs to correct output file.log"
            "first message" | Should -BeIn $Content
            "remote log text" | Should -BeIn $Content
        }

        It "cleans logs in source directory" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions $Sessions
            Move-Logs -From $SourcePath
            Test-Path $SourcePath | Should -Be $false
        }

        It "adds a prefix describing source directory" {
            Initialize-PesterLogger -OutDir "TestDrive:\" -Sessions $Sessions
            Write-Log "first message"
            Move-Logs -From $SourcePath
            $ContentRaw = Get-Content -Raw "TestDrive:\PesterLogger.Move-Logs.adds a prefix describing source directory.log"
            $ContentRaw | Should -BeLike "*$SourcePath*"
            $ComputerName = $Sessions[0].ComputerName
            $ContentRaw | Should -BeLike "*$ComputerName*"
        }

        It "works with multiple sessions" {
            $Sess
        }

        BeforeEach {
            $Sess1 = New-PSSession -ComputerName localhost
            $Sess2 = New-PSSession -ComputerName "127.0.0.1"
            $Sessions = @($Sess1, $Sess2)
            "remote log text" | Out-File "TestDrive:\remote.log"
            $SourcePath = ((Get-Item $TestDrive).FullName) + "\remote.log"
        }

        AfterEach {
            $Sessions | ForEach-Object {
                Remove-PSSession $_
            }
        }
    }

    Context "Initializing in BeforeEach" {
        It "registers Write-Log correctly" {
            Write-Log "hi"
            Get-Content "TestDrive:\PesterLogger.Initializing in BeforeEach.registers Write-Log correctly.log" `
                | Should -Be @("hi")
        }
        BeforeEach {
            Initialize-PesterLogger -OutDir "TestDrive:\"
        }
    }

    AfterEach {
        if (Get-Item function:Write-Log -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-Log
        }
    }
}
