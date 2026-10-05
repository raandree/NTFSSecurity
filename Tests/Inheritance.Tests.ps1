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
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Inheritance'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
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