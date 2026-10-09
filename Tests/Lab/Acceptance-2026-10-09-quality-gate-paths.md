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
  `NTFSSecurity.zip` byte for byte (SHA-256).
- Test source, identical in both runs (last written 20:56 and 20:54 UTC,
  before the first run started): `NTFSSecurity.Live.Tests.ps1` (Git blob
  `67b85efeb45af67070538f241c203c4afa38b6f4`) and
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
| A later command and the error of a folder that Get-ChildItem2 cannot read (Delegate) | 3 | 2 | 0 | `d44a200` |
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
channels, and clocks (skew at most 7 s) passed on all six machines. No
`NTFSSecurityLive` OU or `NtfsLive*` account existed before the run. No VM,
operating system, or network changed, and no other session or controller
process used the lab.

Six checkpoints named `ntfs-qg-paths-83149ee-before-acceptance` were taken
at 20:45 to 20:46 UTC, one per machine. The policy of each machine is
Production, but Hyper-V reports the type Standard. As before, Production
classification is unverified, and no checkpoint was restored.

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
one of the 148 baseline failures passed on the candidate. All 148 failures are
among the 156 tests of case 10 and the state test, which
[the results file](Acceptance-2026-10-09-quality-gate-paths-Results.csv)
lists with both results and the first line of the baseline message.

What the baseline shows, from its messages:

- Owner: `RestoreOwnerError ... (5) Access is denied` for the unchanged owner.
- `InheritedFrom`: a text of 13 characters instead of the 14 of
  `unknown parent`.
- Later command: the second item changed after `Select-Object -First 1`; the
  `Downstream failure` of a `throw` never reached the caller; and a `break`
  of a later command didn't leave the caller's loop.
- `-Filter`: no result for a name with brackets; `*.*` returned only the
  three names with a dot and dropped `NoExtension` and `NoExtensionFolder`;
  `$null` gave `ArgumentNull` instead of the parameter validation error.
- Privileges: `TakeOwnership` still enabled after the pipeline stopped.

The 21 `Select-Object -First 1` tests per edition carry no message on the
baseline and no line in the Pester log. The State test shows independently
that the baseline changed the second item for each role.

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

## Evidence

The result files, logs, hashes, readiness, checkpoint, snapshot, and cleanup
logs of both runs are in the session artifact
`4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files\lab-qg-paths` (local, not in Git).
The per-test results of case 10 are in
[the results file](Acceptance-2026-10-09-quality-gate-paths-Results.csv).
