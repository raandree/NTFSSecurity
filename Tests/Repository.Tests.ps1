<#
    Tests repository files that the build and GitHub use, without a build: every packages.config lists the AlphaFS
    version that the projects reference and ship, and Dependabot keeps the actions of the CI workflow up to date.
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
        $ecosystems = @($lines | Select-String -Pattern '^\s*-\s*package-ecosystem:\s*"?([\w-]+)"?\s*$' |
                ForEach-Object -Process { $_.Matches[0].Groups[1].Value })
    }

    It 'Should exist in the .github folder' {
        $configPath | Should -Exist
    }

    It 'Should update only the actions of the CI workflow' {
        $ecosystems | Should -BeExactly @('github-actions')
    }

    It 'Should check for updates every week' {
        $lines -match '^\s+interval:\s*"?weekly"?\s*$' | Should -HaveCount 1
    }

    It 'Should group all updates into one pull request' {
        $lines -match '^\s+groups:\s*$' | Should -HaveCount 1
        $lines -match '^\s+-\s*"\*"\s*$' | Should -HaveCount 1
    }
}
