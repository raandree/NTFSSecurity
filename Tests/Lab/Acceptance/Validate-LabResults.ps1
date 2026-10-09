[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $ResultsFolder,
    [Parameter(Mandatory)] [string] $OutputPrefix,
    [string[]] $Edition = @('Desktop', 'Core'),
    [ValidateSet('Candidate', 'Baseline')] [string] $Expect = 'Candidate'
)

# Validates one controller result folder: every edition and role has exactly one result, and for a candidate no test failed
# and every exit code is 0. It writes the counts per role, every test with its result (from the result files of the roles,
# not from the counts), and the failures with their full names and messages. A Desktop ConvertFrom-Json wraps an array in
# one object, so each JSON array is enumerated explicitly. -File passes an array as one string.
$ErrorActionPreference = 'Stop'
$Edition = @($Edition | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
$summary = @(Get-Content -LiteralPath (Join-Path -Path $ResultsFolder -ChildPath 'Summary.json') -Raw | ConvertFrom-Json | ForEach-Object -Process { $_ })
$roles = 'Delegate', 'ServerAdmin', 'Admin', 'Server'
$expected = @(foreach ($name in $Edition) { foreach ($role in $roles) { '{0}:{1}' -f $name, $role } })
$actual = @($summary | ForEach-Object -Process { '{0}:{1}' -f $_.Edition, $_.Role })
$problems = New-Object -TypeName 'System.Collections.Generic.List[string]'
foreach ($identity in $expected) {
    $count = @($actual | Where-Object -FilterScript { $_ -eq $identity }).Count
    if ($count -ne 1) { $problems.Add("$identity has $count results instead of 1") }
}

if ($summary.Count -ne $expected.Count) { $problems.Add("The summary has $($summary.Count) results instead of $($expected.Count)") }
$counts = foreach ($entry in $summary) {
    [pscustomobject]@{
        Version = $entry.Version; Edition = $entry.Edition; Role = $entry.Role; Account = $entry.Account; ExitCode = $entry.ExitCode
        Passed = $entry.Passed; Failed = $entry.Failed; Skipped = $entry.Skipped
    }
}

$tests = New-Object -TypeName 'System.Collections.Generic.List[object]'
foreach ($file in Get-ChildItem -LiteralPath $ResultsFolder -Filter '*.result.json') {
    $baseName = $file.Name -replace '\.result\.json$', ''
    $role = ($baseName -split '-')[-1]
    $resultEdition = if ($baseName -match '-(Desktop|Core)-') { $Matches[1] } else { '' }
    foreach ($case in @(Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json | ForEach-Object -Process { $_ })) {
        $tests.Add([pscustomobject]@{ Edition = $resultEdition; Role = $role; Test = $case.Name; Result = $case.Result; Message = (($case.Message -split '\r?\n')[0]) })
    }
}

$failures = @($tests | Where-Object -FilterScript { $_.Result -eq 'Failed' })
if ($Expect -eq 'Candidate') {
    foreach ($row in $counts) {
        if ($row.ExitCode -ne 0 -or $row.Failed -ne 0 -or $row.Passed -eq 0) { $problems.Add("$($row.Edition) $($row.Role): exit code $($row.ExitCode), $($row.Passed) passed, $($row.Failed) failed") }
    }

    if ($failures.Count -gt 0) { $problems.Add("$($failures.Count) failed tests in the result files") }
}

$counts | Export-Csv -LiteralPath ($OutputPrefix + '-counts.csv') -NoTypeInformation -Encoding utf8
$tests | Export-Csv -LiteralPath ($OutputPrefix + '-tests.csv') -NoTypeInformation -Encoding utf8
$failures | Export-Csv -LiteralPath ($OutputPrefix + '-failures.csv') -NoTypeInformation -Encoding utf8
foreach ($editionName in $Edition) {
    $selected = @($counts | Where-Object -FilterScript { $_.Edition -eq $editionName })
    '{0}: passed={1}, failed={2}, skipped={3}' -f $editionName, ($selected.Passed | Measure-Object -Sum).Sum, ($selected.Failed | Measure-Object -Sum).Sum, ($selected.Skipped | Measure-Object -Sum).Sum
}

$counts | Format-Table -AutoSize | Out-String -Width 200
'tests in the result files: {0}; failed: {1}; skipped: {2}' -f $tests.Count, $failures.Count, @($tests | Where-Object -FilterScript { $_.Result -eq 'Skipped' }).Count
if ($problems.Count -gt 0) {
    $problems | ForEach-Object -Process { 'PROBLEM: ' + $_ }
    'LIVE_RESULT_NOT_ACCEPTED'
    exit 1
}

'LIVE_RESULT_VERIFIED ({0})' -f $Expect
