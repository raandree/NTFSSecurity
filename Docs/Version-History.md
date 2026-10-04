# Version history

This page lists the changes in NTFSSecurity 4.2.6 and earlier. It replaces
the hand-written version history that the GitHub wiki kept until 2018. For the
changes since 4.2.6, see the [changelog](../CHANGELOG.md).

## 4.2.5 and 4.2.6

The PowerShell Gallery published 4.2.5 on 2019-07-11 and 4.2.6 on
2019-07-12. The wiki listed no changes for these versions, so this list is
reconstructed from the commit history.

- Removed `Show-NTFSSimpleAccess`, which used Windows Forms, for
  compatibility with PowerShell Core.
- Fixed parameter alias definitions that made importing the module fail,
  for example in Service Management Automation
  ([#18](https://github.com/raandree/NTFSSecurity/issues/18),
  [#36](https://github.com/raandree/NTFSSecurity/issues/36)).
- Fixed the `ToSimpleFileSystemAccessRule2` method of the access entries
  that `Get-NTFSAccess` returns
  ([#48](https://github.com/raandree/NTFSSecurity/issues/48)).
- Fixed the `ApplyTo` column in the output of `Get-NTFSAccess`.
- Added the MIT license.

## 4.2.4

- Bug fixes.

## 4.2.3

- Added the cmdlet `Get-FileHash2`.
- Bug fixes.

## 4.2.1

- Added the cmdlets `Get-NTFSHardLink`, `New-NTFSHardLink`, and
  `New-NTFSSymbolicLink`.

## 4.2

- Added the cmdlets `Move-Item2` and `Copy-Item2`.
- `Remove-Item2`, `Move-Item2`, and `Copy-Item2` now support `-WhatIf` and
  `-Confirm`.

## 4.1

- The `-Attributes` parameter of `Get-ChildItem2` works like the one of the
  standard cmdlet `Get-ChildItem`, as requested.
- `Remove-NTFSAccess` can now remove access from existing access control
  entries. The old behavior is still available with the `-RemoveSpecific`
  switch parameter.

## 4.0

- The `*-NTFSAccess` cmdlets can now work on security descriptors to allow
  bulk processes.
- Code cleanup for better performance and maintainability.
- Bug fixes.

## 3.2.3

- Fixed a bug in `GetInheritedFrom` that resulted in "Invalid Path" or "Path
  not found" errors.

## 3.2

- Bug fixes for managing auditing.
- Fixed various bugs reported on CodePlex.

## 3.1

- All cmdlets have the prefix `NTFS` now. There are aliases for backward
  compatibility.
- The new version of `Get-NTFSEffectivePermission` uses `AuthzAccessCheck`
  instead of `GetEffectiveRightsFromAcl`.
- The previous `Get-NTFSEffectivePermission` cmdlet has been renamed to
  `Get-NTFSEffectivePermissionOld`.
- Added `FileSystemAuditRule2` to the PowerShell formatters.
- Added the `InheritedFrom` information to `FileSystemAuditRule2`.

## 3.0

- This version uses [AlphaFS](https://github.com/alphaleonis/AlphaFS) to
  work around the `MAX_PATH` limit of 260 characters.
- New `*-Item2` cmdlets discover items with a long path:
  - `Get-ChildItem2` (`dir2`)
  - `Get-Item2` (`gi2`)
  - `Remove-Item2` (`del2`, `rm2`)
- For inherited access control entries, `InheritedFrom` is displayed.
- Generic access rights are supported.
- Performance improvements.
- Bug fixes.

## 2.4

- `Remove-Access` did not remove deny entries when using the pipeline, for
  example `Import-Csv .\access.txt | Remove-Access`.
- `Add-Access` did not remove deny entries when using the pipeline, for
  example `Import-Csv .\access.txt | Add-Access`.
- The parameter `-Account` was undiscoverable when using the pipeline.

## 2.3

- The module now makes full use of the Backup, Restore, and Take Ownership
  privileges, so as an administrator you can edit permissions on objects
  that you don't have explicit access to. Privileges are enabled by default
  if the value `EnablePrivileges` is `$true` in `NTFSSecurity.psd1`. The new
  cmdlets `Get-Privileges`, `Disable-Privileges`, and `Enable-Privileges`
  are for manual control.
- The `-Path` parameter now works consistently.

## 2.1

- Fixed bugs with `Set-Owner`.
- Added support for managing auditing (SACL).

## 2.0 (beta)

- New commands: `Get-SimpleAccess`, `Get-SimpleEffectiveAccess`,
  `Show-SimpleAccess`, `Show-SimpleEffectiveAccess`, and `Copy-Access`.
- All cmdlets are now written in C#.
- Fixed a number of bugs.

## 1.3

- Fixed an issue with parameter handling.
- Now works with PowerShell 3.0.

## 1.2

- Fixed some issues with path validation.
- Fixed documentation bugs.

## 1.1

- Fixed the issue with square brackets in paths.
- Performance improvements.

## 1.0

- The last tests didn't reveal any issue. PowerShell has a problem handling
  files that have square brackets in the file name, and this module inherits
  the issue.

## 0.9 (beta)

- Fixed some bugs.
- Updated documentation.

## 0.8 (beta)

- Initial release.
