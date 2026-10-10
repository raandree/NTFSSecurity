<#
    Live tests of the module against a Windows file server in a lab, for the cases that depend on the file server or
    on domain accounts and that the tests in the Tests folder can't cover. Invoke-NTFSSecurityLabTest.ps1 prepares the
    lab and runs this file on the client in the roles Delegate, ServerAdmin, and Admin, as the accounts of these roles,
    and then on the file server in the role Server, which checks the security descriptors that the runs on the client
    left, without the module. README.md describes the cases and the lab. Without a configuration, all tests are
    skipped.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '', Justification = 'Pester passes the data of the container to the blocks.'
)]
param (
    [string]
    $ModulePath,

    [string]
    $ConfigurationPath,

    [ValidateSet('', 'Delegate', 'ServerAdmin', 'Admin', 'Server')]
    [string]
    $Role
)

BeforeDiscovery {
    $configured = -not [string]::IsNullOrEmpty($ConfigurationPath)

    $variants = @(
        @{ Variant = 'LegacyDacl'; Description = 'a DACL without the auto-inherit flag'; AutoInherited = $false }
        @{ Variant = 'AutoInheritedDacl'; Description = 'an auto-inherited DACL'; AutoInherited = $true }
    )
    $operations = 'AddAccess', 'RemoveAccess', 'ClearAccess', 'DisableInheritance', 'EnableInheritance',
    'SetInheritance', 'SetSecurityDescriptor'

    $auditSuccessCases = @(
        @{ AuditRole = 'Admin'; Description = 'an administrator of the file server and the client' }
        @{ AuditRole = 'ServerAdmin'; Description = 'an administrator of the file server only' }
    )

    $ownedFolders = @(
        foreach ($variant in $variants) {
            foreach ($operation in $operations) {
                @{ Folder = 'Case1\{0}\{1}' -f $variant.Variant, $operation }
            }
        }
        foreach ($auditRole in 'Admin', 'ServerAdmin', 'Delegate') {
            foreach ($operation in 'GetAudit', 'AddAudit', 'RemoveAudit') {
                @{ Folder = 'Case2\{0}\{1}' -f $auditRole, $operation }
            }
        }
    )

    # The administrators of the file server add and remove the audit entries; the delegated account changes nothing.
    $auditExpectations = @(
        foreach ($auditRole in 'Admin', 'ServerAdmin', 'Delegate') {
            $mayWrite = $auditRole -ne 'Delegate'
            @{ Folder = "Case2\$auditRole\GetAudit"; Count = 1 }
            @{ Folder = "Case2\$auditRole\AddAudit"; Count = [int]$mayWrite }
            @{ Folder = "Case2\$auditRole\RemoveAudit"; Count = [int](-not $mayWrite) }
        }
    )

    # Case 5: only the administrators of the file server hold the Restore privilege there, which assigning an owner
    # other than the account itself needs.
    $ownerCases = @(
        @{ OwnerRole = 'Admin'; Description = 'an administrator of the file server and the client'; MayAssign = $true }
        @{ OwnerRole = 'ServerAdmin'; Description = 'an administrator of the file server only'; MayAssign = $true }
        @{ OwnerRole = 'Delegate'; Description = 'the delegated account, an administrator of the client only'; MayAssign = $false }
    )
    $ownerExpectations = @(
        foreach ($ownerCase in $ownerCases) {
            @{ Folder = "Case5\$($ownerCase.OwnerRole)\GetOwner"; Owner = 'Administrators' }
            @{ Folder = "Case5\$($ownerCase.OwnerRole)\TakeOwnership"; Owner = $ownerCase.OwnerRole }
            @{ Folder = "Case5\$($ownerCase.OwnerRole)\AssignOwner"; Owner = if ($ownerCase.MayAssign) { 'Subject' } else { 'Administrators' } }
        }
    )

    # Case 6: the state of the SACL that each folder has after the runs. The folders inherit one audit entry; the
    # administrators of the file server change them, the delegated account changes nothing.
    $auditInheritanceExpectations = @(
        foreach ($auditRole in 'Admin', 'ServerAdmin', 'Delegate') {
            $mayWrite = $auditRole -ne 'Delegate'
            @{ Folder = "Case6\$auditRole\DisableAuditInheritance"; Protected = $mayWrite; Explicit = [int]$mayWrite; Inherited = [int](-not $mayWrite) }
            @{ Folder = "Case6\$auditRole\EnableAuditInheritance"; Protected = -not $mayWrite; Explicit = 0; Inherited = [int]$mayWrite }
            @{ Folder = "Case6\$auditRole\ClearAudit"; Protected = $false; Explicit = [int](-not $mayWrite); Inherited = 1 }
            @{ Folder = "Case6\$auditRole\GetInheritance"; Protected = $false; Explicit = 0; Inherited = 1 }
        }
    )
    $ownedFolders += @(
        foreach ($auditRole in 'Admin', 'ServerAdmin', 'Delegate') {
            foreach ($operation in 'DisableAuditInheritance', 'EnableAuditInheritance', 'ClearAudit', 'GetInheritance') {
                @{ Folder = "Case6\$auditRole\$operation" }
            }
        }
    )

    # Case 9: the accounts of other domains and forests that the script created, if any.
    $foreignAccounts = @(
        if ($configured) {
            foreach ($account in (Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json).ForeignAccounts) {
                @{ Name = $account.Name; Sid = $account.Sid; Rights = $account.Rights; EffectiveRights = [long]$account.EffectiveRights }
            }
        }
    )
}

BeforeAll {
    if ($ConfigurationPath) {
        . (Join-Path -Path $PSScriptRoot -ChildPath 'NTFSSecurity.LabHelpers.ps1')
        $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
        Assert-LabTestTarget -Configuration $configuration

        # On the client, the tests use the share; on the file server, the folder of the share.
        $runRoot = if ($Role -eq 'Server') { $configuration.ServerPath } else { $configuration.SharePath }
        if ($ModulePath) {
            Import-Module -Name (Join-Path -Path $ModulePath -ChildPath 'NTFSSecurity.psd1') -Force -ErrorAction Stop
        }

        $administrators = 'S-1-5-32-544'
        $everyone = 'S-1-1-0'
        $sidType = [System.Security.Principal.SecurityIdentifier]
        $synchronize = 0x100000L
    }

    function Get-LabPath {
        param ([string] $RelativePath)

        # Normalized, so that neither '..' nor '/' leads out of the folder of the run.
        $path = [System.IO.Path]::GetFullPath((Join-Path -Path $runRoot -ChildPath $RelativePath))
        if ([System.IO.Path]::IsPathRooted($RelativePath) -or
            -not $path.StartsWith($runRoot.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "'$RelativePath' must be a path in the folder of the run."
        }

        $path
    }

    function Get-LabOwner {
        param ([string] $Path)

        (Get-LabSecurityDescriptor -Path $Path).Owner.Value
    }

    function Get-LabExplicitAccessRule {
        param ([string] $Path, [string] $Sid)

        (Get-Acl -LiteralPath $Path).GetAccessRules($true, $false, $sidType) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq $Sid }
    }

    function Format-LabError {
        param ([object[]] $ErrorRecord)

        foreach ($record in $ErrorRecord) {
            if ($null -ne $record) {
                '{0}: {1}' -f $record.FullyQualifiedErrorId, $record.Exception.Message
            }
        }
    }

    function Format-LabRight {
        param ([object] $Right)

        # .NET adds Synchronize to every allow entry that it creates.
        '0x{0:X}' -f (([long]$Right) -bor $synchronize)
    }
}

AfterAll {
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Account of the run' -Tag 'Delegate', 'ServerAdmin', 'Admin', 'Server' -Skip:(-not $configured) {
    It 'Should run as the account of the role' {
        [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value | Should -Be $configuration.Accounts.$Role.Sid
    }

    It 'Should be an administrator of this computer only in the roles that are' {
        $principal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList (
            [System.Security.Principal.WindowsIdentity]::GetCurrent()
        )
        $expected = if ($env:COMPUTERNAME -eq $configuration.FileServer) {
            $configuration.Accounts.$Role.FileServerAdministrator
        }
        else {
            $configuration.Accounts.$Role.ClientAdministrator
        }

        $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) | Should -Be $expected
    }

    It 'Should test the module version of the run' -Skip:($Role -eq 'Server') {
        $module = Get-Module -Name NTFSSecurity
        $version = [string]$module.Version
        if ($module.PrivateData.PSData.Prerelease) {
            $version = '{0}-{1}' -f $version, $module.PrivateData.PSData.Prerelease
        }

        $version | Should -Be $configuration.ModuleVersion
    }
}

Describe 'Access and inheritance cmdlets on a share folder whose owner the account may not assign (#34)' -Tag 'Delegate' -Skip:(-not $configured) {
    # The delegated account has Full Control on the folders through a domain group, but isn't an administrator of the
    # file server, so the file server refuses Administrators as the owner that the account writes: (1307) This security
    # ID may not be assigned as the owner of this object. Before 5.0.0-rc3, the cmdlets wrote the unchanged owner back
    # whenever they had read it: Windows returns the owner with a DACL that is read alone when the DACL has no
    # auto-inherit flag, and Get-NTFSSecurityDescriptor always reads it.
    Context 'With <Description>' -ForEach $variants {
        BeforeAll {
            $folder = Get-LabPath -RelativePath "Case1\$Variant"
        }

        It 'Should start with folders that Administrators own' {
            foreach ($operation in 'AddAccess', 'RemoveAccess', 'ClearAccess', 'DisableInheritance',
                'EnableInheritance', 'SetInheritance', 'SetSecurityDescriptor') {
                $path = Join-Path -Path $folder -ChildPath $operation
                Get-LabOwner -Path $path | Should -Be $administrators -Because $operation
                Test-LabDaclAutoInherited -Path $path | Should -Be $AutoInherited -Because $operation
            }
        }

        It 'Add-NTFSAccess should add the entry and keep the owner' {
            $path = Join-Path -Path $folder -ChildPath 'AddAccess'

            Add-NTFSAccess -Path $path -Account $everyone -AccessRights ReadData -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            Get-LabOwner -Path $path | Should -Be $administrators
            @(Get-LabExplicitAccessRule -Path $path -Sid $everyone) | Should -HaveCount 1
        }

        It 'Remove-NTFSAccess should remove the entry and keep the owner' {
            $path = Join-Path -Path $folder -ChildPath 'RemoveAccess'
            @(Get-LabExplicitAccessRule -Path $path -Sid $everyone) | Should -HaveCount 1

            Remove-NTFSAccess -Path $path -Account $everyone -AccessRights ReadAndExecute -InheritanceFlags 'ContainerInherit, ObjectInherit' -PropagationFlags None -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            Get-LabOwner -Path $path | Should -Be $administrators
            Get-LabExplicitAccessRule -Path $path -Sid $everyone | Should -BeNullOrEmpty
        }

        It 'Clear-NTFSAccess should remove the explicit entries and keep the owner' {
            $path = Join-Path -Path $folder -ChildPath 'ClearAccess'

            Clear-NTFSAccess -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            Get-LabOwner -Path $path | Should -Be $administrators
            (Get-Acl -LiteralPath $path).GetAccessRules($true, $false, $sidType) | Should -BeNullOrEmpty
        }

        It 'Disable-NTFSAccessInheritance should disable the inheritance and keep the owner' {
            $path = Join-Path -Path $folder -ChildPath 'DisableInheritance'

            Disable-NTFSAccessInheritance -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            Get-LabOwner -Path $path | Should -Be $administrators
            (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -BeTrue
        }

        It 'Enable-NTFSAccessInheritance should enable the inheritance and keep the owner' {
            $path = Join-Path -Path $folder -ChildPath 'EnableInheritance'
            (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -BeTrue

            Enable-NTFSAccessInheritance -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            Get-LabOwner -Path $path | Should -Be $administrators
            (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -BeFalse
        }

        It 'Set-NTFSInheritance should disable the inheritance and keep the owner' {
            $path = Join-Path -Path $folder -ChildPath 'SetInheritance'

            Set-NTFSInheritance -Path $path -AccessInheritanceEnabled $false -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            Get-LabOwner -Path $path | Should -Be $administrators
            (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -BeTrue
        }

        It 'Set-NTFSSecurityDescriptor should write the added entry and keep the owner' {
            $path = Join-Path -Path $folder -ChildPath 'SetSecurityDescriptor'

            $descriptor = Get-NTFSSecurityDescriptor -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue
            Add-NTFSAccess -SecurityDescriptor $descriptor -Account $everyone -AccessRights ReadData -ErrorVariable +operationErrors -ErrorAction SilentlyContinue
            Set-NTFSSecurityDescriptor -SecurityDescriptor $descriptor -ErrorVariable +operationErrors -ErrorAction SilentlyContinue

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            Get-LabOwner -Path $path | Should -Be $administrators
            @(Get-LabExplicitAccessRule -Path $path -Sid $everyone) | Should -HaveCount 1
        }
    }
}

Describe 'Audit cmdlets on a share folder' -Skip:(-not $configured) {
    # Over SMB, the file server checks whether the account holds the Security privilege there; the role Server checks
    # the audit entries that the runs left on the file server.
    foreach ($auditCase in $auditSuccessCases) {
        Context 'As <Description>' -Tag $auditCase.AuditRole -ForEach @($auditCase) {
            BeforeAll {
                $folder = Get-LabPath -RelativePath "Case2\$AuditRole"
            }

            It 'Get-NTFSAudit should return the audit entry of the folder' {
                $entries = @(Get-NTFSAudit -Path (Join-Path -Path $folder -ChildPath 'GetAudit') -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                $entries | Should -HaveCount 1
                $entries[0].Account.Sid | Should -Be $everyone
                $entries[0].AuditFlags | Should -Be 'Success'
                [long]$entries[0].AccessRights | Should -Be 0x10000
            }

            It 'Add-NTFSAudit should add the audit entry and keep the owner' {
                $path = Join-Path -Path $folder -ChildPath 'AddAudit'

                Add-NTFSAudit -Path $path -Account $everyone -AccessRights ReadData -AuditFlags Failure -InheritanceFlags None -PropagationFlags None -ErrorVariable operationErrors -ErrorAction SilentlyContinue

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                Get-LabOwner -Path $path | Should -Be $administrators
            }

            It 'Remove-NTFSAudit should remove the audit entry and keep the owner' {
                $path = Join-Path -Path $folder -ChildPath 'RemoveAudit'

                Remove-NTFSAudit -Path $path -Account $everyone -AccessRights Delete -AuditFlags Success -InheritanceFlags None -PropagationFlags None -ErrorVariable operationErrors -ErrorAction SilentlyContinue

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                Get-LabOwner -Path $path | Should -Be $administrators
            }
        }
    }

    Context 'As the delegated account, an administrator of the client only' -Tag 'Delegate' {
        # The account has Full Control on the folders, so taking ownership succeeds, but it doesn't hold the Security
        # privilege on the file server, and it may not assign Administrators as the owner again.
        BeforeAll {
            $folder = Get-LabPath -RelativePath 'Case2\Delegate'
        }

        It 'Get-NTFSAudit should write a ReadSecurityError that names the missing privilege' {
            $entries = @(Get-NTFSAudit -Path (Join-Path -Path $folder -ChildPath 'GetAudit') -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

            $entries | Should -BeNullOrEmpty
            @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1
            $operationErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $operationErrors[0].Exception.Message | Should -Match 'privilege'
        }

        It 'Add-NTFSAudit should write an AddAceError that names the missing privilege and leave the folder unchanged' {
            $path = Join-Path -Path $folder -ChildPath 'AddAudit'
            $before = (Get-LabSecurityDescriptor -Path $path).GetSddlForm('All')

            Add-NTFSAudit -Path $path -Account $everyone -AccessRights ReadData -AuditFlags Failure -InheritanceFlags None -PropagationFlags None -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            $written = (Format-LabError -ErrorRecord $operationErrors) -join ' | '
            (Get-LabSecurityDescriptor -Path $path).GetSddlForm('All') | Should -Be $before -Because "the cmdlet wrote: $written"
            @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1 -Because "the cmdlet wrote: $written"
            $operationErrors[0].FullyQualifiedErrorId | Should -BeLike 'AddAceError,*'
            $operationErrors[0].Exception.Message | Should -Match 'privilege'
        }

        It 'Remove-NTFSAudit should write a RemoveAceError that names the missing privilege and leave the folder unchanged' {
            $path = Join-Path -Path $folder -ChildPath 'RemoveAudit'
            $before = (Get-LabSecurityDescriptor -Path $path).GetSddlForm('All')

            Remove-NTFSAudit -Path $path -Account $everyone -AccessRights Delete -AuditFlags Success -InheritanceFlags None -PropagationFlags None -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            $written = (Format-LabError -ErrorRecord $operationErrors) -join ' | '
            (Get-LabSecurityDescriptor -Path $path).GetSddlForm('All') | Should -Be $before -Because "the cmdlet wrote: $written"
            @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1 -Because "the cmdlet wrote: $written"
            $operationErrors[0].FullyQualifiedErrorId | Should -BeLike 'RemoveAceError,*'
            $operationErrors[0].Exception.Message | Should -Match 'privilege'
        }
    }
}

Describe 'Get-NTFSEffectiveAccess for a domain account on a share folder' -Tag 'Admin' -Skip:(-not $configured) {
    # The account gets ReadAndExecute through two nested domain groups and Write through a local group of the file
    # server. Only the file server knows its local groups. The expected rights come from the S4U tokens that the file
    # server and the client create for the account, which hold the same groups as the Effective Access tab there.
    BeforeAll {
        $path = Get-LabPath -RelativePath 'Case3\EffectiveAccess'
        $subject = $configuration.Accounts.Subject.Name
    }

    It 'Should return the rights through the domain groups and the local group of the file server with -ServerName, without a warning' {
        $result = @(Get-NTFSEffectiveAccess -Path $path -Account $subject -ServerName $configuration.FileServerFqdn -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $operationWarnings | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        Format-LabRight -Right $result[0].AccessRights | Should -Be (Format-LabRight -Right $configuration.EffectiveAccess.FileServerRights)
    }

    It 'Should return only the rights through the domain groups without -ServerName' {
        $result = @(Get-NTFSEffectiveAccess -Path $path -Account $subject -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        Format-LabRight -Right $result[0].AccessRights | Should -Be (Format-LabRight -Right $configuration.EffectiveAccess.ClientRights)
    }

    # The cmdlet page: when the remote authorization manager can't be reached, the cmdlet falls back to the local one
    # and warns that the result may be inaccurate; since 5.0.0-rc7, the warning names the computer.
    It 'Should fall back to the authorization manager of the client and warn when -ServerName can''t be reached' {
        $result = @(Get-NTFSEffectiveAccess -Path $path -Account $subject -ServerName $configuration.UnreachableServerName -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $operationWarnings.Message | Should -Contain ('The effective rights can only be computed based on group membership on this computer, ' +
            "because the computer '$($configuration.UnreachableServerName)' can't be reached for a remote access check. " +
            'For more accurate results, calculate effective access rights on that computer.')
        $result | Should -HaveCount 1
        Format-LabRight -Right $result[0].AccessRights | Should -Be (Format-LabRight -Right $configuration.EffectiveAccess.ClientRights)
    }
}

Describe 'Get-NTFSEffectiveAccess as an account that is not an administrator of the file server' -Tag 'Delegate' -Skip:(-not $configured) {
    # The cmdlet page: the authorization manager of a computer answers only its administrators and the members of its
    # group Access Control Assistance Operators. The error must name the denial; no access instead of an error would be
    # a wrong result.
    It 'Should write a GetEffectiveAccessError that names the denial with -ServerName, and no result' {
        $path = Get-LabPath -RelativePath 'Case5\Delegate\GetOwner'

        $result = @(Get-NTFSEffectiveAccess -Path $path -Account $configuration.Accounts.Delegate.Sid -ServerName $configuration.FileServerFqdn -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        $operationWarnings | Should -BeNullOrEmpty
        @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1
        $operationErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetEffectiveAccessError,*'
        $operationErrors[0].Exception.InnerException.NativeErrorCode | Should -Be 5
    }
}

Describe 'Get-NTFSOrphanedAccess with the entry of a deleted domain account on a share folder' -Tag 'Admin' -Skip:(-not $configured) {
    BeforeAll {
        $folder = Get-LabPath -RelativePath 'Case4\OrphanedAccess'
        $file = Join-Path -Path $folder -ChildPath 'File.txt'
        $orphan = $configuration.Accounts.Orphan.Sid
    }

    It 'Should return the entry of the deleted account with its SID' {
        $entries = @(Get-NTFSOrphanedAccess -Path $folder -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $operationWarnings | Should -BeNullOrEmpty
        $entries | Should -HaveCount 1
        $entries[0].Account.Sid | Should -Be $orphan
        $entries[0].Account.AccountName | Should -BeNullOrEmpty
        $entries[0].IsInherited | Should -BeFalse
    }

    It 'Should return the inherited entry for a file in the folder, and nothing with -ExcludeInherited' {
        $entries = @(Get-NTFSOrphanedAccess -Path $file -ErrorVariable operationErrors -ErrorAction SilentlyContinue)
        $explicitEntries = @(Get-NTFSOrphanedAccess -Path $file -ExcludeInherited -ErrorVariable +operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $entries | Should -HaveCount 1
        $entries[0].Account.Sid | Should -Be $orphan
        $entries[0].IsInherited | Should -BeTrue
        $explicitEntries | Should -BeNullOrEmpty
    }
}

Describe 'Paths longer than 260 characters on a share' -Tag 'Admin' -Skip:(-not $configured) {
    BeforeAll {
        $folder = Get-LabPath -RelativePath 'LongPath'
        $file = Join-Path -Path $folder -ChildPath $configuration.LongPath
    }

    It 'Get-ChildItem2 should return the file at the end of the long path' {
        $files = @(Get-ChildItem2 -Path $folder -Recurse -File -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $files | Should -HaveCount 1
        $files[0].FullName.Length | Should -BeGreaterThan 260
    }

    It 'Get-NTFSAccess should return the entries of that file' {
        $file.Length | Should -BeGreaterThan 260

        $entries = @(Get-NTFSAccess -Path $file -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $entries | Should -Not -BeNullOrEmpty
    }
}

Describe 'Copy-Item2 and Move-Item2 with -WhatIf onto an existing file on a share (#108)' -Tag 'Admin' -Skip:(-not $configured) {
    # Before 5.0.0-rc4, the cmdlets wrote an error with -WhatIf when the destination file existed.
    BeforeAll {
        $folder = Get-LabPath -RelativePath 'WhatIf'
        $source = Join-Path -Path $folder -ChildPath 'Source.txt'
        $destination = Join-Path -Path $folder -ChildPath 'Destination.txt'
    }

    It 'Copy-Item2 should write no error and leave the destination unchanged' {
        Copy-Item2 -Path $source -Destination $destination -WhatIf -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Get-Content -LiteralPath $destination -Raw | Should -Be 'Destination'
    }

    It 'Move-Item2 should write no error and leave both files unchanged' {
        Move-Item2 -Path $source -Destination $destination -WhatIf -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Get-Content -LiteralPath $source -Raw | Should -Be 'Source'
        Get-Content -LiteralPath $destination -Raw | Should -Be 'Destination'
    }
}

Describe 'Owner cmdlets on share folders' -Skip:(-not $configured) {
    # The file server decides: taking ownership needs the Take Ownership right, which Full Control includes, and
    # assigning another account needs the Restore privilege there. The folders start owned by Administrators.
    foreach ($ownerCase in $ownerCases) {
        Context 'As <Description>' -Tag $ownerCase.OwnerRole -ForEach @($ownerCase) {
            BeforeAll {
                $folder = Get-LabPath -RelativePath "Case5\$OwnerRole"
                $accountSid = $configuration.Accounts.$OwnerRole.Sid
            }

            It 'Get-NTFSOwner should return Administrators' {
                $owners = @(Get-NTFSOwner -Path (Join-Path -Path $folder -ChildPath 'GetOwner') -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                $owners | Should -HaveCount 1
                $owners[0].Owner.Sid | Should -Be $administrators
            }

            It 'Set-NTFSOwner should make the account itself the owner' {
                $path = Join-Path -Path $folder -ChildPath 'TakeOwnership'

                Set-NTFSOwner -Path $path -Account $accountSid -ErrorVariable operationErrors -ErrorAction SilentlyContinue

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                Get-LabOwner -Path $path | Should -Be $accountSid
            }

            It 'Set-NTFSOwner should assign another account only with the Restore privilege of the file server' {
                $path = Join-Path -Path $folder -ChildPath 'AssignOwner'

                Set-NTFSOwner -Path $path -Account $configuration.Accounts.Subject.Sid -ErrorVariable operationErrors -ErrorAction SilentlyContinue

                $written = (Format-LabError -ErrorRecord $operationErrors) -join ' | '
                if ($MayAssign) {
                    $written | Should -BeNullOrEmpty
                    Get-LabOwner -Path $path | Should -Be $configuration.Accounts.Subject.Sid
                }
                else {
                    @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1 -Because "the cmdlet wrote: $written"
                    $operationErrors[0].FullyQualifiedErrorId | Should -BeLike 'SetOwnerError,*'
                    Get-LabOwner -Path $path | Should -Be $administrators
                }
            }
        }
    }
}

Describe 'Audit inheritance cmdlets and Clear-NTFSAudit on share folders' -Skip:(-not $configured) {
    # The subfolders of Case6\<role> inherit one audit entry; the role Server checks the SACLs that the runs left.
    foreach ($auditCase in $auditSuccessCases) {
        Context 'As <Description>' -Tag $auditCase.AuditRole -ForEach @($auditCase) {
            BeforeAll {
                $folder = Get-LabPath -RelativePath "Case6\$AuditRole"
            }

            It 'Disable-NTFSAuditInheritance should protect the audit entries and keep the owner' {
                $path = Join-Path -Path $folder -ChildPath 'DisableAuditInheritance'

                Disable-NTFSAuditInheritance -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                Get-LabOwner -Path $path | Should -Be $administrators
                (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -BeFalse
            }

            It 'Enable-NTFSAuditInheritance should let the folder inherit the audit entries and keep the owner' {
                $path = Join-Path -Path $folder -ChildPath 'EnableAuditInheritance'

                Enable-NTFSAuditInheritance -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                Get-LabOwner -Path $path | Should -Be $administrators
                (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -BeTrue
            }

            It 'Clear-NTFSAudit should remove the explicit audit entry, keep the inherited one, and keep the owner' {
                $path = Join-Path -Path $folder -ChildPath 'ClearAudit'

                Clear-NTFSAudit -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                Get-LabOwner -Path $path | Should -Be $administrators
                @(Get-NTFSAudit -Path $path -ExcludeInherited) | Should -BeNullOrEmpty
                @(Get-NTFSAudit -Path $path -ExcludeExplicit) | Should -HaveCount 1
            }

            It 'Get-NTFSInheritance should report the protected DACL and the inherited audit entries' {
                $states = @(Get-NTFSInheritance -Path (Join-Path -Path $folder -ChildPath 'GetInheritance') -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

                Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
                $states | Should -HaveCount 1
                $states[0].AccessInheritanceEnabled | Should -BeFalse
                $states[0].AuditInheritanceEnabled | Should -BeTrue
            }
        }
    }

    Context 'As the delegated account, an administrator of the client only' -Tag 'Delegate' {
        BeforeAll {
            $folder = Get-LabPath -RelativePath 'Case6\Delegate'
        }

        It '<Command> should write a <ErrorId> that names the missing privilege and leave the folder unchanged' -ForEach @(
            @{ Command = 'Disable-NTFSAuditInheritance'; SubFolder = 'DisableAuditInheritance'; ErrorId = 'ModifySdError' }
            @{ Command = 'Enable-NTFSAuditInheritance'; SubFolder = 'EnableAuditInheritance'; ErrorId = 'ModifySdError' }
            @{ Command = 'Clear-NTFSAudit'; SubFolder = 'ClearAudit'; ErrorId = 'ClearAclError' }
        ) {
            $path = Join-Path -Path $folder -ChildPath $SubFolder
            $before = (Get-LabSecurityDescriptor -Path $path).GetSddlForm('All')

            & $Command -Path $path -ErrorVariable operationErrors -ErrorAction SilentlyContinue

            $written = (Format-LabError -ErrorRecord $operationErrors) -join ' | '
            (Get-LabSecurityDescriptor -Path $path).GetSddlForm('All') | Should -Be $before -Because "the cmdlet wrote: $written"
            @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1 -Because "the cmdlet wrote: $written"
            $operationErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
            $operationErrors[0].Exception.Message | Should -Match 'privilege'
        }

        # The cmdlet page: without the Security privilege, AuditInheritanceEnabled is $null and no error is written.
        It 'Get-NTFSInheritance should report the protected DACL, no audit state, and no error' {
            $states = @(Get-NTFSInheritance -Path (Join-Path -Path $folder -ChildPath 'GetInheritance') -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

            Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
            $states | Should -HaveCount 1
            $states[0].AccessInheritanceEnabled | Should -BeFalse
            $states[0].AuditInheritanceEnabled | Should -BeNullOrEmpty
        }
    }
}

Describe 'Item cmdlets on a share folder' -Tag 'Delegate' -Skip:(-not $configured) {
    # The delegated account fully controls the folder through its domain group.
    BeforeAll {
        $folder = Get-LabPath -RelativePath 'Case7\Items'
        $source = Join-Path -Path $folder -ChildPath 'Source.txt'
    }

    It 'Get-Item2 should return the file with its path on the share' {
        $item = @(Get-Item2 -Path $source -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $item | Should -HaveCount 1
        $item[0].FullName | Should -Be $source
        $item[0].Length | Should -Be 6
    }

    It 'Test-Path2 should find the file and the folder, and not a missing item' {
        Test-Path2 -Path $source -PathType Leaf | Should -BeTrue
        Test-Path2 -Path (Join-Path -Path $folder -ChildPath 'Folder') -PathType Container | Should -BeTrue
        Test-Path2 -Path (Join-Path -Path $folder -ChildPath 'Missing.txt') | Should -BeFalse
    }

    It 'Get-FileHash2 should return the hash that Get-FileHash returns' {
        $hash = @(Get-FileHash2 -Path $source -Algorithm SHA256 -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $hash | Should -HaveCount 1
        $hash[0].Hash | Should -Be (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    }

    It 'Copy-Item2 should copy a file, and a folder with its file' {
        Copy-Item2 -Path $source -Destination (Join-Path -Path $folder -ChildPath 'Copy.txt') -ErrorVariable operationErrors -ErrorAction SilentlyContinue
        Copy-Item2 -Path (Join-Path -Path $folder -ChildPath 'Folder') -Destination (Join-Path -Path $folder -ChildPath 'FolderCopy') -ErrorVariable +operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Get-Content -LiteralPath (Join-Path -Path $folder -ChildPath 'Copy.txt') -Raw | Should -Be 'Source'
        Get-Content -LiteralPath (Join-Path -Path $folder -ChildPath 'FolderCopy\File.txt') -Raw | Should -Be 'File'
        Get-Content -LiteralPath $source -Raw | Should -Be 'Source'
    }

    It 'Move-Item2 should move a file' {
        $moving = Join-Path -Path $folder -ChildPath 'Move.txt'

        Move-Item2 -Path $moving -Destination (Join-Path -Path $folder -ChildPath 'Moved.txt') -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Test-Path -LiteralPath $moving | Should -BeFalse
        Get-Content -LiteralPath (Join-Path -Path $folder -ChildPath 'Moved.txt') -Raw | Should -Be 'Move'
    }

    It 'Remove-Item2 should remove a file' {
        $removing = Join-Path -Path $folder -ChildPath 'Remove.txt'

        Remove-Item2 -Path $removing -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Test-Path -LiteralPath $removing | Should -BeFalse
    }

    It 'Get-ChildItem2 should list the file and the folder that the tests leave in place' {
        $names = @(Get-ChildItem2 -Path $folder -ErrorVariable operationErrors -ErrorAction SilentlyContinue).Name

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $names | Should -Contain 'Source.txt'
        $names | Should -Contain 'Folder'
    }
}

Describe 'Link cmdlets on a share folder' -Tag 'Admin' -Skip:(-not $configured) {
    BeforeAll {
        $folder = Get-LabPath -RelativePath 'Case8\Links'
        $target = Join-Path -Path $folder -ChildPath 'Target.txt'
        $hardLink = Join-Path -Path $folder -ChildPath 'HardLink.txt'
    }

    It 'New-NTFSHardLink should give the file a second name' {
        New-NTFSHardLink -Path $hardLink -Target $target -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Get-Content -LiteralPath $hardLink -Raw | Should -Be 'Target'
    }

    # The cmdlet pages: Windows can't list the names of a file on a share, so the cmdlets write a GetHardLinkError.
    It 'Get-NTFSHardLink should write a GetHardLinkError, because Windows cannot list the names on a share' {
        $links = @(Get-NTFSHardLink -Path $target -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        $links | Should -BeNullOrEmpty
        @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1
        $operationErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
    }

    It 'New-NTFSHardLink -PassThru should create the link and write a GetHardLinkError instead of the names' {
        $passThruLink = Join-Path -Path $folder -ChildPath 'PassThruLink.txt'

        $result = @(New-NTFSHardLink -Path $passThruLink -Target $target -PassThru -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        @(Format-LabError -ErrorRecord $operationErrors) | Should -HaveCount 1
        $operationErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
        Get-Content -LiteralPath $passThruLink -Raw | Should -Be 'Target'
    }

    It 'New-NTFSSymbolicLink should create a link to a file and a link to a folder' {
        New-NTFSSymbolicLink -Path (Join-Path -Path $folder -ChildPath 'FileLink.txt') -Target $target -ErrorVariable operationErrors -ErrorAction SilentlyContinue
        New-NTFSSymbolicLink -Path (Join-Path -Path $folder -ChildPath 'FolderLink') -Target (Join-Path -Path $folder -ChildPath 'TargetFolder') -ErrorVariable +operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
    }
}

Describe 'Get-NTFSSimpleAccess on share folders' -Tag 'Delegate' -Skip:(-not $configured) {
    It 'Should report the parent folder first and for the subfolder only the entry of its own' {
        $parent = Get-LabPath -RelativePath 'Case9\Simple'
        $child = Join-Path -Path $parent -ChildPath 'Child'

        $entries = @(Get-NTFSSimpleAccess -Path $child -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $entries | Should -Not -BeNullOrEmpty
        $entries[0].FullName | Should -Be $parent
        @($entries | Where-Object -Property FullName -EQ -Value $child).Identity.Sid | Should -Be $configuration.Accounts.Subject.Sid
    }
}

Describe 'Get-NTFSOrphanedAudit with the audit entry of a deleted domain account on a share folder' -Tag 'Admin' -Skip:(-not $configured) {
    It 'Should return the audit entry of the deleted account with its SID' {
        $entries = @(Get-NTFSOrphanedAudit -Path (Get-LabPath -RelativePath 'Case4\OrphanedAudit') -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $operationWarnings | Should -BeNullOrEmpty
        $entries | Should -HaveCount 1
        $entries[0].Account.Sid | Should -Be $configuration.Accounts.Orphan.Sid
    }
}

Describe 'Accounts of another domain and of other forests on share folders' -Tag 'Admin' -Skip:(-not $configured -or $foreignAccounts.Count -eq 0) {
    # Through the trusts, the client resolves the names of the accounts, and the file server creates their tokens.
    BeforeAll {
        $folder = Get-LabPath -RelativePath 'Case9\Foreign'
    }

    It 'Get-NTFSAccess should return the entry of <Name> with its name' -ForEach $foreignAccounts {
        $entries = @(Get-NTFSAccess -Path $folder -ExcludeInherited -ErrorVariable operationErrors -ErrorAction SilentlyContinue |
                Where-Object -FilterScript { $_.Account.Sid -eq $Sid })

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $entries | Should -HaveCount 1
        $entries[0].Account.AccountName | Should -Be $Name
    }

    It 'Get-NTFSOrphanedAccess should not report the entries of the accounts' {
        $entries = @(Get-NTFSOrphanedAccess -Path $folder -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $entries | Should -BeNullOrEmpty
    }

    It 'Add-NTFSAccess should add an entry for <Name> by its name' -ForEach $foreignAccounts {
        $path = Get-LabPath -RelativePath 'Case9\ForeignAdd'

        Add-NTFSAccess -Path $path -Account $Name -AccessRights ReadAndExecute -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        @(Get-LabExplicitAccessRule -Path $path -Sid $Sid) | Should -HaveCount 1
    }

    It 'Remove-NTFSAccess should remove the entry of <Name> by its name' -ForEach $foreignAccounts {
        $path = Get-LabPath -RelativePath 'Case9\ForeignRemove'

        Remove-NTFSAccess -Path $path -Account $Name -AccessRights ReadAndExecute -InheritanceFlags 'ContainerInherit, ObjectInherit' -PropagationFlags None -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Get-LabExplicitAccessRule -Path $path -Sid $Sid | Should -BeNullOrEmpty
    }

    It 'Get-NTFSEffectiveAccess should return the rights of <Name> on the file server with -ServerName, without a warning' -ForEach $foreignAccounts {
        $EffectiveRights | Should -BeGreaterThan 0 -Because 'the file server must create a token for the account to calculate the expected rights'

        $result = @(Get-NTFSEffectiveAccess -Path $folder -Account $Name -ServerName $configuration.FileServerFqdn -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $operationWarnings | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        Format-LabRight -Right $result[0].AccessRights | Should -Be (Format-LabRight -Right $EffectiveRights)
    }
}

Describe 'Security descriptors on the file server after the runs on the client' -Tag 'Server' -Skip:(-not $configured) {
    It 'Should keep Administrators as the owner of <Folder>' -ForEach $ownedFolders {
        Get-LabOwner -Path (Get-LabPath -RelativePath $Folder) | Should -Be $administrators
    }

    It 'Should have <Count> explicit audit entries on <Folder>' -ForEach $auditExpectations {
        $acl = Get-Acl -LiteralPath (Get-LabPath -RelativePath $Folder) -Audit

        @($acl.GetAuditRules($true, $false, $sidType)).Count | Should -Be $Count
    }

    It 'Should have the owner <Owner> on <Folder>' -ForEach $ownerExpectations {
        $expected = if ($Owner -eq 'Administrators') { $administrators } else { $configuration.Accounts.$Owner.Sid }

        Get-LabOwner -Path (Get-LabPath -RelativePath $Folder) | Should -Be $expected
    }

    It 'Should have <Explicit> explicit and <Inherited> inherited audit entries on <Folder>, protected: <Protected>' -ForEach $auditInheritanceExpectations {
        $acl = Get-Acl -LiteralPath (Get-LabPath -RelativePath $Folder) -Audit

        $acl.AreAuditRulesProtected | Should -Be $Protected
        @($acl.GetAuditRules($true, $false, $sidType)).Count | Should -Be $Explicit
        @($acl.GetAuditRules($false, $true, $sidType)).Count | Should -Be $Inherited
    }

    It 'Should have the items that the item cmdlets left' {
        $folder = Get-LabPath -RelativePath 'Case7\Items'

        foreach ($name in 'Source.txt', 'Copy.txt', 'Moved.txt', 'FolderCopy\File.txt') {
            Test-Path -LiteralPath (Join-Path -Path $folder -ChildPath $name) -PathType Leaf | Should -BeTrue -Because $name
        }

        foreach ($name in 'Move.txt', 'Remove.txt') {
            Test-Path -LiteralPath (Join-Path -Path $folder -ChildPath $name) | Should -BeFalse -Because $name
        }
    }

    It 'Should have the links that the link cmdlets created' {
        $folder = Get-LabPath -RelativePath 'Case8\Links'

        @(& fsutil.exe hardlink list (Join-Path -Path $folder -ChildPath 'Target.txt') | Where-Object -FilterScript { $_ }) | Should -HaveCount 3
        (Get-Item -LiteralPath (Join-Path -Path $folder -ChildPath 'FileLink.txt') -Force).LinkType | Should -Be 'SymbolicLink'
        (Get-Item -LiteralPath (Join-Path -Path $folder -ChildPath 'FolderLink') -Force).LinkType | Should -Be 'SymbolicLink'
    }

    It 'Should have the entry of <Name> that Add-NTFSAccess added, and not the one that Remove-NTFSAccess removed' -ForEach $foreignAccounts {
        @(Get-LabExplicitAccessRule -Path (Get-LabPath -RelativePath 'Case9\ForeignAdd') -Sid $Sid) | Should -HaveCount 1
        Get-LabExplicitAccessRule -Path (Get-LabPath -RelativePath 'Case9\ForeignRemove') -Sid $Sid | Should -BeNullOrEmpty
    }
}
