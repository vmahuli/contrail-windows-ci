function DeferExcept([scriptblock] $block) {
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

    return Invoke-Command -ScriptBlock {
        & {
            $ErrorActionPreference = "Continue"
            & $block
        }

        if (!$?) {
            if ($LASTEXITCODE -ne 0) {
                throw "Command ``$block`` failed with exitcode: $LASTEXITCODE"
            } else {
                throw "Command ``$block`` failed"
            }
        }
    }
}
