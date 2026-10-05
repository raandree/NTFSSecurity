<#
    Tests Get-FileHash2 of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'FileHash'
    Push-Location -LiteralPath $sandbox

    $folder = Join-Path -Path $sandbox -ChildPath 'Folder'
    $first = Join-Path -Path $sandbox -ChildPath 'One.txt'
    $second = Join-Path -Path $sandbox -ChildPath 'Two.txt'
    Assert-TestSandboxPath -Sandbox $sandbox -Path $folder, $first, $second
    New-Item -ItemType Directory -Path $folder | Out-Null
    Set-Content -LiteralPath $first -Value 'One'
    Set-Content -LiteralPath $second -Value 'Two'
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-FileHash2' {
    Context 'When -Path contains a folder' {
        It 'Should skip the folder and hash the files that follow it' {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Set-ItResult -Skipped -Because 'Get-FileHash2 fails in PowerShell 7 until it no longer references RIPEMD160'
            }

            $results = @(Get-FileHash2 -Path $first, $folder, $second -ErrorVariable hashErrors -ErrorAction SilentlyContinue)

            $hashErrors | Should -BeNullOrEmpty
            $results.Name | Should -Be @('One.txt', 'Two.txt')
            $results[1].Hash | Should -BeExactly (Get-FileHash -LiteralPath $second -Algorithm SHA256).Hash
        }
    }
}
