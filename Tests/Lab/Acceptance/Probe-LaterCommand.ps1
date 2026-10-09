[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester passes the data to the blocks of the container.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'The tests read the variables that BeforeAll sets.')]
[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $ModulePath,
    [Parameter(Mandatory)] [string] $OutFile,
    [string] $PesterPath = 'V:\Git\WindowsAccessControl\output\RequiredModules\Pester\5.7.1'
)

# Diagnostic of the acceptance in Acceptance-2026-10-09-quality-gate-paths.md, not part of it: why do the Select-Object rows of case 10
# fail on the base of the branch without a message? It runs the bodies of those tests (Assert-LabPipelineStop and
# Assert-LabDownstreamFailure of NTFSSecurity.Live.Tests.ps1) against files in a new folder below TEMP, with the settings of the
# runner (Pester 5.7.1, ErrorActionPreference Stop, detailed plain text), and lists for each test its result and error records, and
# the state of the items afterwards. One module build in one edition per process, never imported into another session; the script
# removes its own folder at the end after it has checked the path. Windows only. For example:
#   powershell.exe -NoProfile -File Probe-LaterCommand.ps1 -ModulePath <folder with NTFSSecurity.psd1> -OutFile <result.txt>
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path -Path $PesterPath -ChildPath 'Pester.psd1') -Force
$root = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('mute-probe-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$account = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$lines = New-Object -TypeName 'System.Collections.Generic.List[string]'
try {
    $container = New-PesterContainer -ScriptBlock {
        param ($ModulePath, $Root, $Account)
        BeforeAll {
            Import-Module -Name (Join-Path -Path $ModulePath -ChildPath 'NTFSSecurity.psd1') -Force -ErrorAction Stop
            $everyone = 'S-1-1-0'
            $administrators = 'S-1-5-32-544'
            $privateData = (Get-Module -Name NTFSSecurity).PrivateData
            $privateData['EnablePrivileges'] = $false
            $account = $Account

            function Get-ProbeOwner {
                param ([string] $Path)
                (Get-Acl -LiteralPath $Path).GetOwner([System.Security.Principal.SecurityIdentifier]).Value
            }

            function New-ProbeFolder {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Helper that writes only to the folder of this run.'
                )]
                param ([string] $Name)
                $path = Join-Path -Path $Root -ChildPath $Name
                $null = New-Item -ItemType Directory -Path $path -Force
                $path
            }

            function New-ProbePair {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Helper that writes only to the folder of this run.'
                )]
                param ([string] $Name)
                $directory = New-ProbeFolder -Name $Name
                foreach ($item in 'First', 'Second') {
                    Set-Content -LiteralPath (Join-Path -Path $directory -ChildPath "$item.txt") -Value $item -NoNewline
                }

                @{ Directory = $directory; First = (Join-Path -Path $directory -ChildPath 'First.txt'); Second = (Join-Path -Path $directory -ChildPath 'Second.txt') }
            }

            $cases = @{
                'Remove-Item2'               = @{
                    Prepare   = { param ($Slug) New-ProbePair -Name "RemoveItem2-$Slug" }
                    Run       = { param ($Context) Remove-Item2 -Path $Context.First, $Context.Second -PassThru -ErrorAction SilentlyContinue }
                    Untouched = { param ($Context) Test-Path -LiteralPath $Context.Second }
                }
                'Copy-Item2'                 = @{
                    Prepare   = { param ($Slug) $c = New-ProbePair -Name "CopyItem2-$Slug"; $c.Destination = New-ProbeFolder -Name "CopyItem2-$Slug-To"; $c }
                    Run       = { param ($Context) Copy-Item2 -Path $Context.First, $Context.Second -Destination $Context.Destination -PassThru $true -ErrorAction SilentlyContinue }
                    Untouched = { param ($Context) -not (Test-Path -LiteralPath (Join-Path -Path $Context.Destination -ChildPath 'Second.txt')) }
                }
                'Move-Item2'                 = @{
                    Prepare   = { param ($Slug) $c = New-ProbePair -Name "MoveItem2-$Slug"; $c.Destination = New-ProbeFolder -Name "MoveItem2-$Slug-To"; $c }
                    Run       = { param ($Context) Move-Item2 -Path $Context.First, $Context.Second -Destination $Context.Destination -PassThru $true -ErrorAction SilentlyContinue }
                    Untouched = { param ($Context) Test-Path -LiteralPath $Context.Second }
                }
                'Set-NTFSOwner'              = @{
                    Prepare   = { param ($Slug) New-ProbePair -Name "SetOwner-$Slug" }
                    Run       = { param ($Context) Set-NTFSOwner -Path $Context.First, $Context.Second -Account $account -PassThru -ErrorAction SilentlyContinue }
                    Untouched = { param ($Context) (Get-ProbeOwner -Path $Context.Second) -eq $administrators }
                }
                'Set-NTFSSecurityDescriptor' = @{
                    Prepare   = {
                        param ($Slug)
                        $c = New-ProbePair -Name "SetDescriptor-$Slug"
                        $c.Descriptors = @(Get-NTFSSecurityDescriptor -Path $c.First, $c.Second -ErrorAction Stop)
                        Add-NTFSAccess -SecurityDescriptor $c.Descriptors -Account $everyone -AccessRights ReadData -ErrorAction Stop
                        $c
                    }
                    Run       = { param ($Context) Set-NTFSSecurityDescriptor -SecurityDescriptor $Context.Descriptors -PassThru -ErrorAction SilentlyContinue }
                    Untouched = { param ($Context) -not (@((Get-Acl -LiteralPath $Context.Second).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $everyone }).Count) }
                }
            }
            $streamCases = @{
                'Set-NTFSSecurityDescriptor/verbose' = @{
                    Prepare    = $cases['Set-NTFSSecurityDescriptor'].Prepare
                    Run        = { param ($Context) Set-NTFSSecurityDescriptor -SecurityDescriptor $Context.Descriptors -Verbose -ErrorAction SilentlyContinue 4>&1 }
                    Untouched  = $cases['Set-NTFSSecurityDescriptor'].Untouched
                    RecordType = [System.Management.Automation.VerboseRecord]
                }
                'Set-NTFSOwner/debug'                = @{
                    Prepare    = $cases['Set-NTFSOwner'].Prepare
                    Run        = { param ($Context) Set-NTFSOwner -Path $Context.First, $Context.Second -Account $account -ErrorAction SilentlyContinue 5>&1 }
                    Untouched  = $cases['Set-NTFSOwner'].Untouched
                    RecordType = [System.Management.Automation.DebugRecord]
                }
            }

            function Assert-ProbePipelineStop {
                param ([hashtable] $Case, [string] $Slug, [string] $Stream)

                if ($Stream -eq 'debug') { $DebugPreference = 'Continue' }
                $context = & $Case.Prepare $Slug
                $Error.Clear()

                $result = @(& $Case.Run $context | Select-Object -First 1)

                $result | Should -HaveCount 1
                if ($Case.RecordType) {
                    $result[0] | Should -BeOfType $Case.RecordType
                }

                $Error.Count | Should -Be 0
                if ($Case.Untouched) {
                    (& $Case.Untouched $context) | Should -BeTrue
                }
            }

            function Assert-ProbeDownstreamFailure {
                param ([hashtable] $Case, [string] $Slug, [string] $Stream)

                if ($Stream -eq 'debug') { $DebugPreference = 'Continue' }
                $context = & $Case.Prepare $Slug
                $emitted = 0
                $caught = $null
                $Error.Clear()
                try {
                    & $Case.Run $context | ForEach-Object -Process {
                        $emitted++
                        throw 'Downstream failure'
                    }
                }
                catch {
                    $caught = $_
                }

                $caught.Exception.Message | Should -BeLike '*Downstream failure*'
                $emitted | Should -Be 1
                @($Error | Where-Object -FilterScript { $_.Exception.Message -notlike '*Downstream failure*' }) | Should -BeNullOrEmpty
                if ($Case.Untouched) {
                    (& $Case.Untouched $context) | Should -BeTrue
                }
            }
        }

        Describe 'Mirror of the later-command tests' {
            It '<Name> should stop after the first object for Select-Object -First 1' -ForEach @(
                @{ Name = 'Remove-Item2' }, @{ Name = 'Copy-Item2' }, @{ Name = 'Move-Item2' }, @{ Name = 'Set-NTFSOwner' }, @{ Name = 'Set-NTFSSecurityDescriptor' }
            ) {
                Assert-ProbePipelineStop -Case $cases[$Name] -Slug 'Select'
            }

            It '<Name> should stop after the first object for throw' -ForEach @(
                @{ Name = 'Remove-Item2' }, @{ Name = 'Copy-Item2' }, @{ Name = 'Move-Item2' }, @{ Name = 'Set-NTFSOwner' }, @{ Name = 'Set-NTFSSecurityDescriptor' }
            ) {
                Assert-ProbeDownstreamFailure -Case $cases[$Name] -Slug 'Throw'
            }

            It '<Key> should stop at the message for Select-Object -First 1' -ForEach @(
                @{ Key = 'Set-NTFSSecurityDescriptor/verbose'; Stream = 'verbose' }, @{ Key = 'Set-NTFSOwner/debug'; Stream = 'debug' }
            ) {
                Assert-ProbePipelineStop -Case $streamCases[$Key] -Slug ('{0}Select' -f $Stream) -Stream $Stream
            }
        }
    } -Data @{ ModulePath = $ModulePath; Root = $root; Account = $account }

    $configuration = New-PesterConfiguration
    $configuration.Run.Container = $container
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'Detailed'
    $configuration.Output.RenderMode = 'Plaintext'
    $lines.Add(('Edition {0} {1}; module {2}' -f $PSVersionTable.PSEdition, $PSVersionTable.PSVersion, $ModulePath))
    $lines.Add('--- Pester output')
    $output = & { Invoke-Pester -Configuration $configuration } *>&1
    $result = @($output | Where-Object -FilterScript { $_ -is [Pester.Run] }) | Select-Object -First 1
    foreach ($entry in @($output | Where-Object -FilterScript { $_ -isnot [Pester.Run] })) { $lines.Add('{0}' -f $entry) }
    $lines.Add('--- Results')
    foreach ($test in $result.Tests) {
        $messages = @(@($test.ErrorRecord) | Where-Object -FilterScript { $_ } | ForEach-Object -Process { ($_.ToString() -split '\r?\n')[0] })
        $lines.Add(('{0} | {1} | error records: {2} | {3}' -f $test.Result, $test.ExpandedName, @($test.ErrorRecord).Count, ($messages -join ' // ')))
    }

    $lines.Add(('Totals: passed {0}, failed {1}, not run {2}; result {3}' -f $result.PassedCount, $result.FailedCount, $result.NotRunCount, $result.Result))
    $lines.Add('--- State of the items after the run')
    foreach ($folder in Get-ChildItem -LiteralPath $root -Directory | Sort-Object -Property Name) {
        $files = @(Get-ChildItem -LiteralPath $folder.FullName -File | ForEach-Object -Process { $_.Name })
        $lines.Add(('{0}: {1}' -f $folder.Name, ($files -join ', ')))
    }

    $lines.Add('--- Owner (SetOwner folders) and explicit entry for Everyone (SetDescriptor folders) after the run')
    foreach ($folder in Get-ChildItem -LiteralPath $root -Directory | Where-Object -FilterScript { $_.Name -like 'SetOwner-*' -or $_.Name -like 'SetDescriptor-*' } | Sort-Object -Property Name) {
        foreach ($name in 'First.txt', 'Second.txt') {
            $path = Join-Path -Path $folder.FullName -ChildPath $name
            $acl = Get-Acl -LiteralPath $path
            if ($folder.Name -like 'SetOwner-*') {
                $owner = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
                $lines.Add(('{0}\{1}: owner {2}' -f $folder.Name, $name, $(if ($owner -eq 'S-1-5-32-544') { 'Administrators (as created)' } elseif ($owner -eq $account) { 'the account of the run (changed)' } else { $owner })))
            }
            else {
                $entries = @($acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
                $lines.Add(('{0}\{1}: explicit entry for Everyone: {2}' -f $folder.Name, $name, $(if ($entries.Count) { 'yes (changed)' } else { 'no (as created)' })))
            }
        }
    }
}
finally {
    $full = [System.IO.Path]::GetFullPath($root)
    if ($full.StartsWith([System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()), [System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Path $full -Leaf) -like 'mute-probe-*') {
        Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
    }

    Set-Content -LiteralPath $OutFile -Value $lines -Encoding utf8
}
