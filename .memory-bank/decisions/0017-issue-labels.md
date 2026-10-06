---
status: accepted
date: 2026-10-06
last-verified: 2026-10-06
owner: shared
source: maintainer decision of 2026-10-06
---

# Decision 17: Issue labels

- Choice: Issues carry the labels of the repository by these rules. The
  maintainer approved them on 2026-10-06, and they were applied to the
  issues triaged on 2026-10-05.
  - **Bug**: a confirmed bug, open or fixed. An unconfirmed report gets no
    type label.
  - **Enhancement**: a feature request or an improvement, also of the tests.
  - **Documentation**: a request for documentation or a gap in it.
  - **Question**: a usage question, with **Solution Delivered** once it is
    answered. A documentation request that the docs answer gets
    **Documentation** and **Solution Delivered**.
  - **WontFix**: the cause is outside the module, or a fix is too complex.
  - **Help Wanted**: the maintainer needs help from outside, such as a
    tester with a file server for #34.
  - **Needs Info**, added on 2026-10-06: the issue waits for the reporter.
  - **CodePlex** marks the issues migrated from CodePlex, **Duplicate** a
    duplicate.
- Closing: answered and fixed issues close as completed, not reproducible
  ones and won't fix as not planned. A not reproducible issue keeps its
  labels; the close reason says enough.
- Rationale: The labels existed but weren't applied consistently. Fixed
  bugs carried Question or no label, and nothing marked the issues that
  wait for their reporters.
