---
status: accepted
date: 2026-10-04
last-verified: 2026-10-04
owner: shared
source: maintainer decisions after #97 (release first, prerelease first)
---

# Decision 12: Releases are built and published by CI on a version tag

- Choice: Pushing a tag such as `5.0.0` or `5.0.0-rc1` on `master` runs the
  `release` job of `.github/workflows/ci.yml`. It publishes the package that
  the `build` job built and tested to the PowerShell Gallery
  (`Publish-PSResource -NupkgPath`) and creates the GitHub release with
  `NTFSSecurity.zip`, marked as a prerelease for a prerelease tag. The job
  checks that the tag equals the manifest version (with the prerelease
  label) and points to a commit on `master`, and it skips a version the
  Gallery or GitHub already has, so a rerun is safe.
- Package: `New-ModulePackage.ps1` copies only the `FileList` files of the
  Release build, so no `.pdb`, XML documentation, or
  `System.Management.Automation.dll` ships. `Compress-PSResource` builds the
  nupkg; the script adds the command tags (`PSIncludes_Cmdlet`,
  `PSCmdlet_<name>`, `PSCommand_<name>`) that PowerShellGet 2 added and
  PSResourceGet 1.2 doesn't, because the Gallery lists cmdlets and
  `Find-Command` searches by them. Every CI run builds the packages, so pull
  requests test them.
- Secret: `PSGALLERY_API_KEY` belongs to the GitHub environment
  `powershell-gallery`, which only the `release` job uses; the maintainer
  creates the key, the environment, and the secret, and may require a
  reviewer.
- Process: a prerelease first (maintainer, 2026-10-04: "no full release
  without proper testing"), starting with `5.0.0-rc1`; the final release
  removes the label and dates the changelog section. Steps for maintainers
  are in `Docs/Contributing/05-Releasing.md`.
- Rationale: Releases so far were local Debug builds published by hand
  with the whole output folder; tags carried the previous version.
- Rejected: publishing with PowerShellGet 2 `Publish-Module` (repackages at
  publish time, so the tested package isn't the published one), and adding
  the command tags to the shipped manifest.
