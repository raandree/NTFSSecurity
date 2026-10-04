---
status: accepted
date: 2026-10-02
last-verified: 2026-10-04
owner: shared
source: maintainer choice in work package 2 (option A)
---

# Decision 8: Commit the generated help file and check it in CI

- Choice: `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml` is generated from
  `Docs/Cmdlets` with `New-ExternalHelp` (platyPS 0.14.2, Windows
  PowerShell 5.1) and committed. `NTFSSecurity.csproj` copies it to the
  output as `Content`, the manifest `FileList` lists it, and the CI workflow
  (`.github/workflows/ci.yml`) regenerates it and fails on
  `git status --porcelain -- NTFSSecurity/en-US`.
- Rationale: Releases are built locally in Visual Studio (Debug, written to
  `C:\Program Files\WindowsPowerShell\Modules\NTFSSecurity`) and published
  by hand with `Publish-Module`. A committed file ships with every build
  and needs no tool on the build machine. Generating it in an MSBuild step
  would need platyPS on every build machine, or would silently ship without
  help when platyPS is missing.
- Consequence: every change to `Docs/Cmdlets` must be followed by
  `New-ExternalHelp -Path .\Docs\Cmdlets -OutputPath .\NTFSSecurity\en-US
  -Force`. The output is deterministic (byte-identical between runs), so
  the CI check is exact.
- Rejected: an MSBuild `AfterBuild` target that runs platyPS.
