. $PSScriptRoot/PesterLogger.ps1

function New-LogSource {
    Param([Parameter(Mandatory = $true)] [string] $Path,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    return $Sessions | ForEach-Object {
        @{
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

function Get-LogContent {
    param([System.Collections.Hashtable] $LogSource)
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
    Invoke-CommandRemoteOrLocal -Func $ContentGetterBody -Session $LogSource.Session -Arguments $LogSource.Path
}

function Clear-LogContent {
    param([System.Collections.Hashtable] $LogSource)
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
    Invoke-CommandRemoteOrLocal -Func $LogCleanerBody -Session $LogSource.Session -Arguments $LogSource.Path
}

function Merge-Logs {
    Param([Parameter(Mandatory = $true)] [System.Collections.Hashtable[]] $LogSources,
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
