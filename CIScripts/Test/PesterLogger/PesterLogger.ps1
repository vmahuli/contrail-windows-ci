. $PSScriptRoot/Get-CurrentPesterScope.ps1

function New-PesterLogger {
    Param([Parameter(Mandatory = $true)] [string] $Outdir,
          $WriterFunc = (Get-Item function:Add-ContentForce))

    $DeducerFunc = Get-Item function:Get-CurrentPesterScope

    $WriteLogFunc = {
        Param([Parameter(Mandatory = $true)] [string] $Message)
        $Scope = & $DeducerFunc
        $Outpath = $Script:Outdir
        $Scope | ForEach-Object { $Outpath = Join-Path $Outpath $_ }
        $Outpath += ".log"
        & $WriterFunc -Path $Outpath -Value $Message
    }.GetNewClosure()

    Register-NewWriteLogFunc -Func $WriteLogFunc
}

function Add-ContentForce {
    Param([string] $Path, [string] $Value)
    if (-not (Test-Path $Path)) {
        New-Item -Force -Path $Path -Type File
    }
    Add-Content -Path $Path -Value $Value
}

function Register-NewWriteLogFunc {
    Param($Func)
    if (Get-Item function:Write-Log -ErrorAction SilentlyContinue) {
        Remove-Item function:Write-Log
    }
    New-Item -Path function:\ -Name Global:Write-Log -Value $Func
}
