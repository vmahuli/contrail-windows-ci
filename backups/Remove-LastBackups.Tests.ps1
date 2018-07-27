. $PSScriptRoot\Remove-LastBackups.ps1

Describe 'Remove-LastBackups' -Tags CI, Unit {
    BeforeEach {
        $backupRepository = "TestDrive:\Backups\"
        New-Item -ItemType Directory -Path $backupRepository
    }

    AfterEach {
        Get-ChildItem TestDrive:\ | Remove-Item -Force -Recurse
    }

    It 'preserves last n directories in backup repository' {
        $dates = @(
            "20180701",
            "20180702",
            "20180703"
        )

        foreach ($date in $dates) {
            New-Item -ItemType Directory -Path (Join-Path $backupRepository $date)
        }

        Remove-LastBackups -Repository $backupRepository -PreserveCount 3

        $dir = Get-ChildItem $backupRepository -Directory
        $dir | Should -HaveCount 3
    }

    It 'preserves last n directories in backup repository, removing the oldest' {
        $dates = @(
            "20180701",
            "20180702",
            "20180703",
            "20180704",
            "20180705",
            "20180706",
            "20180707"
        )

        foreach ($date in $dates) {
            New-Item -ItemType Directory -Path (Join-Path $backupRepository $date)
        }

        Remove-LastBackups -Repository $backupRepository -PreserveCount 3

        $dir = Get-ChildItem $backupRepository -Directory
        $dir | Should -HaveCount 3
        ($dir | Where-Object Name -Match "20180707").FullName | Should -Exist
        ($dir | Where-Object Name -Match "20180706").FullName | Should -Exist
        ($dir | Where-Object Name -Match "20180705").FullName | Should -Exist
    }
}
