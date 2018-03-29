$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "PesterLogger" {
    Context "when inside Context block" {
        It "getting Pester scope works" {
            Get-CurrentPesterScope | Should BeExactly "PesterLogger.when inside Context block.getting Pester scope works"
        }
    }

    It "getting Pester scope works" {
        Get-CurrentPesterScope | Should BeExactly "PesterLogger.getting Pester scope works"
    }

    It "SANITY CHECK: hack tested only on Pester 4.2.0" {
        $PesterInfo = InModuleScope Pester {
            Get-Module Pester
        }
        $PesterInfo.Version | Should Be "4.2.0"
    }

    function InMemoryAddContent() {
        Param($Path, $Value)
        $Script:Content += $Value
        $Script:Path = $Path
    }

    BeforeEach {
        $Script:Content = ""
        $Script:Path = ""
    }

    Context "New-PesterLogger" {
        It "registers a new global Write-Log function" {
            New-PesterLogger -OutDir "some_dir"
            Get-Item function:Write-Log -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "unregisters previous Write-Log function and registers a new one" {
            function OldImpl {}
            Mock OldImpl {}
            New-Item function:Write-Log -Value OldImpl
            Write-Log "test"

            New-PesterLogger -OutDir "some_dir" -WriterFunc (Get-Item function:InMemoryAddContent)
            Get-Item function:Write-Log -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty

            Write-Log "test2"
            Assert-MockCalled OldImpl -Exactly -Times 1
        }
    }

    Context "Write-Log" {
        It "writes correct messages" {
            New-PesterLogger -OutDir "some_dir" -WriterFunc (Get-Item function:InMemoryAddContent)
            Write-Log "msg1"
            Write-Log "msg2"
            $Script:Content | Should Be "msg1msg2"
        }
        
        It "writes to correct file" {
            New-PesterLogger -OutDir "some_dir" -WriterFunc (Get-Item function:InMemoryAddContent)
            Write-Log "msg"
            $Script:Path | Should Be "some_dir/PesterLogger.Write-Log.writes to correct file.log"
        }
    }

    AfterEach {
        if (Get-Item function:Write-Log -ErrorAction SilentlyContinue) {
            Remove-Item function:Write-Log
        }
    }
}
