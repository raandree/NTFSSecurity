[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $LogPath,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')] [string] $Name,
    [Parameter(Mandatory)] [string] $OperatingSystem,
    [Parameter(Mandatory)] [string] $IpAddress,
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [ValidateRange(2, 16)] [int] $MemoryGB = 4,
    [ValidateRange(1, 8)] [int] $Processors = 2,
    [ValidateRange(5, 240)] [int] $StartTimeoutMinutes = 40,
    [string] $BackupRoot = 'C:\ProgramData\AutomatedLab\Backups'
)

# Adds one machine to the already deployed matrix lab (Decision 24) and creates only that machine. AutomatedLab 5.61 has no supported way to
# extend a deployed lab: Add-LabMachineDefinition refuses while a lab is imported or exported, and Install-Lab creates every machine of the
# lab again. This script copies the lab metadata first (the copy is readable by administrators only, because the files hold the lab
# credentials), reloads the definition with Import-LabDefinition (never Import-Lab), adds the machine, exports the definition, and then runs
# the same steps Install-Lab runs for a single machine: base image, hosts entries, virtual machine, start. The other machines are neither
# created, started, nor changed. Windows PowerShell 5.1 on the host; run it elevated.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$stamp = '[{0:yyyy-MM-dd HH:mm:ss}Z]'
function Write-Step { param ([string] $Message) ($stamp -f [DateTime]::UtcNow) + ' ' + $Message | Add-Content -LiteralPath $LogPath }

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'This script must run in an elevated PowerShell session.' }

($stamp -f [DateTime]::UtcNow) + " START add-os-matrix-machine lab=$LabName name=$Name os='$OperatingSystem' ip=$IpAddress" | Set-Content -LiteralPath $LogPath
$lockPath = $null
try {
    Import-Module -Name AutomatedLab -ErrorAction Stop
    if ((Get-Lab -List) -notcontains $LabName) { throw "The lab '$LabName' does not exist." }
    if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { throw "A virtual machine named '$Name' exists already." }
    $hostsText = Get-Content -LiteralPath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\drivers\etc\hosts') -Raw
    if ($hostsText -match ('(?im)^\s*[^#\s]+\s+{0}(\.|\s|$)' -f [regex]::Escape($Name)) -or $hostsText -match ('(?im)^\s*{0}\s' -f [regex]::Escape($IpAddress))) {
        throw "The hosts file mentions '$Name' or $IpAddress already."
    }

    $labFolder = Join-Path -Path (Get-LabConfigurationItem -Name LabAppDataRoot) -ChildPath "Labs\$LabName"
    $backup = Join-Path -Path $BackupRoot -ChildPath ('{0}-{1:yyyyMMdd-HHmmss}' -f $LabName, [DateTime]::UtcNow)
    $null = New-Item -ItemType Directory -Path $backup -Force
    $null = & icacls.exe $backup /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F'
    if ($LASTEXITCODE -ne 0) { throw "icacls failed on the backup folder (exit code $LASTEXITCODE)." }
    Copy-Item -LiteralPath $labFolder -Destination $backup -Recurse
    Write-Step "lab metadata copied to $backup"

    Import-LabDefinition -Name $LabName
    $definition = Get-LabDefinition
    $before = @(Get-LabMachineDefinition | ForEach-Object -Process { $_.Name })
    $domainName = $definition.Domains[0].Name
    $rootDc = Get-LabMachineDefinition | Where-Object -FilterScript { 'RootDC' -in $_.Roles.Name } | Select-Object -First 1
    $dcAddress = ($rootDc.NetworkAdapters | Select-Object -First 1).Ipv4Address.IpAddress.AddressAsString
    $dcPrefix = ($dcAddress -split '\.')[0..2] -join '.'
    $newPrefix = ($IpAddress -split '\.')[0..2] -join '.'
    if ($dcPrefix -ne $newPrefix) { throw "$IpAddress isn't in the /24 of the domain controller ($dcAddress)." }
    Write-Step ("definition loaded: domain {0}; machines {1}; installation account {2}" -f $domainName, ($before -join ','), $definition.DefaultInstallationCredential.UserName)

    $parameters = @{
        Name = $Name; DomainName = $domainName; OperatingSystem = $OperatingSystem; Memory = ($MemoryGB * 1GB)
        Processors = $Processors; Network = $LabName; IpAddress = $IpAddress
    }
    if ($OperatingSystem -like 'Windows 11*') {
        $parameters.HypervProperties = @{ EnableSecureBoot = 'On'; SecureBootTemplate = 'MicrosoftWindows'; EnableTpm = 'true' }
    }

    Add-LabMachineDefinition @parameters
    Export-LabDefinition -Force -ExportDefaultUnattendedXml
    Import-Lab -Name $LabName -NoValidation -NoDisplay
    $after = @(Get-LabVM -IncludeLinux | ForEach-Object -Process { $_.Name })
    $difference = @(Compare-Object -ReferenceObject ($before + $Name) -DifferenceObject $after)
    if ($difference.Count -gt 0) { throw "The exported lab doesn't hold exactly the old machines plus $Name. Restore the metadata from $backup." }
    Write-Step 'definition extended and exported'

    $lockPath = Get-LabConfigurationItem -Name DiskDeploymentInProgressPath
    if (Test-Path -LiteralPath $lockPath) { throw "Another lab disk deployment seems to be in progress ($lockPath)." }
    $null = New-Item -Path $lockPath -ItemType File -Value $LabName
    New-LabBaseImages
    Write-Step 'base images ready'

    $machine = Get-LabVM -ComputerName $Name
    $address = ($machine.NetworkAdapters | Select-Object -First 1).Ipv4Address.IpAddress.AddressAsString
    $null = Add-HostEntry -HostName $machine.Name -IpAddress $address -Section $LabName
    $null = Add-HostEntry -HostName $machine.FQDN -IpAddress $address -Section $LabName
    New-LabVM -Name $Name
    Set-LabDefinition -Machines (Get-Lab).Machines
    Export-LabDefinition -Force -ExportDefaultUnattendedXml -Silent
    Write-Step 'virtual machine created and definition exported'
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    $lockPath = $null

    Start-LabVM -ComputerName $Name -ProgressIndicator 30 -TimeoutInMinutes $StartTimeoutMinutes -Wait
    Write-Step 'machine started and reachable with the lab credentials'

    $userName = (Get-Lab).DefaultInstallationCredential.UserName
    Invoke-LabCommand -ActivityName 'Setting PasswordNeverExpires for local deployment accounts' -ComputerName $Name -NoDisplay -Variable (Get-Variable -Name userName) -ScriptBlock {
        Get-CimInstance -Query "Select * from Win32_UserAccount where name = '$userName' and localaccount='true'" | Set-CimInstance -Property @{ PasswordExpires = $false }
    }

    $evidence = Invoke-LabCommand -ComputerName $Name -ActivityName 'Readiness of the new member' -NoDisplay -PassThru -ErrorAction Stop -ArgumentList $domainName -ScriptBlock {
        param ($Domain)
        $current = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        [pscustomobject]@{
            Build         = '{0}.{1}' -f $current.CurrentBuildNumber, $current.UBR
            Product       = $current.ProductName
            Domain        = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
            SecureChannel = [bool] (Test-ComputerSecureChannel)
            Verify        = (@(& nltest.exe "/sc_verify:$Domain" 2>&1) -join ' | ')
        }
    }
    Write-Step ('new member: build {0} ({1}); domain {2}; secure channel {3}; nltest: {4}' -f $evidence.Build, $evidence.Product, $evidence.Domain, $evidence.SecureChannel, $evidence.Verify)
    if (-not $evidence.SecureChannel) { throw "The secure channel of $Name is broken." }

    Write-Step 'add-os-matrix-machine-DONE'
    exit 0
}
catch {
    Write-Step ('add-os-matrix-machine-FAILED: {0}' -f $_)
    $_ | Format-List -Property * -Force | Out-String | Add-Content -LiteralPath $LogPath
    exit 1
}
finally {
    if ($lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
