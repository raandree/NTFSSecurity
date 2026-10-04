---
status: accepted
date: 2026-10-04
last-verified: 2026-10-04
owner: shared
source: maintainer decisions in work package 4
---

# Decision 10: One version for the manifest, assemblies, and changelog

- Choice: `ModuleVersion` in `NTFSSecurity.psd1`, `AssemblyVersion` and
  `AssemblyFileVersion` of `NTFSSecurity`, `Security2`, and
  `PrivilegeControl` (as `x.y.z.0`), and the latest version section of
  `CHANGELOG.md` carry the same version. The vendored `ProcessPrivileges`
  and the unshipped `Log` keep their own versions.
  `Tests\Manifest.Tests.ps1` enforces this.
- Rationale: Before, the manifest said 4.2.5, the release 4.2.6, and the
  assemblies 4.2.1.0, 3.2.3.0, and 1.0.0.0; releases bumped the version
  only in the published copy. One version, set in the repository before
  the release, identifies a build.
- Consequence: A version bump changes all five places in one commit. The
  date of the version section is the release date; update it when you tag.
- Context: 5.0.0 is major because the minimum PowerShell version rose to
  5.1. `Remove-Item2 -PassThur` stays as a deprecated alias of `-PassThru`.
