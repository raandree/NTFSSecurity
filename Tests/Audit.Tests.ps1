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
        # Before 5.0.0, the cmdlet wrote the entries of the previous item again for the failing path. In CI, the deny
        # entry made the original implementation, which also read the DACL, fail for the second path. The current one
        # reads only the SACL, which the deny entry doesn't block; Access.Tests.ps1 guards the same loop fix in
        # Get-NTFSAccess with a read that fails without elevation.
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

Describe 'Add-NTFSAudit' {
    Context 'Positional parameters' {
        It 'Should take -Account at position 2 and -AccessRights at position 3 in the <_> parameter set' -ForEach @(
            'PathSimple', 'PathComplex', 'SDSimple', 'SDComplex'
        ) {
            $parameterSet = (Get-Command -Name Add-NTFSAudit).ParameterSets | Where-Object -Property Name -EQ -Value $_
            $positions = @{}
            $parameterSet.Parameters | Where-Object -Property Position -GE -Value 0 | ForEach-Object -Process {
                $positions[$_.Name] = $_.Position
            }

            $positions['Account'] | Should -Be 2
            $positions['AccessRights'] | Should -Be 3
        }

        It 'Should bind an account and access rights that are passed by position' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Positional'
            $sd = Get-NTFSSecurityDescriptor -Path $file

            Add-NTFSAudit -SecurityDescriptor $sd 'Everyone' 'ReadData' -InheritanceFlags None -PropagationFlags None -ErrorAction Stop

            $rules = $sd.SecurityDescriptor.GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier])
            @($rules | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
        }
    }

    Context 'With -PassThru' {
        It 'Should return the audit entries of a security descriptor, not its access entries' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThru'
            $sd = Get-NTFSSecurityDescriptor -Path $file

            $result = @(Add-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -PassThru)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' }) | Should -HaveCount 1
        }

        It 'Should report the inheritance of the audit entries in InheritanceEnabled, not that of the access entries' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditProtected'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            $sd.SecurityDescriptor.SetAuditRuleProtection($true, $false)

            $result = @(Add-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -PassThru)

            $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeFalse
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_.InheritanceEnabled | Should -BeFalse }
        }
    }
}

Describe 'Remove-NTFSAudit' {
    Context 'With -PassThru' {
        It 'Should return the audit entries of the item, not its access entries' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThru'
            Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
            Add-NTFSAudit -Path $file -Account 'BUILTIN\Users' -AccessRights Delete -InheritanceFlags None -PropagationFlags None

            $result = @(Remove-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -PassThru)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-5-32-545' }) | Should -HaveCount 1
        }
    }
}
