<#
    Tests the owner cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidAssignmentToAutomaticVariable', '', Justification = 'A test shadows $PWD on purpose (#86).'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # With the Backup privilege, Windows may grant reading the owner despite a deny entry.
    $canBypassDeny = Test-PrivilegeHeld -Name 'SeBackupPrivilege'
    # Assigning an owner other than the user or one of its groups needs the Restore privilege.
    $canAssignAnyOwner = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Owner'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSOwner' {
    Context 'When a downstream command stops the pipeline' {
        It 'Should stop without writing errors' {
            $files = 1..3 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "Owner$_" }

            $result = @(Get-NTFSOwner -Path $files -ErrorVariable ownerErrors -ErrorAction SilentlyContinue | Select-Object -First 1)

            $ownerErrors | Should -BeNullOrEmpty
            $result | Should -HaveCount 1
        }
    }

    Context 'When the owner cannot be read' {
        It 'Should write one permission error and keep the owner' -Skip:$canBypassDeny {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Block-TestReadPermission -Sandbox $sandbox -Path $file

            $result = @(Get-NTFSOwner -Path $file -ErrorVariable ownerErrors -ErrorAction SilentlyContinue)

            $result | Should -BeNullOrEmpty
            $ownerErrors | Should -HaveCount 1
            $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $ownerErrors[0].CategoryInfo.Category | Should -Be 'PermissionDenied'
        }
    }
}

Describe 'Current location' {
    BeforeAll {
        # The command runs in a child scope of this function, so the cmdlets see its $PWD = $null through the scope
        # chain, as in the report.
        function Invoke-WithShadowedPwd {
            param ([scriptblock] $Command)

            $PWD = $null
            & $Command
        }
    }

    # Before 5.0.0, a variable named PWD in the scope of the caller, such as a loop variable, made every cmdlet
    # fail with a NullReferenceException, also for an absolute path (#86).
    It 'Should ignore a variable named PWD for an absolute path' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Pwd'

        $result = Invoke-WithShadowedPwd -Command { Get-NTFSOwner -Path $file -ErrorAction Stop }

        $result.FullName | Should -Be $file
    }

    It 'Should resolve a relative path against the current location despite a variable named PWD' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PwdRelative'
        $name = Split-Path -Path $file -Leaf

        $result = Invoke-WithShadowedPwd -Command { Get-NTFSOwner -Path $name -ErrorAction Stop }

        $result.FullName | Should -Be $file
    }

    It '<_> should use the current location without -Path despite a variable named PWD' -ForEach @(
        'Get-NTFSAccess', 'Get-NTFSAudit', 'Get-NTFSEffectiveAccess', 'Get-NTFSInheritance', 'Get-ChildItem2',
        'Get-Item2', 'Get-NTFSSecurityDescriptor'
    ) {
        $cmdlet = $_

        { Invoke-WithShadowedPwd -Command { & $cmdlet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue } } |
            Should -Not -Throw
    }

    # The error for the folder is non-terminating since 5.0.0-rc6, so -ErrorAction Stop turns it into the exception.
    It 'Get-NTFSHardLink should report the folder of the current location, not a NullReferenceException' {
        { Invoke-WithShadowedPwd -Command { Get-NTFSHardLink -ErrorAction Stop } } |
            Should -Throw -ExpectedMessage '*must be a file*'
    }
}

Describe 'File and folder objects as arguments' {
    # Before 5.0.0, Windows PowerShell bound a folder object that was passed by position as its name, which the
    # cmdlets resolved against the current location (#88).
    It 'Should take a folder object by position' {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'Parent' -Directory
        $child = Join-Path -Path $parent -ChildPath 'Child'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $child
        New-Item -ItemType Directory -Path $child | Out-Null
        $folder = Get-ChildItem -LiteralPath $parent -Directory

        $result = Get-NTFSOwner $folder -ErrorAction Stop

        $result.FullName | Should -Be $child
    }

    It 'Should take file objects through the pipeline as before' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Piped'

        $result = Get-Item -LiteralPath $file | Get-NTFSOwner

        $result.FullName | Should -Be $file
    }
}

Describe 'Set-NTFSOwner' {
    BeforeAll {
        $sidType = [System.Security.Principal.SecurityIdentifier]
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        # An owner that the user can assign only with the Restore privilege
        $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
        $privateData = (Get-Module -Name NTFSSecurity).PrivateData
        $enablePrivileges = $privateData['EnablePrivileges']

        function Get-TestOwner {
            param ([string] $Path)

            (Get-Acl -LiteralPath $Path).GetOwner($sidType).Value
        }
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $enablePrivileges
    }

    It 'Should make the account the owner and write nothing without -PassThru' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwner'

        $result = @(Set-NTFSOwner -Path $file -Account $currentUser -ErrorAction Stop)

        $result | Should -BeNullOrEmpty
        Get-TestOwner -Path $file | Should -Be $currentUser
    }

    It 'Should return the new owner of a folder with -PassThru' {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerFolder' -Directory

        $result = @(Set-NTFSOwner -Path $folder -Account $currentUser -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType [Security2.FileSystemOwner]
        $result[0].FullName | Should -Be $folder
        $result[0].Owner.Sid | Should -Be $currentUser
        Get-TestOwner -Path $folder | Should -Be $currentUser
    }

    It 'Should take the items from the pipeline' {
        $files = 1..2 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "SetOwnerPiped$_" }

        $result = @(Get-Item2 -Path $files | Set-NTFSOwner -Account $currentUser -PassThru -ErrorAction Stop)

        ($result.FullName -join '|') | Should -Be ($files -join '|')
    }

    It 'Should set an owner that only the Restore privilege allows' -Skip:(-not $canAssignAnyOwner) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerRestore'

        Set-NTFSOwner -Path $file -Account $trustedInstaller -ErrorAction Stop

        Get-TestOwner -Path $file | Should -Be $trustedInstaller
    }

    It 'Should write a read error for a path that does not exist and continue with the next path' {
        $missing = Join-Path -Path $sandbox -ChildPath 'SetOwnerMissing.txt'
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerAfterMissing'

        Set-NTFSOwner -Path $missing, $file -Account $currentUser -ErrorVariable ownerErrors -ErrorAction SilentlyContinue

        $ownerErrors | Should -HaveCount 1
        $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
        Get-TestOwner -Path $file | Should -Be $currentUser
    }

    Context 'When Windows refuses the owner' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Without the Restore privilege, Windows refuses an owner other than the user or one of its groups: (1307) This
        # security ID may not be assigned as the owner of this object.
        It 'Should write a SetOwnerError and keep the owner' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerRefused'
            $owner = Get-TestOwner -Path $file
            (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState | Should -Not -Be 'Enabled'

            Set-NTFSOwner -Path $file -Account $trustedInstaller -ErrorVariable ownerErrors -ErrorAction SilentlyContinue

            $ownerErrors | Should -HaveCount 1
            $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike 'SetOwnerError,*'
            Get-TestOwner -Path $file | Should -Be $owner
        }
    }

    Context 'With -SecurityDescriptor' {
        It 'Should change only the descriptor in memory until Set-NTFSSecurityDescriptor writes it' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerDescriptor'
            $owner = Get-TestOwner -Path $file
            if ($owner -eq $currentUser) {
                # Only an elevated session creates items that the Administrators group owns.
                Set-ItResult -Skipped -Because 'the user owns new items, and no other owner can be set without privileges'
                return
            }
            $sd = Get-NTFSSecurityDescriptor -Path $file

            $result = @(Set-NTFSOwner -SecurityDescriptor $sd -Account $currentUser -PassThru -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0].Owner.Sid | Should -Be $currentUser
            Get-TestOwner -Path $file | Should -Be $owner
            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
            Get-TestOwner -Path $file | Should -Be $currentUser
        }
    }
}
