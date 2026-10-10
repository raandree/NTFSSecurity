---
status: current
last-verified: 2026-10-10
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
| 23 | [Non-Windows file servers before 5.0.0, #34 (proposed)](decisions/0023-non-windows-file-servers.md) |
| 24 | [The operating-system matrix lab (proposed)](decisions/0024-os-matrix-lab.md) |

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
- A catch-all for one item's failures passes on what a later command raises
  through a Write call (`IsFromLaterCommand`, `PipelineControl`; see
  `BaseCmdlets.cs`); add a row to `Tests/PipelineControl.Tests.ps1` for a new
  cmdlet. Record an enabled privilege before the next write.
- `Get-ChildItem2 -Filter` has two matchers (AlphaFS, then a wildcard on the
  name); `*.*` means `*`, other dot patterns are an open decision.

### Tests and documentation

- Tests import Release in isolated processes, both editions and privilege
  modes, with guarded sandboxes; a skip needs an eligible counterpart.
- Assert persisted state, errors/targets, continuation, and no failed
  PassThru output. Prove new characterization guards with bounded mutations
  (one round together only if no guard can fail because of another); restore
  source exactly and rebuild before green validation or packaging. A retry
  test asserts its precondition (the plain write is denied).
- CI scripts and focused runs set `Stop`: a test that needs a non-terminating
  error names `-ErrorAction Continue`. Don't name a test variable like an
  automatic variable (`$foreach`): Pester runs the block inside a foreach.
- Fixture DACLs use .NET SetAccessControl, not Set-Acl's unintended SACL writes.
- Scope/descendant expectations are independent of the production converter.
- Desktop platyPS: generate help, rebuild, round-trip unchanged, check links;
  platyPS 0.14.2 turns paired asterisks into emphasis, even in backticks.
- Live tests use only approved lab targets, SMB then independent server state;
  Get/SetFileSecurity preserves stored DACLs; rights oracles use S4U tokens.
- A suite that is green on the host and CI misses defects that need a domain
  member or another token (the matrix found three): also run a domain member,
  other builds, and a basic user. A failure that follows cell order, not
  version, points to stale account state (Decision 24): alternate the cells.

### CI, publication, and integration

- Discovery treats only PackageNotFound as absence. Rerun/uncertain-upload
  success needs Gallery SHA-512 equality with the exact build artifact
  (ordinal Base64); anything else preserves the upload error. Secrets stay
  environment references; mock all publication commands, no test uploads.
- Gate prompts are self-contained: pins are historical, state is rechecked,
  completion is evidence, risk acceptance is no test pass. In a stack of pull
  requests, retarget each to `master` before merging the one below; delete a
  head branch only when no open pull request uses it as its base (Decision 15).
