<#
    Tests Remove-Item2 of the module built in NTFSSecurity\bin\Release.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

Describe 'Remove-Item2' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
        Import-Module -Name $modulePath -Force -ErrorAction Stop
    }

    AfterAll {
        Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
    }

    Context 'When called with -PassThur, the parameter name in 4.2.6 and earlier' {
        BeforeAll {
            $path = Join-Path -Path $TestDrive -ChildPath 'PassThur.txt'
            Set-Content -LiteralPath $path -Value 'Remove-Item2 test'

            $removedItem = Remove-Item2 -Path $path -PassThur
        }

        It 'Should delete the file' {
            $path | Should -Not -Exist
        }

        It 'Should return the deleted file, like -PassThru' {
            $removedItem.Name | Should -BeExactly 'PassThur.txt'
        }
    }
}
