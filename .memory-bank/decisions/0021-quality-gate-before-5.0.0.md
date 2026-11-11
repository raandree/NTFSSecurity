---
status: accepted
date: 2026-10-08
last-verified: 2026-11-11
owner: shared
source: maintainer decision of 2026-10-08; closing choices of 2026-10-19; status of 2026-10-20; Handoff 6 of 2026-11-10 to 11; another prerelease, 2026-11-11
---

# Decision 21: A quality gate before 5.0.0

- Choice: 5.0.0 ships only at the highest quality, with everything tested
  (maintainer, 2026-10-08). The gate has three phases:
  1. Measure 5.0.0-rc5: done on 2026-10-08 (`progress.md`).
  2. Add tests until every code path is tested or explained, live tests
     for the remaining cmdlets, and test-first fixes of the known defects;
     release them as 5.0.0-rc6. The maintainer approved it on 2026-10-08.
  3. Run the live tests on more operating systems, such as a Windows 11
     client and Server 2019 and 2022 file servers, then release 5.0.0.
- Exit criteria for 5.0.0, as proposed on 2026-10-08:
  - Every cmdlet and parameter set has behavior tests, error paths
    included.
  - No test is skipped in every configuration that runs.
  - The C# coverage is measured, and every path that no test runs is
    tested or explained.
  - Every known defect is fixed, or accepted by the maintainer and listed
    in the release notes.
  - The published package passes the live tests on every operating system
    of the matrix.
- Rationale: rc5 passed every test that ran, but the tests ran 55.9% of
  the code lines and 37.4% of the branches; five cmdlets had no tests of
  their own, and 19 cmdlets never ran over SMB. (That measurement counted
  only one of the four test runs; with all four, rc5 runs 58.1% of the
  lines and 38.0% of the branches, see `techContext.md`.)
- Open: behavior changes found on the way stay the maintainer's decision
  (Decision 16); so do the 244 lines of classes that no cmdlet calls, the
  operating systems of Phase 3, and how to cover file servers that aren't
  Windows (#34).

## Closing the gate (maintainer, 2026-10-19)

After Handoff 5 and the merges of #125 and #124 (`master` at `354ce04`), the
maintainer answered five questions, each time with the recommended option:

- rc8 is the next prerelease and carries `master`, which is ahead of rc7 by the
  seven product files of #125. Stable 5.0.0 is accepted through the last
  prerelease (`Docs/Contributing/05-Releasing.md`), so rc8 is mandatory.
- Code before rc8: fix the false "no access" of `Get-NTFSEffectiveAccess` (the
  swallowed initialization errors, a LOW finding of the security review),
  test-first, with an independent review. The hard-link names under a root that
  is not the volume root stay a known limit that the release notes list (the
  exit criterion allows "fixed, or accepted and listed"). The other open items
  of the paths report and of Handoff 5 are not decided yet.
- Test gaps: the plain test items that the ParameterSets table marks `budget`
  (68 mentions in the 57 sets that are not closed) are closed in a round of
  tests only, time-boxed to 2026-11-02; the report lists what is left. The
  shipped DLL does not change by it. A defect that a test finds needs its own
  decision and a new prerelease.
- #34: wait for a tester until 2026-11-02, then choose between waiting longer
  and accepting the untested risk (Decision 23, option 3).
- Decisions 22 and 24 are accepted (their records).
- A tester's result on rc7 counts for rc8 only while no change of rc8 touches
  the code that writes a section of a security descriptor (Decision 19). The
  seven product files of #125 have no such line, and the fix of
  `Get-NTFSEffectiveAccess` reads.
- Path to stable: the rc8 pull request (label `rc8`, `5.0.0-rc7` into
  `$publishedVersions`, changelog), the tag, the acceptance of the published
  rc8 (matrix cells, first lab, suite on the four machines), the stable pull
  request (no `Prerelease`, `## [5.0.0] - <date>`, `5.0.0-rc8` into
  `$publishedVersions`), the tag. The maintainer checks the expiry of
  `PSGALLERY_API_KEY` before the stable tag. After 5.0.0 the repository is
  archived (Decision 18), so what ships stays.

### Status on 2026-10-20

rc8 is published (tag `c719197`, Gallery 10:40:58Z) and accepted: the identity
check, three matrix cells 1,374/0/12, the suite in 24 runs, the first lab
245/0/1 per edition, every end state CLEAN (record
`Tests/Lab/Acceptance-2026-10-20-published-rc8.md`). The fix of the swallowed
initialization errors went in with a review (one Minor, the warning before the
error, fixed), and the hard-link known limit is in the pages and the
CHANGELOG. The exit criterion "matrix on published bytes" is met for rc8. The
tests-only round ran the same afternoon (report
`Tests/Coverage/Quality-Gate-Test-Round-2026-10-20.md`): 89 `It` blocks, 121
cases, the suite 1,494 to 1,615 per configuration with no failure, 38 of 64
parameter sets closed, 26 with a leftover (16 Limit, 7 MaintainerDecision, 3
would-pin), no defect. It is #129 (merged 2026-10-21); on the runner the
counts equal the local run in each test file. No plain gap is left. Open are
the 10 rows that wait for his decision (7 MaintainerDecision, 3 would-pin),
the decision on #34 (2026-11-02), and the key check. The stable build is new
bytes: the stable change may touch only the label, the CHANGELOG, and
`$publishedVersions`; any other product change needs rc9 and the same
acceptance.

### Status on 2026-11-10

The published rc9 is accepted with the old live tests (record
`Tests/Lab/Acceptance-2026-11-10-published-rc9.md`). A readiness check of the
same day found criteria 2 to 4 open for the final code: the C# coverage was
last measured on 2026-10-11 (33 C# product files changed since, 35 files in
rc9), the by-row check of the skipped tests was not repeated for the new tests,
and the known limits of Decision 27 were not in the release notes. The live
tests, unchanged since rc7, don't exercise the rc9 changes. The maintainer held
the stable tag and chose the focused scope (Handoff 6): the known limits are
accepted and listed in the CHANGELOG, none fixed in an rc10; the coverage of
`823c814` is measured, and every unvisited point of the changed files is tested
or explained; a time-boxed case 11 of the live tests is added and must fail on
the published rc8; the published rc9 is accepted again with the extended kit.
A defect that this work finds is reproduced on the published rc9, and he
chooses rc10 or accept-and-list. Criterion 4 asks for the listing in the
release notes, so Decision 7 (user-visible changes only) doesn't keep a known
limit out of the CHANGELOG.

### Status on 2026-11-11

Handoff 6 addressed criteria 2 to 4 for the published rc9, locally and for the
maintainer's approval (nothing is pushed), and changed nothing in the module,
the help file, or the manifest.
Criterion 3: the tag `823c814` is measured in four configurations, 3,666 of
4,074 sequence points (89.99%), and 3,672 (90.13%) with the 52 new unit cases.
Each of the 169 methods with an unvisited point (402 sequence points) is
classified by one of 35 rules, with its source, caller evidence, reason, and
residual risk; none is open, and the difference from `2112ee3` is explained
(report `Tests/Coverage/Quality-Gate-rc9-2026-11-10.md`). Criterion 2: of 8,856
rows, 834 are skipped, 417 distinct rows of 214 tests, each executed in two
other configurations. Criterion 4: the six known limits are in the `[5.0.0]`
section of the CHANGELOG on `ai/release-5.0.0`; five were reproduced on the
published rc9 in both editions, and one was read from the source. Criterion 5,
for what rc9 changed: case 11 of the live tests (191 tests per edition) fails
in 79 tests on the published rc8, each for the documented reason, and passes
on the published rc9 in the first lab (436 / 0 / 1 per edition) and in the
three cells (2,520 / 0 / 12); the module's suite passed in 24 runs (1,911
cases per configuration, the host 1,910), and every end state is CLEAN
(addendum `Tests/Lab/Acceptance-2026-11-10-published-rc9-case-11.md`). The
final unit suite on the tip passed in four configurations (2,214 cases each).
The built-in `code-review` agent read the work three times; its findings
(a probe gap and a missing cmdlet list in the release notes, a stale commit
count, and claims that said more than the evidence) are fixed. No new product
defect was found beyond the six accepted limits. Open for the maintainer:
confirm the 169
explanations, the six limits, and the reading of the empty rc10 field (none);
merge in the order of Decision 15; tag. The stable build is new bytes from the
same source, so the acceptance of the last prerelease stands in for it, which
the release procedure leaves to him.

### Another prerelease before stable (maintainer, 2026-11-11)

After #133 and #134 were merged, the maintainer chose one more prerelease
before 5.0.0, each time with the recommended option of the form:

- Label `rc9a`. The Gallery and PSResourceGet compare prerelease labels as
  text: NuGet.Versioning 6.9.1.3 ranks `5.0.0-rc10` below `5.0.0-rc9`, so
  `Install-Module -AllowPrerelease` and `Update-Module` would keep installing
  rc9; `rc9a` and `rtm` rank above it. rc9 is no longer the last prerelease
  (Decision 27).
- Scope: rc9's code. The module folders, the help file, `Docs/Cmdlets`, and
  `CHANGELOG.md` of `master` equal the rc9 tag; the note about #34 and the six
  known limits of `ai/release-5.0.0` move verbatim into `[Unreleased]`, the
  notes of a prerelease, so the stable change shrinks to the label, the
  heading, and `$publishedVersions`. This confirms the six limits and that none
  is fixed (the empty rc10 field of 2026-11-10).
- He chose that the agent pushes the branch and opens the pull request, but
  the hook of the house rules blocks an agent's push even then, so he runs
  both commands; he merges the pull request and pushes the tag.

rc9a is new bytes, so the stable tag waits for the acceptance of the published
rc9a: the identity check, the three cells, the first lab with case 11, and the
suite in 24 runs (about 1.5 hours on 2026-11-10 to 11).
