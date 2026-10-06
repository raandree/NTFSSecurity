---
status: accepted
date: 2026-10-06
last-verified: 2026-10-06
owner: shared
source: maintainer decision of 2026-10-06
---

# Decision 18: NTFSSecurity will be archived

- Choice: The repository will be archived soon, and its users move to
  [WindowsAccessControl](https://github.com/raandree/WindowsAccessControl),
  which is on the PowerShell Gallery. The README, the documentation home
  (also the wiki home), the `Deprecated` section of the changelog, and,
  since 5.0.0-rc3, the manifest `Description`, which the PowerShell Gallery
  shows, say so; keep these notes until the repository is archived. The
  module writes no warning on import, which would reach every script and
  scheduled task (maintainer, 2026-10-06).
- Before the archive: 5.0.0-rc3 for #34, #67, and the copied inherited
  entries, published on 2026-10-06, then 5.0.0. The maintainer decided on
  2026-10-06 to publish rc3 before 5.0.0.
