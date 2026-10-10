[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $Timeline,
    [ValidateRange(1, 60)] [double] $FromMinutes = 3,
    [ValidateRange(1, 60)] [double] $ToMinutes = 16,
    [ValidateRange(0.01, 5)] [double] $StepMinutes = 0.25,
    [ValidateRange(1, 60)] [double] $Lifetime,
    [ValidateRange(0, 100000)] [int] $Permutations = 0,
    [switch] $AsIfSameSubject,
    [switch] $ShowMismatches
)

# Replays the Admin roles of a timeline (Export-CellTimeline.ps1) against a model of the failures that the effective-access tests of the Admin role showed in
# the cells of the operating-system matrix (Decision 24). The model is a description of the observations, not an explanation of Windows:
#
#   A remote authorization manager (the one of the client for the default -ServerName, the one of the file server for its own name) computes the groups of an
#   account at the first request for the account name and answers from that result for L minutes, also when the account was deleted and created again under
#   the same name in the meantime, with a new SID and new group memberships. The answer then has no access through the groups (0x100000, Synchronize only).
#
# For each L from -FromMinutes to -ToMinutes, the script walks the Admin roles in time order, keeps one entry per computer and account name, and predicts
# whether the first (file server) and the second (client) test pass: a test passes when no entry that is younger than L minutes and was made for another
# account instance exists. It reports how many of the observed outcomes each L predicts. A fit says that the position of a cell in the sequence is enough to
# explain the failures, whichever module was under test; it doesn't say how Windows does it, or that the lifetime is a constant. A run whose account name is
# new always passes, which is what the controller relies on since 1dec389. It reads files only; Windows PowerShell 5.1 or PowerShell 7.
#
# -Lifetime L lists every run with the observed and the predicted outcome of both tests for that one L instead of searching for the best L. -AsIfSameSubject
# gives every run the same account name: for the cells of a controller that gives each fixture a new name (rc7l and later), the listing then shows where a
# controller that reuses the name would have met a stale entry. -Permutations N asks how often a random assignment of the observed outcomes to the runs
# (the same number of failures, a fixed random seed) reaches the best agreement of the real outcomes for some L: if the position of a cell decides the
# outcome, it should almost never.
#
# The lifetimes are those of a grid with the step -StepMinutes, so a range is known to within one step (use 0.05 to see the ranges of the record). The model
# doesn't know that a computer restarted. If the state lives in the memory of the computer, a restart would clear it; for the real account names of the series
# of Decision 24, no restart of the client or of a file server changes a prediction (the entry that a restart would have cleared had expired, or the run that
# read it had the same account). For -AsIfSameSubject it matters once: the client restarted between ab6 and ab7.
$ErrorActionPreference = 'Stop'
$random = New-Object -TypeName 'System.Random' -ArgumentList 20261010
$rows = @(Import-Csv -LiteralPath $Timeline | ForEach-Object -Process {
        [pscustomobject]@{
            Time      = [DateTime]::ParseExact($_.AdminRoleStarted, 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
            Run       = $_.Run
            Candidate = $_.Candidate
            Server    = $_.FileServer
            Edition   = $_.Edition
            Subject   = if ($AsIfSameSubject) { 'one name' } else { $_.Subject }
            Sid       = $_.SubjectRid
            Test1     = $_.T1ServerNameFileServer -like 'pass*'
            Test2     = $_.T2DefaultServerName -like 'pass*'
        }
    } | Sort-Object -Property Time)

function Test-Model {
    param ([double] $Minutes, [ValidateSet('Test1', 'Test2')] [string] $Test)

    $entries = @{}
    $mismatch = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $predictions = New-Object -TypeName 'System.Collections.Generic.List[bool]'
    $agree = 0
    foreach ($row in $rows) {
        $scope = if ($Test -eq 'Test2') { 'client|' + $row.Subject } else { $row.Server + '|' + $row.Subject }
        $entry = $entries[$scope]
        if ($entry -and ($row.Time - $entry.Created).TotalMinutes -lt $Minutes) {
            $predicted = $entry.Sid -eq $row.Sid
        }
        else {
            $entries[$scope] = @{ Created = $row.Time; Sid = $row.Sid }
            $predicted = $true
        }

        $predictions.Add($predicted)
        $observed = $row.$Test
        if ($predicted -eq $observed) {
            $agree++
        }
        else {
            $mismatch.Add(('{0:HH:mm} {1} {2} {3} [{4}]: observed {5}, model {6}' -f $row.Time, $row.Run, $row.Server, $row.Edition, $row.Candidate,
                    $(if ($observed) { 'pass' } else { 'FAIL' }), $(if ($predicted) { 'pass' } else { 'FAIL' })))
        }
    }

    [pscustomobject]@{ Minutes = $Minutes; Agree = $agree; Mismatch = $mismatch; Predictions = $predictions }
}

if ($PSBoundParameters.ContainsKey('Lifetime')) {
    $first = Test-Model -Minutes $Lifetime -Test Test1
    $second = Test-Model -Minutes $Lifetime -Test Test2
    $word = { param ($Passed) if ($Passed) { 'pass' } else { 'FAIL' } }
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $row = $rows[$index]
        [pscustomobject]@{
            Time        = $row.Time.ToString('MM-dd HH:mm:ss')
            Run         = $row.Run
            Server      = $row.Server
            Edition     = $row.Edition
            Candidate   = $row.Candidate
            Subject     = $row.Subject
            Test1       = & $word $row.Test1
            Test1Model  = & $word $first.Predictions[$index]
            Test2       = & $word $row.Test2
            Test2Model  = & $word $second.Predictions[$index]
        }
    }

    return
}

function Get-Range {
    # The lifetimes of a result list as ranges of the grid: 'a to b', or 'a to b and c to d' when the list has a gap.
    param ([object[]] $Result)

    $segments = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $start = $null
    $last = $null
    foreach ($item in $Result) {
        if ($null -eq $start) {
            $start = $item.Minutes
        }
        elseif ($item.Minutes - $last -gt $StepMinutes * 1.5) {
            $segments.Add(('{0:N2} to {1:N2}' -f $start, $last))
            $start = $item.Minutes
        }

        $last = $item.Minutes
    }

    if ($null -ne $start) { $segments.Add(('{0:N2} to {1:N2}' -f $start, $last)) }
    $segments -join ' and '
}

# Every lifetime is computed from its index, because adding the step again and again drifts and would lose the last grid point of a range.
$grid = @(for ($step = 0; ; $step++) {
        $value = [Math]::Round($FromMinutes + $step * $StepMinutes, 6)
        if ($value -gt $ToMinutes) { break }
        $value
    })
$resultsByTest = @{}
foreach ($test in 'Test1', 'Test2') {
    $results = @(foreach ($minutes in $grid) { Test-Model -Minutes $minutes -Test $test })
    $resultsByTest[$test] = $results
    $best = ($results | Measure-Object -Property Agree -Maximum).Maximum
    $bestResults = @($results | Where-Object -FilterScript { $_.Agree -eq $best })
    $failures = @($rows | Where-Object -FilterScript { -not $_.$test }).Count
    '{0} ({1}): the model predicts {2} of {3} outcomes for L from {4} minutes; {5} runs failed' -f $test,
    $(if ($test -eq 'Test1') { 'the name of the file server' } else { 'the default server name, the client' }), $best, $rows.Count, (Get-Range -Result $bestResults), $failures
    if ($ShowMismatches) { foreach ($line in $bestResults[0].Mismatch) { '    mismatch: ' + $line } }
    if ($Permutations -gt 0) {
        $observed = [bool[]] @($rows | ForEach-Object -Process { $_.$test })
        $reached = 0
        $highest = 0
        for ($shuffle = 0; $shuffle -lt $Permutations; $shuffle++) {
            $shuffled = [bool[]] @($observed | Sort-Object -Property { $random.Next() })
            $agreement = 0
            foreach ($result in $results) {
                $agree = 0
                for ($index = 0; $index -lt $shuffled.Count; $index++) { if ($result.Predictions[$index] -eq $shuffled[$index]) { $agree++ } }
                if ($agree -gt $agreement) { $agreement = $agree }
            }

            if ($agreement -ge $best) { $reached++ }
            if ($agreement -gt $highest) { $highest = $agreement }
        }

        '    {0} of {1} random assignments of the outcomes to the runs reach {2} of {3} for some L; the best of them reaches {4}' -f $reached, $Permutations, $best, $rows.Count, $highest
    }
}

# One lifetime for both tests: the range of L at which the model predicts the most outcomes of the two tests together.
$together = @(for ($index = 0; $index -lt $grid.Count; $index++) {
        [pscustomobject]@{ Minutes = $grid[$index]; Agree = $resultsByTest['Test1'][$index].Agree + $resultsByTest['Test2'][$index].Agree }
    })
$bestTogether = ($together | Measure-Object -Property Agree -Maximum).Maximum
'Both tests with one L: the model predicts {0} of {1} outcomes for L from {2} minutes' -f $bestTogether, (2 * $rows.Count), (Get-Range -Result @($together | Where-Object -FilterScript { $_.Agree -eq $bestTogether }))
