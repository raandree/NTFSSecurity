<#
.SYNOPSIS
    Runs the Pester tests in the Tests folder and reports the result to GitHub Actions.

.DESCRIPTION
    Imports Pester 5.7.1, runs the tests against the module build in NTFSSecurity\bin\Release, writes the result
    file in the NUnit format, and adds the counts and the failed tests to the job summary of GitHub Actions. Fails if
    a test or a test file fails. The live tests in Tests\Lab need a lab and don't run here.

.PARAMETER ResultPath
    Specifies the path of the result file.

.PARAMETER Title
    Specifies the heading of the test results in the job summary, such as the PowerShell edition.

.EXAMPLE
    .\.github\scripts\Invoke-Tests.ps1 -ResultPath TestResults\WindowsPowerShell.xml -Title 'Windows PowerShell 5.1'

    Runs the tests and writes the result file. Outside GitHub Actions, the script writes no job summary.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ResultPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Title
)

$ErrorActionPreference = 'Stop'
Import-Module -Name Pester -RequiredVersion 5.7.1

$resultFolder = Split-Path -Path $ResultPath -Parent
if ($resultFolder -and -not (Test-Path -LiteralPath $resultFolder)) {
    New-Item -ItemType Directory -Path $resultFolder | Out-Null
}

$testsPath = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\Tests')).ProviderPath
$configuration = New-PesterConfiguration
$configuration.Run.Path = $testsPath
# The live tests in Tests\Lab need a lab (Tests\Lab\README.md). Pester matches the full path of each test file.
$configuration.Run.ExcludePath = '{0}\Lab\*' -f [WildcardPattern]::Escape($testsPath)
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.TestResult.OutputPath = $ResultPath
$result = Invoke-Pester -Configuration $configuration

if ($env:GITHUB_STEP_SUMMARY) {
    $summary = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $summary.Add("### Tests in $Title")
    $summary.Add('')
    $summary.Add('| Result | Passed | Failed | Skipped | Total |')
    $summary.Add('| --- | ---: | ---: | ---: | ---: |')
    $summary.Add(('| {0} | {1} | {2} | {3} | {4} |' -f $result.Result, $result.PassedCount, $result.FailedCount,
            $result.SkippedCount, $result.TotalCount))
    if ($result.Failed.Count -gt 0 -or $result.FailedContainersCount -gt 0) {
        $summary.Add('')
        $summary.Add('Failed:')
        $summary.Add('')
        foreach ($test in $result.Failed) {
            $message = "$(@($test.ErrorRecord)[0])" -replace '\s+', ' '
            $summary.Add(('- {0}: {1}' -f $test.ExpandedPath, $message))
        }
        foreach ($container in $result.Containers | Where-Object -Property Result -EQ -Value 'Failed') {
            $summary.Add(('- {0}: {1}' -f $container.Item, ("$(@($container.ErrorRecord)[0])" -replace '\s+', ' ')))
        }
    }
    $summary.Add('')

    $encoding = New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false
    [IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, ($summary -join "`n") + "`n", $encoding)
}

if ($result.Result -ne 'Passed') {
    throw "The tests in $Title failed: $($result.FailedCount) failed tests, $($result.FailedContainersCount) failed test files."
}
