<#
    Tests repository files that the build and GitHub use, without a build: every packages.config lists the AlphaFS
    version that the projects reference and ship, Dependabot keeps the actions of the CI workflow up to date, and the
    manifest and the README describe the release.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    $repositoryPath = Join-Path -Path $PSScriptRoot -ChildPath '..'
    $packageConfigs = foreach ($project in Get-ChildItem -Path $repositoryPath -Filter '*.csproj' -Recurse -Depth 1) {
        $configPath = Join-Path -Path $project.DirectoryName -ChildPath 'packages.config'
        if ((Test-Path -LiteralPath $configPath) -and (Select-String -LiteralPath $configPath -Pattern 'id="AlphaFS"' -Quiet)) {
            @{ Project = $project.Directory.Name; Path = $configPath }
        }
    }
}

Describe 'NuGet packages of the projects' {
    BeforeAll {
        $repositoryPath = Join-Path -Path $PSScriptRoot -ChildPath '..'
        $projects = Get-ChildItem -Path $repositoryPath -Filter '*.csproj' -Recurse -Depth 1
        $hintPathVersions = @($projects | Select-String -Pattern 'packages\\AlphaFS\.(\d+\.\d+\.\d+)\\' |
                ForEach-Object -Process { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique)
    }

    It 'Should reference one AlphaFS version in the HintPaths of all projects' {
        $hintPathVersions | Should -HaveCount 1
    }

    It 'Should find the packages.config of the three projects that reference AlphaFS' -ForEach @(@{ Configs = $packageConfigs }) {
        $Configs | Should -HaveCount 3
    }

    It 'Should list the AlphaFS version of the HintPaths in <Project>\packages.config' -ForEach $packageConfigs {
        $package = ([xml] (Get-Content -LiteralPath $Path -Raw)).packages.package |
            Where-Object -Property id -EQ -Value 'AlphaFS'

        $package.version | Should -BeExactly $hintPathVersions[0]
    }
}

Describe 'Dependabot configuration' {
    BeforeAll {
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath '..\.github\dependabot.yml'
        $lines = if (Test-Path -LiteralPath $configPath) { Get-Content -LiteralPath $configPath } else { @() }
        $raw = $lines -join "`n"
        $ecosystems = @($lines | Select-String -Pattern '^\s*-\s*package-ecosystem:\s*"?([\w-]+)"?\s*$' |
                ForEach-Object -Process { $_.Matches[0].Groups[1].Value })
    }

    It 'Should exist in the .github folder' {
        $configPath | Should -Exist
    }

    It 'Should use version 2 of the format and the root folder of the repository' {
        $lines -match '^version:\s*2\s*$' | Should -HaveCount 1
        $lines -match '^\s+directory:\s*"?/"?\s*$' | Should -HaveCount 1
    }

    It 'Should update only the actions of the CI workflow' {
        $ecosystems | Should -BeExactly @('github-actions')
    }

    It 'Should check for updates every week' {
        $lines -match '^\s+interval:\s*"?weekly"?\s*$' | Should -HaveCount 1
    }

    It 'Should wait at least a week before it proposes a new release' {
        $raw | Should -Match '(?m)^\s+cooldown:\s*\n\s+default-days:\s*([7-9]|[1-9]\d+)\s*$'
    }

    It 'Should group all updates into one pull request' {
        $raw | Should -Match '(?m)^\s+groups:\s*\n\s+[\w-]+:\s*\n\s+patterns:\s*\n\s+-\s*["'']\*["'']\s*$'
    }
}

Describe 'Release metadata' {
    BeforeAll {
        $repositoryPath = Join-Path -Path $PSScriptRoot -ChildPath '..'
        $manifest = Import-PowerShellDataFile -Path (Join-Path -Path $repositoryPath -ChildPath 'NTFSSecurity\NTFSSecurity.psd1')
        $version = $manifest.ModuleVersion
        if ($manifest.PrivateData.PSData.Prerelease) {
            $version = '{0}-{1}' -f $version, $manifest.PrivateData.PSData.Prerelease
        }
    }

    # Before 5.0.0-rc2, the description said "Windows PowerShell Module", although the module supports PowerShell 7. Since
    # 5.0.0-rc3, it announces that the project will be archived, for the users who see only the PowerShell Gallery.
    It 'Should have the description that the PowerShell Gallery shows for the module' {
        $manifest.Description | Should -BeExactly ('PowerShell module for managing file and folder security on NTFS volumes. ' +
            'NTFSSecurity will be archived; its successor is WindowsAccessControl.')
    }

    # The PowerShell Gallery doesn't accept a version twice. Add every published version to this list
    # (Docs/Contributing/05-Releasing.md).
    It 'Should not reuse a version that the PowerShell Gallery already has' {
        $publishedVersions = '4.0', '4.2.2', '4.2.3', '4.2.4', '4.2.5', '4.2.6', '5.0.0-rc1', '5.0.0-rc2', '5.0.0-rc3', '5.0.0-rc4', '5.0.0-rc5', '5.0.0-rc6'

        $publishedVersions | Should -Not -Contain $version
    }

    It 'Should not name a prerelease version in the README, which outlives the release' {
        Get-Content -LiteralPath (Join-Path -Path $repositoryPath -ChildPath 'Docs\README.md') -Raw |
            Should -Not -Match '\d+\.\d+\.\d+-[A-Za-z]'
    }
}

Describe 'Invoke-TestsAsBasicUser.ps1' {
    BeforeAll {
        # Only the parameters of the script, so that a test binds them without running the tests as a basic user
        $path = Join-Path -Path $PSScriptRoot -ChildPath '..\.github\scripts\Invoke-TestsAsBasicUser.ps1'
        $tokens = $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref] $tokens, [ref] $parseErrors)
        $bindParameters = [scriptblock]::Create($ast.ParamBlock.Extent.Text)
    }

    # The title goes into a quoted argument of cmd.exe, which expands environment variables also inside quotes and ends
    # the command at a line break.
    It 'Should refuse a title with the character <Name>, which would change the command line of cmd.exe' -ForEach @(
        @{ Name = '%'; Character = '%' }
        @{ Name = 'double quote'; Character = '"' }
        @{ Name = 'line feed'; Character = "`n" }
        @{ Name = 'carriage return'; Character = "`r" }
    ) {
        { & $bindParameters -ResultPath 'TestResults\Refused.xml' -Title "CI run $Character 1" } |
            Should -Throw -ExpectedMessage "*'Title'*"
    }

    It 'Should refuse a title that ends with a line break' {
        { & $bindParameters -ResultPath 'TestResults\Refused.xml' -Title "CI run`n" } |
            Should -Throw -ExpectedMessage "*'Title'*"
    }

    It 'Should accept the title <_> of the CI workflow' -ForEach @('Windows PowerShell 5.1 as a basic user', 'PowerShell 7 as a basic user') {
        { & $bindParameters -ResultPath 'TestResults\Accepted.xml' -Title $_ } | Should -Not -Throw
    }
}
