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
