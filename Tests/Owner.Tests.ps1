<#
    Tests the owner cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # With the Backup privilege, Windows may grant reading the owner despite a deny entry.
    $canBypassDeny = Test-PrivilegeHeld -Name 'SeBackupPrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Owner'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSOwner' {
    Context 'When a downstream command stops the pipeline' {
        It 'Should stop without writing errors' {
            $files = 1..3 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "Owner$_" }

            $result = @(Get-NTFSOwner -Path $files -ErrorVariable ownerErrors -ErrorAction SilentlyContinue | Select-Object -First 1)

            $ownerErrors | Should -BeNullOrEmpty
            $result | Should -HaveCount 1
        }
    }

    Context 'When the owner cannot be read' {
        It 'Should write one permission error and keep the owner' -Skip:$canBypassDeny {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Block-TestReadPermission -Sandbox $sandbox -Path $file

            $result = @(Get-NTFSOwner -Path $file -ErrorVariable ownerErrors -ErrorAction SilentlyContinue)

            $result | Should -BeNullOrEmpty
            $ownerErrors | Should -HaveCount 1
            $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $ownerErrors[0].CategoryInfo.Category | Should -Be 'PermissionDenied'
        }
    }
}
