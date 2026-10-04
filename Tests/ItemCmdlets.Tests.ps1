<#
    Tests the long-path item cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'ItemCmdlets'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ChildItem2' {
    Context 'When -Path is a file' {
        BeforeAll {
            $folder = Join-Path -Path $sandbox -ChildPath 'ChildItem'
            $file = Join-Path -Path $folder -ChildPath 'File.txt'
            $other = Join-Path -Path $folder -ChildPath 'Folder\Other.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $folder, $file, $other
            New-Item -ItemType Directory -Path (Split-Path -Path $other -Parent) -Force | Out-Null
            Set-Content -LiteralPath $file -Value 'File'
            Set-Content -LiteralPath $other -Value 'Other'
        }

        It 'Should return the file itself, like Get-ChildItem' {
            $items = @(Get-ChildItem2 -Path $file -ErrorVariable childItemErrors -ErrorAction SilentlyContinue)

            $childItemErrors | Should -BeNullOrEmpty
            $items | Should -HaveCount 1
            $items[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
            $items[0].Name | Should -BeExactly 'File.txt'
        }

        It 'Should continue with the next path after a file' {
            $items = @(Get-ChildItem2 -Path $file, (Join-Path -Path $folder -ChildPath 'Folder') -ErrorAction SilentlyContinue)

            $items.Name | Should -Be @('File.txt', 'Other.txt')
        }

        It 'Should return nothing for a file with -Directory' {
            $items = @(Get-ChildItem2 -Path $file -Directory -ErrorVariable childItemErrors -ErrorAction SilentlyContinue)

            $childItemErrors | Should -BeNullOrEmpty
            $items | Should -BeNullOrEmpty
        }
    }
}
