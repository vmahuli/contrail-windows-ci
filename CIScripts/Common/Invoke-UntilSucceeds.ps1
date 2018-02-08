. $PSScriptRoot\Aliases.ps1
. $PSScriptRoot\Exceptions.ps1

function Invoke-UntilSucceeds {
    <#
    .SYNOPSIS
    Repeatedly calls a script block until its return value evaluates to true. Subsequent calls
    happen after Interval seconds. Will catch any exceptions that occur in the meantime.
    User has to specify a timeout after which the function fails by setting the Duration parameter.
    If the function fails, it throws an exception containing the last reason of failure.
    .PARAMETER ScriptBlock
    ScriptBlock to repeatedly call.
    .PARAMETER Interval
    Interval (in seconds) between retries.
    .PARAMETER Duration
    Timeout (in seconds).
    #>
    Param (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)] [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory=$false)] [int] $Interval = 1,
        [Parameter(Mandatory=$true)] [int] $Duration = 3
    )
    if ($Duration -lt $Interval) {
        throw "Duration must be longer than interval"
    }
    if ($Interval -eq 0) {
        throw "Interval must not be equal to zero"
    }
    $StartTime = Get-Date
    $ReturnVal = $null
    do {
        try {
            $ReturnVal = & $ScriptBlock
            if ($ReturnVal) {
                break
            } else {
                throw New-Object -TypeName CITimeoutException("Did not evaluate to True." + 
                    "Last return value encountered was: $ReturnVal.")
            }
        } catch {
            $LastException = $_.Exception
            Start-Sleep -s $Interval
        }
    } while (((Get-Date) - $StartTime).Seconds -lt $Duration)

    if ($ReturnVal) {
        return $ReturnVal
    } else {
        $NewException = New-Object -TypeName CITimeoutException("Invoke-UntilSucceeds failed.",
            $LastException)
        throw $NewException
    }
}
