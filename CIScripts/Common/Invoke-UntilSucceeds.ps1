. $PSScriptRoot\Aliases.ps1
. $PSScriptRoot\Exceptions.ps1

function Invoke-UntilSucceeds {
    <#
    .SYNOPSIS
    Repeatedly calls a script block until its return value evaluates to true. Subsequent calls
    happen after Interval seconds. Will catch any exceptions that occur in the meantime.
    User has to specify a timeout after which the function fails by setting the Duration parameter.
    If the function fails, it throws an exception containing the last reason of failure.

    It is guaranteed that that if Invoke-UntilSucceeds had failed and precondition was true,
    there was at least one check performed at time T where T >= T_start + Duration
    .PARAMETER ScriptBlock
    ScriptBlock to repeatedly call.
    .PARAMETER Interval
    Interval (in seconds) between retries.
    .PARAMETER Duration
    Timeout (in seconds).
    .PARAMETER Precondition
    If the precondition is false or throws, abort the waiting immediately.
    .PARAMETER Name
    Name of the function to be used in exceptions' messages.
    .Parameter AssumeTrue
    If set, Invoke-UntilSucceeds doesn't check the returned value at all
    (it will still treat exceptions as failure though).
    #>
    Param (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)] [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory=$false)] [int] $Interval = 1,
        [Parameter(Mandatory=$true)] [int] $Duration = 3,
        [Parameter(Mandatory=$false)] [ScriptBlock] $Precondition,
        [Parameter(Mandatory=$false)] [String] $Name = "Invoke-UntilSucceds",
        [Switch] $AssumeTrue
    )
    if ($Duration -lt $Interval) {
        throw "Duration must be longer than interval"
    }
    if ($Interval -eq 0) {
        throw "Interval must not be equal to zero"
    }
    $StartTime = Get-Date

    while ($true) {
        $LastCheck = ((Get-Date) - $StartTime).TotalSeconds -ge $Duration

        if ($Precondition -and -not (Invoke-Command $Precondition)) {
            throw New-Object -TypeName CITimeoutException("Precondition was false, waiting aborted early")
        }

        try {
            $ReturnVal = Invoke-Command $ScriptBlock
            if ($AssumeTrue -Or $ReturnVal) {
                return $ReturnVal
            } else {
                throw New-Object -TypeName CITimeoutException("Did not evaluate to True." + 
                    "Last return value encountered was: $ReturnVal.")
            }
        } catch {
            if ($LastCheck) {
                throw New-Object -TypeName CITimeoutException("$Name failed.", $_.Exception)
            } else {
                Start-Sleep -Seconds $Interval
            }
        }
    }
}
