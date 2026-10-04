<#
    Tests the shared helpers in TestHelpers.psm1, which keep the tests that change files, links, and security
    descriptors inside their sandbox folders. CI runs every *.Tests.ps1 file of this folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
}

AfterAll {
    Remove-Module -Name TestHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Test helpers' {
    Context 'New-TestSandbox' {
        BeforeAll {
            $sandbox = New-TestSandbox -Name 'Helpers'
        }

        AfterAll {
            Remove-TestSandbox -Sandbox $sandbox
        }

        It 'Should create an empty folder below $env:TEMP\NTFSSecurity.Tests' {
            $sandbox | Should -Exist
            Get-ChildItem -LiteralPath $sandbox -Force | Should -BeNullOrEmpty
            $expectedParent = [IO.Path]::GetFullPath((Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'NTFSSecurity.Tests'))
            Split-Path -Path $sandbox -Parent | Should -Be $expectedParent
            Split-Path -Path $sandbox -Leaf | Should -BeLike 'Helpers-*'
        }
    }

    Context 'Assert-TestSandboxPath' {
        BeforeAll {
            $sandbox = New-TestSandbox -Name 'Helpers'
            Push-Location -LiteralPath $sandbox
        }

        AfterAll {
            Pop-Location
            Remove-TestSandbox -Sandbox $sandbox
        }

        It 'Should accept a full path inside the sandbox' {
            { Assert-TestSandboxPath -Sandbox $sandbox -Path (Join-Path -Path $sandbox -ChildPath 'Folder\File.txt') } |
                Should -Not -Throw
        }

        It 'Should resolve a relative path against the current location' {
            { Assert-TestSandboxPath -Sandbox $sandbox -Path '.\File.txt', 'Folder\File.txt' } | Should -Not -Throw
        }

        It 'Should reject <_>' -ForEach @('..', '..\Other', 'C:\Windows', '\Windows') {
            { Assert-TestSandboxPath -Sandbox $sandbox -Path $_ } | Should -Throw -ExpectedMessage 'Refusing to change*'
        }

        It 'Should reject a sibling folder whose name starts with the name of the sandbox' {
            { Assert-TestSandboxPath -Sandbox $sandbox -Path "$sandbox-Other\File.txt" } |
                Should -Throw -ExpectedMessage 'Refusing to change*'
        }

        It 'Should reject a sandbox that New-TestSandbox did not create' {
            { Assert-TestSandboxPath -Sandbox $env:TEMP -Path (Join-Path -Path $env:TEMP -ChildPath 'File.txt') } |
                Should -Throw -ExpectedMessage '*is not a test sandbox*'
        }
    }

    Context 'Remove-TestSandbox' {
        BeforeAll {
            $sandbox = New-TestSandbox -Name 'Helpers'
            $otherSandbox = New-TestSandbox -Name 'Helpers'
            $target = Join-Path -Path $otherSandbox -ChildPath 'Target'
            $link = Join-Path -Path $sandbox -ChildPath 'Link'
            $locked = Join-Path -Path $sandbox -ChildPath 'Locked'

            Assert-TestSandboxPath -Sandbox $otherSandbox -Path $target
            New-Item -ItemType Directory -Path $target | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $target -ChildPath 'Keep.txt') -Value 'Keep'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $link, $locked
            New-Item -ItemType Junction -Path $link -Value $target | Out-Null
            New-Item -ItemType Directory -Path $locked | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $locked -ChildPath 'File.txt') -Value 'Locked'
            # An empty, protected DACL that grants nobody access, as some tests leave behind
            & icacls.exe $locked /inheritance:r *> $null

            Remove-TestSandbox -Sandbox $sandbox
        }

        AfterAll {
            Remove-TestSandbox -Sandbox $otherSandbox
        }

        It 'Should remove the sandbox, even with a folder that denies access' {
            $sandbox | Should -Not -Exist
        }

        It 'Should remove a junction without removing the files of its target' {
            Join-Path -Path $target -ChildPath 'Keep.txt' | Should -Exist
        }
    }

    Context 'Test-IsElevated and Test-PrivilegeHeld' {
        It 'Should tell whether the process is elevated' {
            Test-IsElevated | Should -BeOfType [bool]
        }

        It 'Should find SeChangeNotifyPrivilege, which every access token holds' {
            Test-PrivilegeHeld -Name 'SeChangeNotifyPrivilege' | Should -BeTrue
        }

        It 'Should not find a privilege that does not exist' {
            Test-PrivilegeHeld -Name 'SeNoSuchPrivilege' | Should -BeFalse
        }
    }
}
