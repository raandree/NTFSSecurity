<#
    Tests Get-NTFSSecurityDescriptor and Set-NTFSSecurityDescriptor of the module built in NTFSSecurity\bin\Release on
    files in a sandbox folder. Tests that need the Security or the Restore privilege skip without it; CI runs them
    elevated.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $holdsSecurityPrivilege = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    # Assigning an owner other than the user or one of its groups needs the Restore privilege.
    $canAssignAnyOwner = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'SecurityDescriptor'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']
    $sidType = [System.Security.Principal.SecurityIdentifier]
    # An owner that the user can assign only with the Restore privilege
    $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'

    function Get-RestorePrivilegeState {
        (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState
    }

    function Get-EveryoneRule ([string] $Path) {
        (Get-Acl -LiteralPath $Path).GetAccessRules($true, $false, $sidType) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSSecurityDescriptor' {
    # Before 5.0.0-rc3, the cmdlet read the DACL together with the SACL when the process held the Security privilege.
    # When the folder has no SACL, Windows then returns the inherited entries of a DACL without the auto-inherit flag,
    # such as that of a file in the temp folder of the user, without their inherited flag.
    It 'Should report the inherited access entries as inherited' -Skip:(-not $holdsSecurityPrivilege) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Inherited'
        $inheritedCount = @((Get-Acl -LiteralPath $file).GetAccessRules($false, $true, $sidType)).Count
        $inheritedCount | Should -BeGreaterThan 0

        $sd = Get-NTFSSecurityDescriptor -Path $file

        @($sd.SecurityDescriptor.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
        @($sd.SecurityDescriptor.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $inheritedCount
    }

    It 'Should read the owner and the audit entries with the access entries' -Skip:(-not $holdsSecurityPrivilege) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Sections'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        Add-NTFSAudit -Path $file -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None

        $sd = Get-NTFSSecurityDescriptor -Path $file

        $sd.SecurityDescriptor.GetOwner($sidType).Value | Should -Be (Get-Acl -LiteralPath $file).GetOwner($sidType).Value
        @($sd.SecurityDescriptor.GetAuditRules($true, $false, $sidType)) | Should -HaveCount 1
    }
}

Describe 'Set-NTFSSecurityDescriptor' {
    Context 'When a cmdlet added an access entry to the descriptor' {
        It 'Should write the entry as the only explicit entry of the item' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddedEntry'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd

            @(Get-EveryoneRule -Path $file) | Should -HaveCount 1
            @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType)) | Should -HaveCount 1
        }
    }

    Context 'When the item has an owner that the user cannot assign' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0-rc3, the cmdlet wrote every section that Get-NTFSSecurityDescriptor read, also the unchanged
        # owner, which Windows refuses without the Restore privilege, like a file server that refuses the owner (#34).
        It 'Should write an added access entry and keep the owner' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OtherOwner'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorVariable setErrors -ErrorAction SilentlyContinue

            $setErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
            @(Get-EveryoneRule -Path $file) | Should -HaveCount 1
        }

        It 'Should write an added audit entry and keep the owner' -Skip:(-not ($holdsSecurityPrivilege -and $canAssignAnyOwner)) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OtherOwnerAudit'
            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller
            Get-RestorePrivilegeState | Should -Be 'Disabled'
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAudit -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorVariable setErrors -ErrorAction SilentlyContinue

            $setErrors | Should -BeNullOrEmpty
            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
            @(Get-NTFSAudit -Path $file -ExcludeInherited) | Should -HaveCount 1
        }
    }

    Context 'When the descriptor has sections that it did not change' {
        # Before 5.0.0-rc3, the cmdlet wrote every section that Get-NTFSSecurityDescriptor read, so it also undid the
        # changes that were made to the item after it was read.
        It 'Should not write back the access entries of an unchanged descriptor' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Unchanged'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            $acl = Get-Acl -LiteralPath $file
            $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                        (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-1-0'),
                        [System.Security.AccessControl.FileSystemRights]::ReadData, [System.Security.AccessControl.AccessControlType]::Allow
                    )))
            Set-Acl -LiteralPath $file -AclObject $acl

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd

            @(Get-EveryoneRule -Path $file) | Should -HaveCount 1
        }

        It 'Should write the owner when only the owner changed' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NewOwner'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            $sd.SecurityDescriptor.SetOwner((New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $trustedInstaller))

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd

            (Get-Acl -LiteralPath $file).GetOwner($sidType).Value | Should -Be $trustedInstaller
        }
    }

    Context 'With -Verbose' {
        It 'Should name the sections that it writes' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'VerboseChanged'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            $messages = Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -Verbose 4>&1

            $messages.Message | Should -Contain "Writing the changed sections of the security descriptor of '$($sd.FullName)': Access"
        }

        It 'Should say that it writes nothing for an unchanged descriptor' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'VerboseUnchanged'
            $sd = Get-NTFSSecurityDescriptor -Path $file

            $messages = Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -Verbose 4>&1

            $messages.Message |
                Should -Contain "No section of the security descriptor of '$($sd.FullName)' changed since it was read or last written; nothing is written"
        }
    }
}
