<#
    Tests how the cmdlets of the module built in NTFSSecurity\bin\Release behave when a later command in the pipeline
    ends it: a break or continue in a script block, or Select-Object -First. The exception that carries it passes through
    the cmdlet while it writes an object. A catch for the failures of an item must not report it as an error of that item
    and go on with the next one: a cmdlet that removes, copies, moves, or changes items would change them all, although
    the caller ended the pipeline. Every test works on files and folders in a sandbox.
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
}
