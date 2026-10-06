---
status: current
last-verified: 2026-10-05
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

5.0.0-rc2 is published. On 2026-10-05 the PRs #99 to #106 were merged into
`master` in order, each with a merge commit, and the tag `5.0.0-rc2` on the
merge commit of #106 (`7ddda8d`) published the module to the PowerShell
Gallery and created the GitHub prerelease through CI (Decision 12). Next:
test the prerelease, answer the issues, and decide between 5.0.0 and an rc3
for #34 and #67.

## Evidence

- The first CI runs of #100 to #106 failed an elevated test that had only
  skipped on the workstation, and from #104 on a second one. The audit
  inheritance cmdlets wrote no section for an item without a SACL, which
  Windows answers with "Access is denied"; and a test read a descriptor with
  its SACL, for which Windows doesn't mark the inherited entries of a DACL
  that isn't in the auto-inherit format. Fixed test-first in `629f4e7` on
  #106, red and green in both editions.
- CI of #106 at `629f4e7` and of `master` at `7ddda8d`: Windows PowerShell
  5.1 436 passed, 19 skipped; PowerShell 7 407 passed, 48 skipped; no
  failures. Before the merges, a simulation showed that each merge leaves
  `master` at the tree its pull request tested.
- The package from the Gallery imports in both editions as 5.0.0-rc2 with
  36 cmdlets and help, and `Disable-NTFSAuditInheritance` works on a file
  without audit entries.
- The merges closed #3, #4, #5, #17, #74, #82, #86, and #88 and deleted the
  eight `ai/` branches. Later that day the 37 issues that were open before
  the merges got their replies, 16 of them were closed (as completed when
  answered or already fixed, as not planned when not reproducible or won't
  fix), and the follow-up issues #107 to #111 were created; 18 issues are
  open. On 2026-10-06 the issues got their labels by Decision 17.
- Found while fixing the CI: elevated, `Add-NTFSAccess` and `Add-NTFSAudit`
  read the DACL together with the SACL, so the inherited entries of a DACL
  without the auto-inherit flag come back as explicit entries, and the write
  stores them as explicit copies. Same cause as #34: every section is read
  and written; the fix for #34 covers both.

## Next step

The maintainer tests 5.0.0-rc2, then decides between 5.0.0 and 5.0.0-rc3,
which would fix #34, #67, and the copied inherited entries.
