. $PSScriptRoot/PesterLogger.ps1

class LogSource {
    [PSSessionT] $Session

    # @{ Path: path } or @{ Container: container }
    [Hashtable] $Source
}

function New-ContainerLogSource {
    Param([Parameter(Mandatory = $true)] [string[]] $ContainerNames,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        $Session = $_
        $ContainerNames | ForEach-Object {
            [LogSource] @{
                Session = $Session
                Source = @{ Container = $_ }
            }
        }
    }
}

function New-FileLogSource {
    Param([Parameter(Mandatory = $true)] [string] $Path,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        [LogSource] @{
            Session = $_
            Source = @{ Path = $Path }
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

function Get-FileLogContent {
    param([PSSessionT] $Session, [String] $Path)
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
    Invoke-CommandRemoteOrLocal -Func $ContentGetterBody -Session $Session -Arguments $Path
}

function Clear-FileLogContent {
    param([PSSessionT] $Session, [String] $Path)
    $LogCleanerBody = {
        Param([Parameter(Mandatory = $true)] [string] $What)
        $Files = Get-ChildItem -Path $What -ErrorAction SilentlyContinue
        foreach ($File in $Files) {
            Remove-Item $File
        }
    }
    Invoke-CommandRemoteOrLocal -Func $LogCleanerBody -Session $Session -Arguments $Path
}

function Get-ContainerLogContent {
    param([PSSessionT] $Session, [String] $ContainerName)
    throw "unimplemented"
}

function Get-LogContent {
    param([LogSource] $LogSource)

    if ($LogSource.Source['Path']) {
        Get-FileLogContent -Session $LogSource.Session -Path $LogSource.Source.Path
    } elseif ($LogSource.Source['Container']) {
        Get-ContainerLogContent -Session $LogSource.Session -Container $LogSource.Source.Container
    } else {
        throw "Unkonwn LogSource source: $( $LogSource.Source )"
    }
}

function Clear-LogContent {
    param([LogSource] $LogSource)

    if ($LogSource.Source['Path']) {
        Clear-FileLogContent -Session $LogSource.Session -Path $LogSource.Source.Path
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

        $Logs = Get-LogContent -LogSource $LogSource
        foreach ($Log in $Logs.GetEnumerator()) {
            $SourceFilenamePrefix = "Contents of $($Log.Key):"
            Write-Log ("-" * 100)
            Write-Log $SourceFilenamePrefix
            Write-Log $Log.Value
        }
        
        if (-not $DontCleanUp) {
            Clear-LogContent -LogSource $LogSource
        }
    }
}
