---
status: current
last-verified: 2026-10-02
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Work packages 1 and 2 are pushed and green; the maintainer opens their
PRs: `ai/housekeeping` into `master`, and `ai/ship-help` into
`ai/housekeeping`. The agent can't open them (see `techContext.md`,
Constraints). The work packages and their order are in `progress.md`.

## Evidence

- AppVeyor 54834155 (`ai/housekeeping`, `74abb0b`) passed. AppVeyor
  54834154 (`ai/ship-help`, `fba3a7d`) passed all four `test_script`
  steps; Pester passed 218 of 218 tests in Windows PowerShell 5.1,
  including the `Get-Help -Online` tests.
- The same build listed 870 tests on the Tests tab: the NUnit import files
  each Pester 5 test under every enclosing block (Pester, file, Describe,
  Context), so 216 tests appear four times and 2 three times. The
  follow-up commit `c9fbaf5` reports the results through the build worker
  API instead (`POST api/tests/batch`); AppVeyor 54834216 of `c9fbaf5`
  passed and lists 218 tests, one entry each.
- The AppVeyor job log API returns `application/octet-stream`; decode the
  bytes as UTF-8 before searching it.
- Merging work package 1 with a merge commit keeps `ai/ship-help` valid;
  after a squash merge it needs
  `git rebase --onto origin/master ai/housekeeping ai/ship-help`.
- PR descriptions for both work packages are in the session folder
  (`files/pr`), outside the repository.

## Next step

The maintainer opens both PRs with the prepared `gh pr create` commands;
then work package 3 (Read the Docs) after the go-ahead.
