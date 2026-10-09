<#
    Tests the audit cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder. Reading
    and changing audit entries needs the Security privilege; tests that need it skip without it and run in CI,
    whose runners are elevated.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canReadAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    # Assigning an owner other than the user or one of its groups needs the Restore privilege.
    $canAssignAnyOwner = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Audit'
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

Describe 'Get-NTFSAudit' {
    Context 'When the audit entries cannot be read' {
        It 'Should write an error without the Security privilege instead of returning nothing' -Skip:$canReadAudit {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NoPrivilege'

            $entries = @(Get-NTFSAudit -Path $file -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $entries | Should -BeNullOrEmpty
            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        }

        It 'Should write an error for a security descriptor that was read without the audit entries' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AccessOnly'
            $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
                (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Access
            )

            $entries = @(Get-NTFSAudit -SecurityDescriptor $sd -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $entries | Should -BeNullOrEmpty
            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        }
    }

    Context 'When a path fails after a path with audit entries' {
        # Before 5.0.0, the cmdlet wrote the entries of the previous item again for the failing path. In CI, the deny
        # entry made the original implementation, which also read the DACL, fail for the second path. The current one
        # reads only the SACL, which the deny entry doesn't block; Access.Tests.ps1 guards the same loop fix in
        # Get-NTFSAccess with a read that fails without elevation.
        It 'Should return the entries of the first item once' -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Audited' -Directory
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Add-NTFSAudit -Path $folder -Account 'Everyone' -AccessRights Delete -AuditFlags Success
            Block-TestReadPermission -Sandbox $sandbox -Path $denied

            $entries = @(Get-NTFSAudit -Path $folder, $denied -ExcludeInherited -ErrorAction SilentlyContinue)

            @($entries | Where-Object -Property FullName -EQ -Value $folder) | Should -HaveCount 1
        }
    }
}

Describe 'Add-NTFSAudit' {
    Context 'Positional parameters' {
        It 'Should take -Account at position 2 and -AccessRights at position 3 in the <_> parameter set' -ForEach @(
            'PathSimple', 'PathComplex', 'SDSimple', 'SDComplex'
        ) {
            $parameterSet = (Get-Command -Name Add-NTFSAudit).ParameterSets | Where-Object -Property Name -EQ -Value $_
            $positions = @{}
            $parameterSet.Parameters | Where-Object -Property Position -GE -Value 0 | ForEach-Object -Process {
                $positions[$_.Name] = $_.Position
            }

            $positions['Account'] | Should -Be 2
            $positions['AccessRights'] | Should -Be 3
        }

        # A descriptor from Get-NTFSSecurityDescriptor contains the audit entries only with the Security privilege.
        It 'Should bind an account and access rights that are passed by position' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Positional'
            $sd = Get-NTFSSecurityDescriptor -Path $file

            Add-NTFSAudit -SecurityDescriptor $sd 'Everyone' 'ReadData' -InheritanceFlags None -PropagationFlags None -ErrorAction Stop

            $rules = $sd.SecurityDescriptor.GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier])
            @($rules | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
        }
    }

    # A descriptor from Get-NTFSSecurityDescriptor contains the audit entries only with the Security privilege.
    Context 'With -PassThru' -Skip:(-not $canReadAudit) {
        It 'Should return the audit entries of a security descriptor, not its access entries' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThru'
            $sd = Get-NTFSSecurityDescriptor -Path $file

            $result = @(Add-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -PassThru)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' }) | Should -HaveCount 1
        }

        It 'Should report the inheritance of the audit entries in InheritanceEnabled, not that of the access entries' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditProtected'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            $sd.SecurityDescriptor.SetAuditRuleProtection($true, $false)

            $result = @(Add-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -PassThru)

            $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeFalse
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_.InheritanceEnabled | Should -BeFalse }
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
        # privilege (#34).
        It 'Should add the audit entry and keep the owner' -Skip:(-not ($canReadAudit -and $canAssignAnyOwner)) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OtherOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'

            Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorVariable addErrors -ErrorAction SilentlyContinue

            $addErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
            @(Get-NTFSAudit -Path $file -ExcludeInherited) | Should -HaveCount 1
        }
    }

    Context 'With inherited access entries' {
        # Before 5.0.0-rc3, the cmdlet also read and wrote the DACL. Read together with the SACL, the inherited entries
        # of a DACL without the auto-inherit flag lose their inherited flag when the folder has no SACL, and the cmdlet
        # wrote them back as explicit copies.
        It 'Should leave the access entries unchanged' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Inherited'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $inheritedCount = @((Get-Acl -LiteralPath $file).GetAccessRules($false, $true, $sidType)).Count
            $inheritedCount | Should -BeGreaterThan 0

            Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None

            $acl = Get-Acl -LiteralPath $file
            @($acl.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
            @($acl.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $inheritedCount
        }
    }
}

Describe 'Get-NTFSOrphanedAudit' {
    BeforeAll {
        $orphanedFile = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedAudit'
        $missing = Join-Path -Path $sandbox -ChildPath 'MissingOrphanedAudit.txt'
    }

    Context 'With the Security privilege' {
        BeforeAll {
            # Two entries of accounts that don't exist and one of Everyone, which resolves. Each test reads them, so
            # none depends on another one.
            foreach ($sid in 'S-1-5-21-1-2-3-1001', 'S-1-5-21-1-2-3-1002', 'S-1-1-0') {
                Add-NTFSAudit -Path $orphanedFile -Account $sid -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            }

            $orphanedFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedAuditFolder' -Directory
            Add-NTFSAudit -Path $orphanedFolder -Account 'S-1-5-21-1-2-3-1003' -AccessRights Delete -ErrorAction Stop
            $inheritingFile = Join-Path -Path $orphanedFolder -ChildPath 'File.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $inheritingFile
            Set-Content -LiteralPath $inheritingFile -Value 'File'
        }

        # Before 5.0.0, the cmdlet wrote the entries of an item as one collection and ignored -Account.
        It 'Should return one object per entry whose account cannot be resolved' -Skip:(-not $canReadAudit) {
            $result = @(Get-NTFSOrphanedAudit -Path $orphanedFile)

            $result | Should -HaveCount 2
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            $result.Account.Sid | Should -Not -Contain 'S-1-1-0'
        }

        It 'Should return only the entries of -Account' -Skip:(-not $canReadAudit) {
            $result = @(Get-NTFSOrphanedAudit -Path $orphanedFile -Account 'S-1-5-21-1-2-3-1002')

            $result | Should -HaveCount 1
            $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-1002'
        }

        It 'Should read the entries of a security descriptor' -Skip:(-not $canReadAudit) {
            $result = @(Get-NTFSSecurityDescriptor -Path $orphanedFile | Get-NTFSOrphanedAudit -ErrorAction Stop)

            $result | Should -HaveCount 2
            $result | ForEach-Object -Process { $_.FullName | Should -Be $orphanedFile }
        }

        It 'Should return an inherited entry, and nothing with -ExcludeInherited' -Skip:(-not $canReadAudit) {
            $result = @(Get-NTFSOrphanedAudit -Path $inheritingFile -ErrorAction Stop)
            $explicitResult = @(Get-NTFSOrphanedAudit -Path $inheritingFile -ExcludeInherited -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-1003'
            $result[0].IsInherited | Should -BeTrue
            $explicitResult | Should -BeNullOrEmpty
        }

        It 'Should report the number of orphaned entries of each item in a verbose message' -Skip:(-not $canReadAudit) {
            $messages = @(Get-NTFSOrphanedAudit -Path $orphanedFile -Verbose 4>&1 | Where-Object -FilterScript {
                    $_ -is [System.Management.Automation.VerboseRecord] })

            $messages.Message | Should -Contain "Item $orphanedFile knows about 2 orphaned SIDs in its ACL"
        }
    }

    It 'Should write an error for a path that does not exist and continue with the next path' -Skip:(-not $canReadAudit) {
        $result = @(Get-NTFSOrphanedAudit -Path $missing, $orphanedFile -ErrorVariable orphanedErrors -ErrorAction SilentlyContinue)

        $orphanedErrors | Should -HaveCount 1
        $orphanedErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadError,*'
        $orphanedErrors[0].TargetObject | Should -Be $missing
        $result | ForEach-Object -Process { $_.FullName | Should -Be $orphanedFile }
    }

    # Since 5.0.0-rc7, the next path has an error of its own without the Security privilege, which shows that the cmdlet
    # continued with it.
    It 'Should write an error for a path that does not exist and continue with the next path without the Security privilege' -Skip:$canReadAudit {
        $result = @(Get-NTFSOrphanedAudit -Path $missing, $orphanedFile -ErrorVariable orphanedErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        $orphanedErrors | Should -HaveCount 2
        $orphanedErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadError,*'
        $orphanedErrors[0].TargetObject | Should -Be $missing
        $orphanedErrors[1].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        $orphanedErrors[1].TargetObject | Should -Be $orphanedFile
    }

    It 'Should write an error for a security descriptor that was read without the audit entries' {
        $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
            (Get-Item2 -Path $orphanedFile), [System.Security.AccessControl.AccessControlSections]::Access
        )

        $result = @($sd | Get-NTFSOrphanedAudit -ErrorVariable orphanedErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        $orphanedErrors | Should -HaveCount 1
        $orphanedErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
    }

    # Before 5.0.0-rc7, the cmdlet read the item without its audit entries and returned nothing, as for an item without
    # orphaned entries; it now writes the error of Get-NTFSAudit.
    It 'Should write a ReadSecurityError without the Security privilege instead of returning nothing' -Skip:$canReadAudit {
        $result = @(Get-NTFSOrphanedAudit -Path $orphanedFile -ErrorVariable orphanedErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        $orphanedErrors | Should -HaveCount 1
        $orphanedErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        $orphanedErrors[0].TargetObject | Should -Be $orphanedFile
    }
}

Describe 'Remove-NTFSAudit' {
    Context 'When a path does not exist' {
        BeforeAll {
            $missing = Join-Path -Path $sandbox -ChildPath 'Missing.txt'
        }

        # Before 5.0.0, the cmdlet went on with the missing item and wrote a second, misleading RemoveAceError.
        It 'Should write only the read error' {
            Remove-NTFSAudit -Path $missing -Account 'Everyone' -AccessRights ReadData -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
        }

        It 'Should not stop with -PassThru' {
            { Remove-NTFSAudit -Path $missing -Account 'Everyone' -AccessRights ReadData -PassThru -ErrorAction SilentlyContinue } |
                Should -Not -Throw
        }
    }

    # A descriptor from Get-NTFSSecurityDescriptor contains the audit entries only with the Security privilege.
    Context 'With -RemoveSpecific' -Skip:(-not $canReadAudit) {
        BeforeEach {
            $removeFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSpecific' -Directory
            $sd = Get-NTFSSecurityDescriptor -Path $removeFolder
            Add-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights Modify

            function Get-EveryoneAuditRule {
                $sd.SecurityDescriptor.GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
            }
        }

        It 'Should keep an audit entry that does not match exactly' {
            Remove-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -RemoveSpecific

            (Get-EveryoneAuditRule).FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Modify) | Should -BeTrue
        }

        It 'Should remove an audit entry that matches exactly' {
            Remove-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights Modify -RemoveSpecific

            Get-EveryoneAuditRule | Should -BeNullOrEmpty
        }

        It 'Should keep an audit entry that does not match exactly, given the path' {
            Add-NTFSAudit -Path $removeFolder -Account 'Everyone' -AccessRights Modify

            Remove-NTFSAudit -Path $removeFolder -Account 'Everyone' -AccessRights ReadData -RemoveSpecific -ErrorAction Stop

            $entries = @(Get-NTFSAudit -Path $removeFolder -ExcludeInherited | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' })
            $entries | Should -HaveCount 1
            $entries[0].AccessRights.ToString() | Should -BeLike '*Modify*'
        }

        It 'Should remove an audit entry that matches exactly, given the path' {
            Add-NTFSAudit -Path $removeFolder -Account 'Everyone' -AccessRights Modify

            Remove-NTFSAudit -Path $removeFolder -Account 'Everyone' -AccessRights Modify -RemoveSpecific -ErrorAction Stop

            Get-NTFSAudit -Path $removeFolder -ExcludeInherited | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' } |
                Should -BeNullOrEmpty
        }
    }

    Context 'With -PassThru' {
        It 'Should return the audit entries of the item, not its access entries' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThru'
            Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
            Add-NTFSAudit -Path $file -Account 'BUILTIN\Users' -AccessRights Delete -InheritanceFlags None -PropagationFlags None

            $result = @(Remove-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -PassThru)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-5-32-545' }) | Should -HaveCount 1
        }
    }

    Context 'When the item has no SACL' {
        # An item without audit entries can have no SACL at all, and Windows denies a write without any section:
        # (5) Access is denied. Before 5.0.0-rc4, the cmdlet failed for such an item, although there was nothing to
        # remove.
        It 'Should write no error' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NoSacl'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $audit = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
                (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Audit
            )
            $audit.SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit') | Should -BeNullOrEmpty

            Remove-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -BeNullOrEmpty
        }
    }
}

Describe 'Audit cmdlets with a security descriptor without the audit entries' {
    # Before 5.0.0-rc4, only Get-NTFSAudit reported a security descriptor that was read without the audit entries, such
    # as without the Security privilege. The other audit cmdlets changed the missing SACL in memory and wrote no error,
    # and -PassThru returned nothing (#109).
    It '<Command> should write an error and leave the descriptor without audit entries' -ForEach @(
        @{ Command = 'Add-NTFSAudit'; Parameters = @{ Account = 'Everyone'; AccessRights = 'ReadData'; PassThru = $true } }
        @{ Command = 'Remove-NTFSAudit'; Parameters = @{ Account = 'Everyone'; AccessRights = 'ReadData'; PassThru = $true } }
        @{ Command = 'Clear-NTFSAudit'; Parameters = @{ DisableInheritance = $true } }
    ) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AccessOnly'
        $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
            (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Access
        )

        $result = @(& $Command -SecurityDescriptor $sd @Parameters -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        $auditErrors | Should -HaveCount 1
        $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        # The descriptor was read with the access entries only, not without the Security privilege.
        $auditErrors[0].Exception.Message | Should -Not -BeLike '*because it was read without the Security privilege*'
        $sd.SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit') | Should -BeNullOrEmpty
    }
}

Describe 'Clear-NTFSAudit' {
    Context 'When the item has an owner that the user cannot assign' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc3, the cmdlet wrote the unchanged owner back, which Windows refuses without the Restore
        # privilege (#34).
        It 'Should remove the audit entries and keep the owner' -Skip:(-not ($canReadAudit -and $canAssignAnyOwner)) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearOtherOwner'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'

            Clear-NTFSAudit -Path $file -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
            @(Get-NTFSAudit -Path $file -ExcludeInherited) | Should -BeNullOrEmpty
        }
    }

    Context 'When the item has no SACL' {
        # An item without audit entries can have no SACL at all, and Windows denies a write without any section.
        # Before 5.0.0-rc3, the cmdlet also read and wrote the DACL, and in an elevated session it wrote the inherited
        # access entries back as explicit copies.
        It 'Should write no error and leave the access entries unchanged' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NoSacl'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $audit = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
                (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Audit
            )
            $audit.SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit') | Should -BeNullOrEmpty
            $inheritedCount = @((Get-Acl -LiteralPath $file).GetAccessRules($false, $true, $sidType)).Count
            # Without inherited entries, the test couldn't see them copied as explicit ones (#110).
            $inheritedCount | Should -BeGreaterThan 0

            Clear-NTFSAudit -Path $file -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -BeNullOrEmpty
            $acl = Get-Acl -LiteralPath $file
            @($acl.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
            @($acl.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $inheritedCount
        }
    }

    Context 'Without the Security privilege' {
        # Before 5.0.0-rc3, the cmdlet read the security descriptor without its SACL, found no audit entries to remove,
        # and finished without an error although nothing was changed; it also wrote the DACL back.
        It 'Should write an error and leave the item unchanged' -Skip:$canReadAudit {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NoPrivilege'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sddl = (Get-Acl -LiteralPath $file).Sddl

            Clear-NTFSAudit -Path $file -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -HaveCount 1
            $clearErrors[0].FullyQualifiedErrorId | Should -BeLike 'ClearAclError,*'
            (Get-Acl -LiteralPath $file).Sddl | Should -BeExactly $sddl
        }
    }
}

# Before 5.0.0-rc6, comparing an audit entry with anything threw an InvalidCastException.
Describe 'Comparing audit entries' {
    It 'Should find an entry equal to itself and not to a string' -Skip:(-not $canReadAudit) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Compare'
        Add-NTFSAudit -Path $file -Account 'S-1-1-0' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
        $entries = @(Get-NTFSAudit -Path $file -ExcludeInherited)
        $entries | Should -HaveCount 1

        $entries[0] -eq $entries[0] | Should -BeTrue
        $entries -contains $entries[0] | Should -BeTrue
        $entries[0].Equals('S-1-1-0') | Should -BeFalse
    }
}

# Before 5.0.0-rc6, -ExcludeExplicit gave each inherited audit entry the source of another entry.
Describe 'InheritedFrom of audit entries' {
    It 'Should name the folder that an inherited entry comes from, also with -ExcludeExplicit' -Skip:(-not $canReadAudit) {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritedFrom' -Directory
        Add-NTFSAudit -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -InheritanceFlags 'ContainerInherit, ObjectInherit' -PropagationFlags None
        $file = Join-Path -Path $folder -ChildPath 'File.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        Set-Content -LiteralPath $file -Value 'File'
        Add-NTFSAudit -Path $file -Account 'S-1-5-32-546' -AccessRights Delete -InheritanceFlags None -PropagationFlags None

        $all = @(Get-NTFSAudit -Path $file)
        $inherited = @(Get-NTFSAudit -Path $file -ExcludeExplicit)

        @($all | Where-Object -FilterScript { $_.IsInherited }) | Should -HaveCount 1
        @($all | Where-Object -FilterScript { $_.IsInherited })[0].InheritedFrom | Should -Be $folder
        $inherited | Should -HaveCount 1
        $inherited[0].InheritedFrom | Should -Be $folder
    }
}
Describe 'Audit changes with the Security privilege disabled' {
    BeforeAll {
        $holdsSecurityForOperations = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    }

    BeforeEach {
        $savedEnablePrivileges = $privateData['EnablePrivileges']
        $securityWasEnabled = (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Security').PrivilegeState -eq 'Enabled'
    }

    AfterEach {
        $privateData['EnablePrivileges'] = $savedEnablePrivileges
        if ($securityWasEnabled) {
            $null = [ProcessPrivileges.ProcessExtensions]::EnablePrivilege(
                [Diagnostics.Process]::GetCurrentProcess(), [ProcessPrivileges.Privilege]::Security
            )
        }
        else {
            $null = [ProcessPrivileges.ProcessExtensions]::DisablePrivilege(
                [Diagnostics.Process]::GetCurrentProcess(), [ProcessPrivileges.Privilege]::Security
            )
        }
    }

    It '<Command> should use a held privilege or report a missing one and continue to the next path' -ForEach @(
        @{ Command = 'Add-NTFSAudit'; ErrorId = 'AddAceError'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData'; PassThru = $true } }
        @{ Command = 'Remove-NTFSAudit'; ErrorId = 'RemoveAceError'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'Delete'; PassThru = $true } }
        @{ Command = 'Clear-NTFSAudit'; ErrorId = 'ClearAclError'; Parameters = @{ DisableInheritance = $true } }
        @{ Command = 'Enable-NTFSAuditInheritance'; ErrorId = 'ModifySdError'; Parameters = @{ PassThru = $true; RemoveExplicitAuditRules = $true } }
        @{ Command = 'Disable-NTFSAuditInheritance'; ErrorId = 'ModifySdError'; Parameters = @{ PassThru = $true; RemoveInheritedAuditRules = $true } }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'DisabledSecurity'
        $missing = Join-Path -Path $sandbox -ChildPath ('MissingAudit-{0}' -f [guid]::NewGuid().ToString('N'))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path, $missing
        if ($holdsSecurityForOperations) {
            $privateData['EnablePrivileges'] = $true
            Add-NTFSAudit -Path $path -Account 'S-1-1-0' -AccessRights Delete -AuditFlags Success -AppliesTo ThisFolderOnly
            $saclBefore = (Get-NTFSSecurityDescriptor -Path $path).SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit')
        }
        $before = (Get-Acl -LiteralPath $path).Sddl
        $privateData['EnablePrivileges'] = $false
        $null = [ProcessPrivileges.ProcessExtensions]::DisablePrivilege(
            [Diagnostics.Process]::GetCurrentProcess(), [ProcessPrivileges.Privilege]::Security
        )

        (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Security').PrivilegeState | Should -Not -Be 'Enabled'

        $result = @(& $Command -Path $path, $missing @Parameters -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

        (Get-Acl -LiteralPath $path).Sddl | Should -BeExactly $before
        if ($holdsSecurityForOperations) {
            # AlphaFS temporarily enables a held Security privilege for SACL access, even with automatic privileges off.
            (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Security').PrivilegeState | Should -Be 'Disabled'
            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $auditErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $auditErrors[0].TargetObject | Should -BeExactly $missing
            $written = Get-NTFSSecurityDescriptor -Path $path
            $rules = @($written.SecurityDescriptor.GetAuditRules(
                $true, $false, [System.Security.Principal.SecurityIdentifier]
            ))
            switch ($Command) {
                'Add-NTFSAudit' {
                    $result | Should -Not -BeNullOrEmpty
                    $result | ForEach-Object { $_.FullName | Should -BeExactly $path }
                    @($rules | Where-Object {
                        $_.IdentityReference.Value -eq 'S-1-1-0' -and $_.FileSystemRights.HasFlag(
                            [System.Security.AccessControl.FileSystemRights]::ReadData
                        )
                    }).Count | Should -BeGreaterThan 0
                }
                'Disable-NTFSAuditInheritance' {
                    $result | Should -HaveCount 1
                    $result[0].AuditInheritanceEnabled | Should -BeFalse
                    $rules | Should -HaveCount 1
                    $rules[0].FileSystemRights | Should -Be ([System.Security.AccessControl.FileSystemRights]::Delete)
                }
                'Enable-NTFSAuditInheritance' {
                    $result | Should -HaveCount 1
                    $result[0].AuditInheritanceEnabled | Should -BeTrue
                    $rules | Should -BeNullOrEmpty
                }
                default {
                    $result | Should -BeNullOrEmpty
                    $rules | Should -BeNullOrEmpty
                }
            }
            $written.SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit') | Should -Not -BeExactly $saclBefore
        }
        else {
            $result | Should -BeNullOrEmpty
            $auditErrors | Should -HaveCount 2
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
            $auditErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $auditErrors[0].TargetObject | Should -BeExactly $path
            $auditErrors[1].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $auditErrors[1].CategoryInfo.Category | Should -Be 'OpenError'
            $auditErrors[1].TargetObject | Should -BeExactly $missing
        }
    }
}
