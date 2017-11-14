. $PSScriptRoot\..\Common\VMUtils.ps1
. $PSScriptRoot\..\Common\Aliases.ps1

class NewVMCreationSettings {
    [string] $ResourcePoolName;
    [string] $TemplateName;
    [string] $CustomizationSpecName;
    [string[]] $DatastoresList;
    [string] $NewVMLocation;
}

function New-TestbedVMs {
    [CmdletBinding(DefaultParametersetName = "None")]
    Param ([Parameter(Mandatory = $true, HelpMessage = "List of names of created VMs")] [string[]] $VMNames,
           [Parameter(Mandatory = $true, HelpMessage = "Access data for VIServer")] [VIServerAccessData] $VIServerAccessData,
           [Parameter(Mandatory = $true, HelpMessage = "Settings required for creating new VM")] [NewVMCreationSettings] $VMCreationSettings,
           [Parameter(Mandatory = $true, HelpMessage = "Credentials required to access created VMs")] [PSCredentialT] $VMCredentials,
           [Parameter(Mandatory = $true, HelpMessage = "Location of crash dump files")] [string] $DumpFilesLocation,
           [Parameter(Mandatory = $true, HelpMessage = "Crash dump files base name (prefix)")] [string] $DumpFilesBaseName,
           [Parameter(Mandatory = $true, HelpMessage = "Max time to wait for VMs")] [int] $MaxWaitVMMinutes,
           [Parameter(HelpMessage = "Switch indicating if MSVC debug DLLs should be copied", ParameterSetName = "CopyMsvcDebugDlls")] [switch] $CopyMsvcDebugDlls,
           [Parameter(Mandatory = $true, HelpMessage = "Directory with MSVC debug DLLs", ParameterSetName = "CopyMsvcDebugDlls")] [string] $MsvcDebugDllsDir)

    function New-StartedVM {
        Param ([Parameter(Mandatory = $true)] [string] $VMName,
               [Parameter(Mandatory = $true)] [NewVMCreationSettings] $VMCreationSettings)

        Write-Host "Creating and starting $VMName"
        $ResourcePool = Get-ResourcePool -Name $VMCreationSettings.ResourcePoolName
        $Template = Get-Template -Name $VMCreationSettings.TemplateName
        $CustomizationSpec = Get-OSCustomizationSpec -Name $VMCreationSettings.CustomizationSpecName

        $AllDatastores = Get-Datastore -Name $VMCreationSettings.DatastoresList
        $EmptiestDatastore = ($AllDatastores | Sort-Object -Property FreeSpaceGB -Descending)[0]

        New-VM -Name $VMName -Template $Template -Datastore $EmptiestDatastore -ResourcePool $ResourcePool -Location $VMCreationSettings.NewVMLocation `
            -OSCustomizationSpec $CustomizationSpec -ErrorAction Stop -Verbose | Out-Null
        #New-HardDisk -VM $vm -CapacityGB 2 -Datastore DUMP -StorageFormat thin -Controller (Get-ScsiController -VM $vm) -Persistence IndependentPersistent -Verbose # TODO: Fix after JW-796
        Start-VM -VM $VMName -Confirm:$false -ErrorAction Stop -Verbose | Out-Null
    }

    function Wait-VMs {
        Param ([Parameter(Mandatory = $true)] [Collections.Generic.List[String]] $VMNamesList,
               [Parameter(Mandatory = $false)] [int] $MaxWaitMinutes = 15)

        $DelaySec = 30
        $MaxRetries = [math]::Ceiling($MaxWaitMinutes * 60 / $DelaySec)

        for ($RetryNum = 0; $VMNamesList.Count -ne 0; ) {
            Write-Host "Retry number $RetryNum / $MaxRetries"
            ping $VMNamesList[0] | Out-Null

            if ($? -eq $true) {
                $VMNamesList.RemoveAt(0)
                continue
            }

            Start-Sleep -s $DelaySec
            $RetryNum++

            if ($RetryNum -gt $MaxRetries) {
                throw "Waited for too long. The VMs did not respond in maximum expected time."
            }
        }
    }

    function Enable-NBLDebugging {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

        Invoke-Command -Session $Session -ScriptBlock {
            # Enable tracing of NBL owner, so that !ndiskd.pendingnbls debugger extension can search and identify lost NBLs.
            New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\NDIS\Parameters" -Name TrackNblOwner -Value 1 -PropertyType DWORD -Force | Out-Null
        }
    }

    function Initialize-CrashDumpSaving {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [string] $DumpFilesLocation,
               [Parameter(Mandatory = $true)] [string] $DumpFilesBaseName)

        $DumpFilename = $DumpFilesLocation + "\" + $DumpFilesBaseName + "_" + $Session.ComputerName + ".dmp"

        Invoke-Command -Session $Session -ScriptBlock {
            # TODO: Fix after JW-796
            <#Get-Disk | Where-Object PartitionStyle -eq 'raw' |
                Initialize-Disk -PartitionStyle MBR -PassThru |
                New-Partition -AssignDriveLetter -UseMaximumSize |
                Format-Volume -FileSystem NTFS -NewFileSystemLabel "DUMP_HD" -Confirm:$false | Out-Null#>

            New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name DumpFile -PropertyType ExpandString -Value $Using:DumpFilename -Force | Out-Null
        }
    }

    function Copy-MsvcDebugDlls {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [string] $MsvcDebugDllsDir)

        Invoke-Command -Session $Session -ScriptBlock {
            Copy-Item -Path "$Using:MsvcDebugDllsDir\*.dll" -Destination "C:\Windows\system32\"
        }
    }

    Write-Host "Connecting to VIServer"
    Initialize-VIServer -VIServerAccessData $VIServerAccessData

    Write-Host "Starting VMs"
    $VMNames.ForEach({ New-StartedVM -VMName $_ -VMCreationSettings $VMCreationSettings })

    Write-Host "Waiting for VMs to start..."
    $VMsList = [Collections.Generic.List[String]] $VMNames
    Wait-VMs -VMNames $VMsList -MaxWaitMinutes $MaxWaitVMMinutes

    $Sessions = New-RemoteSessions -VMNames $VMNames -Credentials $VMCredentials

    Write-Host "Initializing Crash dump saving and configuring NBL debugging"
    $Sessions.ForEach({
        Initialize-CrashDumpSaving -Session $_ -DumpFilesLocation $DumpFilesLocation -DumpFilesBaseName $DumpFilesBaseName
        Enable-NBLDebugging -Session $_
    })

    if ($CopyMsvcDebugDlls.IsPresent) {
        Write-Host "Copying MSVC debug DLLs"
        $Sessions.ForEach({ Copy-MsvcDebugDlls -Session $_ -MsvcDebugDllsDir $MsvcDebugDllsDir })
    }

    return $Sessions
}

function Remove-TestbedVMs {
    Param ([Parameter(Mandatory = $true, HelpMessage = "List of names of VMs")] [string[]] $VMNames,
           [Parameter(Mandatory = $true, HelpMessage = "Access data for VIServer")] [VIServerAccessData] $VIServerAccessData)

    Initialize-VIServer -VIServerAccessData $VIServerAccessData

    $VMNames.ForEach({
        Write-Host "Removing $_ from datastore"
        Stop-VM -VM $_ -Kill -Confirm:$false | Out-Null
        Remove-VM -VM $_ -DeletePermanently -Confirm:$false | Out-Null
    })
}

function Get-SanitizedOrGeneratedVMName {
    Param ([Parameter(Mandatory = $true, HelpMessage = "Name to check. It will be regenerated if needed.")] [string] $VMName,
           [Parameter(Mandatory = $true, HelpMessage = "Prefix added to randomly generated name")] [string] $RandomNamePrefix)

    $VMName = $VMName.Replace("_", "-")
    $VMName = [Regex]::Replace($VMName, "[^0-9a-zA-Z-]", [string]::Empty)

    if (($VMName -eq "Auto") -or ($VMName.Length -eq 0)) {
        return $RandomNamePrefix + [string]([guid]::NewGuid().Guid).Replace("-", "").ToUpper().Substring(0, 6)
    }

    return $VMName
}
