$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Invoke-UntilSucceeds" {
    It "fails if ScriptBlock doesn't return anything" {
        { {} | Invoke-UntilSucceeds -Duration 3 } | Should Throw
    }

    It "fails if ScriptBlock never returns true" {
        { { return $false } | Invoke-UntilSucceeds -Duration 3 } | Should Throw
    }

    It "fails if ScriptBlock only throws all the time" {
        { { throw "abcd" } | Invoke-UntilSucceeds -Duration 3 } | Should Throw
    }

    It "succeeds if ScriptBlock is immediately true" {
        { { return $true } | Invoke-UntilSucceeds -Duration 3 } | Should Not Throw
        { return $true } | Invoke-UntilSucceeds -Duration 3 | Should Be $true
    }

    It "succeeds for other values than pure `$true" {
        { { return "abcd" } | Invoke-UntilSucceeds -Duration 3 } | Should Not Throw
        { return "abcd" } | Invoke-UntilSucceeds -Duration 3 | Should Be "abcd"
    }

    It "can be called by not using pipe operator" {
        $Ret = Invoke-UntilSucceeds { return "abcd" } -Interval 2 -Duration 4
        $Ret | Should Be "abcd"
        Invoke-UntilSucceeds { return "abcd" } -Duration 3 | Should Be "abcd"
    }

    It "succeeds if ScriptBlock is eventually true" {
        $Script:Counter = 0
        { { 
            $Script:Counter += 1;
            return ($Script:Counter -eq 3)
        } | Invoke-UntilSucceeds -Duration 3 } `
            | Should Not Throw
    }

    It "keeps retrying even when exception is throw" {
        $Script:Counter = 0
        { { 
            $Script:Counter += 1;
            if ($Script:Counter -eq 1) {
                return $false 
            } elseif ($Script:Counter -eq 2) {
                throw "nope"
            } elseif ($Script:Counter -eq 3) {
                return $true
            }
        } | Invoke-UntilSucceeds -Duration 3 } `
            | Should Not Throw
    }

    It "retries until specified timeout is reached with sleeps in between" {
        $StartDate = Get-Date
        $ExpectedAfter = ($StartDate).AddSeconds(3)
        { { return $false } | Invoke-UntilSucceeds -Interval 1 -Duration 3 } | Should Throw
        (Get-Date).Second | Should BeExactly $ExpectedAfter.Second
    }

    It "does not allow interval equal to zero" {
        { Invoke-UntilSucceeds {} -Interval 0 -Duration 3} | Should Throw
    }

    It "does not allow interval to be greater than duration" {
        { Invoke-UntilSucceeds {} -Interval 3 -Duration 2 } | Should Throw
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
        Invoke-UntilSucceeds {
            $Script:WasCalled = $true;
            return $true 
        } -Interval 1 -Duration 1
        $Script:WasCalled | Should Be $true
    }

    It "rethrows the last exception" {
        $HasThrown = $false
        try {
            { throw "abcd" } | Invoke-UntilSucceeds -Duration 3
        } catch {
            $HasThrown = $true
            $_.Exception.GetType().FullName | Should be "CITimeoutException"
            $_.Exception.InnerException.Message | Should Be "abcd"
        }
        $HasThrown | Should Be $true
    }

    It "throws a descriptive exception in case of never getting true" {
        $HasThrown = $false
        try {
            { return $false } | Invoke-UntilSucceeds -Duration 3
        } catch {
            $HasThrown = $true
            $_.Exception.GetType().FullName | Should be "CITimeoutException"
            $_.Exception.InnerException.Message | Should BeLike "*False."
        }
        $HasThrown | Should Be $true
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
    }
}
