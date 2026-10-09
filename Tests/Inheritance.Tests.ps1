<#
    Tests the inheritance cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
    Tests that change the audit section need the Security privilege and skip without it; CI runs them elevated.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canChangeAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    # Assigning an owner other than the user or one of its groups needs the Restore privilege.
    $canAssignAnyOwner = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
    $inheritanceCases = @(foreach ($type in 'file', 'folder') {
        foreach ($enable in $false, $true) {
            foreach ($remove in $false, $true) {
                @{ Type = $type; Enable = $enable; Remove = $remove }
            }
        }
    })
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Inheritance'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']
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

Describe 'Get-NTFSInheritance' {
    Context 'With a security descriptor' {
        BeforeEach {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Descriptor'
        }

        It 'Should report the same state as for the path of the item' {
            $byPath = Get-NTFSInheritance -Path $file
            $bySecurityDescriptor = Get-NTFSInheritance -SecurityDescriptor (Get-NTFSSecurityDescriptor -Path $file)

            $bySecurityDescriptor.AccessInheritanceEnabled | Should -Be $byPath.AccessInheritanceEnabled
            $bySecurityDescriptor.AuditInheritanceEnabled | Should -Be $byPath.AuditInheritanceEnabled
        }

        It 'Should report the audit inheritance as $null for a security descriptor without the audit entries' {
            $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
                (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Access
            )

            $result = Get-NTFSInheritance -SecurityDescriptor $sd

            $result.AccessInheritanceEnabled | Should -BeTrue
            $result.AuditInheritanceEnabled | Should -BeNullOrEmpty
        }
    }
}

Describe 'Inheritance cmdlets with -PassThru' {
    BeforeDiscovery {
        # With the Backup privilege, Windows may grant reading the security descriptor despite a deny entry.
        $canBypassDeny = Test-PrivilegeHeld -Name 'SeBackupPrivilege'
    }

    # Before 5.0.0, the cmdlets wrote the -PassThru object in a finally block, also after a failure (#74).
    It '<_> should return nothing when the audit change fails' -Skip:$canChangeAudit -ForEach @(
        'Enable-NTFSAuditInheritance', 'Disable-NTFSAuditInheritance'
    ) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThru'

        $result = @(& $_ -Path $file -PassThru -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue)

        $inheritanceErrors | Should -Not -BeNullOrEmpty
        $result | Should -BeNullOrEmpty
    }

    It 'Set-NTFSInheritance should return nothing when the audit change fails' -Skip:$canChangeAudit {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThru'

        $result = @(Set-NTFSInheritance -Path $file -AuditInheritanceEnabled $false -PassThru -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue)

        $inheritanceErrors | Should -Not -BeNullOrEmpty
        $result | Should -BeNullOrEmpty
    }

    It '<_> should write an error and return nothing when the security descriptor cannot be read' -Skip:$canBypassDeny -ForEach @(
        'Enable-NTFSAccessInheritance', 'Disable-NTFSAccessInheritance'
    ) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
        Block-TestReadPermission -Sandbox $sandbox -Path $file

        $result = @(& $_ -Path $file -PassThru -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue)

        $inheritanceErrors | Should -HaveCount 1
        $inheritanceErrors[0].FullyQualifiedErrorId | Should -BeLike 'ModifySdError,*'
        $result | Should -BeNullOrEmpty
    }

    It '<_> should write a read error and return nothing for a path that does not exist' -ForEach @(
        'Enable-NTFSAccessInheritance', 'Disable-NTFSAccessInheritance',
        'Enable-NTFSAuditInheritance', 'Disable-NTFSAuditInheritance'
    ) {
        $missing = Join-Path -Path $sandbox -ChildPath 'Missing.txt'

        $result = @(& $_ -Path $missing -PassThru -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue)

        $inheritanceErrors | Should -HaveCount 1
        $inheritanceErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Set-NTFSInheritance' {
    Context 'When it changes the inheritance' {
        # Before 5.0.0, -AccessInheritanceEnabled $false removed the inherited access entries and
        # -AuditInheritanceEnabled $true removed the explicit audit entries, unlike the dedicated cmdlets.
        It 'Should keep the inherited access entries as explicit ones when it disables access inheritance' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'KeepAccess'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $inheritedCount = @((Get-Acl -LiteralPath $file).Access | Where-Object -Property IsInherited).Count
            # Without inherited entries, the test couldn't see them kept as explicit ones (#110).
            $inheritedCount | Should -BeGreaterThan 0

            Set-NTFSInheritance -Path $file -AccessInheritanceEnabled $false

            $acl = Get-Acl -LiteralPath $file
            $acl.AreAccessRulesProtected | Should -BeTrue
            @($acl.Access | Where-Object -Property IsInherited -EQ -Value $false) | Should -HaveCount $inheritedCount
        }

        # In memory, the kept entries stay marked as inherited; Windows stores them as explicit ones on write.
        # The descriptor holds only the access entries.
        It 'Should keep the inherited access entries of a security descriptor' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'KeepDescriptor'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
                (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Access
            )
            $sidType = [System.Security.Principal.SecurityIdentifier]
            $inheritedCount = @($sd.SecurityDescriptor.GetAccessRules($false, $true, $sidType)).Count
            $inheritedCount | Should -BeGreaterThan 0

            Set-NTFSInheritance -SecurityDescriptor $sd -AccessInheritanceEnabled $false

            $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeTrue
            @($sd.SecurityDescriptor.GetAccessRules($true, $true, $sidType)) | Should -HaveCount $inheritedCount
        }

        It 'Should keep the explicit audit entries when it enables audit inheritance' -Skip:(-not $canChangeAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'KeepAudit'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights Delete -AuditFlags Failure
            Disable-NTFSAuditInheritance -Path $file -ErrorVariable disableErrors -ErrorAction SilentlyContinue
            $disableErrors | Should -BeNullOrEmpty
            (Get-NTFSInheritance -Path $file).AuditInheritanceEnabled | Should -BeFalse

            Set-NTFSInheritance -Path $file -AuditInheritanceEnabled $true -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue

            $inheritanceErrors | Should -BeNullOrEmpty
            (Get-NTFSInheritance -Path $file).AuditInheritanceEnabled | Should -BeTrue
            @(Get-NTFSAudit -Path $file -ExcludeInherited) | Should -HaveCount 1
        }
    }
    Context 'When -AccessInheritanceEnabled or -AuditInheritanceEnabled is omitted' {
        BeforeEach {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'File'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        }

        It 'Should change nothing and write no error when both are omitted' {
            Set-NTFSInheritance -Path $file -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue

            $inheritanceErrors | Should -BeNullOrEmpty
            (Get-NTFSInheritance -Path $file).AccessInheritanceEnabled | Should -BeTrue
        }

        It 'Should leave a security descriptor unchanged when both are omitted' {
            $sd = Get-NTFSSecurityDescriptor -Path $file

            { Set-NTFSInheritance -SecurityDescriptor $sd -ErrorAction Stop } | Should -Not -Throw
            $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeFalse
        }

        It 'Should change only the access inheritance when -AuditInheritanceEnabled is omitted' {
            $before = Get-NTFSInheritance -Path $file

            Set-NTFSInheritance -Path $file -AccessInheritanceEnabled $false -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue

            $inheritanceErrors | Should -BeNullOrEmpty
            $after = Get-NTFSInheritance -Path $file
            $after.AccessInheritanceEnabled | Should -BeFalse
            $after.AuditInheritanceEnabled | Should -Be $before.AuditInheritanceEnabled
        }

        It 'Should change only the audit inheritance when -AccessInheritanceEnabled is omitted' -Skip:(-not $canChangeAudit) {
            Set-NTFSInheritance -Path $file -AuditInheritanceEnabled $false -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue

            $inheritanceErrors | Should -BeNullOrEmpty
            $after = Get-NTFSInheritance -Path $file
            $after.AccessInheritanceEnabled | Should -BeTrue
            $after.AuditInheritanceEnabled | Should -BeFalse
        }
    }
}

Describe 'Audit inheritance of an item without audit entries' {
    # A new item has no SACL. Before 5.0.0, the cmdlets changed only the flag that disables or enables audit
    # inheritance, which is written only together with a SACL, so they wrote no section at all: (5) Access is denied.
    It '<Command> should set the audit inheritance of a <Type> and keep its access entries' -Skip:(-not $canChangeAudit) -ForEach @(
        @{ Command = 'Disable-NTFSAuditInheritance'; Parameters = @{}; Type = 'file'; Expected = $false }
        @{ Command = 'Disable-NTFSAuditInheritance'; Parameters = @{}; Type = 'folder'; Expected = $false }
        @{ Command = 'Enable-NTFSAuditInheritance'; Parameters = @{}; Type = 'file'; Expected = $true }
        @{ Command = 'Enable-NTFSAuditInheritance'; Parameters = @{}; Type = 'folder'; Expected = $true }
        @{ Command = 'Set-NTFSInheritance'; Parameters = @{ AuditInheritanceEnabled = $false }; Type = 'folder'; Expected = $false }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'NoAudit' -Directory:($Type -eq 'folder')
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        @((Get-Acl -LiteralPath $path -Audit).Audit) | Should -BeNullOrEmpty
        $accessEntries = (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access')

        & $Command -Path $path @Parameters -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue

        $inheritanceErrors | Should -BeNullOrEmpty
        (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -Be $Expected
        (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access') | Should -Be $accessEntries
    }

    # Written later, an added empty SACL would replace the audit entries of the item.
    It 'Should add no SACL to a security descriptor that was read without its audit entries' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NoAuditSection'
        $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
            (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Access
        )

        Disable-NTFSAuditInheritance -SecurityDescriptor $sd

        $binaryForm = $sd.SecurityDescriptor.GetSecurityDescriptorBinaryForm()
        $descriptor = New-Object -TypeName 'System.Security.AccessControl.RawSecurityDescriptor' -ArgumentList $binaryForm, 0
        $null -eq $descriptor.SystemAcl | Should -BeTrue
    }
}

Describe 'Audit inheritance switches' {
    # Before 5.0.0, the switches were named after access entries, although they remove audit entries.
    It '<Command> should take -<Name> with the alias -<Alias>' -ForEach @(
        @{ Command = 'Disable-NTFSAuditInheritance'; Name = 'RemoveInheritedAuditRules'; Alias = 'RemoveInheritedAccessRules' }
        @{ Command = 'Enable-NTFSAuditInheritance'; Name = 'RemoveExplicitAuditRules'; Alias = 'RemoveExplicitAccessRules' }
    ) {
        $parameter = (Get-Command -Name $Command).Parameters[$Name]

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.SwitchParameter | Should -BeTrue
        $parameter.Aliases | Should -Contain $Alias
    }

    It '<Command> should bind -<Switch>' -ForEach @(
        @{ Command = 'Disable-NTFSAuditInheritance'; Switch = 'RemoveInheritedAuditRules' }
        @{ Command = 'Disable-NTFSAuditInheritance'; Switch = 'RemoveInheritedAccessRules' }
        @{ Command = 'Enable-NTFSAuditInheritance'; Switch = 'RemoveExplicitAuditRules' }
        @{ Command = 'Enable-NTFSAuditInheritance'; Switch = 'RemoveExplicitAccessRules' }
    ) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditSwitch'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        $parameters = @{ Path = $file; $Switch = $true }

        { & $Command @parameters -ErrorAction SilentlyContinue } | Should -Not -Throw
    }
}

Describe 'Access inheritance transitions on files and folders' {
    It 'Should set enabled=<Enable> on a <Type>, remove requested entries=<Remove>, and report the written state' -ForEach $inheritanceCases {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'AccessParent' -Directory
        $path = Join-Path -Path $parent -ChildPath 'Child'
        $parentAccount = 'S-1-5-21-1-2-3-4901'
        $childAccount = 'S-1-5-21-1-2-3-4902'
        Add-NTFSAccess -Path $parent -Account $parentAccount -AccessRights ReadData -ErrorAction Stop
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        if ($Type -eq 'folder') { New-Item -ItemType Directory -Path $path | Out-Null } else { Set-Content -LiteralPath $path -Value 'Child' }
        Add-NTFSAccess -Path $path -Account $childAccount -AccessRights Delete -AppliesTo ThisFolderOnly -ErrorAction Stop
        @(Get-NTFSAccess -Path $path -Account $parentAccount -ExcludeExplicit -ErrorAction Stop) | Should -HaveCount 1
        $owner = (Get-NTFSOwner -Path $path -ErrorAction Stop).Owner.Sid
        if ($Enable) {
            Disable-NTFSAccessInheritance -Path $path -RemoveInheritedAccessRules -ErrorAction Stop
            $parameters = @{ RemoveExplicitAccessRules = $Remove }
            $command = 'Enable-NTFSAccessInheritance'
        }
        else {
            $parameters = @{ RemoveInheritedAccessRules = $Remove }
            $command = 'Disable-NTFSAccessInheritance'
        }

        $result = @(& $command -Path $path @parameters -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType [Security2.FileSystemInheritanceInfo]
        $result[0].FullName | Should -Be $path
        $result[0].AccessInheritanceEnabled | Should -Be $Enable
        (Get-NTFSInheritance -Path $path).AccessInheritanceEnabled | Should -Be $Enable
        (Get-NTFSOwner -Path $path).Owner.Sid | Should -Be $owner
        $parentRules = @(Get-NTFSAccess -Path $path -Account $parentAccount)
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
        $childRules = @(Get-NTFSAccess -Path $path -Account $childAccount)
        if ($Enable -and $Remove) { $childRules | Should -BeNullOrEmpty } else { $childRules | Should -HaveCount 1 }
    }

    It 'Set-NTFSInheritance should re-enable access inheritance on a <_> and keep its explicit entry' -ForEach @('file', 'folder') {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AccessEnable' -Directory:($_ -eq 'folder')
        Add-NTFSAccess -Path $path -Account 'S-1-5-21-1-2-3-4902' -AccessRights Delete -AppliesTo ThisFolderOnly -ErrorAction Stop
        Disable-NTFSAccessInheritance -Path $path -RemoveInheritedAccessRules -ErrorAction Stop

        $result = @(Set-NTFSInheritance -Path $path -AccessInheritanceEnabled $true -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].AccessInheritanceEnabled | Should -BeTrue
        @(Get-NTFSAccess -Path $path -ExcludeExplicit) | Should -Not -BeNullOrEmpty
        @(Get-NTFSAccess -Path $path -Account 'S-1-5-21-1-2-3-4902' -ExcludeInherited) | Should -HaveCount 1
    }
}

Describe 'Audit inheritance transitions on files and folders' -Skip:(-not $canChangeAudit) {
    It 'Should set enabled=<Enable> on a <Type>, remove requested audit entries=<Remove>, and leave the DACL unchanged' -ForEach $inheritanceCases {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditParent' -Directory
        $path = Join-Path -Path $parent -ChildPath 'Child'
        $parentAccount = 'S-1-5-21-1-2-3-4911'
        $childAccount = 'S-1-5-21-1-2-3-4912'
        Add-NTFSAudit -Path $parent -Account $parentAccount -AccessRights ReadData -AuditFlags Success -ErrorAction Stop
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        if ($Type -eq 'folder') { New-Item -ItemType Directory -Path $path | Out-Null } else { Set-Content -LiteralPath $path -Value 'Child' }
        Add-NTFSAudit -Path $path -Account $childAccount -AccessRights Delete -AuditFlags Failure -AppliesTo ThisFolderOnly -ErrorAction Stop
        @(Get-NTFSAudit -Path $path -Account $parentAccount -ExcludeExplicit -ErrorAction Stop) | Should -HaveCount 1
        $before = (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access')
        if ($Enable) {
            Disable-NTFSAuditInheritance -Path $path -RemoveInheritedAuditRules -ErrorAction Stop
            $parameters = @{ RemoveExplicitAuditRules = $Remove }
            $command = 'Enable-NTFSAuditInheritance'
        }
        else {
            $parameters = @{ RemoveInheritedAuditRules = $Remove }
            $command = 'Disable-NTFSAuditInheritance'
        }

        $result = @(& $command -Path $path @parameters -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $path
        $result[0].AuditInheritanceEnabled | Should -Be $Enable
        (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -Be $Enable
        (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $before
        $parentRules = @(Get-NTFSAudit -Path $path -Account $parentAccount)
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
        $childRules = @(Get-NTFSAudit -Path $path -Account $childAccount)
        if ($Enable -and $Remove) { $childRules | Should -BeNullOrEmpty } else { $childRules | Should -HaveCount 1 }
    }

    It 'Set-NTFSInheritance should re-enable audit inheritance on a <_> and keep its explicit audit entry' -ForEach @('file', 'folder') {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditEnable' -Directory:($_ -eq 'folder')
        Add-NTFSAudit -Path $path -Account 'S-1-5-21-1-2-3-4912' -AccessRights Delete -AuditFlags Failure -AppliesTo ThisFolderOnly -ErrorAction Stop
        Disable-NTFSAuditInheritance -Path $path -RemoveInheritedAuditRules -ErrorAction Stop
        $before = (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access')

        $result = @(Set-NTFSInheritance -Path $path -AuditInheritanceEnabled $true -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].AuditInheritanceEnabled | Should -BeTrue
        @(Get-NTFSAudit -Path $path -Account 'S-1-5-21-1-2-3-4912' -ExcludeInherited) | Should -HaveCount 1
        (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $before
    }
}
Describe 'Access inheritance cmdlets' {
    Context 'When the item has an owner that the user cannot assign' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc3, the cmdlets read only the DACL, but wrote the owner that Windows returns with a DACL without
        # the auto-inherit flag, such as that of a new file in the temp folder of the user. Windows refuses that owner
        # without the Restore privilege (#34).
        It '<_> should write no error and keep the owner' -Skip:(-not $canAssignAnyOwner) -ForEach @(
            'Disable-NTFSAccessInheritance', 'Enable-NTFSAccessInheritance'
        ) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OtherOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'

            & $_ -Path $file -ErrorVariable inheritanceErrors -ErrorAction SilentlyContinue

            $inheritanceErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner([System.Security.Principal.SecurityIdentifier]).Value |
                Should -Be $trustedInstaller
        }
    }
}
Describe 'Set-NTFSInheritance with an in-memory descriptor' {
    It 'Should set access inheritance enabled=<Enable> on a <Type> only when the descriptor is written' -ForEach @(
        @{ Type = 'file'; Enable = $false }
        @{ Type = 'file'; Enable = $true }
        @{ Type = 'folder'; Enable = $false }
        @{ Type = 'folder'; Enable = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorAccessState' -Directory:($Type -eq 'folder')
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        Set-NTFSInheritance -Path $path -AccessInheritanceEnabled (-not $Enable) -ErrorAction Stop
        Add-NTFSAccess -Path $path -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly
        $before = (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access')
        $ownerBefore = (Get-Acl -LiteralPath $path).Owner
        $sd = Get-NTFSSecurityDescriptor -Path $path

        $result = @(Set-NTFSInheritance -SecurityDescriptor $sd -AccessInheritanceEnabled $Enable -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -BeExactly $path
        $result[0].Name | Should -BeExactly ([IO.Path]::GetFileName($path))
        $result[0].AccessInheritanceEnabled | Should -Be $Enable
        $sd.SecurityDescriptor.AreAccessRulesProtected | Should -Be (-not $Enable)
        (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $before
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -Be (-not $Enable)
        (Get-Acl -LiteralPath $path).Owner | Should -BeExactly $ownerBefore
        @(Get-NTFSAccess -Path $path -ExcludeInherited | Where-Object { $_.Account.Sid -eq 'S-1-1-0' }) |
            Should -HaveCount 1
    }

    It 'Should set audit inheritance enabled=<Enable> on a <Type> without changing its DACL or owner' -Skip:(-not $canChangeAudit) -ForEach @(
        @{ Type = 'file'; Enable = $false }
        @{ Type = 'file'; Enable = $true }
        @{ Type = 'folder'; Enable = $false }
        @{ Type = 'folder'; Enable = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorAuditState' -Directory:($Type -eq 'folder')
        Assert-TestSandboxPath -Sandbox $sandbox -Path $path
        Set-NTFSInheritance -Path $path -AuditInheritanceEnabled (-not $Enable) -ErrorAction Stop
        Add-NTFSAudit -Path $path -Account 'S-1-1-0' -AccessRights Delete -AuditFlags Success -AppliesTo ThisFolderOnly
        $before = (Get-NTFSSecurityDescriptor -Path $path).SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit')
        $daclBefore = (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access')
        $ownerBefore = (Get-Acl -LiteralPath $path).Owner
        $sd = Get-NTFSSecurityDescriptor -Path $path

        $result = @(Set-NTFSInheritance -SecurityDescriptor $sd -AuditInheritanceEnabled $Enable -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].AuditInheritanceEnabled | Should -Be $Enable
        $sd.SecurityDescriptor.AreAuditRulesProtected | Should -Be (-not $Enable)
        (Get-NTFSSecurityDescriptor -Path $path).SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit') |
            Should -BeExactly $before
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -Be $Enable
        (Get-Acl -LiteralPath $path).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $daclBefore
        (Get-Acl -LiteralPath $path).Owner | Should -BeExactly $ownerBefore
        @(Get-NTFSAudit -Path $path -ExcludeInherited | Where-Object { $_.Account.Sid -eq 'S-1-1-0' }) |
            Should -HaveCount 1
    }

    It 'Should keep audit inheritance unknown when requested enabled=<_> on an access-only descriptor' -ForEach @($false, $true) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorUnknownAudit'
        $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
            (Get-Item2 -Path $path), [System.Security.AccessControl.AccessControlSections]::Access
        )
        $before = (Get-Acl -LiteralPath $path).Sddl

        $result = @(Set-NTFSInheritance -SecurityDescriptor $sd -AuditInheritanceEnabled $_ -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].AuditInheritanceEnabled | Should -BeNullOrEmpty
        $raw = New-Object -TypeName 'System.Security.AccessControl.RawSecurityDescriptor' -ArgumentList (
            $sd.SecurityDescriptor.GetSecurityDescriptorBinaryForm(), 0
        )
        $null -eq $raw.SystemAcl | Should -BeTrue
        (Get-Acl -LiteralPath $path).Sddl | Should -BeExactly $before
    }
}
