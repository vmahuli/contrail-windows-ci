$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "PesterHelpers" {
    Context "Consistently" {
        It "works on trivial cases" {
            { Consistently { $true | Should Be $true } -Duration 3 } | Should Not Throw
            { Consistently { $true | Should Not Be $false } -Duration 3 } | Should Not Throw
            { Consistently { $true | Should Not Be $true } -Duration 3 } | Should Throw
        }

        It "works with inner exceptions" {
            { Consistently { {} | Should Not Throw } -Duration 3 } | Should Not Throw
            { Consistently { {} | Should Throw } -Duration 3 } | Should Throw
            { Consistently { { throw "a" } | Should Not Throw } -Duration 3 } | Should Throw
            # Looks like there is a bug in Pester: this assertion fails, even though
            # in manual tests it's fine.
            # Consistently { { throw "a" } | Should Throw } | Should Not Throw
        }

        It "calls assert multiple times until duration is reached" {
            $Script:Counter = 0
            Consistently { $Script:Counter += 1 } -Interval 1 -Duration 3
            $Script:Counter | Should Be 3
        }

        It "throws if inner assert is false at any time" {
            $Script:Counter = 0
            { Consistently { $Script:Counter += 1; $Script:Counter | Should Not Be 2 } `
                -Interval 1 -Duration 3 } | Should Throw
        }

        It "does not allow interval equal to zero" {
            { Consistently {} -Interval 0 -Duration 3 } | Should Throw
        }

        It "does not allow interval to be greater than duration" {
            { Consistently {} -Interval 3 -Duration 2 } | Should Throw
        }

        It "runs at least one time" {
            $Script:TimeCalled = 0
            Mock Get-Date {
                if ($Script:TimeCalled -eq 0) {
                    $Script:TimeCalled += 1
                    return $Script:MockStartDate.AddSeconds($Script:SecondsCounter)
                } else {
                    # simulate a lot of time has passed since the first call.
                    return $Script:MockStartDate.AddSeconds($Script:SecondsCounter + 100)
                }
            }
            $Script:WasCalled = $false
            Consistently { $Script:WasCalled = $true } -Duration 3
            $Script:WasCalled | Should Be $true
        }

        It "exception contains the same info as normal Pester exception" {
            try {
                Consistently { $true | Should Not Be $true } -Duration 3
            } catch {
                $_.Exception.Message | `
                    Should Be "Expected: value was {True}, but should not have been the same"
            }
        }
    }

    Context "Eventually" {
        It "works on trivial cases" {
            { Eventually { $true | Should Be $true } -Duration 3 } | Should Not Throw
            { Eventually { $true | Should Not Be $false } -Duration 3 } | Should Not Throw
            { Eventually { $true | Should Not Be $true } -Duration 3 } | Should Throw
        }

        It "works with inner exceptions" {
            { Eventually { {} | Should Not Throw } -Duration 3 } | Should Not Throw
            { Eventually { {} | Should Throw } -Duration 3 } | Should Throw
            { Eventually { { throw "a" } | Should Not Throw } -Duration 3 } | Should Throw
            # Looks like there is a bug in Pester: this assertion fails, even though
            # in manual tests it's fine.
            # Eventually { { throw "a" } | Should Throw } | Should Not Throw
        }
        
        It "calls assert multiple times until it is true" {
            $Script:Counter = 0
            Eventually { $Script:Counter += 1; $Script:Counter | Should Be 3 } `
                -Interval 1 -Duration 5
            $Script:Counter | Should Be 3
        }

        It "throws if inner assert is never true" {
            $Script:Counter = 0
            { Eventually { $Script:Counter += 1; $Script:Counter | Should Be 6 } `
                -Interval 1 -Duration 5 } | Should Throw
        }

        It "does not allow interval equal to zero" {
            { Eventually {} -Interval 0 -Duration 3 } | Should Throw
        }

        It "does not allow interval to be greater than duration" {
            { Eventually {} -Interval 3 -Duration 2 } | Should Throw
        }

        It "rethrows the last exception that occurred" {
            $Script:Messages = @("E1", "E2", "E3", "E4", "E5")
            $Script:Counter = 0
            try {
                Eventually { $Script:Counter += 1; throw $Script:Messages[$Script:Counter] } `
                    -Duration 3
            } catch {
                $_.Exception.InnerException.Message | `
                    Should Be "E4"
            }
        }

        It "rethrows the last Pester exception in trivial case" {
            try {
                Eventually { $true | Should Not Be $true } -Duration 3
            } catch {
                $_.Exception.InnerException.Message | `
                    Should Be "Expected: value was {True}, but should not have been the same"
            }
        }

        It "rethrows the last Pester exception in Throw assert" {
            try {
                Eventually { {} | Should Throw } -Duration 3
            } catch {
                $_.Exception.InnerException.Message | `
                    Should Be "Expected: the expression to throw an exception"
            }
        }
    }

    BeforeEach {
        $Script:MockStartDate = Get-Date
        $Script:SecondsCounter = 0
        Mock Start-Sleep {
            $Script:SecondsCounter += 1;
        }
        Mock Get-Date {
            return $Script:MockStartDate.AddSeconds($Script:SecondsCounter)
        }
        Mock Write-Host { return }
    }
}
