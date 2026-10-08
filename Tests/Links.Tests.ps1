<#
    Tests the link cmdlets of the module built in NTFSSecurity\bin\Release in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canCreateSymbolicLinks = Test-PrivilegeHeld -Name 'SeCreateSymbolicLinkPrivilege'
    # The administrative share of the drive of the sandboxes reaches them over SMB, like a share of a file server.
    $canUseAdminShare = Test-AdminShareAvailable
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Links'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'New-NTFSHardLink' {
    It 'Should create a hard link to a file' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'Target'
        $link = Join-Path -Path $sandbox -ChildPath 'Link.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSHardLink -Path $link -Target $target -ErrorAction Stop

        $link | Should -Exist
        Get-Content -LiteralPath $link | Should -Be (Get-Content -LiteralPath $target)
    }

    # Before 5.0.0, the error said "The target path exist" for a target that did not exist.
    It 'Should report that a missing target does not exist' {
        $missing = Join-Path -Path $sandbox -ChildPath 'Missing.txt'
        $link = Join-Path -Path $sandbox -ChildPath 'MissingLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing, $link

        { New-NTFSHardLink -Path $link -Target $missing -ErrorAction Stop } | Should -Throw -ExpectedMessage '*does not exist*'
        $link | Should -Not -Exist
    }

    It 'Should write nothing without -PassThru' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'Quiet'
        $link = Join-Path -Path $sandbox -ChildPath 'QuietLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $result = @(New-NTFSHardLink -Path $link -Target $target -ErrorAction Stop)

        $result | Should -BeNullOrEmpty
    }

    It 'Should return every name of the file with -PassThru' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'Names'
        $link = Join-Path -Path $sandbox -ChildPath 'NamesLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $result = @(New-NTFSHardLink -Path $link -Target $target -PassThru -ErrorAction Stop)

        $result | Should -HaveCount 2
        $result | ForEach-Object -Process { $_ | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo] }
        ($result.FullName | Sort-Object) -join '|' | Should -Be ((@($target, $link) | Sort-Object) -join '|')
        $result[0].Mode | Should -Not -BeNullOrEmpty
    }

    It 'Should give both names the same data' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'Shared'
        $link = Join-Path -Path $sandbox -ChildPath 'SharedLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link
        New-NTFSHardLink -Path $link -Target $target -ErrorAction Stop

        Set-Content -LiteralPath $link -Value 'Changed through the link'

        Get-Content -LiteralPath $target | Should -Be 'Changed through the link'
    }

    It 'Should resolve relative paths against the current location' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'Relative'
        $link = Join-Path -Path $sandbox -ChildPath 'RelativeLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSHardLink -Path 'RelativeLink.txt' -Target (Split-Path -Path $target -Leaf) -ErrorAction Stop

        $link | Should -Exist
    }

    It 'Should refuse an existing -Path and leave it unchanged' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'ExistingTarget'
        $existing = New-TestSandboxItem -Sandbox $sandbox -Name 'Existing'
        Set-Content -LiteralPath $existing -Value 'Existing'

        { New-NTFSHardLink -Path $existing -Target $target -ErrorAction Stop } | Should -Throw -ExpectedMessage '*already exist*'

        Get-Content -LiteralPath $existing | Should -Be 'Existing'
    }

    It 'Should refuse a folder as -Target and create no link' {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'FolderTarget' -Directory
        $link = Join-Path -Path $sandbox -ChildPath 'FolderLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        { New-NTFSHardLink -Path $link -Target $folder -ErrorAction Stop } | Should -Throw -ExpectedMessage '*not a file*'

        $link | Should -Not -Exist
    }

    # Before 5.0.0-rc7, an existing -Path, a missing -Target, or a folder as -Target stopped the pipeline with a
    # terminating error, so the links that followed weren't created.
    It 'Should write a non-terminating error for each link that it cannot create and continue with the next one' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'ContinueTarget'
        $existing = New-TestSandboxItem -Sandbox $sandbox -Name 'ContinueExisting'
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ContinueFolder' -Directory
        $missing = Join-Path -Path $sandbox -ChildPath 'ContinueMissing.txt'
        $missingLink = Join-Path -Path $sandbox -ChildPath 'ContinueMissingLink.txt'
        $folderLink = Join-Path -Path $sandbox -ChildPath 'ContinueFolderLink.txt'
        $link = Join-Path -Path $sandbox -ChildPath 'ContinueLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing, $missingLink, $folderLink, $link
        $requests = @(
            [pscustomobject]@{ Path = $existing; Target = $target }
            [pscustomobject]@{ Path = $missingLink; Target = $missing }
            [pscustomobject]@{ Path = $folderLink; Target = $folder }
            [pscustomobject]@{ Path = $link; Target = $target }
        )

        $requests | New-NTFSHardLink -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 3
        $linkErrors | ForEach-Object -Process { $_.FullyQualifiedErrorId | Should -BeLike 'CreateHardLinkError,*' }
        ($linkErrors | ForEach-Object -Process { $_.CategoryInfo.Category }) -join ',' | Should -Be 'ResourceExists,ObjectNotFound,InvalidArgument'
        ($linkErrors | ForEach-Object -Process { $_.TargetObject }) -join '|' | Should -Be (($existing, $missingLink, $folderLink) -join '|')
        # Since 5.0.0-rc7, the error for a folder as -Target names the folder.
        $linkErrors[2].Exception.Message | Should -BeLike ("*'{0}'*" -f [WildcardPattern]::Escape($folder))
        $link | Should -Exist
        $missingLink | Should -Not -Exist
        $folderLink | Should -Not -Exist
        Get-Content -LiteralPath $existing | Should -Be 'ContinueExisting'
    }

    # Windows can't list the names of a file on a network share. Before 5.0.0-rc6, the cmdlet stopped with a
    # terminating error after it had created the link.
    It 'Should create the link on a network share and write an error for -PassThru, which cannot list the names there' -Skip:(-not $canUseAdminShare) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'ShareTarget'
        $link = Join-Path -Path $sandbox -ChildPath 'ShareLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $result = @(New-NTFSHardLink -Path (ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $link) -Target (ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $target) -PassThru -ErrorVariable linkErrors -ErrorAction SilentlyContinue)

        $link | Should -Exist
        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-NTFSHardLink' {
    It 'Should return the file itself for a file with one name' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Single'

        $result = @(Get-NTFSHardLink -Path $file -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $file
        $result[0].Mode | Should -Not -BeNullOrEmpty
    }

    It 'Should return every name of a file with hard links' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Linked'
        $link = Join-Path -Path $sandbox -ChildPath 'LinkedLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link
        New-NTFSHardLink -Path $link -Target $file -ErrorAction Stop

        $result = @(Get-NTFSHardLink -Path $link -ErrorAction Stop)

        ($result.FullName | Sort-Object) -join '|' | Should -Be ((@($file, $link) | Sort-Object) -join '|')
    }

    It 'Should take the files with more than one name from Get-ChildItem2' {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Counted' -Directory
        $file = Join-Path -Path $folder -ChildPath 'File.txt'
        $link = Join-Path -Path $folder -ChildPath 'Link.txt'
        $other = Join-Path -Path $folder -ChildPath 'Other.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file, $link, $other
        Set-Content -LiteralPath $file, $other -Value 'File'
        New-NTFSHardLink -Path $link -Target $file -ErrorAction Stop

        $result = @(Get-ChildItem2 -Path $folder -File | Where-Object -Property HardLinkCount -GT -Value 1 | Get-NTFSHardLink -ErrorAction Stop)

        $result.FullName | Should -Not -Contain $other
        @($result.FullName | Sort-Object -Unique) -join '|' | Should -Be ((@($file, $link) | Sort-Object) -join '|')
    }

    It 'Should write an error for a path that does not exist and continue with the next path' {
        $missing = Join-Path -Path $sandbox -ChildPath 'MissingHardLink.txt'
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AfterMissing'

        $result = @(Get-NTFSHardLink -Path $missing, $file -ErrorVariable linkErrors -ErrorAction SilentlyContinue)

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'FileNotFound,*'
        $result.FullName | Should -Be $file
    }

    # Before 5.0.0-rc6, a folder stopped the cmdlet with a terminating error, so that it skipped the remaining paths.
    It 'Should write an error for a folder and continue with the next path' {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'HardLinkFolder' -Directory
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AfterFolder'

        $result = @(Get-NTFSHardLink -Path $folder, $file -ErrorVariable linkErrors -ErrorAction SilentlyContinue)

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
        $linkErrors[0].TargetObject | Should -Be $folder
        $linkErrors[0].Exception.Message | Should -Be 'The item must be a file'
        $result.FullName | Should -Be $file
    }

    # Windows can't list the names of a file on a network share. Before 5.0.0-rc6, the cmdlet stopped with a
    # terminating error, so that it skipped the remaining paths.
    It 'Should write an error for a file on a network share and continue with the next path' -Skip:(-not $canUseAdminShare) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ShareFile'
        $other = New-TestSandboxItem -Sandbox $sandbox -Name 'AfterShare'
        $sharePath = ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $file

        $result = @(Get-NTFSHardLink -Path $sharePath, $other -ErrorVariable linkErrors -ErrorAction SilentlyContinue)

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
        $linkErrors[0].TargetObject | Should -Be $sharePath
        $result.FullName | Should -Be $other
    }
}

Describe 'New-NTFSSymbolicLink' {
    BeforeAll {
        function Get-LinkTarget {
            param ([string] $Path)

            # Windows PowerShell returns the target as an array, PowerShell 7 as a string.
            @((Get-Item -LiteralPath $Path -Force).Target)[0]
        }
    }

    It 'Should create a link to a file that reads the data of the file' -Skip:(-not $canCreateSymbolicLinks) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicTarget'
        Set-Content -LiteralPath $target -Value 'Target'
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicFile.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $result = @(New-NTFSSymbolicLink -Path $link -Target $target -ErrorAction Stop)

        $result | Should -BeNullOrEmpty
        (Get-Item -LiteralPath $link -Force).LinkType | Should -Be 'SymbolicLink'
        Get-LinkTarget -Path $link | Should -Be $target
        Get-Content -LiteralPath $link | Should -Be 'Target'
    }

    It 'Should create a link to a folder through which the files of the folder are reachable' -Skip:(-not $canCreateSymbolicLinks) {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicFolder' -Directory
        $file = Join-Path -Path $folder -ChildPath 'File.txt'
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicFolderLink'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file, $link
        Set-Content -LiteralPath $file -Value 'File'

        New-NTFSSymbolicLink -Path $link -Target $folder -ErrorAction Stop

        (Get-Item -LiteralPath $link -Force).Attributes.HasFlag([IO.FileAttributes]::Directory) | Should -BeTrue
        Test-Path2 -Path (Join-Path -Path $link -ChildPath 'File.txt') -PathType Leaf | Should -BeTrue
    }

    It 'Should return a file object for a link to a file with -PassThru' -Skip:(-not $canCreateSymbolicLinks) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicPassThru'
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicPassThru.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $result = New-NTFSSymbolicLink -Path $link -Target $target -PassThru -ErrorAction Stop

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $result.FullName | Should -Be $link
    }

    # Before 5.0.0, the cmdlet returned a file object for a link to a folder.
    It 'Should return a folder object for a link to a folder with -PassThru' -Skip:(-not $canCreateSymbolicLinks) {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicPassThruFolder' -Directory
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicPassThruFolderLink'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $result = New-NTFSSymbolicLink -Path $link -Target $folder -PassThru -ErrorAction Stop

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result.FullName | Should -Be $link
    }

    It 'Should store the absolute path of a relative target' -Skip:(-not $canCreateSymbolicLinks) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicRelative'
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicRelative.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSSymbolicLink -Path 'SymbolicRelative.txt' -Target (Split-Path -Path $target -Leaf) -ErrorAction Stop

        Get-LinkTarget -Path $link | Should -Be $target
    }

    It 'Should refuse an existing -Path and leave it unchanged' -Skip:(-not $canCreateSymbolicLinks) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicExistingTarget'
        $existing = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicExisting'
        Set-Content -LiteralPath $existing -Value 'Existing'

        { New-NTFSSymbolicLink -Path $existing -Target $target -ErrorAction Stop } | Should -Throw -ExpectedMessage '*already exist*'

        (Get-Item -LiteralPath $existing -Force).LinkType | Should -BeNullOrEmpty
        Get-Content -LiteralPath $existing | Should -Be 'Existing'
    }

    It 'Should write an error for a target that does not exist and create no link' {
        $missing = Join-Path -Path $sandbox -ChildPath 'SymbolicMissing.txt'
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicMissingLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing, $link

        New-NTFSSymbolicLink -Path $link -Target $missing -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'CreateSymbolicLinkError,*'
        Test-Path2 -Path $link | Should -BeFalse
    }

    # Before 5.0.0-rc7, an existing -Path stopped the pipeline with a terminating error. The cmdlet checks the paths
    # before it creates a link, so this runs without the right to create symbolic links as well.
    It 'Should write a non-terminating error for an existing -Path and continue with the next link' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicContinueTarget'
        $existing = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicContinueExisting'
        $missing = Join-Path -Path $sandbox -ChildPath 'SymbolicContinueMissing.txt'
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicContinueLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing, $link
        $requests = @(
            [pscustomobject]@{ Path = $existing; Target = $target }
            [pscustomobject]@{ Path = $link; Target = $missing }
        )

        $requests | New-NTFSSymbolicLink -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 2
        $linkErrors | ForEach-Object -Process { $_.FullyQualifiedErrorId | Should -BeLike 'CreateSymbolicLinkError,*' }
        ($linkErrors | ForEach-Object -Process { $_.CategoryInfo.Category }) -join ',' | Should -Be 'ResourceExists,ObjectNotFound'
        (Get-Item -LiteralPath $existing -Force).LinkType | Should -BeNullOrEmpty
        Test-Path2 -Path $link | Should -BeFalse
    }

    # Windows rejects the link with error 1314 without the "Create symbolic links" user right. Its message is
    # localized, so the test compares the HRESULT of that error. Before 5.0.0-rc7, the error was terminating.
    It 'Should write a non-terminating error and create no link without the right to create symbolic links' -Skip:$canCreateSymbolicLinks {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'SymbolicNoRight'
        $link = Join-Path -Path $sandbox -ChildPath 'SymbolicNoRight.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSSymbolicLink -Path $link -Target $target -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'CreateSymbolicLinkError,*'
        '0x{0:X8}' -f $linkErrors[0].Exception.HResult | Should -Be '0x80070522'
        Test-Path2 -Path $link | Should -BeFalse
    }
}

# Each error names its item, so that the errors of many links can be told apart. Before 5.0.0-rc7, the errors of
# New-NTFSSymbolicLink for an existing -Path and a missing -Target named no path. No link is created, so the tests run
# without the right to create symbolic links as well.
Describe 'Errors of the cmdlets that create links' {
    It '<Command> should name the existing -Path and the missing -Target in its errors' -ForEach @(
        @{ Command = 'New-NTFSHardLink' }
        @{ Command = 'New-NTFSSymbolicLink' }
    ) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'NamedTarget'
        $existing = New-TestSandboxItem -Sandbox $sandbox -Name 'NamedExisting'
        $missing = Join-Path -Path $sandbox -ChildPath ('NamedMissing-{0}.txt' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        $link = Join-Path -Path $sandbox -ChildPath ('NamedLink-{0}.txt' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing, $link
        $requests = @(
            [pscustomobject]@{ Path = $existing; Target = $target }
            [pscustomobject]@{ Path = $link; Target = $missing }
        )

        $requests | & $Command -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 2
        $linkErrors[0].Exception.Message | Should -BeLike ("*'{0}'*" -f [WildcardPattern]::Escape($existing))
        $linkErrors[1].Exception.Message | Should -BeLike ("*'{0}'*" -f [WildcardPattern]::Escape($missing))
        Test-Path2 -Path $link | Should -BeFalse
    }

    # Both cmdlets check -Path before -Target. Before 5.0.0-rc7, New-NTFSSymbolicLink checked -Target first and
    # reported a missing target instead.
    It '<Command> should report an existing -Path before a missing -Target' -ForEach @(
        @{ Command = 'New-NTFSHardLink' }
        @{ Command = 'New-NTFSSymbolicLink' }
    ) {
        $existing = New-TestSandboxItem -Sandbox $sandbox -Name 'FirstExisting'
        $missing = Join-Path -Path $sandbox -ChildPath ('FirstMissing-{0}.txt' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing

        & $Command -Path $existing -Target $missing -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].CategoryInfo.Category | Should -Be 'ResourceExists'
        $linkErrors[0].TargetObject | Should -Be $existing
        Get-Content -LiteralPath $existing | Should -Be 'FirstExisting'
    }
}

# Windows PowerShell rejects a character that Windows doesn't allow in a path, such as |, before Windows sees the path.
# Before 5.0.0-rc7, that stopped the pipeline in Windows PowerShell, and PowerShell 7 reported it as a WriteError.
Describe 'Paths that Windows does not allow in the cmdlets that create links' {
    It '<Command> should write a non-terminating InvalidArgument error and continue with the next link' -ForEach @(
        @{ Command = 'New-NTFSHardLink'; ErrorId = 'CreateHardLinkError' }
        @{ Command = 'New-NTFSSymbolicLink'; ErrorId = 'CreateSymbolicLinkError' }
    ) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'InvalidTarget'
        $existing = New-TestSandboxItem -Sandbox $sandbox -Name 'InvalidExisting'
        $invalid = Join-Path -Path $sandbox -ChildPath 'Invalid|Link.txt'
        # The second link exists, so that the cmdlet rejects it before it creates anything, also without the right to
        # create symbolic links; its error shows that the cmdlet went on.
        $requests = @(
            [pscustomobject]@{ Path = $invalid; Target = $target }
            [pscustomobject]@{ Path = $existing; Target = $target }
        )

        $requests | & $Command -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 2
        $linkErrors | ForEach-Object -Process { $_.FullyQualifiedErrorId | Should -BeLike "$ErrorId,*" }
        ($linkErrors | ForEach-Object -Process { $_.CategoryInfo.Category }) -join ',' | Should -Be 'InvalidArgument,ResourceExists'
        $linkErrors[0].TargetObject | Should -Be $invalid
        Get-Content -LiteralPath $existing | Should -Be 'InvalidExisting'
    }
}

# Before 5.0.0-rc7, both parameters were optional. Without -Path, the cmdlets failed with an index error; without -Target,
# they used the current location, so New-NTFSSymbolicLink -Path Link created a link to the current folder.
Describe 'Parameters of the cmdlets that create links' {
    It '<Command> should require -<Parameter>' -ForEach @(
        @{ Command = 'New-NTFSHardLink'; Parameter = 'Path' }
        @{ Command = 'New-NTFSHardLink'; Parameter = 'Target' }
        @{ Command = 'New-NTFSSymbolicLink'; Parameter = 'Path' }
        @{ Command = 'New-NTFSSymbolicLink'; Parameter = 'Target' }
    ) {
        $sets = @((Get-Command -Name $Command).Parameters[$Parameter].ParameterSets.Values)

        $sets | Should -Not -BeNullOrEmpty
        $sets | ForEach-Object -Process { $_.IsMandatory | Should -BeTrue }
    }
}
