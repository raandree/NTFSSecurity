<#
    Closes TestNeeded gaps of the judged parameter-set matrix (judged-inheritance.csv / judged-inheritance-notes.md,
    scanned at HEAD 6696f68) for the inheritance, owner, and security-descriptor cmdlets: Disable/Enable-NTFSAccessInheritance,
    Disable/Enable-NTFSAuditInheritance, Get/Set-NTFSInheritance, Get/Set-NTFSOwner, Get-NTFSSecurityDescriptor. The module
    built in NTFSSecurity\bin\Release runs on files and folders in a sandbox folder. Every assertion reads state with .NET
    (Get-Acl, Get-Acl -Audit) or compares an independent oracle, asserts an ErrorId/category/target triple, exercises a
    pipeline that no existing test used, or checks continuation to the next item/descriptor; none of it repeats what
    Inheritance.Tests.ps1, Owner.Tests.ps1, SecurityDescriptor.Tests.ps1, SecurityDescriptorSets.Tests.ps1, or
    PathErrors.Tests.ps1 already assert. Tests that change or read the audit section need the Security privilege and skip
    without it; CI runs them elevated too. This file does not test the 17 shared owner-restore handlers against what a
    later command raises there (an open maintainer decision, see systemPatterns.md), the abandoned PrivilegeEnabler, or
    any Decision 22 behavior, and it does not add a new gap test for Set-NTFSSecurityDescriptor, whose own row is judged
    GapKind None.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canChangeAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    $holdsRestorePrivilege = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
    $canBypassDeny = Test-PrivilegeHeld -Name 'SeBackupPrivilege'

    # State: file/folder x Enable(Disable=false/Enable=true) x Remove, read back with Get-Acl, not with Get-NTFSAccess.
    $accessOracleCases = @(foreach ($type in 'file', 'folder') {
            foreach ($enable in $false, $true) {
                foreach ($remove in $false, $true) {
                    @{ Type = $type; Enable = $enable; Remove = $remove }
                }
            }
        })

    # State: the same transitions for the SACL, read back with Get-Acl -Audit, not with Get-NTFSAudit/Get-NTFSInheritance.
    $auditOracleCases = @(foreach ($type in 'file', 'folder') {
            foreach ($enable in $false, $true) {
                foreach ($remove in $false, $true) {
                    @{ Type = $type; Enable = $enable; Remove = $remove }
                }
            }
        })

    # State: the -RemoveInheritedAccessRules/-RemoveExplicitAccessRules switches with a -SecurityDescriptor, which
    # SecurityDescriptorSets.Tests.ps1 covers only without the switch (Disable) or without any explicit entry (Enable).
    $sdAccessSwitchCases = @(
        @{ Command = 'Disable-NTFSAccessInheritance'; SwitchName = 'RemoveInheritedAccessRules'; Remove = $true }
        @{ Command = 'Enable-NTFSAccessInheritance'; SwitchName = 'RemoveExplicitAccessRules'; Remove = $false }
        @{ Command = 'Enable-NTFSAccessInheritance'; SwitchName = 'RemoveExplicitAccessRules'; Remove = $true }
    )

    # Error: a fully denied write with -PassThru, asserting the category and the next item's new state together (S1).
    $deniedWriteCases = @(
        @{ Command = 'Disable-NTFSAccessInheritance'; Parameters = @{}; ErrorId = 'ModifySdError'; PreDisable = $false; ExpectedFlag = $false }
        @{ Command = 'Enable-NTFSAccessInheritance'; Parameters = @{}; ErrorId = 'ModifySdError'; PreDisable = $true; ExpectedFlag = $true }
        @{ Command = 'Set-NTFSInheritance'; Parameters = @{ AccessInheritanceEnabled = $false }; ErrorId = 'ModifySdError'; PreDisable = $false; ExpectedFlag = $false }
    )

    # Error: RestoreOwnerError of these three Path cmdlets, none of which has a test for it today (S3).
    $restoreOwnerCases = @(
        @{ Command = 'Disable-NTFSAccessInheritance'; Parameters = @{}; PreDisable = $false; ExpectedProtected = $true }
        @{ Command = 'Enable-NTFSAccessInheritance'; Parameters = @{}; PreDisable = $true; ExpectedProtected = $false }
        @{ Command = 'Set-NTFSInheritance'; Parameters = @{ AccessInheritanceEnabled = $false }; PreDisable = $false; ExpectedProtected = $true }
    )

    # Error: a missing path, asserting the OpenError category and exactly one object for the next path (S1 + S6).
    $missingPathOpenErrorCases = @(
        @{ Command = 'Get-NTFSInheritance'; ErrorId = 'ReadFileError' }
        @{ Command = 'Get-NTFSSecurityDescriptor'; ErrorId = 'ReadFileError' }
    )

    # Error: Set-NTFSOwner id/category/target together, for a missing path and for a refused owner (S1 + S6).
    $setOwnerErrorCases = @(
        @{ Scenario = 'Missing'; ErrorId = 'ReadFileError'; Category = 'OpenError' }
        @{ Scenario = 'Refused'; ErrorId = 'SetOwnerError'; Category = 'WriteError' }
    )

    # Pipeline: Get-ChildItem2 piped into the four Path-set inheritance cmdlets with -PassThru, access and audit.
    $pipedInheritanceCases = @(
        @{ Command = 'Disable-NTFSAccessInheritance'; Scope = 'access'; PreDisable = $false; Expected = $false }
        @{ Command = 'Enable-NTFSAccessInheritance'; Scope = 'access'; PreDisable = $true; Expected = $true }
        @{ Command = 'Disable-NTFSAuditInheritance'; Scope = 'audit'; PreDisable = $false; Expected = $false }
        @{ Command = 'Enable-NTFSAuditInheritance'; Scope = 'audit'; PreDisable = $true; Expected = $true }
    )

    # Pipeline: two security descriptors piped into the four SecurityDescriptor-set inheritance cmdlets.
    $pipedInheritanceSdCases = @(
        @{ Command = 'Disable-NTFSAccessInheritance'; Scope = 'access'; PreDisable = $false; Expected = $false }
        @{ Command = 'Enable-NTFSAccessInheritance'; Scope = 'access'; PreDisable = $true; Expected = $true }
        @{ Command = 'Disable-NTFSAuditInheritance'; Scope = 'audit'; PreDisable = $false; Expected = $false }
        @{ Command = 'Enable-NTFSAuditInheritance'; Scope = 'audit'; PreDisable = $true; Expected = $true }
    )
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'ParameterSetsInheritance'
    Push-Location -LiteralPath $sandbox

    $sidType = [System.Security.Principal.SecurityIdentifier]
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    # An owner that the user can assign only with the Restore privilege
    $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']
    # Recomputed here (not only in BeforeDiscovery): an It body runs in the Run phase, which does not see
    # BeforeDiscovery variables, and the two piped-inheritance tests need this flag inside the body, not only in -Skip.
    $canChangeAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    $holdsRestorePrivilege = Test-PrivilegeHeld -Name 'SeRestorePrivilege'

    function Get-TestAcl {
        # .NET, because Get-Acl of an elevated Windows PowerShell reads also items that deny reading their permissions.
        # .NET Core has the method as an extension method. Matches the helper of PathErrors.Tests.ps1.
        param ([string] $Path)

        $info = New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $Path
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            $info.GetAccessControl()
        }
        else {
            [System.IO.FileSystemAclExtensions]::GetAccessControl($info)
        }
    }

    function Get-TestAuditAcl {
        # The SACL read alone, through .NET. Get-Acl -Audit reads it together with the other sections, and on a domain
        # member that reports the SACL of an item without audit entries as protected from inheritance, which is not its
        # state (see Security2\FileSystem\FileSystemSecurity2.cs). Matches the helper of ParameterSets.Audit.Tests.ps1.
        param ([string] $Path)

        $sections = [System.Security.AccessControl.AccessControlSections]::Audit
        $info = if (Test-Path -LiteralPath $Path -PathType Container) {
            New-Object -TypeName 'System.IO.DirectoryInfo' -ArgumentList $Path
        }
        else {
            New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $Path
        }
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            $info.GetAccessControl($sections)
        }
        else {
            [System.IO.FileSystemAclExtensions]::GetAccessControl($info, $sections)
        }
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'State: independent .NET oracles for inheritance transitions and descriptor-only changes' {
    It 'Should set the DACL protected flag to <Enable> and the explicit/inherited rule counts for -Remove=<Remove> on a <Type>, read with Get-Acl' -ForEach $accessOracleCases {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'AccessOracleParent' -Directory
        $path = Join-Path -Path $parent -ChildPath 'Child'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        $parentAccount = 'S-1-5-21-1-2-3-4921'
        $childAccount = 'S-1-5-21-1-2-3-4922'
        Add-NTFSAccess -Path $parent -Account $parentAccount -AccessRights ReadData -ErrorAction Stop
        if ($Type -eq 'folder') { New-Item -ItemType Directory -Path $path | Out-Null } else { Set-Content -LiteralPath $path -Value 'Child' }
        Add-NTFSAccess -Path $path -Account $childAccount -AccessRights Delete -AppliesTo ThisFolderOnly -ErrorAction Stop
        $inheritedBefore = @((Get-Acl -LiteralPath $path).GetAccessRules($false, $true, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $parentAccount })
        $inheritedBefore | Should -HaveCount 1
        if ($Enable) {
            Disable-NTFSAccessInheritance -Path $path -RemoveInheritedAccessRules -ErrorAction Stop
            $parameters = @{ RemoveExplicitAccessRules = $Remove }
            $command = 'Enable-NTFSAccessInheritance'
        }
        else {
            $parameters = @{ RemoveInheritedAccessRules = $Remove }
            $command = 'Disable-NTFSAccessInheritance'
        }

        & $command -Path $path @parameters -ErrorAction Stop

        $acl = Get-Acl -LiteralPath $path
        $acl.AreAccessRulesProtected | Should -Be (-not $Enable)
        $parentRules = @($acl.GetAccessRules($true, $true, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $parentAccount })
        if ($Enable) {
            $parentRules | Should -HaveCount 1
            $parentRules[0].IsInherited | Should -BeTrue
        }
        elseif ($Remove) {
            $parentRules | Should -BeNullOrEmpty
        }
        else {
            $parentRules | Should -HaveCount 1
            $parentRules[0].IsInherited | Should -BeFalse
        }
        $childRules = @($acl.GetAccessRules($true, $true, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $childAccount })
        if ($Enable -and $Remove) { $childRules | Should -BeNullOrEmpty } else { $childRules | Should -HaveCount 1 }
    }

    It 'Should set the SACL protected flag to <Enable> and the explicit/inherited audit-rule counts for -Remove=<Remove> on a <Type>, read with Get-Acl -Audit' -Skip:(-not $canChangeAudit) -ForEach $auditOracleCases {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditOracleParent' -Directory
        $path = Join-Path -Path $parent -ChildPath 'Child'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        $parentAccount = 'S-1-5-21-1-2-3-4931'
        $childAccount = 'S-1-5-21-1-2-3-4932'
        Add-NTFSAudit -Path $parent -Account $parentAccount -AccessRights ReadData -AuditFlags Success -ErrorAction Stop
        if ($Type -eq 'folder') { New-Item -ItemType Directory -Path $path | Out-Null } else { Set-Content -LiteralPath $path -Value 'Child' }
        Add-NTFSAudit -Path $path -Account $childAccount -AccessRights Delete -AuditFlags Failure -AppliesTo ThisFolderOnly -ErrorAction Stop
        $inheritedBefore = @((Get-Acl -LiteralPath $path -Audit).GetAuditRules($false, $true, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $parentAccount })
        $inheritedBefore | Should -HaveCount 1
        $daclBefore = (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access')
        if ($Enable) {
            Disable-NTFSAuditInheritance -Path $path -RemoveInheritedAuditRules -ErrorAction Stop
            $parameters = @{ RemoveExplicitAuditRules = $Remove }
            $command = 'Enable-NTFSAuditInheritance'
        }
        else {
            $parameters = @{ RemoveInheritedAuditRules = $Remove }
            $command = 'Disable-NTFSAuditInheritance'
        }

        & $command -Path $path @parameters -ErrorAction Stop

        $acl = Get-Acl -LiteralPath $path -Audit
        $acl.AreAuditRulesProtected | Should -Be (-not $Enable)
        $parentRules = @($acl.GetAuditRules($true, $true, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $parentAccount })
        if ($Enable) {
            $parentRules | Should -HaveCount 1
            $parentRules[0].IsInherited | Should -BeTrue
        }
        elseif ($Remove) {
            $parentRules | Should -BeNullOrEmpty
        }
        else {
            $parentRules | Should -HaveCount 1
            $parentRules[0].IsInherited | Should -BeFalse
        }
        $childRules = @($acl.GetAuditRules($true, $true, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $childAccount })
        if ($Enable -and $Remove) { $childRules | Should -BeNullOrEmpty } else { $childRules | Should -HaveCount 1 }
        (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $daclBefore
    }

    It '<Command> -SecurityDescriptor should change the in-memory access entries per -<SwitchName>:<Remove>, applied to the item only after Set-NTFSSecurityDescriptor writes it' -ForEach $sdAccessSwitchCases {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'SdSwitchParent' -Directory
        $file = Join-Path -Path $parent -ChildPath 'Child'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        Add-NTFSAccess -Path $parent -Account 'S-1-5-21-1-2-3-4941' -AccessRights ReadData -ErrorAction Stop
        Set-Content -LiteralPath $file -Value 'Child'
        if ($Command -eq 'Enable-NTFSAccessInheritance') {
            Add-NTFSAccess -Path $file -Account 'S-1-5-21-1-2-3-4942' -AccessRights Delete -AppliesTo ThisFolderOnly -ErrorAction Stop
            Disable-NTFSAccessInheritance -Path $file -RemoveInheritedAccessRules -ErrorAction Stop
        }
        $before = (Get-Acl -LiteralPath $file).Sddl
        $sd = Get-NTFSSecurityDescriptor -Path $file
        $switchParameters = @{ $SwitchName = $Remove }

        & $Command -SecurityDescriptor $sd @switchParameters -ErrorAction Stop

        $sd.SecurityDescriptor.AreAccessRulesProtected | Should -Be ($Command -eq 'Disable-NTFSAccessInheritance')
        (Get-Acl -LiteralPath $file).Sddl | Should -BeExactly $before

        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop

        $acl = Get-Acl -LiteralPath $file
        if ($Command -eq 'Disable-NTFSAccessInheritance') {
            $acl.AreAccessRulesProtected | Should -BeTrue
            $inherited = @($acl.GetAccessRules($false, $true, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-4941' })
            $explicitCopy = @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-4941' })
            if ($Remove) {
                $inherited | Should -BeNullOrEmpty
                $explicitCopy | Should -BeNullOrEmpty
            }
            else {
                $explicitCopy | Should -HaveCount 1
            }
        }
        else {
            $acl.AreAccessRulesProtected | Should -BeFalse
            $explicitChild = @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-4942' })
            if ($Remove) { $explicitChild | Should -BeNullOrEmpty } else { $explicitChild | Should -HaveCount 1 }
        }
    }

    It 'Set-NTFSInheritance -SecurityDescriptor should set both inheritance flags in one call, changing only the in-memory descriptor until it is written' -Skip:(-not $canChangeAudit) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorBothFlags'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        $daclBefore = (Get-Acl -LiteralPath $file).Sddl
        $sd = Get-NTFSSecurityDescriptor -Path $file

        $result = @(Set-NTFSInheritance -SecurityDescriptor $sd -AccessInheritanceEnabled $false -AuditInheritanceEnabled $false -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].AccessInheritanceEnabled | Should -BeFalse
        $result[0].AuditInheritanceEnabled | Should -BeFalse
        $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeTrue
        $sd.SecurityDescriptor.AreAuditRulesProtected | Should -BeTrue
        (Get-Acl -LiteralPath $file).Sddl | Should -BeExactly $daclBefore

        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop

        (Get-Acl -LiteralPath $file).AreAccessRulesProtected | Should -BeTrue
        (Get-TestAuditAcl -Path $file).AreAuditRulesProtected | Should -BeTrue
    }

    It 'Set-NTFSOwner should change only the owner and leave the Access entries and the group unchanged' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OwnerOnlyChange'
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
        $before = Get-Acl -LiteralPath $file
        if ($before.GetOwner($sidType).Value -eq $currentUser) {
            Set-ItResult -Skipped -Because 'the user already owns new items, so Set-NTFSOwner would not change the owner'
            return
        }
        $accessBefore = $before.GetSecurityDescriptorSddlForm('Access')
        $groupBefore = $before.GetGroup($sidType).Value

        $result = @(Set-NTFSOwner -Path $file -Account $currentUser -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType ([Security2.FileSystemOwner])
        $result[0].Owner.Sid | Should -Be $currentUser
        $after = Get-Acl -LiteralPath $file
        $after.GetOwner($sidType).Value | Should -Be $currentUser
        $after.GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $accessBefore
        $after.GetGroup($sidType).Value | Should -Be $groupBefore
    }
}

Describe 'Errors: categories, targets, and continuation of the inheritance and owner cmdlets' {
    Context 'A denied write, with and without a restorable owner' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It '<Command> should report <ErrorId> with category WriteError and target for the denied item, and still return the next item''s new state with -PassThru' -ForEach $deniedWriteCases {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'DeniedWriteBlocked'
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'DeniedWriteNext'
            if ($PreDisable) {
                Disable-NTFSAccessInheritance -Path $blocked, $next -ErrorAction Stop
            }
            Block-TestWritePermission -Sandbox $sandbox -Path $blocked
            $before = (Get-Acl -LiteralPath $blocked).Sddl

            $result = @(& $Command -Path $blocked, $next @Parameters -PassThru -ErrorVariable changeErrors -ErrorAction SilentlyContinue)

            $changeErrors | Should -HaveCount 1
            $changeErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
            $changeErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $changeErrors[0].TargetObject | Should -Be $blocked
            (Get-Acl -LiteralPath $blocked).Sddl | Should -BeExactly $before
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $next
            $result[0].AccessInheritanceEnabled | Should -Be $ExpectedFlag
        }

        It '<Command> should report RestoreOwnerError after a successful ownership retry and continue with the next path' -Skip:(-not $holdsRestorePrivilege) -ForEach $restoreOwnerCases {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'RestoreOwnerBlocked'
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'RestoreOwnerNext'
            if ($PreDisable) {
                Disable-NTFSAccessInheritance -Path $blocked, $next -ErrorAction Stop
            }
            $user = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $user = 'ChangePermissions' }
            Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
            (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState | Should -Be 'Disabled'

            & $Command -Path $blocked, $next @Parameters -ErrorVariable changeErrors -ErrorAction SilentlyContinue

            $changeErrors | Should -HaveCount 1
            $changeErrors[0].FullyQualifiedErrorId | Should -BeLike 'RestoreOwnerError,*'
            $changeErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $changeErrors[0].TargetObject | Should -Be $blocked
            (Get-TestAcl -Path $blocked).GetOwner($sidType).Value | Should -Be $user
            (Get-TestAcl -Path $blocked).AreAccessRulesProtected | Should -Be $ExpectedProtected
            (Get-TestAcl -Path $next).AreAccessRulesProtected | Should -Be $ExpectedProtected
        }
    }

    It '<Command> should write <ErrorId> with category OpenError for a path that does not exist, and return exactly one object for the next path' -ForEach $missingPathOpenErrorCases {
        $missing = Join-Path -Path $sandbox -ChildPath ('Missing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
        $next = New-TestSandboxItem -Sandbox $sandbox -Name 'NextAfterMissing'

        $output = @(& $Command -Path $missing, $next -ErrorVariable pathErrors -ErrorAction SilentlyContinue)

        $pathErrors | Should -HaveCount 1
        $pathErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $pathErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
        $pathErrors[0].TargetObject | Should -Be $missing
        $output | Should -HaveCount 1
        $output[0].FullName | Should -Be $next
    }

    It 'Get-NTFSOwner should write a ReadSecurityError with its id, category, and target together for a denied item, and return exactly one object for the next path' -Skip:$canBypassDeny {
        $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'OwnerDenied'
        Block-TestReadPermission -Sandbox $sandbox -Path $blocked
        $next = New-TestSandboxItem -Sandbox $sandbox -Name 'OwnerDeniedNext'

        $output = @(Get-NTFSOwner -Path $blocked, $next -ErrorVariable ownerErrors -ErrorAction SilentlyContinue)

        $ownerErrors | Should -HaveCount 1
        $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        $ownerErrors[0].CategoryInfo.Category | Should -Be 'PermissionDenied'
        $ownerErrors[0].TargetObject | Should -Be $blocked
        $output | Should -HaveCount 1
        $output[0].FullName | Should -Be $next
    }

    Context 'Set-NTFSOwner when Windows refuses the new owner' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It 'Should write <ErrorId> with its category and target for <Scenario>, and keep processing the remaining path' -ForEach $setOwnerErrorCases {
            if ($Scenario -eq 'Missing') {
                # -Account is one shared value for every -Path of the call, so only a missing path can fail while a
                # second, existing path still succeeds with the very same account.
                $target = Join-Path -Path $sandbox -ChildPath ('Missing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
                Assert-TestSandboxPath -Sandbox $sandbox -Path $target
                $next = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerNext'

                $result = @(Set-NTFSOwner -Path $target, $next -Account $currentUser -PassThru -ErrorVariable ownerErrors -ErrorAction SilentlyContinue)

                $ownerErrors | Should -HaveCount 1
                $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
                $ownerErrors[0].CategoryInfo.Category | Should -Be $Category
                $ownerErrors[0].TargetObject | Should -Be $target
                $result | Should -HaveCount 1
                $result[0].FullName | Should -Be $next
                $result[0].Owner.Sid | Should -Be $currentUser
            }
            else {
                # Windows refuses the same account for every path of the call, so both paths fail; each must still be
                # reported on its own, which proves the loop did not stop after the first one.
                $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerRefused'
                $next = New-TestSandboxItem -Sandbox $sandbox -Name 'SetOwnerRefusedNext'
                (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState | Should -Not -Be 'Enabled'

                $result = @(Set-NTFSOwner -Path $target, $next -Account $trustedInstaller -PassThru -ErrorVariable ownerErrors -ErrorAction SilentlyContinue)

                $ownerErrors | Should -HaveCount 2
                $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
                $ownerErrors[0].CategoryInfo.Category | Should -Be $Category
                $ownerErrors[0].TargetObject | Should -Be $target
                $ownerErrors[1].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
                $ownerErrors[1].CategoryInfo.Category | Should -Be $Category
                $ownerErrors[1].TargetObject | Should -Be $next
                $result | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'Pipeline: binding into the -Path and -SecurityDescriptor sets that no existing test piped' {
    It '<Command> should take piped folders from Get-ChildItem2 and report the <Scope> inheritance state of each with -PassThru' -ForEach $pipedInheritanceCases {
        if ($Scope -eq 'audit' -and -not $canChangeAudit) {
            Set-ItResult -Skipped -Because 'changing audit inheritance needs the Security privilege'
            return
        }
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'PipedInheritanceParent' -Directory
        $children = foreach ($i in 1, 2) {
            $child = Join-Path -Path $parent -ChildPath "Child$i"
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            New-Item -ItemType Directory -Path $child | Out-Null
            $child
        }
        if ($PreDisable) {
            foreach ($child in $children) {
                if ($Scope -eq 'access') { Disable-NTFSAccessInheritance -Path $child -ErrorAction Stop }
                else { Disable-NTFSAuditInheritance -Path $child -ErrorAction Stop }
            }
        }

        $result = @(Get-ChildItem2 -Path $parent -Directory | & $Command -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 2
        $result | ForEach-Object -Process { $_ | Should -BeOfType ([Security2.FileSystemInheritanceInfo]) }
        (@($result.FullName) | Sort-Object) | Should -Be (@($children) | Sort-Object)
        foreach ($child in $children) {
            $item = $result | Where-Object -FilterScript { $_.FullName -eq $child }
            $item | Should -HaveCount 1
            if ($Scope -eq 'access') {
                $item.AccessInheritanceEnabled | Should -Be $Expected
                (Get-Acl -LiteralPath $child).AreAccessRulesProtected | Should -Be (-not $Expected)
            }
            else {
                $item.AuditInheritanceEnabled | Should -Be $Expected
                (Get-TestAuditAcl -Path $child).AreAuditRulesProtected | Should -Be (-not $Expected)
            }
        }
    }

    It '<Command> -SecurityDescriptor should take two piped descriptors and report both in order, written only by Set-NTFSSecurityDescriptor' -ForEach $pipedInheritanceSdCases {
        if ($Scope -eq 'audit' -and -not $canChangeAudit) {
            Set-ItResult -Skipped -Because 'changing audit inheritance needs the Security privilege'
            return
        }
        $files = 1, 2 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "PipedSdInheritance$_" }
        if ($PreDisable) {
            foreach ($file in $files) {
                if ($Scope -eq 'access') { Disable-NTFSAccessInheritance -Path $file -ErrorAction Stop }
                else { Disable-NTFSAuditInheritance -Path $file -ErrorAction Stop }
            }
        }
        $descriptors = @(Get-NTFSSecurityDescriptor -Path $files)
        $descriptors | Should -HaveCount 2

        $result = @($descriptors | & $Command -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 2
        ($result.FullName -join '|') | Should -Be ($files -join '|')
        for ($i = 0; $i -lt 2; $i++) {
            if ($Scope -eq 'access') {
                $descriptors[$i].SecurityDescriptor.AreAccessRulesProtected | Should -Be (-not $Expected)
                (Get-Acl -LiteralPath $files[$i]).AreAccessRulesProtected | Should -Be $PreDisable
            }
            else {
                $descriptors[$i].SecurityDescriptor.AreAuditRulesProtected | Should -Be (-not $Expected)
                (Get-TestAuditAcl -Path $files[$i]).AreAuditRulesProtected | Should -Be $PreDisable
            }
        }

        Set-NTFSSecurityDescriptor -SecurityDescriptor $descriptors -ErrorAction Stop

        foreach ($file in $files) {
            if ($Scope -eq 'access') { (Get-Acl -LiteralPath $file).AreAccessRulesProtected | Should -Be (-not $Expected) }
            else { (Get-TestAuditAcl -Path $file).AreAuditRulesProtected | Should -Be (-not $Expected) }
        }

        # A direct array binds both descriptors within one ProcessRecord call, unlike the pipeline above, which
        # rebinds the parameter once per item; only this direct form can catch a handler that always changes the
        # first descriptor of the set.
        $directFiles = 1, 2 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "DirectSdInheritance$_" }
        if ($PreDisable) {
            foreach ($file in $directFiles) {
                if ($Scope -eq 'access') { Disable-NTFSAccessInheritance -Path $file -ErrorAction Stop }
                else { Disable-NTFSAuditInheritance -Path $file -ErrorAction Stop }
            }
        }
        $directDescriptors = @(Get-NTFSSecurityDescriptor -Path $directFiles)

        & $Command -SecurityDescriptor $directDescriptors -ErrorAction Stop

        for ($i = 0; $i -lt 2; $i++) {
            if ($Scope -eq 'access') { $directDescriptors[$i].SecurityDescriptor.AreAccessRulesProtected | Should -Be (-not $Expected) }
            else { $directDescriptors[$i].SecurityDescriptor.AreAuditRulesProtected | Should -Be (-not $Expected) }
        }
    }

    It 'Get-NTFSInheritance should take piped folder objects from Get-ChildItem2 and a piped custom object by its FullName property' {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritancePipeParent' -Directory
        $children = foreach ($i in 1, 2) {
            $child = Join-Path -Path $parent -ChildPath "Child$i"
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            New-Item -ItemType Directory -Path $child | Out-Null
            $child
        }

        $result = @(Get-ChildItem2 -Path $parent -Directory | Get-NTFSInheritance -ErrorAction Stop)

        $result | Should -HaveCount 2
        (@($result.FullName) | Sort-Object) | Should -Be (@($children) | Sort-Object)
        $result | ForEach-Object -Process { $_ | Should -BeOfType ([Security2.FileSystemInheritanceInfo]) }

        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritancePipeByProperty'
        $expectedFlag = -not (Get-Acl -LiteralPath $file).AreAccessRulesProtected

        $byProperty = @([pscustomobject]@{ FullName = $file } | Get-NTFSInheritance -ErrorAction Stop)

        $byProperty | Should -HaveCount 1
        $byProperty[0].FullName | Should -Be $file
        $byProperty[0].AccessInheritanceEnabled | Should -Be $expectedFlag
    }

    It 'Get-NTFSInheritance -SecurityDescriptor should take two piped descriptors, one protected, and report both in order' {
        $protectedItem = New-TestSandboxItem -Sandbox $sandbox -Name 'SdInheritanceProtected'
        Disable-NTFSAccessInheritance -Path $protectedItem -ErrorAction Stop
        $plainItem = New-TestSandboxItem -Sandbox $sandbox -Name 'SdInheritancePlain'
        $descriptors = @(Get-NTFSSecurityDescriptor -Path $protectedItem, $plainItem)

        $result = @($descriptors | Get-NTFSInheritance -ErrorAction Stop)

        $result | Should -HaveCount 2
        $result[0].FullName | Should -Be $protectedItem
        $result[0].Name | Should -Be ([IO.Path]::GetFileName($protectedItem))
        $result[0].AccessInheritanceEnabled | Should -BeFalse
        $result[1].FullName | Should -Be $plainItem
        $result[1].AccessInheritanceEnabled | Should -BeTrue

        # The same array passed directly to the parameter, not only through the pipeline.
        $byParameter = @(Get-NTFSInheritance -SecurityDescriptor $descriptors -ErrorAction Stop)

        $byParameter | Should -HaveCount 2
        $byParameter[0].AccessInheritanceEnabled | Should -BeFalse
        $byParameter[1].AccessInheritanceEnabled | Should -BeTrue
    }

    It 'Set-NTFSInheritance should restore a saved inheritance state through the pipeline by property name' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'RoundTripState' -Directory
        $state = Get-NTFSInheritance -Path $path -ErrorAction Stop
        Disable-NTFSAccessInheritance -Path $path -ErrorAction Stop
        (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -BeTrue

        $result = @($state | Set-NTFSInheritance -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType ([Security2.FileSystemInheritanceInfo])
        $result[0].FullName | Should -Be $path
        (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -BeFalse
    }

    It 'Set-NTFSInheritance -SecurityDescriptor should protect both descriptors in memory, written only by Set-NTFSSecurityDescriptor, piped and passed directly to the parameter' {
        $files = 1, 2 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "SdInheritanceSet$_" }
        $descriptors = @(Get-NTFSSecurityDescriptor -Path $files)

        $result = @($descriptors | Set-NTFSInheritance -AccessInheritanceEnabled $false -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 2
        ($result.FullName -join '|') | Should -Be ($files -join '|')
        $descriptors | ForEach-Object -Process { $_.SecurityDescriptor.AreAccessRulesProtected | Should -BeTrue }
        foreach ($file in $files) { (Get-Acl -LiteralPath $file).AreAccessRulesProtected | Should -BeFalse }

        Set-NTFSSecurityDescriptor -SecurityDescriptor $descriptors -ErrorAction Stop

        foreach ($file in $files) { (Get-Acl -LiteralPath $file).AreAccessRulesProtected | Should -BeTrue }

        # A direct array binds both descriptors within one ProcessRecord call, unlike the pipeline above, which
        # rebinds the parameter once per item; only this direct form can catch a handler that always changes the
        # first descriptor of the set.
        $directFiles = 1, 2 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "DirectSdInheritanceSet$_" }
        $directDescriptors = @(Get-NTFSSecurityDescriptor -Path $directFiles)

        Set-NTFSInheritance -SecurityDescriptor $directDescriptors -AccessInheritanceEnabled $false -ErrorAction Stop

        $directDescriptors | ForEach-Object -Process { $_.SecurityDescriptor.AreAccessRulesProtected | Should -BeTrue }
    }

    It 'Get-NTFSOwner should take two piped folders from Get-ChildItem2 and return the owner of each, verified with Get-Acl' {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'OwnerPipeParent' -Directory
        $children = foreach ($i in 1, 2) {
            $child = Join-Path -Path $parent -ChildPath "Child$i"
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            New-Item -ItemType Directory -Path $child | Out-Null
            $child
        }

        $result = @(Get-ChildItem2 -Path $parent -Directory | Get-NTFSOwner -ErrorAction Stop)

        $result | Should -HaveCount 2
        $result | ForEach-Object -Process { $_ | Should -BeOfType ([Security2.FileSystemOwner]) }
        foreach ($child in $children) {
            $owner = $result | Where-Object -FilterScript { $_.FullName -eq $child }
            $owner | Should -HaveCount 1
            $owner.Owner.Sid | Should -Be (Get-Acl -LiteralPath $child).GetOwner($sidType).Value
        }
    }

    It 'Get-NTFSOwner -SecurityDescriptor should return the owner of each descriptor, piped and passed directly to the parameter, verified with Get-Acl' {
        $first = New-TestSandboxItem -Sandbox $sandbox -Name 'SdOwnerFirst'
        $second = New-TestSandboxItem -Sandbox $sandbox -Name 'SdOwnerSecond'
        if ($holdsRestorePrivilege) {
            Set-TestOwner -Sandbox $sandbox -Path $second -Sid $trustedInstaller
        }
        $expectedFirst = (Get-Acl -LiteralPath $first).GetOwner($sidType).Value
        $expectedSecond = (Get-Acl -LiteralPath $second).GetOwner($sidType).Value
        if ($holdsRestorePrivilege) {
            $expectedFirst | Should -Not -Be $expectedSecond
        }
        $descriptors = @(Get-NTFSSecurityDescriptor -Path $first, $second)

        $piped = @($descriptors | Get-NTFSOwner -ErrorAction Stop)

        $piped | Should -HaveCount 2
        $piped | ForEach-Object -Process { $_ | Should -BeOfType ([Security2.FileSystemOwner]) }
        $piped[0].FullName | Should -Be $first
        $piped[0].Owner.Sid | Should -Be $expectedFirst
        $piped[1].FullName | Should -Be $second
        $piped[1].Owner.Sid | Should -Be $expectedSecond

        # Row 14 of the matrix was bound only by a call the scan could not classify; call it directly and by name too.
        $direct = @(Get-NTFSOwner -SecurityDescriptor $descriptors -ErrorAction Stop)

        $direct | Should -HaveCount 2
        $direct[0].Owner.Sid | Should -Be $expectedFirst
        $direct[1].Owner.Sid | Should -Be $expectedSecond
    }

    It 'Set-NTFSOwner -SecurityDescriptor should change both owners in memory without touching the items, piped and passed directly to the parameter' {
        $files = 1, 2 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "SdOwnerSet$_" }
        $before = $files | ForEach-Object -Process { (Get-Acl -LiteralPath $_).GetOwner($sidType).Value }
        $descriptors = @(Get-NTFSSecurityDescriptor -Path $files)

        $result = @($descriptors | Set-NTFSOwner -Account 'S-1-1-0' -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 2
        ($result.FullName -join '|') | Should -Be ($files -join '|')
        $result | ForEach-Object -Process { $_.Owner.Sid | Should -Be 'S-1-1-0' }
        for ($i = 0; $i -lt 2; $i++) {
            (Get-Acl -LiteralPath $files[$i]).GetOwner($sidType).Value | Should -Be $before[$i]
        }

        # A direct array binds both descriptors within one ProcessRecord call; the pipeline above rebinds the
        # parameter once per item instead, so only this direct form can catch a handler that always changes the
        # first descriptor of the set.
        $directFiles = 1, 2 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "SdOwnerSetDirect$_" }
        $directDescriptors = @(Get-NTFSSecurityDescriptor -Path $directFiles)

        Set-NTFSOwner -SecurityDescriptor $directDescriptors -Account 'S-1-1-0' -ErrorAction Stop

        $directDescriptors | ForEach-Object -Process { $_.SecurityDescriptor.GetOwner($sidType).Value | Should -Be 'S-1-1-0' }
    }

    It 'Get-NTFSSecurityDescriptor should take piped folder objects, a standard Get-Item object, and a piped custom object by its Path property' {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'SdPipeParent' -Directory
        $children = foreach ($i in 1, 2) {
            $child = Join-Path -Path $parent -ChildPath "Child$i"
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            New-Item -ItemType Directory -Path $child | Out-Null
            $child
        }

        $result = @(Get-ChildItem2 -Path $parent -Directory | Get-NTFSSecurityDescriptor -ErrorAction Stop)

        $result | Should -HaveCount 2
        $result | ForEach-Object -Process { $_ | Should -BeOfType ([Security2.FileSystemSecurity2]) }
        (@($result.FullName) | Sort-Object) | Should -Be (@($children) | Sort-Object)
        foreach ($child in $children) {
            $sd = $result | Where-Object -FilterScript { $_.FullName -eq $child }
            $sd.SecurityDescriptor.GetSecurityDescriptorSddlForm('Access') | Should -Be (Get-Acl -LiteralPath $child).GetSecurityDescriptorSddlForm('Access')
        }

        $standardItem = Get-Item -LiteralPath $children[0]
        $byStandardItem = @(Get-NTFSSecurityDescriptor -Path $standardItem -ErrorAction Stop)
        $byStandardItem | Should -HaveCount 1
        $byStandardItem[0].FullName | Should -Be $children[0]

        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'SdPipeByProperty'
        $expectedSddl = (Get-Acl -LiteralPath $file).GetSecurityDescriptorSddlForm('Access')

        $byProperty = @([pscustomobject]@{ Path = $file } | Get-NTFSSecurityDescriptor -ErrorAction Stop)

        $byProperty | Should -HaveCount 1
        $byProperty[0].FullName | Should -Be $file
        $byProperty[0].SecurityDescriptor.GetSecurityDescriptorSddlForm('Access') | Should -Be $expectedSddl
    }
}
