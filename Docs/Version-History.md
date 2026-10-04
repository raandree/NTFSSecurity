# Version history

This page lists the changes in NTFSSecurity 4.2.6 and earlier. It replaces
the hand-written version history that the GitHub wiki kept until 2018. For the
changes since 4.2.6, see the [changelog](../CHANGELOG.md).

Dates are the days on which the PowerShell Gallery published a version.
Versions without a date were released only on CodePlex, and their release
dates are lost. The notes for 4.2.2 and later also draw on a comparison of
the packages in the PowerShell Gallery and on the commit history.

## 4.2.6 - 2019-07-12

- Fixed the `Applies to` column in the output of `Get-NTFSAccess`
  ([#57](https://github.com/raandree/NTFSSecurity/pull/57)).

## 4.2.5 - 2019-07-11

- Removed `Show-SimpleAccess`, which used Windows Forms, for compatibility
  with PowerShell Core. It had not been available since 4.2.2.
- Fixed the aliases `IdentityReference` and `ID` of the `-Account`
  parameter, whose definition made importing the module fail, for example
  in Service Management Automation
  ([#18](https://github.com/raandree/NTFSSecurity/issues/18),
  [#36](https://github.com/raandree/NTFSSecurity/issues/36)).
- Fixed the `ToSimpleFileSystemAccessRule2` method of the access entries
  that `Get-NTFSAccess` returns
  ([#48](https://github.com/raandree/NTFSSecurity/issues/48)).
- Known issue: the `Applies to` column in the output of `Get-NTFSAccess`
  shows the inheritance flags instead of the scope, such as
  `ThisFolderSubfoldersAndFiles`. 4.2.6 fixes it.

## 4.2.4 - 2018-08-13

- `Get-ChildItem2` adds a `HardLinkCount` property to each file. The new
  module setting `IdentifyHardLinks` turns it off.
- The objects that `Get-NTFSOwner` returns have the properties `FullName`
  and `Account`, so you can pipe them into `Set-NTFSOwner`
  ([#31](https://github.com/raandree/NTFSSecurity/issues/31)).
- `Copy-Item2 -Force` and `Move-Item2 -Force` replace an existing file
  instead of failing.
- Updated AlphaFS, the library for long paths, to 2.2.1.
- Added the MIT license.
- Fixed `Get-NTFSSimpleAccess -ExcludeInherited`, which returned inherited
  permissions ([#12](https://github.com/raandree/NTFSSecurity/issues/12)).
- Fixed `-PassThru` of `Enable-NTFSAccessInheritance`,
  `Disable-NTFSAccessInheritance`, `Enable-NTFSAuditInheritance`, and
  `Disable-NTFSAuditInheritance`
  ([#33](https://github.com/raandree/NTFSSecurity/issues/33)).
- Fixed `Remove-NTFSAudit`, which didn't work
  ([#35](https://github.com/raandree/NTFSSecurity/issues/35)).

## 4.2.3 - 2016-05-19

- Added the cmdlet `Get-FileHash2`.
- Bug fixes.

## 4.2.2 - 2016-05-18

No notes exist for this version. Compared with 4.0, the previous version in
the PowerShell Gallery, it adds the cmdlets of 4.2 and 4.2.1 and these
changes, which no notes mention:

- Added the cmdlet `Test-Path2`.
- Added the `-PassThur` parameter to `Remove-Item2`, renamed to `-PassThru`
  in 5.0.0.
- `Add-NTFSAudit` takes the audit flags in the new `-AuditFlags` parameter
  instead of `-AccessType`.
- `Remove-NTFSAudit` has the new parameters `-Path` and
  `-SecurityDescriptor`, and its `-Type` parameter is renamed to
  `-AuditFlags`, its former alias.
- `Show-SimpleAccess` is no longer available, because the module manifest
  lists it as `Show-NTFSSimpleAccess`.

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

## 4.0 - 2015-08-19

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
