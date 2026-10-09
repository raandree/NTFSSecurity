<#
    Tests Gallery publication recovery offline. Every network and publication command is mocked; the fake API key
    exists only in the test process and is restored afterwards. Package hashes come from a sandbox file.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $sandbox = New-TestSandbox -Name 'PublishPackage'
    $package = Join-Path -Path $sandbox -ChildPath 'NTFSSecurity.5.0.0-rc7.nupkg'
    Assert-TestSandboxPath -Sandbox $sandbox -Path $package
    [IO.File]::WriteAllBytes($package, [Text.Encoding]::UTF8.GetBytes('The package that CI built.'))
    $sha512 = [Security.Cryptography.SHA512]::Create()
    try { $hash = [Convert]::ToBase64String($sha512.ComputeHash([IO.File]::ReadAllBytes($package))) }
    finally { $sha512.Dispose() }
    $metadata = [pscustomobject]@{ entry = [pscustomobject]@{ properties = [pscustomobject]@{
                Id = 'NTFSSecurity'; Version = '5.0.0-rc7'; PackageHashAlgorithm = 'SHA512'; PackageHash = $hash
            } } }
    $published = [pscustomobject]@{ Name = 'NTFSSecurity'; Version = [version]'5.0.0'; Prerelease = 'rc7' }
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '..\.github\scripts\Publish-ModulePackage.ps1'
    $originalKey = $env:PSGALLERY_API_KEY

    # Stubs keep these tests available in Windows PowerShell, where PSResourceGet might not be installed.
    function Find-PSResource {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '', Justification = 'Command stub supplies parameter metadata for Pester mocks.'
        )]
        [CmdletBinding()]
        param ([string] $Name, [string] $Version, [switch] $Prerelease, [string] $Repository)
        throw 'Find-PSResource must be mocked in this test.'
    }
    function Publish-PSResource {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter', '', Justification = 'Command stub supplies parameter metadata for Pester mocks.'
        )]
        [CmdletBinding()]
        param ([string] $NupkgPath, [string] $Repository, [string] $ApiKey)
        throw 'Publish-PSResource must be mocked in this test.'
    }
}

AfterAll {
    $env:PSGALLERY_API_KEY = $originalKey
    Remove-TestSandbox -Sandbox $sandbox
}

Describe 'Publish-ModulePackage.ps1' {
    BeforeEach {
        $env:PSGALLERY_API_KEY = 'test-only-api-key'
        Mock -CommandName Find-PSResource
        Mock -CommandName Publish-PSResource
        Mock -CommandName Invoke-RestMethod -MockWith { $metadata }
    }

    It 'Should publish a new version using the environment key and the verified package path' {
        & $scriptPath -NupkgPath $package -Version '5.0.0-rc7'

        Should -Invoke -CommandName Publish-PSResource -Times 1 -Exactly -ParameterFilter {
            $NupkgPath -eq $package -and $Repository -eq 'PSGallery' -and $ApiKey -eq 'test-only-api-key'
        }
    }

    It 'Should skip publication only after checking the existing package hash' {
        Mock -CommandName Find-PSResource -MockWith { $published }

        & $scriptPath -NupkgPath $package -Version '5.0.0-rc7'

        Should -Invoke -CommandName Publish-PSResource -Times 0 -Exactly
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq "https://www.powershellgallery.com/api/v2/Packages(Id='NTFSSecurity',Version='5.0.0-rc7')"
        }
    }

    It 'Should refuse an existing version containing a different package' {
        Mock -CommandName Find-PSResource -MockWith { $published }
        Mock -CommandName Invoke-RestMethod -MockWith {
            [pscustomobject]@{ entry = [pscustomobject]@{ properties = [pscustomobject]@{ PackageHashAlgorithm = 'SHA512'; PackageHash = 'different-package' } } }
        }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' } | Should -Throw -ExpectedMessage '*different package*'
        Should -Invoke -CommandName Publish-PSResource -Times 0 -Exactly
    }

    It 'Should refuse metadata without a usable SHA512 package hash: <Case>' -ForEach @(
        @{ Case = 'missing hash'; Algorithm = 'SHA512'; PackageHash = '' }
        @{ Case = 'wrong algorithm'; Algorithm = 'SHA256'; PackageHash = 'not-sha512' }
    ) {
        Mock -CommandName Find-PSResource -MockWith { $published }
        Mock -CommandName Invoke-RestMethod -MockWith {
            [pscustomobject]@{ entry = [pscustomobject]@{ properties = [pscustomobject]@{ PackageHashAlgorithm = $Algorithm; PackageHash = $PackageHash } } }
        }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' } | Should -Throw -ExpectedMessage '*SHA512*'
        Should -Invoke -CommandName Publish-PSResource -Times 0 -Exactly
    }

    It 'Should recover an uncertain upload only when the exact package appears in the Gallery' {
        $script:lookups = 0
        Mock -CommandName Find-PSResource -MockWith { $script:lookups++; if ($script:lookups -gt 1) { $published } }
        Mock -CommandName Publish-PSResource -MockWith { throw '409: a package with this version already exists.' }

        & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' -WarningVariable uploadWarnings -WarningAction SilentlyContinue

        Should -Invoke -CommandName Publish-PSResource -Times 1 -Exactly
        Should -Invoke -CommandName Find-PSResource -Times 2 -Exactly
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly
        $uploadWarnings | Should -HaveCount 1
        $uploadWarnings[0].Message | Should -BeLike '*verified*exact package*'
    }

    It 'Should preserve the upload error when the version remains absent' {
        Mock -CommandName Publish-PSResource -MockWith { throw 'Upload failed: the server is unavailable.' }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' } | Should -Throw -ExpectedMessage '*Upload failed: the server is unavailable*'
        Should -Invoke -CommandName Publish-PSResource -Times 1 -Exactly
        Should -Invoke -CommandName Find-PSResource -Times 2 -Exactly
    }

    It 'Should preserve the upload error when verification finds a different package' {
        $script:lookups = 0
        Mock -CommandName Find-PSResource -MockWith { $script:lookups++; if ($script:lookups -gt 1) { $published } }
        Mock -CommandName Publish-PSResource -MockWith { throw 'Upload failed: version collision.' }
        Mock -CommandName Invoke-RestMethod -MockWith {
            [pscustomobject]@{ entry = [pscustomobject]@{ properties = [pscustomobject]@{ PackageHashAlgorithm = 'SHA512'; PackageHash = 'different-package' } } }
        }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' -WarningAction SilentlyContinue } | Should -Throw -ExpectedMessage '*Upload failed: version collision*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly
    }

    It 'Should not publish after a lookup fails for a reason other than a missing version' {
        Mock -CommandName Find-PSResource -MockWith { Write-Error -Message 'Lookup failed.' -ErrorId RepositoryUnavailable }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' } | Should -Throw -ExpectedMessage '*Lookup failed*'
        Should -Invoke -CommandName Publish-PSResource -Times 0 -Exactly
    }

    It 'Should compare Base64 hashes case-sensitively' {
        Mock -CommandName Find-PSResource -MockWith { $published }
        $differentCase = $hash.ToLowerInvariant()
        ($hash -ceq $differentCase) | Should -BeFalse
        Mock -CommandName Invoke-RestMethod -MockWith {
            [pscustomobject]@{ entry = [pscustomobject]@{ properties = [pscustomobject]@{ PackageHashAlgorithm = 'SHA512'; PackageHash = $differentCase } } }
        }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' } | Should -Throw -ExpectedMessage '*different package*'
        Should -Invoke -CommandName Publish-PSResource -Times 0 -Exactly
    }

    It 'Should preserve the upload error when post-upload metadata is unavailable' {
        $script:lookups = 0
        Mock -CommandName Find-PSResource -MockWith { $script:lookups++; if ($script:lookups -gt 1) { $published } }
        Mock -CommandName Publish-PSResource -MockWith { throw 'Upload failed: original error.' }
        Mock -CommandName Invoke-RestMethod -MockWith { throw 'Metadata is unavailable.' }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' -WarningAction SilentlyContinue } | Should -Throw -ExpectedMessage '*Upload failed: original error*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly
    }

    It 'Should preserve the upload error when the post-upload lookup fails' {
        $script:lookups = 0
        Mock -CommandName Find-PSResource -MockWith {
            $script:lookups++
            if ($script:lookups -gt 1) { Write-Error -Message 'Post-upload lookup failed.' -ErrorId RepositoryUnavailable }
        }
        Mock -CommandName Publish-PSResource -MockWith { throw 'Upload failed: original error.' }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' -WarningAction SilentlyContinue } | Should -Throw -ExpectedMessage '*Upload failed: original error*'
        Should -Invoke -CommandName Find-PSResource -Times 2 -Exactly
    }
    It 'Should allow the expected PackageNotFound probe result before publishing' {
        Mock -CommandName Find-PSResource -MockWith { Write-Error -Message 'Not published yet.' -ErrorId PackageNotFound }

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' } | Should -Not -Throw
        Should -Invoke -CommandName Publish-PSResource -Times 1 -Exactly
    }

    It 'Should reject a missing API key before contacting the Gallery' {
        $env:PSGALLERY_API_KEY = $null

        { & $scriptPath -NupkgPath $package -Version '5.0.0-rc7' } | Should -Throw -ExpectedMessage '*PSGALLERY_API_KEY*not set*'
        Should -Invoke -CommandName Find-PSResource -Times 0 -Exactly
        Should -Invoke -CommandName Publish-PSResource -Times 0 -Exactly
    }
}
