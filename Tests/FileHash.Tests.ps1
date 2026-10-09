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

        # PowerShell binds only the named algorithms to -Algorithm, so a program that calls the public method with an
        # undefined value is the only way to get here.
        It 'Should refuse an algorithm that the enumeration does not define when the public method creates it' {
            $unknown = [Enum]::ToObject([Security2.FileSystem.FileInfo.HashAlgorithms], 99)

            $failure = { [Security2.FileSystem.FileInfo.Extensions]::CreateHashAlgorithm($unknown) } | Should -Throw -PassThru

            $failure.Exception.GetBaseException() | Should -BeOfType [System.ArgumentOutOfRangeException]
            $failure.Exception.GetBaseException().ParamName | Should -BeExactly 'algorithm'
        }

        It 'Should warn once that MACTripleDES is deprecated' -Skip:$isCore {
            $results = @(Get-FileHash2 -Path $first, $second -Algorithm MACTripleDES -WarningVariable hashWarnings -WarningAction SilentlyContinue)

            $results | Should -HaveCount 2
            $results[0].Hash | Should -Not -BeNullOrEmpty
            $hashWarnings | Should -HaveCount 1
            $hashWarnings[0].Message | Should -BeLike '*MACTripleDES*random key*deprecated*'
        }

        # PowerShell calls the cmdlet once for each object in the pipeline; the warning belongs to the command.
        It 'Should warn once that MACTripleDES is deprecated for several objects in the pipeline' -Skip:$isCore {
            $results = @($first, $second | Get-FileHash2 -Algorithm MACTripleDES -WarningVariable hashWarnings -WarningAction SilentlyContinue)

            $results | Should -HaveCount 2
            $hashWarnings | Should -HaveCount 1
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
        BeforeAll {
            $privateData = (Get-Module -Name NTFSSecurity).PrivateData
            $enablePrivileges = $privateData['EnablePrivileges']
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Disable automatic privileges so that the deny entry reaches the ownership retry even in an elevated process.
        # Administrators is an assignable owner for that process, unlike TrustedInstaller.
        It 'Should restore the previous owner' -Skip:(-not $isElevated) {
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $denied
            Set-NTFSOwner -Path $denied -Account 'S-1-5-32-544'
            Add-NTFSAccess -Path $denied -Account 'S-1-1-0' -AccessRights ReadData -AccessType Deny

            $results = @(Get-FileHash2 -Path $denied -ErrorVariable hashErrors -ErrorAction SilentlyContinue)

            $hashErrors | Should -HaveCount 1
            $hashErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHashError,*'
            $results | Should -BeNullOrEmpty
            (Get-NTFSOwner -Path $denied).Owner.Sid | Should -Be 'S-1-5-32-544'
        }

        It 'Should report both the failed read and the failed owner restoration without returning a hash' -Skip:(-not $isElevated) {
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'RestoreDenied'
            Add-TestDenyRule -Sandbox $sandbox -Path $denied -Rights @{ 'S-1-1-0' = 'ReadData' }
            $originalOwner = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
            Set-TestOwner -Sandbox $sandbox -Path $denied -Sid $originalOwner
            (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Restore').PrivilegeState | Should -Be 'Disabled'

            $result = @(Get-FileHash2 -Path $denied -ErrorVariable hashErrors -ErrorAction SilentlyContinue)

            $result | Should -BeNullOrEmpty
            $hashErrors | Should -HaveCount 2
            $hashErrors[0].FullyQualifiedErrorId | Should -BeLike 'RestoreOwnerError,*'
            $hashErrors[1].FullyQualifiedErrorId | Should -BeLike 'GetHashError,*'
            $hashErrors | ForEach-Object -Process { $_.TargetObject | Should -Be $denied }
            (Get-NTFSOwner -Path $denied).Owner.Sid | Should -Be ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
        }
    }
}
