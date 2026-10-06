<#
    Tests the shared helpers in TestHelpers.psm1, which keep the tests that change files, links, and security
    descriptors inside their sandbox folders. CI runs every *.Tests.ps1 file of this folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # Assigning an owner other than the user or one of its groups needs the Restore privilege.
    $canAssignAnyOwner = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
}

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

        It 'Should reject a path below a link, which can point outside the sandbox' {
            $otherSandbox = New-TestSandbox -Name 'Helpers'
            try {
                $link = Join-Path -Path $sandbox -ChildPath 'Link'
                Assert-TestSandboxPath -Sandbox $sandbox -Path $link
                New-Item -ItemType Junction -Path $link -Value $otherSandbox | Out-Null

                { Assert-TestSandboxPath -Sandbox $sandbox -Path (Join-Path -Path $link -ChildPath 'File.txt') } |
                    Should -Throw -ExpectedMessage '*is a link*'
            }
            finally {
                Remove-TestSandbox -Sandbox $otherSandbox
            }
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
            # An explicit entry that a reset through the link would remove
            $targetAcl = Get-Acl -LiteralPath $target
            $targetAcl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                        (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-1-0'),
                        [System.Security.AccessControl.FileSystemRights]::ReadData, [System.Security.AccessControl.AccessControlType]::Allow
                    )))
            Set-Acl -LiteralPath $target -AclObject $targetAcl
            $targetSddl = (Get-Acl -LiteralPath $target).Sddl
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

        It 'Should not change the ACL of the target of a junction' {
            (Get-Acl -LiteralPath $target).Sddl | Should -BeExactly $targetSddl
        }
    }

    Context 'Set-TestOwner' {
        BeforeAll {
            $sandbox = New-TestSandbox -Name 'Helpers'
            $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
        }

        AfterAll {
            Remove-TestSandbox -Sandbox $sandbox
        }

        It 'Should make the account the owner of an item in the sandbox' -Skip:(-not $canAssignAnyOwner) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Owner'

            Set-TestOwner -Sandbox $sandbox -Path $file -Sid $trustedInstaller

            (Get-Acl -LiteralPath $file).GetOwner([System.Security.Principal.SecurityIdentifier]).Value |
                Should -Be $trustedInstaller
        }

        It 'Should refuse an item outside the sandbox' {
            { Set-TestOwner -Sandbox $sandbox -Path "$sandbox-Other\File.txt" -Sid $trustedInstaller } |
                Should -Throw -ExpectedMessage 'Refusing to change*'
        }

        # icacls reports a failure on stderr, which Windows PowerShell turns into a terminating error of its own when
        # the caller uses -ErrorAction Stop.
        It 'Should throw its own error when icacls fails, also with -ErrorAction Stop' {
            $missing = Join-Path -Path $sandbox -ChildPath 'Missing.txt'

            { Set-TestOwner -Sandbox $sandbox -Path $missing -Sid $trustedInstaller -ErrorAction Stop } |
                Should -Throw -ExpectedMessage 'icacls could not make*'
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
