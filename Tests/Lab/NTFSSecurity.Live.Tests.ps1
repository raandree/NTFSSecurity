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
    # and warns that the result may be inaccurate.
    It 'Should fall back to the authorization manager of the client and warn when -ServerName can''t be reached' {
        $result = @(Get-NTFSEffectiveAccess -Path $path -Account $subject -ServerName $configuration.UnreachableServerName -WarningVariable operationWarnings -WarningAction SilentlyContinue -ErrorVariable operationErrors -ErrorAction SilentlyContinue)

        Format-LabError -ErrorRecord $operationErrors | Should -BeNullOrEmpty
        $operationWarnings.Message | Should -Contain ('The effective rights can only be computed based on group membership on this computer. ' +
            'For more accurate results, calculate effective access rights on the target computer')
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

Describe 'Security descriptors on the file server after the runs on the client' -Tag 'Server' -Skip:(-not $configured) {
    It 'Should keep Administrators as the owner of <Folder>' -ForEach $ownedFolders {
        Get-LabOwner -Path (Get-LabPath -RelativePath $Folder) | Should -Be $administrators
    }

    It 'Should have <Count> explicit audit entries on <Folder>' -ForEach $auditExpectations {
        $acl = Get-Acl -LiteralPath (Get-LabPath -RelativePath $Folder) -Audit

        @($acl.GetAuditRules($true, $false, $sidType)).Count | Should -Be $Count
    }
}
