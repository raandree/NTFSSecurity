# Changelog

All notable changes to this project are documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases up to
4.2.6 are described in the
[version history](https://github.com/raandree/NTFSSecurity/wiki/Version-History)
in the wiki.

## [Unreleased]

### Changed

- **Breaking:** rename the `-PassThur` parameter of `Remove-Item2` to
  `-PassThru` ([#64](https://github.com/raandree/NTFSSecurity/pull/64))
- Declare support for Windows PowerShell and PowerShell 7 in the module
  manifest ([#61](https://github.com/raandree/NTFSSecurity/issues/61))
- Document every cmdlet with synopsis, description, parameters, examples,
  inputs, outputs, and notes, checked against the source code
- Rewrite the home, concepts, examples, and contributor pages to match the
  current cmdlets, including module settings, privileges, and long paths

### Fixed

- Fix `Get-Help`, which showed only the syntax: ship the help file
  `en-US\NTFSSecurity.dll-Help.xml` generated from the cmdlet documentation,
  including the links that `Get-Help -Online` opens, instead of the outdated
  `NTFSSecurity-Help.xml`
- Fix documentation examples that did not work, such as restoring
  permissions from a CSV file and filtering entries by account
- Fix the documentation site navigation, the "Edit on GitHub" links, and the
  Read the Docs build configuration

[Unreleased]: https://github.com/raandree/NTFSSecurity/compare/4.2.6...HEAD
