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

    # Case 10: the cmdlets that a later command in the pipeline stops, and the roles whose items the file server checks.
    $laterCommandCases = @(
        foreach ($name in 'Remove-Item2', 'Copy-Item2', 'Move-Item2', 'Set-NTFSOwner', 'Set-NTFSSecurityDescriptor') {
            foreach ($style in 'Select-Object -First 1', 'throw') {
                @{ Name = $name; Style = $style }
            }
        }
    )
    $laterCommandStreamCases = @(
        foreach ($case in @(
                @{ Name = 'Set-NTFSSecurityDescriptor'; Stream = 'verbose' }
                @{ Name = 'Get-FileHash2'; Stream = 'verbose' }
                @{ Name = 'Set-NTFSOwner'; Stream = 'debug' }
            )) {
            foreach ($style in 'Select-Object -First 1', 'throw') {
                @{ Name = $case.Name; Stream = $case.Stream; Style = $style }
            }
        }
    )
    $laterCommandStates = @(
        foreach ($stateRole in 'Admin', 'ServerAdmin', 'Delegate') {
            @{ StateRole = $stateRole }
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

Describe 'Get-NTFSEffectiveAccess for a domain account as an account that is not an administrator of the client' -Tag 'ServerAdmin' -Skip:(-not $configured) {
    # The remote authorization manager of a computer answers only its administrators and the members of its group Access
    # Control Assistance Operators, and a computer in a domain offers it to every caller. Before 5.0.0-rc7, the cmdlet
    # wrote "Access is denied" for this computer, too, so the default -ServerName (localhost) failed for every user who
    # isn't an administrator of the client. Now the local authorization manager of the client answers, which is the
    # manager that the name asks for.
    BeforeAll {
        $path = Get-LabPath -RelativePath 'Case3\EffectiveAccess'
        $subject = $configuration.Accounts.Subject.Name
    }

    It 'Should return the rights through the domain groups without -ServerName, like for an administrator of the client' {
        $result = @(Get-NTFSEffectiveAccess -Path $path -Account $subject -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        Format-LabRight -Right $result[0].AccessRights | Should -Be (Format-LabRight -Right $configuration.EffectiveAccess.ClientRights)
    }

    It 'Should return the same rights without a warning for the name of the client' {
        $result = @(Get-NTFSEffectiveAccess -Path $path -Account $subject -ServerName $env:COMPUTERNAME -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        # The warning that the account doesn't hold the Security privilege is allowed; a warning about an unreachable computer isn't.
        ($operationWarnings.Message -join '|') | Should -Not -BeLike '*can''t be reached*'
        $result | Should -HaveCount 1
        Format-LabRight -Right $result[0].AccessRights | Should -Be (Format-LabRight -Right $configuration.EffectiveAccess.ClientRights)
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

    It 'Get-ChildItem2 -Hidden should include the first hidden file without explicit -Force over SMB' {
        $hiddenFolder = Get-LabPath -RelativePath 'Case7\Hidden'
        $hiddenFile = Join-Path -Path $hiddenFolder -ChildPath 'Only.txt'

        $result = @(Get-ChildItem2 -Path $hiddenFolder -Hidden -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $hiddenFile
        [System.IO.File]::GetAttributes($hiddenFile).HasFlag([System.IO.FileAttributes]::Hidden) | Should -BeTrue
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

# Case 10: the behavior that the fixes of the quality gate before 5.0.0 changed. Each test works in a folder of its role below
# Case10, which the delegated group fully controls, and fails on a build before the fix that its comment names.
Describe 'An item that the account owns and whose owner may not change its permissions on a share' -Tag 'Delegate' -Skip:(-not $configured) {
    # The delegated account owns what it creates on the share. A deny entry for OWNER RIGHTS replaces the right of the owner to
    # change the DACL, so the cmdlets take ownership for the write, which the file server answers by removing that entry. Once
    # the DACL is cleared and protected, nobody holds the right to set an owner. Before 5.0.0, the cmdlets set the previous
    # owner back also when it was the account itself: the file server refused it, and they reported a RestoreOwnerError for an
    # owner that had not changed.
    BeforeAll {
        $folder = Get-LabPath -RelativePath "Case10\$Role\Owner"
        $null = New-Item -ItemType Directory -Path $folder -Force
        $ownerRights = 'S-1-3-4'
        $protectedFlag = [System.Security.AccessControl.ControlFlags]::DiscretionaryAclProtected

        function New-LabUnchangeableFile {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to the folder of the run.'
            )]
            param ([string] $Name)

            $file = Join-Path -Path $folder -ChildPath $Name
            Set-Content -LiteralPath $file -Value $Name -NoNewline
            Get-LabOwner -Path $file | Should -Be $configuration.Accounts.$Role.Sid -Because 'the account owns what it creates'
            Add-NTFSAccess -Path $file -Account $ownerRights -AccessType Deny -AccessRights ChangePermissions -ErrorAction Stop
            # icacls reports the refusal on its error stream, which a terminating error action would turn into an exception
            $savedPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $null = & icacls.exe $file /grant '*S-1-1-0:(R)' 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $savedPreference
            }

            $exitCode | Should -Not -Be 0 -Because 'a plain write of the DACL fails for the owner now'
            $file
        }

        function Assert-LabClearedDescriptor {
            param ([string] $File)

            $descriptor = Get-LabSecurityDescriptor -Path $File
            $descriptor.Owner.Value | Should -Be $configuration.Accounts.$Role.Sid
            ($descriptor.ControlFlags -band $protectedFlag) | Should -Be $protectedFlag
            $null -ne $descriptor.DiscretionaryAcl | Should -BeTrue -Because 'the DACL is empty, not NULL'
            $descriptor.DiscretionaryAcl.Count | Should -Be 0
        }
    }

    It 'Clear-NTFSAccess -DisableInheritance should take ownership, clear and protect the DACL, and report no RestoreOwnerError' {
        $file = New-LabUnchangeableFile -Name 'Clear.txt'

        Clear-NTFSAccess -Path $file -DisableInheritance -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Assert-LabClearedDescriptor -File $file
    }

    It 'Set-NTFSSecurityDescriptor should write the cleared DACL and report no RestoreOwnerError' {
        $file = New-LabUnchangeableFile -Name 'Descriptor.txt'
        $descriptor = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop
        Clear-NTFSAccess -SecurityDescriptor $descriptor -DisableInheritance -ErrorAction Stop

        Set-NTFSSecurityDescriptor -SecurityDescriptor $descriptor -ErrorVariable operationErrors -ErrorAction SilentlyContinue

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        Assert-LabClearedDescriptor -File $file
    }
}

# Windows can't name the folders that the inherited entries of an item come from when the item is gone, for example deleted by
# another process after its security descriptor was read, or when a folder above it can't be read. The entries still come
# back. Before 5.0.0, the text lost its last character, and an explicit entry, which has no source, got it as well.
Describe 'InheritedFrom of access entries that Windows cannot resolve on a share' -Tag 'Delegate', 'ServerAdmin', 'Admin' -Skip:(-not $configured) {
    BeforeAll {
        $folder = Get-LabPath -RelativePath "Case10\$Role\InheritedFrom"
        $null = New-Item -ItemType Directory -Path $folder -Force
    }

    It 'Should name an unknown parent for an inherited entry and no source for an explicit entry when the file is gone' {
        $file = Join-Path -Path $folder -ChildPath 'Gone.txt'
        Set-Content -LiteralPath $file -Value 'Gone' -NoNewline
        Add-NTFSAccess -Path $file -Account $everyone -AccessRights ReadData -ErrorAction Stop
        $descriptor = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop
        Remove-Item -LiteralPath $file -Force

        $entries = @([Security2.FileSystemAccessRule2]::GetFileSystemAccessRules($descriptor, $true, $true, $true))

        $inherited = @($entries | Where-Object -FilterScript { $_.IsInherited })
        $inherited | Should -Not -BeNullOrEmpty
        foreach ($entry in $inherited) {
            $entry.InheritedFrom | Should -BeExactly 'unknown parent'
        }

        $explicit = @($entries | Where-Object -FilterScript { -not $_.IsInherited })
        $explicit | Should -HaveCount 1
        $explicit[0].InheritedFrom | Should -BeNullOrEmpty
    }
}

Describe 'InheritedFrom of audit entries that Windows cannot resolve on a share' -Tag 'ServerAdmin', 'Admin' -Skip:(-not $configured) {
    # The administrators of the file server read and change the audit entries over SMB (case 2).
    BeforeAll {
        $folder = Get-LabPath -RelativePath "Case10\$Role\InheritedFromAudit"
        $null = New-Item -ItemType Directory -Path $folder -Force
        Add-NTFSAudit -Path $folder -Account $everyone -AccessRights ReadData -InheritanceFlags 'ContainerInherit, ObjectInherit' -PropagationFlags None -ErrorAction Stop
    }

    It 'Should name an unknown parent for an inherited audit entry and no source for an explicit entry when the file is gone' {
        $file = Join-Path -Path $folder -ChildPath 'Gone.txt'
        Set-Content -LiteralPath $file -Value 'Gone' -NoNewline
        Add-NTFSAudit -Path $file -Account 'S-1-5-32-546' -AccessRights Delete -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
        $descriptor = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop
        Remove-Item -LiteralPath $file -Force

        $entries = @([Security2.FileSystemAuditRule2]::GetFileSystemAuditRules($descriptor, $true, $true, $true))

        $inherited = @($entries | Where-Object -FilterScript { $_.IsInherited })
        $inherited | Should -HaveCount 1
        $inherited[0].InheritedFrom | Should -BeExactly 'unknown parent'
        $explicit = @($entries | Where-Object -FilterScript { -not $_.IsInherited })
        $explicit | Should -HaveCount 1
        $explicit[0].InheritedFrom | Should -BeNullOrEmpty
    }
}

Describe 'InheritedFrom of an item below a folder on a share whose permissions the account cannot read' -Tag 'Delegate' -Skip:(-not $configured) {
    # Administrators own the folder, so a deny entry for the delegated account takes effect for it. The entry applies to the
    # folder only: the item below it keeps its entries and stays readable.
    BeforeAll {
        $locked = Get-LabPath -RelativePath 'Case10\Locked'
        $child = Join-Path -Path $locked -ChildPath 'Child.txt'
        Set-Content -LiteralPath $child -Value 'Child' -NoNewline
        Add-NTFSAccess -Path $child -Account $everyone -AccessRights ReadData -ErrorAction Stop
        Add-NTFSAccess -Path $locked -Account $configuration.Accounts.Delegate.Sid -AccessType Deny -AccessRights ReadPermissions -AppliesTo ThisFolderOnly -ErrorAction Stop
    }

    It 'Should start with a folder whose permissions the account cannot read, and an item that it can' {
        { Get-Acl -LiteralPath $locked -ErrorAction Stop } | Should -Throw
        { Get-Acl -LiteralPath $child -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Get-NTFSAccess should name an unknown parent for an inherited entry and no source for an explicit entry' {
        $entries = @(Get-NTFSAccess -Path $child -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $inherited = @($entries | Where-Object -FilterScript { $_.IsInherited })
        $inherited | Should -Not -BeNullOrEmpty
        foreach ($entry in $inherited) {
            $entry.InheritedFrom | Should -BeExactly 'unknown parent'
        }

        $explicit = @($entries | Where-Object -FilterScript { -not $_.IsInherited -and $_.Account.Sid -eq $everyone })
        $explicit | Should -HaveCount 1
        $explicit[0].InheritedFrom | Should -BeNullOrEmpty
    }
}

# Before 5.0.0, a cmdlet took what a later command ended the pipeline with (Select-Object -First, a break) or threw for a failure
# of the item and went on with the next item: Remove-Item2 removed every item after Select-Object -First 1, and the caller
# never saw a throw. Each case runs one command over two items and the file server checks the items afterwards (role Server).
Describe 'A later command that ends the pipeline or throws, for the item cmdlets on a share' -Tag 'Delegate', 'ServerAdmin', 'Admin' -Skip:(-not $configured) {
    BeforeAll {
        $account = $configuration.Accounts.$Role.Sid
        $caseRoot = Get-LabPath -RelativePath "Case10\$Role\LaterCommand"
        $privateData = (Get-Module -Name NTFSSecurity).PrivateData
        $savedEnablePrivileges = $privateData['EnablePrivileges']

        function Get-LabSlug {
            param ([string] $Style)

            if ($Style -eq 'throw') { 'Throw' } else { 'Select' }
        }

        function New-LabCaseFolder {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to the folder of the run.'
            )]
            param ([string] $Name)

            $path = Join-Path -Path $caseRoot -ChildPath $Name
            $null = New-Item -ItemType Directory -Path $path -Force
            $path
        }

        function New-LabPair {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to the folder of the run.'
            )]
            param ([string] $Name)

            $directory = New-LabCaseFolder -Name $Name
            foreach ($item in 'First', 'Second') {
                Set-Content -LiteralPath (Join-Path -Path $directory -ChildPath "$item.txt") -Value $item -NoNewline
            }

            @{
                Directory = $directory
                First     = (Join-Path -Path $directory -ChildPath 'First.txt')
                Second    = (Join-Path -Path $directory -ChildPath 'Second.txt')
            }
        }

        # Each case runs one command over the two items of its context. Untouched tells whether the second item is as it was,
        # which it is only when the command stopped after the first one.
        $cases = @{
            'Remove-Item2'               = @{
                Prepare   = { param ($Slug) New-LabPair -Name "RemoveItem2-$Slug" }
                Run       = { param ($Context) Remove-Item2 -Path $Context.First, $Context.Second -PassThru -ErrorAction SilentlyContinue }
                Untouched = { param ($Context) Test-Path -LiteralPath $Context.Second }
            }
            'Copy-Item2'                 = @{
                Prepare   = {
                    param ($Slug)
                    $context = New-LabPair -Name "CopyItem2-$Slug"
                    $context.Destination = New-LabCaseFolder -Name "CopyItem2-$Slug-To"
                    $context
                }
                Run       = { param ($Context) Copy-Item2 -Path $Context.First, $Context.Second -Destination $Context.Destination -PassThru $true -ErrorAction SilentlyContinue }
                Untouched = { param ($Context) -not (Test-Path -LiteralPath (Join-Path -Path $Context.Destination -ChildPath 'Second.txt')) }
            }
            'Move-Item2'                 = @{
                Prepare   = {
                    param ($Slug)
                    $context = New-LabPair -Name "MoveItem2-$Slug"
                    $context.Destination = New-LabCaseFolder -Name "MoveItem2-$Slug-To"
                    $context
                }
                Run       = { param ($Context) Move-Item2 -Path $Context.First, $Context.Second -Destination $Context.Destination -PassThru $true -ErrorAction SilentlyContinue }
                Untouched = { param ($Context) Test-Path -LiteralPath $Context.Second }
            }
            # The files of the fixture are owned by Administrators, so that the first one changes its owner.
            'Set-NTFSOwner'              = @{
                Prepare   = {
                    param ($Slug)
                    $directory = Join-Path -Path $caseRoot -ChildPath "SetOwner-$Slug"
                    @{ First = (Join-Path -Path $directory -ChildPath 'First.txt'); Second = (Join-Path -Path $directory -ChildPath 'Second.txt') }
                }
                Run       = { param ($Context) Set-NTFSOwner -Path $Context.First, $Context.Second -Account $account -PassThru -ErrorAction SilentlyContinue }
                Untouched = { param ($Context) (Get-LabOwner -Path $Context.Second) -eq $administrators }
            }
            'Set-NTFSSecurityDescriptor' = @{
                Prepare   = {
                    param ($Slug)
                    $context = New-LabPair -Name "SetDescriptor-$Slug"
                    $context.Descriptors = @(Get-NTFSSecurityDescriptor -Path $context.First, $context.Second -ErrorAction Stop)
                    Add-NTFSAccess -SecurityDescriptor $context.Descriptors -Account $everyone -AccessRights ReadData -ErrorAction Stop
                    $context
                }
                Run       = { param ($Context) Set-NTFSSecurityDescriptor -SecurityDescriptor $Context.Descriptors -PassThru -ErrorAction SilentlyContinue }
                Untouched = { param ($Context) -not (Get-LabExplicitAccessRule -Path $Context.Second -Sid $everyone) }
            }
        }

        # The command writes a verbose or a debug message inside the try of its loop, which the later command takes. With the
        # privileges enabled, the cmdlet writes a message before that, outside the try, so the module setting is off for these
        # cases. Get-FileHash2 skips the folder that comes first with a verbose message.
        $streamCases = @{
            'Set-NTFSSecurityDescriptor/verbose' = @{
                Prepare    = $cases['Set-NTFSSecurityDescriptor'].Prepare
                Run        = { param ($Context) Set-NTFSSecurityDescriptor -SecurityDescriptor $Context.Descriptors -Verbose -ErrorAction SilentlyContinue 4>&1 }
                Untouched  = $cases['Set-NTFSSecurityDescriptor'].Untouched
                RecordType = [System.Management.Automation.VerboseRecord]
            }
            'Get-FileHash2/verbose'              = @{
                Prepare    = {
                    param ($Slug)
                    @{
                        First = (New-LabCaseFolder -Name "FileHash2-$Slug-Folder")
                        File  = (New-LabPair -Name "FileHash2-$Slug").First
                    }
                }
                Run        = { param ($Context) Get-FileHash2 -Path $Context.First, $Context.File -Verbose -ErrorAction SilentlyContinue 4>&1 }
                RecordType = [System.Management.Automation.VerboseRecord]
            }
            'Set-NTFSOwner/debug'                = @{
                Prepare    = $cases['Set-NTFSOwner'].Prepare
                Run        = { param ($Context) Set-NTFSOwner -Path $Context.First, $Context.Second -Account $account -ErrorAction SilentlyContinue 5>&1 }
                Untouched  = $cases['Set-NTFSOwner'].Untouched
                RecordType = [System.Management.Automation.DebugRecord]
            }
        }

        function Assert-LabPipelineStop {
            param ([hashtable] $Case, [string] $Slug, [string] $Stream)

            if ($Stream -eq 'debug') { $DebugPreference = 'Continue' }
            $context = & $Case.Prepare $Slug
            $Error.Clear()

            $result = @(& $Case.Run $context | Select-Object -First 1)

            $result | Should -HaveCount 1
            if ($Case.RecordType) {
                $result[0] | Should -BeOfType $Case.RecordType
            }

            $Error.Count | Should -Be 0
            if ($Case.Untouched) {
                (& $Case.Untouched $context) | Should -BeTrue
            }
        }

        # A later command that throws ends the pipeline for the commands before it. The error is the caller's: the cmdlet must
        # neither report it as an error of an item nor go on with the next item.
        function Assert-LabDownstreamFailure {
            param ([hashtable] $Case, [string] $Slug, [string] $Stream)

            if ($Stream -eq 'debug') { $DebugPreference = 'Continue' }
            $context = & $Case.Prepare $Slug
            $emitted = 0
            $caught = $null
            $Error.Clear()
            try {
                & $Case.Run $context | ForEach-Object -Process {
                    $emitted++
                    throw 'Downstream failure'
                }
            }
            catch {
                $caught = $_
            }

            $caught.Exception.Message | Should -BeLike '*Downstream failure*'
            $emitted | Should -Be 1
            @($Error | Where-Object -FilterScript { $_.Exception.Message -notlike '*Downstream failure*' }) | Should -BeNullOrEmpty
            if ($Case.Untouched) {
                (& $Case.Untouched $context) | Should -BeTrue
            }
        }
    }

    It '<Name> should stop after the first object for <Style> and change nothing else' -ForEach $laterCommandCases {
        $slug = Get-LabSlug -Style $Style

        if ($Style -eq 'throw') {
            Assert-LabDownstreamFailure -Case $cases[$Name] -Slug $slug
        }
        else {
            Assert-LabPipelineStop -Case $cases[$Name] -Slug $slug
        }
    }

    Context 'With the messages of the verbose and debug streams' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $savedEnablePrivileges
        }

        It '<Name> should stop at the <Stream> message for <Style> and change nothing else' -ForEach $laterCommandStreamCases {
            $slug = '{0}{1}' -f [System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($Stream), (Get-LabSlug -Style $Style)

            if ($Style -eq 'throw') {
                Assert-LabDownstreamFailure -Case $streamCases["$Name/$Stream"] -Slug $slug -Stream $Stream
            }
            else {
                Assert-LabPipelineStop -Case $streamCases["$Name/$Stream"] -Slug $slug -Stream $Stream
            }
        }
    }
}

# The errors that Get-ChildItem2 writes for a folder that it cannot read reach a later command too, for example with 2>&1.
# Before 5.0.0, the recursion took what the later command threw for a failure of the folder above, and ended the listing.
Describe 'A later command and the error of a folder that Get-ChildItem2 cannot read on a share' -Tag 'Delegate' -Skip:(-not $configured) {
    BeforeAll {
        $errorTree = Get-LabPath -RelativePath "Case10\$Role\ErrorTree"
        $null = New-Item -ItemType Directory -Path $errorTree -Force
        $unreadable = foreach ($name in 'A', 'B') {
            $path = Join-Path -Path $errorTree -ChildPath $name
            $null = New-Item -ItemType Directory -Path $path
            # An entry for Everyone stops the delegated account, which isn't the file server's administrator
            Add-NTFSAccess -Path $path -Account $everyone -AccessType Deny -AccessRights ReadData -ErrorAction Stop
            $path
        }

        $readableFile = Join-Path -Path $errorTree -ChildPath 'C\Three.txt'
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $readableFile -Parent)
        Set-Content -LiteralPath $readableFile -Value 'Three' -NoNewline
    }

    It 'Should start with folders that the account cannot list' {
        foreach ($path in $unreadable) {
            { Get-ChildItem -LiteralPath $path -ErrorAction Stop } | Should -Throw
        }
    }

    It 'Should pass on what a later command throws when it takes the error of a nested folder' {
        $emitted = 0
        $caught = $null
        try {
            Get-ChildItem2 -Path $errorTree -Recurse -File -ErrorAction Continue 2>&1 | ForEach-Object -Process {
                $emitted++
                throw 'Downstream failure'
            }
        }
        catch {
            $caught = $_
        }

        $caught.Exception.Message | Should -BeLike '*Downstream failure*'
        $emitted | Should -Be 1
    }

    It 'Should leave the loop for a break of a later command that takes the error of a nested folder' {
        $emitted = 0
        $reachedEnd = $false
        foreach ($round in 1) {
            Get-ChildItem2 -Path $errorTree -Recurse -File -ErrorAction Continue 2>&1 | ForEach-Object -Process {
                $emitted++
                break
            }

            $reachedEnd = $true
        }

        $emitted | Should -Be 1
        $reachedEnd | Should -BeFalse
    }
}

# Only * and ? are wildcards in -Filter, and the pattern *.* selects every item, as it does for Windows and Get-ChildItem.
Describe 'Get-ChildItem2 -Filter on a share folder' -Tag 'Delegate', 'ServerAdmin', 'Admin' -Skip:(-not $configured) {
    BeforeAll {
        $folder = Get-LabPath -RelativePath "Case10\$Role\Filter"
        $null = New-Item -ItemType Directory -Path $folder -Force
        $names = 'Report[1].txt', 'Report1.txt', 'Page.htm', 'NoExtension'
        foreach ($name in $names) {
            Set-Content -LiteralPath (Join-Path -Path $folder -ChildPath $name) -Value $name -NoNewline
        }

        $null = New-Item -ItemType Directory -Path (Join-Path -Path $folder -ChildPath 'NoExtensionFolder')
    }

    # Before 5.0.0, the cmdlet read [1] as a character class and returned nothing.
    It 'Should find a file whose name contains brackets by that name with -Filter' {
        $result = @(Get-ChildItem2 -Path $folder -Filter 'Report[1].txt' -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        $result[0].Name | Should -BeExactly 'Report[1].txt'
    }

    # Before 5.0.0, the cmdlet compared each name with the pattern again and dropped the items without a dot in their names,
    # files and folders alike.
    It 'Should return every item for -Filter *.*, also the ones without a dot in their names' {
        $result = @(Get-ChildItem2 -Path $folder -Filter '*.*' -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $expected = @($names) + 'NoExtensionFolder'
        (@($result.Name) | Sort-Object) -join ',' | Should -BeExactly (($expected | Sort-Object) -join ',')
    }

    # A null value used to end in a NullReferenceException of the cmdlet.
    It 'Should reject a null -Filter' {
        { Get-ChildItem2 -Path $folder -Filter $null -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,NTFSSecurity.GetChildItem2' -ExpectedMessage "*'Filter'*"
    }
}

Describe 'Privileges when a later command takes the debug messages of the cmdlet on a share' -Tag 'Delegate', 'Admin' -Skip:(-not $configured) {
    # The two roles are administrators of the client, so the cmdlets enable privileges there. Before 5.0.0, a later command that
    # ended the pipeline or threw at the message after the enabling left a privilege enabled in the session: the cmdlet had not
    # noted yet that it enabled it, so nothing disabled it, and a throw was taken for a failure to enable the privilege.
    BeforeAll {
        $privateData = (Get-Module -Name NTFSSecurity).PrivateData
        $savedEnablePrivileges = $privateData['EnablePrivileges']
        $privateData['EnablePrivileges'] = $true
        $debugFolder = Get-LabPath -RelativePath "Case10\$Role\Privileges"
        $null = New-Item -ItemType Directory -Path $debugFolder -Force

        function Get-LabEnabledFileSystemPrivilege {
            # The names of the privileges that the cmdlets enable, as far as they are enabled now
            @(Get-Privileges | Where-Object -FilterScript {
                    $_.Privilege -in 'TakeOwnership', 'Restore', 'Backup', 'Security' -and $_.PrivilegeState -eq 'Enabled'
                } | ForEach-Object -Process { $_.Privilege.ToString() })
        }
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $savedEnablePrivileges
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    BeforeEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    AfterEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    It 'Should hold the four privileges that the cmdlets enable' {
        @(Get-Privileges | Where-Object -FilterScript { $_.Privilege -in 'TakeOwnership', 'Restore', 'Backup', 'Security' }) | Should -HaveCount 4
    }

    It 'Should disable the privilege when Select-Object -First ends the pipeline at the message after its enabling' {
        $DebugPreference = 'Continue'
        $messages = @(Get-NTFSOwner -Path $debugFolder 5>&1 | ForEach-Object -Process { $_.Message })
        $enabledAt = $messages.IndexOf('..enabled') + 1
        $enabledAt | Should -BeGreaterThan 0
        Get-LabEnabledFileSystemPrivilege | Should -BeNullOrEmpty

        $result = @(Get-NTFSOwner -Path $debugFolder 5>&1 | Select-Object -First $enabledAt)

        $result | Should -HaveCount $enabledAt
        $result[-1].Message | Should -BeExactly '..enabled'
        Get-LabEnabledFileSystemPrivilege | Should -BeNullOrEmpty
    }

    It 'Should pass on what a later command throws at the message after the enabling and disable the privileges' {
        $DebugPreference = 'Continue'
        $caught = $null
        try {
            Get-NTFSOwner -Path $debugFolder 5>&1 | ForEach-Object -Process {
                if ($_.Message -eq '..enabled') { throw 'Downstream failure' }
                $_
            } | Out-Null
        }
        catch {
            $caught = $_
        }

        $caught.Exception.Message | Should -BeLike '*Downstream failure*'
        Get-LabEnabledFileSystemPrivilege | Should -BeNullOrEmpty
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

    It 'Should retain the hidden file and its attribute after the client listing' {
        $hiddenFile = Get-LabPath -RelativePath 'Case7\Hidden\Only.txt'

        Get-Content -LiteralPath $hiddenFile -Raw | Should -BeExactly 'Hidden'
        [System.IO.File]::GetAttributes($hiddenFile).HasFlag([System.IO.FileAttributes]::Hidden) | Should -BeTrue
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

    # Case 10: a later command stopped each cmdlet after its first item. The first item changed, the second is as it was.
    It 'Should have changed only the first item of <StateRole> for each cmdlet that a later command stopped' -ForEach $laterCommandStates {
        $root = Get-LabPath -RelativePath "Case10\$StateRole\LaterCommand"
        $account = $configuration.Accounts.$StateRole.Sid

        foreach ($slug in 'Select', 'Throw') {
            $removed = Join-Path -Path $root -ChildPath "RemoveItem2-$slug"
            Test-Path -LiteralPath (Join-Path -Path $removed -ChildPath 'First.txt') | Should -BeFalse -Because "Remove-Item2 removed the first item ($slug)"
            Test-Path -LiteralPath (Join-Path -Path $removed -ChildPath 'Second.txt') | Should -BeTrue -Because "Remove-Item2 left the second item ($slug)"

            $copied = Join-Path -Path $root -ChildPath "CopyItem2-$slug-To"
            Test-Path -LiteralPath (Join-Path -Path $copied -ChildPath 'First.txt') | Should -BeTrue -Because "Copy-Item2 copied the first item ($slug)"
            Test-Path -LiteralPath (Join-Path -Path $copied -ChildPath 'Second.txt') | Should -BeFalse -Because "Copy-Item2 left the second item ($slug)"

            $moved = Join-Path -Path $root -ChildPath "MoveItem2-$slug"
            Test-Path -LiteralPath (Join-Path -Path $moved -ChildPath 'First.txt') | Should -BeFalse -Because "Move-Item2 moved the first item ($slug)"
            Test-Path -LiteralPath (Join-Path -Path $moved -ChildPath 'Second.txt') | Should -BeTrue -Because "Move-Item2 left the second item ($slug)"
            Test-Path -LiteralPath (Join-Path -Path $root -ChildPath "MoveItem2-$slug-To\First.txt") | Should -BeTrue -Because "Move-Item2 moved the first item ($slug)"
            Test-Path -LiteralPath (Join-Path -Path $root -ChildPath "MoveItem2-$slug-To\Second.txt") | Should -BeFalse -Because "Move-Item2 left the second item ($slug)"

            $owned = Join-Path -Path $root -ChildPath "SetOwner-$slug"
            Get-LabOwner -Path (Join-Path -Path $owned -ChildPath 'First.txt') | Should -Be $account -Because "Set-NTFSOwner changed the first item ($slug)"
            Get-LabOwner -Path (Join-Path -Path $owned -ChildPath 'Second.txt') | Should -Be $administrators -Because "Set-NTFSOwner left the second item ($slug)"

            # The messages come before the change of an item, so the first item may still be as it was.
            $ownedAtDebug = Join-Path -Path $root -ChildPath "SetOwner-Debug$slug"
            Get-LabOwner -Path (Join-Path -Path $ownedAtDebug -ChildPath 'Second.txt') | Should -Be $administrators -Because "Set-NTFSOwner left the second item at the debug message ($slug)"

            $written = Join-Path -Path $root -ChildPath "SetDescriptor-$slug"
            @(Get-LabExplicitAccessRule -Path (Join-Path -Path $written -ChildPath 'First.txt') -Sid $everyone) | Should -HaveCount 1 -Because "Set-NTFSSecurityDescriptor wrote the first descriptor ($slug)"
            Get-LabExplicitAccessRule -Path (Join-Path -Path $written -ChildPath 'Second.txt') -Sid $everyone | Should -BeNullOrEmpty -Because "Set-NTFSSecurityDescriptor left the second item ($slug)"
            $writtenAtVerbose = Join-Path -Path $root -ChildPath "SetDescriptor-Verbose$slug"
            Get-LabExplicitAccessRule -Path (Join-Path -Path $writtenAtVerbose -ChildPath 'Second.txt') -Sid $everyone | Should -BeNullOrEmpty -Because "Set-NTFSSecurityDescriptor left the second item at the verbose message ($slug)"
        }
    }
}
