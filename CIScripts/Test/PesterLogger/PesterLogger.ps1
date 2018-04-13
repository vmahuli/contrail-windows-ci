. $PSScriptRoot/Get-CurrentPesterScope.ps1

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
        $Outpath = Join-Path $Script:ConstOutdir $Filename
        & $WriterFunc -Path $Outpath -Value $Message
    }.GetNewClosure()

    Register-NewWriteLogFunc -Func $WriteLogFunc
}

function Add-ContentForce {
    Param([string] $Path, [object] $Value)
    if (-not (Test-Path $Path)) {
        New-Item -Force -Path $Path -Type File | Out-Null
    }
    Add-Content -Path $Path -Value $Value | Out-Null
}

function Register-NewWriteLogFunc {
    Param($Func)
    if (Get-Item function:Write-Log -ErrorAction SilentlyContinue) {
        Remove-Item function:Write-Log
    }
    New-Item -Path function:\ -Name Global:Write-Log -Value $Func | Out-Null
}
