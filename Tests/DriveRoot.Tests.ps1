<#
    Tests the cmdlets of the module built in NTFSSecurity\bin\Release on the root folder of the system drive. The tests
    only read, so they need no sandbox.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

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
