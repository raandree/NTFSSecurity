[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $LogPath,
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [string[]] $Member = @('OSDC1', 'OSFile19', 'OSFile22', 'OSFile25', 'OSWin11E'),
    [string[]] $LocalCredentialMember = @(),
    [string] $PesterModulePath = 'V:\Git\WindowsAccessControl\output\RequiredModules\Pester\5.7.1',
    [string] $PowerShell7Msi = 'V:\LabSources\SoftwarePackages\PowerShell-7.6.3-win-x64.msi'
)

# Finishes machines of the matrix lab after a deployment that stopped in AutomatedLab's file server step (a job that never completed
# although its remote side was idle) or after Add-OsMatrixMachine.ps1: detaches the installation ISO from the file servers, installs
# PowerShell 7 from the MSI of the host, and copies Pester 5.7.1 into the module folders of both editions. It uses no AutomatedLab job
# (no -AsJob), only synchronous remoting. A member in -LocalCredentialMember is reached with the local installation account through a
# session, for a machine whose secure channel to the domain controller fails. Windows PowerShell 5.1 on the host; run it elevated.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# -File passes an array as one string, so a list may arrive as 'A,B'.
$Member = @($Member | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
$LocalCredentialMember = @($LocalCredentialMember | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
$stamp = '[{0:yyyy-MM-dd HH:mm:ss}Z]'
function Write-Step { param ([string] $Message) ($stamp -f [DateTime]::UtcNow) + ' ' + $Message | Add-Content -LiteralPath $LogPath }

$installBlock = {
    param ($Msi)
    $msiPath = Join-Path -Path 'C:\Windows\Temp' -ChildPath $Msi
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', ('"{0}"' -f $msiPath), '/quiet', '/norestart', 'ADD_PATH=1', '/l*v', 'C:\Windows\Temp\pwsh-install.log') -Wait -PassThru
    $pwsh = Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe'
    [pscustomobject]@{ ExitCode = $process.ExitCode; Pwsh = $(if (Test-Path -LiteralPath $pwsh) { (Get-Item -LiteralPath $pwsh).VersionInfo.ProductVersion } else { 'missing' }) }
}
$createBlock = { param ($Path) $null = New-Item -Path $Path -ItemType Directory -Force }
$checkBlock = { param ($Path) '{0}: {1}' -f $env:COMPUTERNAME, (Test-Path -LiteralPath (Join-Path -Path $Path -ChildPath '5.7.1\Pester.psd1')) }

($stamp -f [DateTime]::UtcNow) + " START complete-os-matrix-lab lab=$LabName members=$($Member -join ',') localCredential=$($LocalCredentialMember -join ',')" | Set-Content -LiteralPath $LogPath
try {
    foreach ($path in $PesterModulePath, $PowerShell7Msi) { if (-not (Test-Path -LiteralPath $path)) { throw "Missing payload: $path" } }
    Import-Module -Name AutomatedLab -ErrorAction Stop
    Import-Lab -Name $LabName -NoValidation -NoDisplay
    $fileServers = @($Member | Where-Object -FilterScript { $_ -like 'OSFile*' -and $_ -notin $LocalCredentialMember })
    if ($fileServers) {
        Dismount-LabIsoImage -ComputerName $fileServers -SupressOutput
        Write-Step "installation ISO detached from $($fileServers -join ',')"
    }

    $msiName = Split-Path -Path $PowerShell7Msi -Leaf
    $domainMembers = @($Member | Where-Object -FilterScript { $_ -notin $LocalCredentialMember })
    foreach ($name in $Member) {
        if ($name -in $LocalCredentialMember) {
            $session = New-LabPSSession -ComputerName $name -UseLocalCredential
            try {
                Copy-Item -LiteralPath $PowerShell7Msi -Destination 'C:\Windows\Temp\' -ToSession $session -Force
                $outcome = Invoke-Command -Session $session -ScriptBlock $installBlock -ArgumentList $msiName
                foreach ($modulesRoot in 'C:\Program Files\WindowsPowerShell\Modules', 'C:\Program Files\PowerShell\Modules') {
                    $destination = Join-Path -Path $modulesRoot -ChildPath 'Pester'
                    Invoke-Command -Session $session -ScriptBlock $createBlock -ArgumentList $destination
                    Copy-Item -LiteralPath $PesterModulePath -Destination $destination -ToSession $session -Recurse -Force
                    Write-Step ("Pester 5.7.1 in {0}: {1}" -f $modulesRoot, (Invoke-Command -Session $session -ScriptBlock $checkBlock -ArgumentList $destination))
                }
            }
            finally {
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            }
        }
        else {
            Copy-LabFileItem -Path $PowerShell7Msi -ComputerName $name -DestinationFolderPath 'C:\Windows\Temp'
            $outcome = Invoke-LabCommand -ComputerName $name -ActivityName "Install PowerShell 7 on $name" -NoDisplay -PassThru -ErrorAction Stop -ArgumentList $msiName -ScriptBlock $installBlock
        }

        Write-Step ("PowerShell 7 on {0}: msiexec exit code {1}; pwsh {2}" -f $name, $outcome.ExitCode, $outcome.Pwsh)
        if ($outcome.ExitCode -notin 0, 3010 -or $outcome.Pwsh -eq 'missing') { throw "PowerShell 7 isn't installed on $name (exit code $($outcome.ExitCode))." }
    }

    if ($domainMembers) {
        foreach ($modulesRoot in 'C:\Program Files\WindowsPowerShell\Modules', 'C:\Program Files\PowerShell\Modules') {
            $destination = Join-Path -Path $modulesRoot -ChildPath 'Pester'
            Invoke-LabCommand -ComputerName $domainMembers -ActivityName 'Create the Pester module directory' -NoDisplay -ErrorAction Stop -ArgumentList $destination -ScriptBlock $createBlock
            Copy-LabFileItem -Path $PesterModulePath -ComputerName $domainMembers -DestinationFolderPath $destination -Recurse
            $found = Invoke-LabCommand -ComputerName $domainMembers -ActivityName 'Check Pester' -NoDisplay -PassThru -ErrorAction Stop -ArgumentList $destination -ScriptBlock $checkBlock
            Write-Step ("Pester 5.7.1 in {0}: {1}" -f $modulesRoot, (@($found) -join '; '))
            if (@($found | Where-Object -FilterScript { $_ -notmatch ': True$' }).Count -gt 0) { throw "Pester 5.7.1 isn't in $destination on every member." }
        }
    }

    Write-Step 'complete-os-matrix-lab-DONE'
    exit 0
}
catch {
    Write-Step ("complete-os-matrix-lab-FAILED: {0}" -f $_)
    $_ | Format-List -Property * -Force | Out-String | Add-Content -LiteralPath $LogPath
    exit 1
}
