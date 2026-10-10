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

        $badPath = switch ($CaseName) {
            'as an empty string' { '' }
            'as $null' { $null }
            'as an array with an empty element' { @('') }
        }

        { & $Command -Path $badPath -Destination $destination -ErrorAction Stop } |
            Should -Throw -ErrorId "ParameterArgumentValidationError,$TypeName"
        $source | Should -Exist
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
                $libraryEntry[0].PrivilegeState.ToString() | Should -Be $whoamiEntry[0].State
                $isEnabledByAttributes = ($libraryEntry[0].PrivilegeAttributes -band [ProcessPrivileges.PrivilegeAttributes]::Enabled) -eq [ProcessPrivileges.PrivilegeAttributes]::Enabled
                $isEnabledByAttributes | Should -Be ($whoamiEntry[0].State -eq 'Enabled')
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
