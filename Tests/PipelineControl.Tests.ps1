<#
    Tests how the cmdlets of the module built in NTFSSecurity\bin\Release behave when a later command in the pipeline
    ends it: a break or continue in a script block, Select-Object -First, or a terminating error such as a throw. The
    exception that carries it passes through the cmdlet while it writes an object, an error, a verbose message, or a debug
    message. A catch-all for the failures of an item must not report it as an error of that item and go on with the next
    one: a cmdlet that removes, copies, moves, or changes items would change them all, although the caller ended the
    pipeline, and the caller would never see the exception. Every test works on files and folders in a sandbox.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canReadAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'

    $names = @(
        'Get-ChildItem2', 'Get-DiskSpace', 'Get-FileHash2', 'Get-Item2', 'Get-NTFSAccess', 'Get-NTFSEffectiveAccess',
        'Get-NTFSHardLink', 'Get-NTFSInheritance', 'Get-NTFSOrphanedAccess', 'Get-NTFSOwner', 'Get-NTFSSecurityDescriptor',
        'Get-NTFSSimpleAccess', 'Get-Privileges', 'Test-Path2', 'Add-NTFSAccess', 'Remove-NTFSAccess',
        'Disable-NTFSAccessInheritance', 'Enable-NTFSAccessInheritance', 'Set-NTFSInheritance', 'Set-NTFSOwner',
        'Set-NTFSSecurityDescriptor', 'Copy-Item2', 'Move-Item2', 'Remove-Item2'
    )
    $auditNames = @(
        'Get-NTFSAudit', 'Get-NTFSOrphanedAudit', 'Add-NTFSAudit', 'Remove-NTFSAudit', 'Disable-NTFSAuditInheritance',
        'Enable-NTFSAuditInheritance'
    )
    $loopCases = foreach ($name in $names) {
        foreach ($keyword in 'break', 'continue') {
            @{ Name = $name; Keyword = $keyword }
        }
    }
    $stopCases = foreach ($name in $names) {
        @{ Name = $name }
    }
    $auditLoopCases = foreach ($name in $auditNames) {
        foreach ($keyword in 'break', 'continue') {
            @{ Name = $name; Keyword = $keyword }
        }
    }
    $auditStopCases = foreach ($name in $auditNames) {
        @{ Name = $name }
    }
    $failureCases = foreach ($name in $names) {
        foreach ($style in 'throw', 'Write-Error -ErrorAction Stop') {
            @{ Name = $name; Style = $style }
        }
    }
    $auditFailureCases = foreach ($name in $auditNames) {
        foreach ($style in 'throw', 'Write-Error -ErrorAction Stop') {
            @{ Name = $name; Style = $style }
        }
    }
    $streamCases = foreach ($case in @(
            @{ Name = 'Get-FileHash2'; Stream = 'verbose' }
            @{ Name = 'Set-NTFSSecurityDescriptor'; Stream = 'verbose' }
            @{ Name = 'Set-NTFSOwner'; Stream = 'debug' }
        )) {
        foreach ($style in 'Select-Object -First 1', 'throw') {
            @{ Name = $case.Name; Stream = $case.Stream; Style = $style }
        }
    }
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'PipelineControl'
    Push-Location -LiteralPath $sandbox

    $sidType = [System.Security.Principal.SecurityIdentifier]
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $orphan = 'S-1-5-21-1-2-3-1001'
    $privateData = (Get-Module -Name NTFSSecurity).PrivateData

    function New-Pair {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to the sandbox.'
        )]
        param ([switch] $Directory)

        @{
            First  = New-TestSandboxItem -Sandbox $sandbox -Name 'First' -Directory:$Directory
            Second = New-TestSandboxItem -Sandbox $sandbox -Name 'Second' -Directory:$Directory
        }
    }

    function Test-ExplicitEntry {
        param ([string] $Path, [string] $Account)

        @((Get-Acl -LiteralPath $Path).GetAccessRules($true, $false, $sidType) |
                Where-Object -FilterScript { $_.IdentityReference.Value -eq $Account }).Count -gt 0
    }

    # Each case runs one command over the two items of its context. Untouched tells whether the second item is as it
    # was, which it is only when the command stopped after the first one.
    $cases = @{
        'Get-ChildItem2'                = @{
            # The first file is two levels below the folder, so the exception passes the frames of the recursion.
            Prepare   = {
                $top = New-TestSandboxItem -Sandbox $sandbox -Name 'Tree' -Directory
                foreach ($relative in 'A\B\Two.txt', 'C\Three.txt') {
                    $file = Join-Path -Path $top -ChildPath $relative
                    Assert-TestSandboxPath -Sandbox $sandbox -Path $file
                    New-Item -ItemType Directory -Path (Split-Path -Path $file -Parent) -Force | Out-Null
                    Set-Content -LiteralPath $file -Value 'Tree'
                }
                @{ Top = $top }
            }
            Run       = { param ($Context) Get-ChildItem2 -Path $Context.Top -Recurse -File -ErrorAction SilentlyContinue }
        }
        'Get-DiskSpace'                 = @{
            Prepare = { @{} }
            Run     = { Get-DiskSpace -ErrorAction SilentlyContinue }
        }
        'Get-FileHash2'                 = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-FileHash2 -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-Item2'                     = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-Item2 -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSAccess'                = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-NTFSAccess -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSEffectiveAccess'       = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-NTFSEffectiveAccess -Path $Context.First, $Context.Second -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }
        }
        'Get-NTFSHardLink'              = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-NTFSHardLink -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSInheritance'           = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-NTFSInheritance -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSOrphanedAccess'        = @{
            Prepare = {
                $context = New-Pair
                Add-NTFSAccess -Path $context.First, $context.Second -Account $orphan -AccessRights ReadData -ErrorAction Stop
                $context
            }
            Run     = { param ($Context) Get-NTFSOrphanedAccess -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSOwner'                 = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-NTFSOwner -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSSecurityDescriptor'    = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Get-NTFSSecurityDescriptor -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSSimpleAccess'          = @{
            Prepare = { New-Pair -Directory }
            Run     = { param ($Context) Get-NTFSSimpleAccess -Path $Context.First, $Context.Second -IncludeRootFolder:$false -ErrorAction SilentlyContinue }
        }
        'Get-Privileges'                = @{
            Prepare = { @{} }
            Run     = { Get-Privileges -ErrorAction SilentlyContinue }
        }
        'Test-Path2'                    = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Test-Path2 -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Add-NTFSAccess'                = @{
            Prepare   = { New-Pair }
            Run       = { param ($Context) Add-NTFSAccess -Path $Context.First, $Context.Second -Account 'S-1-1-0' -AccessRights ReadData -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) -not (Test-ExplicitEntry -Path $Context.Second -Account 'S-1-1-0') }
        }
        'Remove-NTFSAccess'             = @{
            Prepare   = {
                $context = New-Pair
                Add-NTFSAccess -Path $context.First, $context.Second -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
                $context
            }
            Run       = { param ($Context) Remove-NTFSAccess -Path $Context.First, $Context.Second -Account 'S-1-1-0' -AccessRights ReadData -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) Test-ExplicitEntry -Path $Context.Second -Account 'S-1-1-0' }
        }
        'Disable-NTFSAccessInheritance' = @{
            Prepare   = { New-Pair }
            Run       = { param ($Context) Disable-NTFSAccessInheritance -Path $Context.First, $Context.Second -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) -not (Get-Acl -LiteralPath $Context.Second).AreAccessRulesProtected }
        }
        'Enable-NTFSAccessInheritance'  = @{
            Prepare   = {
                $context = New-Pair
                Disable-NTFSAccessInheritance -Path $context.First, $context.Second -ErrorAction Stop
                $context
            }
            Run       = { param ($Context) Enable-NTFSAccessInheritance -Path $Context.First, $Context.Second -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) (Get-Acl -LiteralPath $Context.Second).AreAccessRulesProtected }
        }
        'Set-NTFSInheritance'           = @{
            Prepare   = { New-Pair }
            Run       = { param ($Context) Set-NTFSInheritance -Path $Context.First, $Context.Second -AccessInheritanceEnabled $false -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) -not (Get-Acl -LiteralPath $Context.Second).AreAccessRulesProtected }
        }
        'Set-NTFSOwner'                 = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Set-NTFSOwner -Path $Context.First, $Context.Second -Account $currentUser -PassThru -ErrorAction SilentlyContinue }
        }
        'Set-NTFSSecurityDescriptor'    = @{
            Prepare   = {
                $context = New-Pair
                $context.Descriptors = @(Get-NTFSSecurityDescriptor -Path $context.First, $context.Second -ErrorAction Stop)
                Add-NTFSAccess -SecurityDescriptor $context.Descriptors -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
                $context
            }
            Run       = { param ($Context) Set-NTFSSecurityDescriptor -SecurityDescriptor $Context.Descriptors -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) -not (Test-ExplicitEntry -Path $Context.Second -Account 'S-1-1-0') }
        }
        'Copy-Item2'                    = @{
            Prepare   = {
                $context = New-Pair
                $context.Destination = New-TestSandboxItem -Sandbox $sandbox -Name 'CopyTo' -Directory
                $context
            }
            Run       = { param ($Context) Copy-Item2 -Path $Context.First, $Context.Second -Destination $Context.Destination -PassThru $true -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) -not (Test-Path -LiteralPath (Join-Path -Path $Context.Destination -ChildPath (Split-Path -Path $Context.Second -Leaf))) }
        }
        'Move-Item2'                    = @{
            Prepare   = {
                $context = New-Pair
                $context.Destination = New-TestSandboxItem -Sandbox $sandbox -Name 'MoveTo' -Directory
                $context
            }
            Run       = { param ($Context) Move-Item2 -Path $Context.First, $Context.Second -Destination $Context.Destination -PassThru $true -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) Test-Path -LiteralPath $Context.Second }
        }
        'Remove-Item2'                  = @{
            Prepare   = { New-Pair }
            Run       = { param ($Context) Remove-Item2 -Path $Context.First, $Context.Second -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) Test-Path -LiteralPath $Context.Second }
        }
        'Get-NTFSAudit'                 = @{
            Prepare = {
                $context = New-Pair
                Add-NTFSAudit -Path $context.First, $context.Second -Account 'S-1-1-0' -AccessRights Delete -AuditFlags Success -ErrorAction Stop
                $context
            }
            Run     = { param ($Context) Get-NTFSAudit -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Get-NTFSOrphanedAudit'         = @{
            Prepare = {
                $context = New-Pair
                Add-NTFSAudit -Path $context.First, $context.Second -Account $orphan -AccessRights Delete -AuditFlags Success -ErrorAction Stop
                $context
            }
            Run     = { param ($Context) Get-NTFSOrphanedAudit -Path $Context.First, $Context.Second -ErrorAction SilentlyContinue }
        }
        'Add-NTFSAudit'                 = @{
            Prepare   = { New-Pair }
            Run       = { param ($Context) Add-NTFSAudit -Path $Context.First, $Context.Second -Account 'S-1-1-0' -AccessRights Delete -AuditFlags Success -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) @(Get-NTFSAudit -Path $Context.Second -ErrorAction Stop).Count -eq 0 }
        }
        'Remove-NTFSAudit'              = @{
            # The entry of the orphan goes; the one of Everyone stays, so that there is an object to write.
            Prepare   = {
                $context = New-Pair
                foreach ($account in $orphan, 'S-1-1-0') {
                    Add-NTFSAudit -Path $context.First, $context.Second -Account $account -AccessRights Delete -AuditFlags Success -ErrorAction Stop
                }
                $context
            }
            Run       = { param ($Context) Remove-NTFSAudit -Path $Context.First, $Context.Second -Account $orphan -AccessRights Delete -AuditFlags Success -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) @(Get-NTFSAudit -Path $Context.Second -Account $orphan -ErrorAction Stop).Count -gt 0 }
        }
        'Disable-NTFSAuditInheritance'  = @{
            Prepare   = { New-Pair }
            Run       = { param ($Context) Disable-NTFSAuditInheritance -Path $Context.First, $Context.Second -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) (Get-NTFSInheritance -Path $Context.Second -ErrorAction Stop).AuditInheritanceEnabled }
        }
        'Enable-NTFSAuditInheritance'   = @{
            Prepare   = {
                $context = New-Pair
                Disable-NTFSAuditInheritance -Path $context.First, $context.Second -ErrorAction Stop
                $context
            }
            Run       = { param ($Context) Enable-NTFSAuditInheritance -Path $Context.First, $Context.Second -PassThru -ErrorAction SilentlyContinue }
            Untouched = { param ($Context) -not (Get-NTFSInheritance -Path $Context.Second -ErrorAction Stop).AuditInheritanceEnabled }
        }
    }

    # The commands that write a verbose or a debug message inside the try of their loop, which the later command takes.
    # The first record that reaches Select-Object ends the pipeline there. The preference of the debug stream is set by
    # Assert-StreamStop: the Debug switch would ask before every message. The error action is named because the CI runner
    # sets $ErrorActionPreference to Stop: a catch that reports the exception of the later command as an error of the
    # item would then end the pipeline with it, and the test could not tell that catch from passing the exception on.
    $streamRuns = @{
        'Get-FileHash2/verbose'              = @{
            # The first path is a folder, which the cmdlet skips with a verbose message.
            Prepare = {
                $context = New-Pair -Directory
                $context.File = New-TestSandboxItem -Sandbox $sandbox -Name 'Hashed'
                $context
            }
            Run     = { param ($Context) Get-FileHash2 -Path $Context.First, $Context.File -Verbose -ErrorAction SilentlyContinue 4>&1 }
        }
        'Set-NTFSSecurityDescriptor/verbose' = @{
            Prepare   = $cases['Set-NTFSSecurityDescriptor'].Prepare
            Run       = { param ($Context) Set-NTFSSecurityDescriptor -SecurityDescriptor $Context.Descriptors -Verbose -ErrorAction SilentlyContinue 4>&1 }
            Untouched = $cases['Set-NTFSSecurityDescriptor'].Untouched
        }
        'Set-NTFSOwner/debug'                = @{
            Prepare = { New-Pair }
            Run     = { param ($Context) Set-NTFSOwner -Path $Context.First, $Context.Second -Account $currentUser -ErrorAction SilentlyContinue 5>&1 }
        }
    }

    # The command writes its first object, and the break or continue of the later command ends the loop around the
    # pipeline before the next statement of the loop runs.
    function Assert-LoopControl {
        param ([string] $Name, [string] $Keyword)

        $case = $cases[$Name]
        $context = & $case.Prepare
        $emitted = 0
        $reachedEnd = $false
        $Error.Clear()
        foreach ($round in 1) {
            & $case.Run $context | ForEach-Object -Process {
                $emitted++
                if ($Keyword -eq 'break') { break } else { continue }
            }
            $reachedEnd = $true
        }

        $emitted | Should -Be 1
        $reachedEnd | Should -BeFalse
        $Error.Count | Should -Be 0
        if ($case.Untouched) {
            (& $case.Untouched $context) | Should -BeTrue
        }
    }

    function Assert-PipelineStop {
        param ([string] $Name)

        $case = $cases[$Name]
        $context = & $case.Prepare
        $Error.Clear()

        $result = @(& $case.Run $context | Select-Object -First 1)

        $result | Should -HaveCount 1
        $Error.Count | Should -Be 0
        if ($case.Untouched) {
            (& $case.Untouched $context) | Should -BeTrue
        }
    }

    # A later command that fails with a terminating error ends the pipeline for the commands before it. The error is the
    # caller's: the cmdlet must neither report it as an error of an item nor go on with the next item. PowerShell wraps
    # the exception of a throw, so the cmdlet never sees the type that was thrown.
    function Assert-DownstreamFailure {
        param ([string] $Name, [string] $Style)

        $case = $cases[$Name]
        $context = & $case.Prepare
        $emitted = 0
        $caught = $null
        $Error.Clear()
        try {
            & $case.Run $context | ForEach-Object -Process {
                $emitted++
                if ($Style -eq 'throw') { throw 'Downstream failure' }
                Write-Error -Message 'Downstream failure' -ErrorAction Stop
            }
        }
        catch {
            $caught = $_
        }

        $caught.Exception.Message | Should -BeLike '*Downstream failure*'
        $emitted | Should -Be 1
        @($Error | Where-Object -FilterScript { $_.Exception.Message -notlike '*Downstream failure*' }) | Should -BeNullOrEmpty
        if ($case.Untouched) {
            (& $case.Untouched $context) | Should -BeTrue
        }
    }

    # The first verbose or debug record reaches the later command, which ends the pipeline inside the try of the loop:
    # Select-Object raises the end of the pipeline, a throw raises an exception of its own. With the privileges enabled,
    # the cmdlet writes a message before that, outside the try, so they stay off here.
    function Assert-StreamStop {
        param ([string] $Name, [string] $Stream, [string] $Style)

        $case = $streamRuns["$Name/$Stream"]
        $recordType = if ($Stream -eq 'debug') { [System.Management.Automation.DebugRecord] } else { [System.Management.Automation.VerboseRecord] }
        $context = & $case.Prepare
        $saved = $privateData['EnablePrivileges']
        $savedDebugPreference = $DebugPreference
        $privateData['EnablePrivileges'] = $false
        $DebugPreference = if ($Stream -eq 'debug') { 'Continue' } else { $savedDebugPreference }
        $emitted = 0
        $caught = $null
        $result = @()
        $Error.Clear()
        try {
            if ($Style -eq 'throw') {
                try {
                    & $case.Run $context | ForEach-Object -Process {
                        $emitted++
                        throw 'Downstream failure'
                    }
                }
                catch {
                    $caught = $_
                }
            }
            else {
                $result = @(& $case.Run $context | Select-Object -First 1)
            }
        }
        finally {
            $privateData['EnablePrivileges'] = $saved
            $DebugPreference = $savedDebugPreference
        }

        if ($Style -eq 'throw') {
            $caught.Exception.Message | Should -BeLike '*Downstream failure*'
            $emitted | Should -Be 1
            @($Error | Where-Object -FilterScript { $_.Exception.Message -notlike '*Downstream failure*' }) | Should -BeNullOrEmpty
        }
        else {
            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType $recordType
            $Error.Count | Should -Be 0
        }

        if ($case.Untouched) {
            (& $case.Untouched $context) | Should -BeTrue
        }
    }
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'A later command that ends the pipeline' {
    It '<Name> should leave the loop for <Keyword> after its first object and change nothing else' -ForEach $loopCases {
        Assert-LoopControl -Name $Name -Keyword $Keyword
    }

    It '<Name> should stop after the first object for Select-Object -First 1 and change nothing else' -ForEach $stopCases {
        Assert-PipelineStop -Name $Name
    }

    It '<Name> should leave the loop for <Keyword> after its first object and change nothing else' -Skip:(-not $canReadAudit) -ForEach $auditLoopCases {
        Assert-LoopControl -Name $Name -Keyword $Keyword
    }

    It '<Name> should stop after the first object for Select-Object -First 1 and change nothing else' -Skip:(-not $canReadAudit) -ForEach $auditStopCases {
        Assert-PipelineStop -Name $Name
    }

    It '<Name> should stop for a terminating error (<Style>) of the later command and change nothing else' -ForEach $failureCases {
        Assert-DownstreamFailure -Name $Name -Style $Style
    }

    It '<Name> should stop for a terminating error (<Style>) of the later command and change nothing else' -Skip:(-not $canReadAudit) -ForEach $auditFailureCases {
        Assert-DownstreamFailure -Name $Name -Style $Style
    }

    It '<Name> should stop at the <Stream> message for <Style> of the later command and change nothing else' -ForEach $streamCases {
        Assert-StreamStop -Name $Name -Stream $Stream -Style $Style
    }
}

# The errors that Get-ChildItem2 writes for a folder that it cannot read reach a later command too, for example with 2>&1.
# The folders that cannot be read come first in the order of the file system, so that the folder with the file is reached
# only if the listing goes on after the first error.
Describe 'A later command and the error of a folder that Get-ChildItem2 cannot read' {
    BeforeAll {
        $errorTree = New-TestSandboxItem -Sandbox $sandbox -Name 'ErrorTree' -Directory
        $unreadable = foreach ($name in 'A', 'B') {
            $folder = Join-Path -Path $errorTree -ChildPath $name
            Assert-TestSandboxPath -Sandbox $sandbox -Path $folder
            New-Item -ItemType Directory -Path $folder | Out-Null
            $folder
        }
        $readableFile = Join-Path -Path $errorTree -ChildPath 'C\Three.txt'
        Assert-TestSandboxPath -Sandbox $sandbox -Path $readableFile
        New-Item -ItemType Directory -Path (Split-Path -Path $readableFile -Parent) | Out-Null
        Set-Content -LiteralPath $readableFile -Value 'Three'
        foreach ($folder in $unreadable) {
            Add-TestDenyRule -Sandbox $sandbox -Path $folder -Rights @{ 'S-1-1-0' = 'ReadData' }
        }
    }

    # Before 5.0.0-rc7, the recursion took what the later command threw for the error of a nested folder as a failure of
    # the folder above it, wrote a verbose message, and left the loop over the folders: the listing ended early and the
    # caller never saw the exception. The error action is named because the CI runner sets $ErrorActionPreference to Stop,
    # which would end the listing at the first error before the later command saw it.
    It 'Should pass on what a later command throws when it takes the error of a nested folder' {
        $emitted = 0
        $caught = $null
        try {
            Get-ChildItem2 -Path $errorTree -Recurse -File -ErrorAction Continue 2>&1 | ForEach-Object -Process {
                $emitted++
                throw 'Downstream failure'
            }
        }
        catch {
            $caught = $_
        }

        $caught.Exception.Message | Should -BeLike '*Downstream failure*'
        $emitted | Should -Be 1
    }

    It 'Should leave the loop for a <Keyword> of a later command that takes the error of a nested folder' -ForEach @(
        @{ Keyword = 'break' }
        @{ Keyword = 'continue' }
    ) {
        $emitted = 0
        $reachedEnd = $false
        foreach ($round in 1) {
            Get-ChildItem2 -Path $errorTree -Recurse -File -ErrorAction Continue 2>&1 | ForEach-Object -Process {
                $emitted++
                if ($Keyword -eq 'break') { break } else { continue }
            }
            $reachedEnd = $true
        }

        $emitted | Should -Be 1
        $reachedEnd | Should -BeFalse
    }

    It 'Should stop with the error of the first nested folder that it cannot read for -ErrorAction Stop' {
        $listed = New-Object -TypeName 'System.Collections.Generic.List[object]'
        $caught = $null
        try {
            Get-ChildItem2 -Path $errorTree -Recurse -File -ErrorAction Stop | ForEach-Object -Process { $listed.Add($_) }
        }
        catch {
            $caught = $_
        }

        $caught | Should -Not -BeNullOrEmpty
        $caught.FullyQualifiedErrorId | Should -BeLike 'DirUnauthorizedAccessError,*'
        $caught.TargetObject | Should -Be $unreadable[0]
        $listed | Should -BeNullOrEmpty
    }
}

# The catches of Get-ChildItem2 for an UnauthorizedAccessException and of Remove-Item2 for an IOException don't ask where
# the exception comes from: they rely on PowerShell wrapping what a later command throws, so that an exception of these
# types never reaches them as it was thrown. A PowerShell version that hands it on as it is fails these tests.
Describe 'A later command that throws an exception of a type that a cmdlet handles' {
    It 'Get-ChildItem2 should pass on a thrown UnauthorizedAccessException' {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ThrownDenied' -Directory
        $files = 'One.txt', 'Two.txt' | ForEach-Object -Process { Join-Path -Path $folder -ChildPath $_ }
        Assert-TestSandboxPath -Sandbox $sandbox -Path $files
        Set-Content -LiteralPath $files -Value 'File'
        $emitted = 0
        $caught = $null
        $Error.Clear()
        try {
            Get-ChildItem2 -Path $folder -File -ErrorAction SilentlyContinue | ForEach-Object -Process {
                $emitted++
                throw [System.UnauthorizedAccessException]::new('Downstream failure')
            }
        }
        catch {
            $caught = $_
        }

        $caught.Exception | Should -BeOfType [System.UnauthorizedAccessException]
        $caught.Exception.Message | Should -BeExactly 'Downstream failure'
        $emitted | Should -Be 1
        @($Error | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like 'DirUnauthorizedAccessError,*' }) | Should -BeNullOrEmpty
    }

    It 'Remove-Item2 should pass on a thrown IOException and leave the next item' {
        $pair = New-Pair
        $emitted = 0
        $caught = $null
        $Error.Clear()
        try {
            Remove-Item2 -Path $pair.First, $pair.Second -PassThru -ErrorAction SilentlyContinue | ForEach-Object -Process {
                $emitted++
                throw [System.IO.IOException]::new('Downstream failure')
            }
        }
        catch {
            $caught = $_
        }

        $caught.Exception | Should -BeOfType [System.IO.IOException]
        $caught.Exception.Message | Should -BeExactly 'Downstream failure'
        $emitted | Should -Be 1
        $pair.Second | Should -Exist
        @($Error | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like 'DeleteError,*' }) | Should -BeNullOrEmpty
    }
}

# A cmdlet also meets the end of the pipeline where it did not write: another call of PowerShell can raise it too. The
# check that every catch-all makes recognizes the exceptions by their types. PowerShell keeps the exceptions of break and
# continue internal, so they are recognized by the name of their base type, which a stand-in with that name shows.
Describe 'Recognizing the end of a pipeline by the type of the exception' {
    BeforeAll {
        if (-not ('NtfsSecurityTests.StandInForBreak' -as [type])) {
            # The compiler warns that the stand-in has the name of an imported type, and Add-Type treats a warning as an error.
            Add-Type -IgnoreWarnings -TypeDefinition @'
namespace System.Management.Automation { public class FlowControlException : System.Exception { } }
namespace NtfsSecurityTests { public class StandInForBreak : System.Management.Automation.FlowControlException { } }
'@
        }

        $isEnd = [NTFSSecurity.BaseCmdlet].Assembly.GetType('NTFSSecurity.PipelineControl').GetMethod(
            'IsEnd', [System.Reflection.BindingFlags] 'NonPublic, Static')
    }

    It 'Should recognize a PipelineStoppedException' {
        $isEnd.Invoke($null, @([System.Management.Automation.PipelineStoppedException]::new())) | Should -BeTrue
    }

    It 'Should recognize an exception whose base type is the flow control exception of PowerShell' {
        $isEnd.Invoke($null, @([NtfsSecurityTests.StandInForBreak]::new())) | Should -BeTrue
    }

    It 'Should not recognize <Description>' -ForEach @(
        @{ Description = 'a failure of an item'; Exception = [System.InvalidOperationException]::new('Failure') }
        @{ Description = 'an access denial'; Exception = [System.UnauthorizedAccessException]::new('Denied') }
        @{ Description = 'a failure with an inner exception that ends the pipeline'; Exception = [System.InvalidOperationException]::new('Failure', [System.Management.Automation.PipelineStoppedException]::new()) }
    ) {
        $isEnd.Invoke($null, @($Exception)) | Should -BeFalse
    }
}

# InvokeAsOwner (and Set-NTFSSecurityDescriptor's WriteChangesAsOwner) take ownership, run the action, and in a
# finally restore the previous owner, writing a RestoreOwnerError through WriteError when that restore fails.
# WriteError runs the later commands of the pipeline and notes what they raise (IsFromLaterCommand, above); the catch
# around the InvokeAsOwner/WriteChangesAsOwner call must pass that on instead of reporting it as the item's own error
# and going on, or the caller never sees it. Each row denies the current user the right its own action needs (a
# change denial for the writers, a read denial on Everyone for Get-FileHash2, which needs file data, not
# permissions) and gives the item an owner that only the Restore privilege can set back, which the tests turn off;
# InvokeAsOwner/WriteChangesAsOwner then takes ownership, runs the action, and fails to restore the owner. Eight of
# the seventeen handlers of item 7 can be pinned this way. The scenario and the "without a later command" assertion
# already exist for six of them: ParameterSets.Inheritance.Tests.ps1 (Disable/Enable-NTFSAccessInheritance,
# Set-NTFSInheritance), PathErrors.Tests.ps1 (Clear-NTFSAccess -DisableInheritance), SecurityDescriptor.Tests.ps1
# (Set-NTFSSecurityDescriptor), FileHash.Tests.ps1 (Get-FileHash2); Add-NTFSAccess and Remove-NTFSAccess use the same
# scenario as the inheritance cmdlets. So this table only adds the later-command assertion, not a duplicate of the
# existing one.
#
# NOT DONE for the other nine (the reason is the same Windows rule in both groups: taking ownership only bypasses a
# denial of ReadPermissions/ChangePermissions, never of a different right): Get-NTFSAccess, Get-NTFSOrphanedAccess,
# Get-NTFSEffectiveAccess, and Get-NTFSInheritance read the security descriptor; InvokeAsOwner's own first statement,
# FileSystemOwner.GetOwner, reads it too and needs the same ReadPermissions right the cmdlet's read needs, so a
# denial that fails one fails the other and InvokeAsOwner never reaches the owner-restore step (verified: denying
# ReadPermissions directly to the user reports ReadSecurityError with the plain UnauthorizedAccessException, not
# RestoreOwnerError, and the owner is never taken; probes-wi2\p-restoreowner-read-vs-write.ps1,
# p-read-cmdlets-2.ps1). Clear-NTFSAudit, Disable-NTFSAuditInheritance, Enable-NTFSAuditInheritance, Add-NTFSAudit, and
# Remove-NTFSAudit write the SACL, which Windows grants to this elevated session regardless of a DACL deny and
# regardless of the module's EnablePrivileges setting, so the action does not fail to begin with (verified with both
# a ChangePermissions deny and EnablePrivileges off: no error, the SACL is written, and the owner is left unchanged;
# probes-wi2\p-audit-restoreowner.ps1, p-audit-restoreowner-2.ps1). The handlers of all seventeen carry the check.
Describe 'A later command that throws at the RestoreOwnerError record' {
    BeforeDiscovery {
        $holdsRestorePrivilege = Test-PrivilegeHeld -Name 'SeRestorePrivilege'
        $laterCommandRestoreOwnerNames = @(
            'Clear-NTFSAccess', 'Disable-NTFSAccessInheritance', 'Enable-NTFSAccessInheritance', 'Set-NTFSInheritance',
            'Set-NTFSSecurityDescriptor', 'Get-FileHash2', 'Add-NTFSAccess', 'Remove-NTFSAccess'
        )
    }

    BeforeAll {
        # An owner that the user can assign only with the Restore privilege, which EnablePrivileges = $false below
        # keeps disabled, matching the existing RestoreOwnerError tests of the other files.
        $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
        $enablePrivileges = $privateData['EnablePrivileges']
        $privateData['EnablePrivileges'] = $false

        $laterCommandRestoreOwnerCases = @{
            'Clear-NTFSAccess'               = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterClearBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterClearNext'
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid 'S-1-5-32-544'
                    Add-NTFSAccess -Path $blocked, $next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ 'S-1-3-4' = 'ChangePermissions' }
                    @{ Blocked = $blocked; Next = $next }
                }
                Run         = { param ($Context) Clear-NTFSAccess -Path $Context.Blocked, $Context.Next -DisableInheritance -ErrorAction Continue }
                ItemErrorId = 'ClearAclError'
                Untouched   = { param ($Context, $Emitted) (Test-ExplicitEntry -Path $Context.Next -Account 'S-1-1-0') -and -not (Get-Acl -LiteralPath $Context.Next).AreAccessRulesProtected -and $Emitted.Count -eq 0 }
            }
            'Disable-NTFSAccessInheritance'  = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterDisableBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterDisableNext'
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $currentUser = 'ChangePermissions' }
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
                    @{ Blocked = $blocked; Next = $next }
                }
                Run         = { param ($Context) Disable-NTFSAccessInheritance -Path $Context.Blocked, $Context.Next -ErrorAction Continue }
                ItemErrorId = 'ModifySdError'
                Untouched   = { param ($Context, $Emitted) -not (Get-Acl -LiteralPath $Context.Next).AreAccessRulesProtected -and $Emitted.Count -eq 0 }
            }
            'Enable-NTFSAccessInheritance'   = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterEnableBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterEnableNext'
                    Disable-NTFSAccessInheritance -Path $blocked, $next -ErrorAction Stop
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $currentUser = 'ChangePermissions' }
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
                    @{ Blocked = $blocked; Next = $next }
                }
                Run         = { param ($Context) Enable-NTFSAccessInheritance -Path $Context.Blocked, $Context.Next -ErrorAction Continue }
                ItemErrorId = 'ModifySdError'
                Untouched   = { param ($Context, $Emitted) (Get-Acl -LiteralPath $Context.Next).AreAccessRulesProtected -and $Emitted.Count -eq 0 }
            }
            'Set-NTFSInheritance'            = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterSetInheritanceBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterSetInheritanceNext'
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $currentUser = 'ChangePermissions' }
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
                    @{ Blocked = $blocked; Next = $next }
                }
                Run         = { param ($Context) Set-NTFSInheritance -Path $Context.Blocked, $Context.Next -AccessInheritanceEnabled $false -ErrorAction Continue }
                ItemErrorId = 'ModifySdError'
                Untouched   = { param ($Context, $Emitted) -not (Get-Acl -LiteralPath $Context.Next).AreAccessRulesProtected -and $Emitted.Count -eq 0 }
            }
            'Set-NTFSSecurityDescriptor'     = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterSdBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterSdNext'
                    $descriptors = @(Get-NTFSSecurityDescriptor -Path $blocked, $next -ErrorAction Stop)
                    Add-NTFSAccess -SecurityDescriptor $descriptors -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $currentUser = 'ChangePermissions' }
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
                    @{ Descriptors = $descriptors; Next = $next }
                }
                Run         = { param ($Context) Set-NTFSSecurityDescriptor -SecurityDescriptor $Context.Descriptors -ErrorAction Continue }
                ItemErrorId = 'WriteSdError'
                Untouched   = { param ($Context, $Emitted) -not (Test-ExplicitEntry -Path $Context.Next -Account 'S-1-1-0') -and $Emitted.Count -eq 0 }
            }
            'Get-FileHash2'                  = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterHashBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterHashNext'
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ 'S-1-1-0' = 'ReadData' }
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
                    @{ Blocked = $blocked; Next = $next }
                }
                Run         = { param ($Context) Get-FileHash2 -Path $Context.Blocked, $Context.Next -ErrorAction Continue }
                ItemErrorId = 'GetHashError'
                # Get-FileHash2 has no ACL state of its own to read back, so the oracle is that the next path still
                # exists, untouched, and that the pipeline produced no hash at all: the next path's hash would be the
                # only object a later-command block ever sees, since neither -PassThru nor an output object exists
                # for the blocked path in either state of the fix. Not @($Emitted): PowerShell's array operator
                # raises ArgumentException for an empty generic List(Of T).
                Untouched   = { param ($Context, $Emitted) (Test-Path -LiteralPath $Context.Next) -and $Emitted.Count -eq 0 }
            }
            'Add-NTFSAccess'                 = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterAddBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterAddNext'
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $currentUser = 'ChangePermissions' }
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
                    @{ Blocked = $blocked; Next = $next }
                }
                Run         = { param ($Context) Add-NTFSAccess -Path $Context.Blocked, $Context.Next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Continue }
                ItemErrorId = 'AddAceError'
                Untouched   = { param ($Context, $Emitted) -not (Test-ExplicitEntry -Path $Context.Next -Account 'S-1-1-0') -and $Emitted.Count -eq 0 }
            }
            'Remove-NTFSAccess'              = @{
                Prepare     = {
                    $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterRemoveBlocked'
                    $next = New-TestSandboxItem -Sandbox $sandbox -Name 'LaterRemoveNext'
                    Add-NTFSAccess -Path $blocked, $next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
                    Add-TestDenyRule -Sandbox $sandbox -Path $blocked -Rights @{ $currentUser = 'ChangePermissions' }
                    Set-TestOwner -Sandbox $sandbox -Path $blocked -Sid $trustedInstaller
                    @{ Blocked = $blocked; Next = $next }
                }
                Run         = { param ($Context) Remove-NTFSAccess -Path $Context.Blocked, $Context.Next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Continue }
                ItemErrorId = 'RemoveAceError'
                Untouched   = { param ($Context, $Emitted) (Test-ExplicitEntry -Path $Context.Next -Account 'S-1-1-0') -and $Emitted.Count -eq 0 }
            }
        }
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $enablePrivileges
    }

    It '<_> should pass on what a later command raises at the RestoreOwnerError record instead of reporting it as the item''s own error, and leave the next path untouched' -Skip:(-not $holdsRestorePrivilege) -ForEach $laterCommandRestoreOwnerNames {
        $case = $laterCommandRestoreOwnerCases[$_]
        $context = & $case.Prepare
        $Error.Clear()
        $caught = $null
        $emitted = New-Object -TypeName 'System.Collections.Generic.List[object]'

        try {
            & $case.Run $context 2>&1 | ForEach-Object -Process {
                if ($_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -like 'RestoreOwnerError,*') {
                    throw 'later'
                }
                $emitted.Add($_)
                $_
            }
        }
        catch {
            $caught = $_
        }

        $caught.Exception.Message | Should -BeLike '*later*'
        @($Error | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like ('{0},*' -f $case.ItemErrorId) }) | Should -BeNullOrEmpty
        (& $case.Untouched $context $emitted) | Should -BeTrue
    }

    # Without a later command, the existing behavior stays: RestoreOwnerError is reported and the cmdlet goes on to
    # the next path, already pinned by the tests named above for all six rows; not duplicated here.
}
