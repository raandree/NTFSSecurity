# Live tests in a lab

The tests in this folder run the module against a Windows file server with
domain accounts, in an [AutomatedLab](https://automatedlab.org) lab. They cover
the cases that depend on the file server or on the accounts, which the tests in
`Tests` can't cover: those run on one computer, against local folders, with
local and well-known accounts. CI doesn't run the tests in this folder, and
without a lab they skip every test.

## Cases

| Case | Role | What the tests check |
| --- | --- | --- |
| 1, [#34][issue-34] | Delegate | `Add-NTFSAccess`, `Remove-NTFSAccess`, `Clear-NTFSAccess`, `Disable-NTFSAccessInheritance`, `Enable-NTFSAccessInheritance`, `Set-NTFSInheritance`, and `Set-NTFSSecurityDescriptor` on share folders that Administrators own and on which a domain group has Full Control, run by a member of that group who isn't an administrator of the file server. They succeed and keep the owner. |
| 2 | Admin, ServerAdmin, Delegate | `Get-NTFSAudit`, `Add-NTFSAudit`, and `Remove-NTFSAudit` on share folders. Over SMB, the file server checks the Security privilege of the account. The administrators of the file server read and change the audit entries; the delegated account gets the errors that the cmdlet pages describe, and the folders stay unchanged. |
| 3 | Admin, Delegate | `Get-NTFSEffectiveAccess` for a domain account with rights through two nested domain groups and through a local group of the file server. With `-ServerName`, the result includes the local group, without a warning; without it, the client doesn't know that group. With an unreachable server, the cmdlet falls back to the client and warns. The authorization manager of the file server refuses the delegated account, which isn't an administrator there, and the cmdlet reports that as an error, not as no access. |
| 4 | Admin | `Get-NTFSOrphanedAccess` returns the entry of a deleted domain account with its SID, on the folder and as inherited entry on a file in it; `Get-NTFSOrphanedAudit` returns the audit entry of that account. |
| 5 | Admin, ServerAdmin, Delegate | `Get-NTFSOwner` and `Set-NTFSOwner` on share folders that Administrators own. Every role makes itself the owner; only the administrators of the file server, which hold the Restore privilege there, assign another account. The delegated account gets a `SetOwnerError`, and the owner stays. |
| 6 | Admin, ServerAdmin, Delegate | `Disable-NTFSAuditInheritance`, `Enable-NTFSAuditInheritance`, `Clear-NTFSAudit`, and `Get-NTFSInheritance` on share folders that inherit an audit entry. The administrators of the file server change the audit entries; the delegated account gets the errors that the cmdlet pages describe, and `Get-NTFSInheritance` reports no audit state for it. |
| 7 | Delegate | `Get-Item2`, `Test-Path2`, `Get-FileHash2`, `Copy-Item2`, `Move-Item2`, `Remove-Item2`, and `Get-ChildItem2` in a share folder, including the first hidden file with `-Hidden` and without explicit `-Force`. |
| 8 | Admin | `New-NTFSHardLink`, `Get-NTFSHardLink`, and `New-NTFSSymbolicLink` in a share folder. Windows can't list the names of a file on a share, so `Get-NTFSHardLink` and `New-NTFSHardLink -PassThru` write the `GetHardLinkError` that their pages describe. |
| 9 | Delegate, Admin | `Get-NTFSSimpleAccess` compares a share folder with its parent. For the accounts of another domain and of other forests, `Get-NTFSAccess` returns their names, `Get-NTFSOrphanedAccess` doesn't report them, `Add-NTFSAccess` and `Remove-NTFSAccess` find them by name, and `Get-NTFSEffectiveAccess -ServerName` returns the rights that the file server's own token of each account gets. |
| Long paths | Admin | `Get-ChildItem2` and `Get-NTFSAccess` with a share path longer than 260 characters. |
| [#108][issue-108] | Admin | `Copy-Item2` and `Move-Item2` with `-WhatIf` onto an existing file on the share write no error. |
| State | Server | After the runs on the client, the file server checks the owners, the audit entries, the items, the links, and the entries of the foreign accounts itself, without the module. |

Case 1 uses two kinds of folders. Before 5.0.0-rc3, the cmdlets wrote back the
owner that Windows returns with a DACL without the auto-inherit flag, and the
file server refused it with error 1307, "This security ID may not be assigned
as the owner of this object". Windows sets that flag whenever it writes a DACL
with `SetNamedSecurityInfo`, so the fixture stores the DACL of one kind of
folders again with `SetFileSecurity`, without the flag, like tools that predate
Windows 2000. `Set-NTFSSecurityDescriptor` wrote the owner on both kinds.

The expected rights of case 3 come from the tokens that the file server and the
client create for the account with a Kerberos S4U logon, the way the Effective
Access tab of the advanced security settings does. Case 9 calculates the rights
of the foreign accounts the same way, on the file server.

## Roles

| Role | Account | Administrator of the client | Administrator of the file server |
| --- | --- | --- | --- |
| Delegate | `NtfsLiveDelegate`, member of `NtfsLiveDelegates` | Yes | No |
| ServerAdmin | `NtfsLiveServerAdmin`, member of Remote Management Users on the client | No | Yes |
| Admin | `NtfsLiveAdmin` | Yes | Yes |
| Server | The installation account of the lab, on the file server | Yes | Yes |

The script also creates `NtfsLiveSubject`, the account of case 3, which is a
member of `NtfsLiveInner`, a member of `NtfsLiveOuter`, and of the local group
`NtfsLiveLocal` of the file server, and `NtfsLiveOrphan`, which it deletes in
every run. For case 9, it creates `NtfsLiveForeign` in the organizational unit
`NTFSSecurityLive` of each domain of `-ForeignDomainController`.

## Lab

The lab needs a domain controller, a file server, and a client of one domain,
PowerShell 7 and Pester 5.7.1 on the client and the file server, and
remoting with CredSSP from the host, which AutomatedLab sets up. The defaults
use the lab of
[WindowsAccessControl](https://github.com/raandree/WindowsAccessControl), which
`tests/Lab/Deploy-WindowsAccessControlLab.ps1` in that repository deploys:
`F1ADC1` as domain controller, `F1AFile2` as file server, and `F1AFile1` as
client, all in `a.forest1.net`. `-DomainController`, `-FileServer`, and
`-Client` select other machines. Case 9 uses `F1BDC1` of `b.forest1.net`, a
domain of the same forest, and `F2DC1` and `F3DC1` of the forests
`forest2.net` and `forest3.net`, which have forest trusts with `forest1.net`;
`-ForeignDomainController @()` leaves it out.

The script adds to the lab:

- the organizational unit `NTFSSecurityLive` with the accounts and groups, and
  with `NtfsLiveForeign` in the domains of the foreign domain controllers
- the local group `NtfsLiveLocal` and members of Administrators on the file
  server, and members of Administrators and Remote Management Users on the
  client
- the share `NTFSSecurityLive` on `C:\NTFSSecurityLive` of the file server,
  with a folder for each run
- the folder `C:\NTFSSecurityLab` with the tests on the file server, and with
  the modules and the tests on the client

## Run the tests

In an elevated Windows PowerShell 5.1 session on the Hyper-V host of the lab:

```powershell
.\Tests\Lab\Invoke-NTFSSecurityLabTest.ps1 -Version 5.0.0-rc2, 5.0.0-rc4 -Confirm:$false
```

The script downloads each version from the PowerShell Gallery, checks the hash
that the gallery publishes, and runs the tests for each version in Windows
PowerShell 5.1 and PowerShell 7. Each version runs in its own process, because
all versions of `NTFSSecurity.dll` have the same assembly version. To test a
build, add `-ModulePath .\NTFSSecurity\bin\Release`; it runs as the version
`local`.

The script sets new random passwords for the accounts in every call and keeps
them in memory only. The tests refuse to run on a computer other than the
client and the file server of the configuration, and on a folder outside the
share.

Remove everything the script added to the lab:

```powershell
.\Tests\Lab\Invoke-NTFSSecurityLabTest.ps1 -RemoveFixture
```

## Results

Each call writes to a new folder in `$env:TEMP\NTFSSecurityLab\Results`:

- `Summary.md` and `Summary.json`: the counts per version, edition, and role,
  and the failed tests with their messages
- `<run>-<role>.result.json` and `<run>-<role>.log`: the result and the
  error message of each test that ran, and the output of Pester
- `<run>.json`: the configuration of the run
- `<run>-State.json`: the stored owner, group, and DACL, and the SACL of each
  folder after the run

A version before 5.0.0-rc3 fails case 1 with error 1307, a version before
5.0.0-rc4 fails the tests of #108, a version before 5.0.0-rc5 fails the
test of case 3 with a computer that can't be reached: it returned no access
instead of the result of the client. A version before 5.0.0-rc6 fails two
tests of case 8: `Get-NTFSHardLink` and `New-NTFSHardLink -PassThru` stopped
on the share with the terminating error (50).

## Acceptance of a release candidate

Before a release, run the live tests once more under controlled conditions
and record the evidence in this folder:

1. Build the candidate once, package it with
   `.github\scripts\New-ModulePackage.ps1`, and record the SHA-256 of the
   packages and of the module files.
2. Check that WinRM, LDAP, Kerberos, the secure channel, and the clocks of
   the lab machines work.
3. Take a checkpoint of the machines, named after the candidate and its
   commit.
4. Run the tests with `-ModulePath` of the extracted `NTFSSecurity.zip` in
   both editions.
5. Remove the fixture with `-RemoveFixture` and check that its accounts,
   share, folders, group memberships, and profiles are gone.

Records: [5.0.0-rc6](Acceptance-2026-10-08-5.0.0-rc6.md),
[5.0.0-rc7](Acceptance-2026-10-08-5.0.0-rc7.md), and
[quality-gate follow-up](Acceptance-2026-10-09-quality-gate.md). The review
of the code that no unit test visits, with the fixes that the lab has to
repeat, is in
[Tests/Coverage](../Coverage/Quality-Gate-Paths-2026-10-09.md).

## Files

| File | Purpose |
| --- | --- |
| `Invoke-NTFSSecurityLabTest.ps1` | Prepares the lab, runs the tests, and writes the results; runs on the host. |
| `NTFSSecurity.Live.Tests.ps1` | The tests; run on the client and the file server. |
| `Start-NTFSSecurityLiveTest.ps1` | Runs the tests of one role in a new process. |
| `NTFSSecurity.LabHelpers.ps1` | Reads and writes security descriptors as Windows stores them, and calculates the expected rights. |

[issue-34]: https://github.com/raandree/NTFSSecurity/issues/34
[issue-108]: https://github.com/raandree/NTFSSecurity/issues/108
