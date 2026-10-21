<#
    Closes TestNeeded gaps that the judged parameter-set matrix found in the item, link, hash, privilege, and
    disk-space cmdlets of the module built in NTFSSecurity\bin\Release: no test piped into Copy-Item2, Get-ChildItem2,
    Get-Item2, Move-Item2, or Remove-Item2; an empty or null -Path/-Target never falls back to the current location;
    missing error categories and output types; and continuation after an earlier item in the same pipeline. It does not
    pin the -Filter dot rules, the Decision 22 behaviors, the PrivilegeEnabler class, or the owner-restore handlers,
    which are covered and decided elsewhere.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canCreateSymbolicLinks = Test-PrivilegeHeld -Name 'SeCreateSymbolicLinkPrivilege'
    # The restricted token of the basic-user runner cannot map a drive letter or reach the administrative share.
    $canMapDrive = Test-DriveMappingAvailable
    $canUseAdminShare = Test-AdminShareAvailable
    $isElevated = Test-IsElevated
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'ParameterSetsItems'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Copy-Item2 and Move-Item2 accept pipeline input' {
    # The cmdlet pages document piping Get-ChildItem2 output into Copy-Item2/Move-Item2, but no existing test pipes
    # anything into either cmdlet. A missing item in the middle of the pipeline must not stop the surrounding items.
    It '<Command> should accept <InputKind> piped by value and still process the surrounding items' -ForEach @(
        @{ Command = 'Copy-Item2'; InputKind = 'plain path strings with a missing item in the middle' }
        @{ Command = 'Copy-Item2'; InputKind = 'Get-ChildItem2 file objects' }
        @{ Command = 'Move-Item2'; InputKind = 'plain path strings with a missing item in the middle' }
        @{ Command = 'Move-Item2'; InputKind = 'Get-ChildItem2 file objects' }
    ) {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'PipelineItems' -Directory
        $destination = Join-Path -Path $folder -ChildPath 'Destination'
        $first = Join-Path -Path $folder -ChildPath 'First.txt'
        $second = Join-Path -Path $folder -ChildPath 'Second.txt'
        $missing = Join-Path -Path $folder -ChildPath 'Missing.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $destination, $first, $second, $missing
        New-Item -ItemType Directory -Path $destination | Out-Null
        Set-Content -LiteralPath $first -Value 'First'
        Set-Content -LiteralPath $second -Value 'Second'

        $usesMissingItem = $InputKind -like '*missing item*'
        $items = if ($usesMissingItem) {
            @($first, $missing, $second)
        }
        else {
            @(Get-ChildItem2 -Path $folder -File -ErrorAction Stop)
        }

        $result = @($items | & $Command -Destination $destination -PassThru $true -ErrorVariable itemErrors -ErrorAction SilentlyContinue)

        if ($usesMissingItem) {
            $itemErrors | Should -HaveCount 1
            $itemErrors[0].FullyQualifiedErrorId | Should -BeLike 'FileNotFound,*'
            $itemErrors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
            $itemErrors[0].TargetObject | Should -Be $missing
            $itemErrors[0].Exception | Should -BeOfType [System.IO.FileNotFoundException]
        }
        else {
            $itemErrors | Should -BeNullOrEmpty
        }
        $result | Should -HaveCount 2
        $destinationFirst = Join-Path -Path $destination -ChildPath 'First.txt'
        $destinationSecond = Join-Path -Path $destination -ChildPath 'Second.txt'
        @($result.FullName | Sort-Object) | Should -Be (@($destinationFirst, $destinationSecond) | Sort-Object)
        Get-Content -LiteralPath $destinationFirst | Should -Be 'First'
        Get-Content -LiteralPath $destinationSecond | Should -Be 'Second'
        if ($Command -eq 'Copy-Item2') {
            $first | Should -Exist
            $second | Should -Exist
        }
        else {
            $first | Should -Not -Exist
            $second | Should -Not -Exist
        }
    }
}

Describe 'Get-ChildItem2 accepts pipeline input' {
    # No existing test pipes a path into Get-ChildItem2, although -Path documents taking it by value and by FullName.
    It 'Should accept piped folders by value, write one error for a path that does not exist, and list the items of the other folders' {
        $folderA = New-TestSandboxItem -Sandbox $sandbox -Name 'PipelineFolderA' -Directory
        $folderB = New-TestSandboxItem -Sandbox $sandbox -Name 'PipelineFolderB' -Directory
        $missing = Join-Path -Path $sandbox -ChildPath ('PipelineChildMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        $fileA = Join-Path -Path $folderA -ChildPath 'A.txt'
        $fileB = Join-Path -Path $folderB -ChildPath 'B.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $fileA, $fileB
        Set-Content -LiteralPath $fileA -Value 'A'
        Set-Content -LiteralPath $fileB -Value 'B'

        $result = @(@($folderA, $missing, $folderB) | Get-ChildItem2 -ErrorVariable childErrors -ErrorAction SilentlyContinue)

        $childErrors | Should -HaveCount 1
        $childErrors[0].FullyQualifiedErrorId | Should -BeLike 'FileNotFound,*'
        $childErrors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $childErrors[0].TargetObject | Should -Be $missing
        @($result.FullName | Sort-Object) | Should -Be (@($fileA, $fileB) | Sort-Object)
    }

    # Chains a folder object from one call into -Path of a second call, by value (AlphaFS objects, not strings).
    It 'Should accept folder objects piped from Get-ChildItem2 -Directory and list only the files directly below them' {
        $tree = New-TestSandboxItem -Sandbox $sandbox -Name 'ChainedTree' -Directory
        $childFolder = Join-Path -Path $tree -ChildPath 'Child'
        $childFile = Join-Path -Path $childFolder -ChildPath 'Child.log'
        $grandchildFile = Join-Path -Path $childFolder -ChildPath 'Grandchild\Deep.log'
        $rootFile = Join-Path -Path $tree -ChildPath 'Root.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $childFile, $grandchildFile, $rootFile
        New-Item -ItemType Directory -Path (Split-Path -Path $grandchildFile -Parent) -Force | Out-Null
        Set-Content -LiteralPath $childFile -Value 'Child'
        Set-Content -LiteralPath $grandchildFile -Value 'Grandchild'
        Set-Content -LiteralPath $rootFile -Value 'Root'

        $result = @(Get-ChildItem2 -Path $tree -Directory -ErrorAction Stop | Get-ChildItem2 -File -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $result[0].FullName | Should -Be $childFile
    }
}

Describe 'Get-Item2 accepts pipeline input' {
    # No existing test pipes a path into Get-Item2; the output type and Mode were asserted only for non-piped calls.
    It 'Should accept piped items by value, return each in order with its output type, and write one error for a path that does not exist' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'GetItemPipelineFile'
        [IO.File]::SetAttributes($file, [IO.FileAttributes]::Archive)
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'GetItemPipelineFolder' -Directory
        $missing = Join-Path -Path $sandbox -ChildPath ('GetItemPipelineMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))

        $result = @(@($file, $missing, $folder) | Get-Item2 -ErrorVariable itemErrors -ErrorAction SilentlyContinue)

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike 'FileNotFound,*'
        $itemErrors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $itemErrors[0].TargetObject | Should -Be $missing
        $result | Should -HaveCount 2
        $result[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $result[0].FullName | Should -Be $file
        $result[0].Mode | Should -BeExactly '-a---'
        $result[1] | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result[1].FullName | Should -Be $folder
        $result[1].Mode | Should -BeExactly 'd----'
    }
}

Describe 'Remove-Item2 accepts pipeline input' {
    # No existing test pipes a path into Remove-Item2, although its page documents Get-ChildItem2 | Remove-Item2.
    It 'Should accept piped items by value, write one error for a non-empty folder, remove the files, and keep the folder' {
        $fileA = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePipelineA'
        $fileB = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePipelineB'
        $nonEmptyFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePipelineFolder' -Directory
        $kept = Join-Path -Path $nonEmptyFolder -ChildPath 'Keep.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $kept
        Set-Content -LiteralPath $kept -Value 'Keep'

        $result = @(@($fileA, $nonEmptyFolder, $fileB) | Remove-Item2 -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)

        $removeErrors | Should -HaveCount 1
        $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'DeleteError,*'
        $removeErrors[0].CategoryInfo.Category | Should -Be 'InvalidData'
        $removeErrors[0].TargetObject | Should -Be $nonEmptyFolder
        $fileA | Should -Not -Exist
        $fileB | Should -Not -Exist
        $nonEmptyFolder | Should -Exist
        Get-Content -LiteralPath $kept | Should -Be 'Keep'
        $result | Should -HaveCount 2
        @($result.FullName | Sort-Object) | Should -Be (@($fileA, $fileB) | Sort-Object)
    }
}

Describe 'Empty or null -Path or -Target is rejected instead of falling back to the current location' {
    # GetRelativePath('') returns the current location, so ValidateNotNullOrEmpty is the only guard between an empty
    # value and a recursive delete of the current folder. A probe against the built module confirmed in both editions
    # that the attribute does reject an empty string, $null, a piped empty string, and an empty array element, so this
    # pins verified-safe behavior rather than an assumption.
    It 'Remove-Item2 should reject -Path <CaseName> instead of removing the current location' -ForEach @(
        @{ CaseName = 'as an empty string' }
        @{ CaseName = 'as $null' }
        @{ CaseName = 'as an array with an empty element' }
        @{ CaseName = 'piped as an empty string' }
    ) {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'EmptyPathGuard' -Directory
        $keep = Join-Path -Path $folder -ChildPath 'Keep.txt'
        $innerFolder = Join-Path -Path $folder -ChildPath 'Sub'
        $inner = Join-Path -Path $innerFolder -ChildPath 'Inner.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $keep, $innerFolder, $inner
        New-Item -ItemType Directory -Path $innerFolder | Out-Null
        Set-Content -LiteralPath $keep -Value 'Keep'
        Set-Content -LiteralPath $inner -Value 'Inner'

        Push-Location -LiteralPath $folder
        try {
            switch ($CaseName) {
                'as an empty string' {
                    { Remove-Item2 -Path '' -Recurse -Force -ErrorAction Stop } |
                        Should -Throw -ErrorId 'ParameterArgumentValidationError,NTFSSecurity.RemoveItem2'
                }
                'as $null' {
                    { Remove-Item2 -Path $null -Recurse -Force -ErrorAction Stop } |
                        Should -Throw -ErrorId 'ParameterArgumentValidationError,NTFSSecurity.RemoveItem2'
                }
                'as an array with an empty element' {
                    { Remove-Item2 -Path @('') -Recurse -Force -ErrorAction Stop } |
                        Should -Throw -ErrorId 'ParameterArgumentValidationError,NTFSSecurity.RemoveItem2'
                }
                'piped as an empty string' {
                    { '' | Remove-Item2 -Recurse -Force -ErrorAction Stop } |
                        Should -Throw -ErrorId 'ParameterArgumentValidationError,NTFSSecurity.RemoveItem2'
                }
            }
        }
        finally {
            Pop-Location
        }

        $keep | Should -Exist
        $inner | Should -Exist
    }

    It '<Command> should reject -Path <CaseName> instead of silently using the current location' -ForEach @(
        @{ Command = 'Copy-Item2'; TypeName = 'NTFSSecurity.CopyItem2'; CaseName = 'as an empty string' }
        @{ Command = 'Copy-Item2'; TypeName = 'NTFSSecurity.CopyItem2'; CaseName = 'as $null' }
        @{ Command = 'Copy-Item2'; TypeName = 'NTFSSecurity.CopyItem2'; CaseName = 'as an array with an empty element' }
        @{ Command = 'Move-Item2'; TypeName = 'NTFSSecurity.MoveItem2'; CaseName = 'as an empty string' }
        @{ Command = 'Move-Item2'; TypeName = 'NTFSSecurity.MoveItem2'; CaseName = 'as $null' }
        @{ Command = 'Move-Item2'; TypeName = 'NTFSSecurity.MoveItem2'; CaseName = 'as an array with an empty element' }
    ) {
        $destination = New-TestSandboxItem -Sandbox $sandbox -Name 'EmptyPathDestination' -Directory
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'EmptyPathSource'
        # An empty path resolves to the current location, so the rows run in a folder of their own: a guard that regressed
        # would copy or move this empty folder and not the whole sandbox into itself.
        $workFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'EmptyPathWork' -Directory

        # The comma keeps the array: a switch writes to the pipeline, which unrolls @('') into a plain empty string.
        $badPath = switch ($CaseName) {
            'as an empty string' { '' }
            'as $null' { $null }
            'as an array with an empty element' { , @('') }
        }

        Push-Location -LiteralPath $workFolder
        try {
            { & $Command -Path $badPath -Destination $destination -ErrorAction Stop } |
                Should -Throw -ErrorId "ParameterArgumentValidationError,$TypeName"
        }
        finally {
            Pop-Location
        }
        $source | Should -Exist
        $workFolder | Should -Exist
        @(Get-ChildItem -LiteralPath $destination -Force) | Should -BeNullOrEmpty
    }

    # "Both link creators" per the proposal; a probe confirmed the same safe, verified behavior for New-NTFSHardLink.
    It '<Command> should reject <CaseName> instead of creating a link to the current folder' -ForEach @(
        @{ Command = 'New-NTFSHardLink'; TypeName = 'NTFSSecurity.NewHardLink'; CaseName = 'an empty -Target' }
        @{ Command = 'New-NTFSHardLink'; TypeName = 'NTFSSecurity.NewHardLink'; CaseName = 'a $null -Target' }
        @{ Command = 'New-NTFSHardLink'; TypeName = 'NTFSSecurity.NewHardLink'; CaseName = 'an empty -Path' }
        @{ Command = 'New-NTFSSymbolicLink'; TypeName = 'NTFSSecurity.NewSymbolicLink'; CaseName = 'an empty -Target' }
        @{ Command = 'New-NTFSSymbolicLink'; TypeName = 'NTFSSecurity.NewSymbolicLink'; CaseName = 'a $null -Target' }
        @{ Command = 'New-NTFSSymbolicLink'; TypeName = 'NTFSSecurity.NewSymbolicLink'; CaseName = 'an empty -Path' }
    ) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'EmptyGuardTarget'
        $link = Join-Path -Path $sandbox -ChildPath ('EmptyGuardLink-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        switch ($CaseName) {
            'an empty -Target' {
                { & $Command -Path $link -Target '' -ErrorAction Stop } |
                    Should -Throw -ErrorId "ParameterArgumentValidationError,$TypeName"
                $link | Should -Not -Exist
            }
            'a $null -Target' {
                { & $Command -Path $link -Target $null -ErrorAction Stop } |
                    Should -Throw -ErrorId "ParameterArgumentValidationError,$TypeName"
                $link | Should -Not -Exist
            }
            'an empty -Path' {
                { & $Command -Path '' -Target $target -ErrorAction Stop } |
                    Should -Throw -ErrorId "ParameterArgumentValidationError,$TypeName"
                Get-Content -LiteralPath $target | Should -Be 'EmptyGuardTarget'
            }
        }
    }
}

Describe 'Get-NTFSHardLink errors, categories, output type, and positional binding' {
    It 'Should accept piped strings by value, write errors with their categories for a folder and a missing path, and return the files in order' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'HardLinkPipelineFile'
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'HardLinkPipelineFolder' -Directory
        $missing = Join-Path -Path $sandbox -ChildPath ('HardLinkPipelineMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
        $other = New-TestSandboxItem -Sandbox $sandbox -Name 'HardLinkPipelineOther'

        $result = @(@($file, $folder, $missing, $other) | Get-NTFSHardLink -ErrorVariable linkErrors -ErrorAction SilentlyContinue)

        $linkErrors | Should -HaveCount 2
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
        $linkErrors[0].CategoryInfo.Category | Should -Be 'InvalidArgument'
        $linkErrors[0].TargetObject | Should -Be $folder
        $linkErrors[1].FullyQualifiedErrorId | Should -BeLike 'FileNotFound,*'
        $linkErrors[1].CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $linkErrors[1].TargetObject | Should -Be $missing
        $result | Should -HaveCount 2
        $result[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $result[0].FullName | Should -Be $file
        $result[1] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $result[1].FullName | Should -Be $other
        (Get-NTFSHardLink $file -ErrorAction Stop).FullName | Should -Be $file
    }
}

Describe 'Pipeline continuation for the link-creating cmdlets' {
    # Mirrors the PipelineControl.Tests.ps1 Untouched convention locally: a later command that ends the pipeline after
    # the first pass-through object must leave the second link request completely untouched.
    It 'New-NTFSHardLink should stop after the first pass-through object for Select-Object -First 1 and leave the second request untouched' {
        $firstTarget = New-TestSandboxItem -Sandbox $sandbox -Name 'ContinuationHardFirstTarget'
        $secondTarget = New-TestSandboxItem -Sandbox $sandbox -Name 'ContinuationHardSecondTarget'
        $firstLink = Join-Path -Path $sandbox -ChildPath 'ContinuationHardFirstLink.txt'
        $secondLink = Join-Path -Path $sandbox -ChildPath 'ContinuationHardSecondLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $firstLink, $secondLink
        $requests = @(
            [pscustomobject]@{ Path = $firstLink; Target = $firstTarget }
            [pscustomobject]@{ Path = $secondLink; Target = $secondTarget }
        )

        $result = @($requests | New-NTFSHardLink -PassThru -ErrorVariable linkErrors -ErrorAction SilentlyContinue | Select-Object -First 1)

        $linkErrors | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        $firstLink | Should -Exist
        $secondLink | Should -Not -Exist
    }

    It 'New-NTFSSymbolicLink should stop after the first pass-through object for Select-Object -First 1 and leave the second request untouched' -Skip:(-not $canCreateSymbolicLinks) {
        $firstTarget = New-TestSandboxItem -Sandbox $sandbox -Name 'ContinuationSymbolicFirstTarget'
        $secondTarget = New-TestSandboxItem -Sandbox $sandbox -Name 'ContinuationSymbolicSecondTarget'
        $firstLink = Join-Path -Path $sandbox -ChildPath 'ContinuationSymbolicFirstLink.txt'
        $secondLink = Join-Path -Path $sandbox -ChildPath 'ContinuationSymbolicSecondLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $firstLink, $secondLink
        $requests = @(
            [pscustomobject]@{ Path = $firstLink; Target = $firstTarget }
            [pscustomobject]@{ Path = $secondLink; Target = $secondTarget }
        )

        $result = @($requests | New-NTFSSymbolicLink -PassThru -ErrorVariable linkErrors -ErrorAction SilentlyContinue | Select-Object -First 1)

        $linkErrors | Should -BeNullOrEmpty
        $result | Should -HaveCount 1
        (Test-Path2 -Path $firstLink) | Should -BeTrue
        (Test-Path2 -Path $secondLink) | Should -BeFalse
    }
}

Describe 'New-NTFSSymbolicLink creates a link after an earlier failure in the same pipeline' {
    # Every existing piped request fails (the suite runs without the privilege on most hosts), so a successful
    # creation that follows a failed one in the same call was unverified; this is the weakest dimension the matrix
    # found for this cmdlet (Continuation: Partly).
    It 'Should write one ResourceExists error for an existing -Path and still create the links for the requests that follow it' -Skip:(-not $canCreateSymbolicLinks) {
        $existingTarget = New-TestSandboxItem -Sandbox $sandbox -Name 'SuccessAfterFailureExistingTarget'
        $existingPath = New-TestSandboxItem -Sandbox $sandbox -Name 'SuccessAfterFailureExistingPath'
        Set-Content -LiteralPath $existingPath -Value 'ExistingPath'
        $fileTarget = New-TestSandboxItem -Sandbox $sandbox -Name 'SuccessAfterFailureFileTarget'
        Set-Content -LiteralPath $fileTarget -Value 'FileTargetData'
        $fileLink = Join-Path -Path $sandbox -ChildPath 'SuccessAfterFailureFileLink.txt'
        $folderTarget = New-TestSandboxItem -Sandbox $sandbox -Name 'SuccessAfterFailureFolderTarget' -Directory
        $folderLink = Join-Path -Path $sandbox -ChildPath 'SuccessAfterFailureFolderLink'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $fileLink, $folderLink
        $requests = @(
            [pscustomobject]@{ Path = $existingPath; Target = $existingTarget }
            [pscustomobject]@{ Path = $fileLink; Target = $fileTarget }
            [pscustomobject]@{ Path = $folderLink; Target = $folderTarget }
        )

        $result = @($requests | New-NTFSSymbolicLink -PassThru -ErrorVariable linkErrors -ErrorAction SilentlyContinue)

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'CreateSymbolicLinkError,*'
        $linkErrors[0].CategoryInfo.Category | Should -Be 'ResourceExists'
        $linkErrors[0].TargetObject | Should -Be $existingPath
        Get-Content -LiteralPath $existingPath | Should -Be 'ExistingPath'
        $result | Should -HaveCount 2
        $result[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $result[0].FullName | Should -Be $fileLink
        $result[1] | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result[1].FullName | Should -Be $folderLink
        (Get-Item -LiteralPath $fileLink -Force).LinkType | Should -Be 'SymbolicLink'
        Get-Content -LiteralPath $fileLink | Should -Be 'FileTargetData'
    }
}

Describe 'Enable-Privileges and Disable-Privileges error paths' {
    # 'Enable Privilege Error' and 'Disable Privilege Error' run silently in many existing cleanups but are never
    # asserted; both IDs contain spaces by design (BaseCmdlets.cs, OtherCmdlets.cs), which this pins as given.
    BeforeAll {
        $privateData = (Get-Module -Name NTFSSecurity).PrivateData
        $savedEnablePrivileges = $privateData['EnablePrivileges']

        # Runs in a child process: removing a privilege from a token is permanent for that process, so a token that
        # holds all four (elevated) ends up holding at most three, and a token that holds none (basic user) stays at
        # none either way. Either way, Enable-Privileges cannot enable all four and must report the error.
        $enablePrivilegesErrorScript = Join-Path -Path $sandbox -ChildPath 'Invoke-EnablePrivilegesWithoutSecurity.ps1'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $enablePrivilegesErrorScript
        Set-Content -LiteralPath $enablePrivilegesErrorScript -Value @'
param ($ModulePath)
Import-Module -Name $ModulePath -ErrorAction Stop
$process = [System.Diagnostics.Process]::GetCurrentProcess()
try {
    [ProcessPrivileges.ProcessExtensions]::RemovePrivilege($process, [ProcessPrivileges.Privilege]::Security) | Out-Null
}
catch {
}
Enable-Privileges -ErrorVariable enableErrors -ErrorAction SilentlyContinue
'COUNT:{0}' -f @($enableErrors).Count
if ($enableErrors) {
    'ID:{0}' -f $enableErrors[0].FullyQualifiedErrorId
    'CATEGORY:{0}' -f $enableErrors[0].CategoryInfo.Category
    'EXCEPTIONTYPE:{0}' -f $enableErrors[0].Exception.GetType().FullName
    'MESSAGE:{0}' -f $enableErrors[0].Exception.Message
}
'@
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $savedEnablePrivileges
    }

    AfterEach {
        # A failing test here must not leave a privilege enabled for the tests that follow.
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    It 'Enable-Privileges should write Enable Privilege Error with SecurityError and AdjustPriviledgeException when it cannot enable all four privileges' {
        $output = & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $enablePrivilegesErrorScript -ModulePath ([IO.Path]::GetFullPath($modulePath))

        ($output | Where-Object -FilterScript { $_ -like 'COUNT:*' }) | Should -Be 'COUNT:1'
        ($output | Where-Object -FilterScript { $_ -like 'ID:*' }) | Should -Be 'ID:Enable Privilege Error,NTFSSecurity.EnablePrivileges'
        ($output | Where-Object -FilterScript { $_ -like 'CATEGORY:*' }) | Should -Be 'CATEGORY:SecurityError'
        ($output | Where-Object -FilterScript { $_ -like 'EXCEPTIONTYPE:*' }) | Should -Be 'EXCEPTIONTYPE:Security2.AdjustPriviledgeException'
        ($output | Where-Object -FilterScript { $_ -like 'MESSAGE:*' }) | Should -BeLike 'MESSAGE:*Could not enable requested privileges*'
    }

    It 'Disable-Privileges should write Disable Privilege Error with SecurityError and AdjustPriviledgeException and no output when nothing is enabled' {
        # EnablePrivileges=$false stops BeginProcessing from auto-enabling the privileges first, which would otherwise
        # always satisfy the "something is enabled" check and hide this error path.
        $privateData['EnablePrivileges'] = $false
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

        $result = @(Disable-Privileges -PassThru -ErrorVariable disableErrors -ErrorAction SilentlyContinue)

        $disableErrors | Should -HaveCount 1
        $disableErrors[0].FullyQualifiedErrorId | Should -Be 'Disable Privilege Error,NTFSSecurity.DisablePrivileges'
        $disableErrors[0].CategoryInfo.Category | Should -Be 'SecurityError'
        $disableErrors[0].Exception | Should -BeOfType [Security2.AdjustPriviledgeException]
        $disableErrors[0].Exception.Message | Should -Be 'Privileges are not enabled'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-DiskSpace with several drive letters' {
    # Reuses the free-letter lookup of the existing tests at ItemCmdlets.Tests.ps1:802 and :1063.
    It 'Should return only the system drive and warn for a drive letter without a volume, regardless of order (<Order>)' -ForEach @(
        @{ Order = 'valid letter first' }
        @{ Order = 'invalid letter first' }
    ) {
        $used = @((Get-PSDrive -PSProvider FileSystem).Name) + @([System.IO.DriveInfo]::GetDrives() | ForEach-Object -Process { $_.Name.Substring(0, 1) })
        $letter = [char[]](68..90) | Where-Object -FilterScript { [string] $_ -notin $used } | Select-Object -First 1
        if (-not $letter) {
            Set-ItResult -Skipped -Because 'every drive letter is in use'
            return
        }
        $missingLetter = "${letter}:"
        $driveLetters = if ($Order -eq 'valid letter first') { @($env:SystemDrive, $missingLetter) } else { @($missingLetter, $env:SystemDrive) }

        $result = @(Get-DiskSpace -DriveLetter $driveLetters -WarningVariable spaceWarnings -WarningAction SilentlyContinue -ErrorVariable spaceErrors -ErrorAction SilentlyContinue)

        $spaceErrors | Should -BeNullOrEmpty
        $spaceWarnings.Message | Should -Be "Could not get drive details for '$missingLetter'"
        $result | Should -HaveCount 1
        $result[0].DriveName | Should -Be ('{0}\' -f $env:SystemDrive)
    }

    It 'Should accept a lower-case drive letter positionally and report the same total size as .NET' {
        $systemDrive = New-Object -TypeName 'System.IO.DriveInfo' -ArgumentList $env:SystemDrive

        $result = @(Get-DiskSpace $env:SystemDrive.ToLowerInvariant() -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].TotalNumberOfBytes | Should -Be $systemDrive.TotalSize
    }
}

Describe 'Get-Privileges compared with an independent source' {
    # whoami and the library name some privileges differently; these five are named consistently via 'Se<Name>Privilege'.
    It 'Should match whoami /priv for the privileges that whoami and the library name the same way' {
        $whoamiPrivileges = & whoami.exe /priv /fo csv | Select-Object -Skip 1 | ConvertFrom-Csv -Header 'Name', 'Description', 'State'
        $libraryPrivileges = @(Get-Privileges -ErrorAction Stop)

        foreach ($name in 'ChangeNotify', 'TakeOwnership', 'Restore', 'Backup', 'Security') {
            $whoamiName = 'Se{0}Privilege' -f $name
            $whoamiEntry = @($whoamiPrivileges | Where-Object -Property Name -EQ -Value $whoamiName)
            $libraryEntry = @($libraryPrivileges | Where-Object -Property Privilege -EQ -Value $name)

            if ($whoamiEntry.Count -gt 0) {
                $libraryEntry | Should -HaveCount 1 -Because "Get-Privileges should list $name when whoami lists $whoamiName"
                $libraryEntry[0] | Should -BeOfType [ProcessPrivileges.PrivilegeAndAttributes]
                # The State column is localized (a German Windows prints Aktiviert), so the states are compared only where
                # whoami prints the English words; the privilege names above are not localized.
                if ($whoamiEntry[0].State -in 'Enabled', 'Disabled') {
                    $libraryEntry[0].PrivilegeState.ToString() | Should -Be $whoamiEntry[0].State
                    $isEnabledByAttributes = ($libraryEntry[0].PrivilegeAttributes -band [ProcessPrivileges.PrivilegeAttributes]::Enabled) -eq [ProcessPrivileges.PrivilegeAttributes]::Enabled
                    $isEnabledByAttributes | Should -Be ($whoamiEntry[0].State -eq 'Enabled')
                }
            }
            else {
                $libraryEntry | Should -BeNullOrEmpty -Because "Get-Privileges should not list $name when whoami does not list $whoamiName"
            }
        }
    }
}

Describe 'Get-FileHash2 with pipeline input and ordered failures' {
    It 'Should accept Get-ChildItem2 objects piped by value, skip a folder, and match Get-FileHash for each file' {
        $dir = New-TestSandboxItem -Sandbox $sandbox -Name 'HashPipelineDir' -Directory
        $fileA = Join-Path -Path $dir -ChildPath 'A.txt'
        $fileB = Join-Path -Path $dir -ChildPath 'B.txt'
        $subFolder = Join-Path -Path $dir -ChildPath 'Sub'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $fileA, $fileB, $subFolder
        Set-Content -LiteralPath $fileA -Value 'HashA'
        Set-Content -LiteralPath $fileB -Value 'HashB'
        New-Item -ItemType Directory -Path $subFolder | Out-Null

        $result = @(Get-ChildItem2 -Path $dir -ErrorVariable childErrors -ErrorAction SilentlyContinue | Get-FileHash2 -ErrorVariable hashErrors -ErrorAction SilentlyContinue)

        $childErrors | Should -BeNullOrEmpty
        $hashErrors | Should -BeNullOrEmpty
        $result | Should -HaveCount 2
        @($result.Name | Sort-Object) | Should -Be @('A.txt', 'B.txt')
        foreach ($item in $result) {
            $sourcePath = Join-Path -Path $dir -ChildPath $item.Name
            $item.Hash | Should -BeExactly (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
            $item.Algorithm | Should -Be 'SHA256'
            $item.PSObject.TypeNames[0] | Should -Be 'Alphaleonis.Win32.Filesystem.FileInfo+Hash'
        }

        # The algorithm comes from a variable, like the data of FileHash.Tests.ps1: the test compares with Get-FileHash and uses no hash for security.
        $legacyAlgorithm = 'MD5'
        $md5Result = @(Get-ChildItem -LiteralPath $dir -File | Get-FileHash2 -Algorithm $legacyAlgorithm -ErrorAction Stop)

        $md5Result | Should -HaveCount 2
        foreach ($item in $md5Result) {
            $sourcePath = Join-Path -Path $dir -ChildPath $item.Name
            $item.Hash | Should -BeExactly (Get-FileHash -LiteralPath $sourcePath -Algorithm $legacyAlgorithm).Hash
        }
    }

    It 'Should write GetHashError with its category for a locked file first, hash the file that follows it, and resolve a relative path' {
        $locked = New-TestSandboxItem -Sandbox $sandbox -Name 'HashLocked'
        $first = New-TestSandboxItem -Sandbox $sandbox -Name 'HashFirstFollowing'
        Set-Content -LiteralPath $first -Value 'FollowingContent'
        $stream = [IO.File]::Open($locked, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        try {
            $result = @(Get-FileHash2 -Path $locked, $first -ErrorVariable hashErrors -ErrorAction SilentlyContinue)
        }
        finally {
            $stream.Dispose()
        }

        $hashErrors | Should -HaveCount 1
        $hashErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHashError,*'
        $hashErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
        $hashErrors[0].TargetObject | Should -Be $locked
        $result | Should -HaveCount 1
        $result[0].Name | Should -BeExactly (Split-Path -Path $first -Leaf)
        $result[0].Hash | Should -BeExactly (Get-FileHash -LiteralPath $first -Algorithm SHA256).Hash

        Push-Location -LiteralPath (Split-Path -Path $first -Parent)
        try {
            $relativeResult = Get-FileHash2 -Path (Split-Path -Path $first -Leaf) -ErrorAction Stop
        }
        finally {
            Pop-Location
        }

        $relativeResult.Hash | Should -BeExactly $result[0].Hash
    }
}

Describe 'Bracket and wildcard characters in a path are treated literally' {
    # A bracket is an ordinary character in a path, as the existing -Filter test already pins for Get-ChildItem2
    # (ItemCmdlets.Tests.ps1:202); this closes the same gap for the path parameter of the other item cmdlets.
    It '<Command> should treat a path with brackets in the name as a literal file name' -ForEach @(
        @{ Command = 'Copy-Item2' }
        @{ Command = 'Move-Item2' }
        @{ Command = 'Get-Item2' }
        @{ Command = 'Remove-Item2' }
    ) {
        $sourceFolder = New-TestSandboxItem -Sandbox $sandbox -Name ('Bracket{0}Source' -f $Command.Replace('-', '')) -Directory
        $bracketFile = Join-Path -Path $sourceFolder -ChildPath 'Report[1].txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $bracketFile
        Set-Content -LiteralPath $bracketFile -Value 'Bracket'

        switch ($Command) {
            'Copy-Item2' {
                $destination = Join-Path -Path $sourceFolder -ChildPath 'Copied'
                New-Item -ItemType Directory -Path $destination | Out-Null

                $result = Copy-Item2 -Path $bracketFile -Destination $destination -PassThru $true -ErrorAction Stop

                $result.Name | Should -Be 'Report[1].txt'
                Get-Content -LiteralPath (Join-Path -Path $destination -ChildPath 'Report[1].txt') | Should -Be 'Bracket'
                # Should -Exist uses a non-literal Test-Path, which reads the brackets as a character class and
                # would misreport a file that is actually there; [IO.File]::Exists is a literal, independent oracle.
                [IO.File]::Exists($bracketFile) | Should -BeTrue
            }
            'Move-Item2' {
                $destination = Join-Path -Path $sourceFolder -ChildPath 'Moved'
                New-Item -ItemType Directory -Path $destination | Out-Null

                $result = Move-Item2 -Path $bracketFile -Destination $destination -PassThru $true -ErrorAction Stop

                $result.Name | Should -Be 'Report[1].txt'
                [IO.File]::Exists($bracketFile) | Should -BeFalse
                Get-Content -LiteralPath (Join-Path -Path $destination -ChildPath 'Report[1].txt') | Should -Be 'Bracket'
            }
            'Get-Item2' {
                $result = Get-Item2 -Path $bracketFile -ErrorAction Stop

                $result.Name | Should -Be 'Report[1].txt'
                $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
            }
            'Remove-Item2' {
                $result = Remove-Item2 -Path $bracketFile -PassThru -ErrorAction Stop

                $result.Name | Should -Be 'Report[1].txt'
                [IO.File]::Exists($bracketFile) | Should -BeFalse
            }
        }
    }

    # '*' and '?' are not in [IO.Path]::GetInvalidPathChars() in either edition (only '|' and the control characters
    # are, and Windows PowerShell additionally rejects '"', '<', '>'), so a literal asterisk or question mark reaches
    # the file system as an ordinary character instead of raising ArgumentException: AlphaFS, like System.IO, looks
    # for the exact literal name and reports it missing rather than expanding the character as a search pattern.
    It '<Command> should not expand an asterisk in a path as a wildcard and should report FileNotFound' -ForEach @(
        @{ Command = 'Move-Item2'; ErrorId = 'FileNotFound' }
        @{ Command = 'Remove-Item2'; ErrorId = 'FileNotFound' }
    ) {
        $sourceFolder = New-TestSandboxItem -Sandbox $sandbox -Name ('Wildcard{0}Source' -f $Command.Replace('-', '')) -Directory
        $fileA = Join-Path -Path $sourceFolder -ChildPath 'FileA.txt'
        $fileB = Join-Path -Path $sourceFolder -ChildPath 'FileB.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $fileA, $fileB
        Set-Content -LiteralPath $fileA -Value 'A'
        Set-Content -LiteralPath $fileB -Value 'B'
        $wildcardPath = Join-Path -Path $sourceFolder -ChildPath 'File*.txt'

        switch ($Command) {
            'Move-Item2' {
                $destination = Join-Path -Path $sourceFolder -ChildPath 'Destination'
                New-Item -ItemType Directory -Path $destination | Out-Null

                Move-Item2 -Path $wildcardPath -Destination $destination -ErrorVariable itemErrors -ErrorAction SilentlyContinue
            }
            'Remove-Item2' {
                Remove-Item2 -Path $wildcardPath -ErrorVariable itemErrors -ErrorAction SilentlyContinue
            }
        }

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike "$ErrorId,*"
        $itemErrors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $itemErrors[0].TargetObject | Should -Be $wildcardPath
        $fileA | Should -Exist
        $fileB | Should -Exist
        Get-Content -LiteralPath $fileA | Should -Be 'A'
        Get-Content -LiteralPath $fileB | Should -Be 'B'
    }
}

Describe 'Items whose path is longer than 260 characters' {
    BeforeAll {
        Add-Type -Path (Join-Path -Path (Get-Module -Name NTFSSecurity).ModuleBase -ChildPath 'AlphaFS.dll')

        # Builds a fresh folder tree and file below it whose full path is longer than 260 characters, in its own
        # branch of the sandbox, and returns the file's full path. Mirrors ItemCmdlets.Tests.ps1:1029: only the short
        # root goes through Assert-TestSandboxPath, because [IO.Path] (which it calls) throws PathTooLongException
        # for the long path itself in Windows PowerShell; AlphaFS does not have that limit. A script block, not a
        # function: PowerShell does not parse an attribute on a function statement nested inside another block, so
        # PSUseShouldProcessForStateChangingFunctions (its name starts with New) could not be suppressed that way.
        $newTestLongPathFile = {
            param ([Parameter(Mandatory)] [string] $Name)

            $root = New-TestSandboxItem -Sandbox $sandbox -Name $Name -Directory
            $deep = Join-Path -Path $root -ChildPath ((('A' * 100), ('B' * 100), ('C' * 100)) -join '\')
            [Alphaleonis.Win32.Filesystem.Directory]::CreateDirectory($deep) | Out-Null
            $file = Join-Path -Path $deep -ChildPath 'Long.txt'
            [Alphaleonis.Win32.Filesystem.File]::WriteAllText($file, 'LongPathContent')
            if ($file.Length -le 260) {
                throw "The test path '$file' is not longer than 260 characters."
            }
            $file
        }
    }

    It 'Get-Item2 should return the file and its folder' {
        $file = & $newTestLongPathFile -Name 'GetItemLong'

        $fileResult = Get-Item2 -Path $file -ErrorAction Stop
        $folderResult = Get-Item2 -Path (Split-Path -Path $file -Parent) -ErrorAction Stop

        $fileResult | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $fileResult.FullName | Should -Be $file
        $folderResult | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
    }

    It 'Get-ChildItem2 should list the content of the folder' {
        $file = & $newTestLongPathFile -Name 'ChildItemLong'

        $result = @(Get-ChildItem2 -Path (Split-Path -Path $file -Parent) -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $file
    }

    It 'Get-FileHash2 should hash the file and match an independent SHA256 read through AlphaFS' {
        $file = & $newTestLongPathFile -Name 'HashLong'
        $bytes = [Alphaleonis.Win32.Filesystem.File]::ReadAllBytes($file)
        $expectedHash = -join (([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)) | ForEach-Object -Process { $_.ToString('X2') })

        $result = Get-FileHash2 -Path $file -ErrorAction Stop

        $result.Hash | Should -BeExactly $expectedHash
    }

    It 'Copy-Item2 should copy the file to a short destination and leave the source in place' {
        $file = & $newTestLongPathFile -Name 'CopyLong'
        $destination = New-TestSandboxItem -Sandbox $sandbox -Name 'CopyLongDestination' -Directory

        $result = Copy-Item2 -Path $file -Destination $destination -PassThru $true -ErrorAction Stop

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $copied = Join-Path -Path $destination -ChildPath 'Long.txt'
        Get-Content -LiteralPath $copied | Should -Be 'LongPathContent'
        [Alphaleonis.Win32.Filesystem.File]::Exists($file) | Should -BeTrue
    }

    It 'Move-Item2 should move the file to a short destination and remove the source' {
        $file = & $newTestLongPathFile -Name 'MoveLong'
        $destination = New-TestSandboxItem -Sandbox $sandbox -Name 'MoveLongDestination' -Directory

        $result = Move-Item2 -Path $file -Destination $destination -PassThru $true -ErrorAction Stop

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        [Alphaleonis.Win32.Filesystem.File]::Exists($file) | Should -BeFalse
        $moved = Join-Path -Path $destination -ChildPath 'Long.txt'
        Get-Content -LiteralPath $moved | Should -Be 'LongPathContent'
    }
}

Describe 'Item cmdlets at the root of a mapped drive' -Skip:(-not $canMapDrive) {
    # NEVER the real root of a volume: a drive letter that subst maps to a sandbox folder is the root of a drive for
    # Windows and for the module (see Tests\DriveRoot.Tests.ps1), without touching a real volume.
    BeforeAll {
        $driveSandbox = New-TestSandbox -Name 'ItemsDriveRoot'
        $mapped = New-TestSandboxItem -Sandbox $driveSandbox -Name 'Mapped' -Directory
        $driveRoot = New-TestDriveMapping -Sandbox $driveSandbox -Path $mapped
        if (-not $driveRoot) {
            throw 'No drive letter could be mapped to the sandbox folder.'
        }
        $existingFile = Join-Path -Path $mapped -ChildPath 'Existing.txt'
        Assert-TestSandboxPath -Sandbox $driveSandbox -Path $existingFile
        Set-Content -LiteralPath $existingFile -Value 'Existing'
    }

    AfterAll {
        if ($driveRoot) {
            Remove-TestDriveMapping -Root $driveRoot
        }
        Remove-TestSandbox -Sandbox $driveSandbox
    }

    It 'Get-Item2 should return a DirectoryInfo object for the root of the mapped drive' {
        $result = Get-Item2 -Path $driveRoot -ErrorAction Stop

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result.FullName.TrimEnd('\') | Should -Be $driveRoot.TrimEnd('\')
    }

    It 'Get-ChildItem2 should list the content at the root of the mapped drive' {
        $result = @(Get-ChildItem2 -Path $driveRoot -ErrorAction Stop)

        $result.Name | Should -Contain 'Existing.txt'
    }

    It 'Test-Path2 should find the root of the mapped drive as a container' {
        Test-Path2 -Path $driveRoot -PathType Container -ErrorAction Stop | Should -BeTrue
    }

    It 'Copy-Item2 should copy a file to the root of the mapped drive' {
        $source = New-TestSandboxItem -Sandbox $driveSandbox -Name 'CopyToDriveRootSource'
        Set-Content -LiteralPath $source -Value 'CopyToRoot'

        $result = Copy-Item2 -Path $source -Destination $driveRoot -PassThru $true -ErrorAction Stop

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $copied = Join-Path -Path $mapped -ChildPath (Split-Path -Path $source -Leaf)
        Get-Content -LiteralPath $copied | Should -Be 'CopyToRoot'
        $source | Should -Exist
    }

    It 'Move-Item2 should move a file to the root of the mapped drive' {
        $source = New-TestSandboxItem -Sandbox $driveSandbox -Name 'MoveToDriveRootSource'
        Set-Content -LiteralPath $source -Value 'MoveToRoot'

        $result = Move-Item2 -Path $source -Destination $driveRoot -PassThru $true -ErrorAction Stop

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $source | Should -Not -Exist
        $moved = Join-Path -Path $mapped -ChildPath (Split-Path -Path $source -Leaf)
        Get-Content -LiteralPath $moved | Should -Be 'MoveToRoot'
    }
}

Describe 'Omitted -Path falls back to the current location' {
    BeforeAll {
        $currentLocationFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'OmittedPathLocation' -Directory
        $currentLocationFile = Join-Path -Path $currentLocationFolder -ChildPath 'Child.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $currentLocationFile
        Set-Content -LiteralPath $currentLocationFile -Value 'Child'
    }

    It 'Get-Item2 should return the folder of the current location' {
        Push-Location -LiteralPath $currentLocationFolder
        try {
            $result = Get-Item2 -ErrorAction Stop
        }
        finally {
            Pop-Location
        }

        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result.FullName.TrimEnd('\') | Should -Be $currentLocationFolder.TrimEnd('\')
    }

    It 'Get-ChildItem2 should list the content of the current location' {
        Push-Location -LiteralPath $currentLocationFolder
        try {
            $result = @(Get-ChildItem2 -ErrorAction Stop)
        }
        finally {
            Pop-Location
        }

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $currentLocationFile
    }
}

Describe 'Get-ChildItem2 parameter interactions' {
    BeforeAll {
        $interactionFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'ParamInteractions' -Directory
        $interactionSubFolder = Join-Path -Path $interactionFolder -ChildPath 'Sub'
        $interactionTopFile = Join-Path -Path $interactionFolder -ChildPath 'Top.txt'
        $interactionNestedFile = Join-Path -Path $interactionSubFolder -ChildPath 'Nested.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $interactionSubFolder, $interactionTopFile, $interactionNestedFile
        New-Item -ItemType Directory -Path $interactionSubFolder | Out-Null
        Set-Content -LiteralPath $interactionTopFile -Value 'Top'
        Set-Content -LiteralPath $interactionNestedFile -Value 'Nested'

        $attributeFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'AttributesIgnored' -Directory
        $hiddenSystemFile = Join-Path -Path $attributeFolder -ChildPath 'HiddenSystem.txt'
        $systemFile = Join-Path -Path $attributeFolder -ChildPath 'System.txt'
        $hiddenFile = Join-Path -Path $attributeFolder -ChildPath 'Hidden.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $hiddenSystemFile, $systemFile, $hiddenFile
        Set-Content -LiteralPath $hiddenSystemFile -Value 'HS'
        Set-Content -LiteralPath $systemFile -Value 'S'
        Set-Content -LiteralPath $hiddenFile -Value 'H'
        [IO.File]::SetAttributes($hiddenSystemFile, [IO.FileAttributes] 'Hidden, System')
        [IO.File]::SetAttributes($systemFile, [IO.FileAttributes] 'System')
        [IO.File]::SetAttributes($hiddenFile, [IO.FileAttributes] 'Hidden')
    }

    It 'Should resolve a relative -Path against the current location' {
        Push-Location -LiteralPath $interactionFolder
        try {
            $result = @(Get-ChildItem2 -Path (Split-Path -Path $interactionSubFolder -Leaf) -ErrorAction Stop)
        }
        finally {
            Pop-Location
        }

        $result | Should -HaveCount 1
        $result[0].FullName | Should -Be $interactionNestedFile
    }

    It 'Should return only the folder when -Directory and -File are given together' {
        $result = @(Get-ChildItem2 -Path $interactionFolder -Directory -File -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result[0].FullName | Should -Be $interactionSubFolder
    }

    # The cmdlet page documents that -Attributes makes the cmdlet ignore -Force, -Hidden, -System, and -ReadOnly, and
    # that it returns a matching hidden item without -Force; each row returns the same names as -Attributes alone,
    # which these switches would narrow or widen if they were not ignored.
    It 'Should return the same matches for -Attributes <AttributesValue> regardless of -Force, -Hidden, -System, and -ReadOnly (<Case>)' -ForEach @(
        @{ Case = 'alone'; AttributesValue = 'System'; Switches = @{} }
        @{ Case = 'with every other switch set'; AttributesValue = 'System'; Switches = @{ Force = $true; Hidden = $true; System = $true; ReadOnly = $true } }
        @{ Case = 'alone, matching a hidden item without -Force'; AttributesValue = 'Hidden'; Switches = @{} }
        @{ Case = 'with -ReadOnly set'; AttributesValue = 'Hidden'; Switches = @{ ReadOnly = $true } }
    ) {
        $expected = if ($AttributesValue -eq 'System') { @('HiddenSystem.txt', 'System.txt') } else { @('Hidden.txt', 'HiddenSystem.txt') }

        $result = @(Get-ChildItem2 -Path $attributeFolder -Attributes $AttributesValue @Switches -ErrorAction Stop)

        @($result.Name | Sort-Object) | Should -Be $expected
    }

    It 'Should have no effect without -Recurse' {
        $withDepth = @(Get-ChildItem2 -Path $interactionFolder -Depth 0 -ErrorAction Stop)
        $withoutDepth = @(Get-ChildItem2 -Path $interactionFolder -ErrorAction Stop)

        @($withDepth.Name | Sort-Object) | Should -Be @('Sub', 'Top.txt')
        @($withDepth.Name | Sort-Object) | Should -Be @($withoutDepth.Name | Sort-Object)
    }

    It 'Should list the same items through the dir2 alias' {
        $result = @(dir2 -Path $interactionFolder -ErrorAction Stop)

        @($result.Name | Sort-Object) | Should -Be @('Sub', 'Top.txt')
    }

    It 'Should write AttributesEmpty with its category and target for an empty -Attributes value' {
        $caught = $null

        try {
            Get-ChildItem2 -Path $interactionFolder -Attributes 0 -ErrorAction Stop
        }
        catch {
            $caught = $_
        }

        $caught.FullyQualifiedErrorId | Should -Be 'AttributesEmpty,NTFSSecurity.GetChildItem2'
        $caught.CategoryInfo.Category | Should -Be 'InvalidArgument'
        $caught.TargetObject | Should -Be ([IO.FileAttributes] 0)
    }
}

Describe 'Copy-Item2 destination conflicts and output' {
    It 'Should replace an existing file directly with -Force, with PassThru=<_>' -ForEach @($false, $true) {
        $sourceFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'CopyForceSource' -Directory
        $destinationFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'CopyForceDestination' -Directory
        $source = Join-Path -Path $sourceFolder -ChildPath 'Replace.txt'
        $target = Join-Path -Path $destinationFolder -ChildPath 'Replace.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $source, $target
        Set-Content -LiteralPath $source -Value 'NewContent'
        Set-Content -LiteralPath $target -Value 'OldContent'

        $result = @(Copy-Item2 -Path $source -Destination $destinationFolder -Force -PassThru $_ -ErrorAction Stop)

        Get-Content -LiteralPath $target | Should -Be 'NewContent'
        $source | Should -Exist
        if ($_) {
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $target
        }
        else {
            $result | Should -BeNullOrEmpty
        }
    }

    # The folder case of the same conflict (ItemCmdlets.Tests.ps1:633) already asserts ID, category, and target; this
    # file case was asserted by error count only.
    It 'Should write DestinationFileAlreadyExists with its category and target for a file that exists at the destination' {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'FileConflictSource'
        $destinationFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'FileConflictDestination' -Directory
        $existing = Join-Path -Path $destinationFolder -ChildPath (Split-Path -Path $source -Leaf)
        Assert-TestSandboxPath -Sandbox $sandbox -Path $existing
        Set-Content -LiteralPath $existing -Value 'Existing'

        Copy-Item2 -Path $source -Destination $destinationFolder -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -HaveCount 1
        $itemErrors[0].FullyQualifiedErrorId | Should -BeLike 'DestinationFileAlreadyExists,*'
        $itemErrors[0].CategoryInfo.Category | Should -Be 'ResourceExists'
        $itemErrors[0].TargetObject | Should -Be $existing
        Get-Content -LiteralPath $existing | Should -Be 'Existing'
    }

    It '-PassThru should return the output type for a file and for a folder, and write nothing without -PassThru' {
        $sourceFile = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThruTypeFile'
        $sourceFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThruTypeFolder' -Directory
        $destination = New-TestSandboxItem -Sandbox $sandbox -Name 'PassThruTypeDestination' -Directory

        $fileResult = @(Copy-Item2 -Path $sourceFile -Destination $destination -PassThru $true -ErrorAction Stop)
        $folderResult = @(Copy-Item2 -Path $sourceFolder -Destination (Join-Path -Path $destination -ChildPath 'CopiedFolder') -PassThru $true -ErrorAction Stop)
        $quietResult = @(Copy-Item2 -Path $sourceFile -Destination (Join-Path -Path $destination -ChildPath 'Quiet') -ErrorAction Stop)

        $fileResult | Should -HaveCount 1
        $fileResult[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.FileInfo]
        $folderResult | Should -HaveCount 1
        $folderResult[0] | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $quietResult | Should -BeNullOrEmpty
    }
}

Describe 'Move-Item2 folder trees, in-place renames, and -Force' {
    It 'Should move a non-empty folder tree to a new destination' {
        $sourceFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'MoveTreeSource' -Directory
        $nestedFolder = Join-Path -Path $sourceFolder -ChildPath 'Nested'
        $topFile = Join-Path -Path $sourceFolder -ChildPath 'Top.txt'
        $nestedFile = Join-Path -Path $nestedFolder -ChildPath 'Inner.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $nestedFolder, $topFile, $nestedFile
        New-Item -ItemType Directory -Path $nestedFolder | Out-Null
        Set-Content -LiteralPath $topFile -Value 'Top'
        Set-Content -LiteralPath $nestedFile -Value 'Inner'
        $destinationParent = New-TestSandboxItem -Sandbox $sandbox -Name 'MoveTreeDestinationParent' -Directory

        $result = Move-Item2 -Path $sourceFolder -Destination $destinationParent -PassThru $true -ErrorAction Stop

        $movedFolder = Join-Path -Path $destinationParent -ChildPath (Split-Path -Path $sourceFolder -Leaf)
        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $sourceFolder | Should -Not -Exist
        Get-Content -LiteralPath (Join-Path -Path $movedFolder -ChildPath 'Top.txt') | Should -Be 'Top'
        Get-Content -LiteralPath (Join-Path -Path $movedFolder -ChildPath 'Nested\Inner.txt') | Should -Be 'Inner'
    }

    It 'Should rename an item in place on the same volume' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RenameSource'
        Set-Content -LiteralPath $file -Value 'RenameContent'
        $renamed = Join-Path -Path (Split-Path -Path $file -Parent) -ChildPath 'RenameTarget.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $renamed

        $result = Move-Item2 -Path $file -Destination $renamed -PassThru $true -ErrorAction Stop

        $file | Should -Not -Exist
        $renamed | Should -Exist
        Get-Content -LiteralPath $renamed | Should -Be 'RenameContent'
        $result.FullName | Should -Be $renamed
    }

    # Unlike Copy-Item2 -Force, which merges into an existing folder of the same name (ItemCmdlets.Tests.ps1:681),
    # the cmdlet page documents that Move-Item2 -Force "overwrites an existing destination item" and runs with the
    # ReplaceExisting option (Move-Item2.md, -Force and the Notes section); a non-empty folder at the destination
    # confirms that this means a full replace, not a merge, which a probe showed first (the existing folder and the
    # file it held were gone afterwards, and the moved folder took its place with no error).
    It 'Should replace an existing folder outright with -Force, not merge it, and write no error' {
        $sourceFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'MoveForceFolderSource' -Directory
        $destinationParent = New-TestSandboxItem -Sandbox $sandbox -Name 'MoveForceFolderDestinationParent' -Directory
        $existingFolder = Join-Path -Path $destinationParent -ChildPath (Split-Path -Path $sourceFolder -Leaf)
        Assert-TestSandboxPath -Sandbox $sandbox -Path $existingFolder
        New-Item -ItemType Directory -Path $existingFolder | Out-Null
        $sourceContent = Join-Path -Path $sourceFolder -ChildPath 'FromSource.txt'
        $existingContent = Join-Path -Path $existingFolder -ChildPath 'AlreadyThere.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $sourceContent, $existingContent
        Set-Content -LiteralPath $sourceContent -Value 'FromSource'
        Set-Content -LiteralPath $existingContent -Value 'AlreadyThere'

        $result = Move-Item2 -Path $sourceFolder -Destination $destinationParent -Force -PassThru $true -ErrorVariable itemErrors -ErrorAction SilentlyContinue

        $itemErrors | Should -BeNullOrEmpty
        $result | Should -BeOfType [Alphaleonis.Win32.Filesystem.DirectoryInfo]
        $result.FullName | Should -Be $existingFolder
        [IO.Directory]::Exists($sourceFolder) | Should -BeFalse
        Get-Content -LiteralPath (Join-Path -Path $existingFolder -ChildPath 'FromSource.txt') | Should -Be 'FromSource'
        [IO.File]::Exists($existingContent) | Should -BeFalse
    }
}


Describe 'Remove-Item2 defaults, aliases, and error details' {
    It 'Should do nothing when -Path is omitted' {
        $omittedPathFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveOmittedPath' -Directory
        $kept = Join-Path -Path $omittedPathFolder -ChildPath 'Kept.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $kept
        Set-Content -LiteralPath $kept -Value 'Kept'

        Push-Location -LiteralPath $omittedPathFolder
        try {
            $result = @(Remove-Item2 -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)
        }
        finally {
            Pop-Location
        }

        $removeErrors | Should -BeNullOrEmpty
        $result | Should -BeNullOrEmpty
        $kept | Should -Exist
        $omittedPathFolder | Should -Exist
    }

    It 'Should remove the file through the <Alias> alias' -ForEach @(
        @{ Alias = 'rm2' }
        @{ Alias = 'del2' }
    ) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name "RemoveAlias$Alias"

        & $Alias -Path $file -ErrorAction Stop

        $file | Should -Not -Exist
    }

    It 'Should write FileNotFound with its category and target for a path that does not exist' {
        $missing = Join-Path -Path $sandbox -ChildPath ('RemoveMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))

        Remove-Item2 -Path $missing -ErrorVariable removeErrors -ErrorAction SilentlyContinue

        $removeErrors | Should -HaveCount 1
        $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'FileNotFound,*'
        $removeErrors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $removeErrors[0].TargetObject | Should -Be $missing
    }

    It 'Should write nothing for a successful removal without -PassThru' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveQuiet'

        $result = @(Remove-Item2 -Path $file -ErrorAction Stop)

        $result | Should -BeNullOrEmpty
        $file | Should -Not -Exist
    }

    # The generic catch of RemoveItem2.cs (category NotSpecified) is reached by anything that is not an IOException;
    # a Deny ACE for Delete makes the file system refuse with an UnauthorizedAccessException, a sibling of
    # IOException, not a subclass of it, so it falls through to that generic branch instead of the InvalidData one
    # that the locked-file and non-empty-folder cases already cover (Remove-Item2.Tests.ps1:36,97). NTFS allows a
    # delete when either the file itself allows it or its parent grants DeleteSubdirectoriesAndFiles, so a dedicated
    # folder denies the second route as well; otherwise the inherited folder permission of the sandbox still lets the
    # delete through despite the Deny entry on the file alone (seen first-hand: no error was written).
    It 'Should write DeleteError with category NotSpecified when a Deny ACE refuses the delete' {
        $deniedFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveAccessDeniedFolder' -Directory
        $file = Join-Path -Path $deniedFolder -ChildPath 'Denied.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $file
        Set-Content -LiteralPath $file -Value 'Denied'
        Add-TestDenyRule -Sandbox $sandbox -Path $deniedFolder -Rights @{ 'S-1-1-0' = 'DeleteSubdirectoriesAndFiles' }
        Add-TestDenyRule -Sandbox $sandbox -Path $file -Rights @{ 'S-1-1-0' = 'Delete' }

        Remove-Item2 -Path $file -ErrorVariable removeErrors -ErrorAction SilentlyContinue

        $removeErrors | Should -HaveCount 1
        $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'DeleteError,*'
        $removeErrors[0].CategoryInfo.Category | Should -Be 'NotSpecified'
        $removeErrors[0].TargetObject | Should -Be $file
        $removeErrors[0].Exception | Should -BeOfType [System.UnauthorizedAccessException]
        $file | Should -Exist
    }
}

Describe 'Test-Path2 with several path shapes' {
    It 'Should accept several piped objects and bind -PathType by property name for each' {
        $pipedFile = New-TestSandboxItem -Sandbox $sandbox -Name 'PipedPathTypeFile'
        $pipedFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'PipedPathTypeFolder' -Directory
        $requests = @(
            [pscustomobject]@{ FullName = $pipedFile; PathType = 'Leaf' }
            [pscustomobject]@{ FullName = $pipedFile; PathType = 'Container' }
            [pscustomobject]@{ FullName = $pipedFolder; PathType = 'Container' }
        )

        $result = @($requests | Test-Path2 -ErrorAction Stop)

        $result -join ',' | Should -Be 'True,False,True'
    }

    It 'Should find an item whose name contains brackets' {
        $bracketFile = Join-Path -Path $sandbox -ChildPath 'TestPathBracket[2].txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $bracketFile
        Set-Content -LiteralPath $bracketFile -Value 'Bracket'

        Test-Path2 -Path $bracketFile -PathType Leaf -ErrorAction Stop | Should -BeTrue
    }

    It 'Should find an item through a UNC path of the administrative share' -Skip:(-not $canUseAdminShare) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'UncPathFile'
        $uncPath = ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $file

        Test-Path2 -Path $uncPath -PathType Leaf -ErrorAction Stop | Should -BeTrue
    }
}

Describe 'Get-FileHash2 binds -Algorithm by property name' {
    It 'Should hash with the algorithm bound by property name from the pipeline' {
        # Stored in a variable, like FileHash.Tests.ps1 and the MD5 call above: PSScriptAnalyzer flags a literal
        # weak-algorithm argument, not one that comes from a variable.
        $propertyAlgorithm = 'MD5'
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'HashAlgorithmByProperty'
        Set-Content -LiteralPath $file -Value 'AlgorithmPropertyContent'
        $request = [pscustomobject]@{ FullName = $file; Algorithm = $propertyAlgorithm }

        $result = $request | Get-FileHash2 -ErrorAction Stop

        $result.Algorithm | Should -Be $propertyAlgorithm
        $result.Hash | Should -BeExactly (Get-FileHash -LiteralPath $file -Algorithm $propertyAlgorithm).Hash
    }
}

Describe 'Get-DiskSpace free-space values and validation error' {
    It 'Should report free-space values close to an independent .NET read for the system drive' {
        $before = New-Object -TypeName 'System.IO.DriveInfo' -ArgumentList $env:SystemDrive

        $result = Get-DiskSpace -DriveLetter $env:SystemDrive -ErrorAction Stop

        $after = New-Object -TypeName 'System.IO.DriveInfo' -ArgumentList $env:SystemDrive
        # Free space can change between two live reads of a system drive under normal system activity, so the
        # comparison admits a tolerance around the values read immediately before and after the call, instead of
        # exact equality; the tolerance is still tight enough to catch a swapped or a wrong field.
        $tolerance = 500MB
        $result.TotalNumberOfFreeBytes | Should -BeGreaterOrEqual ([Math]::Min($before.TotalFreeSpace, $after.TotalFreeSpace) - $tolerance)
        $result.TotalNumberOfFreeBytes | Should -BeLessOrEqual ([Math]::Max($before.TotalFreeSpace, $after.TotalFreeSpace) + $tolerance)
        $result.FreeBytesAvailable | Should -BeGreaterOrEqual ([Math]::Min($before.AvailableFreeSpace, $after.AvailableFreeSpace) - $tolerance)
        $result.FreeBytesAvailable | Should -BeLessOrEqual ([Math]::Max($before.AvailableFreeSpace, $after.AvailableFreeSpace) + $tolerance)
    }

    # PowerShell's own parameter-validation engine raises this error before the cmdlet runs, so unlike the cmdlet's
    # own WriteError calls it carries no target object; this pins that engine behavior as observed, not assumed.
    It 'Should write the validation error for a bad -DriveLetter with its category, and no target object' {
        $caught = $null

        try {
            Get-DiskSpace -DriveLetter 'C' -ErrorAction Stop
        }
        catch {
            $caught = $_
        }

        $caught.FullyQualifiedErrorId | Should -Be 'ParameterArgumentValidationError,NTFSSecurity.GetDiskSpace'
        $caught.CategoryInfo.Category | Should -Be 'InvalidData'
        $caught.TargetObject | Should -BeNullOrEmpty
    }
}

Describe 'New-NTFSHardLink positional binding, FileInfo input, and share errors' {
    It 'Should bind -Path and -Target positionally' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'PositionalHardLinkTarget'
        Set-Content -LiteralPath $target -Value 'PositionalTarget'
        $link = Join-Path -Path $sandbox -ChildPath 'PositionalHardLinkLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSHardLink $link $target -ErrorAction Stop

        $link | Should -Exist
        Get-Content -LiteralPath $link | Should -Be 'PositionalTarget'
    }

    # Target has no FullName alias, so a FileInfo object can reach it only by value, through the
    # FileSystemPathTransformationAttribute of BaseCmdlets.cs, which reads .FullName for a FileSystemInfo argument.
    # -Path is bound explicitly by name here, which keeps it out of the pipeline-by-value binding so that the piped
    # FileInfo binds to -Target only.
    It 'Should accept a FileInfo object piped by value for -Target' {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'FileInfoBoundTarget'
        Set-Content -LiteralPath $target -Value 'FileInfoTarget'
        $targetItem = Get-Item2 -Path $target -ErrorAction Stop
        $link = Join-Path -Path $sandbox -ChildPath 'FileInfoBoundLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        $targetItem | New-NTFSHardLink -Path $link -ErrorAction Stop

        $link | Should -Exist
        Get-Content -LiteralPath $link | Should -Be 'FileInfoTarget'
    }

    # The existing share test (Links.Tests.ps1:150) asserts only the ID of this error.
    It '-PassThru should write GetHardLinkError with category ReadError and the link path as target on a network share' -Skip:(-not $canUseAdminShare) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'ShareCategoryTarget'
        $link = Join-Path -Path $sandbox -ChildPath 'ShareCategoryLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link
        $sharePath = ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $link
        $shareTarget = ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $target

        $result = @(New-NTFSHardLink -Path $sharePath -Target $shareTarget -PassThru -ErrorVariable linkErrors -ErrorAction SilentlyContinue)

        $link | Should -Exist
        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
        $linkErrors[0].CategoryInfo.Category | Should -Be 'ReadError'
        $linkErrors[0].TargetObject | Should -Be $sharePath
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-NTFSHardLink category on a network share' {
    # The existing share test (Links.Tests.ps1:247) asserts the ID and the target but not the category.
    It 'Should write GetHardLinkError with category ReadError for a file on a network share' -Skip:(-not $canUseAdminShare) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'HardLinkShareCategoryFile'
        $sharePath = ConvertTo-TestAdminSharePath -Sandbox $sandbox -Path $file

        Get-NTFSHardLink -Path $sharePath -ErrorVariable linkErrors -ErrorAction SilentlyContinue

        $linkErrors | Should -HaveCount 1
        $linkErrors[0].FullyQualifiedErrorId | Should -BeLike 'GetHardLinkError,*'
        $linkErrors[0].CategoryInfo.Category | Should -Be 'ReadError'
        $linkErrors[0].TargetObject | Should -Be $sharePath
    }
}

Describe 'New-NTFSSymbolicLink positional binding and folder links' {
    It 'Should bind -Path and -Target positionally' -Skip:(-not $canCreateSymbolicLinks) {
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'PositionalSymbolicTarget'
        Set-Content -LiteralPath $target -Value 'PositionalSymbolicTarget'
        $link = Join-Path -Path $sandbox -ChildPath 'PositionalSymbolicLink.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSSymbolicLink $link $target -ErrorAction Stop

        (Get-Item -LiteralPath $link -Force).LinkType | Should -Be 'SymbolicLink'
        Get-Content -LiteralPath $link | Should -Be 'PositionalSymbolicTarget'
    }

    # The existing folder-link test (Links.Tests.ps1:304) checks only the Directory attribute and reachability; only
    # the file-link test (Links.Tests.ps1:297) asserts LinkType and the resolved target.
    It 'Should set LinkType and the resolved target for a link to a folder' -Skip:(-not $canCreateSymbolicLinks) {
        $targetFolder = New-TestSandboxItem -Sandbox $sandbox -Name 'FolderLinkTypeTarget' -Directory
        $link = Join-Path -Path $sandbox -ChildPath 'FolderLinkType'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $link

        New-NTFSSymbolicLink -Path $link -Target $targetFolder -ErrorAction Stop

        (Get-Item -LiteralPath $link -Force).LinkType | Should -Be 'SymbolicLink'
        # Windows PowerShell returns the target as an array, PowerShell 7 as a string (Links.Tests.ps1:286).
        @((Get-Item -LiteralPath $link -Force).Target)[0] | Should -Be $targetFolder
    }
}

Describe 'Enable-Privileges -PassThru privilege states' {
    AfterEach {
        # Leaves the process token as the rest of the file expects it, regardless of which assertion above failed.
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
    }

    # Only Get-Privileges was used as the read-back before; this reads the four states directly from the -PassThru
    # objects and cross-checks them against whoami /priv, an independent source outside the module.
    It 'Should report Enabled for TakeOwnership, Restore, Backup, and Security in -PassThru, matching whoami /priv' -Skip:(-not $isElevated) {
        $result = @(Enable-Privileges -PassThru -ErrorAction Stop)
        $whoamiPrivileges = & whoami.exe /priv /fo csv | Select-Object -Skip 1 | ConvertFrom-Csv -Header 'Name', 'Description', 'State'

        foreach ($name in 'TakeOwnership', 'Restore', 'Backup', 'Security') {
            $entry = @($result | Where-Object -Property Privilege -EQ -Value $name)
            $entry | Should -HaveCount 1 -Because "Enable-Privileges -PassThru should list $name"
            $entry[0].PrivilegeState | Should -Be 'Enabled'

            $whoamiEntry = @($whoamiPrivileges | Where-Object -Property Name -EQ -Value ('Se{0}Privilege' -f $name))
            # The State column is localized; only the rows that whoami prints in English are compared (Get-Privileges
            # compared with an independent source, above).
            if ($whoamiEntry.Count -gt 0 -and $whoamiEntry[0].State -in 'Enabled', 'Disabled') {
                $whoamiEntry[0].State | Should -Be 'Enabled'
            }
        }
    }
}

Describe 'Disable-Privileges -PassThru privilege states' {
    It 'Should report Disabled for TakeOwnership, Restore, and Backup in -PassThru after a successful disable' -Skip:(-not $isElevated) {
        Enable-Privileges -ErrorAction Stop

        $result = @(Disable-Privileges -PassThru -ErrorAction Stop)

        foreach ($name in 'TakeOwnership', 'Restore', 'Backup') {
            $entry = @($result | Where-Object -Property Privilege -EQ -Value $name)
            $entry | Should -HaveCount 1 -Because "Disable-Privileges -PassThru should list $name"
            $entry[0].PrivilegeState | Should -Be 'Disabled'
        }
    }
}

# NOT DONE: "the Removed PrivilegeState value" (WORKLIST row 14) is not reachable through Get-Privileges. A probe
# (elevated, PowerShell 7) that removed the Backup privilege of a child process and compared Get-Privileges before
# and after showed the entry disappear from the list entirely instead of remaining with PrivilegeState=Removed:
#   BEFORE: ...,Backup=0,Restore=0,...   AFTER: ...,Restore=0,...   (Backup is gone, not listed as Removed)
# Privileges.GetPrivileges(accessTokenHandle) (ProcessPrivileges\Privileges.cs) builds its collection only from what
# GetTokenInformation(TokenPrivileges) currently returns, which drops an entry once SE_PRIVILEGE_REMOVED takes effect
# (matching the documented Win32 behavior of that attribute); the Removed state is produced only by the unrelated
# Privileges.GetPrivilegeAttributes(privilege, collection) lookup helper, which Get-Privileges never calls. No input
# makes Get-Privileges itself emit a Removed entry, so this item is left out instead of pinning a test that cannot
# exercise the branch it names; this is a structural gap of the same kind as the "Limit" rows, not a defect of a
# cmdlet, so nothing is reported under DEFECTS.

