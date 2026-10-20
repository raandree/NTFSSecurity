---
status: accepted
date: 2026-10-08
last-verified: 2026-10-20
owner: shared
source: maintainer decision of 2026-10-08; closing choices of 2026-10-19; status of 2026-10-20
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
CHANGELOG. The exit criterion "matrix on published bytes" is met for rc8; open
are the tests-only round (until 2026-11-02), #34 (2026-11-02), and the key
check. The stable build is new bytes: the stable change may touch only the
label, the CHANGELOG, and `$publishedVersions`; any other product change needs
rc9 and the same acceptance.
