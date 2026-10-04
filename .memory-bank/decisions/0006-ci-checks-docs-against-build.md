---
status: accepted
date: 2026-10-02
last-verified: 2026-10-04
owner: shared
source: PR #91 (moved from systemPatterns.md)
---

# Decision 6: CI checks the docs against a build of the source

- Choice: The CI workflow (`.github/workflows/ci.yml`, Decision 11; before
  that `appveyor.yml`) builds `NTFSSecurity.csproj` and runs
  `Update-MarkdownHelp` against `NTFSSecurity\bin\Release`, not against the
  module from the PowerShell Gallery.
- Rationale: Checking against the last release fails for every unreleased
  parameter change (PR #91 failed on `Remove-Item2 -PassThru`) and never
  compiled the code.
