<#
    Tests the output types of the cmdlets of the module built in NTFSSecurity\bin\Release: the [OutputType] that
    Get-Command reports, and the objects that -PassThru writes. Tests that need a privilege skip without it and run
    in CI, whose runners are elevated.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $holdsBackupPrivilege = Test-PrivilegeHeld -Name 'SeBackupPrivilege'
    $canCreateSymbolicLinks = Test-PrivilegeHeld -Name 'SeCreateSymbolicLinkPrivilege'

    $itemTypes = @('Alphaleonis.Win32.Filesystem.FileInfo', 'Alphaleonis.Win32.Filesystem.DirectoryInfo')
    $declaredTypes = @(
        @{ Name = 'Test-Path2'; Types = @('System.Boolean') }
        @{ Name = 'Get-FileHash2'; Types = @('Alphaleonis.Win32.Filesystem.FileInfo+Hash') }
        @{ Name = 'Add-NTFSAudit'; Types = @('Security2.FileSystemAuditRule2') }
        @{ Name = 'Remove-NTFSAudit'; Types = @('Security2.FileSystemAuditRule2') }
        @{ Name = 'Copy-Item2'; Types = $itemTypes }
        @{ Name = 'Move-Item2'; Types = $itemTypes }
        @{ Name = 'Remove-Item2'; Types = $itemTypes }
        @{ Name = 'Enable-NTFSAccessInheritance'; Types = @('Security2.FileSystemInheritanceInfo') }
        @{ Name = 'Disable-NTFSAccessInheritance'; Types = @('Security2.FileSystemInheritanceInfo') }
        @{ Name = 'Enable-NTFSAuditInheritance'; Types = @('Security2.FileSystemInheritanceInfo') }
        @{ Name = 'Disable-NTFSAuditInheritance'; Types = @('Security2.FileSystemInheritanceInfo') }
        @{ Name = 'Set-NTFSInheritance'; Types = @('Security2.FileSystemInheritanceInfo') }
    )
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'OutputTypes'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Declared output types' {
    It '<Name> should declare the type of the objects it writes' -ForEach $declaredTypes {
        @((Get-Command -Name $Name).OutputType.Name) | Should -Be $Types
    }

    # Before 5.0.0-rc4, Get-FileHash2 declared the AlphaFS FileInfo, although it writes objects with the type name
    # that its format view uses (#111).
    It 'Get-FileHash2 should declare the type name of the objects it writes' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Hash'

        $result = Get-FileHash2 -Path $file

        $result.PSObject.TypeNames[0] | Should -Be @((Get-Command -Name Get-FileHash2).OutputType.Name)[0]
    }
}

Describe 'Privilege cmdlets with -PassThru' {
    AfterEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    # Before 5.0.0, -PassThru wrote the privileges as one collection.
    It 'Enable-Privileges should write one object per privilege' {
        $result = @(Enable-Privileges -PassThru -ErrorAction SilentlyContinue)

        $result.Count | Should -BeGreaterThan 1
        $result | ForEach-Object -Process { $_ | Should -BeOfType [ProcessPrivileges.PrivilegeAndAttributes] }
    }

    It 'Disable-Privileges should write one object per privilege' -Skip:(-not $holdsBackupPrivilege) {
        Enable-Privileges -ErrorAction SilentlyContinue

        $result = @(Disable-Privileges -PassThru -WarningAction SilentlyContinue)

        $result.Count | Should -BeGreaterThan 1
        $result | ForEach-Object -Process { $_ | Should -BeOfType [ProcessPrivileges.PrivilegeAndAttributes] }
    }
}

Describe 'New-NTFSSymbolicLink with -PassThru' {
    # Before 5.0.0, the cmdlet returned a file object for a link to a folder as well.
    It 'Should return a folder object for a link to a folder' -Skip:(-not $canCreateSymbolicLinks) {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Target' -Directory
        $link = Join-Path -Path $sandbox -ChildPath 'FolderLink'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $result = New-NTFSSymbolicLink -Path $link -Target $folder -PassThru

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
    }
}

Describe 'Cmdlet classes' {
    # Before 5.0.0, these classes declared members that nothing used.
    It '<_> should declare no Path property, which was never a parameter' -ForEach @(
        'Enable-Privileges', 'Disable-Privileges', 'Get-Privileges'
    ) {
        (Get-Command -Name $_).ImplementingType.GetProperty('Path') | Should -BeNullOrEmpty
    }

    It 'Remove-Item2 should declare no filter field' {
        $flags = [System.Reflection.BindingFlags]'NonPublic, Instance'

        (Get-Command -Name 'Remove-Item2').ImplementingType.GetField('filter', $flags) | Should -BeNullOrEmpty
    }
}
