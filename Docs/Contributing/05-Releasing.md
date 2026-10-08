# Release a new version

This page explains how a maintainer releases a new version of NTFSSecurity.
The CI workflow does the work: when you push a version tag, it builds and
tests the module, publishes the package to the PowerShell Gallery, and creates
the GitHub release with `NTFSSecurity.zip`.

## Prepare the repository once

1. In the PowerShell Gallery, [create an API key][api-key] for the account
   that owns NTFSSecurity. Select the scope **Push new versions of existing
   packages**, enter `NTFSSecurity` as the glob pattern, and choose an
   expiration.
2. In the settings of the repository on GitHub, under **Environments**,
   create the environment `powershell-gallery`. To approve every release
   before it's published, add yourself as a required reviewer. Under
   **Deployment branches and tags**, allow only tags such as
   `[0-9]*.[0-9]*.[0-9]*`.
3. Add the API key as the secret `PSGALLERY_API_KEY` of the environment.
   The command asks for the key:

   ```powershell
   gh secret set PSGALLERY_API_KEY --env powershell-gallery --repo raandree/NTFSSecurity
   ```

Renew the API key before it expires, and update the secret.

## Versions

- `ModuleVersion` in `NTFSSecurity\NTFSSecurity.psd1` and the
  `AssemblyVersion` and `AssemblyFileVersion` of the `NTFSSecurity`,
  `Security2`, and `PrivilegeControl` projects carry the same version. The
  tests in `Tests\Manifest.Tests.ps1` check this.
- A prerelease, such as `5.0.0-rc1`, has its label in `Prerelease` under
  `PrivateData.PSData` of the module manifest. Its release notes are the
  `[Unreleased]` section of `CHANGELOG.md`. The PowerShell Gallery installs a
  prerelease only when you add `-AllowPrerelease`.
- A release, such as `5.0.0`, has no `Prerelease` value. Its release notes
  are the section `## [5.0.0] - <date>` of `CHANGELOG.md`.

The tests in `Tests\Release.Tests.ps1` check that `CHANGELOG.md` has the
release notes for the version of the module manifest and test the release
scripts. The tests in `Tests\Repository.Tests.ps1` check the release metadata:
the description that the PowerShell Gallery shows, that the version isn't one
that the Gallery already has, and that `Docs/README.md` names no prerelease
version. Name a prerelease only in `CHANGELOG.md`, because the documentation
home outlives it.

## Publish a prerelease

1. Set the version and the `Prerelease` label, such as `rc1`, and make sure
   that the `[Unreleased]` section of `CHANGELOG.md` describes the changes.
   Add the version that the Gallery has now to `$publishedVersions` in
   `Tests/Repository.Tests.ps1`, so that a test catches a version that is
   reused. Merge the change into `master`.
2. Tag the commit on `master` with the version and push the tag:

   ```powershell
   git switch master
   git pull
   git tag 5.0.0-rc1
   git push origin 5.0.0-rc1
   ```

3. Watch the CI run of the tag. The **Release** job checks that the tag
   matches the version in the module manifest and points to a commit on
   `master`. Then it publishes the package and creates a GitHub prerelease.
   If the environment requires a reviewer, approve the deployment.
4. Install the prerelease in a test environment and test it:

   ```powershell
   Install-Module -Name NTFSSecurity -AllowPrerelease -Scope CurrentUser
   ```

For another prerelease, increase the label, such as `rc2`. The PowerShell
Gallery compares labels as text, so `rc10` sorts before `rc2`.

## Publish a release

Before you publish a release, run the live tests in a lab against the last
prerelease from the PowerShell Gallery, as the
[acceptance of a release candidate](../../Tests/Lab/README.md#acceptance-of-a-release-candidate)
describes, with `-Version` instead of `-ModulePath`.

1. Remove the `Prerelease` value from the module manifest.
2. In `CHANGELOG.md`, rename `## [Unreleased]` to the version with the
   release date, such as `## [5.0.0] - 2026-10-31`, add an empty
   `## [Unreleased]` section above it, and update the links at the end of the
   file:

   ```markdown
   [Unreleased]: https://github.com/raandree/NTFSSecurity/compare/5.0.0...HEAD
   [5.0.0]: https://github.com/raandree/NTFSSecurity/compare/4.2.6...5.0.0
   ```

3. Merge the change into `master`. Then tag the commit with the version, such
   as `5.0.0`, and push the tag, as for a prerelease. The **Release** job
   warns if the date in `CHANGELOG.md` isn't the day of the release.

## If a release fails

The **Release** job skips what's already done: a version that the PowerShell
Gallery already has, and a GitHub release that already exists. If the
failure doesn't need a change in the repository, fix the cause and rerun the
failed job.

If the fix needs a change in the repository and the PowerShell Gallery
doesn't have the version yet, delete the tag, merge the fix, and tag the new
commit:

```powershell
git push origin --delete 5.0.0-rc1
git tag --delete 5.0.0-rc1
```

The PowerShell Gallery never accepts the same version twice. To replace a
published version, publish the next one, such as `5.0.0-rc2`, and
[unlist][unlist] the faulty version.

<!-- External URLs -->
[api-key]: https://learn.microsoft.com/powershell/gallery/how-to/managing-profile/creating-apikeys
[unlist]: https://learn.microsoft.com/powershell/gallery/how-to/publishing-packages/unlisting-packages
