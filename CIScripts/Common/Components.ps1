function Get-ComponentsToBuild {
    if (Test-Path Env:COMPONENTS_TO_BUILD) {
        return $Env:COMPONENTS_TO_BUILD.Split(",")
    } else {
        return @("DockerDriver", "Extension", "Agent")
    }
}
