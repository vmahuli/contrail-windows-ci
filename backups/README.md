contrail-windows-ci - infrastructure backups
============================================

## How to perform infrastructure backups

**Prerequisites**

- RDP access to `winci-veeam` virtual machine
- Credentials to `winci-veeam` virtual machine

**Steps**

1. Connect with RDP to `winci-veeam` virtual machine
1. Open PowerShell console
1. Create a temporary directory and enter it

    ```powershell
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item $path -ItemType Directory
    pushd $path
    ```

1. Clone `contrail-windows-ci` repository and enter `backups` directory

    ```powershell
    git clone https://github.com/Juniper/contrail-windows-ci.git
    cd contrail-windows-ci/backups
    ```

1. Run backup script

   ```powershell
   .\Backup.ps1
   ```

1. After backup script finishes exit temporary directory and remove it

    ```powershell
    popd
    Remove-Item $path -Recurse
    ```

## How to restore a VM from backup

**TODO**
