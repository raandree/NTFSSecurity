# Changelog

All notable changes to this project are documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases up to
4.2.6 are described in the [version history](Docs/Version-History.md).

## [Unreleased]

### Added

- Publish the documentation in the
  [wiki](https://github.com/raandree/NTFSSecurity/wiki), generated from the
  `Docs` folder after every change, with a sidebar that lists all cmdlets

### Changed

- Complete the version history with the release dates from the PowerShell
  Gallery, notes for 4.2.2, detailed notes for 4.2.4, and separate notes for
  4.2.5 and 4.2.6

## [5.0.0] - 2026-10-04

### Changed

- **Breaking:** require Windows PowerShell 5.1 or PowerShell 7, and declare
  support for both editions in the module manifest
  ([#61](https://github.com/raandree/NTFSSecurity/issues/61)); the manifest
  declared PowerShell 2.0 and .NET Framework 3.5, although the module needs
  .NET Framework 4.5.2
- Rename the `-PassThur` parameter of `Remove-Item2` to `-PassThru`;
  `-PassThur` still works as an alias
  ([#64](https://github.com/raandree/NTFSSecurity/pull/64))
- Document every cmdlet with synopsis, description, parameters, examples,
  inputs, outputs, and notes, checked against the source code
- Rewrite the home, concepts, examples, and contributor pages to match the
  current cmdlets, including module settings, privileges, and long paths
- Move the version history and the installation instructions from the wiki
  into the documentation, and add the missing notes for 4.2.5 and 4.2.6

### Deprecated

- Deprecate the `-PassThur` alias of `Remove-Item2`; use `-PassThru`

### Fixed

- Fix `Get-Help`, which showed only the syntax: ship the help file
  `en-US\NTFSSecurity.dll-Help.xml` generated from the cmdlet documentation,
  including the links that `Get-Help -Online` opens, instead of the outdated
  `NTFSSecurity-Help.xml`
- Fix documentation examples that did not work, such as restoring
  permissions from a CSV file and filtering entries by account
- Remove `Show-NTFSSimpleAccess`, which no longer exists, and duplicate
  entries from the cmdlets that the module manifest exports and the
  PowerShell Gallery lists

[Unreleased]: https://github.com/raandree/NTFSSecurity/compare/5.0.0...HEAD
[5.0.0]: https://github.com/raandree/NTFSSecurity/compare/4.2.6...5.0.0
