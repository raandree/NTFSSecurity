<#
    Tests Get-NTFSSecurityDescriptor and Set-NTFSSecurityDescriptor of the module built in NTFSSecurity\bin\Release on
    files in a sandbox folder. Tests that need the Security or the Restore privilege skip without it; CI runs them
    elevated.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $holdsSecurityPrivilege = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    # Assigning an owner other than the user or one of its groups needs the Restore privilege.
    $canAssignAnyOwner = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'SecurityDescriptor'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']
    $sidType = [System.Security.Principal.SecurityIdentifier]
    # An owner that the user can assign only with the Restore privilege
    $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'

    function Get-RestorePrivilegeState {
        (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState
    }

    function Get-EveryoneRule ([string] $Path) {
        (Get-Acl -LiteralPath $Path).GetAccessRules($true, $false, $sidType) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSSecurityDescriptor' {
    # Before 5.0.0-rc3, the cmdlet read the DACL together with the SACL when the process held the Security privilege.
    # When the folder has no SACL, Windows then returns the inherited entries of a DACL without the auto-inherit flag,
    # such as that of a file in the temp folder of the user, without their inherited flag.
    It 'Should report the inherited access entries as inherited' -Skip:(-not $holdsSecurityPrivilege) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Inherited'
        $inheritedCount = @((Get-Acl -LiteralPath $file).GetAccessRules($false, $true, $sidType)).Count
        $inheritedCount | Should -BeGreaterThan 0

        $sd = Get-NTFSSecurityDescriptor -Path $file

        @($sd.SecurityDescriptor.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
        @($sd.SecurityDescriptor.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $inheritedCount
    }

    It 'Should read the owner and the audit entries with the access entries' -Skip:(-not $holdsSecurityPrivilege) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Sections'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None

        $sd = Get-NTFSSecurityDescriptor -Path $file

        $sd.SecurityDescriptor.GetOwner($sidType).Value | Should -Be (Get-Acl -LiteralPath $file).GetOwner($sidType).Value
        @($sd.SecurityDescriptor.GetAuditRules($true, $false, $sidType)) | Should -HaveCount 1
    }
}

Describe 'Set-NTFSSecurityDescriptor' {
    Context 'When a cmdlet added an access entry to the descriptor' {
        It 'Should write the entry as the only explicit entry of the item' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddedEntry'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd

            @(Get-EveryoneRule -Path $file) | Should -HaveCount 1
            @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType)) | Should -HaveCount 1
        }
    }

    Context 'When the item has an owner that the user cannot assign' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc3, the cmdlet wrote every section that Get-NTFSSecurityDescriptor read, also the unchanged
        # owner, which Windows refuses without the Restore privilege, like a file server that refuses the owner (#34).
        It 'Should write an added access entry and keep the owner' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OtherOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorVariable setErrors -ErrorAction SilentlyContinue

            $setErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
            @(Get-EveryoneRule -Path $file) | Should -HaveCount 1
        }

        It 'Should write an added audit entry and keep the owner' -Skip:(-not ($holdsSecurityPrivilege -and $canAssignAnyOwner)) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OtherOwnerAudit'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorVariable setErrors -ErrorAction SilentlyContinue

            $setErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
            @(Get-NTFSAudit -Path $file -ExcludeInherited) | Should -HaveCount 1
        }
    }

    Context 'When the descriptor has sections that it did not change' {
        # Before 5.0.0-rc3, the cmdlet wrote every section that Get-NTFSSecurityDescriptor read, so it also undid the
        # changes that were made to the item after it was read.
        It 'Should not write back the access entries of an unchanged descriptor' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Unchanged'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            $acl = Get-Acl -LiteralPath $file
            $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                        (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-1-0'),
                        [System.Security.AccessControl.FileSystemRights]::ReadData, [System.Security.AccessControl.AccessControlType]::Allow
                    )))
            Set-Acl -LiteralPath $file -AclObject $acl

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd

            @(Get-EveryoneRule -Path $file) | Should -HaveCount 1
        }

        It 'Should write the owner when only the owner changed' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NewOwner'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            $sd.SecurityDescriptor.SetOwner((New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $trustedInstaller))

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd

            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
        }
    }

    Context 'With -Verbose' {
        It 'Should name the sections that it writes' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'VerboseChanged'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            $messages = Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -Verbose 4>&1

            $messages.Message | Should -Contain "Writing the changed sections of the security descriptor of '$($sd.FullName)': Access"
        }

        It 'Should say that it writes nothing for an unchanged descriptor' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'VerboseUnchanged'
            $sd = Get-NTFSSecurityDescriptor -Path $file

            $messages = Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -Verbose 4>&1

            $messages.Message |
                Should -Contain "No section of the security descriptor of '$($sd.FullName)' changed since it was read or last written; nothing is written"
        }
    }

    Context 'When the write is denied until the cmdlet takes ownership' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc4, the cmdlet set the previous owner back after the write, which undid an owner that the
        # descriptor set, and failed for a previous owner that the user can't assign. The deny entry for the user stops
        # the first write; as the owner, the user may change the permissions.
        It 'Should keep the owner that the descriptor sets when the write succeeds' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RetryOwner'
            Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ $currentUser = 'ChangePermissions' }
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData
            $sd.SecurityDescriptor.SetOwner((New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-5-32-544'))

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorVariable setErrors -ErrorAction SilentlyContinue

            $setErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be 'S-1-5-32-544'
        }

        # Before 5.0.0-rc6, the cmdlet wrote no object with -PassThru when it had to take ownership for the write.
        It 'Should return the written descriptor with -PassThru also when it took ownership for the write' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RetryPassThru'
            Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ $currentUser = 'ChangePermissions' }
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData
            $sd.SecurityDescriptor.SetOwner((New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-5-32-544'))

            $result = @(Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -PassThru -ErrorVariable setErrors -ErrorAction SilentlyContinue)

            $setErrors | Should -BeNullOrEmpty
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $file
            $result[0].SecurityDescriptor.GetOwner($sidType).Value | Should -Be 'S-1-5-32-544'
        }

        # With a cleared, protected DACL, nobody keeps the right to set an owner, so setting the previous owner back would
        # fail. The user owned the item already, so there is no owner to set back.
        It 'Should not report an owner that did not change when the write that took ownership leaves an empty DACL' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RetryUnchangedOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $currentUser
            Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Clear-NTFSAccess -SecurityDescriptor $sd -DisableInheritance -ErrorAction Stop

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorVariable setErrors -ErrorAction SilentlyContinue

            $setErrors | Should -BeNullOrEmpty
            $acl = Get-Acl -LiteralPath $file
            $acl.GetOwner($sidType).Value | Should -Be $currentUser
            $acl.AreAccessRulesProtected | Should -BeTrue
            @($acl.GetAccessRules($true, $true, $sidType)) | Should -BeNullOrEmpty
        }

        # Without the Restore privilege, the user can't set an owner such as TrustedInstaller back. The cmdlet reports it
        # after it wrote the descriptor.
        It 'Should report RestoreOwnerError for a previous owner that it cannot set back after the write' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RetryRestoreDenied'
            Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ $currentUser = 'ChangePermissions' }
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorVariable setErrors -ErrorAction SilentlyContinue

            $setErrors | Should -HaveCount 1
            $setErrors[0].FullyQualifiedErrorId | Should -BeLike 'RestoreOwnerError,*'
            $setErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $setErrors[0].TargetObject.FullName | Should -Be $file
            @(Get-EveryoneRule -Path $file) | Should -HaveCount 1
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $currentUser
        }
    }

    Context 'A descriptor that cannot be written' {
        BeforeEach {
            $savedPrivileges = $privateData['EnablePrivileges']
            $privateData['EnablePrivileges'] = $false
        }

        AfterEach {
            $privateData['EnablePrivileges'] = $savedPrivileges
        }

        It 'Should report a denied write, return no failed item, and write the next descriptor' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorWriteDenied'
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorWriteNext'
            Block-TestWritePermission -Sandbox $sandbox -Path $blocked
            $before = (Get-Acl -LiteralPath $blocked).Sddl
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $blocked, $next)
            $descriptors | Should -HaveCount 2
            Add-NTFSAccess -SecurityDescriptor $descriptors -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop

            $result = @($descriptors | Set-NTFSSecurityDescriptor -PassThru -ErrorVariable setErrors -ErrorAction SilentlyContinue)

            $setErrors | Should -HaveCount 1
            $setErrors[0].FullyQualifiedErrorId | Should -BeLike 'WriteSdError,*'
            $setErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $setErrors[0].TargetObject.FullName | Should -Be $blocked
            (Get-Acl -LiteralPath $blocked).Sddl | Should -BeExactly $before
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $next
            @(Get-EveryoneRule -Path $next) | Should -HaveCount 1
        }

        It 'Should report a deleted target and still write the next descriptor' {
            $deleted = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorDeleted'
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorAfterDeleted'
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $deleted, $next)
            Add-NTFSAccess -SecurityDescriptor $descriptors -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            Assert-TestSandboxPath -Sandbox $sandbox -Path $deleted
            Remove-Item -LiteralPath $deleted

            $result = @(Set-NTFSSecurityDescriptor -SecurityDescriptor $descriptors -PassThru -ErrorVariable setErrors -ErrorAction SilentlyContinue)

            $setErrors | Should -HaveCount 1
            $setErrors[0].FullyQualifiedErrorId | Should -BeLike 'WriteSdError,*'
            $setErrors[0].TargetObject.FullName | Should -Be $deleted
            $deleted | Should -Not -Exist
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $next
            @(Get-EveryoneRule -Path $next) | Should -HaveCount 1
        }
    }

    Context 'When the written descriptor denies reading it again' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc6, the cmdlet read the item again for -PassThru inside the block that retries a denied write,
        # so that a denied read started an ownership retry and ended in a WriteSdError, although the write succeeded.
        It 'Should write the descriptor and report a read error for -PassThru, not a write error' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThruDenied'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            # A deny entry for OWNER RIGHTS replaces the right of the owner to read the security descriptor.
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'S-1-3-4' -AccessRights ReadPermissions -AccessType Deny -AppliesTo ThisFolderOnly

            $result = @(Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -PassThru -ErrorVariable setErrors -ErrorAction SilentlyContinue)

            $result | Should -BeNullOrEmpty
            $setErrors | Should -HaveCount 1
            $setErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            # Get-Acl of an elevated Windows PowerShell still reads the item, so .NET checks that the entry was written;
            # .NET Core has the method as an extension method.
            $info = New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $file
            $denied = $null
            try {
                if ($PSVersionTable.PSEdition -eq 'Desktop') {
                    $null = $info.GetAccessControl()
                }
                else {
                    $null = [System.IO.FileSystemAclExtensions]::GetAccessControl($info)
                }
            }
            catch {
                $denied = $_.Exception.GetBaseException()
            }

            $denied | Should -BeOfType [System.UnauthorizedAccessException]
        }
    }
}

Describe 'FileSystemSecurity2.Write with another item' {
    # Before 5.0.0-rc4, Write wrote every section that the descriptor held to the other item, also the owner that
    # Windows returns with a DACL without the auto-inherit flag, which fails for an owner that the user can't assign.
    It 'Should write only the sections that were read, given the item as <_>' -Skip:(-not $canAssignAnyOwner) -ForEach @(
        'FileSystemInfo', 'String'
    ) {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'Source'
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'Target'
        Set-TestOwner -Sandbox $sandbox -Path $source -Sid $trustedInstaller
        $targetOwner = (Get-Acl -LiteralPath $target).GetOwner($sidType).Value
        Get-RestorePrivilegeState | Should -Be 'Disabled'
        $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
            (Get-Item2 -Path $source), [System.Security.AccessControl.AccessControlSections]::Access
        )
        $sd.SecurityDescriptor.GetOwner($sidType).Value | Should -Be $trustedInstaller
        Assert-TestSandboxPath -Sandbox $sandbox -Path $target
        $destination = if ($_ -eq 'String') { $target } else { Get-Item2 -Path $target }

        { $sd.Write($destination) } | Should -Not -Throw

        (Get-Acl -LiteralPath $target).GetOwner($sidType).Value | Should -Be $targetOwner
    }
}

# Before 5.0.0-rc6, comparing a descriptor threw an InvalidCastException, and its hash code a NullReferenceException,
# so -eq and a hashtable with the descriptor as key failed.
Describe 'Comparing security descriptors' {
    It 'Should find a descriptor equal to itself and not to another one, and use it as a key' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Compare'
        $sd = Get-NTFSSecurityDescriptor -Path $file
        $other = Get-NTFSSecurityDescriptor -Path $file

        $sd -eq $sd | Should -BeTrue
        $sd -eq $other | Should -BeFalse
        $sd.Equals('x') | Should -BeFalse
        $table = @{}
        $table[$sd] = 'first'
        $table[$other] = 'second'
        $table[$sd] | Should -Be 'first'
        $table.Count | Should -Be 2
    }

    # Before 5.0.0-rc6, the conversion returned a field that was never set, so it gave $null.
    It 'Should convert to the security object of .NET that it holds' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ConvertFile'
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ConvertFolder' -Directory
        $fileSd = Get-NTFSSecurityDescriptor -Path $file
        $folderSd = Get-NTFSSecurityDescriptor -Path $folder

        [object]::ReferenceEquals([System.Security.AccessControl.FileSecurity] $fileSd, $fileSd.SecurityDescriptor) | Should -BeTrue
        [object]::ReferenceEquals([System.Security.AccessControl.DirectorySecurity] $folderSd, $folderSd.SecurityDescriptor) | Should -BeTrue
    }

    It 'Should be equal only to a descriptor of the module, in both directions' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Symmetric'
        $sd = Get-NTFSSecurityDescriptor -Path $file
        $raw = $sd.SecurityDescriptor

        $sd.Equals($raw) | Should -BeFalse
        $raw.Equals($sd) | Should -BeFalse
    }
}
