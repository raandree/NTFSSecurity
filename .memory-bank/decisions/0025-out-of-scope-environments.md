---
status: accepted
date: 2026-10-11
last-verified: 2026-10-11
owner: shared
source: maintainer decision of 2026-10-11
---

# Decision 25: Four environments are out of scope for the tests and the acceptance

- Choice: The tests and the acceptance of the quality gate do not cover
  Windows Server Core, ARM64, a localized operating system, or file servers
  that are not Windows servers. They are not open items, and no agent plans,
  deploys, or tests them (maintainer, 2026-10-11).
- Rationale: The audience of the tool does not need them (maintainer).
- Not changed: Decision 23 and #34, the question of what to do for reporters
  with non-Windows file servers, stay as they are until the maintainer says
  otherwise.
