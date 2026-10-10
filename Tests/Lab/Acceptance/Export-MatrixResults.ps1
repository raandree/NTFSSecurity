[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $OutputPrefix,
    [string] $MatrixRoot,
    [string] $Label,
    [string[]] $LocalSuiteFolder = @(),
    [string] $ReferenceMachine = 'LOCAL'
)

# Turns the raw results of the operating-system matrix (Decision 24) into the tables of the acceptance record, in Windows PowerShell 5.1.
# -MatrixRoot and -Label name the sequences of Run-MatrixSequence.ps1 (folders <Label>-<file server>): per cell, edition, and role the
# counts, the skipped tests, and the operating systems of the readiness log. -LocalSuiteFolder lists the result folders of
# Run-MatrixLocalSuite.ps1 (folders <label>-<machine> with one JSON file per run): per machine, mode, and edition the counts, and the
# difference of the skipped tests to the reference machine (a skipped test that only one side skips is a difference). Every input file is
# listed with its SHA-256 in <OutputPrefix>-hashes.csv. Nothing is changed in the lab.
$ErrorActionPreference = 'Stop'
# -File passes an array as one string, so a list may arrive as 'A,B'.
$LocalSuiteFolder = @($LocalSuiteFolder | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
$hashRows = New-Object -TypeName 'System.Collections.Generic.List[object]'
function Add-Hash { param ([string] $Path) $hashRows.Add([pscustomobject]@{ File = $Path; Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash; Bytes = (Get-Item -LiteralPath $Path).Length }) }
function Get-Multiset { param ([string[]] $Name) $set = @{}; foreach ($item in @($Name | Where-Object -FilterScript { $_ })) { $set[$item] = 1 + [int] $set[$item] }; $set }
function Get-Excess {
    param ([hashtable] $Left, [hashtable] $Right)
    foreach ($key in ($Left.Keys | Sort-Object)) { $extra = [int] $Left[$key] - [int] $Right[$key]; if ($extra -gt 0) { '{0} (x{1})' -f $key, $extra } }
}

if ($MatrixRoot) {
    $cellRows = New-Object -TypeName 'System.Collections.Generic.List[object]'
    $skipRows = New-Object -TypeName 'System.Collections.Generic.List[object]'
    foreach ($folder in (Get-ChildItem -LiteralPath $MatrixRoot -Directory -Filter "$Label-*" | Sort-Object -Property Name)) {
        $server = $folder.Name.Substring($Label.Length + 1)
        $readiness = Join-Path -Path $folder.FullName -ChildPath 'readiness.log'
        $operatingSystems = @{}
        foreach ($match in (Select-String -LiteralPath $readiness -Pattern '^(\S+)\s+wsman=ok .* os=(.+?) type=(\d)')) {
            $groups = $match.Matches[0].Groups
            $operatingSystems[$groups[1].Value] = '{0} ({1})' -f ($groups[2].Value -replace '^Microsoft ', ''), $(if ($groups[3].Value -eq '1') { 'client' } else { 'server' })
        }

        $clientName = @($operatingSystems.Keys | Where-Object -FilterScript { $operatingSystems[$_] -like '*client*' })[0]
        $counts = Import-Csv -LiteralPath (Join-Path -Path $folder.FullName -ChildPath "$Label-$server-counts.csv")
        foreach ($row in $counts) {
            $cellRows.Add([pscustomobject]@{
                    FileServer = $server; FileServerOs = $operatingSystems[$server]; Client = $clientName; ClientOs = $operatingSystems[$clientName]
                    Edition = $row.Edition; Role = $row.Role; Account = $row.Account; ExitCode = $row.ExitCode; Passed = $row.Passed; Failed = $row.Failed; Skipped = $row.Skipped
                })
        }

        foreach ($test in (Import-Csv -LiteralPath (Join-Path -Path $folder.FullName -ChildPath "$Label-$server-tests.csv") | Where-Object -FilterScript { $_.Result -ne 'Passed' })) {
            $skipRows.Add([pscustomobject]@{ FileServer = $server; Edition = $test.Edition; Role = $test.Role; Result = $test.Result; Test = $test.Test; Message = $test.Message })
        }

        foreach ($name in "$Label-$server-counts.csv", "$Label-$server-tests.csv", "$Label-$server-failures.csv", 'readiness.log', 'validation.log', 'run.log', 'fixture-sids.json', 'cleanup-1-snapshot.log', 'cleanup-2-remove.log', 'cleanup-3-verify.log') {
            $path = Join-Path -Path $folder.FullName -ChildPath $name
            if (Test-Path -LiteralPath $path) { Add-Hash -Path $path }
        }

        foreach ($summary in (Get-ChildItem -LiteralPath (Join-Path -Path $folder.FullName -ChildPath 'Results') -Filter 'Summary.json' -Recurse -ErrorAction SilentlyContinue)) { Add-Hash -Path $summary.FullName }
    }

    $cellRows | Export-Csv -LiteralPath "$OutputPrefix-cells.csv" -NoTypeInformation
    $skipRows | Export-Csv -LiteralPath "$OutputPrefix-cells-skipped.csv" -NoTypeInformation
    '{0} role rows and {1} tests that did not pass, in {2} cell(s)' -f $cellRows.Count, $skipRows.Count, @($cellRows | Select-Object -ExpandProperty FileServer -Unique).Count
}

if ($LocalSuiteFolder) {
    $runs = New-Object -TypeName 'System.Collections.Generic.List[object]'
    foreach ($folder in $LocalSuiteFolder) {
        $machine = ((Split-Path -Path $folder -Leaf) -split '-', 2)[1]
        foreach ($json in (Get-ChildItem -LiteralPath $folder -Filter '*.json' | Sort-Object -Property Name)) {
            $summary = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json
            Add-Hash -Path $json.FullName
            $log = [IO.Path]::ChangeExtension($json.FullName, '.log')
            if (Test-Path -LiteralPath $log) { Add-Hash -Path $log }
            $runs.Add([pscustomobject]@{
                    Machine = $machine; Os = $summary.Os; Mode = $(if ($summary.Elevated) { 'Elevated' } else { 'Basic' }); Edition = $summary.Edition; PowerShell = $summary.PowerShell
                    Result = $summary.Result; Passed = $summary.Passed; Failed = $summary.Failed; Skipped = $summary.Skipped; Total = $summary.Total; Seconds = $summary.Seconds
                    SkippedTests = @($summary.SkippedTests | Where-Object -FilterScript { $_ }); FailedTests = @($summary.FailedTests | Where-Object -FilterScript { $_ })
                })
        }
    }

    $runs | Select-Object -Property Machine, Os, Mode, Edition, PowerShell, Result, Passed, Failed, Skipped, Total, Seconds | Sort-Object -Property Machine, Mode, Edition |
        Export-Csv -LiteralPath "$OutputPrefix-localsuite.csv" -NoTypeInformation
    $differences = foreach ($run in ($runs | Where-Object -FilterScript { $_.Machine -ne $ReferenceMachine })) {
        $reference = $runs | Where-Object -FilterScript { $_.Machine -eq $ReferenceMachine -and $_.Mode -eq $run.Mode -and $_.Edition -eq $run.Edition } | Select-Object -First 1
        if (-not $reference) { continue }
        $mine = Get-Multiset -Name $run.SkippedTests
        $theirs = Get-Multiset -Name $reference.SkippedTests
        [pscustomobject]@{
            Machine = $run.Machine; Mode = $run.Mode; Edition = $run.Edition; Skipped = $run.Skipped; ReferenceSkipped = $reference.Skipped
            OnlyOnMachine = (@(Get-Excess -Left $mine -Right $theirs) -join ' | '); OnlyOnReference = (@(Get-Excess -Left $theirs -Right $mine) -join ' | ')
            Failed = $run.Failed; FailedTests = ($run.FailedTests -join ' | ')
        }
    }

    $differences | Sort-Object -Property Machine, Mode, Edition | Export-Csv -LiteralPath "$OutputPrefix-localsuite-skipdiff.csv" -NoTypeInformation
    '{0} local-suite run(s) of {1} machine(s)' -f $runs.Count, @($runs | Select-Object -ExpandProperty Machine -Unique).Count
}

$hashRows | Export-Csv -LiteralPath "$OutputPrefix-hashes.csv" -NoTypeInformation
'{0} input file(s) hashed' -f $hashRows.Count
