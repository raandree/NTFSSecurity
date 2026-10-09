<#
    Tests how the cmdlets of the module built in NTFSSecurity\bin\Release handle the Backup, Restore, Take Ownership,
    and Security privileges. These tests need an access token that holds the privileges, so they skip without them
    and run in CI, whose runners are elevated. They change only the privileges of the test process and restore the
    module setting EnablePrivileges.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $missingPrivileges = @('SeBackupPrivilege', 'SeRestorePrivilege', 'SeTakeOwnershipPrivilege', 'SeSecurityPrivilege') |
        Where-Object -FilterScript { -not (Test-PrivilegeHeld -Name $_) }
    $holdsPrivileges = -not $missingPrivileges
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Privileges'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']

    function Get-BackupPrivilegeState {
        (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Backup').PrivilegeState
    }

    function Get-EnabledFileSystemPrivilege {
        # The names of the privileges that the cmdlets enable, as far as they are enabled now
        @(Get-Privileges | Where-Object -FilterScript {
                $_.Privilege -in 'TakeOwnership', 'Restore', 'Backup', 'Security' -and $_.PrivilegeState -eq 'Enabled'
            } | ForEach-Object -Process { $_.Privilege.ToString() })
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Disable-Privileges' {
    Context 'When the module setting EnablePrivileges is $false' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0, the cmdlet warned that it could not disable the privileges and left them enabled.
        It 'Should disable the privileges that Enable-Privileges enabled' -Skip:(-not $holdsPrivileges) {
            Enable-Privileges
            Get-BackupPrivilegeState | Should -Be 'Enabled'

            Disable-Privileges -WarningVariable privilegeWarnings -WarningAction SilentlyContinue

            $privilegeWarnings | Should -BeNullOrEmpty
            Get-BackupPrivilegeState | Should -Be 'Disabled'
        }

        # Before 5.0.0, the verbose message said that the privileges were now enabled.
        It 'Should say in the verbose message that the privileges are disabled' -Skip:(-not $holdsPrivileges) {
            Enable-Privileges

            $messages = Disable-Privileges -Verbose -WarningAction SilentlyContinue 4>&1

            $messages.Message | Should -Contain "The privileges 'TakeOwnership', 'Restore' and 'Backup' are now disabled."
        }
    }

    Context 'When the access token holds only some of the privileges' {
        # Before 5.0.0-rc4, the cmdlet also tried to disable the privileges that the access token doesn't hold, and
        # warned for each one that it couldn't disable it. A removed privilege can't be added back, so the test removes
        # them in a child process.
        It 'Should not warn about the privileges that the access token does not hold' -Skip:(-not $holdsPrivileges) {
            $script = Join-Path -Path $sandbox -ChildPath 'Disable-PartialPrivileges.ps1'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $script
            Set-Content -LiteralPath $script -Value @'
param ($ModulePath)
Import-Module -Name $ModulePath -ErrorAction Stop
$process = [System.Diagnostics.Process]::GetCurrentProcess()
[ProcessPrivileges.ProcessExtensions]::RemovePrivilege($process, [ProcessPrivileges.Privilege]::TakeOwnership) | Out-Null
[ProcessPrivileges.ProcessExtensions]::RemovePrivilege($process, [ProcessPrivileges.Privilege]::Security) | Out-Null
Enable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Disable-Privileges -WarningVariable privilegeWarnings -WarningAction SilentlyContinue
'WARNINGS:{0}' -f @($privilegeWarnings).Count
'@

            $output = & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script -ModulePath ([IO.Path]::GetFullPath($modulePath))

            $output | Should -Contain 'WARNINGS:0'
        }
    }
}

Describe 'Inheritance cmdlets' {
    Context 'When the module setting EnablePrivileges is $false' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Inheritance'
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Before 5.0.0, the inheritance cmdlets enabled the privileges anyway and left them enabled.
        It '<_> should leave the privileges disabled' -Skip:(-not $holdsPrivileges) -ForEach @(
            'Get-NTFSInheritance', 'Set-NTFSInheritance', 'Enable-NTFSAccessInheritance',
            'Disable-NTFSAccessInheritance', 'Enable-NTFSAuditInheritance', 'Disable-NTFSAuditInheritance'
        ) {
            Get-BackupPrivilegeState | Should -Be 'Disabled'

            & $_ -Path $file -ErrorAction SilentlyContinue | Out-Null

            Get-BackupPrivilegeState | Should -Be 'Disabled'
        }
    }
}

Describe 'Privileges when the pipeline stops early' {
    BeforeAll {
        # The cmdlets enable the privileges only with this setting; without it, these tests would prove nothing.
        $privateData['EnablePrivileges'] = $true
        $files = 1..3 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "Stopped$_" }
        $missing = Join-Path -Path $sandbox -ChildPath 'StoppedMissing.txt'
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $enablePrivileges
    }

    BeforeEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    AfterEach {
        # A failing test must not leave the privileges enabled for the tests that follow.
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    # Before 5.0.0-rc6, a cmdlet disabled the privileges that it had enabled only in EndProcessing, which PowerShell
    # skips when a later command or a terminating error stops the pipeline. The Backup, Restore, Take Ownership, and
    # Security privileges then stayed enabled in the session.
    It 'Should disable the privileges after Select-Object -First stops the pipeline' -Skip:(-not $holdsPrivileges) {
        Get-BackupPrivilegeState | Should -Be 'Disabled'

        $stateWhileRunning = Get-NTFSOwner -Path $files | ForEach-Object -Process { Get-BackupPrivilegeState } |
            Select-Object -First 1

        $stateWhileRunning | Should -Be 'Enabled'
        Get-BackupPrivilegeState | Should -Be 'Disabled'
    }

    It 'Should disable the privileges after a terminating error' -Skip:(-not $holdsPrivileges) {
        Get-BackupPrivilegeState | Should -Be 'Disabled'
        $statesWhileRunning = New-Object -TypeName 'System.Collections.Generic.List[string]'

        {
            Get-NTFSAccess -Path $files[0], $missing -ErrorAction Stop |
                ForEach-Object -Process { $statesWhileRunning.Add((Get-BackupPrivilegeState)) }
        } | Should -Throw

        $statesWhileRunning | Should -Not -BeNullOrEmpty
        $statesWhileRunning | Should -Not -Contain 'Disabled'
        Get-BackupPrivilegeState | Should -Be 'Disabled'
    }

    It 'Enable-Privileges should keep the privileges enabled also when the pipeline stops early' -Skip:(-not $holdsPrivileges) {
        Enable-Privileges -PassThru | Select-Object -First 1 | Out-Null

        Get-BackupPrivilegeState | Should -Be 'Enabled'
    }
}

# A cmdlet enables the privileges one after the other and writes a debug message before and after each one. A later command
# that takes the debug stream can end the pipeline or throw at the message after the enabling, before the cmdlet has noted
# that it enabled the privilege.
Describe 'Privileges when a later command takes the debug messages of the cmdlet' {
    BeforeAll {
        $privateData['EnablePrivileges'] = $true
        $debugFile = New-TestSandboxItem -Sandbox $sandbox -Name 'DebugStopped'
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $enablePrivileges
    }

    BeforeEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    AfterEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    # Before 5.0.0-rc7, the privilege that the cmdlet had enabled at that moment stayed enabled in the session: nothing
    # disabled it, because the cmdlet had not noted yet that it enabled it.
    It 'Should disable the privilege when Select-Object -First ends the pipeline at the message after its enabling' -Skip:(-not $holdsPrivileges) {
        $DebugPreference = 'Continue'
        $messages = @(Get-NTFSOwner -Path $debugFile 5>&1 | ForEach-Object -Process { $_.Message })
        $enabledAt = $messages.IndexOf('..enabled') + 1
        $enabledAt | Should -BeGreaterThan 0
        Get-EnabledFileSystemPrivilege | Should -BeNullOrEmpty

        $result = @(Get-NTFSOwner -Path $debugFile 5>&1 | Select-Object -First $enabledAt)

        $result | Should -HaveCount $enabledAt
        $result[-1].Message | Should -BeExactly '..enabled'
        Get-EnabledFileSystemPrivilege | Should -BeNullOrEmpty
    }

    # Before 5.0.0-rc7, the cmdlet took the exception for the failure to enable the privilege, went on with the next
    # privilege, and the caller never saw it; all four privileges stayed enabled.
    It 'Should pass on what a later command throws at the message after the enabling and disable the privileges' -Skip:(-not $holdsPrivileges) {
        $DebugPreference = 'Continue'
        $caught = $null
        try {
            Get-NTFSOwner -Path $debugFile 5>&1 | ForEach-Object -Process {
                if ($_.Message -eq '..enabled') { throw 'Downstream failure' }
                $_
            } | Out-Null
        }
        catch {
            $caught = $_
        }

        $caught.Exception.Message | Should -BeLike '*Downstream failure*'
        Get-EnabledFileSystemPrivilege | Should -BeNullOrEmpty
    }
}

# Enable-Privileges recognizes the script NTFSSecurity.Init.ps1, which a user adds to start the module, by its name: from
# that script, it enables the privileges only for the module setting EnablePrivileges, from any other script always. Each
# test runs the script in a child process, which inherits the privilege states of this one (disabled here, see BeforeEach),
# so that the privileges of this process stay as they are. With the setting $true, the module enables the privileges
# itself before the cmdlet runs, so the state alone does not show that the cmdlet did: it also announces that in a verbose
# message.
Describe 'Enable-Privileges in the script NTFSSecurity.Init.ps1' {
    BeforeAll {
        function Invoke-StartScript {
            param ([string] $ScriptName, [bool] $Setting)

            $folder = Join-Path -Path $sandbox -ChildPath ('Start-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            $script = Join-Path -Path $folder -ChildPath $ScriptName
            Assert-TestSandboxPath -Sandbox $sandbox -Path $script
            New-Item -ItemType Directory -Path $folder | Out-Null
            Set-Content -LiteralPath $script -Value @'
param ($ModulePath, $Setting)
Import-Module -Name $ModulePath -ErrorAction Stop
(Get-Module -Name NTFSSecurity).PrivateData['EnablePrivileges'] = ($Setting -eq 'True')
$messages = @(Enable-Privileges -Verbose 4>&1 | ForEach-Object -Process { "$($_.Message)" })
'ANNOUNCED:{0}' -f [bool] @($messages -like '*are now enabled giving you access*').Count
'BACKUP:{0}' -f (Get-Privileges | Where-Object -Property Privilege -EQ -Value 'Backup').PrivilegeState
'@
            $output = @(& (Get-Process -Id $PID).Path -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script -ModulePath ([IO.Path]::GetFullPath($modulePath)) -Setting $Setting)
            [pscustomobject]@{
                Announced = @($output | Where-Object -FilterScript { $_ -like 'ANNOUNCED:*' }) -replace '^ANNOUNCED:'
                Backup    = @($output | Where-Object -FilterScript { $_ -like 'BACKUP:*' }) -replace '^BACKUP:'
            }
        }
    }

    BeforeEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    AfterEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    It 'Should enable the privileges when the module setting EnablePrivileges is $true' -Skip:(-not $holdsPrivileges) {
        Get-BackupPrivilegeState | Should -Be 'Disabled'

        $result = Invoke-StartScript -ScriptName 'NTFSSecurity.Init.ps1' -Setting $true

        $result.Backup | Should -Be 'Enabled'
        $result.Announced | Should -Be 'True'
    }

    It 'Should leave the privileges disabled when the module setting EnablePrivileges is $false' -Skip:(-not $holdsPrivileges) {
        Get-BackupPrivilegeState | Should -Be 'Disabled'

        $result = Invoke-StartScript -ScriptName 'NTFSSecurity.Init.ps1' -Setting $false

        $result.Backup | Should -Be 'Disabled'
        $result.Announced | Should -Be 'False'
    }

    It 'Should enable the privileges in a script of another name also when the module setting EnablePrivileges is $false' -Skip:(-not $holdsPrivileges) {
        Get-BackupPrivilegeState | Should -Be 'Disabled'

        $result = Invoke-StartScript -ScriptName 'Other.ps1' -Setting $false

        $result.Backup | Should -Be 'Enabled'
        $result.Announced | Should -Be 'True'
    }
}

Describe 'Privileges that another command in the pipeline changes' {
    BeforeAll {
        $privateData['EnablePrivileges'] = $true
        $files = 1..3 | ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name "Changed$_" }

        function Disable-TakeOwnershipOnce {
            # Passes the objects on and disables the Take Ownership privilege when the first one passes, as another
            # command in the pipeline can. Records the state of the Backup privilege at that moment.
            param (
                [Parameter(ValueFromPipeline)]
                [object]
                $InputObject,

                [Parameter(Mandatory)]
                [AllowEmptyCollection()]
                [System.Collections.Generic.List[string]]
                $BackupState
            )

            begin {
                $first = $true
            }

            process {
                if ($first) {
                    $BackupState.Add((Get-BackupPrivilegeState))
                    $null = [ProcessPrivileges.ProcessExtensions]::DisablePrivilege(
                        [System.Diagnostics.Process]::GetCurrentProcess(), [ProcessPrivileges.Privilege]::TakeOwnership
                    )
                    $first = $false
                }

                $InputObject
            }
        }
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $enablePrivileges
    }

    BeforeEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    AfterEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    # Before 5.0.0-rc6, a cmdlet decided which privileges to disable on the states that it had read when it enabled
    # them. A privilege that another command had disabled since then stopped it with "Priviledge already disabled",
    # and the privileges after that one in its list stayed enabled.
    It 'Should disable the other privileges when another command disabled one of them' -Skip:(-not $holdsPrivileges) {
        $backupState = New-Object -TypeName 'System.Collections.Generic.List[string]'

        { Get-NTFSOwner -Path $files | Disable-TakeOwnershipOnce -BackupState $backupState | Out-Null } | Should -Not -Throw

        $backupState | Should -Be 'Enabled'
        Get-EnabledFileSystemPrivilege | Should -BeNullOrEmpty
    }

    It 'Should disable the other privileges when another command disabled one of them and the pipeline stops early' -Skip:(-not $holdsPrivileges) {
        $backupState = New-Object -TypeName 'System.Collections.Generic.List[string]'

        Get-NTFSOwner -Path $files | Disable-TakeOwnershipOnce -BackupState $backupState | Select-Object -First 1 | Out-Null

        $backupState | Should -Be 'Enabled'
        Get-EnabledFileSystemPrivilege | Should -BeNullOrEmpty
    }

    It 'Should not fail when Disable-Privileges runs inside the pipeline' -Skip:(-not $holdsPrivileges) {
        {
            Get-NTFSOwner -Path $files |
                ForEach-Object -Process { Disable-Privileges -WarningAction SilentlyContinue; $_ } |
                Out-Null
        } | Should -Not -Throw

        Get-EnabledFileSystemPrivilege | Should -BeNullOrEmpty
    }
}

# The library class of the module that the cmdlets leave unused; the tests change only the privileges of the test process.
Describe 'The PrivilegeEnabler class' {
    BeforeAll {
        $privateData['EnablePrivileges'] = $false
        $backup = [ProcessPrivileges.Privilege]::Backup
        $changeNotify = [ProcessPrivileges.Privilege]::ChangeNotify
        $currentProcess = [System.Diagnostics.Process]::GetCurrentProcess()

        # The enabler goes out of scope in the function, so that nothing but the caller's handle refers to what it owns.
        function New-AbandonedHandle {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only creates an object.'
            )]
            param ($Process)

            $enabler = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $Process
            $field = [ProcessPrivileges.PrivilegeEnabler].GetField('accessTokenHandle', [System.Reflection.BindingFlags] 'NonPublic, Instance')
            $field.GetValue($enabler)
        }
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $enablePrivileges
    }

    BeforeEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    AfterEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    It 'Should enable a disabled privilege until it is disposed' -Skip:(-not $holdsPrivileges) {
        Get-BackupPrivilegeState | Should -Be 'Disabled'

        $enabler = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $currentProcess, $backup
        try {
            Get-BackupPrivilegeState | Should -Be 'Enabled'
        }
        finally {
            $enabler.Dispose()
        }

        Get-BackupPrivilegeState | Should -Be 'Disabled'
        $enabler.Dispose()
        Get-BackupPrivilegeState | Should -Be 'Disabled'
    }

    It 'Should report a privilege that it modified once and leave it to the instance that enabled it' -Skip:(-not $holdsPrivileges) {
        $first = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $currentProcess
        $second = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $currentProcess
        try {
            $first.EnablePrivilege($backup) | Should -Be 'PrivilegeModified'
            Get-BackupPrivilegeState | Should -Be 'Enabled'
            $first.EnablePrivilege($backup) | Should -Be 'None'
            $second.EnablePrivilege($backup) | Should -Be 'None'
            $second.Dispose()
            Get-BackupPrivilegeState | Should -Be 'Enabled'
        }
        finally {
            $first.Dispose()
            $second.Dispose()
        }

        Get-BackupPrivilegeState | Should -Be 'Disabled'
    }

    It 'Should not disable a privilege that was enabled before' -Skip:(-not $holdsPrivileges) {
        $null = [ProcessPrivileges.ProcessExtensions]::EnablePrivilege($currentProcess, $backup)

        $enabler = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $currentProcess, $backup
        try {
            $enabler.EnablePrivilege($backup) | Should -Be 'None'
        }
        finally {
            $enabler.Dispose()
        }

        Get-BackupPrivilegeState | Should -Be 'Enabled'
    }

    It 'Should enable a privilege through an access token handle that the caller owns' -Skip:(-not $holdsPrivileges) {
        $rights = [ProcessPrivileges.TokenAccessRights]::AdjustPrivileges -bor [ProcessPrivileges.TokenAccessRights]::Query
        $handle = [ProcessPrivileges.ProcessExtensions]::GetAccessTokenHandle($currentProcess, $rights)
        $enabler = $null
        try {
            $enabler = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $handle, $backup
            Get-BackupPrivilegeState | Should -Be 'Enabled'
            $enabler.Dispose()
            $enabler = $null

            Get-BackupPrivilegeState | Should -Be 'Disabled'
            $handle.IsClosed | Should -BeFalse
        }
        finally {
            # The enabler first: a handle that is closed under an enabler that still owns a privilege fails when the
            # enabler disables the privilege.
            if ($enabler) {
                $enabler.Dispose()
            }
            $handle.Dispose()
        }

        $handle.IsClosed | Should -BeTrue
    }

    # The finalizer closes the token handle that an abandoned enabler opened and drops its registration, so that the next
    # enabler for the process opens a handle of its own instead of taking a closed one. The handle is private, so the test
    # reads it by reflection. An enabler that enabled a privilege stays referenced by a static list until it is disposed,
    # so it is never finalized and its privilege stays enabled; only an enabler without a privilege can be abandoned.
    It 'Should close the token handle of an enabler that was never disposed when it is finalized' {
        $handle = New-AbandonedHandle -Process $currentProcess
        $handle.IsClosed | Should -BeFalse

        for ($attempt = 0; $attempt -lt 10 -and -not $handle.IsClosed; $attempt++) {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
        }

        $handle.IsClosed | Should -BeTrue
        $enabler = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $currentProcess
        try {
            $enabler.EnablePrivilege($changeNotify) | Should -Be 'None'
        }
        finally {
            $enabler.Dispose()
        }
    }

    # The access tokens of administrators don't hold the privilege to create a token, and those of basic users don't hold
    # most of the others.
    It 'Should leave a privilege that the access token does not hold alone' {
        $removed = [ProcessPrivileges.Privilege]::CreateToken
        [ProcessPrivileges.ProcessExtensions]::GetPrivilegeState($currentProcess, $removed) | Should -Be 'Removed'

        $enabler = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $currentProcess
        try {
            $enabler.EnablePrivilege($removed) | Should -Be 'None'
        }
        finally {
            $enabler.Dispose()
        }

        [ProcessPrivileges.ProcessExtensions]::GetPrivilegeState($currentProcess, $removed) | Should -Be 'Removed'
    }

    # The enabled flag decides first, then the removed flag; the attributes are not a flags enumeration in .NET.
    It 'Should derive the state <Expected> from the attribute value <Value>' -ForEach @(
        @{ Value = 0; Expected = 'Disabled' }
        @{ Value = 1; Expected = 'Disabled' }
        @{ Value = 2; Expected = 'Enabled' }
        @{ Value = 3; Expected = 'Enabled' }
        @{ Value = 4; Expected = 'Removed' }
        @{ Value = 6; Expected = 'Enabled' }
        @{ Value = -2147483648; Expected = 'Disabled' }
    ) {
        $attributes = [Enum]::ToObject([ProcessPrivileges.PrivilegeAttributes], $Value)

        [ProcessPrivileges.ProcessExtensions]::GetPrivilegeState($attributes) | Should -Be $Expected
    }
}

# Every access token holds the privilege to bypass traverse checking, enabled. The tests use it because they need no other
# privilege and change nothing: a handle that lacks a right fails before it adjusts anything.
Describe 'The access token handle of a process' {
    BeforeAll {
        $currentProcess = [System.Diagnostics.Process]::GetCurrentProcess()
        $changeNotify = [ProcessPrivileges.Privilege]::ChangeNotify
        $tokenRights = [ProcessPrivileges.TokenAccessRights]
    }

    It 'Should open a handle with all access rights when the caller names none and close it on dispose' {
        $handle = [ProcessPrivileges.ProcessExtensions]::GetAccessTokenHandle($currentProcess)
        try {
            $handle.IsInvalid | Should -BeFalse
            @([ProcessPrivileges.ProcessExtensions]::GetPrivileges($handle)) | Should -Not -BeNullOrEmpty
            [ProcessPrivileges.ProcessExtensions]::GetPrivilegeState($handle, $changeNotify) | Should -Be 'Enabled'
        }
        finally {
            $handle.Dispose()
        }

        $handle.IsClosed | Should -BeTrue
    }

    It 'Should refuse to enable a privilege through a handle that may only query' {
        $handle = [ProcessPrivileges.ProcessExtensions]::GetAccessTokenHandle($currentProcess, $tokenRights::Query)
        try {
            $failure = { [ProcessPrivileges.ProcessExtensions]::EnablePrivilege($handle, $changeNotify) } | Should -Throw -PassThru

            $failure.Exception.InnerException | Should -BeOfType [System.ComponentModel.Win32Exception]
            $failure.Exception.InnerException.NativeErrorCode | Should -Be 5
            [ProcessPrivileges.ProcessExtensions]::GetPrivilegeState($handle, $changeNotify) | Should -Be 'Enabled'
        }
        finally {
            $handle.Dispose()
        }
    }

    It 'Should refuse to <Operation> through a handle that may only adjust privileges' -ForEach @(
        @{ Operation = 'list the privileges' }
        @{ Operation = 'read the state of a privilege' }
    ) {
        $handle = [ProcessPrivileges.ProcessExtensions]::GetAccessTokenHandle($currentProcess, $tokenRights::AdjustPrivileges)
        try {
            $failure = {
                if ($Operation -eq 'list the privileges') {
                    [ProcessPrivileges.ProcessExtensions]::GetPrivileges($handle)
                }
                else {
                    [ProcessPrivileges.ProcessExtensions]::GetPrivilegeState($handle, $changeNotify)
                }
            } | Should -Throw -PassThru

            $failure.Exception.InnerException | Should -BeOfType [System.ComponentModel.Win32Exception]
            $failure.Exception.InnerException.NativeErrorCode | Should -Be 5
        }
        finally {
            $handle.Dispose()
        }
    }
}

Describe 'The PrivilegeControl class' {
    BeforeAll {
        $privateData['EnablePrivileges'] = $false
        $control = New-Object -TypeName 'Security2.PrivilegeControl'
        $backup = [ProcessPrivileges.Privilege]::Backup
    }

    AfterAll {
        $privateData['EnablePrivileges'] = $enablePrivileges
    }

    BeforeEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    AfterEach {
        Disable-Privileges -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    It 'Should refuse to <Operation> a privilege that the access token does not hold' -ForEach @(
        @{ Operation = 'enable' }
        @{ Operation = 'disable' }
    ) {
        $failure = {
            if ($Operation -eq 'enable') {
                $control.EnablePrivilege([ProcessPrivileges.Privilege]::CreateToken)
            }
            else {
                $control.DisablePrivilege([ProcessPrivileges.Privilege]::CreateToken)
            }
        } | Should -Throw -PassThru

        $failure.Exception.InnerException | Should -BeOfType [System.Security.AccessControl.PrivilegeNotHeldException]
        $failure.Exception.InnerException.PrivilegeName | Should -BeExactly 'CreateToken'
    }

    It 'Should enable and disable a held privilege and refuse to repeat either' -Skip:(-not $holdsPrivileges) {
        Get-BackupPrivilegeState | Should -Be 'Disabled'
        $failure = { $control.DisablePrivilege($backup) } | Should -Throw -PassThru
        $failure.Exception.InnerException | Should -BeOfType [Security2.AdjustPriviledgeException]
        $failure.Exception.InnerException.Message | Should -BeExactly 'Priviledge already disabled'

        $control.EnablePrivilege($backup) | Should -Be 'PrivilegeModified'
        Get-BackupPrivilegeState | Should -Be 'Enabled'
        $failure = { $control.EnablePrivilege($backup) } | Should -Throw -PassThru
        $failure.Exception.InnerException | Should -BeOfType [Security2.AdjustPriviledgeException]
        $failure.Exception.InnerException.Message | Should -BeExactly 'Priviledge already enabled'

        $control.DisablePrivilege($backup) | Should -Be 'PrivilegeModified'
        Get-BackupPrivilegeState | Should -Be 'Disabled'
    }
}
