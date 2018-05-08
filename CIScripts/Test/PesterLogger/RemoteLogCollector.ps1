. $PSScriptRoot/../../Common/Aliases.ps1
. $PSScriptRoot/../../Common/Invoke-NativeCommand.ps1

. $PSScriptRoot/PesterLogger.ps1

class LogSource {
    [System.Management.Automation.Runspaces.PSSession] $Session

    [Hashtable] GetContent() {
        throw "LogSource is an abstract class, use specific log source instead"
    }

    ClearContent() {
        throw "LogSource is an abstract class, use specific log source instead"
    }
}

class FileLogSource : LogSource {
    [String] $Path

    [Hashtable] GetContent() {
        $ContentGetterBody = {
            Param([Parameter(Mandatory = $true)] [string] $From)
            $Files = Get-ChildItem -Path $From -ErrorAction SilentlyContinue
            $Logs = @{}
            if (-not $Files) {
                $Logs[$From] = "<FILE NOT FOUND>"
            } else {
                foreach ($File in $Files) {
                    $Content = Get-Content -Raw $File
                    $Logs[$File.FullName] = if ($Content) {
                        $Content
                    } else {
                        "<FILE WAS EMPTY>"
                    }
                }
            }
            return $Logs
        }
        return Invoke-CommandRemoteOrLocal -Func $ContentGetterBody -Session $this.Session -Arguments $this.Path
    }

    ClearContent() {
        $LogCleanerBody = {
            Param([Parameter(Mandatory = $true)] [string] $What)
            $Files = Get-ChildItem -Path $What -ErrorAction SilentlyContinue
            foreach ($File in $Files) {
                try {
                    Remove-Item $File
                }
                catch {
                    Write-Warning "$File was not removed due to $_"
                }
            }
        }
        Invoke-CommandRemoteOrLocal -Func $LogCleanerBody -Session $this.Session -Arguments $this.Path
    }
}

class ContainerLogSource : LogSource {
    [String] $Container

    [Hashtable] GetContent() {
        $Command = Invoke-NativeCommand -Session $this.Session -CaptureOutput -AllowNonZero {
            docker logs $Using:this.Container
        }
        return @{
            "$( $this.Container ) container logs" = $Command.Output
        }
    }

    ClearContent() {
        # It's not possible to clear docker container logs,
        # but the --since flag may be used in GetContent instead.
    }
}

function New-ContainerLogSource {
    Param([Parameter(Mandatory = $true)] [string[]] $ContainerNames,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        $Session = $_
        $ContainerNames | ForEach-Object {
            [ContainerLogSource] @{
                Session = $Session
                Container = $_
            }
        }
    }
}

function New-FileLogSource {
    Param([Parameter(Mandatory = $true)] [string] $Path,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        [FileLogSource] @{
            Session = $_
            Path = $Path
        }
    }
}

function Invoke-CommandRemoteOrLocal {
    param([ScriptBlock] $Func, [PSSessionT] $Session, [Object[]] $Arguments) 
    if ($Session) {
        Invoke-Command -Session $Session $Func -ArgumentList $Arguments
    } else {
        Invoke-Command $Func -ArgumentList $Arguments
    }
}

function Merge-Logs {
    Param([Parameter(Mandatory = $true)] [LogSource[]] $LogSources,
          [Parameter(Mandatory = $false)] [switch] $DontCleanUp)

    foreach ($LogSource in $LogSources) {
        $SourceHost = if ($LogSource.Session) {
            $LogSource.Session.ComputerName
        } else {
            "localhost"
        }
        $ComputerNamePrefix = "Logs from $($SourceHost): "
        Write-Log ("=" * 100)
        Write-Log $ComputerNamePrefix

        $Logs = $LogSource.GetContent()
        foreach ($Log in $Logs.GetEnumerator()) {
            $SourceFilenamePrefix = "Contents of $($Log.Key):"
            Write-Log ("-" * 100)
            Write-Log $SourceFilenamePrefix
            Write-Log $Log.Value
        }
        
        if (-not $DontCleanUp) {
            $LogSource.ClearContent()
        }
    }
}
