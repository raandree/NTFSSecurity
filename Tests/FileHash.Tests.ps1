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
    $isCore = $PSVersionTable.PSEdition -eq 'Core'
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
    Context 'Algorithms' {
        # Before 5.0.0, the cmdlet failed in PowerShell 7 for every algorithm, because it referenced RIPEMD160.
        It 'Should return the hash of Get-FileHash for <_>' -ForEach @('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5') {
            $result = Get-FileHash2 -Path $first -Algorithm $_

            $result.Hash | Should -BeExactly (Get-FileHash -LiteralPath $first -Algorithm $_).Hash
            $result.Algorithm | Should -Be $_
        }

        It 'Should calculate RIPEMD160 in Windows PowerShell' -Skip:$isCore {
            $expected = [BitConverter]::ToString(
                [System.Security.Cryptography.RIPEMD160]::Create().ComputeHash([IO.File]::ReadAllBytes($first))
            ).Replace('-', '')

            (Get-FileHash2 -Path $first -Algorithm RIPEMD160).Hash | Should -BeExactly $expected
        }

        It 'Should stop with an error that names <_> in PowerShell 7' -Skip:(-not $isCore) -ForEach @('RIPEMD160', 'MACTripleDES') {
            $algorithm = $_

            $hashError = { Get-FileHash2 -Path $first -Algorithm $algorithm -ErrorAction Stop } |
                Should -Throw -ExpectedMessage "*'$algorithm'*Windows PowerShell 5.1*" -PassThru

            $hashError.FullyQualifiedErrorId | Should -BeLike 'HashAlgorithmNotAvailable,*'
        }

        It 'Should warn once that MACTripleDES is deprecated' -Skip:$isCore {
            $results = @(Get-FileHash2 -Path $first, $second -Algorithm MACTripleDES -WarningVariable hashWarnings -WarningAction SilentlyContinue)

            $results | Should -HaveCount 2
            $results[0].Hash | Should -Not -BeNullOrEmpty
            $hashWarnings | Should -HaveCount 1
            $hashWarnings[0].Message | Should -BeLike '*MACTripleDES*random key*deprecated*'
        }
    }
    Context 'When -Path contains a folder' {
        It 'Should skip the folder and hash the files that follow it' {
            $results = @(Get-FileHash2 -Path $first, $folder, $second -ErrorVariable hashErrors -ErrorAction SilentlyContinue)

            $hashErrors | Should -BeNullOrEmpty
            $results.Name | Should -Be @('One.txt', 'Two.txt')
            $results[1].Hash | Should -BeExactly (Get-FileHash -LiteralPath $second -Algorithm SHA256).Hash
        }
    }

    Context 'When a file cannot be read' {
        # Before 5.0.0, the cmdlet wrote a result for the file anyway, with the hash of the previous file.
        It 'Should write an error and no result for the file' {
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
