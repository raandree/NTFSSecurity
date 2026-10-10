[CmdletBinding()]
param (
    [Parameter(Mandatory)] [ValidateSet('Snapshot', 'Verify', 'Repair')] [string] $Mode,
    [Parameter(Mandatory)] [string] $SidFile,
    [Parameter(Mandatory)] [string] $OutFile,
    [string] $LabName = 'NtfsSecurityOsMatrixLab',
    [string[]] $DomainController = @('OSDC1'),
    [string[]] $Machine = @('OSFile19', 'OSFile22', 'OSFile25', 'OSWin11E')
)

# Independent end-state check of the fixture of Invoke-NTFSSecurityLabTest.ps1 in a lab (Windows PowerShell 5.1, on the host). Snapshot
# records the SIDs of the NtfsLive* accounts while the fixture exists. Verify reads the domains and every machine again, and reports
# the organizational unit, the accounts, the share, the folders, the local group, the memberships of Administrators, Access Control
# Assistance Operators, and Remote Management Users, and the profiles of those SIDs, and what the suite runs and the probes of the kit leave
# behind (scheduled tasks, items in the stage folders, the folders of the account probe, standard users NtfsProbe* with their profiles and their
# entries in Performance Log Users, probe accounts of the domain). The result is judged from this log, never from the wrapper of the controller
# or a global error count. Repair is for a run whose removal failed: with the SIDs of the snapshot, it removes what that run left on the machines
# (the memberships, also of orphaned SIDs, which net localgroup deletes by SID; the share; the local group; the folders) and what the kit leaves
# (the items in the stage folders, the folders of the account probe, the scheduled tasks NtfsMatrix*, the standard users NtfsProbe* with their
# profiles and their entries in Performance Log Users, and the domain accounts NtfsProbe*), and then reports like Verify.
& {
    $ErrorActionPreference = 'Stop'
    # -File passes an array as one string, so a list may arrive as 'A,B'.
    $DomainController = @($DomainController | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
    $Machine = @($Machine | ForEach-Object -Process { $_ -split ',' } | Where-Object -FilterScript { $_ })
    '[{0:yyyy-MM-dd HH:mm:ss}Z] START matrix-cleanup-{1} lab={2}' -f [DateTime]::UtcNow, $Mode, $LabName
    Import-Lab -Name $LabName -NoValidation -NoDisplay
    $labCommand = @{ NoDisplay = $true; PassThru = $true; ErrorAction = 'Stop' }
    if ($Mode -eq 'Repair') {
        # The accounts that the probes of the kit create in the domain, by their prefix; this runs before the directory is read, so that the report shows the result.
        $repairDirectoryScript = {
            Import-Module -Name ActiveDirectory
            $domain = Get-ADDomain
            $objects = @(Get-ADObject -LDAPFilter '(sAMAccountName=NtfsProbe*)' -SearchBase $domain.DistinguishedName -Server $domain.PDCEmulator)
            foreach ($object in $objects) { Remove-ADObject -Identity $object -Recursive -Confirm:$false -Server $domain.PDCEmulator }
            '{0}: removed {1} account(s) named NtfsProbe*' -f $domain.DNSRoot, $objects.Count
        }

        foreach ($name in $DomainController) {
            foreach ($message in @(Invoke-LabCommand -ComputerName $name -ActivityName "Repair the directory of $name" -ScriptBlock $repairDirectoryScript @labCommand)) {
                '{0,-9} repair: {1}' -f $name, $message
            }
        }
    }

    $directoryScript = {
        Import-Module -Name ActiveDirectory
        $domain = Get-ADDomain
        $unit = Get-ADOrganizationalUnit -LDAPFilter '(ou=NTFSSecurityLive)' -SearchBase $domain.DistinguishedName -SearchScope OneLevel -Server $domain.PDCEmulator
        [pscustomobject]@{
            Domain        = $domain.DNSRoot
            Unit          = [bool] $unit
            Sids          = @(Get-ADObject -LDAPFilter '(sAMAccountName=NtfsLive*)' -SearchBase $domain.DistinguishedName -Server $domain.PDCEmulator -Properties objectSid, sAMAccountName |
                    ForEach-Object -Process { '{0}={1}' -f $_.sAMAccountName, $_.objectSid.Value })
            ProbeAccounts = @(Get-ADObject -LDAPFilter '(sAMAccountName=NtfsProbe*)' -SearchBase $domain.DistinguishedName -Server $domain.PDCEmulator).Count
        }
    }

    $directory = @(foreach ($name in $DomainController) { Invoke-LabCommand -ComputerName $name -ActivityName "Read the fixture of $name" -ScriptBlock $directoryScript @labCommand })
    foreach ($state in $directory) {
        '{0,-14} OU NTFSSecurityLive: {1,-5} NtfsLive* accounts: {2}; probe accounts: {3}' -f $state.Domain, $state.Unit, ($(if ($state.Sids) { $state.Sids -join ', ' } else { 'none' })), $state.ProbeAccounts
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

            # What the account probe leaves: the profiles and the profile folders of its users, and its entries in Performance Log Users. net.exe lists a
            # local user by its bare name, and an entry of a deleted domain account as its SID, or as its name for a while (the cache of names).
            $usersFolder = Join-Path -Path $env:SystemDrive -ChildPath 'Users'
            $probePaths = @(@(Get-CimInstance -ClassName Win32_UserProfile | Where-Object -FilterScript { $_.LocalPath -like (Join-Path -Path $usersFolder -ChildPath 'NtfsProbe*') } | ForEach-Object -Process { $_.LocalPath }) +
                @(Get-ChildItem -LiteralPath $usersFolder -Filter 'NtfsProbe*' -Force -ErrorAction SilentlyContinue | ForEach-Object -Process { $_.FullName }) | Sort-Object -Unique)
            $logGroup = ([System.Security.Principal.SecurityIdentifier] 'S-1-5-32-559').Translate([System.Security.Principal.NTAccount]).Value -replace '^.*\\', ''
            $probeMembers = @(& net.exe localgroup $logGroup 2>&1 | ForEach-Object -Process { "$_".Trim() } | Where-Object -FilterScript { $_ -match '^S-1-5-21-[\d-]+$' -or $_ -match 'NtfsProbe' })

            [pscustomobject]@{
                Share         = [bool] (Get-SmbShare -Name 'NTFSSecurityLive' -ErrorAction SilentlyContinue)
                ShareRoot     = Test-Path -LiteralPath 'C:\NTFSSecurityLive'
                Payload       = Test-Path -LiteralPath 'C:\NTFSSecurityLab'
                LocalGroup    = [bool] (Get-LocalGroup -Name 'NtfsLiveLocal' -ErrorAction SilentlyContinue)
                Groups        = $groups -join '; '
                Profiles      = @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object -FilterScript { $_.SID -in $Sid }).Count
                # What the suite runs and the probes of the kit leave behind: scheduled tasks, items in the stage folders, the folders of the
                # account probe, and standard users
                Tasks         = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.TaskName -like 'NtfsMatrix*' }).Count
                Stages        = @('C:\NtfsMatrixLocal', 'C:\NtfsMatrixProbe' | Where-Object -FilterScript { Test-Path -LiteralPath $_ } | ForEach-Object -Process { Get-ChildItem -LiteralPath $_ -Force -ErrorAction SilentlyContinue }).Count +
                @('C:\NtfsProbeRecreation', 'C:\NtfsProbeModules' | Where-Object -FilterScript { Test-Path -LiteralPath $_ }).Count
                Users         = @(Get-LocalUser -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.Name -like 'NtfsProbe*' }).Count
                ProbeProfiles = $probePaths.Count
                ProbeMembers  = $probeMembers.Count
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

                    # What the suite runner and the probes of the kit left: the items in their stage folders, the folders of the account probe,
                    # their scheduled tasks, and the standard users that the probe of the authorization managers creates (with their profiles)
                    foreach ($stage in 'C:\NtfsMatrixLocal', 'C:\NtfsMatrixProbe') {
                        if (Test-Path -LiteralPath $stage) { Get-ChildItem -LiteralPath $stage -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
                    }

                    foreach ($folder in 'C:\NtfsProbeRecreation', 'C:\NtfsProbeModules') {
                        if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue }
                    }

                    Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.TaskName -like 'NtfsMatrix*' } | ForEach-Object -Process { Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue }
                    foreach ($user in @(Get-LocalUser -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.Name -like 'NtfsProbe*' })) { Remove-LocalUser -SID $user.SID -ErrorAction SilentlyContinue }

                    # The entries of the probe in Performance Log Users go by SID or name through the cmdlet: net.exe doesn't take the SID of an account that its name cache still resolves.
                    $logGroup = ([System.Security.Principal.SecurityIdentifier] 'S-1-5-32-559').Translate([System.Security.Principal.NTAccount]).Value -replace '^.*\\', ''
                    foreach ($member in @(& net.exe localgroup $logGroup 2>&1 | ForEach-Object -Process { "$_".Trim() } | Where-Object -FilterScript { $_ -match '^S-1-5-21-[\d-]+$' -or $_ -match 'NtfsProbe' })) {
                        Remove-LocalGroupMember -SID 'S-1-5-32-559' -Member $member -ErrorAction SilentlyContinue
                    }

                    # A profile that the last task of a probe user used stays loaded for a few seconds, so the removal is repeated. What stays is
                    # reported by the check that follows, found by its folder and not by its user, who is gone by now.
                    $usersFolder = Join-Path -Path $env:SystemDrive -ChildPath 'Users'
                    $attempt = 0
                    do {
                        $attempt++
                        @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object -FilterScript { $_.LocalPath -like (Join-Path -Path $usersFolder -ChildPath 'NtfsProbe*') }) | Remove-CimInstance -ErrorAction SilentlyContinue
                        Get-ChildItem -LiteralPath $usersFolder -Filter 'NtfsProbe*' -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                        $left = @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object -FilterScript { $_.LocalPath -like (Join-Path -Path $usersFolder -ChildPath 'NtfsProbe*') }).Count +
                        @(Get-ChildItem -LiteralPath $usersFolder -Filter 'NtfsProbe*' -Force -ErrorAction SilentlyContinue).Count
                        if ($left -gt 0 -and $attempt -lt 10) { Start-Sleep -Seconds 3 }
                    } while ($left -gt 0 -and $attempt -lt 10)

                    $messages.Add(('stage items, probe folders, probe users, their entries in the log group, and scheduled tasks of the kit removed; profile items left: {0} after {1} attempt(s)' -f $left, $attempt))

                    $messages
                }

                foreach ($message in @(Invoke-LabCommand -ComputerName $name -ActivityName "Repair $name" -ScriptBlock $repairScript -ArgumentList (, $sids) @labCommand)) {
                    '{0,-9} repair: {1}' -f $name, $message
                }
            }

            $state = Invoke-LabCommand -ComputerName $name -ActivityName "Check $name" -ScriptBlock $machineScript -ArgumentList (, $sids) @labCommand
            '{0,-9} share={1} C:\NTFSSecurityLive={2} C:\NTFSSecurityLab={3} NtfsLiveLocal={4} profiles={5}' -f $name, $state.Share, $state.ShareRoot, $state.Payload, $state.LocalGroup, $state.Profiles
            '          {0}' -f $state.Groups
            '          residue: scheduled tasks={0} stage items={1} probe users={2} probe profiles={3} probe group members={4}' -f $state.Tasks, $state.Stages, $state.Users, $state.ProbeProfiles, $state.ProbeMembers
        }
    }

    '[{0:yyyy-MM-dd HH:mm:ss}Z] matrix-cleanup-{1}-DONE' -f [DateTime]::UtcNow, $Mode
} *>&1 | Out-File -FilePath $OutFile -Encoding utf8 -Width 400
