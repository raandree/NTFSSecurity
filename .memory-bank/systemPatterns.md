---
status: current
last-verified: 2026-10-09
owner: active-agent
source: repository and regression evidence
---

# System patterns

## Architecture

| Component | Responsibility |
| --- | --- |
| `NTFSSecurity.psd1` | Root script, nested binary, initialization, types, help |
| `NTFSSecurity.Init.ps1` | Loads Security2/privilege assemblies and prepends formatting |
| `NTFSSecurity.dll` | 36 PowerShell cmdlets; BaseCmdlet path/privilege behavior |
| `Security2.dll` | DACL/SACL objects, owners, inheritance, effective access, Win32 |
| AlphaFS | Long-path files/directories/links |
| PrivilegeControl / ProcessPrivileges | Token privilege operations |
| `en-US/NTFSSecurity.dll-Help.xml` | Committed help generated from cmdlet Markdown |

## Decisions

Read only task-relevant records; the index controls routing.

| # | Decision |
| --- | --- |
| 1 | [Use the canonical Memory Bank base](decisions/0001-canonical-memory-bank.md) |
| 2 | [Cmdlet reference stays platyPS markdown](decisions/0002-platyps-cmdlet-reference.md) |
| 3 | [Document the source at HEAD](decisions/0003-document-source-at-head.md) |
| 4 | [Online help points to GitHub](decisions/0004-online-help-on-github.md) |
| 5 | [Document defects, don't fix them in docs work](decisions/0005-document-defects-separately.md) |
| 6 | [CI checks the docs against a build of the source](decisions/0006-ci-checks-docs-against-build.md) |
| 7 | [CHANGELOG lists user-visible changes only](decisions/0007-changelog-user-visible-only.md) |
| 8 | [Commit the generated help file and check it in CI](decisions/0008-commit-generated-help.md) |
| 9 | [Keep the documentation on GitHub](decisions/0009-docs-on-github.md) |
| 10 | [One version for the manifest, assemblies, and changelog](decisions/0010-one-version.md) |
| 11 | [CI and the wiki run on GitHub Actions](decisions/0011-github-actions.md) |
| 12 | [Releases are built and published by CI on a version tag](decisions/0012-ci-releases.md) |
| 13 | [Set-NTFSInheritance keeps entries like the dedicated cmdlets](decisions/0013-set-inheritance-keeps-entries.md) |
| 14 | [Repository hardening is optional](decisions/0014-repository-hardening-optional.md) |
| 15 | [Merge stacked pull requests in order with merge commits](decisions/0015-merge-stacks-with-merge-commits.md) |
| 16 | [Fix only reproducible bugs](decisions/0016-fix-reproducible-bugs-only.md) |
| 17 | [Issue labels](decisions/0017-issue-labels.md) |
| 18 | [NTFSSecurity will be archived](decisions/0018-archive-for-windowsaccesscontrol.md) |
| 19 | [Cmdlets write only the sections that they change](decisions/0019-write-only-changed-sections.md) |
| 20 | [Live tests in a lab live in Tests\Lab](decisions/0020-live-tests-in-tests-lab.md) |
| 21 | [A quality gate before 5.0.0](decisions/0021-quality-gate-before-5.0.0.md) |
| 22 | [The behavior changes of Phase 2 (proposed)](decisions/0022-phase-2-behavior-changes.md) |

## Patterns

### Cmdlets and security sections

- BaseCmdlet resolves relative paths against the current filesystem
  location; file-object input binds FullName through path transformation.
- Write only changed/read sections (Decision 19); a descriptor parameter
  changes memory until `Set-NTFSSecurityDescriptor` persists it.
- Access denial can retry through InvokeAsOwner; restore the previous owner
  on every exit, except a successful descriptor write that intentionally
  sets the owner. Restoration failures must report RestoreOwnerError.
- Privilege cleanup runs in EndProcessing and Dispose, reads current states,
  attempts all cleanup, and preserves explicit enables. Dispose has no stream.
- Pipeline getters never throw; per-item errors name input and allow continuation.
- Folder moves never use CopyAllowed; preserve cross-volume source folders.
- Apply implied Hidden/Force before deciding to emit, including the first item.
- A catch-all for the failures of one item must pass on what a later command
  raises through a Write call. A downstream throw is an ordinary exception,
  so a type check finds only the end of the pipeline, break, and continue.
  BaseCmdlet notes the exception that its WriteObject, WriteError,
  WriteVerbose, and WriteDebug raised (WriteWarning is not noted: no catch-all
  encloses it); `IsFromLaterCommand` recognizes it, and the type check
  `PipelineControl.IsEnd` backs it up for other calls into PowerShell. A write
  inside a helper, such as the owner restore of `InvokeAsOwner`, is an
  accepted gap: its handler reports the item's own error, which raises too.
  Prefer writing outside the try. `Tests/PipelineControl.Tests.ps1` has rows
  for every cmdlet: add a row for a new one, and keep the typed-throw rows
  (they fail if PowerShell stops wrapping a thrown exception).
- Record an enabled privilege before the next write, which a later command
  can answer with an exception: Dispose disables only what is recorded.
- `Get-ChildItem2 -Filter` has two matchers: the AlphaFS enumeration, whose
  dot rules also differ from those of `Get-ChildItem` (probe: `Report.*` and
  `Rep*.` in both editions), and a PowerShell wildcard on the name, where only
  `*` and `?` are special. `*.*` is treated as `*`; the other dot patterns are
  pinned by `ItemCmdlets.Tests` and are an open maintainer decision.

### Tests and documentation

- Tests import Release in isolated processes, both editions and privilege
  modes. File/ACL/link fixtures use shared sandbox guards and cleanup.
  Privilege-dependent skips must have eligible counterparts in the matrix.
- Assert persisted state, errors/targets, continuation, and no failed
  PassThru output. Prove new characterization guards with bounded mutations;
  restore source exactly and rebuild before green validation or packaging.
  Apply the mutations of one round together only when no guard can fail
  because of another mutation; otherwise split the rounds.
- A test that arranges a retry asserts its precondition (the plain write is
  denied), or it can pass without reaching the retry.
- A test variable must not take the name of an automatic variable such as
  `$foreach`: Pester runs the block inside a foreach, and the value is lost.
- The CI scripts set `$ErrorActionPreference = 'Stop'`; focused runs do the
  same, and a test that needs a non-terminating error (for example to take it
  through `2>&1`) names `-ErrorAction Continue`.
- Fixture DACLs use .NET SetAccessControl, not Set-Acl's unintended SACL writes.
- Scope/descendant expectations are independent of the production converter.
- Drive-root tests map a sandbox folder with `subst` through
  `New-TestDriveMapping` (elevated only; the basic token cannot). Tests that
  need a letter without a volume take the lowest free one.
- Desktop platyPS: generate help, rebuild, round-trip unchanged, check links.
  platyPS 0.14.2 turns a pair of asterisks in a paragraph into emphasis, also
  inside backticks, and the help drops them: write the words, put patterns in
  example code blocks, and check the generated XML.
- Live tests use only approved lab targets, SMB then independent server state;
  Get/SetFileSecurity preserves stored DACLs; rights oracles use S4U tokens.

### CI results and publication

- Use Path.Combine then GetFullPath for a rooted-or-repository-relative
  result path; Join-Path appends even a rooted child and corrupts it.
- Discovery handles only expected PackageNotFound as absence; repository,
  authentication, and network errors remain failures.
- Rerun/uncertain-upload success requires Gallery SHA-512 equality with the
  exact build artifact. Base64 is case-sensitive: use ordinal comparison.
  Missing/different/unverifiable metadata preserves the upload error.
- Secrets stay by environment reference, never in process arguments/logs.
  Test all external publication commands with mocks; no test may upload.
- AltCover aggregates all four sequential runs without --save. Report
  sequence points, not unique source lines; keep unmatched paths visible.
