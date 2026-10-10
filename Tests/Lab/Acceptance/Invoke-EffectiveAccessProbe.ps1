[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $ModulePath,
    [Parameter(Mandatory)] [string] $OutFile,
    [Parameter(Mandatory)] [string] $Variant,
    [string] $OtherServer = ''
)

# Runs inside a machine of the operating-system matrix, in Windows PowerShell 5.1 under the token that Probe-EffectiveAccess.ps1 chose for
# the variant, and asks Get-NTFSEffectiveAccess the same question in several ways: for the account of the token, Everyone, the local
# Administrator, and the domain Administrator and Domain Users on a computer in a domain, each for the default server name, localhost, an
# empty name, the names of this computer, and the computers of -OtherServer (a comma-separated list). For every call it writes the result,
# the number of warnings, and the native error with the failing method, so that the failing call of the authorization manager shows. It
# changes nothing but a folder below $env:TEMP.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$stamp = '[{0:HH:mm:ss}]'
function Write-Probe { param ([string] $Message) ($stamp -f [DateTime]::UtcNow) + ' ' + $Message | Add-Content -LiteralPath $OutFile }

$null = New-Item -ItemType Directory -Path (Split-Path -Path $OutFile -Parent) -Force
Set-Content -LiteralPath $OutFile -Value ''
try {
    Import-Module -Name (Join-Path -Path $ModulePath -ChildPath 'NTFSSecurity.psd1') -Force -ErrorAction Stop
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName 'Security.Principal.WindowsPrincipal' -ArgumentList $identity
    $current = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Write-Probe ('START variant={0} user={1} sid={2} administrator={3} os={4} {5}.{6} dll={7}' -f $Variant, $identity.Name, $identity.User.Value,
        $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator), $current.ProductName, $current.CurrentBuildNumber, $current.UBR,
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path -Path $ModulePath -ChildPath 'NTFSSecurity.dll')).Hash.Substring(0, 12))
    $groups = @(& whoami.exe /groups /fo csv | ConvertFrom-Csv)
    Write-Probe ('groups={0}; deny only: {1}' -f $groups.Count, ((@($groups | Where-Object -FilterScript { $_.Attributes -match 'deny' } | ForEach-Object -Process { $_.'Group Name' })) -join ', '))
    Write-Probe ('integrity: {0}' -f ((@($groups | Where-Object -FilterScript { $_.'Group Name' -like 'Mandatory Label*' } | ForEach-Object -Process { $_.'Group Name' })) -join ', '))
    $privileges = @(& whoami.exe /priv /fo csv | ConvertFrom-Csv)
    Write-Probe ('privileges present={0} enabled: {1}' -f $privileges.Count, ((@($privileges | Where-Object -FilterScript { $_.State -eq 'Enabled' } | ForEach-Object -Process { $_.'Privilege Name' })) -join ', '))

    $folder = Join-Path -Path $env:TEMP -ChildPath ('probe-{0}' -f [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $folder
    $fqdn = try { [Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName } catch { $env:COMPUTERNAME }
    function Resolve-Sid {
        param ([string] $Name)
        try { (New-Object -TypeName 'Security.Principal.NTAccount' -ArgumentList $Name).Translate([Security.Principal.SecurityIdentifier]).Value } catch { '' }
    }

    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    Write-Probe ('computer {0} domain joined={1} domain={2}' -f $env:COMPUTERNAME, $computer.PartOfDomain, $computer.Domain)
    $accounts = [ordered]@{ 'self' = ''; 'Everyone' = 'S-1-1-0'; 'local Administrator' = (Resolve-Sid -Name ('{0}\Administrator' -f $env:COMPUTERNAME)) }
    if ($computer.PartOfDomain) {
        $accounts['domain Administrator'] = Resolve-Sid -Name ('{0}\Administrator' -f $computer.Domain)
        $accounts['Domain Users'] = Resolve-Sid -Name ('{0}\Domain Users' -f $computer.Domain)
    }

    $servers = [ordered]@{ 'no -ServerName' = $null; 'localhost' = 'localhost'; 'empty name' = ''; 'computer name' = $env:COMPUTERNAME; 'fqdn' = $fqdn }
    foreach ($name in @($OtherServer -split ',' | Where-Object -FilterScript { $_ })) { $servers["other computer $name"] = $name }
    $cases = foreach ($accountName in $accounts.Keys) {
        if ($accountName -ne 'self' -and -not $accounts[$accountName]) { continue }
        foreach ($serverName in $servers.Keys) {
            $arguments = @{}
            if ($accounts[$accountName]) { $arguments.Account = $accounts[$accountName] }
            if ($null -ne $servers[$serverName]) { $arguments.ServerName = $servers[$serverName] }
            @{ Name = ('{0}, {1}' -f $accountName, $serverName); Arguments = $arguments }
        }
    }

    foreach ($case in $cases) {
        $arguments = $case.Arguments
        $errorList = $null
        $warningList = $null
        try {
            $result = @(Get-NTFSEffectiveAccess -Path $folder @arguments -ErrorVariable errorList -WarningVariable warningList -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
        }
        catch {
            $result = @()
            $errorList = @($_)
        }

        $access = if ($result.Count -gt 0) { ('{0}' -f $result[0].AccessRights) } else { 'none' }
        $warnings = @($warningList | ForEach-Object -Process { ('{0}' -f $_.Message) -replace '\s+', ' ' } | ForEach-Object -Process { if ($_.Length -gt 60) { $_.Substring(0, 60) } else { $_ } })
        Write-Probe ('CASE {0}: results={1} access={2} errors={3} warnings={4}' -f $case.Name, $result.Count, $access, @($errorList).Count, $warnings.Count)
        foreach ($record in @($errorList)) {
            $inner = $record.Exception
            while ($inner.InnerException) { $inner = $inner.InnerException }
            $native = if ($inner -is [ComponentModel.Win32Exception]) { $inner.NativeErrorCode } else { '' }
            $frames = (('{0}' -f $inner.StackTrace) -split "`r?`n" | Select-Object -First 1 | ForEach-Object -Process { $_.Trim() -replace '^at ', '' -replace '\(.*$', '' }) -join ' <- '
            Write-Probe ('  ERROR id={0} type={1} native={2} message={3} frames={4}' -f $record.FullyQualifiedErrorId, $inner.GetType().Name, $native, $inner.Message, $frames)
        }
    }

    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    Write-Probe 'DONE'
}
catch {
    Write-Probe ('FAILED: {0}' -f $_)
}
