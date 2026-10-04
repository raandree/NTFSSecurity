<#
    Tests the audit cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder. Reading
    and changing audit entries needs the Security privilege; tests that need it skip without it and run in CI,
    whose runners are elevated.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canReadAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Audit'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSAudit' {
    Context 'When the audit entries cannot be read' {
        It 'Should write an error without the Security privilege instead of returning nothing' -Skip:$canReadAudit {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NoPrivilege'

            $entries = @(Get-NTFSAudit -Path $file -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $entries | Should -BeNullOrEmpty
            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        }

        It 'Should write an error for a security descriptor that was read without the audit entries' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AccessOnly'
            $sd = New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
                (Get-Item2 -Path $file), [System.Security.AccessControl.AccessControlSections]::Access
            )

            $entries = @(Get-NTFSAudit -SecurityDescriptor $sd -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $entries | Should -BeNullOrEmpty
            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        }
    }

    Context 'When a path fails after a path with audit entries' {
        # Before 5.0.0, the cmdlet wrote the entries of the previous item again for the failing path.
        It 'Should return the entries of the first item once' -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Audited' -Directory
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Add-NTFSAudit -Path $folder -Account 'Everyone' -AccessRights Delete -AuditFlags Success
            Block-TestReadPermission -Sandbox $sandbox -Path $denied

            $entries = @(Get-NTFSAudit -Path $folder, $denied -ExcludeInherited -ErrorAction SilentlyContinue)

            @($entries | Where-Object -Property FullName -EQ -Value $folder) | Should -HaveCount 1
        }
    }
}
