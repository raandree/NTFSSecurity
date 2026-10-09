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
    $canCreateSymbolicLinks = Test-PrivilegeHeld -Name 'SeCreateSymbolicLinkPrivilege'
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

    Context 'Attribute switches' {
        BeforeAll {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Switches' -Directory
            $attributeCases = @{
                'Plain.txt' = 'Normal'
                'Hidden.txt' = 'Hidden'
                'System.txt' = 'System'
                'ReadOnly.txt' = 'ReadOnly'
                'HiddenSystem.txt' = 'Hidden, System'
                'HiddenReadOnly.txt' = 'Hidden, ReadOnly'
                'All.txt' = 'Hidden, ReadOnly, System'
            }
            foreach ($name in $attributeCases.Keys) {
                $path = Join-Path -Path $folder -ChildPath $name
                Assert-TestSandboxPath -Sandbox $sandbox -Path $path
                Set-Content -LiteralPath $path -Value $name
                [IO.File]::SetAttributes($path, [IO.FileAttributes] $attributeCases[$name])
            }
        }

        It 'Should apply <Case> without broadening the other attribute filters' -ForEach @(
            @{ Case = 'default'; Parameters = @{}; Expected = @('Plain.txt', 'System.txt', 'ReadOnly.txt') }
            @{ Case = 'Force'; Parameters = @{ Force = $true }; Expected = @('Plain.txt', 'Hidden.txt', 'System.txt', 'ReadOnly.txt', 'HiddenSystem.txt', 'HiddenReadOnly.txt', 'All.txt') }
            @{ Case = 'Hidden'; Parameters = @{ Hidden = $true }; Expected = @('Hidden.txt', 'HiddenSystem.txt', 'HiddenReadOnly.txt', 'All.txt') }
            @{ Case = 'System'; Parameters = @{ System = $true }; Expected = @('System.txt') }
            @{ Case = 'System with Force'; Parameters = @{ System = $true; Force = $true }; Expected = @('System.txt', 'HiddenSystem.txt', 'All.txt') }
            @{ Case = 'ReadOnly'; Parameters = @{ ReadOnly = $true }; Expected = @('ReadOnly.txt') }
            @{ Case = 'ReadOnly with Force'; Parameters = @{ ReadOnly = $true; Force = $true }; Expected = @('ReadOnly.txt', 'HiddenReadOnly.txt', 'All.txt') }
            @{ Case = 'Hidden and System'; Parameters = @{ Hidden = $true; System = $true }; Expected = @('HiddenSystem.txt', 'All.txt') }
            @{ Case = 'Hidden and ReadOnly'; Parameters = @{ Hidden = $true; ReadOnly = $true }; Expected = @('HiddenReadOnly.txt', 'All.txt') }
            @{ Case = 'System and ReadOnly with Force'; Parameters = @{ System = $true; ReadOnly = $true; Force = $true }; Expected = @('All.txt') }
        ) {
            $result = @(Get-ChildItem2 -Path $folder @Parameters -ErrorAction Stop)

            ($result.Name | Sort-Object) -join ',' | Should -Be (($Expected | Sort-Object) -join ',')
        }
    }

    It 'Should include the first hidden item without requiring explicit -Force' {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'FirstHidden' -Directory
        $file = Join-Path -Path $folder -ChildPath 'Only.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        Set-Content -LiteralPath $file -Value 'Hidden'
        [IO.File]::SetAttributes($file, [IO.FileAttributes]::Hidden)

        $result = @(Get-ChildItem2 -Path $folder -Hidden -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $file
    }

    Context 'Recursion, type filters, and depth' {
        BeforeAll {
            $tree = New-TestSandboxItem -Sandbox $sandbox -Name 'EnumerationTree' -Directory
            $grandchild = Join-Path -Path $tree -ChildPath 'Child\Grandchild'
            $paths = @('Root.txt', 'Child\Child.log', 'Child\Grandchild\Grand.TXT') | ForEach-Object { Join-Path -Path $tree -ChildPath $_ }
            Assert-TestSandboxPath -Sandbox $sandbox -Path (@($grandchild) + @($paths))
            New-Item -ItemType Directory -Path $grandchild -Force | Out-Null
            foreach ($path in $paths) { Set-Content -LiteralPath $path -Value 'Tree' }
        }

        It 'Should return the exact tree for <Case>' -ForEach @(
            @{ Case = 'immediate children'; Parameters = @{}; Expected = @('Child', 'Root.txt') }
            @{ Case = 'all descendants'; Parameters = @{ Recurse = $true }; Expected = @('Child', 'Root.txt', 'Child\Grandchild', 'Child\Child.log', 'Child\Grandchild\Grand.TXT') }
            @{ Case = 'depth zero'; Parameters = @{ Recurse = $true; Depth = 0 }; Expected = @('Child', 'Root.txt') }
            @{ Case = 'depth one'; Parameters = @{ Recurse = $true; Depth = 1 }; Expected = @('Child', 'Root.txt', 'Child\Grandchild', 'Child\Child.log') }
            @{ Case = 'depth two'; Parameters = @{ Recurse = $true; Depth = 2 }; Expected = @('Child', 'Root.txt', 'Child\Grandchild', 'Child\Child.log', 'Child\Grandchild\Grand.TXT') }
            @{ Case = 'directories'; Parameters = @{ Recurse = $true; Directory = $true }; Expected = @('Child', 'Child\Grandchild') }
            @{ Case = 'files'; Parameters = @{ Recurse = $true; File = $true }; Expected = @('Root.txt', 'Child\Child.log', 'Child\Grandchild\Grand.TXT') }
            @{ Case = 'case-insensitive file filter'; Parameters = @{ Recurse = $true; File = $true; Filter = '*.txt' }; Expected = @('Root.txt', 'Child\Grandchild\Grand.TXT') }
        ) {
            $result = @(Get-ChildItem2 -Path $tree @Parameters -ErrorAction Stop)
            $relative = @($result | ForEach-Object { $_.FullName.Substring($tree.Length + 1) })

            ($relative | Sort-Object) -join ',' | Should -Be (($Expected | Sort-Object) -join ',')
        }

        # The pattern must match the name of the item, not its short name (8.3), which Get-ChildItem in Windows PowerShell
        # also compares: there, *.htm returns Page2.html on a volume that creates short names.
        It 'Should return only the items whose name matches -Filter <Filter>' -ForEach @(
            @{ Filter = '*.htm'; Expected = @('Page.htm') }
            @{ Filter = 'Page?.html'; Expected = @('Page2.html') }
            @{ Filter = 'PAGE*'; Expected = @('Page.htm', 'Page2.html') }
        ) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'FilterNames' -Directory
            foreach ($name in 'Page.htm', 'Page2.html') {
                $file = Join-Path -Path $folder -ChildPath $name
                Assert-TestSandboxPath -Sandbox $sandbox -Path $file
                Set-Content -LiteralPath $file -Value $name
            }

            $result = @(Get-ChildItem2 -Path $folder -Filter $Filter -ErrorAction Stop)

            ($result.Name | Sort-Object) -join ',' | Should -Be (($Expected | Sort-Object) -join ',')
        }

        # Only * and ? are wildcards in -Filter. A bracket stands for itself, so a file with brackets in its name is found
        # by its name, as Get-ChildItem finds it, and the file that the brackets would select as a character class is not.
        # Before 5.0.0, the cmdlet read [1] as a character class and returned nothing.
        It 'Should find a file whose name contains brackets by that name with -Filter' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'FilterBrackets' -Directory
            foreach ($name in 'Report[1].txt', 'Report1.txt') {
                $file = Join-Path -Path $folder -ChildPath $name
                Assert-TestSandboxPath -Sandbox $sandbox -Path $file
                Set-Content -LiteralPath $file -Value $name
            }

            $result = @(Get-ChildItem2 -Path $folder -Filter 'Report[1].txt' -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0].Name | Should -BeExactly 'Report[1].txt'
        }

        It 'Should stop a recursive pipeline without recording an enumeration error' {
            $result = @(Get-ChildItem2 -Path $tree -Recurse -ErrorVariable childErrors -ErrorAction SilentlyContinue | Select-Object -First 1)

            $result | Should -HaveCount 1
            $childErrors | Should -BeNullOrEmpty
        }

        # The second file comes from a sub folder, so the pipeline stops while the cmdlet is inside the recursion.
        It 'Should stop a recursive pipeline inside a sub folder without recording an enumeration error' {
            $result = @(Get-ChildItem2 -Path $tree -Recurse -File -ErrorVariable childErrors -ErrorAction SilentlyContinue | Select-Object -First 2)

            $result | Should -HaveCount 2
            $childErrors | Should -BeNullOrEmpty
        }

        # A break or continue in a later pipeline stage passes through the cmdlet as an exception, which it must not
        # report as a failed folder.
        It 'Should end a recursive enumeration for <Keyword> in a later pipeline stage without recording an enumeration error' -ForEach @(
            @{ Keyword = 'break' }
            @{ Keyword = 'continue' }
        ) {
            $names = [System.Collections.Generic.List[string]]::new()
            foreach ($round in 1) {
                Get-ChildItem2 -Path $tree -Recurse -File -ErrorVariable childErrors -ErrorAction SilentlyContinue | ForEach-Object -Process {
                    $names.Add($_.Name)
                    if ($Keyword -eq 'break') { break } else { continue }
                }
            }

            $names | Should -HaveCount 1
            $childErrors | Should -BeNullOrEmpty
        }
    }

    Context 'Unreadable directories' {
        It 'Should report the denied folder and continue with the next path' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'CannotList' -Directory
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'CanList' -Directory
            $file = Join-Path -Path $next -ChildPath 'Next.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            Set-Content -LiteralPath $file -Value 'Next'
            Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ 'S-1-1-0' = 'ReadData' }

            $result = @(Get-ChildItem2 -Path $blocked, $next -ErrorVariable childErrors -ErrorAction SilentlyContinue)

            $childErrors | Should -HaveCount 1
            $childErrors[0].FullyQualifiedErrorId | Should -BeLike 'DirUnauthorizedAccessError,*'
            $childErrors[0].CategoryInfo.Category | Should -Be 'PermissionDenied'
            $childErrors[0].TargetObject | Should -Be $blocked
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $file
        }
    }

    Context 'Link traversal' {
        It 'Should return a junction itself but skip its contents with -SkipMountPoints' {
            $root = New-TestSandboxItem -Sandbox $sandbox -Name 'JunctionListing' -Directory
            $target = New-TestSandboxItem -Sandbox $sandbox -Name 'JunctionTarget' -Directory
            $file = Join-Path -Path $target -ChildPath 'Target.txt'
            $link = Join-Path -Path $root -ChildPath 'Link'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file, $link
            Set-Content -LiteralPath $file -Value 'Target'
            New-Item -ItemType Junction -Path $link -Value $target | Out-Null

            $result = @(Get-ChildItem2 -Path $root -Recurse -SkipMountPoints -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $link
            Get-Content -LiteralPath $file | Should -Be 'Target'
        }

        It 'Should return a symbolic link itself but skip its contents with -SkipSymbolicLinks' -Skip:(-not $canCreateSymbolicLinks) {
            $root = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicListing' -Directory
            $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicTarget' -Directory
            $file = Join-Path -Path $target -ChildPath 'Target.txt'
            $link = Join-Path -Path $root -ChildPath 'Link'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file, $link
            Set-Content -LiteralPath $file -Value 'Target'
            New-NTFSSymbolicLink -Path $link -Target $target -ErrorAction Stop

            $result = @(Get-ChildItem2 -Path $root -Recurse -SkipSymbolicLinks -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $link
            Get-Content -LiteralPath $file | Should -Be 'Target'
        }

        # A junction whose target is gone passes the existence check, but the folder behind it can't be opened. The
        # error belongs to that folder, and the enumeration goes on with the next one.
        It 'Should report a junction whose target was removed as a DirUnspecifiedError and continue with the next folder' {
            $root = New-TestSandboxItem -Sandbox $sandbox -Name 'BrokenJunction' -Directory
            $target = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovedTarget' -Directory
            $link = Join-Path -Path $root -ChildPath 'Broken'
            $sibling = Join-Path -Path $root -ChildPath 'Sibling'
            $file = Join-Path -Path $sibling -ChildPath 'Sibling.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $link, $sibling, $file
            New-Item -ItemType Directory -Path $sibling | Out-Null
            Set-Content -LiteralPath $file -Value 'Sibling'
            New-Item -ItemType Junction -Path $link -Value $target | Out-Null
            Remove-Item -LiteralPath $target -Force

            $result = @(Get-ChildItem2 -Path $root -Recurse -ErrorVariable childErrors -ErrorAction SilentlyContinue)

            $childErrors | Should -HaveCount 1
            $childErrors[0].FullyQualifiedErrorId | Should -BeLike 'DirUnspecifiedError,*'
            $childErrors[0].CategoryInfo.Category | Should -Be 'NotSpecified'
            $childErrors[0].TargetObject | Should -Be $link
            $childErrors[0].Exception | Should -BeOfType [System.IO.DirectoryNotFoundException]
            @($result.FullName | Sort-Object) | Should -Be @(@($link, $sibling, $file) | Sort-Object)
            Get-Content -LiteralPath $file | Should -Be 'Sibling'
        }
    }

    Context 'Optional object properties' {
        BeforeEach {
            $settings = (Get-Module -Name NTFSSecurity).PrivateData
            $savedMode = $settings['GetFileSystemModeProperty']
            $savedHardLinks = $settings['IdentifyHardLinks']
        }

        AfterEach {
            $settings['GetFileSystemModeProperty'] = $savedMode
            $settings['IdentifyHardLinks'] = $savedHardLinks
        }

        It 'Should honor Mode and HardLinkCount enabled=<_>' -ForEach @($true, $false) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ObjectProperties' -Directory
            $file = Join-Path -Path $folder -ChildPath 'File.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            Set-Content -LiteralPath $file -Value 'Properties'
            [IO.File]::SetAttributes($file, [IO.FileAttributes]::Archive)
            $settings['GetFileSystemModeProperty'] = $_
            $settings['IdentifyHardLinks'] = $_

            $item = Get-ChildItem2 -Path $file -ErrorAction Stop

            if ($_) {
                $item.Mode | Should -BeExactly '-a---'
                $item.HardLinkCount | Should -Be 1
            }
            else {
                $item.PSObject.Properties['Mode'] | Should -BeNullOrEmpty
                $item.PSObject.Properties['HardLinkCount'] | Should -BeNullOrEmpty
            }
        }

        It 'Should render read-only, hidden, and system bits in the Mode property' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ModeBits'
            [IO.File]::SetAttributes($file, [IO.FileAttributes] 'ReadOnly, Hidden, System')
            $settings['GetFileSystemModeProperty'] = $true

            $item = Get-ChildItem2 -Path $file -Force -ErrorAction Stop

            $item.Mode | Should -BeExactly '--rhs'
        }

        It 'Should render a folder with a d in the Mode property' {
            $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'ModeFolder' -Directory
            $folder = Join-Path -Path $parent -ChildPath 'Inner'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $folder
            New-Item -ItemType Directory -Path $folder | Out-Null
            $settings['GetFileSystemModeProperty'] = $true

            $item = Get-ChildItem2 -Path $parent -ErrorAction Stop

            $item | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
            $item.Mode | Should -BeExactly 'd----'
        }

        It 'Should return an empty Mode for no object' {
            [NTFSSecurity.FileSystemCodeMembers]::Mode($null) | Should -BeExactly ''
        }

        # Windows can't list the hard links of a file on a network share, (50) "The request is not supported". The cmdlet
        # still returns the file, without HardLinkCount, and says why in a debug message. The test sets the preference,
        # because -Debug would prompt in Windows PowerShell.
        It 'Should return a file on a network share without HardLinkCount and say why in a debug message' -Skip:(-not $canUseAdminShare) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ShareProperties' -Directory
            $file = Join-Path -Path $folder -ChildPath 'Share.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $file
            Set-Content -LiteralPath $file -Value 'Share'
            $sharePath = ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $file
            $settings['IdentifyHardLinks'] = $true
            $DebugPreference = 'Continue'

            $output = @(Get-ChildItem2 -Path $sharePath -ErrorVariable childErrors -ErrorAction SilentlyContinue 5>&1)

            $childErrors | Should -BeNullOrEmpty
            $items = @($output | Where-Object -FilterScript { $_ -isnot [Management.Automation.DebugRecord] })
            $items | Should -HaveCount 1
            $items[0].Name | Should -BeExactly 'Share.txt'
            $items[0].PSObject.Properties['HardLinkCount'] | Should -BeNullOrEmpty
            $messages = @($output | Where-Object -FilterScript { $_ -is [Management.Automation.DebugRecord] } | ForEach-Object -Process { $_.Message })
            $messages | Should -Contain "Could not read hard links for '$sharePath'"
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

    It 'Move-Item2 -Force should replace an existing file with PassThru=<_>' -ForEach @($false, $true) {
        $target = Join-Path -Path $destination -ChildPath 'First.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $target
        Set-Content -LiteralPath $target -Value 'Previous'
        $expected = Get-Content -LiteralPath $first -Raw

        $result = @(Move-Item2 -Path $first -Destination $destination -Force -PassThru $_ -ErrorAction Stop)

        $first | Should -Not -Exist
        Get-Content -LiteralPath $target -Raw | Should -BeExactly $expected
        if ($_) {
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $target
        }
        else {
            $result | Should -BeNullOrEmpty
        }
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

    # A sharing violation is an IOException, which both cmdlets write as InvalidData; the error belongs to its source
    # only, and no object comes out for it with -PassThru.
    It '<Command> should write a <ErrorId> for a source that another process has locked and continue with the next path' -ForEach @(
        @{ Command = 'Copy-Item2'; ErrorId = 'CopyError' }
        @{ Command = 'Move-Item2'; ErrorId = 'MoveError' }
    ) {
        $stream = [IO.File]::Open($first, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        try {
            $result = @(& $Command -Path $first, $second -Destination $destination -PassThru $true -ErrorVariable itemErrors -ErrorAction SilentlyContinue)
        }
        finally {
            $stream.Dispose()
        }

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $itemErrors[0].CategoryInfo.Category | Should -Be 'InvalidData'
        $itemErrors[0].TargetObject | Should -Be $first
        $itemErrors[0].Exception | Should -BeOfType [System.IO.IOException]
        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be (Join-Path -Path $destination -ChildPath 'Second.txt')
        Join-Path -Path $destination -ChildPath 'First.txt' | Should -Not -Exist
        Get-Content -LiteralPath $first | Should -Be 'First'
        Get-Content -LiteralPath (Join-Path -Path $destination -ChildPath 'Second.txt') | Should -Be 'Second'
    }

    # Any other failure of Windows is not an IOException, and both cmdlets write it as NotSpecified. A deny entry for
    # Everyone also applies to an administrator, who doesn't bypass the DACL without a backup privilege.
    It '<Command> should write a <ErrorId> for each source when the destination folder denies new files' -ForEach @(
        @{ Command = 'Copy-Item2'; ErrorId = 'CopyError' }
        @{ Command = 'Move-Item2'; ErrorId = 'MoveError' }
    ) {
        $denied = Join-Path -Path $folder -ChildPath 'Denied'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $denied
        New-Item -ItemType Directory -Path $denied | Out-Null
        Add-TestDenyRule -Sandbox $sandbox -Path $denied -Rights @{ 'S-1-1-0' = 'CreateFiles' }

        $result = @(& $Command -Path $first, $second -Destination $denied -PassThru $true -ErrorVariable itemErrors -ErrorAction SilentlyContinue)

        $itemErrors | Should -HaveCount 2
        for ($index = 0; $index -lt 2; $index++) {
            $itemErrors[$index].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
            $itemErrors[$index].CategoryInfo.Category | Should -Be 'NotSpecified'
            $itemErrors[$index].TargetObject | Should -Be @($first, $second)[$index]
            $itemErrors[$index].Exception | Should -BeOfType [System.UnauthorizedAccessException]
        }
        $result | Should -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath $denied -Force) | Should -BeNullOrEmpty
        Get-Content -LiteralPath $first | Should -Be 'First'
        Get-Content -LiteralPath $second | Should -Be 'Second'
    }

    # A destination on a drive letter without a volume has no folder that the cmdlet could name, so Windows reports the
    # drive as not ready, which AlphaFS raises as an IOException.
    It '<Command> should write a <ErrorId> for a destination on a drive that does not exist and keep the source' -ForEach @(
        @{ Command = 'Copy-Item2'; ErrorId = 'CopyError' }
        @{ Command = 'Move-Item2'; ErrorId = 'MoveError' }
    ) {
        $used = @((Get-PSDrive -PSProvider FileSystem).Name) + @([System.IO.DriveInfo]::GetDrives() | ForEach-Object -Process { $_.Name.Substring(0, 1) })
        $letter = [char[]](68..90) | Where-Object -FilterScript { [string] $_ -notin $used } | Select-Object -Last 1
        if (-not $letter) {
            Set-ItResult -Skipped -Because 'every drive letter is in use'
            return
        }

        $result = @(& $Command -Path $first -Destination "${letter}:\" -PassThru $true -ErrorVariable itemErrors -ErrorAction SilentlyContinue)

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $itemErrors[0].CategoryInfo.Category | Should -Be 'InvalidData'
        $itemErrors[0].TargetObject | Should -Be $first
        $itemErrors[0].Exception | Should -BeOfType [System.IO.IOException]
        $result | Should -BeNullOrEmpty
        Get-Content -LiteralPath $first | Should -Be 'First'
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

Describe 'Relative paths' {
    BeforeAll {
        $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'RelativeParent' -Directory
        $child = Join-Path -Path $parent -ChildPath 'Child'
        $sibling = Join-Path -Path $parent -ChildPath 'Sibling'
        $siblingFile = Join-Path -Path $sibling -ChildPath 'Sibling.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $child, $sibling, $siblingFile
        New-Item -ItemType Directory -Path $child, $sibling | Out-Null
        Set-Content -LiteralPath $siblingFile -Value 'Sibling'
    }

    It 'Get-Item2 should resolve <Path> against the current location' -ForEach @(
        @{ Path = '.'; Expected = 'Child' }
        @{ Path = '.\'; Expected = 'Child' }
        @{ Path = '..'; Expected = 'Parent' }
        @{ Path = '..\Sibling'; Expected = 'Sibling' }
        @{ Path = '..\Sibling\Sibling.txt'; Expected = 'SiblingFile' }
        @{ Path = '..\..'; Expected = 'Grandparent' }
    ) {
        $expectedPath = switch ($Expected) {
            'Child' { $child }
            'Parent' { $parent }
            'Sibling' { $sibling }
            'SiblingFile' { $siblingFile }
            'Grandparent' { Split-Path -Path $parent -Parent }
        }
        Push-Location -LiteralPath $child
        try {
            $result = @(Get-Item2 -Path $Path -ErrorAction Stop)
        }
        finally {
            Pop-Location
        }

        $result | Should -HaveCount 1
        $result[0].FullName.TrimEnd('\') | Should -Be $expectedPath
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
Describe 'Get-ChildItem2 when recursive enumeration becomes denied' {
    It 'Should name the failed recursion in verbose output and continue with the next path' {
        $root = New-TestSandboxItem -Sandbox $sandbox -Name 'ChangingReadPermission' -Directory
        $child = Join-Path -Path $root -ChildPath 'Child'
        $first = Join-Path -Path $root -ChildPath 'First.txt'
        $nested = Join-Path -Path $child -ChildPath 'Nested.txt'
        $next = New-TestSandboxItem -Sandbox $sandbox -Name 'NextRecursivePath' -Directory
        $nextFile = Join-Path -Path $next -ChildPath 'Next.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $root, $child, $first, $nested, $nextFile
        New-Item -ItemType Directory -Path $child | Out-Null
        Set-Content -LiteralPath $first -Value 'First'
        Set-Content -LiteralPath $nested -Value 'Nested'
        Set-Content -LiteralPath $nextFile -Value 'Next'
        $ownerBefore = (Get-Acl -LiteralPath $root).Owner

        # The first file is emitted before the separate recursive directory enumeration opens the folder again.
        $records = @(Get-ChildItem2 -Path $root, $next -File -Recurse -Verbose -ErrorVariable childErrors -ErrorAction SilentlyContinue 4>&1 |
                ForEach-Object {
                    if ($_ -is [Alphaleonis.Win32.Filesystem.FileInfo] -and $_.FullName -eq $first) {
                        Add-TestDenyRule -Sandbox $sandbox -Path $root -Rights @{ 'S-1-1-0' = 'ReadData' }
                    }
                    $_
                })

        $childErrors | Should -BeNullOrEmpty
        $files = @($records | Where-Object { $_ -is [Alphaleonis.Win32.Filesystem.FileInfo] })
        @($files.FullName | Sort-Object) | Should -Be @(@($first, $nextFile) | Sort-Object)
        $messages = @($records | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
        $messages.Message | Should -Contain "Cannot access folder '$root' for recursive operation"
        (Get-Acl -LiteralPath $root).Owner | Should -BeExactly $ownerBefore
        Get-Content -LiteralPath $nested | Should -BeExactly 'Nested'
    }
}
