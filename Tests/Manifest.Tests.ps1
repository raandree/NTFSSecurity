<#
    Tests the module manifest of the module built in NTFSSecurity\bin\Release: it passes Test-ModuleManifest,
    exports exactly the cmdlets of the module, and carries the same version as the assemblies. Release.Tests.ps1
    checks that CHANGELOG.md describes that version.
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
    }
}

Describe 'Type data of NTFSSecurity' {
    BeforeDiscovery {
        # Only Windows PowerShell fails to import type data that conflicts with an existing member, so both CI legs
        # start it.
        $windowsPowerShell = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    BeforeAll {
        $windowsPowerShell = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    # Before 5.0.0, the types file added the alias Size to System.IO.FileInfo, so the import failed when another module
    # had added a member with that name (#82). The module is imported in a child process, because type data stays in a
    # session.
    It 'Should import in Windows PowerShell after another module added a Size member to System.IO.FileInfo' -Skip:(-not (Test-Path -LiteralPath $windowsPowerShell)) {
        $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
        $manifestPath | Should -Exist
        $quotedPath = $manifestPath.Replace("'", "''")
        $command = 'Update-TypeData -TypeName System.IO.FileInfo -MemberType AliasProperty -MemberName Size -Value Length -Force; ' +
            ("Import-Module -Name '{0}' -ErrorAction Stop; " -f $quotedPath) +
            ("if ((Get-Item -LiteralPath '{0}').PSObject.Properties['LengthOnDisk']) {{ 'IMPORTED' }}" -f $quotedPath)

        $output = & $windowsPowerShell -NoProfile -NonInteractive -Command $command 2>&1

        $output | Select-Object -Last 1 | Should -Be 'IMPORTED'
    }
}
