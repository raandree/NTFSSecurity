<#
    Tests the module manifest of the module built in NTFSSecurity\bin\Release: it passes Test-ModuleManifest,
    exports exactly the cmdlets of the module, and carries the same version as the assemblies and CHANGELOG.md.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    # The first-party assemblies of the module carry the module version; ProcessPrivileges is a vendored library.
    $versionedAssemblies = 'NTFSSecurity', 'Security2', 'PrivilegeControl'
}

Describe 'Module manifest of NTFSSecurity' {
    BeforeAll {
        $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $module = Import-Module -Name $manifestPath -Force -PassThru -ErrorAction Stop |
            Where-Object -Property Name -EQ -Value 'NTFSSecurity'
    }

    AfterAll {
        Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
    }

    It 'Should pass Test-ModuleManifest without errors or warnings' {
        $testParameters = @{
            Path            = $manifestPath
            ErrorVariable   = 'manifestErrors'
            WarningVariable = 'manifestWarnings'
            ErrorAction     = 'SilentlyContinue'
            WarningAction   = 'SilentlyContinue'
        }
        $null = Test-ModuleManifest @testParameters

        @($manifestErrors) + @($manifestWarnings) | ForEach-Object -Process { "$_" } | Should -BeNullOrEmpty
    }

    It 'Should list each cmdlet only once in CmdletsToExport' {
        $duplicates = $manifest.CmdletsToExport | Group-Object | Where-Object -Property Count -GT -Value 1

        $duplicates.Name | Should -BeNullOrEmpty
    }

    It 'Should list only cmdlets of the module in CmdletsToExport' {
        $manifest.CmdletsToExport | Where-Object -FilterScript { -not $module.ExportedCmdlets.ContainsKey($_) } |
            Should -BeNullOrEmpty
    }

    It 'Should export exactly 36 cmdlets' {
        @($manifest.CmdletsToExport) | Should -HaveCount 36
        $module.ExportedCmdlets.Keys | Should -HaveCount 36
    }

    Context 'Version' {
        It 'Should give <_>.dll the module version' -ForEach $versionedAssemblies {
            $assemblyPath = Join-Path -Path $module.ModuleBase -ChildPath "$_.dll"
            $assemblyVersion = [Reflection.AssemblyName]::GetAssemblyName($assemblyPath).Version
            $fileVersion = [version] (Get-Item -LiteralPath $assemblyPath).VersionInfo.FileVersion

            $assemblyVersion.ToString(3) | Should -BeExactly $manifest.ModuleVersion
            $fileVersion.ToString(3) | Should -BeExactly $manifest.ModuleVersion
        }

        It 'Should describe the module version in the latest section of CHANGELOG.md' {
            $changelog = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\CHANGELOG.md') -Raw
            $latestVersion = [regex]::Match($changelog, '(?m)^## \[(?<Version>\d+\.\d+\.\d+)\]').Groups['Version'].Value

            $latestVersion | Should -BeExactly $manifest.ModuleVersion
        }
    }
}
