---
status: accepted
date: 2026-10-02
last-verified: 2026-10-02
owner: shared
source: PR #91 (moved from systemPatterns.md)
---

# Decision 5: Document defects, don't fix them in docs work

- Choice: Code defects found while documenting are described on the affected
  page (workaround or limitation) and listed in `progress.md`; source code is
  changed only in separate, tested work.
- Rationale: No build toolchain was available to verify code changes, and
  the docs must describe current behavior.
