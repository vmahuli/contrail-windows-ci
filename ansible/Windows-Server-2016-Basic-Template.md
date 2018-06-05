# Windows Server 2016 - Basic template installation

### VM hardware

- 1 vCPU, hardware virtualization enabled
- 1 GB RAM
- 40 GB HDD, thin
    - SCSI Controller: VMware Paravirtual
- 1 NIC, E1000E

### OS installation

1. Language: English
1. Region: United States
1. Keyboard: US
1. Version: Windows Server 2016 Datacenter (no GUI)
1. Custom Install
    - No drivers?
        - Unmount Windows ISO
        - Mount VMware Tools ISO
        - Select "Load driver"
        - Find "D:\Program Files\VMware Tools\Drivers\pvscsi\Win8\amd64"
        - Choose "VMware PVSCSI Controller" driver
        - Unmount VMware Tools ISO
        - Mount Windows ISO
1. Partition new drive
1. Install

### Configuration

1. On first login - setup credentials
1. Shutdown and unmount Windows ISO (deselect connected and change to client device)
    - `NFS-Datastore` should not appear in `Related Objects of the machine`
1. Power on
1. Mount VMware tools and install (`Typical` option)
1. Basic setup in `sconfig`
    - Domain: `WORKGROUP`
    - Computer name: `tmpl-winsrv2016`
    - Windows Update settings: `Manual`
    - Remote Desktop: `Enable` > `All clients (Less secure)`
    - Network settings:
        - 1 NIC, DHCP Enabled
    - Date and time: nothing, will do later
    - Telemetry settings: Basic
1. Timezone configuration

    ```powershell
    Set-TimeZone -Name "Pacific Standard Time"
    w32tm /config /syncfromflags:manual /manualpeerlist:"$ntpServerAddress"
    Restart-Service w32time
    w32tm /resync
    w32tm /query /status
    ```

1. Restart computer
1. License configuration

    ```powershell
    # Set KMS server address
    slmgr.vbs /skms ${kmsServerAddress}:${kmsServerPort}
    # Activate Windows
    slmgr.vbs /ato
    # Check if succeeded
    slmgr.vbs /dlv
    ```

1. Updates (using sconfig)
1. Password policy change

    ```powershell
    Set-LocalUser -Name Administrator -PasswordNeverExpires:$true
    ```

1. Disable firewall

    ```powershell
    Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False
    ```

1. Configure Ansible remoting

    ```powershell
    wget https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1 -OutFile ConfigureRemotingForAnsible.ps1
    .\ConfigureRemotingForAnsible.ps1 -DisableBasicAuth -EnableCredSSP -ForceNewSSLCert -SkipNetworkProfileCheck
    ```

1. Cleanup

    ```powershell
    Dism /Online /Cleanup-Image /StartComponentCleanup
    ```

1. Shutdown VM
1. Convert to template
