<#
    Tests the release scripts in .github\scripts: Get-ReleaseInfo.ps1, which reads the version of the module and its
    release notes, and New-ModulePackage.ps1, which builds the packages from the module built in
    NTFSSecurity\bin\Release.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'The test helpers write only to TestDrive.'
)]
param ()

BeforeDiscovery {
    # Compress-PSResource is part of Microsoft.PowerShell.PSResourceGet, which comes with PowerShell 7.4 and later.
    $canPackage = [bool](Get-Command -Name Compress-PSResource -ErrorAction SilentlyContinue)
}

Describe 'Get-ReleaseInfo.ps1' {
    BeforeAll {
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '..\.github\scripts\Get-ReleaseInfo.ps1'
        $manifestPath = Join-Path -Path $TestDrive -ChildPath 'Module.psd1'

        function Set-TestManifest {
            param (
                [Parameter(Mandatory)]
                [string]
                $Version,

                [Parameter()]
                [string]
                $Prerelease
            )

            $psData = if ($Prerelease) { "Prerelease = '$Prerelease'" } else { '' }
            Set-Content -LiteralPath $manifestPath -Value "@{ ModuleVersion = '$Version'; PrivateData = @{ PSData = @{ $psData } } }"
        }

        $changelogPath = Join-Path -Path $TestDrive -ChildPath 'CHANGELOG.md'
        Set-Content -LiteralPath $changelogPath -Value @'
# Changelog

## [Unreleased]

### Fixed

- Fix a thing

## [2.0.0] - 2026-01-02

### Changed

- Change a thing

## [1.0.0]

### Added

- Add a thing

[Unreleased]: https://example.com/compare/2.0.0...HEAD
[2.0.0]: https://example.com/compare/1.0.0...2.0.0
'@

        $releasedChangelogPath = Join-Path -Path $TestDrive -ChildPath 'CHANGELOG-released.md'
        Set-Content -LiteralPath $releasedChangelogPath -Value @'
# Changelog

## [Unreleased]

## [2.0.0] - 2026-01-02

### Changed

- Change a thing

[Unreleased]: https://example.com/compare/2.0.0...HEAD
[2.0.0]: https://example.com/compare/1.0.0...2.0.0
'@
    }

    Context 'When the module manifest has no prerelease label' {
        It 'Should return the version, the release date, and the notes of its section' {
            Set-TestManifest -Version '2.0.0'

            $release = & $scriptPath -ManifestPath $manifestPath -ChangelogPath $changelogPath

            $release.Version | Should -BeExactly '2.0.0'
            $release.IsPrerelease | Should -BeFalse
            $release.Date | Should -Be ([datetime] '2026-01-02')
            $release.Notes | Should -BeExactly "### Changed`n`n- Change a thing"
        }

        It 'Should not include the link definitions after the last section in the notes' {
            Set-TestManifest -Version '2.0.0'

            $release = & $scriptPath -ManifestPath $manifestPath -ChangelogPath $releasedChangelogPath

            $release.Notes | Should -BeExactly "### Changed`n`n- Change a thing"
        }

        It 'Should fail if the section of the version has no release date' {
            Set-TestManifest -Version '1.0.0'

            { & $scriptPath -ManifestPath $manifestPath -ChangelogPath $changelogPath } | Should -Throw '*1.0.0*date*'
        }

        It 'Should fail if CHANGELOG.md has no section for the version' {
            Set-TestManifest -Version '3.0.0'

            { & $scriptPath -ManifestPath $manifestPath -ChangelogPath $changelogPath } | Should -Throw '*3.0.0*'
        }
    }

    Context 'When the module manifest has a prerelease label' {
        It 'Should return the prerelease version and the notes of the Unreleased section' {
            Set-TestManifest -Version '3.0.0' -Prerelease 'rc1'

            $release = & $scriptPath -ManifestPath $manifestPath -ChangelogPath $changelogPath

            $release.Version | Should -BeExactly '3.0.0-rc1'
            $release.IsPrerelease | Should -BeTrue
            $release.Date | Should -BeNullOrEmpty
            $release.Notes | Should -BeExactly "### Fixed`n`n- Fix a thing"
        }

        It 'Should fail if the Unreleased section is empty' {
            Set-TestManifest -Version '3.0.0' -Prerelease 'rc1'

            { & $scriptPath -ManifestPath $manifestPath -ChangelogPath $releasedChangelogPath } |
                Should -Throw '*Unreleased*'
        }

        It 'Should fail if CHANGELOG.md already has a section for the version' {
            Set-TestManifest -Version '2.0.0' -Prerelease 'rc1'

            { & $scriptPath -ManifestPath $manifestPath -ChangelogPath $changelogPath } | Should -Throw '*2.0.0*'
        }

        It 'Should fail if the label is not valid in the PowerShell Gallery' {
            Set-TestManifest -Version '3.0.0' -Prerelease 'rc.1'

            { & $scriptPath -ManifestPath $manifestPath -ChangelogPath $changelogPath } | Should -Throw '*rc.1*'
        }
    }

    Context 'When it reads the module manifest and CHANGELOG.md of the repository' {
        It 'Should return release notes for the version of the module manifest' {
            $repositoryPath = Join-Path -Path $PSScriptRoot -ChildPath '..'
            $sourceManifestPath = Join-Path -Path $repositoryPath -ChildPath 'NTFSSecurity\NTFSSecurity.psd1'
            $manifest = Import-PowerShellDataFile -LiteralPath $sourceManifestPath

            $release = & $scriptPath -ManifestPath $sourceManifestPath -ChangelogPath (Join-Path -Path $repositoryPath -ChildPath 'CHANGELOG.md')

            $release.Version | Should -BeLike "$($manifest.ModuleVersion)*"
            $release.Notes | Should -Not -BeNullOrEmpty
            $release.Notes | Should -Not -Match '(?m)^\[[^\]]+\]: '
        }
    }
}

Describe 'New-ModulePackage.ps1' -Skip:(-not $canPackage) {
    BeforeAll {
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '..\.github\scripts\New-ModulePackage.ps1'
        $buildPath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release'
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $buildPath -ChildPath 'NTFSSecurity.psd1')
        $version = $manifest.ModuleVersion
        if ($manifest.PrivateData.PSData.Prerelease) {
            $version = '{0}-{1}' -f $version, $manifest.PrivateData.PSData.Prerelease
        }
        $expectedFiles = @($manifest.FileList | ForEach-Object -Process { $_ -replace '\\', '/' } | Sort-Object)

        function Get-ZipEntryName {
            param (
                [Parameter(Mandatory)]
                [string]
                $Path
            )

            $zip = [IO.Compression.ZipFile]::OpenRead($Path)
            try {
                $zip.Entries | Where-Object -Property Name | ForEach-Object -Process { $_.FullName }
            } finally {
                $zip.Dispose()
            }
        }

        $package = & $scriptPath -BuildPath $buildPath -DestinationPath (Join-Path -Path $TestDrive -ChildPath 'out')
    }

    It 'Should copy exactly the files of the FileList into the module folder' {
        $files = Get-ChildItem -LiteralPath $package.ModulePath -Recurse -File |
            ForEach-Object -Process { $_.FullName.Substring($package.ModulePath.Length + 1) -replace '\\', '/' }

        ($files | Sort-Object) -join ', ' | Should -BeExactly ($expectedFiles -join ', ')
    }

    It 'Should name the NuGet package after the version, including the prerelease label' {
        Split-Path -Path $package.PackagePath -Leaf | Should -BeExactly "NTFSSecurity.$version.nupkg"
        $package.Version | Should -BeExactly $version
    }

    It 'Should put exactly the module files into the NuGet package' {
        $entries = Get-ZipEntryName -Path $package.PackagePath |
            Where-Object -FilterScript { $_ -notmatch '^(_rels/|package/|\[Content_Types\]\.xml$|NTFSSecurity\.nuspec$)' }

        ($entries | Sort-Object) -join ', ' | Should -BeExactly ($expectedFiles -join ', ')
    }

    It 'Should set the version and the link to the release notes in the NuGet package' {
        $zip = [IO.Compression.ZipFile]::OpenRead($package.PackagePath)
        try {
            $reader = New-Object -TypeName 'System.IO.StreamReader' -ArgumentList $zip.GetEntry('NTFSSecurity.nuspec').Open()
            $nuspec = [xml] $reader.ReadToEnd()
            $reader.Dispose()
        } finally {
            $zip.Dispose()
        }

        $nuspec.package.metadata.version | Should -BeExactly $version
        $nuspec.package.metadata.releaseNotes | Should -Match 'https://github\.com/raandree/NTFSSecurity/blob/master/CHANGELOG\.md'
    }

    It 'Should tag the NuGet package with its cmdlets, which the PowerShell Gallery lists and Find-Command searches' {
        $zip = [IO.Compression.ZipFile]::OpenRead($package.PackagePath)
        try {
            $reader = New-Object -TypeName 'System.IO.StreamReader' -ArgumentList $zip.GetEntry('NTFSSecurity.nuspec').Open()
            $tags = ([xml] $reader.ReadToEnd()).package.metadata.tags -split '\s+'
            $reader.Dispose()
        } finally {
            $zip.Dispose()
        }
        $expectedTags = @('PSModule', 'PSIncludes_Cmdlet') + $manifest.PrivateData.PSData.Tags +
            @($manifest.CmdletsToExport | ForEach-Object -Process { "PSCmdlet_$_"; "PSCommand_$_" })

        $expectedTags | Where-Object -FilterScript { $_ -notin $tags } | Should -BeNullOrEmpty
        $tags | Group-Object | Where-Object -Property Count -GT -Value 1 | ForEach-Object -Process { $_.Name } |
            Should -BeNullOrEmpty
    }

    It 'Should put the module folder into NTFSSecurity.zip' {
        $entries = Get-ZipEntryName -Path $package.ZipPath | Sort-Object

        $entries -join ', ' | Should -BeExactly (($expectedFiles | ForEach-Object -Process { "NTFSSecurity/$_" }) -join ', ')
    }

    It 'Should fail if a file of the FileList is missing from the build output' {
        $incompletePath = Join-Path -Path $TestDrive -ChildPath 'incomplete'
        Copy-Item -LiteralPath $buildPath -Destination $incompletePath -Recurse
        Remove-Item -LiteralPath (Join-Path -Path $incompletePath -ChildPath 'en-US\NTFSSecurity.dll-Help.xml')

        { & $scriptPath -BuildPath $incompletePath -DestinationPath (Join-Path -Path $TestDrive -ChildPath 'out-incomplete') } |
            Should -Throw '*NTFSSecurity.dll-Help.xml*'
    }
}
