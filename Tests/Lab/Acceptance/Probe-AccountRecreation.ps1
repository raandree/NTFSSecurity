[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string[]] $ModulePath,
    [Parameter(Mandatory)] [string] $OutFile,
    [string] $Client = 'OSWin11E',
    [string] $DomainController = 'OSDC1',
    [string] $FileServer = 'OSFile22',
    [ValidateRange(2, 20)] [int] $Rounds = 4,
    [string] $LabName = 'NtfsSecurityOsMatrixLab'
)

# Probe of the groups that a computer reports for an account that was deleted and created again with the same name (Decision 24). In each
# round it creates a user in a group that is in another group, with the same names and new SIDs, and a folder on the file server whose DACL
# grants the outer group ReadAndExecute. Then it logs the user on with Kerberos S4U, like the oracle of the live tests does, on the domain
# controller, the client, and the file server, and asks from the client, in a new process for each module, for the effective access of the
# account on the folder by name and by SID, with the default server name and with the name of the file server. -ModulePath takes module
# folders as label=path, such as baseline=C:\Build\NTFSSecurity. From the second round on, a computer that still holds the deleted account
# reports its SID, and every module reports no access (Synchronize only), whichever its version. The probe removes everything it created; the
# accounts, the folder, and the files on the client are named NtfsProbe*, so Test-MatrixCleanup.ps1 reports a leftover. The password of the
# user is random and exists only in memory. Windows PowerShell 5.1 on the Hyper-V host, with AutomatedLab.
& {
    $ErrorActionPreference = 'Stop'
    # -File passes an array as one string, so a list may arrive as 'A,B'.
    $modules = @(
        foreach ($entry in @($ModulePath | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })) {
            $label, $path = $entry -split '=', 2
            if (-not $path -or -not (Test-Path -LiteralPath (Join-Path -Path $path -ChildPath 'NTFSSecurity.psd1'))) { throw "-ModulePath takes label=folder with a module; '$entry' has none." }
            [pscustomobject]@{ Label = $label; Path = $path }
        }
    )
    Import-Module -Name AutomatedLab -ErrorAction Stop
    Import-Lab -Name $LabName -NoValidation -NoDisplay
    $domainName = (Get-Lab).Domains[0].Name
    $netBiosName = $domainName.Split('.')[0].ToUpperInvariant()
    $dcSession = New-LabPSSession -ComputerName $DomainController
    $clientSession = New-LabPSSession -ComputerName $Client
    $serverSession = New-LabPSSession -ComputerName $FileServer
    $machines = [ordered]@{ $DomainController = $dcSession; $Client = $clientSession; $FileServer = $serverSession }
    $userName = 'NtfsProbeSubject'
    $innerName = 'NtfsProbeInner'
    $outerName = 'NtfsProbeOuter'
    $folderName = 'NtfsProbeRecreation'
    $stageName = 'C:\NtfsProbeModules'
    $report = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $bytes = New-Object -TypeName 'byte[]' -ArgumentList 24
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
    # Base64 has upper case and lower case letters and digits; the suffix adds the other classes of a domain's complexity rules.
    $secret = New-Object -TypeName 'System.Security.SecureString'
    foreach ($character in ([Convert]::ToBase64String($bytes) + '!a1Z').ToCharArray()) { $secret.AppendChar($character) }
    $secret.MakeReadOnly()

    $removeOnDcScript = {
        param ($User, $Inner, $Outer)
        Import-Module -Name ActiveDirectory
        foreach ($name in $User) { Get-ADUser -Filter "SamAccountName -eq '$name'" | Remove-ADUser -Confirm:$false }
        foreach ($name in $Inner, $Outer) { Get-ADGroup -Filter "SamAccountName -eq '$name'" | Remove-ADGroup -Confirm:$false }
    }
    $createOnDcScript = {
        param ($User, $Inner, $Outer, [securestring] $Secret)
        Import-Module -Name ActiveDirectory
        $null = New-ADGroup -Name $Outer -SamAccountName $Outer -GroupScope Global
        $null = New-ADGroup -Name $Inner -SamAccountName $Inner -GroupScope Global
        Add-ADGroupMember -Identity $Outer -Members $Inner
        $null = New-ADUser -Name $User -SamAccountName $User -UserPrincipalName ('{0}@{1}' -f $User, (Get-ADDomain).DNSRoot) -AccountPassword $Secret -Enabled $true
        Add-ADGroupMember -Identity $Inner -Members $User
        [pscustomobject]@{ User = (Get-ADUser -Identity $User).SID.Value; Outer = (Get-ADGroup -Identity $Outer).SID.Value }
    }
    $setFolderScript = {
        param ($Folder, $OuterSid)
        $path = Join-Path -Path $env:SystemDrive -ChildPath $Folder
        if (-not (Test-Path -LiteralPath $path)) { $null = New-Item -ItemType Directory -Path $path }
        $acl = New-Object -TypeName 'System.Security.AccessControl.DirectorySecurity'
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($entry in @(@('S-1-5-32-544', 'FullControl'), @('S-1-5-18', 'FullControl'), @($OuterSid, 'ReadAndExecute'))) {
            $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList ([Security.Principal.SecurityIdentifier] $entry[0]), $entry[1], 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
        }

        Set-Acl -LiteralPath $path -AclObject $acl
    }
    $tokenScript = {
        param ($User, $Domain, $UserSid, $OuterSid)
        try {
            $identity = New-Object -TypeName 'System.Security.Principal.WindowsIdentity' -ArgumentList ('{0}@{1}' -f $User, $Domain)
            $groups = @($identity.Groups | ForEach-Object -Process { $_.Value })
            'S4U token of the {0} account, outer group {1}' -f $(if ($identity.User.Value -eq $UserSid) { 'CURRENT' } else { 'OLD' }), ($groups -contains $OuterSid)
        }
        catch { 'S4U logon failed: ' + $_.Exception.Message }
    }
    $effectiveScript = {
        param ($ModuleFolder, $Folder, $Server, $Domain, $NetBios, $User, $UserSid)
        Import-Module -Name (Join-Path -Path $ModuleFolder -ChildPath 'NTFSSecurity.psd1') -Force
        $unc = '\\{0}.{1}\C$\{2}' -f $Server, $Domain, $Folder
        $name = '{0}\{1}' -f $NetBios, $User
        function Measure-Answer {
            param ([hashtable] $Arguments)
            $result = @(Get-NTFSEffectiveAccess @Arguments -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable failures)
            $value = if ($result.Count) { '0x{0:X}' -f ([long] $result[0].AccessRights) } else { 'none' }
            if (@($failures).Count) { $value += ' ERR ' + $failures[0].Exception.Message }
            $value
        }

        $serverName = '{0}.{1}' -f $Server, $Domain
        'effective access by name {0}, by name and server {1}, by SID {2}, by SID and server {3}' -f
        (Measure-Answer -Arguments @{ Path = $unc; Account = $name }),
        (Measure-Answer -Arguments @{ Path = $unc; Account = $name; ServerName = $serverName }),
        (Measure-Answer -Arguments @{ Path = $unc; Account = $UserSid }),
        (Measure-Answer -Arguments @{ Path = $unc; Account = $UserSid; ServerName = $serverName })
    }
    $runEffectiveScript = {
        param ($Stage, $ModuleLabel, $ScriptText, $Folder, $Server, $Domain, $NetBios, $User, $UserSid)
        $block = [scriptblock]::Create($ScriptText)
        $powershell = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
        & $powershell -NoProfile -ExecutionPolicy Bypass -Command $block -args (Join-Path -Path $Stage -ChildPath $ModuleLabel), $Folder, $Server, $Domain, $NetBios, $User, $UserSid
    }
    try {
        Invoke-Command -Session $dcSession -ScriptBlock $removeOnDcScript -ArgumentList $userName, $innerName, $outerName
        Invoke-Command -Session $clientSession -ArgumentList $stageName -ScriptBlock { param ($Stage) if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }; $null = New-Item -ItemType Directory -Path $Stage -Force }
        foreach ($module in $modules) {
            Invoke-Command -Session $clientSession -ArgumentList (Join-Path -Path $stageName -ChildPath $module.Label) -ScriptBlock { param ($Path) $null = New-Item -ItemType Directory -Path $Path -Force }
            Copy-Item -Path (Join-Path -Path $module.Path -ChildPath '*') -Destination (Join-Path -Path $stageName -ChildPath $module.Label) -ToSession $clientSession -Recurse -Force
        }

        for ($round = 1; $round -le $Rounds; $round++) {
            $created = Invoke-Command -Session $dcSession -ScriptBlock $createOnDcScript -ArgumentList $userName, $innerName, $outerName, $secret
            Invoke-Command -Session $serverSession -ScriptBlock $setFolderScript -ArgumentList $folderName, $created.Outer
            $report.Add(('round {0} at {1:HH:mm:ss}Z: subject {2}, outer group {3}' -f $round, [DateTime]::UtcNow, $created.User, $created.Outer))
            foreach ($machine in $machines.Keys) {
                $report.Add(('  {0}: {1}' -f $machine, (Invoke-Command -Session $machines[$machine] -ScriptBlock $tokenScript -ArgumentList $userName, $domainName, $created.User, $created.Outer)))
            }

            # The order of the modules alternates, so that the module that asks first is not always the same.
            $ordered = if ($round % 2) { $modules } else { @($modules)[($modules.Count - 1)..0] }
            foreach ($module in $ordered) {
                $answer = Invoke-Command -Session $clientSession -ArgumentList $stageName, $module.Label, $effectiveScript.ToString(), $folderName, $FileServer, $domainName, $netBiosName, $userName, $created.User -ScriptBlock $runEffectiveScript
                $report.Add(('  {0} on {1}: {2}' -f $module.Label, $Client, (@($answer) -join ' ')))
            }

            Invoke-Command -Session $dcSession -ScriptBlock $removeOnDcScript -ArgumentList $userName, $innerName, $outerName
        }
    }
    finally {
        try { Invoke-Command -Session $dcSession -ScriptBlock $removeOnDcScript -ArgumentList $userName, $innerName, $outerName } catch { $report.Add("cleanup on the domain controller failed: $($_.Exception.Message)") }
        try { Invoke-Command -Session $serverSession -ArgumentList $folderName -ScriptBlock { param ($Folder) Remove-Item -LiteralPath (Join-Path -Path $env:SystemDrive -ChildPath $Folder) -Recurse -Force -ErrorAction SilentlyContinue } } catch { $report.Add("cleanup on the file server failed: $($_.Exception.Message)") }
        try { Invoke-Command -Session $clientSession -ArgumentList $stageName -ScriptBlock { param ($Stage) Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue } } catch { $report.Add("cleanup on the client failed: $($_.Exception.Message)") }
        $report | Set-Content -LiteralPath $OutFile -Encoding utf8
        Remove-PSSession -Session @($machines.Values) -ErrorAction SilentlyContinue
    }

    'done'
}
