<#
    Tests the link cmdlets of the module built in NTFSSecurity\bin\Release in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Links'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'New-NTFSHardLink' {
    It 'Should create a hard link to a file' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'Target'
        $link = Join-Path -Path $sandbox -ChildPath 'Link.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSHardLink -Path $link -Target $target -ErrorAction Stop

        $link | Should -Exist
        Get-Content -LiteralPath $link | Should -Be (Get-Content -LiteralPath $target)
    }

    # Before 5.0.0, the error said "The target path exist" for a target that did not exist.
    It 'Should report that a missing target does not exist' {
        $missing = Join-Path -Path $sandbox -ChildPath 'Missing.txt'
        $link = Join-Path -Path $sandbox -ChildPath 'MissingLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing, $link

        { New-NTFSHardLink -Path $link -Target $missing -ErrorAction Stop } | Should -Throw -ExpectedMessage '*does not exist*'
        $link | Should -Not -Exist
    }
}
