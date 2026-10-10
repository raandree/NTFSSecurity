# Operating-system matrix acceptance, 2026-10-10

Live and local acceptance of NTFSSecurity candidates on more operating systems
than the first lab has (Decision 24, handoff 2 of the 5.0.0 quality gate):
Windows Server 2019, 2022, and 2025 as file servers and Windows 11 as client, in
Windows PowerShell 5.1 and PowerShell 7, elevated and as a basic user. The
candidates are local builds of `ai/quality-gate-lab-matrix`, tested from their
extracted packages with `-ModulePath`. None is a published package, so this
record isn't the acceptance of a release (see the limits at the end), and it
isn't a claim that the quality gate is complete.

## Result

- The module's own suite, 1,011 cases per configuration (1,010 on the host), ran
  on five operating systems and on the host in four configurations each. The
  final candidate (`fdd7a8b`) has no failure in any of the 24 runs; every
  skipped test is also skipped on the host.
- The live controller ran for the final candidate in three cells of the matrix
  (the Windows 11 client with each file server, both editions, every role) in
  one sequence, after the fixture got a new account name for each new fixture:
  1,374 passed, 0 failed, 12 skipped (case 9 and the module test of the Server
  role). An earlier run of the same cells with the old controller had failed in
  the Windows Server 2022 cell for a reason of the fixture, not of the module
  (see "The accounts of the fixture").
- The matrix found three defects of the module. All three are fixed on the
  branch, each with its own commit, and each was red on the machines where it
  shows before its fix and green after it: `Get-NTFSInheritance
  -SecurityDescriptor` for an item without audit entries and `Get-NTFSEffectiveAccess
  -ServerName ''` (`962887a`), and `Get-NTFSEffectiveAccess` for a user who
  isn't an administrator on a computer in a domain (`fdd7a8b`). The first two
  showed on Windows Server 2022 and 2025 and on Windows 11 26H1, the third on
  every machine of the domain.
- The controller had four defects of its own: three in cleanup and setup
  (`7d47316`) and the reuse of the name of the account of case 3 (`1dec389`).
  Windows returns the SID and the groups of a deleted account for a Kerberos S4U
  logon for more than seven minutes, so cells that followed each other failed in
  the effective-access tests of the Admin role. This looked like a regression of
  the module until a probe showed the baseline and the final candidate failing
  alike.
- Windows 11 26H1 (10.0.28000) can't keep a secure channel to the Windows
  Server 2025 domain controller of this lab, so it runs the module's suite only.
  The domain client is Windows 11 Enterprise Evaluation 22H2.
- Open: the published package in every cell (stage D of the gate), case 9 in the
  matrix lab, and the maintainer's decisions listed at the end.

## Machines

All machines are virtual machines on the Hyper-V host in the lab
`NtfsSecurityOsMatrixLab` (domain `osmatrix.net`, switch `192.168.12.0/24`),
which AutomatedLab deployed beside the other labs without touching them. The
.NET Framework release number is the one that the readiness check read.

| Machine | Role | Operating system | Build | .NET Framework | Windows PowerShell | PowerShell 7 |
| --- | --- | --- | --- | ---: | --- | --- |
| OSDC1 | Root domain controller | Windows Server 2025 Datacenter | 10.0.26100.32690 | 533509 | 5.1.26100.32684 | 7.6.3 |
| OSFile19 | File server | Windows Server 2019 Datacenter | 10.0.17763.1217 | 461814 | 5.1.17763.1007 | 7.6.3 |
| OSFile22 | File server | Windows Server 2022 Datacenter | 10.0.20348.4773 | 528449 | 5.1.20348.4294 | 7.6.3 |
| OSFile25 | File server | Windows Server 2025 Datacenter | 10.0.26100.32690 | 533509 | 5.1.26100.32684 | 7.6.3 |
| OSWin11E | Client | Windows 11 Enterprise Evaluation 22H2 | 10.0.22621.525 | 533320 | 5.1.22621.169 | 7.6.3 |
| OSWin11 | Suite only | Windows 11 Pro 26H1 | 10.0.28000.1836 | 533510 | 5.1.28000.1830 | 7.6.3 |
| Host | Reference for the suite | Windows Server 2025 Datacenter | 10.0.26100.33438 | 533509 | 5.1.26100.33438 | 7.6.6 |

Windows 11 reports `Windows 10` as the product name in the registry; the builds
are Windows 11. The VMs have no internet, so PowerShell 7.6.3 and Pester 5.7.1
came from the host. Every machine passed a readiness check before a cell: WinRM
with the lab account, LDAP, Kerberos, the secure channel, the clocks, the tools,
and the Pester version.

## Candidates and artifact identity

Each candidate is a Release build (.NET Framework 4.5.2) in an isolated worktree
of its commit, packaged by `.github/scripts/New-ModulePackage.ps1`. All 11 files
of every tested module folder equal the extracted `NTFSSecurity.zip` byte for
byte. The builds aren't byte-reproducible: `PrivilegeControl.dll` and
`ProcessPrivileges.dll` differ between the candidates although no source of
theirs changed, so the hashes belong to one build each.

| | Baseline `83149ee` | Candidate `962887a` | Final `fdd7a8b` |
| --- | --- | --- | --- |
| What it is | Head of #118 | Two fixes in the module | Three fixes in the module |
| `NTFSSecurity.dll` | `40D0C8A6B819F15A…` | `9AC1169F91687495…` | `B0631389E68C8244…` |
| `Security2.dll` | `804D199335CA0D6A…` | `FF314FACCF01676A…` | `A4D744579E8FF3BE…` |
| `NTFSSecurity.5.0.0-rc7.nupkg` | `2AAE3403A2D1C3AE…` | `ACFA247BCD5AD33D…` | `1A112B8CBBE27F9D…` |
| `NTFSSecurity.zip` | `A5AFA241DCA5DF87…` | `CD836E39C6B22EB3…` | `3DF48E5C590A9E38…` |

The full SHA-256 values and the hashes of every result file are in the local
evidence (see the end). The tests of the suite are the files of the working
tree at the commit of the run. The live tests (Git blob
`efe36e5073b9b10742ca7de242ddcbe90d8eda62`) are those of `fdd7a8b` in every run
from `rc7f` on. The controller of the cells `rc7f` to `rc7k` is the blob
`683aee91ec8805d77a33b2d368acaf876724fa32` (`fdd7a8b`); the cells of `rc7l` ran
with the blob `9917cac5820ed20ed2eb5592eff06894677f9874` (`1dec389`). The
earlier cells of the baseline ran with the controller blobs `0b46427b…` and
`d485b1d0…` and the live tests `67b85efe…`, before the cleanup fixes.

## Method

- **Module's own suite.** `Acceptance\Run-MatrixLocalSuite.ps1` copies the 18
  behavior test files and the candidate to a machine and runs them there in a
  new Windows PowerShell process and a new PowerShell 7 process, elevated and as
  a basic user. The basic user is the token that
  `.github\scripts\Invoke-TestsAsBasicUser.ps1` makes (SAFER level Normal User),
  so the tests that need a missing privilege skip in the elevated mode and run
  in this one. The processes run as scheduled tasks with a batch logon at the
  highest run level: a process that starts from a remoting session has every
  privilege enabled and no credentials of its own, which eight tests don't
  expect. The host runs the same stage as the reference. A skipped test counts
  as a difference when only one side skips it; the skipped lists are compared as
  multisets of test names.
- **Live controller.** `Acceptance\Run-MatrixSequence.ps1` runs, for each file
  server with the client `OSWin11E`: the readiness of every machine, the
  unmodified controller of the repository in both editions, the validation of
  every role from the result files (`Validate-LabResults.ps1`, never from the
  marker `DONE`), a snapshot of the fixture SIDs, the removal of the fixture,
  and an independent check of the end state (`Test-MatrixCleanup.ps1`).
- **Probe.** `Acceptance\Probe-EffectiveAccess.ps1` asks
  `Get-NTFSEffectiveAccess` the same questions under four tokens on one machine
  and writes the result and the failing call of each: the elevated lab account,
  the SAFER token of a basic user, a local standard user, and a standard user of
  the domain. It creates the two standard users with passwords that exist only
  in memory and removes them, their profiles, and their group membership again.
- **Account probe.** `Acceptance\Probe-AccountRecreation.ps1` deletes an account
  and creates it again with the same name in a loop. It shows the token that
  Kerberos S4U logons give on the domain controller, the client, and the file
  server, and what `Get-NTFSEffectiveAccess` of each module under test returns
  from the client (see "The accounts of the fixture"). Its accounts, folder, and
  files are named `NtfsProbe*`, which `Test-MatrixCleanup.ps1` reports if they
  stay.

## Results

### Live controller

The final candidate (`fdd7a8b`) in the three cells of the matrix, with the
Windows 11 client `OSWin11E`, the controller of `1dec389` (Git blob
`9917cac5820ed20ed2eb5592eff06894677f9874`) and the live tests of blob
`efe36e5073b9b10742ca7de242ddcbe90d8eda62`: run `rc7l`, one sequence, 03:45 to
04:07 UTC. Every role was checked from the result files
(`Validate-LabResults.ps1` printed `LIVE_RESULT_VERIFIED`). Passed / failed /
skipped:

| File server | Edition | Delegate | ServerAdmin | Admin | Server |
| --- | --- | --- | --- | --- | --- |
| OSFile19 (Windows Server 2019) | Windows PowerShell | 69 / 0 / 0 | 36 / 0 / 0 | 51 / 0 / 1 | 73 / 0 / 1 |
| OSFile19 (Windows Server 2019) | PowerShell 7 | 69 / 0 / 0 | 36 / 0 / 0 | 51 / 0 / 1 | 73 / 0 / 1 |
| OSFile22 (Windows Server 2022) | Windows PowerShell | 69 / 0 / 0 | 36 / 0 / 0 | 51 / 0 / 1 | 73 / 0 / 1 |
| OSFile22 (Windows Server 2022) | PowerShell 7 | 69 / 0 / 0 | 36 / 0 / 0 | 51 / 0 / 1 | 73 / 0 / 1 |
| OSFile25 (Windows Server 2025) | Windows PowerShell | 69 / 0 / 0 | 36 / 0 / 0 | 51 / 0 / 1 | 73 / 0 / 1 |
| OSFile25 (Windows Server 2025) | PowerShell 7 | 69 / 0 / 0 | 36 / 0 / 0 | 51 / 0 / 1 | 73 / 0 / 1 |

That is 1,374 passed, 0 failed, and 12 skipped for the three cells. The skipped
tests are the same in every cell: case 9 (the Admin role skips "Get-NTFSOrphanedAccess
should not report the entries of the accounts" of other domains and forests,
because the matrix lab has no foreign domain) and the Server role's test of the
module version (that role runs without the module). Each cell had a new
fixture: the subject of case 3 was `NtfsLiveSubject0602` in the cell of
OSFile19 and `NtfsLiveSubject6688` in the cell of OSFile22.

All runs of the controller, as the table of cells
([Cells.csv](Acceptance-2026-10-10-os-matrix-Cells.csv)) lists them. The runs
before `rc7l` used the controller with the fixed name of the subject:

| Run | Candidate | Cells | Result per edition and cell |
| --- | --- | --- | --- |
| `rc7c`, `rc7e` | Baseline `83149ee`, tests before the new cases | OSFile19, 22, 25 | 227 passed, 0 failed, 2 skipped in every cell. The failed cleanup of the first cell had left the accounts in place, so only the third cell of `rc7e` had new accounts |
| `rc7f` | Final `fdd7a8b` | OSFile19, OSFile22 | OSFile19: 229 / 0 / 2. OSFile22: 228 / 1 / 2, the effective-access test of the Admin role |
| `rc7g` | Final | OSFile25 | 229 / 0 / 2 |
| `rc7h` | Final | OSFile22 | 228 / 1 / 2, the same test |
| `rc7i` | Final | OSFile22 | Windows PowerShell 228 / 1 / 2 (Admin), PowerShell 7 229 / 0 / 2 |
| `rc7j` | `962887a` (without the third fix) | OSFile22 | 225 / 4 / 2: the two new tests of the ServerAdmin role (red without the fix, "Access is denied" for `localhost` and for the name of the client) and two tests of the Admin role |
| `rc7k` | Baseline `83149ee`, with the final tests | OSFile22 | 227 / 2 / 2: the two new tests of the ServerAdmin role; the Admin role passed |

The failures of the Admin role in `rc7f`, `rc7h`, `rc7i`, and `rc7j` come from
the fixture, not from the module (see "The accounts of the fixture"). The two
failures of the ServerAdmin role in `rc7j` and `rc7k` are the red state of the
new live tests, as intended; they pass in `rc7f`, `rc7g`, `rc7h`, `rc7i`, and
`rc7l`. The end-state check after each cell of `rc7l` found the fixture gone
(no organizational unit, account, share, folder, local group, membership, or
profile) and reported only the staging folders of the earlier suite runs, which
`Test-MatrixCleanup.ps1` didn't check before (see "The accounts of the fixture"
and the limits).

### The module's own suite, final candidate

Passed / failed / skipped. Every configuration has 1,011 cases on the machines
of the domain and 1,010 on the host, which has no DNS domain and so doesn't run
the case for the fully qualified name of its computer.

| Machine | Elevated, Windows PowerShell | Elevated, PowerShell 7 | Basic user, Windows PowerShell | Basic user, PowerShell 7 |
| --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSFile22 (Server 2022) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSFile25 (Server 2025) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSWin11E (Windows 11 22H2, the client of the cells) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSWin11 (Windows 11 26H1) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| Host (reference) | 993 / 0 / 17 | 991 / 0 / 19 | 781 / 0 / 229 | 779 / 0 / 231 |

On every machine, the skipped tests are the same as on the host, name for name,
in every configuration. They are tests that need the other privilege level or
the other edition and that run in another configuration, as the earlier
analysis of the skipped rows found (all 578 skipped rows of the suite at
`5a5d58b` ran in two other configurations). The two disabled-audit-inheritance
tests that `962887a` added are skipped without the Security privilege, so the
basic configurations skip two cases more than before (229 instead of 227).

### What the fixes changed

The same tests, the same machines, and three builds. The baseline and the
candidate `962887a` were run with the tests of the final commit, so the guards
of the later fixes were present and red.

| Candidate | Elevated | Basic user |
| --- | --- | --- |
| Baseline `83149ee` (Server 2022 and 2025) | 4 failures in every configuration | 20 failures in every configuration |
| `962887a` (all five machines of the domain) | 0 failures | 20 failures in every configuration |
| Final `fdd7a8b` (all five machines of the domain) | 0 failures | 0 failures |

The four elevated failures of the baseline are the same on Server 2022 and
2025, in both editions:

1. `Get-NTFSInheritance` with a security descriptor, "Should report the same
   state as for the path of the item" (existing test),
2. the same for "a file without audit entries" and
3. "a folder without audit entries" (two new guards),
4. `Get-NTFSEffectiveAccess`, "Should return the result of this computer and
   warn for an empty -ServerName" (existing test).

The 20 failures in the basic-user mode are the same set on every machine of the
domain and in both editions, once the name of the computer in two test names is
set aside. All of them call `Get-NTFSEffectiveAccess` without a reachable
remote authorization manager: 11 in its own tests, 5 in the tests of a later
command that ends the pipeline, 2 for an unresolved identity, 1 for a path that
doesn't exist, and 1 for an item whose owner may not read its permissions. Each
fails with "Could not get effective permissions from machine 'localhost'. The
error is 'Access is denied'". The host and the CI runners aren't in a domain and
passed them all along. The failing names of every run are in
[the failures table](Acceptance-2026-10-10-os-matrix-Failures.csv).

## Defects found

### In the module

1. **`Get-NTFSInheritance -SecurityDescriptor` for an item without audit
   entries** reported the audit inheritance as disabled, where `-Path` reported
   it as enabled. On Windows Server 2022 and 2025 and on Windows 11 26H1, .NET
   reports the SACL of such an item as protected from inheritance when it reads
   all sections together, and as not protected when it reads the SACL alone;
   the descriptor kept the first state. The baseline showed it on Windows
   Server 2022 and 2025, and an earlier run with the same two existing tests
   showed it on Windows 11 26H1; the host (build 33438) reads both ways alike.
   The baseline wasn't run on Server 2019 and Windows 11 22H2. `Write()` stores
   the sections that were read, so a descriptor with the wrong flag would also
   have stored the SACL as protected. Fixed in `962887a`: the descriptor takes
   the audit section from a separate read, as it already did for the access
   section.
2. **`Get-NTFSEffectiveAccess -ServerName ''`** wrote "Access is denied" on the
   same machines, because Windows takes an empty name for this computer and the
   remote interface then refuses the check; on the host it fails as
   unreachable. Fixed in `962887a`: an empty name names no computer, so the
   cmdlet warns and returns the result of this computer on every machine.
3. **`Get-NTFSEffectiveAccess` for a user who isn't an administrator**, on a
   computer in a domain, wrote "Access is denied" and returned nothing for
   every account, also for the default `-ServerName localhost`. See the probe
   below. The function that fails, `GetEffectivePermissions_AuthzInitializeContextFromSid`,
   is identical in the published 5.0.0-rc6 (compared with `git diff` against
   the tag; the cmdlet wasn't run there), and the defect shows in the tests only
   on a domain-joined machine as a basic user. Fixed in `fdd7a8b`.

### The probe

The remote interface of the authorization manager of a computer answers only
its administrators and the members of its group Access Control Assistance
Operators. A computer in a domain offers the interface to every caller; a
computer outside a domain doesn't, so the cmdlet already used the local manager
there. The probe, on Windows Server 2019, 2022, and 2025, with the module of
`962887a` (before the third fix):

| Token | Name of this computer (the default, `localhost`, computer name, FQDN) | `-ServerName ''` (the local manager) | Another computer |
| --- | --- | --- | --- |
| Lab account, elevated | Result for every account | Result for every account | Result for every domain account |
| Lab account, filtered (SAFER Normal User) | Access denied for every account | Result for every account, also the Administrator and Domain Users of the domain | Result for domain accounts: network authentication carries the groups of the account |
| Local standard user | Access denied | Result, except for the domain Administrator, a user account of the domain | Access denied: a local account has no domain credentials |
| Standard domain user | Access denied for every account | Result for every account, also the domain Administrator | Access denied, as the cmdlet page and the live test of the delegated account describe |

The accounts were the user itself, Everyone, the local Administrator, and the
Administrator and Domain Users of the domain. The cmdlet now uses the local
manager for a name of this computer when the remote one refuses the user. The
second column shows that this answers for every caller of these four kinds,
except for a local user who asks about a user account of the domain; that stays
an "Access is denied" from Windows. For another computer, the denial stays an
error. A new live test runs the case as the administrator of the file server,
who isn't an administrator of the client, and compares the rights with the S4U
oracle that the other roles use.

### In the environment

- The base images of Windows Server 2019 and Windows 11 22H2 had an empty EFI
  system partition: the `bcdboot` of the Server 2025 host fails with exit code
  193 on their boot files, and AutomatedLab ignores the exit code, so the VM
  doesn't boot (Hyper-V event 18603). `Repair-OsMatrixBoot.ps1` runs the
  `bcdboot` of the image itself on the VM's own disk.
- Windows 11 26H1 (28000.1836) joins the domain but loses the secure channel to
  the domain controller (26100.32690): the client asks `NetrLogonGetCapabilities`
  for query level 2, the controller answers `0xC0000022`, and the client denies
  the channel (`NlConfirmRequestedCapabilities: denying access ... 0xc0000022`).
  A rejoin can't fix a protocol mismatch, so this machine isn't a domain client.
- The Windows 11 Enterprise Evaluation image shuts itself down an hour after
  each start (`wlms.exe`: "The license period for this installation of Windows
  has expired"; status 0xC004F009). It recorded its install time on a clock that
  ran about seven hours ahead, the clock was then corrected, and the evaluation
  licensing took the step back as the end of the grace period. One of the two
  documented rearms didn't clear it. After an unplanned shutdown its machine
  account password no longer matched the domain's (`0xC000018D` for domain
  logons, `nltest /sc_verify` reports `ERROR_INVALID_PASSWORD`);
  `Test-ComputerSecureChannel -Repair` with the lab account repaired it. Runs on
  this machine have to stay under an hour from its start.
- A profile of an account that a scheduled task used stayed loaded on one
  server, so its folder couldn't be removed until the machine restarted.

### In the harness

- A line that a native command writes to stderr is a terminating error in
  Windows PowerShell 5.1 under `$ErrorActionPreference = 'Stop'` when `2>&1`
  redirects it. The first "The directory is not empty" of PowerShell 7 ended the
  fixture removal on Server 2019 before the retry.
- `Get-LocalGroupMember` fails with "Failed to compare two elements in the
  array" when a group holds an orphaned SID, which stopped the setup of the next
  run. The setup now adds members and ignores `MemberExistsException`.
- A profile that is gone in the meantime failed the cleanup of the client.

All three are fixed in the controller (`7d47316`).

### The accounts of the fixture

The cells of the final candidate failed in the Windows Server 2022 cell, and
only there, in the Admin role: `Get-NTFSEffectiveAccess` for the subject of
case 3 returned no access (Synchronize only, `0x100000`) where the tests
expected the rights through the domain groups, once with the default
`-ServerName` or once with the name of the file server, in `rc7f`, `rc7h`,
`rc7i`, and `rc7j` (`rc7j` ran the candidate `962887a`, `rc7i` failed only in
Windows PowerShell). The audit read of `962887a` was the first suspect: it is
the only change of the module on the path of the cmdlet, and the baseline had
passed the cell (`rc7c`, `rc7e`, `rc7k`). A probe disproved it. Every cell of
`rc7c` and `rc7e` had run with the accounts that the failed cleanup of the first
cell left in place; from `rc7f` on, the removal worked, so the fixture deleted
its accounts after each cell and created them again, with the same names and new
SIDs, for the next.

The loop probe (the scratch script of the night, which
`Probe-AccountRecreation.ps1` replaces) creates a user in a group that is in
another group, asks `Get-NTFSEffectiveAccess` from the client in a new process
for the baseline and for the final candidate, deletes the accounts, and creates
them again with the same names every seven seconds:

| Round | Name resolves to | S4U token of the account on the client | Baseline and final candidate, by name and by SID, with the default `-ServerName` and with the file server |
| --- | --- | --- | --- |
| 1 (new names) | the current SID | holds the outer group | `0x1200A9`, both modules, all four calls |
| 2 to 6 | the SID of the previous round in the first process of a round, the current SID in the second | lacks the new outer group | `0x100000`, both modules, all four calls |

The probe of the kit, `Probe-AccountRecreation.ps1`, which also logs the user on
with S4U on the domain controller, the client, and the file server, gave the same
picture in four rounds with the baseline and the final candidate (04:19 UTC): in
round 1, all three machines returned the current account and both modules
`0x1200A9` for every call; in rounds 2 to 4, all three returned the old account,
without the new outer group, and both modules `0x100000` for every call.

A second probe logged the user on with Kerberos S4U the way the oracle of the
live tests does, on all three machines: after the accounts were created again,
the token of the domain controller, the client, and the file server held the
SID of the deleted account (`user is the current SID: False`) and not the new
outer group, in rounds 2 and 3; in round 1 all three were right. The computers'
own ticket cache (logon session `0x3e7`) held no ticket for the account, and
purging it changed nothing.

A third probe created five sets of accounts, logged each user on with S4U on
the three machines, deleted and created them again with the same names, and
asked once per set after a delay, so that no question kept a cache alive. Set 1
was asked at once, then after remedies:

| Question | Domain controller | File server | Client |
| --- | --- | --- | --- |
| At once | old account | old account | old account; Authz by SID `0x100000` |
| After `klist purge` on the client | old account | old account | current account (the token of the session); Authz by SID still `0x100000` |
| After `nltest /sc_reset`, a DNS flush on the client, and a restart of the Kerberos service of the domain controller | old account | old account | unchanged |
| 60 seconds after the accounts were created again | old account | old account | Authz by SID `0x100000` |
| 180 seconds | old account | old account | Authz by SID `0x100000` |
| 420 seconds | old account | old account | Authz by SID `0x100000` |
| 900 seconds | current account | current account | Authz by SID `0x1200A9`, also with the name of the file server |

The sets after the first were asked after the purge on the client, so the token
of the client in their rows isn't independent; the rows of the domain controller
and the file server are. The module isn't involved: `WindowsIdentity` with the
user principal name, which the module doesn't call, returns the old account.
The lifetime is between seven and fifteen minutes when the account is created
again at once; I didn't measure it more closely. A cell of the controller has
minutes between the removal and the next creation, which may be why the cells
failed in some positions and passed in others.

The controller now gives a new fixture a new name for the account of case 3
(`NtfsLiveSubject` and four digits, `1dec389`), and a fixture that exists keeps
its account. No cache has to be flushed, and the module isn't changed by this.
With the new names, the cell of Windows Server 2022 that had failed four times in
a row passed, and so did the other two cells of the same sequence (see "Live
controller"). The baseline's pass in `rc7k` in the same position doesn't fit a
fixed lifetime of the stale state (the deletion and the new creation were about
one minute apart, and the last question about the old account five minutes
earlier); I couldn't explain it, and the unique names make it moot.

## Limits and open items

- Every run is a validation of a local build (`-ModulePath`). The acceptance of
  a release is the run with `-Version` of the exact prerelease from the
  PowerShell Gallery in every cell, which handoff 3 sequences after the maintainer
  decides which fixes belong to 5.0.0-rc7. The same cells have to be repeated for
  a changed binary.
- Case 9 (accounts of other domains and forests) needs trusts that the matrix
  lab doesn't have; it runs only in `WindowsAccessControlLab`, where the
  baseline passed it.
- The file servers are Windows. A server of another kind is the subject of
  Decision 23.
- Windows 11 26H1 has no domain cell until the domain controller or the
  mismatch changes. The Windows 11 client of the cells is the 22H2 evaluation
  build, which has to be started shortly before a run (see above).
- `GetEffectiveAccess` ignores what the initialization of the resource manager
  throws (an outer `catch { }` that is older than this work). An operating
  system that refused another computer at that step, not at the context as every
  machine of the matrix did, would give a result without rights and a warning
  instead of the documented error. This is unverified and outside the fixes.
- The scripts of the kit were read by a reviewer who ran none of them; module
  logging or script-block logging on a machine would record the lab password
  that `Register-ScheduledTask -Password` needs.
- The lifetime of the stale Kerberos S4U state isn't established beyond "more
  than seven and less than fifteen minutes when the account is created again at
  once", and one cell (`rc7k`) passed where the probe predicted a failure. The
  controller doesn't depend on it any more, but a script of the kit that creates
  accounts again under one name would.
- The end-state check of the matrix reported the staging folders of the suite
  runs (`C:\NtfsMatrixLocal`) as residue in the three cells of `rc7l`, which
  made their verdict DIRTY, although the fixture was gone. The suite runner now
  removes its stage after it has copied the results back, the check counts the
  items in the stage folders, and `-Mode Repair` removes what is left. After a
  Repair, `Verify` found the lab clean at 04:21 UTC: no fixture, no probe account
  or user, no scheduled task, and no stage item on the domain machines. The
  stage of OSWin11, which only a local account reaches, was removed by a command
  of its own (4 items).
- Decision 24 is the agent's decision under the maintainer's delegation and stays
  `proposed`. So do Decisions 22 and 23.

## Evidence

The raw logs, result files, probe outputs, and the packages are local, outside
Git, in the session files of the run; they aren't part of this commit. The
tables of this record are in the files next to it:

- [the suite results of the three candidates](Acceptance-2026-10-10-os-matrix-LocalSuite.csv),
- [the failing tests of every run](Acceptance-2026-10-10-os-matrix-Failures.csv),
- [the controller cells](Acceptance-2026-10-10-os-matrix-Cells.csv).

The scripts that produced them are in [Acceptance](Acceptance), and the
decision is `.memory-bank\decisions\0024-os-matrix-lab.md`.
