<#
    Tests how the cmdlets of the module built in NTFSSecurity\bin\Release handle the Backup, Restore, Take Ownership,
    and Security privileges. These tests need an access token that holds the privileges, so they skip without them
    and run in CI, whose runners are elevated. They change only the privileges of the test process and restore the
    module setting EnablePrivileges.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $missingPrivileges = @('SeBackupPrivilege', 'SeRestorePrivilege', 'SeTakeOwnershipPrivilege', 'SeSecurityPrivilege') |
        Where-Object -FilterScript { -not (Test-PrivilegeHeld -Name $_) }
    $holdsPrivileges = -not $missingPrivileges
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Privileges'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']

    function Get-BackupPrivilegeState {
        (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Backup').PrivilegeState
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Disable-Privileges' {
    Context 'When the module setting EnablePrivileges is $false' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0, the cmdlet warned that it could not disable the privileges and left them enabled.
        It 'Should disable the privileges that Enable-Privileges enabled' -Skip:(-not $holdsPrivileges) {
            Enable-Privileges
            Get-BackupPrivilegeState | Should -Be 'Enabled'

            Disable-Privileges -WarningVariable privilegeWarnings -WarningAction SilentlyContinue

            $privilegeWarnings | Should -BeNullOrEmpty
            Get-BackupPrivilegeState | Should -Be 'Disabled'
        }
    }
}

Describe 'Inheritance cmdlets' {
    Context 'When the module setting EnablePrivileges is $false' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Inheritance'
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0, the inheritance cmdlets enabled the privileges anyway and left them enabled.
        It '<_> should leave the privileges disabled' -Skip:(-not $holdsPrivileges) -ForEach @(
            'Get-NTFSInheritance', 'Set-NTFSInheritance', 'Enable-NTFSAccessInheritance',
            'Disable-NTFSAccessInheritance', 'Enable-NTFSAuditInheritance', 'Disable-NTFSAuditInheritance'
        ) {
            Get-BackupPrivilegeState | Should -Be 'Disabled'

            & $_ -Path $file -ErrorAction SilentlyContinue | Out-Null

            Get-BackupPrivilegeState | Should -Be 'Disabled'
        }
    }
}
