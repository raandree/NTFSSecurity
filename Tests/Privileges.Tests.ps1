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
        $currentProcess = [System.Diagnostics.Process]::GetCurrentProcess()
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
        try {
            $enabler = New-Object -TypeName 'ProcessPrivileges.PrivilegeEnabler' -ArgumentList $handle, $backup
            Get-BackupPrivilegeState | Should -Be 'Enabled'
            $enabler.Dispose()

            Get-BackupPrivilegeState | Should -Be 'Disabled'
            $handle.IsClosed | Should -BeFalse
        }
        finally {
            $handle.Dispose()
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
