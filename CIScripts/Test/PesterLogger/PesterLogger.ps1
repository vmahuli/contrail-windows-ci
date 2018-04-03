. $PSScriptRoot/../../Common/Aliases.ps1

. $PSScriptRoot/Get-CurrentPesterScope.ps1

function Initialize-PesterLogger {
    Param([Parameter(Mandatory = $true)] [string] $Outdir,
          [Parameter(Mandatory = $false)] [PSSessionT[]] $Sessions)

    # Closures don't capture functions, so we need to capture them as variables.
    $WriterFunc = Get-Item function:Add-ContentForce
    $DeducerFunc = Get-Item function:Get-CurrentPesterScope

    # This is so we can change location in our test cases but it won't affect location of logs.
    if (-not (Test-Path $Outdir)) {
        New-Item -Force -Path $Outdir -Type Directory
    }
    $ConstOutdir = Resolve-Path $Outdir

    $WriteLogFunc = {
        Param([Parameter(Mandatory = $true)] [string] $Message)
        $Scope = & $DeducerFunc
        $Filename = ($Scope -join ".") + ".log"
        $Outpath = Join-Path $Script:ConstOutdir $Filename
        & $WriterFunc -Path $Outpath -Value $Message
    }.GetNewClosure()

    Register-NewFunc -Name "Write-Log" -Func $WriteLogFunc

    $MoveLogsFunc = {
        Param([Parameter(Mandatory = $true)] [string] $From)
        $Script:Sessions | ForEach-Object {
            $Content = Invoke-Command -Session $_ {
                Get-Content $Using:From
            }
            Write-Log "-----------------------------------"
            Write-Log "Logs from $($_.ComputerName):$From : "
            Write-Log $Content
            Invoke-Command -Session $_ {
                Remove-Item $Using:From
            }
        }
    }.GetNewClosure()

    Register-NewFunc -Name "Move-Logs" -Func $MoveLogsFunc
}

function Add-ContentForce {
    Param([string] $Path, [string] $Value)
    if (-not (Test-Path $Path)) {
        New-Item -Force -Path $Path -Type File
    }
    Add-Content -Path $Path -Value $Value | Out-Null
}

function Register-NewFunc {
    Param([string] $Name, $Func)
    if (Get-Item function:$Name -ErrorAction SilentlyContinue) {
        Remove-Item function:$Name
    }
    New-Item -Path function:\ -Name Global:$Name -Value $Func | Out-Null
}