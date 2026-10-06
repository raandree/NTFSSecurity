---
status: current
last-verified: 2026-10-06
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

5.0.0-rc3 is released and recorded. Next is 5.0.0, when the maintainer
decides; then the repository is archived in favor of WindowsAccessControl
(Decision 18). Issue #34 is open with Bug and Help Wanted and waits for a
tester with a file server that refuses the owner; #67 is closed as not
planned.

## Evidence

- 2026-10-06: the tag `5.0.0-rc3` on `914e8da`, the merge commit of #112,
  published the prerelease to the PowerShell Gallery and to GitHub. The
  Gallery package and `NTFSSecurity.zip` hold identical module files and
  import as 5.0.0-rc3 in both editions; CI passed for #112 and on `master`.
- The replies to #34 and #67 are posted. The merge of #112 closed #34,
  because the PR description said "fixes #34"; the maintainer reopened it.
- The cmdlets write only the sections that they change (Decision 19); the
  manifest `Description` announces the archive (Decision 18).
- Hand commands to the maintainer as fenced code blocks at the end of the
  reply, and end the turn there; never put them in the question dialog,
  which also covers a reply before it. A pull request names an issue
  without a closing keyword unless the merge should close it (techContext).
  A handoff outside the repository fixes the hand-over in the user-level
  Customizations.

## Next step

Before 5.0.0, read #34 for feedback from a tester. Then release 5.0.0 as
`progress.md` describes.
