---
status: accepted
date: 2026-10-02
last-verified: 2026-10-02
owner: shared
source: maintainer decision after PR #91
---

# Decision 7: CHANGELOG lists user-visible changes only

- Choice: `CHANGELOG.md` lists only changes that module users or
  documentation readers can notice. CI and build-only changes, such as
  `appveyor.yml` or local build tooling, get no entry.
- Rationale: Agreed with the maintainer. It follows Keep a Changelog: the
  file tells users what changed, and git history covers CI and build work.
- Example: PR #91 lists the documentation rewrite but not the switch of
  `appveyor.yml` to building the module from source.
