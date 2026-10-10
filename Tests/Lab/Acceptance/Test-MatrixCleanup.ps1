[CmdletBinding()]
param (
    [Parameter(Mandatory)] [ValidateSet('Snapshot', 'Verify', 'Repair')] [string] $Mode,
    [Parameter(Mandatory)] [string] $SidFile,
    [Parameter(Mandatory)] [string] $OutFile,
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [string[]] $DomainController = @('OSDC1'),
    [string[]] $Machine = @('OSFile19', 'OSFile22', 'OSFile25', 'OSWin11')
)

# Independent end-state check of the fixture of Invoke-NTFSSecurityLabTest.ps1 in a lab (Windows PowerShell 5.1, on the host). Snapshot
# records the SIDs of the NtfsLive* accounts while the fixture exists. Verify reads the domains and every machine again, and reports
# the organizational unit, the accounts, the share, the folders, the local group, the memberships of Administrators, Access Control
# Assistance Operators, and Remote Management Users, and the profiles of those SIDs. The result is judged from this log, never from
# the wrapper of the controller or a global error count. Repair is for a run whose removal failed: with the SIDs of the snapshot, it
# removes what that run left on the machines (the memberships, also of orphaned SIDs, which net localgroup deletes by SID; the share; the
# local group; the folders) and then reports like Verify.
& {
    $ErrorActionPreference = 'Stop'
    # -File passes an array as one string, so a list may arrive as 'A,B'.
    $DomainController = @($DomainController | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
    $Machine = @($Machine | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
    '[{0:yyyy-MM-dd HH:mm:ss}Z] START matrix-cleanup-{1} lab={2}' -f [DateTime]::UtcNow, $Mode, $LabName
    Import-Lab -Name $LabName -NoValidation -NoDisplay
    $labCommand = @{ NoDisplay = $true; PassThru = $true; ErrorAction = 'Stop' }
    $directoryScript = {
        Import-Module -Name ActiveDirectory
        $domain = Get-ADDomain
        $unit = Get-ADOrganizationalUnit -LDAPFilter '(ou=NTFSSecurityLive)' -SearchBase $domain.DistinguishedName -SearchScope OneLevel -Server $domain.PDCEmulator
        [pscustomobject]@{
            Domain = $domain.DNSRoot
            Unit   = [bool] $unit
            Sids   = @(Get-ADObject -LDAPFilter '(sAMAccountName=NtfsLive*)' -SearchBase $domain.DistinguishedName -Server $domain.PDCEmulator -Properties objectSid, sAMAccountName |
                    ForEach-Object -Process { '{0}={1}' -f $_.sAMAccountName, $_.objectSid.Value })
        }
    }

    $directory = @(foreach ($name in $DomainController) { Invoke-LabCommand -ComputerName $name -ActivityName "Read the fixture of $name" -ScriptBlock $directoryScript @labCommand })
    foreach ($state in $directory) {
        '{0,-14} OU NTFSSecurityLive: {1,-5} NtfsLive* accounts: {2}' -f $state.Domain, $state.Unit, ($(if ($state.Sids) { $state.Sids -join ', ' } else { 'none' }))
    }

    if ($Mode -eq 'Snapshot') {
        $sids = @($directory | ForEach-Object -Process { $_.Sids } | ForEach-Object -Process { ($_ -split '=', 2)[1] })
        ConvertTo-Json -InputObject $sids | Set-Content -LiteralPath $SidFile -Encoding utf8
        "saved $($sids.Count) SIDs to $SidFile"
    }
    else {
        $sids = [string[]] (Get-Content -LiteralPath $SidFile -Raw | ConvertFrom-Json)
        "checking $($sids.Count) SIDs of the snapshot"
        $machineScript = {
            param ($Sid)
            # net localgroup lists an orphaned SID, which Get-LocalGroupMember in Windows PowerShell 5.1 fails on and skips.
            $groups = foreach ($groupSid in 'S-1-5-32-544', 'S-1-5-32-579', 'S-1-5-32-580') {
                $groupName = ([System.Security.Principal.SecurityIdentifier] $groupSid).Translate([System.Security.Principal.NTAccount]).Value -replace '^.*\\', ''
                $members = @(& net.exe localgroup $groupName 2>&1 | ForEach-Object -Process { "$_".Trim() })
                $hits = @($members | Where-Object -FilterScript { $_ -match 'NtfsLive' -or $_ -in $Sid })
                '{0}: {1} fixture member(s)' -f $groupSid, $hits.Count
            }

            [pscustomobject]@{
                Share      = [bool] (Get-SmbShare -Name 'NTFSSecurityLive' -ErrorAction SilentlyContinue)
                ShareRoot  = Test-Path -LiteralPath 'C:\NTFSSecurityLive'
                Payload    = Test-Path -LiteralPath 'C:\NTFSSecurityLab'
                LocalGroup = [bool] (Get-LocalGroup -Name 'NtfsLiveLocal' -ErrorAction SilentlyContinue)
                Groups     = $groups -join '; '
                Profiles   = @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object -FilterScript { $_.SID -in $Sid }).Count
            }
        }

        foreach ($name in $Machine) {
            if ($Mode -eq 'Repair') {
                $repairScript = {
                    param ($Sid)
                    $messages = New-Object -TypeName 'System.Collections.Generic.List[string]'
                    foreach ($groupSid in 'S-1-5-32-544', 'S-1-5-32-579', 'S-1-5-32-580') {
                        $groupName = ([System.Security.Principal.SecurityIdentifier] $groupSid).Translate([System.Security.Principal.NTAccount]).Value -replace '^.*\\', ''
                        $named = @(& net.exe localgroup $groupName 2>&1 | ForEach-Object -Process { "$_".Trim() } | Where-Object -FilterScript { $_ -match 'NtfsLive' })
                        foreach ($member in @($Sid) + $named) { $null = & net.exe localgroup $groupName $member /delete 2>&1 }
                    }

                    if (Get-SmbShare -Name 'NTFSSecurityLive' -ErrorAction SilentlyContinue) { Remove-SmbShare -Name 'NTFSSecurityLive' -Force }
                    $null = & net.exe localgroup 'NtfsLiveLocal' /delete 2>&1
                    foreach ($path in 'C:\NTFSSecurityLive', 'C:\NTFSSecurityLab') {
                        $command = '$errors = @(); Remove-Item -LiteralPath ''__PATH__'' -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable errors; $errors | ForEach-Object -Process { "$_" }'.Replace('__PATH__', $path)
                        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
                        $attempt = 0
                        while ((Test-Path -LiteralPath $path) -and $attempt -lt 6) {
                            $attempt++
                            if ($attempt -gt 1) { Start-Sleep -Seconds 5 }
                            $null = & (Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe') -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
                        }

                        $messages.Add(('{0}: present after {1} attempt(s): {2}' -f $path, $attempt, (Test-Path -LiteralPath $path)))
                    }

                    $messages
                }

                foreach ($message in @(Invoke-LabCommand -ComputerName $name -ActivityName "Repair $name" -ScriptBlock $repairScript -ArgumentList (, $sids) @labCommand)) {
                    '{0,-9} repair: {1}' -f $name, $message
                }
            }

            $state = Invoke-LabCommand -ComputerName $name -ActivityName "Check $name" -ScriptBlock $machineScript -ArgumentList (, $sids) @labCommand
            '{0,-9} share={1} C:\NTFSSecurityLive={2} C:\NTFSSecurityLab={3} NtfsLiveLocal={4} profiles={5}' -f $name, $state.Share, $state.ShareRoot, $state.Payload, $state.LocalGroup, $state.Profiles
            '          {0}' -f $state.Groups
        }
    }

    '[{0:yyyy-MM-dd HH:mm:ss}Z] matrix-cleanup-{1}-DONE' -f [DateTime]::UtcNow, $Mode
} *>&1 | Out-File -FilePath $OutFile -Encoding utf8 -Width 400
