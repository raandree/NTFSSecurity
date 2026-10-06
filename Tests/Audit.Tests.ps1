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
    }

    # Before 5.0.0, the cmdlet wrote the entries of an item as one collection and ignored -Account.
    It 'Should return one object per entry whose account cannot be resolved' -Skip:(-not $canReadAudit) {
        foreach ($sid in 'S-1-5-21-1-2-3-1001', 'S-1-5-21-1-2-3-1002') {
            Add-NTFSAudit -Path $orphanedFile -Account $sid -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
        }

        $result = @(Get-NTFSOrphanedAudit -Path $orphanedFile)

        $result | Should -HaveCount 2
        $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
    }

    It 'Should return only the entries of -Account' -Skip:(-not $canReadAudit) {
        $result = @(Get-NTFSOrphanedAudit -Path $orphanedFile -Account 'S-1-5-21-1-2-3-1002')

        $result | Should -HaveCount 1
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
