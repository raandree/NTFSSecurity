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
