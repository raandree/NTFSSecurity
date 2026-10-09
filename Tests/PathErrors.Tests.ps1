<#
    Tests the error handling that the cmdlets with -Path share, with the module built in NTFSSecurity\bin\Release on
    files in a sandbox folder: a path that doesn't exist, an item whose owner may not read its permissions, and an item
    whose owner may not change its permissions, which the cmdlets that write the DACL handle by taking ownership. Each
    error belongs to its path only, and the cmdlet continues with the next one. The tests turn the module setting
    EnablePrivileges off, so that an elevated session meets the same denials as a basic user, and restore it.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $holdsSecurityPrivilege = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    $holdsRestorePrivilege = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $readEntry = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData' }
    # An audit entry on a file has no inheritance flags.
    $auditEntry = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData'; InheritanceFlags = 'None'; PropagationFlags = 'None' }

    # Output: whether the cmdlet writes an object for the next path, an existing file.
    $missingPathCases = @(
        @{ Command = 'Get-NTFSAccess'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $true }
        @{ Command = 'Add-NTFSAccess'; Parameters = $readEntry; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Remove-NTFSAccess'; Parameters = $readEntry; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Clear-NTFSAccess'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Get-NTFSEffectiveAccess'; Parameters = @{ Account = 'S-1-1-0' }; ErrorId = 'ReadFileError'; Output = $true }
        @{ Command = 'Get-NTFSOrphanedAccess'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Get-NTFSInheritance'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $true }
        @{ Command = 'Enable-NTFSAccessInheritance'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Disable-NTFSAccessInheritance'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Set-NTFSInheritance'; Parameters = @{ AccessInheritanceEnabled = $true }; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Get-NTFSOwner'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $true }
        @{ Command = 'Set-NTFSOwner'; Parameters = @{ Account = $currentUser }; ErrorId = 'ReadFileError'; Output = $false }
        @{ Command = 'Get-NTFSSecurityDescriptor'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $true }
        @{ Command = 'Get-Item2'; Parameters = @{}; ErrorId = 'FileNotFound'; Output = $true }
        @{ Command = 'Get-ChildItem2'; Parameters = @{}; ErrorId = 'FileNotFound'; Output = $true }
        @{ Command = 'Get-FileHash2'; Parameters = @{}; ErrorId = 'ReadFileError'; Output = $true }
        @{ Command = 'Get-NTFSHardLink'; Parameters = @{}; ErrorId = 'FileNotFound'; Output = $true }
    )

    # The audit cmdlets need the Security privilege for the next path.
    $missingPathAuditCases = @(
        @{ Command = 'Get-NTFSAudit'; Parameters = @{} }
        @{ Command = 'Add-NTFSAudit'; Parameters = $auditEntry }
        @{ Command = 'Remove-NTFSAudit'; Parameters = $auditEntry }
        @{ Command = 'Clear-NTFSAudit'; Parameters = @{} }
        @{ Command = 'Enable-NTFSAuditInheritance'; Parameters = @{} }
        @{ Command = 'Disable-NTFSAuditInheritance'; Parameters = @{} }
    )

    $deniedReadCases = @(
        @{ Command = 'Get-NTFSAccess'; Parameters = @{}; Output = $true }
        @{ Command = 'Get-NTFSEffectiveAccess'; Parameters = @{ Account = 'S-1-1-0' }; Output = $true }
        @{ Command = 'Get-NTFSOrphanedAccess'; Parameters = @{}; Output = $false }
        @{ Command = 'Get-NTFSInheritance'; Parameters = @{}; Output = $true }
        @{ Command = 'Get-NTFSOwner'; Parameters = @{}; Output = $true }
        @{ Command = 'Get-NTFSSecurityDescriptor'; Parameters = @{}; Output = $true }
    )
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'PathErrors'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']
    $privateData['EnablePrivileges'] = $false
    $sidType = [System.Security.Principal.SecurityIdentifier]

    function Get-TestMissingPath {
        $path = Join-Path -Path $sandbox -ChildPath ('Missing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        $path
    }

    function Get-TestAcl {
        # .NET, because Get-Acl of an elevated Windows PowerShell reads also items that deny reading their permissions.
        # .NET Core has the method as an extension method.
        param ([string] $Path)

        $info = New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $Path
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            $info.GetAccessControl()
        }
        else {
            [System.IO.FileSystemAclExtensions]::GetAccessControl($info)
        }
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'A path that does not exist' {
    It '<Command> should write a <ErrorId> for it and continue with the next path' -ForEach $missingPathCases {
        $missing = Get-TestMissingPath
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Next'

        $output = @(& $Command -Path $missing, $file @Parameters -ErrorVariable pathErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)

        $pathErrors | Should -HaveCount 1
        $pathErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $pathErrors[0].TargetObject | Should -Be $missing
        if ($Output) {
            $output | Should -Not -BeNullOrEmpty
        }
    }

    It '<Command> should write a ReadFileError for it and continue with the next path' -ForEach $missingPathAuditCases -Skip:(-not $holdsSecurityPrivilege) {
        $privateData['EnablePrivileges'] = $true
        try {
            $missing = Get-TestMissingPath
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NextAudit'

            & $Command -Path $missing, $file @Parameters -ErrorVariable pathErrors -ErrorAction SilentlyContinue | Out-Null
        }
        finally {
            $privateData['EnablePrivileges'] = $false
        }

        $pathErrors | Should -HaveCount 1
        $pathErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
        $pathErrors[0].TargetObject | Should -Be $missing
    }
}

Describe 'An item whose owner may not read its permissions' {
    # A deny entry for OWNER RIGHTS replaces the right of the owner to read the security descriptor. Taking ownership
    # can't help: the cmdlet must read the owner first, which needs the same right. Before 5.0.0-rc6,
    # Get-NTFSOrphanedAccess reported this as an AddAceError.
    It '<Command> should write a ReadSecurityError for it and continue with the next path' -ForEach $deniedReadCases {
        $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'Unreadable'
        Block-TestReadPermission -Sandbox $sandbox -Path $blocked
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NextReadable'

        $output = @(& $Command -Path $blocked, $file @Parameters -ErrorVariable pathErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)

        $pathErrors | Should -HaveCount 1
        $pathErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        $pathErrors[0].TargetObject | Should -Be $blocked
        if ($Output) {
            $output | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'A denied write and a denied ownership retry' {
    It '<Command> should keep the denied item unchanged, report <ErrorId>, and process the next item' -ForEach @(
        @{ Command = 'Add-NTFSAccess'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData' }; ErrorId = 'AddAceError'; Operation = 'Add' }
        @{ Command = 'Remove-NTFSAccess'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData' }; ErrorId = 'RemoveAceError'; Operation = 'Remove' }
        @{ Command = 'Clear-NTFSAccess'; Parameters = @{}; ErrorId = 'ClearAclError'; Operation = 'Clear' }
        @{ Command = 'Disable-NTFSAccessInheritance'; Parameters = @{}; ErrorId = 'ModifySdError'; Operation = 'Disable' }
        @{ Command = 'Enable-NTFSAccessInheritance'; Parameters = @{}; ErrorId = 'ModifySdError'; Operation = 'Enable' }
        @{ Command = 'Set-NTFSInheritance'; Parameters = @{ AccessInheritanceEnabled = $false }; ErrorId = 'ModifySdError'; Operation = 'Disable' }
    ) {
        $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'RetryBlocked'
        $next = New-TestSandboxItem -Sandbox $sandbox -Name 'RetryNext'
        foreach ($path in $blocked, $next) {
            if ($Operation -ne 'Add') {
                Add-NTFSAccess -Path $path -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            }
            if ($Operation -eq 'Enable') {
                Disable-NTFSAccessInheritance -Path $path -ErrorAction Stop
            }
        }
        Block-TestWritePermission -Sandbox $sandbox -Path $blocked
        $before = (Get-TestAcl -Path $blocked).Sddl

        & $Command -Path $blocked, $next @Parameters -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -HaveCount 1
        $changeErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $changeErrors[0].TargetObject | Should -Be $blocked
        (Get-TestAcl -Path $blocked).Sddl | Should -BeExactly $before
        $acl = Get-TestAcl -Path $next
        $everyone = @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
        switch ($Operation) {
            'Add' { $everyone | Should -HaveCount 1 }
            'Remove' { $everyone | Should -BeNullOrEmpty }
            'Clear' { @($acl.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty }
            'Disable' { $acl.AreAccessRulesProtected | Should -BeTrue }
            'Enable' { $acl.AreAccessRulesProtected | Should -BeFalse }
        }
    }
}

Describe 'An owner that the process cannot restore without the Restore privilege' {
    It 'Should report RestoreOwnerError after a successful ownership retry and continue with the next path' -Skip:(-not $holdsRestorePrivilege) {
        $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'UnassignableOwner'
        $next = New-TestSandboxItem -Sandbox $sandbox -Name 'NextOwner'
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $user = 'ChangePermissions' }
        $originalOwner = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
        Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $originalOwner
        (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState | Should -Be 'Disabled'

        Add-NTFSAccess -Path $blocked, $next -Account 'S-1-1-0' -AccessRights ReadData -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -HaveCount 1
        $changeErrors[0].FullyQualifiedErrorId | Should -BeLike 'RestoreOwnerError,*'
        $changeErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
        $changeErrors[0].TargetObject | Should -Be $blocked
        (Get-TestAcl -Path $blocked).GetOwner($sidType).Value | Should -Be $user
        foreach ($path in $blocked, $next) {
            @((Get-TestAcl -Path $path).GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
        }
    }
}
Describe 'An item whose owner may not change its permissions' {
    # A deny entry for OWNER RIGHTS replaces the right of the owner to change the DACL. The cmdlets take ownership,
    # which Windows answers by removing the OWNER RIGHTS entries, write the DACL, and set the previous owner back.
    BeforeEach {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Unchangeable'
        $acl = Get-TestAcl -Path $file
        $owner = $acl.GetOwner($sidType).Value
    }

    It 'Add-NTFSAccess should take ownership, add the entry, and set the owner back' {
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -BeNullOrEmpty
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $owner
        @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
        @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-3-4' }) | Should -BeNullOrEmpty
    }

    It 'Remove-NTFSAccess should take ownership, remove the entry, and set the owner back' {
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Remove-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -BeNullOrEmpty
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $owner
        @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -BeNullOrEmpty
    }

    It 'Clear-NTFSAccess should take ownership, remove the explicit entries, and set the owner back' {
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Clear-NTFSAccess -Path $file -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -BeNullOrEmpty
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $owner
        @($acl.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
    }

    # With the DACL cleared and protected, nobody keeps the right to set an owner, so setting the previous owner back
    # fails. The user owned the item already, so there is no owner to set back.
    It 'Clear-NTFSAccess -DisableInheritance should take ownership, clear and protect the DACL, and not set an unchanged owner back' {
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        Set-TestOwner -Sandbox $sandbox -Path $file -Sid $user
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Clear-NTFSAccess -Path $file -DisableInheritance -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -BeNullOrEmpty
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $user
        $acl.AreAccessRulesProtected | Should -BeTrue
        @($acl.GetAccessRules($true, $true, $sidType)) | Should -BeNullOrEmpty
    }

    # Windows lets the owner of an item set another owner only with the Restore privilege, which the tests turn off, or
    # with the right in the DACL, which the cleared DACL no longer holds. The cmdlet reports the owner it cannot set back.
    It 'Clear-NTFSAccess -DisableInheritance should report RestoreOwnerError for a previous owner that it cannot set back' -Skip:(-not $holdsRestorePrivilege) {
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $owner | Should -Not -Be $user
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Clear-NTFSAccess -Path $file -DisableInheritance -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -HaveCount 1
        $changeErrors[0].FullyQualifiedErrorId | Should -BeLike 'RestoreOwnerError,*'
        $changeErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
        $changeErrors[0].TargetObject | Should -Be $file
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $user
        $acl.AreAccessRulesProtected | Should -BeTrue
        @($acl.GetAccessRules($true, $true, $sidType)) | Should -BeNullOrEmpty
    }

    It 'Disable-NTFSAccessInheritance should take ownership, protect the DACL, and set the owner back' {
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Disable-NTFSAccessInheritance -Path $file -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -BeNullOrEmpty
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $owner
        $acl.AreAccessRulesProtected | Should -BeTrue
    }

    It 'Enable-NTFSAccessInheritance should take ownership, let the DACL inherit, and set the owner back' {
        Disable-NTFSAccessInheritance -Path $file
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Enable-NTFSAccessInheritance -Path $file -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -BeNullOrEmpty
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $owner
        $acl.AreAccessRulesProtected | Should -BeFalse
    }

    It 'Set-NTFSInheritance should take ownership, protect the DACL, and set the owner back' {
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-3-4' = 'ChangePermissions' }

        Set-NTFSInheritance -Path $file -AccessInheritanceEnabled $false -ErrorVariable changeErrors -ErrorAction SilentlyContinue

        $changeErrors | Should -BeNullOrEmpty
        $acl = Get-TestAcl -Path $file
        $acl.GetOwner($sidType).Value | Should -Be $owner
        $acl.AreAccessRulesProtected | Should -BeTrue
    }
}
