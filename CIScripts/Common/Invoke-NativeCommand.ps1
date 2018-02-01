function Invoke-NativeCommand {
    Param (
        [Parameter(Mandatory = $false)] [Bool] $AllowNonZero = $false,
        [Parameter(Mandatory = $true)] [ScriptBlock] $ScriptBlock
    )
    # Utility wrapper.
    # We encountered issues when trying to run non-powershell commands in a script, when it's
    # called from Jenkinsfile.
    # Everything that is printed to stderr in those external commands immediately causes an
    # exception to be thrown (as well as kills the command).
    # We don't want this, but we also want to know whether the command was successful or not.
    # This is what this wrapper aims to do.
    # 
    # This wrapper will throw only if the whole command failed. It will suppress any exceptions
    # when the command is running.
    #
    # Also, **every** execution of any native command should use this wrapper,
    # because Jenkins misinterprets $LastExitCode variable.
    #
    # Note: The command has to return 0 exitcode to be considered successful.

    # If an executable in $ScriptBlock wouldn't be found then while checking $LastExitCode
    # we would be checking the exit code of a previous command. To avoid this we clear $LastExitCode.
    $Global:LastExitCode = $null

    & {
        # Since we're redirecting stderr to stdout we shouldn't have to set ErrorActionPreference
        # but because of a bug in Powershell we have to.
        # https://github.com/PowerShell/PowerShell/issues/4002
        $ErrorActionPreference = "Continue"

        # We redirect stderr to stdout so nothing is added to $Error.
        # We do this to be compliant to durable-task-plugin 1.18.
        & $ScriptBlock 2>&1
    }

    if ($AllowNonZero -eq $false -and $LastExitCode -ne 0) {
        throw "Command ``$block`` failed with exitcode: $LastExitCode"
    }

    if ($AllowNonZero) {
        Write-Output $LastExitCode
    }

    # We clear it to be compliant with durable-task-plugin up to 1.17
    $Global:LastExitCode = $null
}
