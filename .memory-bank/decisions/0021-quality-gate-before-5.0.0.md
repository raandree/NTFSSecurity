---
status: accepted
date: 2026-10-08
last-verified: 2026-10-08
owner: shared
source: maintainer decision of 2026-10-08
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
  their own, and 19 cmdlets never ran over SMB.
- Open: behavior changes found on the way stay the maintainer's decision
  (Decision 16); so do the 244 lines of classes that no cmdlet calls, the
  operating systems of Phase 3, and how to cover file servers that aren't
  Windows (#34).
