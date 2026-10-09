<#
    Tests the cmdlets of the module built in NTFSSecurity\bin\Release on the root folder of the system drive, which they
    only read, and on the root of a drive that maps a folder of a sandbox, which they change.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # The restricted token of the basic-user runner cannot define a drive letter.
    $canMapDrive = Test-DriveMappingAvailable
}

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $root = [IO.Path]::GetPathRoot($env:SystemRoot)
    $sidType = [System.Security.Principal.SecurityIdentifier]
    $acl = Get-Acl -LiteralPath $root
}

AfterAll {
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

# Before 5.0.0-rc4, the cmdlets read the security descriptor of the drive, a device object, instead of that of its root
# folder, so they showed other entries than Explorer, icacls, and Get-Acl (#41).
Describe 'The root folder of a drive' {
    It 'Get-NTFSAccess should return the access entries of the root folder' {
        $expected = @($acl.GetAccessRules($true, $true, $sidType) | ForEach-Object -Process { $_.IdentityReference.Value } | Sort-Object)

        $entries = @(Get-NTFSAccess -Path $root)

        @($entries | ForEach-Object -Process { $_.Account.Sid } | Sort-Object) | Should -Be $expected
    }

    It 'Get-NTFSSecurityDescriptor should read the DACL of the root folder' {
        $sd = Get-NTFSSecurityDescriptor -Path $root

        $sd.SecurityDescriptor.GetSecurityDescriptorSddlForm('Access') | Should -Be $acl.GetSecurityDescriptorSddlForm('Access')
    }

    It 'Get-NTFSOwner should return the owner of the root folder' {
        (Get-NTFSOwner -Path $root).Owner.Sid | Should -Be $acl.GetOwner($sidType).Value
    }

    It 'Get-NTFSAccess should return the access entries of the root folder for the volume name, such as \\?\Volume{GUID}\' {
        # Win32_Volume returns nothing to a user without elevation; mountvol works for every user.
        $volume = (mountvol.exe $root /L | Out-String).Trim()
        $volume | Should -BeLike '\\?\Volume{*}\'
        $expected = @($acl.GetAccessRules($true, $true, $sidType) | ForEach-Object -Process { $_.IdentityReference.Value } | Sort-Object)

        $entries = @(Get-NTFSAccess -Path $volume)

        @($entries | ForEach-Object -Process { $_.Account.Sid } | Sort-Object) | Should -Be $expected
    }
}

# A test must not change the permissions of a volume. A drive letter that subst maps to a folder of a sandbox is the root
# of a drive for Windows and for the module, so the code that changes the root folder of a drive changes that folder.
Describe 'Changing the root folder of a drive' -Skip:(-not $canMapDrive) {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
        $sandbox = New-TestSandbox -Name 'DriveRootChange'
        $mapped = New-TestSandboxItem -Sandbox $sandbox -Name 'Mapped' -Directory
        $driveRoot = New-TestDriveMapping -Sandbox $sandbox -Path $mapped
        if (-not $driveRoot) {
            throw 'No drive letter could be mapped to the sandbox folder.'
        }

        function Get-MappedEntry {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseSingularNouns', '', Justification = 'The helper returns the explicit entries of the folder.'
            )]
            param ([string] $Account)

            @((Get-Acl -LiteralPath $mapped).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq $Account })
        }
    }

    AfterAll {
        if ($driveRoot) {
            Remove-TestDriveMapping -Root $driveRoot
        }
        Remove-TestSandbox -Sandbox $sandbox
    }

    It 'Should read the access entries of the folder that the drive maps' {
        $expected = @((Get-Acl -LiteralPath $mapped).GetAccessRules($true, $true, $sidType) |
                ForEach-Object -Process { $_.IdentityReference.Value } | Sort-Object)

        $entries = @(Get-NTFSAccess -Path $driveRoot)

        @($entries | ForEach-Object -Process { $_.Account.Sid } | Sort-Object) | Should -Be $expected
    }

    It 'Should add and remove an access entry of the folder that the drive maps' {
        Add-NTFSAccess -Path $driveRoot -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop

        Get-MappedEntry -Account 'S-1-1-0' | Should -HaveCount 1

        Remove-NTFSAccess -Path $driveRoot -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop

        Get-MappedEntry -Account 'S-1-1-0' | Should -BeNullOrEmpty
    }

    It 'Should block and restore the access inheritance of the folder that the drive maps' {
        Disable-NTFSAccessInheritance -Path $driveRoot -ErrorAction Stop

        (Get-Acl -LiteralPath $mapped).AreAccessRulesProtected | Should -BeTrue

        Enable-NTFSAccessInheritance -Path $driveRoot -ErrorAction Stop

        (Get-Acl -LiteralPath $mapped).AreAccessRulesProtected | Should -BeFalse
    }
}
