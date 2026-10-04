---
status: current
last-verified: 2026-10-04
owner: active-agent
source: repository evidence
---

# Progress

## Current status

PRs #91 to #98 are merged. CI published the prerelease 5.0.0-rc1 from
`master` (`e0f5366`, tag `5.0.0-rc1`) to the PowerShell Gallery and GitHub;
the stable Gallery version is still 4.2.6. CI runs on GitHub Actions:
build, docs checks, tests in Windows PowerShell 5.1 and PowerShell 7,
packages, the wiki generated from `Docs` (43 pages), and releases on a
version tag (Decision 12). Next: the maintainer tests 5.0.0-rc1.

## Recent milestones

- 2026-10-02 to 2026-10-04: #91 aligned the docs with the code (Decision
  6; #83 closed as superseded), #92 did housekeeping (Decision 7), and
  #93 shipped the generated help file (Decision 8, `Tests\Help.Tests.ps1`).
- 2026-10-04: #94 to #96 dropped Read the Docs (Decision 9), set version
  5.0.0 with a valid manifest (Decision 10), and moved CI and a wiki
  generated from `Docs` to GitHub Actions (Decision 11). #97 completed the
  version history, kept separate from `CHANGELOG.md`, from the six Gallery
  packages and the commit history.
- 2026-10-04: #98 (`e0f5366`) added releases on a version tag through CI
  (Decision 12), with a prerelease first; `New-ModulePackage.ps1` adds the
  command tags that PSResourceGet drops. The tag `5.0.0-rc1` (run
  37230802387) published to the Gallery at 20:12 UTC and created the
  GitHub prerelease. Verified: the Gallery nupkg and the GitHub zip are
  byte-identical to the CI artifacts, the DLLs are optimized Release
  builds, the Gallery shows the prerelease flag, the release notes link,
  and all 36 `PSCmdlet_` and `PSCommand_` tags, and the installed module
  passes the full suite (Windows PowerShell 261 passed, 7 skipped;
  PowerShell 7 232 passed, 36 skipped).

## Stable capabilities

- 36 cmdlets: access (7), audit (5), inheritance (6), owner and security
  descriptor (4), privileges (3), long-path items (6), links, hash, and
  disk space (5).
- Works in Windows PowerShell 5.1 and PowerShell 7 (smoke-tested), except
  `Get-FileHash2`, which fails in PowerShell 7 (missing `RIPEMD160` type).

## Open work

Work packages in the order agreed with the maintainer. Each gets one
`ai/<slug>` branch and PR, committed locally. The maintainer pushes and
opens the PR (the agent can't; see `techContext.md`, Constraints), and the
next package starts only after the maintainer's go-ahead.

Items 1 to 4c are done: housekeeping (#92), shipped help (#93), docs on
GitHub (#94), manifest and version 5.0.0 (#95), CI and the wiki on GitHub
Actions (#96), version history from the Gallery (#97). Optional for the
maintainer: delete the AppVeyor project and revoke its GitHub
authorization, restrict wiki editing to collaborators, and ask
`Sup3rlativ3` to delete the Read the Docs project.

4d. Release 5.0.0 through CI (Decision 12): 5.0.0-rc1 published and
   verified (#98); the maintainer tests it. The final release PR comes on
   release day (CI warns when the changelog date isn't that day): remove
   the label, date `[Unreleased]` as `[5.0.0]`, tag `5.0.0` (steps in
   `Docs/Contributing/05-Releasing.md`). Also consider the manifest
   `Description` ("Windows PowerShell Module") and the `5.0.0-rc1` example
   in `Docs/README.md`. Releases no longer come from a local Debug build.
4e. Repository settings, proposed to the maintainer on 2026-10-04 (not yet
   agreed): the `powershell-gallery` environment has no protection rules
   and no deployment policy, so a workflow on any branch can use
   `PSGALLERY_API_KEY` (`nyanhp` also has write access); `master` has no
   protection or ruleset; head branches aren't deleted on merge; the
   remote branches `fix/#34` and `test/transfer` (2023-11-28, two commits
   each) aren't merged. Dependabot for the SHA-pinned actions comes with
   `ai/maintenance` (maintainer decision D7, 2026-10-04).
5. Code defects, listed below: `review: on`, one PR per group, regression
   test first. Pester 5 tests import `NTFSSecurity\bin\Release`, run in a
   `$env:TEMP` sandbox and in the CI workflow (pattern:
   `Tests\Help.Tests.ps1`), and skip elevated cases when not elevated.
   GitHub-hosted Windows runners run as administrators with UAC disabled
   (GitHub docs, checked 2026-10-04), so elevated cases run in CI; the
   workstation session isn't elevated. Each fix updates its cmdlet page
   and `CHANGELOG.md`. Start by triaging the 37 open issues (none newer
   than May 2025): #15, #47, and #66 (documentation) and #19 (fixed in
   4.2.4) can be closed; #4 is defect (5); #34 has the WIP branch
   `fix/#34` (`Extensions.cs`, `FileSystemSecurity2.cs`, `TestClient`);
   `test/transfer` only adds a 3 MB `New.zip`. The E decisions set the
   next version: fixes only 5.0.1, additions 5.1.0, changed defaults
   6.0.0, unless they ship in 5.0.0 (rc2).

### Code defects (work package 5)

Numbered as agreed with the maintainer; each is documented on its page.

#### A: Crashes and wrong results (fixed on `ai/defects-a`, not merged)

- (1) `Set-NTFSInheritance` reads an unset `Nullable<bool>` when
  `-AccessInheritanceEnabled` is omitted; omitted should mean unchanged.
- (2) `Get-ChildItem2` casts a file `-Path` to `DirectoryInfo`
  (`InvalidCastException`).
- (3) `Get-FileHash2` returns at a folder in `-Path` and skips the rest.
- (4) `Get-NTFSAudit` re-emits the previous item's entries after a failed
  path, and returns nothing without the Security privilege instead of an
  error.
- (5) `Add-NTFSAudit`: `-Account` and `-AccessRights` share position 2;
  use 2 and 3 like `Remove-NTFSAudit`.
- (6) `-PassThru` returns access entries in `Add-NTFSAudit` SD sets and
  `Remove-NTFSAudit` Path sets.
- (7) `FileSystemAuditRule2.GetFileSystemAuditRules` takes
  `InheritanceEnabled` from `AreAccessRulesProtected`.
- (8) `Get-NTFSInheritance -SecurityDescriptor` reports
  `AuditInheritanceEnabled = $true` without a SACL (Path set: `$null`).
- (9) `Get-NTFSOwner`: the access-denied retry repeats the failing call,
  and the catch-all turns `PipelineStoppedException` into
  `ReadSecurityError`.
- (10) `Copy-Item2` fails on a folder with files
  (`DirectoryNotFoundException`).
- (11) `Disable-Privileges` hits a null `privileges` field when
  `EnablePrivileges = $false`.
- (12) The six inheritance cmdlets enable privileges unconditionally in
  `BeginProcessing` and leave them enabled.
- (13) Format view `Children2`: the `Inherits` column uses
  `IsInheritanceBlocked`, so it always shows `True` for `Get-ChildItem2`.
- Review of group A: five Major findings fixed in the last commit; the
  Minor ones are listed in the PR description.

#### B: Ignored parameters and parameter sets (fixed on `ai/defects-b`, not merged)

- (14) SD sets of `Add-/Remove-NTFSAccess` and `Add-/Remove-NTFSAudit`
  cannot resolve without `-AppliesTo` or the flag parameters.
- (15) `Get-NTFSEffectiveAccess`: `-ExcludeNoneAccessEntries` has no
  effect, there is no output without `-Path`, and the SD set returns
  nothing.
- (16) `Get-NTFSOrphanedAccess`, `Get-NTFSOrphanedAudit`, and
  `Get-NTFSSimpleAccess` ignore `-Account` and `-SecurityDescriptor`;
  `Get-NTFSOrphanedAudit` writes collections; `SimpleFileSystemAccessRule`
  has no format view.
- (17) `removeSpecific` in `Remove-NTFSAccess/Audit` is never bound;
  `Remove-NTFSAudit` leaves `appliesTo` uninitialized.
- Review of group B: no Blocker or Major; three Minor findings fixed, the
  rest are listed in the PR description.

#### C: Error handling (fixed on `ai/defects-c`, not merged)

- (18) `Copy-Item2`, `Move-Item2`, `Remove-Item2`: one failing path skips
  the rest of `-Path` (`return` instead of `continue`).
- (19) `Remove-NTFSAccess` continues after a failed read and writes a
  second, misleading `RemoveAceError`.
- (20) The inheritance cmdlets write `-PassThru` output in `finally`, even
  after a failure.
- (21) `New-NTFSHardLink` says the target path exists when it doesn't.

#### D: Metadata and cosmetics

- (22) Wrong or missing `[OutputType]` (`Test-Path2`, `Get-FileHash2`,
  `Add-NTFSAudit`, `*-Item2`, inheritance cmdlets);
  `Enable-/Disable-Privileges -PassThru` writes one collection;
  `New-NTFSSymbolicLink -PassThru` returns `FileInfo` for folder links.
- (23) Typos: "Privliege" in the `Get-NTFSEffectiveAccess` warning; "are
  now enabled" in the `Disable-Privileges` verbose message.
- (24) Dead code in `RemoveItem2.cs` and `OtherCmdlets.cs`.

#### E: Maintainer decisions before changing behavior

- `Clear-NTFSAccess -DisableInheritance` removes the explicit entries and
  then disables inheritance without copying the inherited ones, which
  leaves an empty DACL: keep that, or copy them?
- `Set-NTFSInheritance` differs from the dedicated cmdlets in two of four
  directions: `-AccessInheritanceEnabled $false` removes the inherited
  access entries, and `-AuditInheritanceEnabled $true` removes the
  explicit audit entries; the dedicated cmdlets keep them unless a switch
  is given. Align?
- The audit inheritance switches are named `*AccessRules`: add
  `*AuditRules` aliases?
- `Get-FileHash2` fails in PowerShell 7 (`RIPEMD160`): drop the algorithm
  there, load it lazily, or deprecate the cmdlet? To verify:
  `MACTripleDES.Create()` may use a random key, so its result would differ
  on every call.
