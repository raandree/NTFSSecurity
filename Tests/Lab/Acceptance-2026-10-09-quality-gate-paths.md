# Quality-gate paths follow-up acceptance, 2026-10-09

Live acceptance, in the lab, of the behavior that the fixes of
`ai/quality-gate-paths` change, as the handoff table of the
[path report](../Coverage/Quality-Gate-Paths-2026-10-09.md) asks. The branch
(28 commits on `f11ff41`, the head of #117; head `83149ee`, draft #118) is a
local candidate, tested from its extracted package with `-ModulePath`. It is
not a published package, and this record is not a claim that the quality gate
is complete. Architecture and cmdlet-design choices remain with the
maintainer (Decisions 16, 21, and 22).

## Method

New live tests, case 10 and one test of the Server role, check what each fix
changed. The same tests, controller, and lab ran against two builds, in new
processes for each edition: the candidate (`83149ee`) and the baseline
(`f11ff41`, the base of the branch). A test is evidence of a fix when it
passes on the candidate and fails on the baseline; a test that passes on both
is a control.

## Candidate and artifact identity

| | Candidate | Baseline |
| --- | --- | --- |
| Commit | `83149eedee0684bd0a0522865abd0bc6127f6bf5` | `f11ff412947b35d682878ac4a8121c949868fcb2` |
| `NTFSSecurity.dll` SHA-256 | `40D0C8A6B819F15AE69A21D4D510B3B3CFCE2D93294368046C707BD558E67C1F` | `96F087E2AA39D521018346CC9F0A23C8AE2EE2D8CB39AE0E9B7A9325CF47AB73` |
| `NTFSSecurity.5.0.0-rc7.nupkg` SHA-256 | `2AAE3403A2D1C3AEE5156F05441E46B85B855AF95B46A7B73D2F80435513D71D` | `06244B161F76F3A9DCCCFDE3D7D6C5D0D5FEB625127FBF1B298D935BCBD8A2E2` |
| `NTFSSecurity.zip` SHA-256 | `A5AFA241DCA5DF87080A9801BB336282BD424D70DA395F6456F2D74B7FC8076A` | `3DF287C9AC4A311E4093DE519DED046B94109F51B513ACBC1653EF483DB3A2C0` |

- Each build is a Release build (.NET Framework 4.5.2) in an isolated worktree
  of its commit, packaged by `.github/scripts/New-ModulePackage.ps1`. Both
  carry the label `5.0.0-rc7` and one assembly version, so every run used a
  new process. All 11 files of each tested module folder equal the extracted
  `NTFSSecurity.zip` byte for byte (SHA-256). The first packaging attempt, at
  20:41 UTC, stopped in both builds at the check of the build script that
  compares the package folder with the extracted zip ("The extracted ZIP
  differs from the module folder"); the logs of that attempt are kept. I
  changed the script (20:43) and built both again; the files that the lab
  tested are those of the second attempt, and the cause of the first
  mismatch wasn't recorded.
- Test source, identical in both runs (last written 20:56 and 20:54 UTC,
  before the candidate run started at 21:02): `NTFSSecurity.Live.Tests.ps1`
  (Git blob `67b85efeb45af67070538f241c203c4afa38b6f4`) and
  `Invoke-NTFSSecurityLabTest.ps1` (blob
  `0b46427bc32b0b15449e283a2a6cf67879937541`). Both are in the commit that
  adds this record.

## Tests added

Case 10 adds 78 tests per edition to the 166 of the acceptance at `3442194`
(244 in all): 75 in the roles on the client and 3 for the state that the file
server finds. The fixture adds the folder `Case10` with delegated Full
Control, the folder `Locked` that Administrators own, and files that
Administrators own for the cases of `Set-NTFSOwner`.

| Describe (roles) | Tests | Fail on baseline | Fail on candidate | Fix |
| --- | ---: | ---: | ---: | --- |
| An item that the account owns and whose owner may not change its permissions (Delegate) | 2 | 2 | 0 | `c7a0383` owner restore |
| InheritedFrom of access entries that Windows cannot resolve (3 roles) | 3 | 3 | 0 | `2909a1c` |
| InheritedFrom of audit entries that Windows cannot resolve (ServerAdmin, Admin) | 2 | 2 | 0 | `2909a1c` |
| InheritedFrom of an item below a folder whose permissions the account cannot read (Delegate) | 2 | 1 | 0 | `2909a1c` |
| A later command that ends the pipeline or throws, for the item cmdlets (3 roles; 16 each) | 48 | 48 | 0 | `c77ecbf`, `40bf6a8` |
| A later command and the error of a folder that Get-ChildItem2 cannot read (Delegate) | 3 | 2 | 0 | `c77ecbf` (break), `d44a200` (throw) |
| Get-ChildItem2 -Filter (3 roles; brackets, `*.*`, null) | 9 | 9 | 0 | `ee7c105`, `40bf6a8`, `ae3078f` |
| Privileges when a later command takes the debug messages (Delegate, Admin) | 6 | 4 | 0 | `d44a200` |
| State of the file server: only the first item changed (Server; one per role) | 3 | 3 | 0 | `c77ecbf`, `40bf6a8` |

The tests that pass on the baseline are controls (a precondition, or the
privileges the cmdlets hold). `b14c90b` (public object APIs) has no lab
scenario; the package smoke below runs its unit tests. The fix of the leaked
native buffer has no observable guard.

A first run of the new tests on the candidate in Windows PowerShell failed
five tests. All five were errors of the tests, not of the module: a native
`icacls` call that Pester's `Stop` turned into a terminating error, and
assertions that expected a descriptor to be written at a verbose stop, which
that stop prevents. The tests were corrected, and the runs below are complete
runs of the final test files.

## Package smoke

Before the lab run, the eight unit-test files that guard the fixes ran
against the extracted candidate package in a scratch tree, in the four
configurations of the report (650 cases each): elevated Desktop 643 passed,
elevated Core 642, basic Desktop 528, basic Core 527; none failed; 7, 8, 122,
and 123 were skipped by their own conditions, which the report's eligibility
check covers.

## Lab and rollback evidence

`WindowsAccessControlLab`: F1ADC1, F1BDC1, F2DC1, F3DC1, F1AFile1 (client),
and F1AFile2 (file server), all Windows Server 2025 (10.0.26100). At
20:41 UTC, authenticated WinRM, LDAP RootDSE, Kerberos tickets, member secure
channels, and clocks (skew at most 7 s) passed on all six machines. At 20:43
UTC, before the first test run, no `NTFSSecurityLive` OU or `NtfsLive*`
account existed. The runs changed no VM, operating system, or network
setting. A process listing at the start showed no other controller of these
tests on the host; it wasn't kept as a log.

Six checkpoints named `ntfs-qg-paths-83149ee-before-acceptance` were taken
at 20:45 to 20:46 UTC, one per machine; the Hyper-V listing that shows the
names is kept with the evidence. The policy of each machine is Production,
but Hyper-V reports the type Standard. As before, Production classification
is unverified, and no checkpoint was restored or deleted. Every machine now
carries seven checkpoints of the acceptances since 2026-10-08, F1AFile1 eight.

## Live results

Candidate run 21:02 to 21:19 UTC, baseline run 21:22 to 21:39 UTC, each in
Windows PowerShell 5.1 and PowerShell 7 against the extracted package. Both
editions gave the same counts in each build.

| Build | Role | Passed | Failed | Skipped |
| --- | --- | ---: | ---: | ---: |
| Candidate | Delegate | 69 | 0 | 0 |
| Candidate | ServerAdmin | 34 | 0 | 0 |
| Candidate | Admin | 64 | 0 | 0 |
| Candidate | Server | 76 | 0 | 1 |
| Baseline | Delegate | 42 | 27 | 0 |
| Baseline | ServerAdmin | 13 | 21 | 0 |
| Baseline | Admin | 41 | 23 | 0 |
| Baseline | Server | 73 | 3 | 1 |

Candidate, both editions: 486 passed, zero failed, two skipped; the skip is
the test that needs the module in the Server role, which doesn't import it.
Baseline, both editions: 338 passed, 148 failed, two skipped. Every role
exited 0 on the candidate. A joined verification of the result files (not of
the counts) found the same 488 tests in both builds, no duplicate, and every
one of the 148 baseline failures passed on the candidate. The 148 failures
are 74 tests in each edition, all among the 78 new tests of each edition
(case 10 and the state test); the four that pass on both builds are
preconditions. [The results file](Acceptance-2026-10-09-quality-gate-paths-Results.csv)
lists the 156 results (78 tests in two editions) with both outcomes and the
first line of the baseline message.

What the baseline shows, from its messages:

- Owner: `RestoreOwnerError ... (5) Access is denied` for the unchanged owner.
- `InheritedFrom`: a text of 13 characters instead of the 14 of
  `unknown parent`.
- Later command: the `Downstream failure` of a `throw` never reached the
  caller (the messages read `Expected like wildcard '*Downstream failure*' to
  match $null`), and a `break` of a later command didn't leave the caller's
  loop. For `Select-Object -First 1`, see the next section.
- `-Filter`: no result for a name with brackets; `*.*` returned only the
  three names with a dot and dropped `NoExtension` and `NoExtensionFolder`;
  `$null` gave `ArgumentNull` instead of the parameter validation error.
- Privileges: `TakeOwnership` still enabled after the pipeline stopped.

### Baseline failures without a message

Seven tests of each role, 21 per edition and 42 in all, fail on the baseline
with an empty message, and Pester prints no line for them: `Select-Object
-First 1` for the five item cmdlets, the verbose stop of
`Set-NTFSSecurityDescriptor`, and the debug stop of `Set-NTFSOwner`. This lab
run doesn't show what the baseline did in them. The State test of the Server
role shows it only for `Remove-Item2`: in each role, the second item was
removed after `Select-Object -First 1`. That test stops at its first failed
assertion, so it says nothing about the other cmdlets, and its assertions for
the debug and verbose stops check only that the second item is as it was,
which is also true when the client test never ran.

To close the gap, the bodies of these tests ran afterwards on this host, in a
sandbox below TEMP, with the settings of the runner (Pester 5.7.1,
`ErrorActionPreference` Stop), one build in one edition per process
(`Acceptance\Probe-LaterCommand.ps1`; it isn't part of the acceptance, and
it didn't run on a share). The result is the same in Windows PowerShell 5.1
and PowerShell 7:

| Cmdlet | Baseline `f11ff41`, after `Select-Object -First 1` and after `throw` | Candidate `83149ee` |
| --- | --- | --- |
| `Remove-Item2` | both items removed | the second item stays |
| `Copy-Item2` | both items copied | only the first is copied |
| `Move-Item2` | both items moved | the second item stays |
| `Set-NTFSOwner` | both owners changed, also at the debug stop | the second owner stays Administrators |
| `Set-NTFSSecurityDescriptor` | both descriptors written | only the first is written |

All 12 tests of the probe (seven stop rows, five `throw` rows) fail on the
baseline, the seven stop rows with no error record, as in the lab, and the
`throw` rows with the message of the lab; all 12 pass on the candidate. At the
verbose stop of `Set-NTFSSecurityDescriptor`, neither build writes a
descriptor, because the stop comes before the first write, so that failure on
the baseline isn't a change of state.

## Cleanup and review

Before the removal, the SIDs of the fixture were saved from the four domains
(10: seven in `a.forest1.net`, one each in `b.forest1.net`, `forest2.net`,
and `forest3.net`). The fixture was removed at 21:40 to 21:41 UTC with
`Invoke-NTFSSecurityLabTest.ps1 -RemoveFixture`. A separate read-only check
at 21:41 UTC, not the wrapper's marker, found in all four domains no
`NTFSSecurityLive` OU and no `NtfsLive*` account, and on F1AFile1 and
F1AFile2 no share, no `C:\NTFSSecurityLive` or `C:\NTFSSecurityLab`, no
`NtfsLiveLocal` group, no fixture member of Administrators, Access Control
Assistance Operators, or Remote Management Users, and no profile of the ten
SIDs. No checkpoint was restored.

One independent, read-only, static review of the finished change (tests,
fixture, README, this record and its results file, and Decision 22) ran
before the first commit. The custom `security-reviewer` can't start because
its configured model is unavailable, so the built-in code-review agent did
it. Verdict: approve with Minor; no Blocker and no Major. It confirmed that
the new tests can't pass vacuously (every precondition is asserted, the data
rows are not empty, nothing is shared between rows), that the fixture stays
below the guarded folders and throws when Administrators don't own the
files, and that the counts, the hashes, the 156 results, and the cleanup
facts of this record match the evidence. Its findings, all corrected in the
commit that follows the first: the fix that this record credited for the
`break` row, the claims about the State test and the 42 messageless
failures (now the section above, with the diagnostic), this heading, the
count of results, the wording about the folders before the run, the
truncated messages in the results file, the README row of case 10, and the
migration hint of item 8 and the comparison with `Copy-Item` in Decision 22.
It could not run anything, so the run state and the lab-wide claims rest on
the logs; the diagnostic above and the checkpoint listing close two of its
open points.

## Limits

- `Get-NTFSAudit` below an unreadable parent folder can't be built here: an
  account that may read the audit entries (it holds the Security privilege)
  also reads the DACL of an Administrators-owned folder. The audit scenario
  uses a file that was deleted after it was read, which reaches the same
  `unknown parent` text.
- The run covers the candidate package from disk (`-ModulePath`), not the
  published package, one lab, and Windows Server 2025 only. The other
  operating systems of Decision 21, the acceptance of the published
  prerelease, and the answer of a non-Windows file server (#34) stay with the
  other gates. The stable version remains 4.2.6.
- The candidate and the baseline differ only by the 28 commits; the test and
  controller files are the same.
- What the baseline did in the 42 failures without a message is shown by a
  local diagnostic, not by this lab run. A State test split per cmdlet and
  stop style would show it on the share too, and would need both lab runs
  again.

## Evidence

The result files, logs, hashes, readiness, checkpoint, snapshot, and cleanup
logs of both runs are in the session artifact
`4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files\lab-qg-paths` (local, not in Git);
so are the Hyper-V listing of the checkpoint names
(`checkpoints-83149ee-names.csv`) and the outputs of the diagnostic
(`runs\diagnostic-mute`, and `runs\diagnostic-mute-first-run` from before the
probe listed owners and entries). The per-test results of case 10 are in
[the results file](Acceptance-2026-10-09-quality-gate-paths-Results.csv). The
scripts that build, package, run, and clean up in this acceptance contain
paths of the session folder and stay in the session artifact; the generic
ones that it used, `Validate-LabResults.ps1` (the check of the result files)
and `Probe-LaterCommand.ps1` (the diagnostic), are in the folder
[Acceptance](Acceptance).
