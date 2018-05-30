. $PSScriptRoot/../../Common/Aliases.ps1

. $PSScriptRoot/Get-CurrentPesterScope.ps1

class UnsupportedPesterTestNameException : System.Exception {
    UnsupportedPesterTestNameException([string] $msg) : base($msg) {}
    UnsupportedPesterTestNameException([string] $msg, [System.Exception] $inner) : base($msg, $inner) {}
}

function Initialize-PesterLogger {
    Param([Parameter(Mandatory = $true)] [string] $Outdir)

    # Closures don't capture functions, so we need to capture them as variables.
    $WriterFunc = Get-Item function:Add-ContentForce
    $DeducerFunc = Get-Item function:Get-CurrentPesterScope

    if (-not (Test-Path $Outdir)) {
        New-Item -Force -Path $Outdir -Type Directory | Out-Null
    }
    # This is so we can change location in our test cases but it won't affect location of logs.
    $ConstOutdir = Resolve-Path $Outdir

    $WriteLogFunc = {
        Param([Parameter(Mandatory = $true)] [object] $Message)
        $Scope = & $DeducerFunc
        $Filename = ($Scope -join ".") + ".log"
        if (($Filename.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())) -ne -1) {
            throw [UnsupportedPesterTestNameException] "Invalid test name; it cannot contain some special characters, like ':', '/', etc."
        }
        $Outpath = Join-Path $Script:ConstOutdir $Filename
        & $WriterFunc -Path $Outpath -Value $Message
    }.GetNewClosure()

    Register-NewFunc -Name "Write-LogImpl" -Func $WriteLogFunc
}

function Add-ContentForce {
    Param([string] $Path, [object] $Value)
    if (-not (Test-Path $Path)) {
        New-Item -Force -Path $Path -Type File | Out-Null
    }
    Add-Content -Path $Path -Value $Value | Out-Null
}

function Register-NewFunc {
    Param([Parameter(Mandatory = $true)] [string] $Name,
          [Parameter(Mandatory = $true)] [ScriptBlock] $Func)
    if (Get-Item function:$Name -ErrorAction SilentlyContinue) {
        Remove-Item function:$Name
    }
    New-Item -Path function:\ -Name Global:$Name -Value $Func | Out-Null
}

function Write-Log {
    if (Get-Item function:Write-LogImpl -ErrorAction SilentlyContinue) {
        # This function is injected into scope by Initialize-PesterLogger
        Write-LogImpl @Args # Analyzer: Allow Write-LogImpl
    } else {
        Write-Host @Args
    }
}
