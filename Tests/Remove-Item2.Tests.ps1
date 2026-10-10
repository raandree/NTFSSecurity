<#
    Tests Remove-Item2 of the module built in NTFSSecurity\bin\Release.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

Describe 'Remove-Item2' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
        Import-Module -Name $modulePath -Force -ErrorAction Stop
        $sandbox = New-TestSandbox -Name 'RemoveItem'
        Push-Location -LiteralPath $sandbox
    }

    AfterAll {
        Pop-Location
        Remove-TestSandbox -Sandbox $sandbox
        Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
    }

    Context 'Folders and their contents' {
        It 'Should remove an empty folder and return its folder object with -PassThru' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Empty' -Directory

            $result = @(Remove-Item2 -Path $folder -PassThru -ErrorAction Stop)

            $folder | Should -Not -Exist
            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
            $result[0].FullName | Should -Be $folder
        }

        It 'Should report DeleteError for a non-empty folder without -Recurse and continue with the next path' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'NonEmpty' -Directory
            $content = Join-Path -Path $folder -ChildPath 'Keep.txt'
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'Next'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $content
            Set-Content -LiteralPath $content -Value 'Keep'

            $result = @(Remove-Item2 -Path $folder, $next -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'DeleteError,*'
            $removeErrors[0].CategoryInfo.Category | Should -Be 'InvalidData'
            $removeErrors[0].TargetObject | Should -Be $folder
            Get-Content -LiteralPath $content | Should -Be 'Keep'
            $next | Should -Not -Exist
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $next
        }

        It 'Should remove a folder tree with -Recurse without touching its sibling' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Tree' -Directory
            $nested = Join-Path -Path $folder -ChildPath 'Child\Grandchild'
            $content = Join-Path -Path $nested -ChildPath 'Delete.txt'
            $sibling = New-TestSandboxItem -Sandbox $sandbox -Name 'Sibling'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $nested, $content
            New-Item -ItemType Directory -Path $nested -Force | Out-Null
            Set-Content -LiteralPath $content -Value 'Delete'

            Remove-Item2 -Path $folder -Recurse -ErrorAction Stop

            $folder | Should -Not -Exist
            Get-Content -LiteralPath $sibling | Should -Be 'Sibling'
        }

        It 'Should leave a folder tree unchanged with -Recurse -Force -WhatIf and write nothing with -PassThru' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Preview' -Directory
            $content = Join-Path -Path $folder -ChildPath 'Keep.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $content
            Set-Content -LiteralPath $content -Value 'Keep'
            [IO.File]::SetAttributes($content, [IO.FileAttributes]::ReadOnly)

            $result = @(Remove-Item2 -Path $folder -Recurse -Force -WhatIf -PassThru -ErrorAction Stop)

            $result | Should -BeNullOrEmpty
            Get-Content -LiteralPath $content | Should -Be 'Keep'
            ([IO.File]::GetAttributes($content) -band [IO.FileAttributes]::ReadOnly) | Should -Not -Be 0
        }

        It 'Should remove a folder tree containing read-only files with -Recurse -Force' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ReadOnlyTree' -Directory
            $content = Join-Path -Path $folder -ChildPath 'Child\ReadOnly.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $content
            New-Item -ItemType Directory -Path (Split-Path -Path $content -Parent) | Out-Null
            Set-Content -LiteralPath $content -Value 'ReadOnly'
            [IO.File]::SetAttributes($content, [IO.FileAttributes]::ReadOnly)

            Remove-Item2 -Path $folder -Recurse -Force -ErrorAction Stop

            $folder | Should -Not -Exist
        }

        It 'Should write DeleteError when a descendant is open without delete sharing, not a successful -PassThru result' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'LockedTree' -Directory
            $content = Join-Path -Path $folder -ChildPath 'Locked.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $content
            Set-Content -LiteralPath $content -Value 'Locked'
            $stream = [IO.File]::Open($content, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
            try {
                $result = @(Remove-Item2 -Path $folder -Recurse -Force -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)
            }
            finally {
                $stream.Dispose()
            }

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'DeleteError,*'
            $removeErrors[0].TargetObject | Should -Be $folder
            $result | Should -BeNullOrEmpty
            Get-Content -LiteralPath $content | Should -Be 'Locked'
        }

        It 'Should delete a junction with -Recurse without deleting or changing its target' {
            $target = New-TestSandboxItem -Sandbox $sandbox -Name 'JunctionTarget' -Directory
            $content = Join-Path -Path $target -ChildPath 'Keep.txt'
            $link = Join-Path -Path $sandbox -ChildPath 'Junction'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $content, $link
            Set-Content -LiteralPath $content -Value 'Keep'
            $before = (Get-Acl -LiteralPath $target).Sddl
            New-Item -ItemType Junction -Path $link -Value $target | Out-Null

            Remove-Item2 -Path $link -Recurse -Force -ErrorAction Stop

            $link | Should -Not -Exist
            Get-Content -LiteralPath $content | Should -Be 'Keep'
            (Get-Acl -LiteralPath $target).Sddl | Should -BeExactly $before
        }

        It 'Should delete a folder tree whose path exceeds 260 characters' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'LongTree' -Directory
            $long = Join-Path -Path $folder -ChildPath (('A' * 100), ('B' * 100), ('C' * 100) -join '\')
            Assert-TestSandboxPath -Sandbox $sandbox -Path $long
            [IO.Directory]::CreateDirectory('\\?\' + $long) | Out-Null
            [IO.File]::WriteAllText(('\\?\' + $long + '\Delete.txt'), 'Long')
            $long.Length | Should -BeGreaterThan 260

            Remove-Item2 -Path $folder -Recurse -Force -ErrorAction Stop

            $folder | Should -Not -Exist
        }
    }

    Context 'Read-only files' {
        It 'Should refuse a read-only file without -Force, keep its contents and attribute, and return nothing' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ReadOnly'
            [IO.File]::SetAttributes($file, [IO.FileAttributes]::ReadOnly)

            $result = @(Remove-Item2 -Path $file -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'DeleteError,*'
            $result | Should -BeNullOrEmpty
            Get-Content -LiteralPath $file | Should -Be 'ReadOnly'
            ([IO.File]::GetAttributes($file) -band [IO.FileAttributes]::ReadOnly) | Should -Not -Be 0
        }

        It 'Should remove a read-only file with -Force' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Forced'
            [IO.File]::SetAttributes($file, [IO.FileAttributes]::ReadOnly)

            Remove-Item2 -Path $file -Force -ErrorAction Stop

            $file | Should -Not -Exist
        }
    }
    Context 'When called with -PassThur, the parameter name in 4.2.6 and earlier' {
        BeforeAll {
            $path = Join-Path -Path $sandbox -ChildPath 'PassThur.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $path
            Set-Content -LiteralPath $path -Value 'Remove-Item2 test'

            $removedItem = Remove-Item2 -Path $path -PassThur
        }

        It 'Should delete the file' {
            $path | Should -Not -Exist
        }

        It 'Should return the deleted file, like -PassThru' {
            $removedItem.Name | Should -BeExactly 'PassThur.txt'
        }
    }
}
