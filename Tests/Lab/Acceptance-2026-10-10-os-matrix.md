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
  the Windows Server 2022 cell. A replay showed that the baseline fails the same
  way there, so the module doesn't decide the outcome: the failures depend on the
  position of the cell (six replay runs can't rule out a small effect of the
  module; see "The effective-access failures of the Admin role").
- The final candidate also passed the live controller in the first lab, where
  case 9 runs: 245 passed, 0 failed, 1 skipped in each edition (see "First lab,
  final candidate (case 9)").
- The matrix found three defects of the module, fixed in two commits on the
  branch, and each was red on the machines where it shows before its fix and
  green after it: `Get-NTFSInheritance -SecurityDescriptor` for an item without
  audit entries and `Get-NTFSEffectiveAccess -ServerName ''` (`962887a`, two
  fixes), and `Get-NTFSEffectiveAccess` for a user who isn't an administrator on
  a computer in a domain (`fdd7a8b`). The first two showed on Windows Server 2022
  and 2025 and on Windows 11 26H1, the third on every machine of the domain.
- The controller had four defects of its own: three in cleanup and setup
  (`7d47316`) and the reuse of the name of the account of case 3 (`1dec389`).
  Cells that followed each other failed in the effective-access tests of the
  Admin role when the account of case 3 was deleted and created again under the
  same name: the remote authorization managers of the client and of the file
  server returned no groups for the new account, for the baseline and for the
  final candidate alike. A model with a lifetime of about ten minutes fits every run; the mechanism
  in Windows isn't known. This looked like a regression of the module until the
  baseline failed the same way in a replay of the same cells.
- Windows 11 26H1 (10.0.28000) can't keep a secure channel to the Windows
  Server 2025 domain controller of this lab, so it runs the module's suite only.
  The domain client is Windows 11 Enterprise Evaluation 22H2.
- Open: the published package in every cell and in the first lab (stage D of the
  gate), and the maintainer's decisions listed at the end. The matrix lab has no
  trusts, so case 9 runs only in the first lab.

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
from `rc7f` to `rc7l` and in the first-lab run `fl1`; the replay `ab0` to `ab10`
ran the same file with one diagnostic test added (blob
`72c12fe09e4005e048a8aed0fa02b9a922c58f34`, see "The effective-access failures
of the Admin role"). The controller of the cells `rc7f` to `rc7k` and of the
replay cells `ab0` to `ab6` is the blob `683aee91ec8805d77a33b2d368acaf876724fa32`
(`fdd7a8b`). The cells of `rc7l` and the replay cells `ab7` to `ab10` ran with the
blob `9917cac5820ed20ed2eb5592eff06894677f9874` (`1dec389`), and the first-lab run
`fl1` with the blob `d269e0fe6ba5f72894dd2dcba5dca7f2dc56624f` (the head of the
branch then, which differs from `1dec389` by a comment). The earlier cells of the
baseline ran with the controller blobs `0b46427b…` and `d485b1d0…` (`rc7d` with
`4cac0d0b…`) and the live tests `67b85efe…`, before the cleanup fixes.

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
  from the client (see "The effective-access failures of the Admin role"). Its
  accounts, folder, and files are named `NtfsProbe*`, which `Test-MatrixCleanup.ps1`
  reports if they stay.
- **Replay.** The cells that failed were run again back to back, one edition, one
  file server, with the baseline and the final candidate alternating: after a
  restart of the client, one `Acceptance\Run-MatrixSequence.ps1 -Edition Desktop
  -FileServer OSFile22` per cell with a different `-ModulePath`, from frozen
  copies of the kit and the controller so that no edit could change a run in
  progress. The live tests of the replay had one test added that is not in the
  repository and prints the state of the subject account after the three
  effective-access tests. The kit has the tools that read the
  result: `Acceptance\Export-CellTimeline.ps1` (the timeline of the Admin role of
  every cell and edition: the module, the account, the times, and the three
  tests) and
  `Acceptance\Test-StaleAuthzModel.ps1` (the model of the failures, replayed
  against that timeline).

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
| `rc7c`, `rc7e` | Baseline `83149ee`, tests before the new cases | OSFile19, 22, 25 | 227 passed, 0 failed, 2 skipped in every cell. In `rc7c`, the failed cleanup of the first cell left the accounts in place through all three cells. `rc7d` between them created accounts and removed them 36 seconds later, because its setup failed ("Failed to compare two elements in the array", fixed in `7d47316`) before any test ran. In `rc7e`, the first cell created new accounts 4.6 minutes after that removal, the second reused them, and the third created new accounts 1.0 minute after the previous removal |
| `rc7f` | Final `fdd7a8b` | OSFile19, OSFile22 | OSFile19: 229 / 0 / 2. OSFile22: 228 / 1 / 2, the effective-access test of the Admin role |
| `rc7g` | Final | OSFile25 | 229 / 0 / 2 |
| `rc7h` | Final | OSFile22 | 228 / 1 / 2, the same test |
| `rc7i` | Final | OSFile22 | Windows PowerShell 228 / 1 / 2 (Admin), PowerShell 7 229 / 0 / 2 |
| `rc7j` | `962887a` (without the third fix) | OSFile22 | 225 / 4 / 2: the two new tests of the ServerAdmin role (red without the fix, "Access is denied" for `localhost` and for the name of the client) and two tests of the Admin role |
| `rc7k` | Baseline `83149ee`, with the final tests | OSFile22 | 227 / 2 / 2: the two new tests of the ServerAdmin role; the Admin role passed |

The failures of the Admin role in `rc7f`, `rc7h`, `rc7i`, and `rc7j` don't depend
on the module: the baseline fails the same way in a replay of the cells (see "The
effective-access failures of the Admin role"). The two
failures of the ServerAdmin role in `rc7j` and `rc7k` are the red state of the
new live tests, as intended; they pass in `rc7f`, `rc7g`, `rc7h`, `rc7i`, and
`rc7l`. The end-state check after each cell of `rc7l` found the fixture gone
(no organizational unit, account, share, folder, local group, membership, or
profile) and reported only the staging folders of the earlier suite runs, which
`Test-MatrixCleanup.ps1` didn't check before (see the limits).

### First lab, final candidate (case 9)

Case 9, the accounts of other domains and forests, needs the trusts of the
first lab, so the cells of the matrix skip it. The final candidate (`fdd7a8b`,
from the same extracted module folder as in the matrix) ran through the
controller of the repository (blob `d269e0fe6ba5f72894dd2dcba5dca7f2dc56624f`) in
`WindowsAccessControlLab`, both editions, on 2026-10-10 from 06:14 to 06:31 UTC
(run `fl1`): the domain controller `F1ADC1`, the file server `F1AFile2`, and the
client `F1AFile1` (all Windows Server 2025 Datacenter 10.0.26100.32690, domain
`a.forest1.net`), with the foreign domain controllers `F1BDC1`, `F2DC1`, and
`F3DC1`. `Validate-LabResults.ps1` printed `LIVE_RESULT_VERIFIED`. Passed /
failed / skipped, the same in both editions
([FirstLab.csv](Acceptance-2026-10-10-os-matrix-FirstLab.csv)):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 69 / 0 / 0 |
| ServerAdmin | 36 / 0 / 0 |
| Admin | 64 / 0 / 0 |
| Server | 76 / 0 / 1 |

That is 245 passed, 0 failed, and 1 skipped per edition; the skipped test is the
test of the module version in the Server role, which runs without the module. A
cell of the matrix has 229 passed and 2 skipped. The 16 tests more that passed
here are the tests of case 9: 15 that a matrix cell doesn't have (12 in the
Admin role and 3 in the Server role: the entries of `NtfsLiveForeign` of the
three foreign domains by `Get-NTFSAccess`, `Add-NTFSAccess`, `Remove-NTFSAccess`,
and `Get-NTFSEffectiveAccess`, and on the file server), and the test of
`Get-NTFSOrphanedAccess` that the matrix cells skip. Every test of a matrix
cell is in this run too (a comparison of the test names of `rc7l` OSFile25 and
this run found none that only the cell has). The fixture was removed with
`-RemoveFixture`, and the independent check (`Test-MatrixCleanup.ps1`, with the
10 SIDs that it recorded before: the accounts of the lab domain and
`NtfsLiveForeign` in each of the three foreign domains) found the four domains
and both machines clean: no organizational unit, account, share, folder, local
group, membership, or profile of the fixture, and none of the residue that the
check counted then (scheduled tasks, stage items, probe users); its verdict was
CLEAN. The check has counted the profiles and the log-group entries of the
account probe since the review that followed, and a `Verify` with that version
(07:29 UTC, the same SIDs) found none on the two machines either. This
is one run of one candidate. The baseline didn't run in the first lab on this
occasion, so the record says nothing about the red state of the new tests there.

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

### The effective-access failures of the Admin role

In the cells of the Windows Server 2022 file server, and only there, the Admin
role failed two effective-access tests of case 3 in `rc7f`, `rc7h`, `rc7i`, and
`rc7j` (`rc7j` ran the candidate `962887a`; `rc7i` failed only in Windows
PowerShell): `Get-NTFSEffectiveAccess` returned no access (Synchronize only,
`0x100000`) for the subject of case 3, where the tests expect the rights
through the nested domain groups (`0x1200A9`, and `0x1201BF` with the local
group of the file server), either with the default `-ServerName` (the
authorization manager of the client) or with the name of the file server, or
both. The baseline had passed the same position in `rc7e` and `rc7k`, and the
audit read of `962887a` is the only change of the module on the path of the
cmdlet before `fdd7a8b`, so the module was the first suspect. It isn't the
cause, as the replay below shows. In `rc7c`, the failed cleanup of the first cell
had left the accounts in place through all three cells; in the later sequences
the fixture was removed after most cells and created again for the next one, with
the same names and new SIDs.

**The replay.** The controller of `db04ef2` (the controller of `rc7f` to
`rc7k`, blob `683aee91ec8805d77a33b2d368acaf876724fa32`, the fixed name of the
account), Windows PowerShell only, the file server OSFile22, seven cells (`ab0`
to `ab6`, 04:57 to 05:33 UTC) back to back after a restart of the client, the
module alternating between the baseline `83149ee` and the final
candidate `fdd7a8b`. The live tests were the blob `efe36e5073b9b10742ca7de242ddcbe90d8eda62`
with one test added for this replay (the file then has the blob
`72c12fe09e4005e048a8aed0fa02b9a922c58f34`), which isn't committed: after the
three effective-access tests of the Admin role it prints, in the same second, the
state of the subject account (see below); it runs after them, so it can't change
their results. `ab0` is the warm-up and has a new fixture.

| Cell | Module | Admin role at (UTC) | Minutes since the previous removal | Test 1, name of the file server | Test 2, default server name |
| --- | --- | --- | ---: | --- | --- |
| `ab0` | final | 05:00:57 | 54.0 | pass | pass |
| `ab1` | baseline | 05:06:09 | 3.8 | FAIL `0x100000` | FAIL `0x100000` |
| `ab2` | final | 05:11:12 | 3.7 | pass | pass |
| `ab3` | final | 05:16:23 | 3.9 | FAIL `0x100000` | FAIL `0x100000` |
| `ab4` | baseline | 05:21:34 | 3.9 | pass | pass |
| `ab5` | baseline | 05:26:57 | 3.9 | FAIL `0x100000` | FAIL `0x100000` |
| `ab6` | final | 05:32:04 | 3.8 | pass | pass |

In every cell from `ab1` on, the accounts were created 1.0 minute after the
removal of the previous fixture, and the Admin role ran 3.7 to 3.9 minutes
after it. The cells differ in the module, in the outcome, and in one more
variable: the age of the entry that an earlier cell left for the same account
name, counted from that cell's Admin role (5.2 to 5.4 minutes in the failing
cells, 10.25 to 10.5 minutes in the passing ones). Not counting the warm-up
`ab0`, the baseline fails two of its three cells and the final candidate one of
its three, and the failing and the passing cells alternate. If the module
decided, the baseline wouldn't fail.

**What is wrong in a failing cell.** The test that runs right after the three
tests printed the same in `ab1`, `ab3`, and `ab5`: the name `osmatrix\NtfsLiveSubject`
resolves to the current SID; a Kerberos S4U logon of `NtfsLiveSubject@osmatrix.net`
on the client returns the current SID with nine groups, among them `NtfsLiveInner`
and `NtfsLiveOuter` (this logon is the oracle of the controller); `Get-NTFSEffectiveAccess`
with the unreachable server name, which falls back to the local authorization
manager, returns `0x1200A9`; and every call that asks a remote authorization
manager, the one of the client by the default `-ServerName` and the one of the
file server by its name, returns `0x100000`, by name and by SID alike. In the
passing cells all five calls were right. So the remote authorization managers
answer as if the account had no groups, while the name resolution, the Kerberos
logon, and the local manager are right in the same second. The module makes the
same Authz calls for both kinds of manager; only the manager differs.

**A model that fits.** The pattern is the one of a cache. The model: a remote
authorization manager computes the groups of an account at the first request
for the account name and answers from that result for L minutes, also when the
account was deleted and created again under the same name in the meantime. The
file server and the client have one entry each for a name, and use doesn't
renew it. `Test-StaleAuthzModel.ps1` replays the Admin roles of the timeline of
all cells ([Timeline.csv](Acceptance-2026-10-10-os-matrix-Timeline.csv): `rc7c`
to `rc7l` and `ab0` to `ab10`, 43 runs in 27 cells, and `rc7d`, which stopped
before its tests) against the model (`-StepMinutes 0.05`, so every bound is known
to within 0.05 minute). With L from 9.35 to 10.25 minutes the model predicts the
result of the first test (the file server) of all 43 runs, and with L from 9.95
to 10.25 minutes that of the second (the client): 43 of 43 for each, with 6 and 9
failures. One L from 9.95 to 10.25 minutes serves both tests (86 of 86). That
includes the cells where the two tests differ (`rc7f`, `rc7h`: the entry of the
client was stale, the one of the file server had expired), the cells of the
baseline that passed (`rc7e`, `rc7k`), and the cells that passed with an account
name that was new. A random assignment of the observed outcomes to the runs (the
same number of failures) never fits that well: none of 5,000 assignments reaches
43 of 43 for any L, and the best of them reaches 41 for the first test and 39
for the second (`-Permutations 5000`, fixed seed). I fitted the model after
`ab3` and wrote down its predictions before they ran (in the night log of the
session, outside the repository, at 05:20 UTC): `ab4` passes, `ab5` fails, `ab6`
passes. All three held, and `ab5` is the baseline failing; if the module decided,
`ab5` would have passed and `ab6` would have failed. `ab6` is the weakest of the
three: its entry was 10.5 minutes old, a little above the lifetimes that fit.

**The probes of the night.** Three probes (the second is
`Probe-AccountRecreation.ps1` of the kit) deleted and created the accounts again
within seconds. In that regime, the Kerberos S4U logon itself returned the old
account on the domain controller, the client, and the file server for more than
seven and less than fifteen minutes, and both modules returned `0x100000` for
every call. In the cells, with one minute between the deletion and the new
creation, the Kerberos logon is right (the oracle of the controller never failed,
and the replay prints it). Both are state that Windows keeps for a name beyond
the deletion of the account; the cells show the variant of the remote
authorization managers.

The first loop probe, with the baseline and the final candidate:

| Round | Name resolves to | S4U token of the account on the client | Baseline and final candidate, by name and by SID, with the default `-ServerName` and with the file server |
| --- | --- | --- | --- |
| 1 (new names) | the current SID | holds the outer group | `0x1200A9`, both modules, all four calls |
| 2 to 6 | the SID of the previous round in the first process of a round, the current SID in the second | lacks the new outer group | `0x100000`, both modules, all four calls |

The probe of the kit, `Probe-AccountRecreation.ps1`, which also logs the user on
with Kerberos S4U on the domain controller, the client, and the file server, gave
the same picture in four rounds with the baseline and the final candidate (04:19
UTC): in round 1, all three machines returned the current account and both
modules `0x1200A9` for every call; in rounds 2 to 4, all three returned the old
account, without the new outer group, and both modules `0x100000` for every call.
The own ticket cache of the computers (logon session `0x3e7`) held no ticket for
the account, and a purge of it changed nothing.

A third probe created five sets of accounts, logged each user on with S4U on the
three machines, deleted and created them again with the same names within a
second, and asked once per set after a delay (the sets after the first were
asked after a `klist purge` on the client, so the rows of the client for them
aren't independent):

| Question | Domain controller | File server | Client |
| --- | --- | --- | --- |
| At once | old account | old account | old account; Authz by SID `0x100000` |
| After `klist purge` on the client | old account | old account | current account (the token of the session); Authz by SID still `0x100000` |
| After `nltest /sc_reset`, a DNS flush on the client, and a restart of the Kerberos service of the domain controller | old account | old account | unchanged |
| 60 seconds after the accounts were created again | old account | old account | Authz by SID `0x100000` |
| 180 seconds | old account | old account | Authz by SID `0x100000` |
| 420 seconds | old account | old account | Authz by SID `0x100000` |
| 900 seconds | current account | current account | Authz by SID `0x1200A9`, also with the name of the file server |

`WindowsIdentity` with the user principal name, which the module doesn't call,
returns the old account in this regime, so the module isn't involved in it
either.

**What the evidence supports.** The failures of the Admin role depend on the
position of the cell relative to the previous fixture with the same account
name, and the module doesn't decide the outcome: not counting the warm-up, the
baseline fails in two of its three replay cells and the final candidate in one
of its three, and one model with one parameter predicts all 43 runs, including
three that it predicted before they ran. In a failing cell the remote
authorization managers of the client and of the file server are the wrong layer:
the name resolution, a Kerberos logon of the account, and the local
authorization manager are right in the same second, and the module makes the
same Authz calls for both kinds of manager. The replay gives no reason to change
the module for it.

**What it doesn't establish.** How Windows does it: which component keeps the
state, and why for about ten minutes. L is estimated from 43 runs on one client
and three file servers with a cell every five minutes or so, so a different
spacing of the cells could tell more. The window of L that fits the client test
is 0.3 minute wide, and its bounds come from two runs (`rc7h`, whose Core run is
9.92 minutes after the entry of `rc7g`, and `ab2`, 10.25 minutes after `ab0`).
The times of the model are those of the start of the Admin role, some seconds
before the first request, and the offset may differ between the editions, so the
bounds of L are uncertain by about that much. The model describes the
observations that it was fitted to, and the three predictions are the only ones
that it didn't see. The replay rules out a module effect that decides the
outcome (every position that the model predicts to fail failed for the
baseline, the final candidate, and the baseline again, and every position that
it predicts to pass passed for the final candidate, the baseline, and the final
candidate), but six runs can't rule out a small or a random effect of the
module. The replay ran one edition against one file server. Whether a user can
meet it, an administrator who deletes an account, creates it again under the same
name, and asks within ten minutes for its effective access on a remote computer,
wasn't tried outside the lab. The cmdlet can't detect it: the answer of a manager
that has no groups for the account looks like the answer for an account without
access.

**The change of the controller.** A new fixture gets a new name for the account
of case 3 (`NtfsLiveSubject` and four digits, `1dec389`), and a fixture that
exists keeps its account. No cache has to be flushed, and the module isn't
changed by this. With it, the Windows Server 2022 cell passed in `rc7l`, where the
cells of the old controller had failed in `rc7f`, `rc7h`, `rc7i`, and `rc7j`, and
so did the other two cells of that sequence.

The controller of `1dec389` (blob `9917cac5820ed20ed2eb5592eff06894677f9874`)
then ran four more cells of the replay, `ab7` to `ab10`: baseline, final,
baseline, final, in Windows PowerShell against OSFile22, back to back after a
restart of the client (05:37 to 05:58 UTC), with the same diagnostic test. Each
cell created a fixture with a new name for the account of case 3. I wrote the
prediction down before the Admin role of `ab7` ran (night log, about 05:40 UTC):
all four pass. For a controller that reuses the name, the model with L = 10.1
minutes predicts failures in `ab7` (the entry of `ab6` would have been 8.1
minutes old) and in `ab9` (5.4 minutes after `ab8`):

| Cell | Module | Account of case 3 | Admin role at (UTC) | Test 1 | Test 2 | Test 3, local manager | The model, had the name been reused (`-AsIfSameSubject`) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ab7` | baseline | `NtfsLiveSubject8013` | 05:40:11 | pass | pass | pass | Test 1 FAIL; Test 2 FAIL, unless the restart of the client at 05:34 cleared its entry |
| `ab8` | final | `NtfsLiveSubject0900` | 05:45:32 | pass | pass | pass | pass |
| `ab9` | baseline | `NtfsLiveSubject7705` | 05:50:54 | pass | pass | pass | both tests FAIL |
| `ab10` | final | `NtfsLiveSubject8799` | 05:56:12 | pass | pass | pass | pass |

The model doesn't know about restarts, and the client restarted ten times between
23:37 and 05:34 UTC, nine of them after the first cell had started (Hyper-V worker
log, UTC: 23:37, 00:38, 01:43, 01:58, 02:43, 03:23,
03:42, 04:07, 04:55, and 05:34; the file servers and the domain controller
didn't restart between the first and the last run, except OSFile22 at 01:36).
If the entry of a remote manager lives in the memory of the computer, a restart
clears it. For the fit this changes no prediction: of the entries that the model
keeps, only one lives across a restart and is read by a later run (the entry
that `rc7e` made at 00:35:48 on OSFile25, read by its Core run after the restart
at 00:38), and that run has the same account, so it passes either way. For the
counterfactual it matters once, in the table: the restart at 05:34 came between
`ab6` and `ab7`, so the client test of `ab7` is a prediction only if the state
survives a restart, while the file-server test (OSFile22 didn't restart) is one
in any case.

In each cell the diagnostic test printed the right rights for all five calls
(`0x1200A9` for the client, `0x1201BF` for the file server). In the timeline, the
old controller failed in 7 of its 20 cells, all on OSFile22 (`rc7f`, `rc7h`,
`rc7i`, `rc7j`, `ab1`, `ab3`, `ab5`); the new one failed in none of its 7 (`rc7l`
and `ab7` to `ab10`), where the model for a reused name predicts failures in 3
(the OSFile22 cell of `rc7l`, `ab7`, `ab9`). The cells aren't paired runs and
seven cells are few, so this doesn't prove that the new names are the reason; it
shows that the failures are absent where the model says that a reused name
fails, which the reuse of the name explains and the module doesn't.

## Limits and open items

- Every run is a validation of a local build (`-ModulePath`). The acceptance of
  a release is the run with `-Version` of the exact prerelease from the
  PowerShell Gallery in every cell, which handoff 3 sequences after the maintainer
  decides which fixes belong to 5.0.0-rc7. The same cells have to be repeated for
  a changed binary. The `-Version` path of `Run-MatrixSequence.ps1` ran once as a
  dry run with the published 5.0.0-rc6 on OSFile19 in Windows PowerShell (07:39 to
  07:45 UTC, kit at `664ef3a`): the controller used the published module, the
  validation reported `LIVE_RESULT_NOT_ACCEPTED` as it must (151 passed, 78
  failed, 2 skipped: the live tests that rc6 predates, such as the later-command
  tests, `Get-ChildItem2 -Filter`, `InheritedFrom`, and the two new ServerAdmin
  tests), and the cleanup verdict was CLEAN. That tests the mechanics only and
  accepts nothing.
- Case 9 (accounts of other domains and forests) needs trusts that the matrix
  lab doesn't have; it runs only in `WindowsAccessControlLab`, where the
  baseline passed it and the final candidate passed it in run `fl1` (see "First
  lab, final candidate (case 9)"). The published package has to run there too.
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
- The mechanism isn't known. The replay shows that the remote authorization
  managers answer for an account name from state that outlives the account, and
  the model puts the lifetime at about ten minutes (9.95 to 10.25 minutes for
  both tests, from 43 runs), but I didn't find which component keeps it, why that
  long, or whether it is constant: all runs have the same timing, and it was
  fitted to them. The replay ran one edition (Windows PowerShell, Desktop)
  against one file server (OSFile22). The probes of the first regime (accounts
  deleted and created again within seconds), in which the Kerberos S4U logon
  returned the old account for more than seven and less than fifteen minutes,
  were measured once, with no repetition, and five remedies (`klist purge`,
  `nltest /sc_reset`, a DNS flush, a restart of the Kerberos service of the
  domain controller, and waiting) were tried: only waiting helped. A script of
  the kit that creates accounts again under one name would meet the state; the
  controller doesn't any more.
- The end-state check of the matrix reported the staging folders of the suite
  runs (`C:\NtfsMatrixLocal`) as residue in the three cells of `rc7l`, which
  made their verdict DIRTY, although the fixture was gone. The suite runner now
  removes its stage after it has copied the results back. The check counts the
  items in the stage folders, each of the folders `C:\NtfsProbeRecreation` and
  `C:\NtfsProbeModules` that exists, the scheduled tasks of the matrix, the local
  `NtfsProbe*` users, their profiles and profile folders (`C:\Users\NtfsProbe*`),
  their entries in Performance Log Users, and the `NtfsProbe*` objects of the
  directory, and `-Mode Repair` removes what it finds. `Verify` and `Repair` treat
  every unresolved `S-1-5-21-…` member of Performance Log Users as the probe's
  (the probe is the only writer of that group in these labs, and its own cleanup
  uses the same pattern); on a machine where something else leaves such members,
  the check would report them and `Repair` would remove them. A `Verify` on the
  two machines of the first lab (07:29 UTC) found none. The check ran with real
  residue on the five machines three times: at 06:03 UTC with the script that
  `9344ff7` committed at 06:08 UTC, at
  06:44 UTC with the handling of profiles and of the entries in Performance Log
  Users that the follow-up review asked for, and at 06:51 UTC after the second run
  had shown that the check missed the entry of a local user (`net localgroup`
  lists a local user by its bare name, and the pattern wanted a domain prefix). A
  first attempt at 05:58 UTC died while it made the residue, without a log (the
  cause is unknown; decision log D37), so the run at 06:03 started in a lab where
  that attempt might have made some items; its first `Verify` listed exactly the
  expected ones.
  The last run made residue of every kind at once: a stage item and a local user
  `NtfsProbeDummy` on OSFile19; a local user with a profile and an entry in
  Performance Log Users on OSFile19; a local user with a profile that was deleted
  afterwards (an orphaned profile) on OSFile22; `C:\NtfsProbeRecreation` on
  OSFile22; a domain account that was made a member of Performance Log Users on
  OSFile22 and then deleted in the directory (`net localgroup` still showed it by
  its cached name); a scheduled task `NtfsMatrix-dummy` on OSFile25;
  `C:\NtfsProbeModules` on OSWin11E; and a disabled directory user
  `NtfsProbeDummy`. `Verify` counted every item (on OSFile19 `probe users=2 probe
  profiles=1 probe group members=1`, on OSFile22 `probe profiles=1 probe group
  members=1`, and so on), and the verdict expression of `Run-MatrixSequence.ps1`,
  read from the script with the parser and not copied, gave DIRTY. `Repair`
  removed every item, and a second `Verify` gave CLEAN. Not tried: a profile that
  stays loaded (the retries of `Repair` never needed a second attempt), and an
  entry that `net localgroup` shows as a bare SID, so the branch for a SID and
  `Remove-LocalGroupMember` with a SID didn't meet real residue (the cached name
  of the deleted domain account was removed by name).
- Decision 24 is the agent's decision under the maintainer's delegation and stays
  `proposed`. So do Decisions 22 and 23.

## Evidence

The raw logs, result files, probe outputs, and the packages are local, outside
Git, in the session files of the run; they aren't part of this commit. The
tables of this record are in the files next to it:

- [the suite results of the three candidates](Acceptance-2026-10-10-os-matrix-LocalSuite.csv),
- [the failing tests of every suite run](Acceptance-2026-10-10-os-matrix-Failures.csv),
- [the controller cells of `rc7c` to `rc7l`](Acceptance-2026-10-10-os-matrix-Cells.csv),
- [the timeline of the Admin role of every cell and edition, `rc7c` to `rc7l` and the replay `ab0` to `ab10`, with the three effective-access tests](Acceptance-2026-10-10-os-matrix-Timeline.csv),
- [the counts of the first-lab run `fl1`](Acceptance-2026-10-10-os-matrix-FirstLab.csv).

The scripts that produced them are in [Acceptance](Acceptance), and the
decision is `.memory-bank\decisions\0024-os-matrix-lab.md`.
