---
status: accepted
date: 2026-10-04
last-verified: 2026-10-04
owner: shared
source: maintainer decisions in work package 4
---

# Decision 10: One version for the manifest, assemblies, and changelog

- Choice: `ModuleVersion` in `NTFSSecurity.psd1` and `AssemblyVersion` and
  `AssemblyFileVersion` of `NTFSSecurity`, `Security2`, and
  `PrivilegeControl` (as `x.y.z.0`) carry the same version
  (`Tests\Manifest.Tests.ps1`). The vendored `ProcessPrivileges` and the
  unshipped `Log` keep their own versions. `CHANGELOG.md` describes that
  version (`Tests\Release.Tests.ps1` through `Get-ReleaseInfo.ps1`): a
  release has a dated section `## [x.y.z] - yyyy-MM-dd`; a prerelease has
  its label in `PrivateData.PSData.Prerelease` and its notes under
  `## [Unreleased]`, with no section for `x.y.z` yet (changelog Option A,
  amended 2026-10-04 for the 5.0.0 prerelease).
- Rationale: Before, the manifest said 4.2.5, the release 4.2.6, and the
  assemblies 4.2.1.0, 3.2.3.0, and 1.0.0.0; releases bumped the version
  only in the published copy. One version, set in the repository before
  the release, identifies a build.
- Consequence: A version bump changes the manifest and three assemblies in
  one commit. The final release renames `[Unreleased]` to the dated version
  section and removes the prerelease label.
- Context: 5.0.0 is major because the minimum PowerShell version rose to
  5.1. `Remove-Item2 -PassThur` stays as a deprecated alias of `-PassThru`.
