<#
    Tests the owner cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidAssignmentToAutomaticVariable', '', Justification = 'A test shadows $PWD on purpose (#86).'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # With the Backup privilege, Windows may grant reading the owner despite a deny entry.
    $canBypassDeny = Test-PrivilegeHeld -Name 'SeBackupPrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Owner'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSOwner' {
    Context 'When a downstream command stops the pipeline' {
        It 'Should stop without writing errors' {
            $files = 1..3 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "Owner$_" }

            $result = @(Get-NTFSOwner -Path $files -ErrorVariable ownerErrors -ErrorAction SilentlyContinue | Select-Object -First 1)

            $ownerErrors | Should -BeNullOrEmpty
            $result | Should -HaveCount 1
        }
    }

    Context 'When the owner cannot be read' {
        It 'Should write one permission error and keep the owner' -Skip:$canBypassDeny {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Block-TestReadPermission -Sandbox $sandbox -Path $file

            $result = @(Get-NTFSOwner -Path $file -ErrorVariable ownerErrors -ErrorAction SilentlyContinue)

            $result | Should -BeNullOrEmpty
            $ownerErrors | Should -HaveCount 1
            $ownerErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $ownerErrors[0].CategoryInfo.Category | Should -Be 'PermissionDenied'
        }
    }
}

Describe 'Current location' {
    BeforeAll {
        # The command runs in a child scope of this function, so the cmdlets see its $PWD = $null through the scope
        # chain, as in the report.
        function Invoke-WithShadowedPwd {
            param ([scriptblock] $Command)

            $PWD = $null
            & $Command
        }
    }

    # Before 5.0.0, a variable named PWD in the scope of the caller, such as a loop variable, made every cmdlet
    # fail with a NullReferenceException, also for an absolute path (#86).
    It 'Should ignore a variable named PWD for an absolute path' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Pwd'

        $result = Invoke-WithShadowedPwd -Command { Get-NTFSOwner -Path $file -ErrorAction Stop }

        $result.FullName | Should -Be $file
    }

    It 'Should resolve a relative path against the current location despite a variable named PWD' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'PwdRelative'
        $name = Split-Path -Path $file -Leaf

        $result = Invoke-WithShadowedPwd -Command { Get-NTFSOwner -Path $name -ErrorAction Stop }

        $result.FullName | Should -Be $file
    }

    It '<_> should use the current location without -Path despite a variable named PWD' -ForEach @(
        'Get-NTFSAccess', 'Get-NTFSAudit', 'Get-NTFSEffectiveAccess', 'Get-NTFSInheritance', 'Get-ChildItem2',
        'Get-Item2', 'Get-NTFSSecurityDescriptor'
    ) {
        $cmdlet = $_

        { Invoke-WithShadowedPwd -Command { & $cmdlet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue } } |
            Should -Not -Throw
    }

    It 'Get-NTFSHardLink should report the folder of the current location, not a NullReferenceException' {
        { Invoke-WithShadowedPwd -Command { Get-NTFSHardLink -ErrorAction SilentlyContinue } } |
            Should -Throw -ExpectedMessage '*must be a file*'
    }
}

Describe 'File and folder objects as arguments' {
    # Before 5.0.0, Windows PowerShell bound a folder object that was passed by position as its name, which the
    # cmdlets resolved against the current location (#88).
    It 'Should take a folder object by position' {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'Parent' -Directory
        $child = Join-Path -Path $parent -ChildPath 'Child'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $child
        New-Item -ItemType Directory -Path $child | Out-Null
        $folder = Get-ChildItem -LiteralPath $parent -Directory

        $result = Get-NTFSOwner $folder -ErrorAction Stop

        $result.FullName | Should -Be $child
    }

    It 'Should take file objects through the pipeline as before' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Piped'

        $result = Get-Item -LiteralPath $file | Get-NTFSOwner

        $result.FullName | Should -Be $file
    }
}
