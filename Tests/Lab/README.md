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
| 3 | Admin, ServerAdmin, Delegate | `Get-NTFSEffectiveAccess` for a domain account with rights through two nested domain groups and through a local group of the file server. With `-ServerName`, the result includes the local group, without a warning; without it, the client doesn't know that group. With an unreachable server, the cmdlet falls back to the client and warns. The authorization manager of the file server refuses the delegated account, which isn't an administrator there, and the cmdlet reports that as an error, not as no access. The administrator of the file server who isn't an administrator of the client gets the result of the client without `-ServerName` and for the name of the client, because the local authorization manager of the client answers when the remote one refuses a user who isn't its administrator. |
| 4 | Admin | `Get-NTFSOrphanedAccess` returns the entry of a deleted domain account with its SID, on the folder and as inherited entry on a file in it; `Get-NTFSOrphanedAudit` returns the audit entry of that account. |
| 5 | Admin, ServerAdmin, Delegate | `Get-NTFSOwner` and `Set-NTFSOwner` on share folders that Administrators own. Every role makes itself the owner; only the administrators of the file server, which hold the Restore privilege there, assign another account. The delegated account gets a `SetOwnerError`, and the owner stays. |
| 6 | Admin, ServerAdmin, Delegate | `Disable-NTFSAuditInheritance`, `Enable-NTFSAuditInheritance`, `Clear-NTFSAudit`, and `Get-NTFSInheritance` on share folders that inherit an audit entry. The administrators of the file server change the audit entries; the delegated account gets the errors that the cmdlet pages describe, and `Get-NTFSInheritance` reports no audit state for it. |
| 7 | Delegate | `Get-Item2`, `Test-Path2`, `Get-FileHash2`, `Copy-Item2`, `Move-Item2`, `Remove-Item2`, and `Get-ChildItem2` in a share folder, including the first hidden file with `-Hidden` and without explicit `-Force`. |
| 8 | Admin | `New-NTFSHardLink`, `Get-NTFSHardLink`, and `New-NTFSSymbolicLink` in a share folder. Windows can't list the names of a file on a share, so `Get-NTFSHardLink` and `New-NTFSHardLink -PassThru` write the `GetHardLinkError` that their pages describe. |
| 9 | Delegate, Admin | `Get-NTFSSimpleAccess` compares a share folder with its parent. For the accounts of another domain and of other forests, `Get-NTFSAccess` returns their names, `Get-NTFSOrphanedAccess` doesn't report them, `Add-NTFSAccess` and `Remove-NTFSAccess` find them by name, and `Get-NTFSEffectiveAccess -ServerName` returns the rights that the file server's own token of each account gets. |
| Long paths | Admin | `Get-ChildItem2` and `Get-NTFSAccess` with a share path longer than 260 characters. |
| [#108][issue-108] | Admin | `Copy-Item2` and `Move-Item2` with `-WhatIf` onto an existing file on the share write no error. |
| 10 | Delegate, ServerAdmin, Admin | The behavior that the quality-gate fixes before 5.0.0 changed, and that the lab can observe. The delegated account, which owns the items it creates, clears and protects the DACL of an item whose OWNER RIGHTS entry denies it the right to change the DACL, and the cmdlets report no `RestoreOwnerError` for the unchanged owner. `InheritedFrom` names an `unknown parent` for entries that Windows can't resolve, for a deleted file and below a folder whose permissions the account can't read, and no source for an explicit entry. A later command that stops the pipeline with `Select-Object -First 1` or throws leaves the second item of `Remove-Item2`, `Copy-Item2`, `Move-Item2`, `Set-NTFSOwner`, and `Set-NTFSSecurityDescriptor` as it was, also when it takes the verbose messages of `Set-NTFSSecurityDescriptor` or the debug messages of `Set-NTFSOwner`, and `Get-FileHash2` writes no error when it takes its verbose messages. `Get-ChildItem2` passes on what a later command throws for the error of a folder it can't read, and a `break` of that command leaves the caller's loop. `Get-ChildItem2 -Filter` finds a name with brackets, returns every item for `*.*`, and rejects `$null`. The privileges that the cmdlets enable are disabled again when a later command stops the pipeline or throws at a debug message. |
| State | Server | After the runs on the client, the file server checks the owners, the audit entries, the items, the links, the entries of the foreign accounts, and which items a later command changed, itself, without the module. |

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

The script also creates the account of case 3, `NtfsLiveSubject` followed by
four digits, which is a member of `NtfsLiveInner`, a member of `NtfsLiveOuter`,
and of the local group `NtfsLiveLocal` of the file server, and `NtfsLiveOrphan`,
which it deletes in every run. For case 9, it creates `NtfsLiveForeign` in the
organizational unit `NTFSSecurityLive` of each domain of
`-ForeignDomainController`.

A new fixture gets a new name for the account of case 3. In the matrix lab, the
authorization managers that `Get-NTFSEffectiveAccess` asks for a remote computer
(the one of the client by the default `-ServerName`, the one of the file server
by its name) answered for about ten minutes as if an account had no groups when
the account was deleted and created again under the same name, so cells that
followed each other failed in the effective-access tests, for the baseline and
for the final candidate alike. The Kerberos logon that the tests use as the
oracle, and the
local authorization manager, were right in the same second. The mechanism in
Windows isn't known (see the record of the operating-system matrix). A fixture
that exists keeps its account, so the runs of one fixture use one name.

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

The operating-system matrix has a lab of its own, `NtfsSecurityOsMatrixLab`,
on the same host. `Acceptance\Deploy-OsMatrixLab.ps1` deploys it in AutomatedLab
without touching another lab: `OSDC1` (Windows Server 2025), the domain
controller of the domain `osmatrix.net`, the file servers `OSFile19`,
`OSFile22`, and `OSFile25` (Windows Server 2019, 2022, and 2025), the client
`OSWin11E` (Windows 11 Enterprise Evaluation 22H2), and `OSWin11` (Windows 11 Pro
26H1), on a switch of their own, `192.168.12.0/24`. `OSWin11` can't keep a
secure channel to the domain controller, so it runs the suite of the module
only (`Run-MatrixLocalSuite.ps1`, below). The evaluation image of `OSWin11E`
shuts down an hour after each start, because its license period has ended: start
it shortly before a run and keep a run under an hour. The lab has no trust with
another forest, so case 9 runs only in the first lab and the matrix runs use
`-ForeignDomainController @()`.

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
on the share with the terminating error (50). A build without the fixes of the
quality gate before 5.0.0 fails case 10 and the matching test of the State
role: 74 of the 244 tests of each edition (see the
[record of that run](Acceptance-2026-10-09-quality-gate-paths.md)).

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

A run with `-ModulePath` validates a build. The acceptance of a release is the
run with `-Version` of the exact prerelease on the PowerShell Gallery, as
`Docs\Contributing\05-Releasing.md` describes. The scripts in the folder
[Acceptance](Acceptance) support it, and each runs in Windows PowerShell 5.1 on
the host:

- `Test-PublishedRelease.ps1 -Version <version> -OutputPath <folder>` checks a
  published version and changes nothing: the tag and its commit on `master`,
  the CI run of the tag, the SHA-512 that the PowerShell Gallery publishes
  against the downloaded package, and the module files of the package against
  those of the GitHub zip file.
- `Validate-LabResults.ps1` checks every role of a controller run from the
  result files, not from the marker `DONE` that the controller writes also when
  tests failed.
- `Run-MatrixSequence.ps1` runs steps 2, 4, and 5 for each file server of the
  matrix lab with the client `OSWin11E`: it checks the readiness of every
  machine (`Test-MatrixReadiness.ps1`), runs the controller in both editions,
  validates every role, removes the fixture, and checks the end state
  independently (`Test-MatrixCleanup.ps1`, which takes the lab name and the
  machines, so it checks the first lab as well; `-Mode Repair` removes what a
  failed cleanup left, and what the probes and the suite runner of the kit leave,
  which includes every unresolved `S-1-5-21-…` member of Performance Log Users:
  the check treats it as the probe's).
- `Run-MatrixLocalSuite.ps1` runs the Pester files of the module on a machine of
  the matrix lab, or on the host as the reference, in both editions, elevated
  and as a basic user, and copies the results back. Run it with a candidate
  before the controller: a test that passes on a computer outside a domain can
  fail on a computer in a domain, as the effective-access tests of the basic
  user did. `Export-MatrixResults.ps1` turns the results into tables.
- `Probe-EffectiveAccess.ps1` asks `Get-NTFSEffectiveAccess` the same questions
  under the token of an administrator, a filtered administrator, a local
  standard user, and a standard domain user, and shows which authorization
  manager answers or refuses.
- `Probe-AccountRecreation.ps1` deletes an account and creates it again with the
  same name in a loop. It shows the SID and the groups that Kerberos S4U logons
  report on the domain controller, the client, and the file server, and what
  `Get-NTFSEffectiveAccess` of each module under test returns. It showed the
  state that the controller avoids with a new name for the account of case 3.
- `Export-CellTimeline.ps1` reads the sequence and run logs of controller cells
  and writes one row for every cell and edition in which the Admin role ran: the
  module, the account and its relative ID, whether the previous cell had the same
  name and the same account, the times of the removal of the previous fixture, of
  the creation of the accounts, and of the Admin role, and the three
  effective-access tests of case 3.
- `Test-StaleAuthzModel.ps1` replays such a timeline against the model of the
  failures of the effective-access tests (an authorization manager that answers
  for an account name from its first request, for some minutes, also after the
  account was created again) and reports, for the lifetimes that predict most
  outcomes, how many of the observed ones the model reproduces. With `-Lifetime`
  it lists every run with the observed and the predicted outcome for that one
  lifetime, with `-AsIfSameSubject` it shows where a controller that reuses
  the account name would have met a stale entry, and with `-Permutations` how
  often a random assignment of the outcomes fits as well. It describes the
  observations; it doesn't explain Windows.
- `Add-OsMatrixMachine.ps1`, `Complete-OsMatrixLab.ps1`, and
  `Repair-OsMatrixBoot.ps1` add a machine to the deployed lab, install the tools
  on the machines (the VMs have no internet), and repair the boot files of a
  base image that the host couldn't write.
- `Probe-LaterCommand.ps1` is the diagnostic of the
  [record of the paths fixes](Acceptance-2026-10-09-quality-gate-paths.md).

To accept a published prerelease, run the stages in this order, because the
evaluation client `OSWin11E` shuts itself down an hour after its start: start
the client and check the readiness of the matrix lab, then
`Run-MatrixSequence.ps1 -Version <version>` for the cells, then
`Run-MatrixLocalSuite.ps1 -ModulePath` on every machine with the extracted
module of the release (`Test-PublishedRelease.ps1` leaves it in the folder
`zip-<version>\NTFSSecurity` of its output folder), then
`Test-MatrixCleanup.ps1 -Mode Verify` for the matrix lab, and last the
controller with `-Version` in the first lab, where case 9 runs. Start the suites
a minute or more apart, because AutomatedLab imports one lab at a time, and
never together with a controller. The
[record of the published 5.0.0-rc7](Acceptance-2026-10-10-published-rc7.md) ran
the stages that way.

Records: [5.0.0-rc6](Acceptance-2026-10-08-5.0.0-rc6.md),
[5.0.0-rc7](Acceptance-2026-10-08-5.0.0-rc7.md),
[quality-gate follow-up](Acceptance-2026-10-09-quality-gate.md),
[quality-gate paths follow-up](Acceptance-2026-10-09-quality-gate-paths.md),
[operating-system matrix](Acceptance-2026-10-10-os-matrix.md), and
[the published 5.0.0-rc7](Acceptance-2026-10-10-published-rc7.md).
The review of the code that no unit test visits, with the fixes that the lab
has to repeat, is in
[Tests/Coverage](../Coverage/Quality-Gate-Paths-2026-10-09.md).

## Files

| File | Purpose |
| --- | --- |
| `Invoke-NTFSSecurityLabTest.ps1` | Prepares the lab, runs the tests, and writes the results; runs on the host. |
| `NTFSSecurity.Live.Tests.ps1` | The tests; run on the client and the file server. |
| `Start-NTFSSecurityLiveTest.ps1` | Runs the tests of one role in a new process. |
| `NTFSSecurity.LabHelpers.ps1` | Reads and writes security descriptors as Windows stores them, and calculates the expected rights. |
| `Acceptance\` | The scripts of the acceptance of a candidate or of a published version, and the diagnostic of the paths record (see above). |

[issue-34]: https://github.com/raandree/NTFSSecurity/issues/34
[issue-108]: https://github.com/raandree/NTFSSecurity/issues/108
