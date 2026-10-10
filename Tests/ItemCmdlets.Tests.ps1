<#
    Tests the long-path item cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    # A path on the administrative share of the drive of the sandboxes is another volume for Windows, like a share of a
    # file server.
    $canUseAdminShare = Test-AdminShareAvailable
}

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

    Context 'With -Attributes' {
        BeforeAll {
            $attributeFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'Attributes' -Directory
            $hiddenFile = Join-Path -Path $attributeFolder -ChildPath 'Hidden.txt'
            $readOnlyFile = Join-Path -Path $attributeFolder -ChildPath 'ReadOnly.txt'
            $plainFile = Join-Path -Path $attributeFolder -ChildPath 'Plain.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $hiddenFile, $readOnlyFile, $plainFile
            Set-Content -LiteralPath $hiddenFile, $readOnlyFile, $plainFile -Value 'Attributes'
            (Get-Item -LiteralPath $hiddenFile -Force).Attributes = [IO.FileAttributes]::Hidden
            (Get-Item -LiteralPath $readOnlyFile).Attributes = [IO.FileAttributes]::ReadOnly
        }

        # Before 5.0.0, the cmdlet returned only the items that had all the listed attributes (#5).
        It 'Should return the items that have any of the listed attributes, like Get-ChildItem' {
            $result = @(Get-ChildItem2 -Path $attributeFolder -Attributes Hidden, ReadOnly)

            @($result.Name | Sort-Object) | Should -Be @('Hidden.txt', 'ReadOnly.txt')
        }

        # Before 5.0.0, an empty value applied no filter and returned hidden items as well.
        It 'Should reject an empty value' {
            { Get-ChildItem2 -Path $attributeFolder -Attributes 0 -ErrorAction Stop } | Should -Throw -ErrorId 'AttributesEmpty,NTFSSecurity.GetChildItem2'
        }

        It 'Should return only the items with the attribute when one is listed' {
            $result = @(Get-ChildItem2 -Path $attributeFolder -Attributes ReadOnly)

            $result.Name | Should -Be 'ReadOnly.txt'
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

    It '<Command> should name the destination of a folder in the verbose message' -ForEach @(
        @{ Command = 'Copy-Item2'; Verb = 'copied' }
        @{ Command = 'Move-Item2'; Verb = 'moved' }
    ) {
        $sourceFolder = Join-Path -Path $folder -ChildPath 'VerboseFolder'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $sourceFolder
        New-Item -ItemType Directory -Path $sourceFolder | Out-Null
        $target = Join-Path -Path $destination -ChildPath 'VerboseFolder'

        $messages = & $Command -Path $sourceFolder -Destination $destination -Verbose 4>&1

        $messages.Message | Should -Contain ("Directory '{0}' {1} to '{2}'" -f $sourceFolder, $Verb, $target)
    }

    # With -PassThru, both cmdlets return the item at the destination, as their pages say.
    It 'Copy-Item2 -PassThru should return the copy' {
        $result = Copy-Item2 -Path $first -Destination $destination -PassThru $true

        $result.FullName | Should -Be (Join-Path -Path $destination -ChildPath 'First.txt')
        $first | Should -Exist
    }

    It 'Copy-Item2 -PassThru should return the copy of a folder' {
        $sourceFolder = Join-Path -Path $folder -ChildPath 'SourceFolder'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $sourceFolder
        New-Item -ItemType Directory -Path $sourceFolder | Out-Null
        Set-Content -LiteralPath (Join-Path -Path $sourceFolder -ChildPath 'Inner.txt') -Value 'Inner'

        $result = Copy-Item2 -Path $sourceFolder -Destination (Join-Path -Path $destination -ChildPath 'Copied') -PassThru $true

        $result.FullName | Should -Be (Join-Path -Path $destination -ChildPath 'Copied')
        $sourceFolder | Should -Exist
    }

    It 'Move-Item2 -PassThru should return the item at its new location' {
        $result = Move-Item2 -Path $first -Destination $destination -PassThru $true

        $result.FullName | Should -Be (Join-Path -Path $destination -ChildPath 'First.txt')
    }

    It 'Move-Item2 -PassThru should return a folder at its new location' {
        $sourceFolder = Join-Path -Path $folder -ChildPath 'MovedFolder'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $sourceFolder
        New-Item -ItemType Directory -Path $sourceFolder | Out-Null

        $result = Move-Item2 -Path $sourceFolder -Destination $destination -PassThru $true

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result.FullName | Should -Be (Join-Path -Path $destination -ChildPath 'MovedFolder')
        $sourceFolder | Should -Not -Exist
    }

    # Before 5.0.0-rc6, the check for an existing destination looked for a file only. For a folder whose name existed
    # in the destination, the cmdlets failed in the middle with a CopyError or a MoveError, and Copy-Item2 could copy
    # a part of the folder.
    It '<_> should write DestinationFileAlreadyExists for a folder that exists at the destination and change nothing' -ForEach @('Copy-Item2', 'Move-Item2') {
        $sourceFolder = Join-Path -Path $folder -ChildPath 'Conflict'
        $existingFolder = Join-Path -Path $destination -ChildPath 'Conflict'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $sourceFolder, $existingFolder
        New-Item -ItemType Directory -Path $sourceFolder, $existingFolder | Out-Null
        Set-Content -LiteralPath (Join-Path -Path $sourceFolder -ChildPath 'A.txt') -Value 'New'
        Set-Content -LiteralPath (Join-Path -Path $sourceFolder -ChildPath 'B.txt') -Value 'New'
        Set-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'A.txt') -Value 'Existing'

        & $_ -Path $sourceFolder -Destination $destination -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike 'DestinationFileAlreadyExists,*'
        $itemErrors[0].TargetObject | Should -Be $existingFolder
        Get-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'A.txt') | Should -Be 'Existing'
        Join-Path -Path $existingFolder -ChildPath 'B.txt' | Should -Not -Exist
        Join-Path -Path $sourceFolder -ChildPath 'A.txt' | Should -Exist
    }

    It 'Copy-Item2 -Force should copy a folder into an existing folder of the same name and replace the files in both' {
        $sourceFolder = Join-Path -Path $folder -ChildPath 'Merge'
        $existingFolder = Join-Path -Path $destination -ChildPath 'Merge'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $sourceFolder, $existingFolder
        New-Item -ItemType Directory -Path $sourceFolder, $existingFolder | Out-Null
        Set-Content -LiteralPath (Join-Path -Path $sourceFolder -ChildPath 'A.txt') -Value 'New'
        Set-Content -LiteralPath (Join-Path -Path $sourceFolder -ChildPath 'B.txt') -Value 'New'
        Set-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'A.txt') -Value 'Existing'
        Set-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'C.txt') -Value 'Existing'

        Copy-Item2 -Path $sourceFolder -Destination $destination -Force -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -BeNullOrEmpty
        Get-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'A.txt') | Should -Be 'New'
        Get-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'B.txt') | Should -Be 'New'
        Get-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'C.txt') | Should -Be 'Existing'
    }

    # Before 5.0.0-rc6, the error named the source item as the path that wasn't found, also when the folder of the
    # destination was missing (#21).
    It '<Command> should name the missing folder of the destination for a <Kind> and change nothing' -ForEach @(
        @{ Command = 'Copy-Item2'; Kind = 'file'; ErrorId = 'CopyError' }
        @{ Command = 'Copy-Item2'; Kind = 'folder'; ErrorId = 'CopyError' }
        @{ Command = 'Move-Item2'; Kind = 'file'; ErrorId = 'MoveError' }
        @{ Command = 'Move-Item2'; Kind = 'folder'; ErrorId = 'MoveError' }
    ) {
        $source = $first
        if ($Kind -eq 'folder') {
            $source = Join-Path -Path $folder -ChildPath 'SourceFolder'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $source
            New-Item -ItemType Directory -Path $source | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $source -ChildPath 'Inner.txt') -Value 'Inner'
        }

        $missingFolder = Join-Path -Path $folder -ChildPath 'MissingFolder'
        $target = Join-Path -Path $missingFolder -ChildPath 'Item'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missingFolder, $target

        & $Command -Path $source -Destination $target -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $itemErrors[0].Exception.Message | Should -BeLike "*'$missingFolder'*"
        $itemErrors[0].TargetObject | Should -Be $target
        $source | Should -Exist
        $missingFolder | Should -Not -Exist
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

    # Before 5.0.0-rc4, an existing destination file produced a real error also with -WhatIf, which only previews the
    # operation, so -WhatIf -ErrorAction Stop stopped the preview (#108).
    It '<_> should write no error with -WhatIf when the destination file exists' -ForEach @('Copy-Item2', 'Move-Item2') {
        $existing = Join-Path -Path $destination -ChildPath 'First.txt'
        Set-Content -LiteralPath $existing -Value 'Existing'

        & $_ -Path $first -Destination $destination -WhatIf -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -BeNullOrEmpty
        $first | Should -Exist
        Get-Content -LiteralPath $existing | Should -Be 'Existing'
    }

    It '<_> should name the existing destination file in a verbose message with -WhatIf' -ForEach @('Copy-Item2', 'Move-Item2') {
        $existing = Join-Path -Path $destination -ChildPath 'First.txt'
        Set-Content -LiteralPath $existing -Value 'Existing'

        $messages = & $_ -Path $first -Destination $destination -WhatIf -Verbose -ErrorAction SilentlyContinue 4>&1

        @($messages | Where-Object -FilterScript { "$_" -like "*'$existing' already exists*" }) | Should -HaveCount 1
    }

    # Before 5.0.0-rc6, -WhatIf didn't tell that the operation would fail because the folder of the destination is
    # missing.
    It '<_> should name the missing folder of the destination in a verbose message with -WhatIf, and write no error' -ForEach @('Copy-Item2', 'Move-Item2') {
        $missingFolder = Join-Path -Path $folder -ChildPath 'MissingFolder'
        $target = Join-Path -Path $missingFolder -ChildPath 'Item'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missingFolder, $target

        $messages = & $_ -Path $first -Destination $target -WhatIf -Verbose -ErrorVariable itemErrors -ErrorAction SilentlyContinue 4>&1

        $itemErrors | Should -BeNullOrEmpty
        @($messages | Where-Object -FilterScript { "$_" -like "*'$missingFolder' does not exist*" }) | Should -HaveCount 1
        $first | Should -Exist
        $missingFolder | Should -Not -Exist
    }

    # The folder of a destination on a share that doesn't exist is the share itself, which the error names.
    It '<Command> should name the missing share of a UNC destination' -ForEach @(
        @{ Command = 'Copy-Item2'; ErrorId = 'CopyError' }
        @{ Command = 'Move-Item2'; ErrorId = 'MoveError' }
    ) {
        $missingShare = '\\localhost\NTFSSecurityMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8)
        $target = Join-Path -Path $missingShare -ChildPath 'Item.txt'

        & $Command -Path $first -Destination $target -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $itemErrors[0].Exception.Message | Should -BeLike "*'$missingShare'*"
        $first | Should -Exist
    }
}

Describe 'Move-Item2' {
    # Windows can't move a folder to another volume. Before 5.0.0-rc7, the cmdlet let AlphaFS emulate the move by
    # copying and deleting, which failed for a folder with files with an error that named a file of the source, and
    # which deleted an empty folder without creating it at the destination.
    It 'Should refuse to move <Kind> folder to another volume and leave it in place' -Skip:(-not $canUseAdminShare) -ForEach @(
        @{ Kind = 'an empty' }
        @{ Kind = 'a non-empty' }
    ) {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'CrossVolume' -Directory
        if ($Kind -eq 'a non-empty') {
            Set-Content -LiteralPath (Join-Path -Path $source -ChildPath 'File.txt') -Value 'File'
        }
        $destination = Join-Path -Path $sandbox -ChildPath ('Moved-{0}' -f (Split-Path -Path $source -Leaf))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $destination

        Move-Item2 -Path $source -Destination (ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $destination) -ErrorVariable moveErrors -ErrorAction SilentlyContinue

        $moveErrors | Should -HaveCount 1
        $moveErrors[0].FullyQualifiedErrorId | Should -BeLike 'MoveError,*'
        $moveErrors[0].CategoryInfo.Category | Should -Be 'InvalidOperation'
        $moveErrors[0].Exception.Message | Should -BeLike "*'$source'*another volume*"
        $moveErrors[0].TargetObject | Should -Be $source
        $source | Should -Exist
        $destination | Should -Not -Exist
    }

    It 'Should still move a file to another volume' -Skip:(-not $canUseAdminShare) {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'CrossVolumeFile'
        $destination = Join-Path -Path $sandbox -ChildPath ('Moved-{0}' -f (Split-Path -Path $source -Leaf))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $destination

        Move-Item2 -Path $source -Destination (ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $destination) -ErrorAction Stop

        $source | Should -Not -Exist
        Get-Content -LiteralPath $destination | Should -Be 'CrossVolumeFile'
    }

    # With -Force, a file moves without CopyAllowed, which Windows refuses for another volume, as the cmdlet page says.
    # The cmdlet writes that error of Windows, (17) "The system cannot move the file to a different disk drive", and
    # not the error for a folder.
    It 'Should write the error of Windows for a file that it moves with -Force to another volume' -Skip:(-not $canUseAdminShare) {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'CrossVolumeForce'
        $destination = Join-Path -Path $sandbox -ChildPath ('Moved-{0}' -f (Split-Path -Path $source -Leaf))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $destination

        Move-Item2 -Path $source -Destination (ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $destination) -Force -ErrorVariable moveErrors -ErrorAction SilentlyContinue

        $moveErrors | Should -HaveCount 1
        $moveErrors[0].FullyQualifiedErrorId | Should -BeLike 'MoveError,*'
        $moveErrors[0].CategoryInfo.Category | Should -Be 'InvalidData'
        '0x{0:X8}' -f $moveErrors[0].Exception.HResult | Should -Be '0x80070011'
        $source | Should -Exist
        $destination | Should -Not -Exist
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

Describe 'Test-Path2' {
    BeforeAll {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'TestPath' -Directory
        $file = Join-Path -Path $folder -ChildPath 'File.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        Set-Content -LiteralPath $file -Value 'File'
        $missing = Join-Path -Path $folder -ChildPath 'Missing.txt'
        $paths = @{ 'file' = $file; 'folder' = $folder; 'missing item' = $missing }
    }

    It 'Should return <Expected> for a <Kind> with -PathType <PathType>' -ForEach @(
        @{ Kind = 'file'; PathType = 'Any'; Expected = $true }
        @{ Kind = 'folder'; PathType = 'Any'; Expected = $true }
        @{ Kind = 'missing item'; PathType = 'Any'; Expected = $false }
        @{ Kind = 'file'; PathType = 'Leaf'; Expected = $true }
        @{ Kind = 'folder'; PathType = 'Leaf'; Expected = $false }
        @{ Kind = 'missing item'; PathType = 'Leaf'; Expected = $false }
        @{ Kind = 'file'; PathType = 'Container'; Expected = $false }
        @{ Kind = 'folder'; PathType = 'Container'; Expected = $true }
        @{ Kind = 'missing item'; PathType = 'Container'; Expected = $false }
    ) {
        $result = @(Test-Path2 -Path $paths[$Kind] -PathType $PathType -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType [bool]
        $result[0] | Should -Be $Expected
    }

    It 'Should write one value per path in the order of the paths' {
        $result = @(Test-Path2 -Path $file, $missing, $folder -ErrorAction Stop)

        $result -join ',' | Should -Be 'True,False,True'
    }

    It 'Should take the items from the pipeline' {
        $result = @(Get-ChildItem -LiteralPath $folder | Test-Path2 -PathType Leaf -ErrorAction Stop)

        $result -join ',' | Should -Be 'True'
    }

    It 'Should resolve a relative path against the current location' {
        $relative = Join-Path -Path (Split-Path -Path $folder -Leaf) -ChildPath 'File.txt'

        Test-Path2 -Path $relative -ErrorAction Stop | Should -BeTrue
    }

    It 'Should find a folder whose path is longer than 260 characters' {
        $longRoot = Join-Path -Path $folder -ChildPath 'Long'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $longRoot
        $long = Join-Path -Path $longRoot -ChildPath (('A' * 100), ('B' * 100), ('C' * 100) -join '\')
        Add-Type -Path (Join-Path -Path (Get-Module -Name NTFSSecurity).ModuleBase -ChildPath 'AlphaFS.dll')
        [Alphaleonis.Win32.Filesystem.Directory]::CreateDirectory($long) | Out-Null
        $long.Length | Should -BeGreaterThan 260

        Test-Path2 -Path $long -PathType Container -ErrorAction Stop | Should -BeTrue
    }

    # Before 5.0.0-rc6, a path with a character that Windows doesn't allow in file names stopped the cmdlet with a
    # terminating "Illegal characters in path" error in Windows PowerShell. Such an item can't exist, so the cmdlet
    # writes $false like for any other missing item, as in PowerShell 7 and like Test-Path.
    It 'Should return $false for a path with the character <_> and continue with the next path' -ForEach @('|', '<', '>', '"', '*', '?') {
        $invalid = Join-Path -Path $folder -ChildPath ('a{0}b' -f $_)

        $result = @(Test-Path2 -Path $invalid, $file -ErrorVariable testErrors -ErrorAction SilentlyContinue)

        $testErrors | Should -BeNullOrEmpty
        $result -join ',' | Should -Be 'False,True'
    }

    # PowerShell 7 accepts these characters and finds no item, so only Windows PowerShell rejects the path. Before
    # 5.0.0-rc6, the cmdlet wrote $false for a rejected path without saying why. -Debug would prompt in Windows
    # PowerShell, so the test sets the preference.
    It 'Should say in a debug message why it writes $false for a path that Windows PowerShell rejects' -Skip:($PSVersionTable.PSEdition -ne 'Desktop') {
        $invalid = Join-Path -Path $folder -ChildPath 'a|b'
        $DebugPreference = 'Continue'

        $output = @(Test-Path2 -Path $invalid -ErrorAction Stop 5>&1)

        $messages = @($output | Where-Object -FilterScript { $_ -is [Management.Automation.DebugRecord] } |
                Where-Object -Property Message -Like -Value '*is not a valid path*')
        $messages | Should -HaveCount 1
        $messages[0].Message.Contains("'$invalid'") | Should -BeTrue
        $output | Where-Object -FilterScript { $_ -is [bool] } | Should -BeFalse
    }
}

Describe 'Get-DiskSpace' {
    BeforeAll {
        $systemDrive = New-Object -TypeName 'System.IO.DriveInfo' -ArgumentList $env:SystemDrive
    }

    It 'Should return the size of the system drive' {
        $result = @(Get-DiskSpace -DriveLetter $env:SystemDrive -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.DiskSpaceInfo]
        $result[0].DriveName | Should -Be ('{0}\' -f $env:SystemDrive)
        $result[0].TotalNumberOfBytes | Should -Be $systemDrive.TotalSize
    }

    It 'Should report free space and clusters that fit the size' {
        $result = Get-DiskSpace -DriveLetter $env:SystemDrive -ErrorAction Stop

        $result.TotalNumberOfFreeBytes | Should -BeLessOrEqual $result.TotalNumberOfBytes
        $result.FreeBytesAvailable | Should -BeLessOrEqual $result.TotalNumberOfFreeBytes
        $result.ClusterSize | Should -Be ($result.BytesPerSector * $result.SectorsPerCluster)
        $result.NumberOfFreeClusters | Should -BeLessOrEqual $result.TotalNumberOfClusters
    }

    It 'Should return the volumes with a size greater than zero without -DriveLetter' {
        $result = @(Get-DiskSpace -WarningAction SilentlyContinue -ErrorAction Stop)

        $result | Should -Not -BeNullOrEmpty
        $result | ForEach-Object -Process { $_.TotalNumberOfBytes | Should -BeGreaterThan 0 }
        $result.TotalNumberOfBytes | Should -Contain $systemDrive.TotalSize
    }

    It 'Should warn and return nothing for a drive letter without a volume' {
        $used = @((Get-PSDrive -PSProvider FileSystem).Name) + @([System.IO.DriveInfo]::GetDrives() | ForEach-Object -Process { $_.Name.Substring(0, 1) })
        $letter = [char[]](68..90) | Where-Object -FilterScript { [string] $_ -notin $used } | Select-Object -Last 1
        if (-not $letter) {
            Set-ItResult -Skipped -Because 'every drive letter is in use'
            return
        }

        $result = @(Get-DiskSpace -DriveLetter "${letter}:" -WarningVariable spaceWarnings -WarningAction SilentlyContinue -ErrorVariable spaceErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        $spaceErrors | Should -BeNullOrEmpty
        $spaceWarnings.Message | Should -Be "Could not get drive details for '${letter}:'"
    }

    It 'Should reject a drive letter without a colon' {
        { Get-DiskSpace -DriveLetter 'C' -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,NTFSSecurity.GetDiskSpace'
    }
}
