[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $MatrixRoot,
    [Parameter(Mandatory)] [string[]] $Label,
    [Parameter(Mandatory)] [string] $OutputPath
)

# The timeline of the cells of the operating-system matrix (Decision 24): for each cell and edition in which the Admin role ran, in the order in which the
# cells ran, the module under test, the account of case 3 (its name and its relative ID, which tells two accounts of one name apart within a domain),
# whether the previous cell had the same name and the same account, when the previous fixture was removed, when the accounts were created, when the
# Admin role started, the minutes between them, and the three effective-access tests of case 3 in the Admin role (result, milliseconds, and the rights
# that a failing test received). A failing effective-access test of the Admin role is easy to blame on the module or on the environment; this table
# puts it beside the module, the position of the cell in the sequence, and the age of the accounts. Pass every label of a series, also a run that
# stopped before its tests (it writes no row, but it created and removed the accounts, which the next cell reports as the previous removal). The
# times come from the logs of Run-MatrixSequence.ps1 and of the controller (UTC). It reads files only; Windows PowerShell 5.1 or PowerShell 7.
$ErrorActionPreference = 'Stop'
# -File passes an array as one string, so a list may arrive as 'A,B'.
$Label = @($Label | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
function Get-LogTime {
    param ([string[]] $Lines, [string] $Pattern)
    $line = $Lines | Where-Object -FilterScript { $_ -match $Pattern } | Select-Object -First 1
    if ($line -and $line -match '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)Z?\]') {
        [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
    }
}

$cells = New-Object -TypeName 'System.Collections.Generic.List[object]'
foreach ($name in $Label) {
    $sequenceLog = Join-Path -Path $MatrixRoot -ChildPath ('{0}-sequence.log' -f $name)
    if (-not (Test-Path -LiteralPath $sequenceLog)) { continue }
    $candidate = if ((Get-Content -LiteralPath $sequenceLog -TotalCount 1) -match 'candidate-(\w+)') { $Matches[1] } else { '' }
    foreach ($folder in (Get-ChildItem -LiteralPath $MatrixRoot -Directory -Filter ('{0}-*' -f $name))) {
        $runLog = Join-Path -Path $folder.FullName -ChildPath 'run.log'
        if (-not (Test-Path -LiteralPath $runLog)) { continue }
        $run = @(Get-Content -LiteralPath $runLog)
        $removeLog = Join-Path -Path $folder.FullName -ChildPath 'cleanup-2-remove.log'
        $removed = if (Test-Path -LiteralPath $removeLog) { Get-LogTime -Lines @(Get-Content -LiteralPath $removeLog) -Pattern 'Removed the live tests' }
        $configuration = Get-ChildItem -LiteralPath (Join-Path -Path $folder.FullName -ChildPath 'Results') -Recurse -Filter 'local-*.json' -ErrorAction SilentlyContinue |
            Where-Object -FilterScript { $_.Name -match '-\d{14}\.json$' } | Select-Object -First 1
        $subjectName = ''
        $subjectRid = ''
        if ($configuration) {
            $subject = (Get-Content -LiteralPath $configuration.FullName -Raw | ConvertFrom-Json).Accounts.Subject
            $subjectName = $subject.Name
            $subjectRid = ($subject.Sid -split '-')[-1]
        }
        else {
            # A cell that stopped before its tests has no result file, but it created and removed the accounts, so the snapshot of its fixture names them.
            $snapshotLog = Join-Path -Path $folder.FullName -ChildPath 'cleanup-1-snapshot.log'
            $snapshot = if (Test-Path -LiteralPath $snapshotLog) { Get-Content -LiteralPath $snapshotLog -Raw }
            if ($snapshot -match '(?m)^(\w+)\.\S+\s+OU NTFSSecurityLive.*\b(NtfsLiveSubject\w*)=S-[\d-]+-(\d+)') {
                $subjectName = '{0}\{1}' -f $Matches[1], $Matches[2]
                $subjectRid = $Matches[3]
            }
        }

        $cells.Add([pscustomobject]@{
                Run        = $name
                Candidate  = $candidate
                FileServer = $folder.Name.Substring($name.Length + 1)
                Folder     = $folder.FullName
                Lines      = $run
                Subject    = $subjectName
                SubjectRid = $subjectRid
                Started    = Get-LogTime -Lines $run -Pattern 'START live tests'
                Created    = Get-LogTime -Lines $run -Pattern 'Preparing the accounts'
                Removed    = $removed
            })
    }
}

$rows = New-Object -TypeName 'System.Collections.Generic.List[object]'
$previous = $null
foreach ($cell in ($cells | Sort-Object -Property Started)) {
    foreach ($edition in 'Desktop', 'Core') {
        $adminStart = Get-LogTime -Lines $cell.Lines -Pattern "local-$edition-\d+: role Admin$"
        if (-not $adminStart) { continue }
        $tests = @{ T1 = ''; T2 = ''; T3 = '' }
        $failures = 0
        $adminLog = Get-ChildItem -LiteralPath (Join-Path -Path $cell.Folder -ChildPath 'Results') -Recurse -Filter "local-$edition-*-Admin.log" | Select-Object -First 1
        if ($adminLog) {
            $text = @(Get-Content -LiteralPath $adminLog.FullName)
            $start = ($text | Select-String -Pattern 'Describing Get-NTFSEffectiveAccess for a domain account on a share folder' | Select-Object -First 1).LineNumber
            $seen = 0
            for ($index = $start; $start -and $index -lt $text.Count -and $seen -lt 3; $index++) {
                if ($text[$index] -notmatch '^\s+\[([+-])\] (.+?) (\d+(?:\.\d+)?m?s) \(') { continue }
                $outcome = $Matches[1]; $title = $Matches[2]; $duration = $Matches[3]
                $received = ''
                if ($outcome -eq '-') {
                    $failures++
                    for ($next = $index + 1; $next -lt [Math]::Min($index + 12, $text.Count); $next++) {
                        if ($text[$next] -match "But was:\s+'(0x\w+)'") { $received = ' ' + $Matches[1]; break }
                        if ($text[$next] -match 'Expected \$null or empty') { $received = ' errors'; break }
                    }
                }

                $key = if ($title -match 'with -ServerName, without') { 'T1' } elseif ($title -match 'without -ServerName') { 'T2' } else { 'T3' }
                $tests[$key] = '{0} {1}{2}' -f $(if ($outcome -eq '+') { 'pass' } else { 'FAIL' }), $duration, $received
                $seen++
            }
        }

        $hasPrevious = $null -ne $previous -and $null -ne $previous.Removed
        $sameName = $null -ne $previous -and $cell.Subject -and $previous.Subject -eq $cell.Subject
        $rows.Add([pscustomobject][ordered]@{
                Run                       = $cell.Run
                Candidate                 = $cell.Candidate
                FileServer                = $cell.FileServer
                Edition                   = $edition
                Subject                   = $cell.Subject
                SubjectRid                = $cell.SubjectRid
                SameNameAsPreviousCell    = [bool] $sameName
                SameAccountAsPreviousCell = [bool] ($sameName -and $previous.SubjectRid -eq $cell.SubjectRid)
                PreviousRemoval           = $(if ($hasPrevious) { '{0:yyyy-MM-dd HH:mm:ss}' -f $previous.Removed })
                AccountsCreated           = '{0:yyyy-MM-dd HH:mm:ss}' -f $cell.Created
                AdminRoleStarted          = '{0:yyyy-MM-dd HH:mm:ss}' -f $adminStart
                MinutesRemovalToCreation  = $(if ($hasPrevious) { '{0:N1}' -f ($cell.Created - $previous.Removed).TotalMinutes })
                MinutesCreationToAdmin    = '{0:N1}' -f ($adminStart - $cell.Created).TotalMinutes
                MinutesRemovalToAdmin     = $(if ($hasPrevious) { '{0:N1}' -f ($adminStart - $previous.Removed).TotalMinutes })
                T1ServerNameFileServer    = $tests.T1
                T2DefaultServerName       = $tests.T2
                T3UnreachableServerName   = $tests.T3
                EffectiveAccessFailures   = $failures
            })
    }

    $previous = [pscustomobject]@{ Removed = $cell.Removed; Subject = $cell.Subject; SubjectRid = $cell.SubjectRid }
}

$rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding ASCII
'{0} rows for {1} cells written to {2}' -f $rows.Count, $cells.Count, $OutputPath
