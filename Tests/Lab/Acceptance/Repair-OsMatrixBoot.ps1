[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $LogPath,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')] [string] $VmName,
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [switch] $Start
)

# Repairs the boot files of one virtual machine of the matrix lab. AutomatedLab builds a base image with the bcdboot of the host and
# ignores its exit code; when the host's bcdboot can't process the boot files of an older image (it fails with exit code 193 on Windows
# Server 2019 and on Windows 11 22H2), the EFI system partition stays empty and the generation 2 virtual machine fails with Hyper-V event
# 18603. This script turns the machine off, mounts the machine's own differencing disk (never the shared base image), runs the bcdboot of
# the image itself, adds the removable-media path EFI\Boot\bootx64.efi that a new virtual machine boots from, checks the files, and
# dismounts the disk. It refuses a machine that isn't connected to the switch of the lab. Windows PowerShell 5.1 on the host, elevated.
$ErrorActionPreference = 'Stop'
$stamp = '[{0:yyyy-MM-dd HH:mm:ss}Z]'
function Write-Step { param ([string] $Message) ($stamp -f [DateTime]::UtcNow) + ' ' + $Message | Add-Content -LiteralPath $LogPath }

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'This script must run in an elevated PowerShell session.' }

($stamp -f [DateTime]::UtcNow) + " START repair-os-matrix-boot vm=$VmName lab=$LabName" | Set-Content -LiteralPath $LogPath
$diskPath = $null
$letters = @()
try {
    $vm = Get-VM -Name $VmName
    if ($vm.Generation -ne 2) { throw "$VmName isn't a generation 2 machine." }
    $switches = @(Get-VMNetworkAdapter -VMName $VmName | ForEach-Object -Process { $_.SwitchName })
    # An array comparison with -ne returns the elements that differ, and an empty result is false: a machine without an adapter, or with an
    # adapter that has no switch, would pass, so the guard counts.
    if ($switches.Count -eq 0 -or @($switches | Where-Object -FilterScript { $_ -ne $LabName }).Count -gt 0) { throw "$VmName isn't connected only to the switch '$LabName' (switches: $($switches -join ', ')). Refusing." }
    if ($vm.State -ne 'Off') {
        Stop-VM -Name $VmName -TurnOff -Force
        Write-Step "$VmName turned off"
    }

    $drive = Get-VMHardDiskDrive -VMName $VmName | Select-Object -First 1
    $diskPath = $drive.Path
    $vhd = Get-VHD -Path $diskPath
    if ($vhd.VhdType -ne 'Differencing') { throw "$diskPath isn't a differencing disk; refusing to change a base image." }
    Write-Step "disk $diskPath (parent $($vhd.ParentPath))"

    $image = Mount-VHD -Path $diskPath -Passthru
    $disk = $image | Get-Disk
    $partitions = @(Get-Partition -DiskNumber $disk.Number)
    $esp = $partitions | Where-Object -FilterScript { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' } | Select-Object -First 1
    $system = $partitions | Where-Object -FilterScript { $_.Type -eq 'Basic' } | Sort-Object -Property Size -Descending | Select-Object -First 1
    if (-not $esp -or -not $system) { throw 'The disk has no EFI system partition or no Windows partition.' }
    foreach ($partition in $esp, $system) {
        # The host may have assigned a letter to the Windows partition on mount already.
        if (-not (Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber).DriveLetter) {
            Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -AssignDriveLetter
        }

        $letters += (Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber).DriveLetter
    }

    $espLetter = (Get-Partition -DiskNumber $disk.Number -PartitionNumber $esp.PartitionNumber).DriveLetter
    $systemLetter = (Get-Partition -DiskNumber $disk.Number -PartitionNumber $system.PartitionNumber).DriveLetter
    $windows = '{0}:\Windows' -f $systemLetter
    $bcdboot = Join-Path -Path $windows -ChildPath 'System32\bcdboot.exe'
    if (-not (Test-Path -LiteralPath $bcdboot)) { throw "$bcdboot is missing." }
    $before = @(Get-ChildItem -LiteralPath ('{0}:\' -f $espLetter) -Recurse -Force -File -ErrorAction SilentlyContinue).Count
    Write-Step ("system partition {0}: {1}; ESP {2}: holds {3} files; image build {4}" -f $systemLetter, $windows, $espLetter, $before, (Get-Item -LiteralPath $bcdboot).VersionInfo.ProductVersion)

    $output = & $bcdboot $windows /s ('{0}:' -f $espLetter) /f UEFI 2>&1 | Out-String
    Write-Step ("bcdboot of the image: exit code {0}: {1}" -f $LASTEXITCODE, ($output -replace '\s+', ' ').Trim())
    if ($LASTEXITCODE -ne 0) { throw "bcdboot of the image failed with exit code $LASTEXITCODE." }

    $bootManager = '{0}:\EFI\Microsoft\Boot\bootmgfw.efi' -f $espLetter
    if (-not (Test-Path -LiteralPath $bootManager)) { throw "$bootManager is missing after bcdboot." }
    $removable = '{0}:\EFI\Boot' -f $espLetter
    $null = New-Item -ItemType Directory -Path $removable -Force
    Copy-Item -LiteralPath $bootManager -Destination (Join-Path -Path $removable -ChildPath 'bootx64.efi') -Force
    $after = @(Get-ChildItem -LiteralPath ('{0}:\' -f $espLetter) -Recurse -Force -File -ErrorAction SilentlyContinue).Count
    $hasBcd = Test-Path -LiteralPath ('{0}:\EFI\Microsoft\Boot\BCD' -f $espLetter)
    Write-Step ("ESP now holds {0} files; BCD present: {1}; bootx64.efi present: {2}" -f $after, $hasBcd, (Test-Path -LiteralPath (Join-Path -Path $removable -ChildPath 'bootx64.efi')))
    if ($after -lt 20 -or -not $hasBcd) { throw "The EFI system partition still looks empty ($after files, BCD $hasBcd)." }
}
catch {
    Write-Step ('repair-os-matrix-boot-FAILED: {0}' -f $_)
    $_ | Format-List -Property * -Force | Out-String | Add-Content -LiteralPath $LogPath
    $failed = $true
}
finally {
    if ($diskPath) {
        try {
            foreach ($partition in @(Get-Partition -DiskNumber (Get-VHD -Path $diskPath).DiskNumber -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.DriveLetter })) {
                Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath ('{0}:\' -f $partition.DriveLetter) -ErrorAction SilentlyContinue
            }
        }
        catch { Write-Step ('access path cleanup: {0}' -f $_) }
        Dismount-VHD -Path $diskPath -ErrorAction SilentlyContinue
        Write-Step 'disk dismounted'
    }
}

if ($failed) { exit 1 }
if ($Start) {
    Start-VM -Name $VmName
    Write-Step "$VmName started"
}

Write-Step 'repair-os-matrix-boot-DONE'
exit 0
