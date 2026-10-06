---
status: current
last-verified: 2026-10-06
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

5.0.0-rc4 is released and recorded. Next is 5.0.0, when the maintainer
decides; then the repository is archived in favor of WindowsAccessControl
(Decision 18). Issue #34 is open with Bug and Help Wanted; a user there
planned to test 5.0.0-rc3 against an IBM ESS file server.

## Evidence

- 2026-10-06: the tag `5.0.0-rc4` on `01d9264`, the merge commit of #113,
  published the prerelease to the PowerShell Gallery and to GitHub. The
  Gallery package and `NTFSSecurity.zip` hold identical module files; the
  package imports as 5.0.0-rc4 in both editions and passes the smoke tests
  of #41 and #34. CI passed for #113 and on `master`.
- The rc4 replies are posted: #41, #108, #109, and #111 are closed as
  completed, #90 and #107 got WontFix and are closed as not planned. The
  findings that the rc4 review deferred are listed in #113.
- Without the Security privilege, the tests that change the audit entries
  of a descriptor from `Get-NTFSSecurityDescriptor` skip; a basic-user run
  fails only the `Enable-Privileges -PassThru` count test (techContext).
- Hand commands to the maintainer as fenced code blocks at the end of the
  reply, and end the turn there; never put them in the question dialog,
  which also covers a reply before it. A pull request names an issue
  without a closing keyword unless the merge should close it (techContext).

## Next step

Before 5.0.0, read #34 for feedback from the tester. Then release 5.0.0 as
`progress.md` describes.
