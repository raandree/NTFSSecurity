[CmdletBinding()]
param (
    [Parameter(Mandatory)] [ValidatePattern('^[\w-]+$')] [string] $Label,
    [Parameter(Mandatory)] [string] $FileServer,
    [string] $Client = 'OSWin11E',
    [string] $ModulePath,
    [string] $Version,
    [string] $Edition = 'Desktop,Core',
    [Parameter(Mandatory)] [string] $OutputRoot,
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [string] $DomainController = 'OSDC1',
    [string] $LabFolder,
    [string] $Machines = 'OSFile19,OSFile22,OSFile25,OSWin11E'
)

# One detached sequence of the operating-system matrix (Decision 24) in Windows PowerShell 5.1 on the Hyper-V host. For each cell, a file
# server with the client, it runs: readiness of every machine, the unmodified controller of the repository for the source (a build
# folder or an exact Gallery version) in both editions, the validation of every role from the result files, a snapshot of the fixture
# SIDs, the removal of the fixture, and an independent check of the end state. An infrastructure failure (no summary of the controller)
# stops the later cells; failing tests don't. Case 9 (accounts of other forests) needs trusts that this lab doesn't have, so the cells
# run with -ForeignDomainController @(). Nothing secret is written: the controller keeps the passwords in memory.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# Windows PowerShell 5.1 leaves $PSScriptRoot empty in a parameter default when the script runs with -File.
if (-not $LabFolder) { $LabFolder = Split-Path -Path $PSScriptRoot -Parent }
$stamp = '[{0:yyyy-MM-dd HH:mm:ss}Z]'
$kit = $PSScriptRoot
$cells = @($FileServer -split ',' | Where-Object -FilterScript { $_ })
$editions = @($Edition -split ',' | Where-Object -FilterScript { $_ })
$allMachines = @($Machines -split ',' | Where-Object -FilterScript { $_ })
if ([bool] $ModulePath -eq [bool] $Version) { throw 'Pass exactly one of -ModulePath and -Version.' }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$sequenceLog = Join-Path -Path $OutputRoot -ChildPath "$Label-sequence.log"
function Write-Sequence { param ([string] $Message) ($stamp -f [DateTime]::UtcNow) + ' ' + $Message | Add-Content -LiteralPath $sequenceLog }
$source = if ($ModulePath) { "module=$ModulePath dll=$((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path -Path $ModulePath -ChildPath 'NTFSSecurity.dll')).Hash)" } else { "version=$Version" }
($stamp -f [DateTime]::UtcNow) + " START matrix-sequence-$Label client=$Client cells=$($cells -join ',') editions=$($editions -join ',') $source" | Set-Content -LiteralPath $sequenceLog
Write-Sequence ('controller blob {0}' -f ((& git -C (Split-Path -Path (Split-Path -Path $LabFolder -Parent) -Parent) hash-object (Join-Path -Path $LabFolder -ChildPath 'Invoke-NTFSSecurityLabTest.ps1')) -join ''))
Write-Sequence ('live tests blob {0}' -f ((& git -C (Split-Path -Path (Split-Path -Path $LabFolder -Parent) -Parent) hash-object (Join-Path -Path $LabFolder -ChildPath 'NTFSSecurity.Live.Tests.ps1')) -join ''))
$controller = Join-Path -Path $LabFolder -ChildPath 'Invoke-NTFSSecurityLabTest.ps1'
$infrastructureFailed = $false

foreach ($fileServerName in $cells) {
    if ($infrastructureFailed) { Write-Sequence "cell $fileServerName SKIPPED after an infrastructure failure"; continue }
    $cell = Join-Path -Path $OutputRoot -ChildPath "$Label-$fileServerName"
    New-Item -ItemType Directory -Path $cell -Force | Out-Null
    $runLog = Join-Path -Path $cell -ChildPath 'run.log'
    $ran = $false
    Write-Sequence "cell $fileServerName START (client $Client)"
    try {
        $readinessLog = Join-Path -Path $cell -ChildPath 'readiness.log'
        & (Join-Path -Path $kit -ChildPath 'Test-MatrixReadiness.ps1') -LabName $LabName -DomainController @($DomainController) -Member @($allMachines) -OutFile $readinessLog
        $readiness = Get-Content -LiteralPath $readinessLog -Raw
        $notReady = 'wsman=failed|secure channel False|PowerShell 7 missing|Core missing|Pester Desktop (?!5\.7\.1)|=False|kerberos: .*Error'
        $problem = [regex]::Match($readiness, $notReady).Value
        if ($readiness -notmatch 'matrix-readiness-DONE' -or $problem) { throw "Readiness of cell $fileServerName failed ('$problem'); see $readinessLog" }
        Write-Sequence "cell $fileServerName readiness ok"

        $arguments = @{
            LabName = $LabName; DomainController = $DomainController; FileServer = $fileServerName; Client = $Client
            ForeignDomainController = @(); Edition = $editions; OutputPath = $cell; Confirm = $false
        }
        if ($ModulePath) { $arguments.Version = @(); $arguments.ModulePath = $ModulePath } else { $arguments.Version = @($Version) }
        ($stamp -f [DateTime]::UtcNow) + " START controller cell=$fileServerName" | Set-Content -LiteralPath $runLog
        $ran = $true
        & { & $controller @arguments } *>&1 | ForEach-Object -Process { '{0}' -f $_ } | Out-File -LiteralPath $runLog -Append -Encoding utf8 -Width 500
        $summaryPath = Get-ChildItem -LiteralPath (Join-Path -Path $cell -ChildPath 'Results') -Filter 'Summary.json' -Recurse -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTimeUtc -Descending | Select-Object -First 1 -ExpandProperty FullName
        if (-not $summaryPath) { throw "The controller wrote no Summary.json for cell $fileServerName; see $runLog" }
        Write-Sequence "cell $fileServerName controller done: $summaryPath"

        $validationLog = Join-Path -Path $cell -ChildPath 'validation.log'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path -Path $kit -ChildPath 'Validate-LabResults.ps1') -ResultsFolder (Split-Path -Path $summaryPath -Parent) -OutputPrefix (Join-Path -Path $cell -ChildPath "$Label-$fileServerName") -Edition ($editions -join ',') -Expect Candidate *>&1 |
            Out-File -LiteralPath $validationLog -Encoding utf8 -Width 400
        Write-Sequence "cell $fileServerName validation exit code $LASTEXITCODE (see validation.log)"
    }
    catch {
        Write-Sequence "cell $fileServerName FAILED before the cleanup: $_"
        if (-not $ran) { Write-Sequence "cell ${fileServerName}: the controller did not start" }
        $infrastructureFailed = $true
    }

    try {
        $sidFile = Join-Path -Path $cell -ChildPath 'fixture-sids.json'
        $common = @{ LabName = $LabName; DomainController = @($DomainController); Machine = @($allMachines) }
        if ($ran) {
            & (Join-Path -Path $kit -ChildPath 'Test-MatrixCleanup.ps1') -Mode Snapshot -SidFile $sidFile -OutFile (Join-Path -Path $cell -ChildPath 'cleanup-1-snapshot.log') @common
            & { & $controller -RemoveFixture -LabName $LabName -DomainController $DomainController -FileServer $fileServerName -Client $Client -ForeignDomainController @() -Confirm:$false } *>&1 |
                ForEach-Object -Process { '{0}' -f $_ } | Out-File -LiteralPath (Join-Path -Path $cell -ChildPath 'cleanup-2-remove.log') -Encoding utf8 -Width 500
            & (Join-Path -Path $kit -ChildPath 'Test-MatrixCleanup.ps1') -Mode Verify -SidFile $sidFile -OutFile (Join-Path -Path $cell -ChildPath 'cleanup-3-verify.log') @common
            $verify = Get-Content -LiteralPath (Join-Path -Path $cell -ChildPath 'cleanup-3-verify.log') -Raw
            $clean = ($verify -match 'matrix-cleanup-Verify-DONE') -and ($verify -notmatch 'OU NTFSSecurityLive: True') -and ($verify -notmatch 'accounts: NtfsLive') -and
            ($verify -notmatch 'share=True|C:\\NTFSSecurityLive=True|C:\\NTFSSecurityLab=True|NtfsLiveLocal=True') -and ($verify -notmatch 'profiles=[1-9]') -and ($verify -notmatch ': [1-9]\d* fixture member') -and
            ($verify -notmatch 'probe accounts: [1-9]') -and ($verify -notmatch 'residue: [^\r\n]*=[1-9]')
            Write-Sequence ("cell $fileServerName cleanup verdict from the verify log: {0}" -f $(if ($clean) { 'CLEAN' } else { 'DIRTY (read cleanup-3-verify.log)' }))
        }
    }
    catch {
        Write-Sequence "cell $fileServerName cleanup FAILED: $_"
    }

    Write-Sequence "cell $fileServerName END"
}

Write-Sequence "matrix-sequence-$Label-DONE"
exit 0
