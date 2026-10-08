---
status: accepted
date: 2026-10-07
last-verified: 2026-10-07
owner: shared
source: maintainer decision of 2026-10-07
---

# Decision 20: Live tests in a lab live in Tests\Lab

- Choice: The live tests that need a file server and domain accounts live
  in `Tests\Lab`: the Pester file `NTFSSecurity.Live.Tests.ps1`, the
  controller `Invoke-NTFSSecurityLabTest.ps1`, which prepares an
  AutomatedLab lab and runs the tests per module version and PowerShell
  edition, and a README with the cases. CI excludes the folder through
  `Run.ExcludePath` in `.github/scripts/Invoke-Tests.ps1`, and without a
  configuration every live test skips. The default lab is the one of
  WindowsAccessControl (`F1ADC1`, `F1AFile2`, `F1AFile1` in
  `a.forest1.net`), which the maintainer allowed on 2026-10-07.
- Rationale: The tests in `Tests` run on one computer with local accounts.
  #34 over SMB, the Security privilege that the file server checks,
  `Get-NTFSEffectiveAccess -ServerName`, and orphaned domain accounts need a
  file server and a domain. In the repository, a later release can repeat
  the tests and review them in a pull request.
- Rejected: a handoff folder outside the repository, which keeps the tests
  on one machine.
- Applied: 5.0.0-rc5.
