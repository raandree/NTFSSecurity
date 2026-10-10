[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $LogPath,
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [string] $DomainName = 'osmatrix.net',
    [string] $VmPath = 'V:\AutomatedLab-VMs',
    [string] $AddressSpace = '192.168.12.0/24',
    [string] $PesterModulePath = 'V:\Git\WindowsAccessControl\output\RequiredModules\Pester\5.7.1',
    [string] $PowerShell7Msi = 'V:\LabSources\SoftwarePackages\PowerShell-7.6.3-win-x64.msi'
)

# Deploys an isolated AutomatedLab lab for the NTFSSecurity operating-system matrix (Decision 24): one domain controller, three file
# servers (Server 2019, 2022, 2025), and a Windows 11 client, in a domain and on a switch of their own. It touches none of the
# existing labs, machines, switches, or domains, never calls Remove-Lab, and refuses to run when the lab or a machine name exists.
# The installation password is generated here, kept in memory, and stored only where AutomatedLab stores it for every lab.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$stamp = '[{0:yyyy-MM-dd HH:mm:ss}Z]'
function Write-Step { param ([string] $Message) ($stamp -f [DateTime]::UtcNow) + ' ' + $Message | Add-Content -LiteralPath $LogPath }

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'This script must run in an elevated PowerShell session.' }

($stamp -f [DateTime]::UtcNow) + " START deploy-os-matrix-lab lab=$LabName" | Set-Content -LiteralPath $LogPath
try {
    Import-Module -Name AutomatedLab -ErrorAction Stop
    foreach ($path in $PesterModulePath, $PowerShell7Msi) { if (-not (Test-Path -LiteralPath $path)) { throw "Missing payload: $path" } }

    $machines = @(
        @{ Name = 'OSDC1'; Os = 'Windows Server 2025 Datacenter (Desktop Experience)'; Roles = @('RootDC'); Memory = 4GB; Address = '192.168.12.10' }
        @{ Name = 'OSFile25'; Os = 'Windows Server 2025 Datacenter (Desktop Experience)'; Roles = @('FileServer'); Memory = 3GB; Address = '192.168.12.25' }
        @{ Name = 'OSFile22'; Os = 'Windows Server 2022 Datacenter (Desktop Experience)'; Roles = @('FileServer'); Memory = 3GB; Address = '192.168.12.22' }
        @{ Name = 'OSFile19'; Os = 'Windows Server 2019 Datacenter (Desktop Experience)'; Roles = @('FileServer'); Memory = 3GB; Address = '192.168.12.19' }
        @{ Name = 'OSWin11'; Os = 'Windows 11 Pro'; Roles = @(); Memory = 4GB; Address = '192.168.12.11' }
    )

    # Collision checks from AutomatedLab metadata and from Hyper-V; the existing labs are only read.
    $existingNames = New-Object System.Collections.Generic.List[string]
    $labs = @(Get-Lab -List)
    if ($labs -contains $LabName) { throw "The lab '$LabName' exists already. Refusing to redefine it." }
    foreach ($existing in $labs) {
        Import-Lab -Name $existing -NoValidation -NoDisplay -ErrorAction Stop
        foreach ($vm in Get-LabVM -IncludeLinux) { $existingNames.Add($vm.Name) }
    }
    foreach ($vm in Get-VM) { $existingNames.Add($vm.Name) }
    $collisions = @($machines.Name | Where-Object { $_ -in $existingNames })
    if ($collisions) { throw "Machine name collision: $($collisions -join ', ')" }
    if (Get-VMSwitch -Name $LabName -ErrorAction SilentlyContinue) { throw "A virtual switch named '$LabName' exists already." }
    $usedAddresses = @(Get-NetIPAddress -AddressFamily IPv4 | ForEach-Object { $_.IPAddress })
    if ($usedAddresses | Where-Object { $_ -like '192.168.12.*' }) { throw 'The address space 192.168.12.0/24 is in use on the host.' }
    Write-Step ('preflight ok; existing labs: {0}; existing machine names: {1}' -f ($labs -join ', '), $existingNames.Count)

    $characters = ([char[]](48..57) + [char[]](65..90) + [char[]](97..122) + '!', '#', '%', '+', '-', '=')
    # A cryptographic generator, without the bias of a remainder: this is the installation and domain administrator password of the lab.
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    $limit = 256 - (256 % $characters.Count)
    $buffer = New-Object -TypeName 'byte[]' -ArgumentList 1
    $chosen = New-Object -TypeName 'System.Text.StringBuilder'
    while ($chosen.Length -lt 24) {
        $generator.GetBytes($buffer)
        if ($buffer[0] -lt $limit) { $null = $chosen.Append($characters[$buffer[0] % $characters.Count]) }
    }

    $password = 'Aa1!' + $chosen.ToString()

    New-LabDefinition -Name $LabName -DefaultVirtualizationEngine HyperV -VmPath $VmPath
    Add-LabVirtualNetworkDefinition -Name $LabName -AddressSpace $AddressSpace
    Add-LabDomainDefinition -Name $DomainName -AdminUser 'install' -AdminPassword $password
    Set-LabInstallationCredential -Username 'install' -Password $password
    foreach ($definition in $machines) {
        $parameters = @{
            Name = $definition.Name; DomainName = $DomainName; OperatingSystem = $definition.Os; Memory = $definition.Memory
            Processors = 2; Network = $LabName; IpAddress = $definition.Address
        }
        if ($definition.Roles.Count -gt 0) { $parameters.Roles = $definition.Roles }
        if ($definition.Os -like 'Windows 11*') {
            $parameters.HypervProperties = @{ EnableSecureBoot = 'On'; SecureBootTemplate = 'MicrosoftWindows'; EnableTpm = 'true' }
        }
        Add-LabMachineDefinition @parameters
    }
    Write-Step 'lab defined; installing network switches and base images'

    Install-Lab -NetworkSwitches -BaseImages
    Write-Step 'network switches and base images done'
    Install-Lab
    Write-Step 'machines, domain, and roles done'

    $labMachines = Get-LabVM
    Install-LabSoftwarePackage -ComputerName $labMachines -Path $PowerShell7Msi -CommandLine '/quiet /norestart ADD_PATH=1' -Timeout 30
    Write-Step 'PowerShell 7 installed'
    foreach ($modulesRoot in 'C:\Program Files\WindowsPowerShell\Modules', 'C:\Program Files\PowerShell\Modules') {
        $destination = Join-Path $modulesRoot 'Pester'
        Invoke-LabCommand -ComputerName $labMachines -ActivityName 'Create the Pester module directory' -ScriptBlock { param ($Path) $null = New-Item -Path $Path -ItemType Directory -Force } -ArgumentList $destination -NoDisplay
        Copy-LabFileItem -Path $PesterModulePath -ComputerName $labMachines -DestinationFolderPath $destination -Recurse
    }
    Write-Step 'Pester 5.7.1 copied'
    Show-LabDeploymentSummary -Summary
    Write-Step "deploy-os-matrix-lab-DONE"
    exit 0
}
catch {
    Write-Step ("deploy-os-matrix-lab-FAILED: {0}" -f $_)
    $_ | Format-List -Property * -Force | Out-String | Add-Content -LiteralPath $LogPath
    exit 1
}
