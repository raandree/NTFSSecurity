[CmdletBinding()]
param (
    [Parameter(Mandatory)] [ValidatePattern('^[\w-]+$')] [string] $Label,
    [Parameter(Mandatory)] [string] $Root,
    [Parameter(Mandatory)] [string] $OutDir,
    [string] $PesterVersion = '5.7.1',
    [string] $PesterModulePath
)

# Runs the Pester files of <Root>\Tests in this process, Windows PowerShell 5.1 or PowerShell 7, against the module in
# <Root>\NTFSSecurity\bin\Release, like .github\scripts\Invoke-Tests.ps1 does for the repository. It writes the log, the NUnit result, a JSON
# summary, and an exit code file to <OutDir>. Run it in a new process for every edition. The tests keep to their own sandbox folders
# below $env:TEMP.
$ErrorActionPreference = 'Stop'
$null = New-Item -ItemType Directory -Path $OutDir -Force
$log = Join-Path -Path $OutDir -ChildPath "$Label.log"
$script:exitCode = 1
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    # A Windows PowerShell process started by PowerShell 7 would inherit the module path of PowerShell 7.
    $env:PSModulePath = @(
        (Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules'),
        (Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules'),
        (Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\Modules')
    ) -join ';'
}

& {
    $principal = New-Object -TypeName 'Security.Principal.WindowsPrincipal' -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
    $elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $current = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    '[{0:yyyy-MM-dd HH:mm:ss}Z] START {1} edition={2} {3} elevated={4} os={5} build={6}.{7} user={8}' -f [DateTime]::UtcNow, $Label, $PSVersionTable.PSEdition,
        $PSVersionTable.PSVersion, $elevated, $current.ProductName, $current.CurrentBuildNumber, $current.UBR, [Security.Principal.WindowsIdentity]::GetCurrent().Name
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        if ($PesterModulePath) { Import-Module -Name (Join-Path -Path $PesterModulePath -ChildPath 'Pester.psd1') -Force -ErrorAction Stop }
        else { Import-Module -Name Pester -RequiredVersion $PesterVersion -Force -ErrorAction Stop }
        $configuration = New-PesterConfiguration
        $configuration.Run.Path = @(Join-Path -Path $Root -ChildPath 'Tests')
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'Normal'
        # The NUnit file is written below, after the summary: its writer asks WMI for the environment, which a restricted token may not do.
        $configuration.TestResult.Enabled = $false
        $result = Invoke-Pester -Configuration $configuration
        'RESULT result={0} passed={1} failed={2} skipped={3} notrun={4} total={5} failedContainers={6} seconds={7:N0}' -f $result.Result, $result.PassedCount,
            $result.FailedCount, $result.SkippedCount, $result.NotRunCount, $result.TotalCount, $result.FailedContainersCount, $watch.Elapsed.TotalSeconds
        foreach ($test in $result.Failed) { 'FAILED: {0}: {1}' -f $test.ExpandedPath, ("$(@($test.ErrorRecord)[0])" -replace '\s+', ' ') }
        foreach ($test in $result.Skipped) { 'SKIPPED: {0}' -f $test.ExpandedPath }
        [pscustomobject]@{
            Label = $Label; Edition = $PSVersionTable.PSEdition; PowerShell = $PSVersionTable.PSVersion.ToString(); Elevated = $elevated
            Os = '{0} {1}.{2}' -f $current.ProductName, $current.CurrentBuildNumber, $current.UBR; Result = [string] $result.Result
            Passed = $result.PassedCount; Failed = $result.FailedCount; Skipped = $result.SkippedCount; NotRun = $result.NotRunCount; Total = $result.TotalCount
            FailedContainers = $result.FailedContainersCount; Seconds = [int] $watch.Elapsed.TotalSeconds
            FailedTests = @($result.Failed | ForEach-Object -Process { $_.ExpandedPath }); SkippedTests = @($result.Skipped | ForEach-Object -Process { $_.ExpandedPath })
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path -Path $OutDir -ChildPath "$Label.json") -Encoding UTF8
        try { Export-NUnitReport -Result $result -Path (Join-Path -Path $OutDir -ChildPath "$Label.xml") }
        catch { 'NUnit report not written: {0}' -f $_.Exception.Message }
        if ($result.Result -eq 'Passed') { $script:exitCode = 0 }
        '[{0:yyyy-MM-dd HH:mm:ss}Z] {1}-DONE' -f [DateTime]::UtcNow, $Label
    }
    catch {
        'ERROR: {0}' -f $_
        '[{0:yyyy-MM-dd HH:mm:ss}Z] {1}-FAILED' -f [DateTime]::UtcNow, $Label
    }
} *>&1 | Out-File -FilePath $log -Encoding utf8 -Width 400
Set-Content -LiteralPath (Join-Path -Path $OutDir -ChildPath "$Label.exit") -Value $script:exitCode
exit $script:exitCode
