<#
    Tests the access cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # With the Restore privilege, Windows may grant writing the DACL despite a deny entry.
    $canBypassWriteDeny = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Access'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSAccess' {
    Context 'When a path fails after a readable path' {
        # Before 5.0.0, the cmdlet wrote the entries of the previous item again for the failing path.
        It 'Should return the entries of the first item once' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Readable' -Directory
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Block-TestReadPermission -Sandbox $sandbox -Path $denied
            $expected = @(Get-NTFSAccess -Path $folder).Count

            $entries = @(Get-NTFSAccess -Path $folder, $denied -ErrorAction SilentlyContinue)

            @($entries | Where-Object -Property FullName -EQ -Value $folder) | Should -HaveCount $expected
        }
    }
}

Describe 'Get-NTFSEffectiveAccess' {
    BeforeAll {
        $effectiveFile = New-TestSandboxItem -Sandbox $sandbox -Name 'Effective'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $effectiveFile
        $acl = Get-Acl -LiteralPath $effectiveFile
        $guests = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-5-32-546'
        $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                    $guests, [System.Security.AccessControl.FileSystemRights]::FullControl,
                    [System.Security.AccessControl.AccessControlType]::Deny
                )))
        Set-Acl -LiteralPath $effectiveFile -AclObject $acl
    }

    It 'Should leave out an account without access when -ExcludeNoneAccessEntries is used' {
        $result = @(Get-NTFSEffectiveAccess -Path $effectiveFile -Account 'S-1-5-32-546' -ExcludeNoneAccessEntries -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -BeNullOrEmpty
    }

    It 'Should return an account with access when -ExcludeNoneAccessEntries is used' {
        $result = @(Get-NTFSEffectiveAccess -Path $effectiveFile -ExcludeNoneAccessEntries -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -HaveCount 1
    }

    It 'Should use the current location when -Path is omitted' {
        $result = @(Get-NTFSEffectiveAccess -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -BeLike ('*\{0}' -f (Split-Path -Path $sandbox -Leaf))
    }

    It 'Should compute the effective access of a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $effectiveFile

        $result = @(Get-NTFSEffectiveAccess -SecurityDescriptor $sd -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $effectiveFile
    }
}

Describe 'Get-NTFSOrphanedAccess' {
    BeforeAll {
        $orphanedFile = New-TestSandboxItem -Sandbox $sandbox -Name 'Orphaned'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $orphanedFile
        $acl = Get-Acl -LiteralPath $orphanedFile
        foreach ($sid in 'S-1-5-21-1-2-3-1001', 'S-1-5-21-1-2-3-1002') {
            $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                        (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $sid),
                        [System.Security.AccessControl.FileSystemRights]::ReadData, [System.Security.AccessControl.AccessControlType]::Allow
                    )))
        }
        Set-Acl -LiteralPath $orphanedFile -AclObject $acl
    }

    It 'Should return the entries whose account cannot be resolved' {
        @(Get-NTFSOrphanedAccess -Path $orphanedFile) | Should -HaveCount 2
    }

    It 'Should return only the entries of -Account' {
        $result = @(Get-NTFSOrphanedAccess -Path $orphanedFile -Account 'S-1-5-21-1-2-3-1002')

        $result | Should -HaveCount 1
        $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-1002'
    }

    It 'Should read the entries of a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $orphanedFile

        $result = @(Get-NTFSOrphanedAccess -SecurityDescriptor $sd)

        $result | Should -HaveCount 2
        $result | ForEach-Object -Process { $_.FullName | Should -Be $orphanedFile }
    }
}

Describe 'Get-NTFSSimpleAccess' {
    BeforeAll {
        $simpleFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'Simple' -Directory
        Assert-TestSandboxPath -Sandbox $sandbox -Path $simpleFolder
        $acl = Get-Acl -LiteralPath $simpleFolder
        $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                    (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-1-0'),
                    [System.Security.AccessControl.FileSystemRights]::ReadData, [System.Security.AccessControl.AccessControlType]::Allow
                )))
        Set-Acl -LiteralPath $simpleFolder -AclObject $acl
    }

    It 'Should return only the entries of -Account' {
        $result = @(Get-NTFSSimpleAccess -Path $simpleFolder -Account 'S-1-1-0' -IncludeRootFolder:$false)

        $result | Should -Not -BeNullOrEmpty
        $result | ForEach-Object -Process { $_.Identity.Sid | Should -Be 'S-1-1-0' }
    }

    It 'Should read the entries of a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $simpleFolder

        $result = @(Get-NTFSSimpleAccess -SecurityDescriptor $sd)

        $result | Should -Not -BeNullOrEmpty
        $result | ForEach-Object -Process { $_.FullName | Should -Be $simpleFolder }
    }

    It 'Should show the entries as a table with the account, the rights, and the type' {
        $text = Get-NTFSSimpleAccess -Path $simpleFolder -IncludeRootFolder:$false | Out-String -Width 200

        $text | Should -Match 'Account\s+Access Rights\s+Type'
    }
}

Describe 'Remove-NTFSAccess' {
    Context 'When a path does not exist' {
        BeforeAll {
            $missing = Join-Path -Path $sandbox -ChildPath 'Missing.txt'
        }

        # Before 5.0.0, the cmdlet went on with the missing item and wrote a second, misleading RemoveAceError.
        It 'Should write only the read error' {
            Remove-NTFSAccess -Path $missing -Account 'Everyone' -AccessRights ReadData -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
        }

        It 'Should not stop with -PassThru' {
            { Remove-NTFSAccess -Path $missing -Account 'Everyone' -AccessRights ReadData -PassThru -ErrorAction SilentlyContinue } |
                Should -Not -Throw
        }
    }

    Context 'When the entries cannot be changed' {
        # Before 5.0.0, -PassThru returned the unchanged entries of the item after the error.
        It 'Should write an error and return nothing with -PassThru' -Skip:$canBypassWriteDeny {
            $protected = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveProtected'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $protected
            Add-NTFSAccess -Path $protected -Account 'Everyone' -AccessRights ReadData
            Block-TestWritePermission -Sandbox $sandbox -Path $protected

            $result = @(Remove-NTFSAccess -Path $protected -Account 'Everyone' -AccessRights ReadData -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'RemoveAceError,*'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'With -RemoveSpecific' {
        BeforeEach {
            $removeFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSpecific' -Directory
            $sd = Get-NTFSSecurityDescriptor -Path $removeFolder
            Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights Modify

            function Get-EveryoneRule {
                $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
            }
        }

        It 'Should keep an entry that does not match exactly' {
            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -RemoveSpecific

            (Get-EveryoneRule).FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Modify) | Should -BeTrue
        }

        It 'Should remove an entry that matches exactly' {
            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights Modify -RemoveSpecific

            Get-EveryoneRule | Should -BeNullOrEmpty
        }

        It 'Should take the rights away from a matching entry without -RemoveSpecific' {
            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

            $rule = Get-EveryoneRule
            $rule | Should -Not -BeNullOrEmpty
            $rule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeFalse
        }
    }
}

Describe 'Add-NTFSAccess' {
    Context 'When the entries cannot be changed' {
        # Before 5.0.0, -PassThru returned the unchanged entries of the item after the error.
        It 'Should write an error and return nothing with -PassThru' -Skip:$canBypassWriteDeny {
            $protected = New-TestSandboxItem -Sandbox $sandbox -Name 'AddProtected'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $protected
            Block-TestWritePermission -Sandbox $sandbox -Path $protected

            $result = @(Add-NTFSAccess -Path $protected -Account 'Everyone' -AccessRights ReadData -PassThru -ErrorVariable addErrors -ErrorAction SilentlyContinue)

            $addErrors | Should -HaveCount 1
            $addErrors[0].FullyQualifiedErrorId | Should -BeLike 'AddAceError,*'
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Security descriptor parameter sets' {
    BeforeAll {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ParameterSets' -Directory
    }

    # Before 5.0.0, PowerShell could not choose between the SDSimple and SDComplex parameter sets.
    It '<_> should accept -SecurityDescriptor without -AppliesTo or the flag parameters' -ForEach @(
        'Add-NTFSAccess', 'Remove-NTFSAccess', 'Add-NTFSAudit', 'Remove-NTFSAudit'
    ) {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        { & $_ -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Add-NTFSAccess should apply the entry to the folder, its subfolders, and files by default' {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

        $rule = $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
        $rule.InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags] 'ContainerInherit, ObjectInherit')
        $rule.PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
    }

    It 'Add-NTFSAccess should still take -AppliesTo for a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -AppliesTo ThisFolderOnly

        $rule = $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
        $rule.InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::None)
    }
}
