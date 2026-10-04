<#
    Tests the access cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

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
