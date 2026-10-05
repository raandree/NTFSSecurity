<#
    Tests Get-FileHash2 of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $isElevated = Test-IsElevated
}

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

    Context 'When a file cannot be read' {
        # Before 5.0.0, the cmdlet wrote a result for the file anyway, with the hash of the previous file.
        It 'Should write an error and no result for the file' {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Set-ItResult -Skipped -Because 'Get-FileHash2 fails in PowerShell 7 until it no longer references RIPEMD160'
            }
            $locked = New-TestSandboxItem -Sandbox $sandbox -Name 'Locked'
            $stream = [IO.File]::Open($locked, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
            try {
                $results = @(Get-FileHash2 -Path $first, $locked -ErrorVariable hashErrors -ErrorAction SilentlyContinue)
            }
            finally {
                $stream.Dispose()
            }

            $hashErrors | Should -HaveCount 1
            $results.Name | Should -Be @('One.txt')
        }
    }

    Context 'When the file cannot be read after taking ownership' {
        # Before 5.0.0, the account that ran the cmdlet stayed the owner when the second attempt failed. Only an
        # elevated process can make another account the owner first, so the test runs in CI.
        It 'Should restore the previous owner' -Skip:(-not $isElevated) {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Set-ItResult -Skipped -Because 'Get-FileHash2 fails in PowerShell 7 until it no longer references RIPEMD160'
            }
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $denied
            Set-NTFSOwner -Path $denied -Account 'S-1-5-32-544'
            Add-NTFSAccess -Path $denied -Account 'S-1-1-0' -AccessRights ReadData -AccessType Deny

            $results = @(Get-FileHash2 -Path $denied -ErrorVariable hashErrors -ErrorAction SilentlyContinue)
            if (-not $hashErrors) {
                Set-ItResult -Inconclusive -Because 'the elevated process could read the file despite the deny entry'
            }

            $hashErrors | Should -HaveCount 1
            $hashErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHashError,*'
            $results | Should -BeNullOrEmpty
            (Get-NTFSOwner -Path $denied).Owner.Sid | Should -Be 'S-1-5-32-544'
        }
    }
}
