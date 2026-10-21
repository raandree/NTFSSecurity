# Quality gate, the tests-only round, 2026-10-20

The maintainer decided on 2026-10-19 (Decision 21, "Closing the gate") that the
plain test gaps of the quality gate are closed in a round of tests only, until
2026-11-02, and that this report lists what is left. The gaps are the items that
the ParameterSets table of the
[report of Handoff 5](Quality-Gate-Unknowns-2026-10-10.md) calls `budget`: plain
test work that needs no decision and no lab, 68 mentions in 51 of its 64
parameter sets. Nothing in the shipped module, the cmdlet pages, or the CI
changed; rc8 stays the candidate of the stable build. The round closes the plain
gaps; it does not close the gate (#34 and the check of the Gallery API key are
open), and a closed row says that its plain gaps are tested, not that the
cmdlet is.

## Result in short

- **The tests.** 89 new `It` blocks, which run as 121 cases per configuration,
  in the four `ParameterSets.*.Tests.ps1` files. The suite goes from 1,494 to
  1,615 cases per configuration, with no failure in Windows PowerShell 5.1 and
  PowerShell 7, elevated and as a basic user, on the host and on the CI runner.
- **The parameter sets.** 38 of 64 are closed (7 before). 31 sets changed to
  closed, among them the one that was open (`Test-Path2`). The one set that had
  no judgement, `Set-NTFSSecurityDescriptor`, is now partly closed. 26 sets have
  something left, and every leftover is named in the table below: 16 are limits
  (no test can reach it, or it needs a lab or a remote server), 7 wait for the
  maintainer, and 3 would pin an inconsistency.
- **No defect.** None of the 121 new cases found a behavior of a cmdlet that
  contradicts its page or common sense. Four expectations of the implementers
  were wrong at first and were corrected in the tests, and my own helper script
  had a defect (see "What the tests showed").
- **No product change, so no new prerelease.** The package of rc8 is the one
  that the labs accepted on 2026-10-20. A defect that a test had found would
  have needed the maintainer's decision and rc9.

## The tests

Four implementer agents each worked in a worktree of `master` at `715c254` and
changed one test file, so that the batches could not conflict. Each had the
same brief: pin observable behavior through the public surface, read state back
with an oracle that is independent of the cmdlet under test (.NET `Get-Acl` and
`FileSecurity`, SDDL, `[IO.File]`, `Get-Item`, `icacls`), assert concrete
values, build every fixture in the sandbox, make sure that at least one of the
four configurations runs each test, and leave out what the reason column of its
worklist calls `would-pin`, `Limit`, `MaintainerDecision`, or `lab`. A defect
was to be reported, not fixed.

| Group | Test file | New `It` | New cases | Sets closed | Negative check |
| --- | --- | ---: | ---: | ---: | --- |
| access | `ParameterSets.Access.Tests.ps1` | 20 | 32 | 6 | 20 flipped, the 32 cases failed |
| audit | `ParameterSets.Audit.Tests.ps1` | 9 | 10 | 4 | 9 flipped, the 10 cases failed |
| inheritance | `ParameterSets.Inheritance.Tests.ps1` | 15 | 25 | 11 | 15 flipped, 25 failed elevated, 16 as a basic user (9 skip) |
| items | `ParameterSets.Items.Tests.ps1` | 45 | 54 | 10 | 45 flipped, 51 failed elevated, 39 as a basic user (12 skip); the other 3 flipped later |
| Total | | 89 | 121 | 31 | |

The negative check is a copy of the file in which each new `It` has one
expectation flipped (a value, a count, a category, a type). Every flipped case
failed in each configuration where it runs, and no other case failed. In the
items batch, 3 of the 54 cases had not been flipped: the Move-Item2, Get-Item2,
and Remove-Item2 rows of the test for a path with brackets, which share one
`It` with the Copy-Item2 row that was flipped. I flipped them afterwards in a
copy, and all three failed in all four configurations while the Copy-Item2 row
stayed green. So each of the 121 new cases is known to fail when what it pins
changes.

Each batch also ran three times in all four configurations with identical
results, and `Invoke-ScriptAnalyzer` reports no finding on any of the four
files. The four diffs add 1,781 lines and delete none: no existing test was
changed, renamed, or moved.

A new case skips where the token lacks what it needs, and runs in the other
configurations. These are the 30 new cases that skip as a basic user, in both
editions:

| Needs | Cases | Where |
| --- | ---: | --- |
| the Security privilege (the SACL, audit entries) | 17 | audit 9, inheritance 8 |
| a drive mapping | 5 | items |
| the administrative share | 3 | items |
| the symbolic-link privilege | 2 | items |
| an elevated token, for the privilege states | 2 | items |
| an owner other than the user (a basic user owns the new items) | 1 | inheritance |

One new case skips when elevated: the `Get-NTFSOrphanedAudit` error without the
Security privilege runs only as a basic user. So each new case runs in at least
two configurations, and none skips in all four. The skipped counts moved
accordingly: elevated 26 to 27 (Windows PowerShell) and 57 to 58 (PowerShell
7); as a basic user 291 to 321 and 322 to 352.

## The suite

The suite is the CI test step, run in four configurations on the host (Windows
Server 2025), against a Release build of the branch. The counts are those of the
NUnit result files of the run, and the new cases per file are the differences of
the counts per test file between this run and the last run before the round
(`Measure-RoundSuiteDelta.ps1`, in the evidence).

| Configuration | Executed | Skipped | Failed | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,588 | 27 | 0 | 1,615 |
| Windows PowerShell 5.1, basic user | 1,294 | 321 | 0 | 1,615 |
| PowerShell 7, elevated | 1,557 | 58 | 0 | 1,615 |
| PowerShell 7, basic user | 1,263 | 352 | 0 | 1,615 |

`master` has 1,494 cases per configuration, with 26, 291, 57, and 322 skipped.
An earlier run with the audit, access, and items batches (1,590 cases) was also
green in all four configurations.

The CI of the pull request (#129) ran the same steps on a GitHub runner
(`windows-2025`, run 39551726767, 14 minutes). Its four configurations gave the
counts of the table above with no failure, and each of the 29 test files has
the same number of executed and skipped cases as in the local run. So the new
cases that need a drive mapping, the administrative share, or a symbolic link
ran there too: the runner user is a local administrator.

## What is left

Every parameter set that is not closed, with the kind of what is left. The
table of all 64 sets, with the status before and after, the new tests of each
(file, line, and name), and what is left, is
[the CSV of this round](Quality-Gate-Test-Round-2026-10-20-ParameterSets.csv).

| Kind | Cmdlet / parameter set | What is left |
| --- | --- | --- |
| MaintainerDecision | `Add-NTFSAccess` / SDSimple | the terminating error of a failing change (a deny entry without rights) is not pinned |
| MaintainerDecision | `Add-NTFSAccess` / SDComplex | the terminating error of a failing descriptor is not pinned |
| MaintainerDecision | `Remove-NTFSAccess` / SDSimple | the terminating error of a failing removal is not pinned |
| MaintainerDecision | `Remove-NTFSAccess` / SDComplex | the terminating error of a failing removal is not pinned |
| MaintainerDecision | `Add-NTFSAudit` / SDSimple | exceptions from the change itself (open item 1 of Handoff 5) |
| MaintainerDecision | `Add-NTFSAudit` / SDComplex | exceptions from the change itself (open item 1 of Handoff 5) |
| MaintainerDecision | `Remove-NTFSAudit` / SDComplex | exceptions from the change itself (open item 1 of Handoff 5) |
| would-pin | `Get-NTFSAccess` / Path | the category of the `ReadSecurityError` after a failed ownership retry (WriteError there, OpenError from the generic catch) is not asserted, so as not to cement the inconsistency |
| would-pin | `Get-NTFSOrphanedAccess` / Path | the choice of a warning, not an error, for a read failure other than access denied |
| would-pin | `Set-NTFSSecurityDescriptor` / all sets | positional binding at Position 2 (the sibling cmdlets use Position 1), an undecided inconsistency |
| Limit | `Get-NTFSAccess` / SD | no failing descriptor is tested for this set (no per-item handler) |
| Limit | `Get-NTFSSimpleAccess` / SD | no failing descriptor is tested for this set (no per-item handler) |
| Limit | `Get-NTFSEffectiveAccess` / Path | the `ReadEffectivePermissionError` handler is unreachable (the library records the failure); remote and group-based results need the lab (the live tests cover them) |
| Limit | `Get-NTFSEffectiveAccess` / SecurityDescriptor | a mix of a failing and a succeeding descriptor in one call |
| Limit | `Add-NTFSAudit` / PathComplex | the owner retry after access denied needs a lab or a remote server |
| Limit | `Remove-NTFSAudit` / PathComplex | the owner retry after access denied needs a lab or a remote server |
| Limit | `Clear-NTFSAudit` / Path | the owner retry after access denied needs a lab or a remote server |
| Limit | `Get-NTFSAudit` / Path | the PermissionDenied category branch of `ReadSecurityError` |
| Limit | `Disable-NTFSAuditInheritance` / Path | a successful ownership retry or `RestoreOwnerError` of a SACL write needs a lab or a remote server |
| Limit | `Enable-NTFSAuditInheritance` / Path | a successful ownership retry or `RestoreOwnerError` of a SACL write needs a lab or a remote server |
| Limit | `Get-NTFSInheritance` / Path | a successful ownership-retry read needs a lab or a remote server |
| Limit | `Get-NTFSSecurityDescriptor` / all sets | a successful ownership-retry read needs a lab or a remote server |
| Limit | `Get-FileHash2` / all sets | the success path of the ownership retry (elevated only; the DACL and owner that give it can't be built in a sandbox) |
| Limit | `Get-NTFSHardLink` / all sets | the `UnauthorizedAccessException` handler is structurally unreachable (Windows lists hard-link names without opening the file) |
| Limit | `Disable-Privileges` / all sets | the warning when a privilege cannot be disabled needs a race with another command |
| Limit | `Get-Privileges` / all sets | the `Removed` value of `PrivilegeState` is unreachable: a removed privilege leaves the list of the token instead of showing the value (a probe before and after confirmed it) |

The 7 decisions and the 3 pins are the maintainer's, as in the report of
Handoff 5; nothing here decides them. The dot patterns of
`Get-ChildItem2 -Filter` are also still his (the row is closed because its
plain gaps are tested, not because the patterns are decided). The "ownership
retry" limits are the paths that run when a cmdlet has to take an owner to read
or write a security descriptor. The report of Handoff 5 explains why no unit
test reaches them (and lists `AUDIT-OWNER-RETRY` as open), so they stay
explained, not tested.

## What the tests showed

- **No defect.** The four implementers found no behavior that contradicts the
  cmdlet page or common sense, and their `defects` folders are empty.
- **`Get-Privileges` and `Removed`.** The `Removed` value of `PrivilegeState`
  can't appear in the output: after a privilege is removed from a token, the
  token's list no longer has it. A probe before and after showed it. The row
  is a limit, not a test gap.
- **`Move-Item2 -Force` onto a non-empty folder replaces it**, with no merge and
  no error. `Docs/Cmdlets/Move-Item2.md` documents the replace, and the new test
  pins it.
- **Four expectations were wrong at first and were corrected in the tests**,
  none of them a defect:
  - `Get-NTFSOrphanedAudit` without the Security privilege reports the category
    `OpenError`, as `Get-NTFSAudit` does, not `PermissionDenied` (that category
    is the limit above).
  - After `Disable-NTFSAuditInheritance` without `-RemoveInheritedAuditRules`
    and a plain enable, an item has two audit entries, not one: the disable
    copies the inherited entry into the SACL as an explicit one, and the cmdlet
    page says so.
  - `-PassThru` of `Copy-Item2` and `Move-Item2` is a `Boolean` that needs a
    value, not a switch, as their pages say.
  - The access-denied test of `Remove-Item2` needs a deny entry on the parent
    folder (`DeleteSubdirectoriesAndFiles`) and one on the file (`Delete`),
    because NTFS grants a delete through either.
- **A defect of my helper script, not of the module.** The inheritance
  implementer reported that its basic-user runs stalled for about 30 minutes,
  twice, and took it for an effect of the load of four agents at once; another
  group's job stuck the same way. The cause was the helper that runs the
  configurations of a batch: a test-name filter with spaces did not survive the
  nested quotes of `runas`, the child never started, and the helper waited for
  its whole timeout. The filter now travels as base64, and the helper gives up
  after a minute without a runner. The suite numbers above come from the run of
  the four CI configurations, which takes no name filter and did not stall.

## Checks not run, and limits

- The new cases ran on Windows Server 2025 only, on the host and on the runner.
  The suite of the rc8 acceptance ran on six machine classes, but before these
  cases existed, so they have not run on Windows Server 2019 or 2022 or on
  Windows 11.
- No lab run: the product bytes did not change. The acceptance of rc8 of
  2026-10-20 stands for them.
- No independent review agent ran on the four batches. I read the diffs of all
  four commits (the added lines, the oracles, and the places where a test
  touches the system). A review of the 1,781 added lines is still possible
  before the merge.
- The mutated copies of the negative checks were deleted. The per-batch results
  rest on the reports of the implementers (in the evidence); only the three
  bracket rows of the items batch were flipped and run again by me.
- The negative checks flip one expectation of a test; they are not a mutation
  test of the product. The mutations of the product were not run again; the
  last ones are in `Quality-Gate-Unknowns-2026-10-10-Mutations.csv`.
- The code coverage was not measured again; the numbers of Handoff 5 remain the
  last measurement.
- The leftovers marked `Limit` are explained from source and from a probe; an
  explanation is not a test.

## Evidence outside git

The raw evidence is in the session folder
`C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns`
(`E`). [The Evidence CSV](Quality-Gate-Test-Round-2026-10-20-Evidence.csv)
lists its files with size and SHA-256; the four worktrees of the implementers
are not in it. The commits of the batches are `7c3de81` (audit), `472003e`
(access), `e32e36a` and `9a2a809` (items), and `404ceca` (inheritance) of the
branch `ai/tests-round-1`.

| Path in `E` | Content |
| --- | --- |
| `round1\IMPLEMENTER-BRIEF.md`, `round1\worklist-*.md` | the brief of the implementers and the four worklists (the rows with their remaining items, reasons, and key tests) |
| `round1\reports\report-*.md` | the final reports of the four implementers, verbatim, with the counts, the negative checks, and the follow-up on the three unflipped rows of the items batch |
| `round1\<group>\commit-diff.txt`, `source-pin.txt` | the diff of the access, inheritance, and items batches (the audit batch has none) and, for each group, the commit that its worktree started from (`715c254`) |
| `round1\suite\rc8suite-20261020-093109` | the last run of the four CI configurations before the round (1,494 cases per configuration) |
| `round1\suite\round1-three-20261020-141224`, `round1\suite\round1-four-20261020-142909` | the runs with three and with all four batches (1,590 and 1,615 cases), each with the NUnit file, the log, and the summary of the four configurations |
| `round1\suite\delta-four-vs-baseline.txt` | the output of `Measure-RoundSuiteDelta.ps1`: the new cases per file and configuration, and the 30 and 1 that skip |
| `round1\suite\runner-39551726767` | the CI run of #129 on the GitHub runner: the log of the job `Build and test`, the four NUnit files of the artifact `test-results`, and the output of `Measure-RoundSuiteDelta.ps1` for them (GitHub deletes logs and artifacts after its retention period) |
| `round1\tables-draft` | the draft of the ParameterSets CSV |
| `scripts` | `Build-Worklists.ps1`, `Build-RoundTables.ps1` (the CSV of this round), `Invoke-RoundJob.ps1`, `Invoke-Build.ps1`, `Run-FocusedPester.ps1`, `Start-FocusedRuns.ps1` (the helper with the quoting defect, fixed), `Run-FullSuite.ps1`, `Run-CiConfiguration.ps1`, `Measure-RoundSuiteDelta.ps1` |
