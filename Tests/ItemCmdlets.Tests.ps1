<#
    Tests the long-path item cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'ItemCmdlets'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ChildItem2' {
    Context 'When -Path is a file' {
        BeforeAll {
            $folder = Join-Path -Path $sandbox -ChildPath 'ChildItem'
            $file = Join-Path -Path $folder -ChildPath 'File.txt'
            $other = Join-Path -Path $folder -ChildPath 'Folder\Other.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $folder, $file, $other
            New-Item -ItemType Directory -Path (Split-Path -Path $other -Parent) -Force | Out-Null
            Set-Content -LiteralPath $file -Value 'File'
            Set-Content -LiteralPath $other -Value 'Other'
        }

        It 'Should return the file itself, like Get-ChildItem' {
            $items = @(Get-ChildItem2 -Path $file -ErrorVariable childItemErrors -ErrorAction SilentlyContinue)

            $childItemErrors | Should -BeNullOrEmpty
            $items | Should -HaveCount 1
            $items[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
            $items[0].Name | Should -BeExactly 'File.txt'
        }

        It 'Should continue with the next path after a file' {
            $items = @(Get-ChildItem2 -Path $file, (Join-Path -Path $folder -ChildPath 'Folder') -ErrorAction SilentlyContinue)

            $items.Name | Should -Be @('File.txt', 'Other.txt')
        }

        It 'Should return nothing for a file with -Directory' {
            $items = @(Get-ChildItem2 -Path $file -Directory -ErrorVariable childItemErrors -ErrorAction SilentlyContinue)

            $childItemErrors | Should -BeNullOrEmpty
            $items | Should -BeNullOrEmpty
        }
    }

    Context 'Default table view' {
        BeforeAll {
            $viewFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'View' -Directory
            $blocked = Join-Path -Path $viewFolder -ChildPath 'Blocked.txt'
            $inheriting = Join-Path -Path $viewFolder -ChildPath 'Inheriting.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $blocked, $inheriting
            Set-Content -LiteralPath $blocked -Value 'Blocked'
            Set-Content -LiteralPath $inheriting -Value 'Inheriting'
            $acl = Get-Acl -LiteralPath $blocked
            $acl.SetAccessRuleProtection($true, $true)
            Set-Acl -LiteralPath $blocked -AclObject $acl

            $lines = Get-ChildItem2 -Path $viewFolder | Out-String -Stream -Width 200
        }

        It 'Should show False in the Inherits column for a file whose inheritance is disabled' {
            ($lines | Where-Object -FilterScript { $_ -match 'Blocked\.txt\s*$' }) | Should -Match '\bFalse\b'
        }

        It 'Should show True in the Inherits column for a file that inherits' {
            ($lines | Where-Object -FilterScript { $_ -match 'Inheriting\.txt\s*$' }) | Should -Match '\bTrue\b'
        }
    }
}

Describe 'Copy-Item2, Move-Item2, and Remove-Item2 with several paths' {
    BeforeEach {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Several' -Directory
        $missing = Join-Path -Path $folder -ChildPath 'Missing.txt'
        $first = Join-Path -Path $folder -ChildPath 'First.txt'
        $second = Join-Path -Path $folder -ChildPath 'Second.txt'
        $destination = Join-Path -Path $folder -ChildPath 'Destination'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing, $first, $second, $destination
        Set-Content -LiteralPath $first -Value 'First'
        Set-Content -LiteralPath $second -Value 'Second'
        New-Item -ItemType Directory -Path $destination | Out-Null
    }

    # Before 5.0.0, the cmdlets stopped processing -Path at the first failing path.
    It 'Remove-Item2 should continue after a path that does not exist' {
        Remove-Item2 -Path $missing, $first -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -HaveCount 1
        $first | Should -Not -Exist
    }

    It '<_> should continue after a path that does not exist' -ForEach @('Copy-Item2', 'Move-Item2') {
        & $_ -Path $missing, $first -Destination $destination -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -HaveCount 1
        Join-Path -Path $destination -ChildPath 'First.txt' | Should -Exist
    }

    It '<_> should continue after a file that exists at the destination' -ForEach @('Copy-Item2', 'Move-Item2') {
        Set-Content -LiteralPath (Join-Path -Path $destination -ChildPath 'First.txt') -Value 'Existing'

        & $_ -Path $first, $second -Destination $destination -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -HaveCount 1
        Join-Path -Path $destination -ChildPath 'Second.txt' | Should -Exist
    }

    # Before 5.0.0, the verbose message named the source path as the destination.
    It '<Command> should name the destination in the verbose message' -ForEach @(
        @{ Command = 'Copy-Item2'; Verb = 'copied' }
        @{ Command = 'Move-Item2'; Verb = 'moved' }
    ) {
        $target = Join-Path -Path $destination -ChildPath 'First.txt'

        $messages = & $Command -Path $first -Destination $destination -Verbose 4>&1

        $messages.Message | Should -Contain ("File '{0}' {1} to '{2}'" -f $first, $Verb, $target)
    }

    # Before 5.0.0, -PassThru wrote the item also when -WhatIf skipped the operation.
    It '<_> should write nothing with -PassThru and -WhatIf' -ForEach @('Copy-Item2', 'Move-Item2', 'Remove-Item2') {
        $parameters = @{ Path = $first; PassThru = $true; WhatIf = $true }
        if ($_ -ne 'Remove-Item2') {
            $parameters.Destination = $destination
        }

        $result = @(& $_ @parameters)

        $result | Should -BeNullOrEmpty
        $first | Should -Exist
    }
}

Describe 'Copy-Item2' {
    Context 'When -Path is a folder with files and subfolders' {
        BeforeAll {
            $source = New-TestSandboxItem -Sandbox $sandbox -Name 'Source' -Directory
            $sourceFile = Join-Path -Path $source -ChildPath 'File.txt'
            $sourceSubfolderFile = Join-Path -Path $source -ChildPath 'Subfolder\Other.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $sourceFile, $sourceSubfolderFile
            New-Item -ItemType Directory -Path (Split-Path -Path $sourceSubfolderFile -Parent) | Out-Null
            Set-Content -LiteralPath $sourceFile -Value 'File'
            Set-Content -LiteralPath $sourceSubfolderFile -Value 'Other'
        }

        It 'Should copy the folder with its files and subfolders' {
            $destination = Join-Path -Path $sandbox -ChildPath ('Copy-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $destination

            Copy-Item2 -Path $source -Destination $destination -ErrorVariable copyErrors -ErrorAction SilentlyContinue

            $copyErrors | Should -BeNullOrEmpty
            Join-Path -Path $destination -ChildPath 'File.txt' | Should -Exist
            Join-Path -Path $destination -ChildPath 'Subfolder\Other.txt' | Should -Exist
        }
    }
}
