. $PSScriptRoot\..\..\Common\Aliases.ps1
. $PSScriptRoot\..\PesterLogger\PesterLogger.ps1

function Start-UDPEchoServerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [Int16] $ServerPort,
        [Parameter(Mandatory=$true)] [Int16] $ClientPort
    )
    $UDPEchoServerCommand = ( `
    '$SendPort = {0};' + `
    '$RcvPort = {1};' + `
    '$IPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, $RcvPort);' + `
    '$UDPSocket = New-Object System.Net.Sockets.UdpClient($IPEndpoint);' + `
    '$RemoteIPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, 0);' + `
    'while($true) {{' + `
    '    $Payload = $UDPSocket.Receive([ref]$RemoteIPEndpoint);' + `
    '    $RemoteIPEndpoint.Port = $SendPort;' + `
    '    $UDPSocket.Send($Payload, $Payload.Length, $RemoteIPEndpoint);' + `
    '    \"Received message and sent it to: $RemoteIPEndpoint.\" | Out-String;' + `
    '}}') -f $ClientPort, $ServerPort

    Invoke-Command -Session $Session -ScriptBlock {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "UDPEchoServerJob",
            Justification="It's actually used."
        )]
        $UDPEchoServerJob = Start-Job -ScriptBlock {
            param($ContainerName, $UDPEchoServerCommand)
            docker exec $ContainerName powershell "$UDPEchoServerCommand"
        } -ArgumentList $Using:ContainerName, $Using:UDPEchoServerCommand
    }
}

function Stop-EchoServerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $Output = Invoke-Command -Session $Session -ScriptBlock {
        $UDPEchoServerJob | Stop-Job | Out-Null
        $Output = Receive-Job -Job $UDPEchoServerJob
        return $Output
    }

    Write-Log "Output from UDP echo server running in remote session: $Output"
}

function Start-UDPListenerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [Int16] $ListenerPort
    )
    $UDPListenerCommand = ( `
    '$RemoteIPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, 0);' + `
    '$UDPRcvSocket = New-Object System.Net.Sockets.UdpClient {0};' + `
    '$Payload = $UDPRcvSocket.Receive([ref]$RemoteIPEndpoint);' + `
    '[Text.Encoding]::UTF8.GetString($Payload)') -f $ListenerPort

    Invoke-Command -Session $Session -ScriptBlock {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "UDPListenerJob",
            Justification="It's actually used."
        )]
        $UDPListenerJob = Start-Job -ScriptBlock {
            param($ContainerName, $UDPListenerCommand)
            & docker exec $ContainerName powershell "$UDPListenerCommand"
        } -ArgumentList $Using:ContainerName, $Using:UDPListenerCommand
    }
}

function Stop-UDPListenerInContainerAndFetchResult {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $Message = Invoke-Command -Session $Session -ScriptBlock {
        $UDPListenerJob | Wait-Job -Timeout 30 | Out-Null
        $ReceivedMessage = Receive-Job -Job $UDPListenerJob
        return $ReceivedMessage
    }
    Write-Log "UDP listener output from remote session: $Message"
    return $Message
}


function Send-UDPFromContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [String] $Message,
        [Parameter(Mandatory=$true)] [String] $ListenerIP,
        [Parameter(Mandatory=$true)] [Int16] $ListenerPort,
        [Parameter(Mandatory=$true)] [Int16] $NumberOfAttempts,
        [Parameter(Mandatory=$true)] [Int16] $WaitSeconds
    )
    $UDPSendCommand = (
    '$EchoServerAddress = New-Object System.Net.IPEndPoint([IPAddress]::Parse(\"{0}\"), {1});' + `
    '$UDPSenderSocket = New-Object System.Net.Sockets.UdpClient 0;' + `
    '$Payload = [Text.Encoding]::UTF8.GetBytes(\"{2}\");' + `
    '1..{3} | ForEach-Object {{' + `
    '    $UDPSenderSocket.Send($Payload, $Payload.Length, $EchoServerAddress);' + `
    '    Start-Sleep -Seconds {4};' + `
    '}}') -f $ListenerIP, $ListenerPort, $Message, $NumberOfAttempts, $WaitSeconds

    $Output = Invoke-Command -Session $Session -ScriptBlock {
        docker exec $Using:ContainerName powershell "$Using:UDPSendCommand"
    }
    Write-Log "Send UDP output from remote session: $Output"
}

function Test-UDP {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session1,
        [Parameter(Mandatory=$true)] [PSSessionT] $Session2,
        [Parameter(Mandatory=$true)] [String] $Container1Name,
        [Parameter(Mandatory=$true)] [String] $Container2Name,
        [Parameter(Mandatory=$true)] [String] $Container1IP,
        [Parameter(Mandatory=$true)] [String] $Container2IP,
        [Parameter(Mandatory=$true)] [String] $Message,
        [Parameter(Mandatory=$true)] [Int16] $UDPServerPort,
        [Parameter(Mandatory=$true)] [Int16] $UDPClientPort
    )

    Write-Log "Starting UDP Echo server on container $Container1Name ..."
    Start-UDPEchoServerInContainer `
        -Session $Session1 `
        -ContainerName $Container1Name `
        -ServerPort $UDPServerPort `
        -ClientPort $UDPClientPort

    Write-Log "Starting UDP listener on container $Container2Name..."
    Start-UDPListenerInContainer `
        -Session $Session2 `
        -ContainerName $Container2Name `
        -ListenerPort $UDPClientPort

    Write-Log "Sending UDP packet from container $Container2Name..."
    Send-UDPFromContainer `
        -Session $Session2 `
        -ContainerName $Container2Name `
        -Message $Message `
        -ListenerIP $Container1IP `
        -ListenerPort $UDPServerPort `
        -NumberOfAttempts 10 `
        -WaitSeconds 1

    Write-Log "Fetching results from listener job..."
    $ReceivedMessage = Stop-UDPListenerInContainerAndFetchResult -Session $Session2
    Stop-EchoServerInContainer -Session $Session1

    Write-Log "Sent message: $Message"
    Write-Log "Received message: $ReceivedMessage"
    if ($ReceivedMessage -eq $Message) {
        return $true
    } else {
        return $false
    }
}