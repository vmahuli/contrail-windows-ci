# Enable all invoked commands tracing for debugging purposes
if ($Env:ENABLE_TRACE -eq $true) {
    Set-PSDebug -Trace 1
}

# Set-PsDebug -Strict # TODO enable JW-1262

# Refresh Path
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Stop script on error
$ErrorActionPreference = "Stop"
