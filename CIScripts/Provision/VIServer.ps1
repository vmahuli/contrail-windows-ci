class VIServerAccessData {
    [string] $Username;
    [string] $Password;
    [string] $Server;
}

function Initialize-VIServer {
    Param ([Parameter(Mandatory = $true)] [VIServerAccessData] $VIServerAccessData)

    Push-Location

    # Global named mutex needed here because all PowerCLI commnads are running in global context and modify common configuration files.
    # Without this mutex, PowerCLI commands may throw an exception in case of configuration file being blocked by another job.
    $Mutex = [System.Threading.Mutex]::new($false, "WinContrailCIPowerCLIMutex")
    $MaxTimeout = 1000 * 60 * 10 # 10 min

    try {
        if (!$Mutex.WaitOne($MaxTimeout)) {
            throw "Timeout while waiting for mutex"
        }
    }
    catch [System.Threading.AbandonedMutexException] {
        [void] $Mutex.Close()
        throw "Global mutex has been abandoned. Try restarting the job."
    }

    try {
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
        Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$false | Out-Null

        Connect-VIServer -User $VIServerAccessData.Username -Password $VIServerAccessData.Password -Server $VIServerAccessData.Server | Out-Null
    }
    finally {
        [void] $Mutex.ReleaseMutex()
        [void] $Mutex.Close()
    }

    Pop-Location
}
