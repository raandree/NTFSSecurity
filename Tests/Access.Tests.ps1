<#
    Tests the access cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # With the Restore privilege, Windows may grant writing the DACL despite a deny entry.
    $canBypassWriteDeny = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
    # Assigning an owner other than the user or one of its groups needs the Restore privilege.
    $canAssignAnyOwner = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
    $holdsSecurityPrivilege = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Access'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']
    $sidType = [System.Security.Principal.SecurityIdentifier]
    # An owner that the user can assign only with the Restore privilege
    $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'

    function Get-RestorePrivilegeState {
        (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSAccess' {
    Context 'When a path fails after a readable path' {
        # Before 5.0.0, the cmdlet wrote the entries of the previous item again for the failing path.
        It 'Should return the entries of the first item once' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Readable' -Directory
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Block-TestReadPermission -Sandbox $sandbox -Path $denied
            $expected = @(Get-NTFSAccess -Path $folder).Count

            $entries = @(Get-NTFSAccess -Path $folder, $denied -ErrorAction SilentlyContinue)

            @($entries | Where-Object -Property FullName -EQ -Value $folder) | Should -HaveCount $expected
        }
    }
}

Describe 'Get-NTFSEffectiveAccess' {
    BeforeAll {
        $effectiveFile = New-TestSandboxItem -Sandbox $sandbox -Name 'Effective'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $effectiveFile
        $acl = Get-Acl -LiteralPath $effectiveFile
        $guests = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-5-32-546'
        $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                    $guests, [System.Security.AccessControl.FileSystemRights]::FullControl,
                    [System.Security.AccessControl.AccessControlType]::Deny
                )))
        Set-Acl -LiteralPath $effectiveFile -AclObject $acl
    }

    # Before 5.0.0, the warning misspelled the privilege as "Privliege".
    It 'Should warn once that the Security privilege is missing' -Skip:$holdsSecurityPrivilege {
        Get-NTFSEffectiveAccess -Path $effectiveFile -WarningVariable accessWarnings -WarningAction SilentlyContinue | Out-Null

        $accessWarnings | Should -HaveCount 1
        $accessWarnings[0].Message | Should -BeExactly 'The user does not hold the Security privilege and might not be able to read the effective permissions.'
    }

    It 'Should leave out an account without access when -ExcludeNoneAccessEntries is used' {
        $result = @(Get-NTFSEffectiveAccess -Path $effectiveFile -Account 'S-1-5-32-546' -ExcludeNoneAccessEntries -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -BeNullOrEmpty
    }

    It 'Should return an account with access when -ExcludeNoneAccessEntries is used' {
        $result = @(Get-NTFSEffectiveAccess -Path $effectiveFile -ExcludeNoneAccessEntries -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -HaveCount 1
    }

    It 'Should use the current location when -Path is omitted' {
        $result = @(Get-NTFSEffectiveAccess -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -BeLike ('*\{0}' -f (Split-Path -Path $sandbox -Leaf))
    }

    It 'Should compute the effective access of a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $effectiveFile

        $result = @(Get-NTFSEffectiveAccess -SecurityDescriptor $sd -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $effectiveFile
    }

    Context 'When the effective access cannot be calculated' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc4, the cmdlet blamed a missing Security privilege for every failure while the privilege
        # wasn't enabled (#109). A security descriptor without an owner is such a failure: the DACL of the file has the
        # auto-inherit flag since Set-Acl wrote it, so Windows returns no owner when only the DACL is read.
        It 'Should name the cause in the error, not the Security privilege' {
            (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Security').PrivilegeState | Should -Not -Be 'Enabled'
            $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
                (Get-Item2 -Path $effectiveFile), [System.Security.AccessControl.AccessControlSections]::Access
            )
            $sd.SecurityDescriptor.GetOwner($sidType) | Should -BeNullOrEmpty

            Get-NTFSEffectiveAccess -SecurityDescriptor $sd -ErrorVariable accessErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

            $accessErrors | Should -HaveCount 1
            $accessErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetEffectiveAccessError,*'
            $accessErrors[0].Exception.Message | Should -Not -BeLike '*Enable-Privileges*'
        }
    }

    Context 'When the computer of -ServerName cannot be reached' {
        # Before 5.0.0-rc5, the cmdlet returned no access when the computer couldn't be reached, although it warned that
        # it had calculated the result on this computer. Windows reports a computer that it can't resolve or reach with
        # the error RPC server unavailable; the name ends in .invalid, which no DNS server resolves (RFC 2606).
        It 'Should return the result of this computer and warn' {
            $expected = Get-NTFSEffectiveAccess -Path $effectiveFile -WarningAction SilentlyContinue -ErrorAction Stop
            [long] $expected.AccessRights | Should -BeGreaterThan ([long] [Security2.FileSystemRights2]::Synchronize)

            $result = @(Get-NTFSEffectiveAccess -Path $effectiveFile -ServerName 'ntfssecurity-test.invalid' -WarningVariable accessWarnings -WarningAction SilentlyContinue -ErrorVariable accessErrors -ErrorAction SilentlyContinue)

            $accessErrors | Should -BeNullOrEmpty
            $result | Should -HaveCount 1
            $result[0].AccessRights | Should -Be $expected.AccessRights
            $accessWarnings.Message | Should -Contain ('The effective rights can only be computed based on group membership on this computer. ' +
                'For more accurate results, calculate effective access rights on the target computer')
        }
    }
}

Describe 'Get-NTFSOrphanedAccess' {
    # Before 5.0.0, a path with braces stopped the cmdlet with a FormatException (#3), which the verbose message raised.
    It 'Should read a folder whose name contains braces' {
        $braces = Join-Path -Path $sandbox -ChildPath ('{{Braces}}-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $braces
        [IO.Directory]::CreateDirectory($braces) | Out-Null

        $messages = @(Get-NTFSOrphanedAccess -Path $braces -Verbose -ErrorAction Stop 4>&1)

        $messages.Message | Should -Contain "Item $braces knows about 0 orphaned SIDs in its ACL"
    }

    BeforeAll {
        $orphanedFile = New-TestSandboxItem -Sandbox $sandbox -Name 'Orphaned'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $orphanedFile
        $acl = Get-Acl -LiteralPath $orphanedFile
        foreach ($sid in 'S-1-5-21-1-2-3-1001', 'S-1-5-21-1-2-3-1002') {
            $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                        (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $sid),
                        [System.Security.AccessControl.FileSystemRights]::ReadData, [System.Security.AccessControl.AccessControlType]::Allow
                    )))
        }
        Set-Acl -LiteralPath $orphanedFile -AclObject $acl
    }

    It 'Should return the entries whose account cannot be resolved' {
        @(Get-NTFSOrphanedAccess -Path $orphanedFile) | Should -HaveCount 2
    }

    It 'Should return only the entries of -Account' {
        $result = @(Get-NTFSOrphanedAccess -Path $orphanedFile -Account 'S-1-5-21-1-2-3-1002')

        $result | Should -HaveCount 1
        $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-1002'
    }

    It 'Should read the entries of a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $orphanedFile

        $result = @(Get-NTFSOrphanedAccess -SecurityDescriptor $sd)

        $result | Should -HaveCount 2
        $result | ForEach-Object -Process { $_.FullName | Should -Be $orphanedFile }
    }
}

Describe 'Get-NTFSSimpleAccess' {
    BeforeAll {
        $simpleFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'Simple' -Directory
        Assert-TestSandboxPath -Sandbox $sandbox -Path $simpleFolder
        $acl = Get-Acl -LiteralPath $simpleFolder
        $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                    (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-1-0'),
                    [System.Security.AccessControl.FileSystemRights]::ReadData, [System.Security.AccessControl.AccessControlType]::Allow
                )))
        Set-Acl -LiteralPath $simpleFolder -AclObject $acl
    }

    It 'Should return only the entries of -Account' {
        $result = @(Get-NTFSSimpleAccess -Path $simpleFolder -Account 'S-1-1-0' -IncludeRootFolder:$false)

        $result | Should -Not -BeNullOrEmpty
        $result | ForEach-Object -Process { $_.Identity.Sid | Should -Be 'S-1-1-0' }
    }

    It 'Should read the entries of a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $simpleFolder

        $result = @(Get-NTFSSimpleAccess -SecurityDescriptor $sd)

        $result | Should -Not -BeNullOrEmpty
        $result | ForEach-Object -Process { $_.FullName | Should -Be $simpleFolder }
    }

    It 'Should show the entries as a table with the account, the rights, and the type' {
        $text = Get-NTFSSimpleAccess -Path $simpleFolder -IncludeRootFolder:$false | Out-String -Width 200

        $text | Should -Match 'Account\s+Access Rights\s+Type'
    }

    Context 'When it reduces the rights of an entry' {
        BeforeAll {
            # One explicit entry per case, for a SID of its own and with exactly these rights. .NET would add
            # Synchronize to an allow entry, so the DACL is set in SDDL.
            $rightsFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'SimpleRights' -Directory
            $rightsCases = @(
                @{ Name = 'ReadData'; Mask = 0x1; Expected = 'Read' }
                @{ Name = 'ReadAttributes'; Mask = 0x80; Expected = 'Read' }
                @{ Name = 'Traverse'; Mask = 0x20; Expected = 'Read' }
                @{ Name = 'ReadPermissions'; Mask = 0x20000; Expected = 'Read' }
                @{ Name = 'CreateFiles'; Mask = 0x2; Expected = 'Write' }
                @{ Name = 'AppendData'; Mask = 0x4; Expected = 'Write' }
                @{ Name = 'WriteAttributes'; Mask = 0x100; Expected = 'Write' }
                @{ Name = 'ChangePermissions'; Mask = 0x40000; Expected = 'Write' }
                @{ Name = 'TakeOwnership'; Mask = 0x80000; Expected = 'Write' }
                @{ Name = 'Delete'; Mask = 0x10000; Expected = 'Delete' }
                @{ Name = 'DeleteSubdirectoriesAndFiles'; Mask = 0x40; Expected = 'Delete' }
                @{ Name = 'Modify'; Mask = 0x1301BF; Expected = 'Read, Write, Delete' }
                @{ Name = 'FullControl'; Mask = 0x1F01FF; Expected = 'Read, Write, Delete' }
            )
            $rightsSid = @{}
            $entries = for ($i = 0; $i -lt $rightsCases.Count; $i++) {
                $sid = 'S-1-5-21-1-2-3-{0}' -f (3001 + $i)
                $rightsSid[$rightsCases[$i].Name] = $sid
                '(A;;0x{0:X};;;{1})' -f $rightsCases[$i].Mask, $sid
            }
            $acl = Get-Acl -LiteralPath $rightsFolder
            $acl.SetSecurityDescriptorSddlForm(('D:{0}' -f ($entries -join '')), 'Access')
            Set-Acl -LiteralPath $rightsFolder -AclObject $acl

            $rightsResult = @(Get-NTFSSimpleAccess -Path $rightsFolder -ExcludeInherited -IncludeRootFolder:$false -ErrorAction Stop)
        }

        # Before 5.0.0-rc6, an entry with ReadData alone, which .NET never creates but other tools do, became None.
        It 'Should reduce <Name> to <Expected>' -ForEach @(
            @{ Name = 'ReadData'; Expected = 'Read' }
            @{ Name = 'ReadAttributes'; Expected = 'Read' }
            @{ Name = 'Traverse'; Expected = 'Read' }
            @{ Name = 'ReadPermissions'; Expected = 'Read' }
            @{ Name = 'CreateFiles'; Expected = 'Write' }
            @{ Name = 'AppendData'; Expected = 'Write' }
            @{ Name = 'WriteAttributes'; Expected = 'Write' }
            @{ Name = 'ChangePermissions'; Expected = 'Write' }
            @{ Name = 'TakeOwnership'; Expected = 'Write' }
            @{ Name = 'Delete'; Expected = 'Delete' }
            @{ Name = 'DeleteSubdirectoriesAndFiles'; Expected = 'Delete' }
            @{ Name = 'Modify'; Expected = 'Read, Write, Delete' }
            @{ Name = 'FullControl'; Expected = 'Read, Write, Delete' }
        ) {
            $entry = @($rightsResult | Where-Object -FilterScript { $_.Identity.Sid -eq $rightsSid[$Name] })

            $entry | Should -HaveCount 1
            $entry[0].AccessRights.ToString() | Should -Be $Expected
        }
    }

    Context 'When it compares folders with their parent folder' {
        BeforeAll {
            # The parent grants Everyone ReadData to its subfolders and the user Full Control, so that a basic user
            # can create the items; the child adds an entry of its own. The child is created after the DACL of the
            # parent, so that it inherits only these entries.
            $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'SimpleParent' -Directory
            $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $acl = Get-Acl -LiteralPath $parent
            $acl.SetSecurityDescriptorSddlForm("D:P(A;OICI;0x120089;;;WD)(A;OICI;FA;;;BA)(A;OICI;FA;;;SY)(A;OICI;FA;;;$user)", 'Access')
            Set-Acl -LiteralPath $parent -AclObject $acl
            $child = Join-Path -Path $parent -ChildPath 'Child'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            New-Item -ItemType Directory -Path $child | Out-Null
            $acl = Get-Acl -LiteralPath $child
            $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                        (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-5-21-1-2-3-3101'),
                        [System.Security.AccessControl.FileSystemRights]::Modify, [System.Security.AccessControl.AccessControlType]::Allow
                    )))
            Set-Acl -LiteralPath $child -AclObject $acl
            $childFile = Join-Path -Path $child -ChildPath 'File.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $childFile
            Set-Content -LiteralPath $childFile -Value 'File' -ErrorAction Stop
        }

        It 'Should report all entries of the first folder and of the following folder only what the parent does not cover' {
            $result = @(Get-NTFSSimpleAccess -Path $parent, $child -IncludeRootFolder:$false -ErrorAction Stop)

            @($result | Where-Object -Property FullName -EQ -Value $parent) | Should -HaveCount 4
            $childEntries = @($result | Where-Object -Property FullName -EQ -Value $child)
            $childEntries | Should -HaveCount 1
            $childEntries[0].Identity.Sid | Should -Be 'S-1-5-21-1-2-3-3101'
        }

        It 'Should compare the folders from the pipeline in the same way' {
            $result = @(Get-Item2 -Path $parent, $child | Get-NTFSSimpleAccess -IncludeRootFolder:$false -ErrorAction Stop)

            @($result | Where-Object -Property FullName -EQ -Value $child).Identity.Sid | Should -Be 'S-1-5-21-1-2-3-3101'
        }

        It 'Should report the parent folder of the first path first by default' {
            $result = @(Get-NTFSSimpleAccess -Path $child -ErrorAction Stop)

            $result[0].FullName | Should -Be $parent
            @($result | Where-Object -Property FullName -EQ -Value $child).Identity.Sid | Should -Be 'S-1-5-21-1-2-3-3101'
        }

        # Before 5.0.0-rc6, a relative path with a single folder name had no parent folder in the result.
        It 'Should report the parent folder of a relative path first by default' {
            Push-Location -LiteralPath $parent
            try {
                $result = @(Get-NTFSSimpleAccess -Path 'Child' -ErrorAction Stop)
            }
            finally {
                Pop-Location
            }

            $result[0].FullName | Should -Be $parent
            @($result | Where-Object -Property FullName -EQ -Value $child).Identity.Sid | Should -Be 'S-1-5-21-1-2-3-3101'
        }

        It 'Should use the current location without -Path' {
            Push-Location -LiteralPath $child
            try {
                $result = @(Get-NTFSSimpleAccess -IncludeRootFolder:$false -ErrorAction Stop)
            }
            finally {
                Pop-Location
            }

            $result | ForEach-Object -Process { $_.FullName | Should -Be $child }
        }

        It 'Should return only the inherited entries with -ExcludeExplicit' {
            $result = @(Get-NTFSSimpleAccess -Path $child -ExcludeExplicit -IncludeRootFolder:$false -ErrorAction Stop)

            $result | Should -HaveCount 4
            $result.Identity.Sid | Should -Not -Contain 'S-1-5-21-1-2-3-3101'
        }

        It 'Should skip a file without an error' {
            $result = @(Get-NTFSSimpleAccess -Path $childFile -IncludeRootFolder:$false -ErrorVariable simpleErrors -ErrorAction SilentlyContinue)

            $simpleErrors | Should -BeNullOrEmpty
            $result | Should -BeNullOrEmpty
        }

        It 'Should report the security descriptor of a file' {
            $result = @(Get-NTFSSecurityDescriptor -Path $childFile | Get-NTFSSimpleAccess -ErrorAction Stop)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_.FullName | Should -Be $childFile }
        }

        It 'Should write an error for a path that does not exist and continue with the next path' {
            $missing = Join-Path -Path $parent -ChildPath 'Missing'

            $result = @(Get-NTFSSimpleAccess -Path $missing, $child -IncludeRootFolder:$false -ErrorVariable simpleErrors -ErrorAction SilentlyContinue)

            $simpleErrors | Should -HaveCount 1
            $simpleErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadError,*'
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_.FullName | Should -Be $child }
        }
    }
}

Describe 'Remove-NTFSAccess' {
    Context 'When a path does not exist' {
        BeforeAll {
            $missing = Join-Path -Path $sandbox -ChildPath 'Missing.txt'
        }

        # Before 5.0.0, the cmdlet went on with the missing item and wrote a second, misleading RemoveAceError.
        It 'Should write only the read error' {
            Remove-NTFSAccess -Path $missing -Account 'Everyone' -AccessRights ReadData -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
        }

        It 'Should not stop with -PassThru' {
            { Remove-NTFSAccess -Path $missing -Account 'Everyone' -AccessRights ReadData -PassThru -ErrorAction SilentlyContinue } |
                Should -Not -Throw
        }
    }

    Context 'When the entries cannot be changed' {
        # Before 5.0.0, -PassThru returned the unchanged entries of the item after the error.
        It 'Should write an error and return nothing with -PassThru' -Skip:$canBypassWriteDeny {
            $protected = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveProtected'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $protected
            Add-NTFSAccess -Path $protected -Account 'Everyone' -AccessRights ReadData
            Block-TestWritePermission -Sandbox $sandbox -Path $protected

            $result = @(Remove-NTFSAccess -Path $protected -Account 'Everyone' -AccessRights ReadData -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'RemoveAceError,*'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When the item has an owner that the user cannot assign' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc3, the cmdlet read only the DACL, but wrote the owner that Windows returns with a DACL without
        # the auto-inherit flag, which Windows refuses without the Restore privilege (#34). Any write of the DACL adds
        # the flag, so the item keeps its DACL as created and has no explicit entry to remove.
        It 'Should write no error and keep the owner' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveOtherOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'

            Remove-NTFSAccess -Path $file -Account 'Everyone' -AccessRights ReadData -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
        }
    }

    Context 'With a generic right' {
        # Before 5.0.0, removing an entry with a generic right such as GENERIC_ALL failed with "The value '269484032' is
        # not valid", because .NET rebuilds the rule and rejects generic rights (#17). Windows keeps generic rights in
        # inherit-only entries of folders.
        BeforeAll {
            $guests = [System.Security.Principal.SecurityIdentifier]'S-1-5-32-546'

            function New-GenericRightFolder {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to the sandbox.'
                )]
                param ([string] $Entry)

                $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Generic' -Directory
                Assert-TestSandboxPath -Sandbox $sandbox -Path $folder
                $acl = Get-Acl -LiteralPath $folder
                $acl.SetSecurityDescriptorSddlForm(($acl.Sddl -replace 'D:(?<flags>[A-Z]*)', ('D:${flags}' + $Entry)))
                Set-Acl -LiteralPath $folder -AclObject $acl
                $folder
            }

            function Get-GuestsRule {
                param ([string] $Path)

                (Get-Acl -LiteralPath $Path).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -Property IdentityReference -EQ -Value $guests
            }
        }

        It 'Should remove an inherit-only entry that Get-NTFSAccess returned, and nothing else' -ForEach @(
            @{ Case = 'Allow'; Entry = '(A;OICIIO;GA;;;BG)'; Specific = $false }
            @{ Case = 'Allow with -RemoveSpecific'; Entry = '(A;OICIIO;GA;;;BG)'; Specific = $true }
            @{ Case = 'Deny'; Entry = '(D;OICIIO;GA;;;BG)'; Specific = $false }
        ) {
            $folder = New-GenericRightFolder -Entry $Entry
            $before = (Get-Acl -LiteralPath $folder).Sddl
            $before | Should -Match ([regex]::Escape($Entry))

            Get-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -ExcludeInherited |
                Remove-NTFSAccess -RemoveSpecific:$Specific -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $folder).Sddl | Should -BeExactly $before.Replace($Entry, '')
        }

        It 'Should remove only the requested generic right from an entry with two' {
            $folder = New-GenericRightFolder -Entry '(A;OICIIO;0x90000000;;;BG)'

            Remove-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights GenericRead -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags InheritOnly -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -BeNullOrEmpty
            $rule = Get-GuestsRule -Path $folder
            $rule | Should -HaveCount 1
            [int] $rule.FileSystemRights | Should -Be 0x10000000
        }

        # A rule that matches the entry exactly is removed as it is, with the Synchronize right that the module adds
        # to an Allow rule; otherwise an entry with only Synchronize would be left behind.
        It 'Should remove an entry with GenericAll and Synchronize when -AccessRights names GenericAll' {
            $folder = New-GenericRightFolder -Entry '(A;OICIIO;0x10100000;;;BG)'

            Remove-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights GenericAll -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags InheritOnly -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -BeNullOrEmpty
            Get-GuestsRule -Path $folder | Should -BeNullOrEmpty
        }
    }
    Context 'With -RemoveSpecific' {
        BeforeEach {
            $removeFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSpecific' -Directory
            $sd = Get-NTFSSecurityDescriptor -Path $removeFolder
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights Modify

            function Get-EveryoneRule {
                $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
            }
        }

        It 'Should keep an entry that does not match exactly' {
            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -RemoveSpecific

            (Get-EveryoneRule).FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Modify) | Should -BeTrue
        }

        It 'Should remove an entry that matches exactly' {
            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights Modify -RemoveSpecific

            Get-EveryoneRule | Should -BeNullOrEmpty
        }

        It 'Should take the rights away from a matching entry without -RemoveSpecific' {
            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            $rule = Get-EveryoneRule
            $rule | Should -Not -BeNullOrEmpty
            $rule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeFalse
        }

        It 'Should keep an entry that does not match exactly, given the path' {
            Add-NTFSAccess -Path $removeFolder -Account 'Everyone' -AccessRights Modify

            Remove-NTFSAccess -Path $removeFolder -Account 'Everyone' -AccessRights ReadData -RemoveSpecific -ErrorAction Stop

            $rules = @((Get-Acl -LiteralPath $removeFolder).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
            $rules | Should -HaveCount 1
            $rules[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Modify) | Should -BeTrue
        }

        It 'Should remove an entry that matches exactly, given the path' {
            Add-NTFSAccess -Path $removeFolder -Account 'Everyone' -AccessRights Modify

            Remove-NTFSAccess -Path $removeFolder -Account 'Everyone' -AccessRights Modify -RemoveSpecific -ErrorAction Stop

            (Get-Acl -LiteralPath $removeFolder).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' } | Should -BeNullOrEmpty
        }
    }
}

Describe 'Add-NTFSAccess' {
    Context 'When the entries cannot be changed' {
        # Before 5.0.0, -PassThru returned the unchanged entries of the item after the error.
        It 'Should write an error and return nothing with -PassThru' -Skip:$canBypassWriteDeny {
            $protected = New-TestSandboxItem -Sandbox $sandbox -Name 'AddProtected'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $protected
            Block-TestWritePermission -Sandbox $sandbox -Path $protected

            $result = @(Add-NTFSAccess -Path $protected -Account 'Everyone' -AccessRights ReadData -PassThru -ErrorVariable addErrors -ErrorAction SilentlyContinue)

            $addErrors | Should -HaveCount 1
            $addErrors[0].FullyQualifiedErrorId | Should -BeLike 'AddAceError,*'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When the item has an owner that the user cannot assign' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc3, the cmdlet wrote the unchanged owner back. Without the Restore privilege, Windows refuses
        # an owner that the user cannot assign, like a file server that refuses the owner (#34): (1307) This security
        # ID may not be assigned as the owner of this object.
        It 'Should add the entry and keep the owner' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OtherOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'

            Add-NTFSAccess -Path $file -Account 'Everyone' -AccessRights ReadData -ErrorVariable addErrors -ErrorAction SilentlyContinue

            $addErrors | Should -BeNullOrEmpty
            $acl = Get-Acl -LiteralPath $file
            $acl.GetOwner($sidType).Value | Should -Be $trustedInstaller
            @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) |
                Should -HaveCount 1
        }
    }

    Context 'With inherited entries' {
        # Before 5.0.0-rc3, the cmdlet read the DACL together with the SACL when the process held the Security
        # privilege. When the folder has no SACL, Windows then returns the inherited entries of a DACL without the
        # auto-inherit flag, such as that of a file in the temp folder of the user, without their inherited flag, and
        # the cmdlet wrote them back as explicit copies.
        It 'Should add one explicit entry and keep the inherited entries inherited' -Skip:(-not $holdsSecurityPrivilege) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Inherited'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $inheritedCount = @((Get-Acl -LiteralPath $file).GetAccessRules($false, $true, $sidType)).Count
            $inheritedCount | Should -BeGreaterThan 0

            Add-NTFSAccess -Path $file -Account 'Everyone' -AccessRights ReadData

            $acl = Get-Acl -LiteralPath $file
            @($acl.GetAccessRules($true, $false, $sidType)) | Should -HaveCount 1
            @($acl.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $inheritedCount
        }
    }

    # The page: -PassThru writes all entries, explicit and inherited, of every item that the cmdlet changed.
    Context 'With -PassThru' {
        It 'Should write all entries of the item after the change' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPassThru'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file

            $result = @(Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData -PassThru)

            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAccessRule2] }
            $result | Should -HaveCount @(Get-NTFSAccess -Path $file).Count
            @($result | Where-Object -FilterScript { $_.IsInherited }) | Should -Not -BeNullOrEmpty
            $added = @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' -and -not $_.IsInherited })
            $added | Should -HaveCount 1
            $added[0].AccessRights.HasFlag([Security2.FileSystemRights2]::ReadData) | Should -BeTrue
        }

        It 'Should write all entries of a security descriptor after the change and leave the item unchanged' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPassThruDescriptor'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file

            $result = @(Add-NTFSAccess -SecurityDescriptor $sd -Account 'S-1-1-0' -AccessRights ReadData -PassThru)

            $result | Should -HaveCount @($sd.SecurityDescriptor.GetAccessRules($true, $true, $sidType)).Count
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' -and -not $_.IsInherited }) | Should -HaveCount 1
            @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -BeNullOrEmpty
        }
    }

    Context 'With -InheritanceFlags and -PropagationFlags' {
        It 'Should add an entry with the flags to a folder' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddFlags' -Directory
            Assert-TestSandboxPath -Sandbox $sandbox -Path $folder

            Add-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights ReadData -InheritanceFlags ContainerInherit -PropagationFlags InheritOnly

            $rules = @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-32-546' })
            $rules | Should -HaveCount 1
            $rules[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit)
            $rules[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::InheritOnly)
        }

        # The page: inheritance and propagation flags are ignored on files.
        It 'Should add an entry without flags to a file' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddFlagsFile'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file

            Add-NTFSAccess -Path $file -Account 'S-1-5-32-546' -AccessRights ReadData -InheritanceFlags 'ContainerInherit, ObjectInherit' -PropagationFlags InheritOnly

            $rules = @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-32-546' })
            $rules | Should -HaveCount 1
            $rules[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::None)
            $rules[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
        }
    }
}

Describe 'Security descriptor parameter sets' {
    BeforeAll {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ParameterSets' -Directory
    }

    # Before 5.0.0, PowerShell could not choose between the SDSimple and SDComplex parameter sets.
    It '<_> should accept -SecurityDescriptor without -AppliesTo or the flag parameters' -ForEach @(
        'Add-NTFSAccess', 'Remove-NTFSAccess'
    ) {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        { & $_ -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -ErrorAction Stop } | Should -Not -Throw
    }

    # A descriptor from Get-NTFSSecurityDescriptor contains the audit entries only with the Security privilege.
    It '<_> should accept -SecurityDescriptor without -AppliesTo or the flag parameters' -Skip:(-not $holdsSecurityPrivilege) -ForEach @(
        'Add-NTFSAudit', 'Remove-NTFSAudit'
    ) {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        { & $_ -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Add-NTFSAccess should apply the entry to the folder, its subfolders, and files by default' {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

        $rule = $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
        $rule.InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags] 'ContainerInherit, ObjectInherit')
        $rule.PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
    }

    It 'Add-NTFSAccess should still take -AppliesTo for a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -AppliesTo ThisFolderOnly

        $rule = $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
        $rule.InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::None)
    }
}

Describe 'Clear-NTFSAccess' {
    Context 'With -DisableInheritance' {
        # The cmdlet does not copy the inherited entries, so the item is left with an empty DACL. This is the
        # documented behavior; Set-NTFSInheritance and Disable-NTFSAccessInheritance keep the entries.
        It 'Should leave the item with an empty, protected DACL' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearAll'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file

            Clear-NTFSAccess -Path $file -DisableInheritance

            $acl = Get-Acl -LiteralPath $file
            $acl.AreAccessRulesProtected | Should -BeTrue
            $acl.Access | Should -BeNullOrEmpty
        }
    }

    Context 'When the item has an owner that the user cannot assign' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc3, the cmdlet wrote the unchanged owner back, which Windows refuses without the Restore
        # privilege (#34). For a DACL without the auto-inherit flag, such as that of a new file in the temp folder of
        # the user, Windows returns the owner even when only the DACL is read. Any write of the DACL adds the flag, so
        # the item keeps its DACL as created.
        It 'Should write no error and keep the owner' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearOtherOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'

            Clear-NTFSAccess -Path $file -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -BeNullOrEmpty
            $acl = Get-Acl -LiteralPath $file
            $acl.GetOwner($sidType).Value | Should -Be $trustedInstaller
            @($acl.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
        }
    }
}

# Before 5.0.0-rc6, comparing an entry with anything threw an InvalidCastException, so -eq, -contains, and in PowerShell 7
# also Select-Object -Unique and Compare-Object failed for the output of Get-NTFSAccess. Like the entries of .NET, two
# objects are equal when they wrap the same entry.
Describe 'Comparing access entries' {
    BeforeAll {
        $compareFile = New-TestSandboxItem -Sandbox $sandbox -Name 'Compare'
        Add-NTFSAccess -Path $compareFile -Account 'S-1-1-0' -AccessRights ReadData
        $entries = @(Get-NTFSAccess -Path $compareFile)
    }

    It 'Should find an entry equal to itself and not to another entry' {
        $entries.Count | Should -BeGreaterThan 1

        $entries[0] -eq $entries[0] | Should -BeTrue
        $entries[0] -eq $entries[1] | Should -BeFalse
        $entries -contains $entries[1] | Should -BeTrue
        $entries[0].Equals('S-1-1-0') | Should -BeFalse
        $entries[0].Equals($null) | Should -BeFalse
    }

    It 'Should work with Select-Object -Unique and Compare-Object' {
        @(@($entries) + $entries[0] | Select-Object -Unique) | Should -HaveCount $entries.Count
        Compare-Object -ReferenceObject $entries -DifferenceObject $entries | Should -BeNullOrEmpty
    }

    # The entry of .NET doesn't know the object of the module, so equality in one direction only would make a hashtable
    # lookup depend on which of the two is the key.
    It 'Should be equal only to an entry of the module, in both directions' {
        $raw = [System.Security.AccessControl.FileSystemAccessRule] $entries[0]

        $entries[0].Equals($raw) | Should -BeFalse
        $raw.Equals($entries[0]) | Should -BeFalse
    }
}

# Before 5.0.0-rc6, -ExcludeExplicit gave each inherited entry the source of another entry, and Get-NTFSAccess stopped
# with an ArgumentOutOfRangeException for a security descriptor with audit entries, because it took the sources of the
# audit entries for the access entries.
Describe 'InheritedFrom of access entries' {
    BeforeAll {
        $inheritedFromFile = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritedFrom'
        Add-NTFSAccess -Path $inheritedFromFile -Account 'S-1-1-0' -AccessRights ReadData
        $expectedSource = @{}
        foreach ($entry in Get-NTFSAccess -Path $inheritedFromFile) {
            if ($entry.IsInherited) {
                $expectedSource["$($entry.Account.Sid)"] = $entry.InheritedFrom
            }
        }
    }

    It 'Should name the folder that each inherited entry comes from' {
        $expectedSource.Count | Should -BeGreaterThan 0
        $expectedSource.Values | ForEach-Object -Process { $_ | Should -Not -BeNullOrEmpty }
    }

    It 'Should name the same folders with -ExcludeExplicit' {
        $result = @(Get-NTFSAccess -Path $inheritedFromFile -ExcludeExplicit)

        $result | Should -HaveCount $expectedSource.Count
        foreach ($entry in $result) {
            $entry.InheritedFrom | Should -Be $expectedSource["$($entry.Account.Sid)"]
        }
    }

    # Two explicit entries before the inherited ones; before 5.0.0-rc6, -ExcludeExplicit shifted the sources by two.
    It 'Should name the folder of an inheritable entry, also with -ExcludeExplicit' {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritedFromParent' -Directory
        Add-NTFSAccess -Path $parent -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo ThisFolderSubfoldersAndFiles
        $child = Join-Path -Path $parent -ChildPath 'Child.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $child
        Set-Content -LiteralPath $child -Value 'Child'
        Add-NTFSAccess -Path $child -Account 'S-1-1-0' -AccessRights ReadData
        Add-NTFSAccess -Path $child -Account 'S-1-5-32-545' -AccessRights ReadData

        $all = @(Get-NTFSAccess -Path $child | Where-Object -FilterScript { $_.IsInherited -and "$($_.Account.Sid)" -eq 'S-1-5-32-546' })
        $inherited = @(Get-NTFSAccess -Path $child -ExcludeExplicit | Where-Object -FilterScript { "$($_.Account.Sid)" -eq 'S-1-5-32-546' })

        $all | Should -HaveCount 1
        $all[0].InheritedFrom | Should -Be $parent
        $inherited | Should -HaveCount 1
        $inherited[0].InheritedFrom | Should -Be $parent
    }

    It 'Should read a security descriptor with audit entries and name the same folders' -Skip:(-not $holdsSecurityPrivilege) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritedFromAudit'
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
        Add-NTFSAudit -Path $file -Account 'S-1-1-0' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
        $sd = Get-NTFSSecurityDescriptor -Path $file
        @($sd.SecurityDescriptor.GetAuditRules($true, $true, $sidType)) | Should -Not -BeNullOrEmpty

        $result = @(Get-NTFSAccess -SecurityDescriptor $sd -ErrorAction Stop)

        $result | Should -HaveCount @(Get-NTFSAccess -Path $file).Count
        foreach ($entry in @($result | Where-Object -FilterScript { $_.IsInherited })) {
            $entry.InheritedFrom | Should -Be $expectedSource["$($entry.Account.Sid)"]
        }
    }
}
