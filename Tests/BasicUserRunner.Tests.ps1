<#
    Tests the basic-user CI wrapper without creating a process or changing privileges. A fake native process writes
    the same result-file boundary as the child; only the Add-Type call of the copied wrapper is mocked.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $sandbox = New-TestSandbox -Name 'BasicUserWrapper'
    $repository = Join-Path -Path $sandbox -ChildPath 'Repository'
    $scripts = Join-Path -Path $repository -ChildPath '.github\scripts'
    Assert-TestSandboxPath -Sandbox $sandbox -Path $scripts
    New-Item -ItemType Directory -Path $scripts -Force | Out-Null
    $wrapper = Join-Path -Path $scripts -ChildPath 'Invoke-TestsAsBasicUser.ps1'
    Copy-Item -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\.github\scripts\Invoke-TestsAsBasicUser.ps1') -Destination $wrapper
    Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Text.RegularExpressions;

public static class NTFSSecurityBasicUserProcess
{
    public static int Calls;
    public static string WorkingDirectory;

    public static int Run(string applicationName, string commandLine, string currentDirectory)
    {
        Calls++;
        WorkingDirectory = currentDirectory;
        var match = Regex.Match(commandLine, "-ResultPath \"([^\"]+)\"");
        if (!match.Success)
            throw new InvalidOperationException("The child command has no result path.");
        File.WriteAllText(match.Groups[1].Value, "<test-results />");
        return 0;
    }
}
"@
}

AfterAll {
    Remove-TestSandbox -Sandbox $sandbox
}

Describe 'Invoke-TestsAsBasicUser.ps1 result paths' {
    BeforeEach {
        [NTFSSecurityBasicUserProcess]::Calls = 0
        [NTFSSecurityBasicUserProcess]::WorkingDirectory = $null
        Mock -CommandName Add-Type -ParameterFilter { $TypeDefinition -like '*class NTFSSecurityBasicUserProcess*' }
    }

    It 'Should copy the result to an absolute path, also when that path contains spaces' {
        $result = Join-Path -Path $sandbox -ChildPath 'Absolute results\Result.xml'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $result

        & $wrapper -ResultPath $result -Title 'Absolute result path' | Out-Null

        Get-Content -LiteralPath $result -Raw | Should -BeExactly '<test-results />'
        [NTFSSecurityBasicUserProcess]::Calls | Should -Be 1
        [NTFSSecurityBasicUserProcess]::WorkingDirectory | Should -Be $repository
        Should -Invoke -CommandName Add-Type -Times 1 -Exactly
    }

    It 'Should resolve a relative path against the repository, not the caller location' {
        $result = Join-Path -Path $repository -ChildPath 'Relative results\Result.xml'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $result
        Push-Location -LiteralPath $sandbox
        try {
            & $wrapper -ResultPath 'Relative results\Result.xml' -Title 'Relative result path' | Out-Null
        }
        finally {
            Pop-Location
        }

        Get-Content -LiteralPath $result -Raw | Should -BeExactly '<test-results />'
        [NTFSSecurityBasicUserProcess]::Calls | Should -Be 1
        [NTFSSecurityBasicUserProcess]::WorkingDirectory | Should -Be $repository
    }
}
