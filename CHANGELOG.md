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
- Link the release notes in the PowerShell Gallery to this changelog

### Changed

- **Breaking:** require Windows PowerShell 5.1 or PowerShell 7, and declare
  support for both editions in the module manifest
  ([#61](https://github.com/raandree/NTFSSecurity/issues/61)); the manifest
  declared PowerShell 2.0 and .NET Framework 3.5, although the module needs
  .NET Framework 4.5.2
- Rename the `-PassThur` parameter of `Remove-Item2` to `-PassThru`;
  `-PassThur` still works as an alias
  ([#64](https://github.com/raandree/NTFSSecurity/pull/64))
- Publish the module as a Release build that contains only the module
  files; 4.2.6 was a Debug build with debug symbols and a copy of
  `System.Management.Automation.dll`
- Document every cmdlet with synopsis, description, parameters, examples,
  inputs, outputs, and notes, checked against the source code
- Rewrite the home, concepts, examples, and contributor pages to match the
  current cmdlets, including module settings, privileges, and long paths
- Move the version history and the installation instructions from the wiki
  into the documentation, and complete the version history with the release
  dates from the PowerShell Gallery, the missing notes for 4.2.2, 4.2.5, and
  4.2.6, and detailed notes for 4.2.4
- Rename `-RemoveInheritedAccessRules` of `Disable-NTFSAuditInheritance` to
  `-RemoveInheritedAuditRules` and `-RemoveExplicitAccessRules` of
  `Enable-NTFSAuditInheritance` to `-RemoveExplicitAuditRules`, because they
  act on audit entries; the old names still work as aliases
- **Breaking:** `Set-NTFSInheritance` keeps entries like the dedicated
  cmdlets: `-AccessInheritanceEnabled $false` now copies the inherited access
  entries into the DACL instead of removing them, and
  `-AuditInheritanceEnabled $true` now keeps the explicit audit entries. A
  script that used `-AccessInheritanceEnabled $false` to drop the inherited
  access entries now leaves them in place, which grants broader access than
  before. To remove the entries, use
  `Disable-NTFSAccessInheritance -RemoveInheritedAccessRules` or
  `Enable-NTFSAuditInheritance -RemoveExplicitAuditRules`

### Deprecated

- Deprecate the `-PassThur` alias of `Remove-Item2`; use `-PassThru`
- Deprecate the `MACTripleDES` value of `Get-FileHash2 -Algorithm`: it uses
  a random key, so its result differs on every call; the cmdlet now warns
  when you use it

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
- Fix `Set-NTFSInheritance`, which failed with "Nullable object must have a
  value" when `-AccessInheritanceEnabled` or `-AuditInheritanceEnabled` was
  omitted; an omitted parameter now leaves its section unchanged
- Fix `Get-ChildItem2`, which stopped with an `InvalidCastException` when
  `-Path` pointed to a file; it now returns the file, like `Get-ChildItem`
- Fix `Get-FileHash2`, which stopped at a folder in `-Path` and didn't hash
  the files that followed it; folders are now skipped
- Fix `Get-NTFSAudit`, which returned nothing without the Security privilege
  instead of an error, and which returned the entries of the previous item
  again after a path whose security descriptor it couldn't read; it also no
  longer takes ownership of an item whose audit entries it can't read, which
  didn't help and could leave the owner changed
- Fix `Get-NTFSAccess`, which returned the entries of the previous item again
  after a path whose ACL it couldn't read
- Fix `Add-NTFSAudit`, whose `-Account` and `-AccessRights` parameters were
  both at position 2, so that positional calls failed; `-AccessRights` is
  now at position 3, like in `Remove-NTFSAudit`
  ([#4](https://github.com/raandree/NTFSSecurity/issues/4))
- Fix `-PassThru` of `Add-NTFSAudit` with `-SecurityDescriptor` and of
  `Remove-NTFSAudit` with `-Path`, which returned access entries; both now
  return the audit entries
- Fix the `InheritanceEnabled` property of audit entries, which reported the
  inheritance of the access entries; it now reports whether the audit
  entries are inherited
- Fix `Get-NTFSInheritance -SecurityDescriptor`, which reported
  `AuditInheritanceEnabled` as `$true` for a security descriptor that was
  read without its audit section; it now reports `$null`, like `-Path`
- Fix `Get-NTFSOwner`, which wrote a "The pipeline has been stopped" error
  for every path when a command such as `Select-Object -First 1` stopped the
  pipeline, and which repeated a failed read instead of reporting the
  denied access
- Fix `Copy-Item2`, which failed with a `DirectoryNotFoundException` when it
  copied a folder that contained files
- Fix `Disable-Privileges`, which couldn't disable the privileges when the
  module setting `EnablePrivileges` was `$false`
- Fix the inheritance cmdlets, which enabled the Backup, Restore, Take
  Ownership, and Security privileges even when the module setting
  `EnablePrivileges` was `$false`, and left them enabled
- Fix the `Inherits` column of the `Get-ChildItem2` output, which showed
  `True` for every item, also for items whose inheritance is disabled
- Fix `Add-NTFSAccess`, `Remove-NTFSAccess`, `Add-NTFSAudit`, and
  `Remove-NTFSAudit`, which failed with "Parameter set cannot be resolved"
  for `-SecurityDescriptor` without `-AppliesTo`, `-InheritanceFlags`, or
  `-PropagationFlags`; `-AppliesTo` is now mandatory in the `Simple`
  parameter sets, so such a command uses the flag parameters and their
  defaults, as for a path
- Fix `Get-NTFSEffectiveAccess`: `-ExcludeNoneAccessEntries` now leaves out
  items without access, the cmdlet uses the current location when `-Path`
  is omitted, and `-SecurityDescriptor` returns the effective access of the
  security descriptor; before, all three returned nothing or ignored the
  parameter
- Fix `Get-NTFSOrphanedAccess`, `Get-NTFSOrphanedAudit`, and
  `Get-NTFSSimpleAccess`, which ignored `-Account` and `-SecurityDescriptor`;
  `Get-NTFSOrphanedAudit` now writes one object per entry instead of one
  collection per item, `Get-NTFSOrphanedAccess` no longer repeats the entries
  of the previous item after a failed read, and the output of
  `Get-NTFSSimpleAccess` has a table view
- Restore the `-RemoveSpecific` switch of `Remove-NTFSAccess`, which version
  4.1 introduced but later versions lacked, and add it to `Remove-NTFSAudit`:
  with it, the cmdlets remove only an entry that matches exactly
- Fix `Copy-Item2`, `Move-Item2`, and `Remove-Item2`, which skipped the
  remaining paths of `-Path` after a path that didn't exist or, for copy and
  move, a file that already existed at the destination
- Fix `Remove-NTFSAccess` and `Remove-NTFSAudit`, which went on with a path
  that didn't exist, wrote a second, misleading `RemoveAceError`, and with
  `-PassThru` stopped with a `NullReferenceException`
- Fix `-PassThru` of `Enable-NTFSAccessInheritance`,
  `Disable-NTFSAccessInheritance`, `Enable-NTFSAuditInheritance`,
  `Disable-NTFSAuditInheritance`, and `Set-NTFSInheritance`, which returned
  the unchanged state of an item also when the change failed, so that the
  inheritance looked disabled
  ([#74](https://github.com/raandree/NTFSSecurity/issues/74))
- Fix the error of `New-NTFSHardLink` for a missing `-Target`, which said
  that the target path existed
- Fix `Get-FileHash2`, which wrote a result for a file that it couldn't
  read, with the hash of the previous file
- Fix `-PassThru` of `Add-NTFSAccess`, `Add-NTFSAudit`, `Remove-NTFSAccess`,
  and `Remove-NTFSAudit`, which returned the unchanged entries of an item
  also when the change failed
- Fix the cmdlets that take ownership of an item to repeat an operation that
  was denied: when the second attempt failed as well, the account that ran
  the cmdlet stayed the owner of the item; now the previous owner is restored
- Fix `-PassThru` of `Enable-Privileges` and `Disable-Privileges`, which
  wrote the privileges as one collection instead of one object per
  privilege, and of `New-NTFSSymbolicLink`, which returned a file object for
  a link to a folder
- Declare the output types of `Test-Path2`, `Get-FileHash2`,
  `Add-NTFSAudit`, `Remove-NTFSAudit`, `Copy-Item2`, `Move-Item2`,
  `Remove-Item2`, and the inheritance cmdlets correctly, so that
  `Get-Command` and tab completion report the objects they write
- Fix the verbose messages of `Copy-Item2` and `Move-Item2`, which named the
  source path as the destination, and of `Disable-Privileges`, which said
  that the privileges were enabled, and the spelling of the privilege in
  the warning of `Get-NTFSEffectiveAccess`
- Fix `-PassThru` of `Copy-Item2`, `Move-Item2`, and `Remove-Item2`, which
  wrote the item also when `-WhatIf` or a declined confirmation skipped the
  operation
- Fix `Get-FileHash2` in PowerShell 7, where it failed for every algorithm;
  `RIPEMD160` and `MACTripleDES`, which .NET lacks there, now stop the
  cmdlet with an error that names the algorithm and points to Windows
  PowerShell 5.1
- Fix a `FormatException` in the cmdlets for a path with braces, such as
  `C:\Data\{Archive}`: their messages formatted the path a second time
  ([#3](https://github.com/raandree/NTFSSecurity/issues/3))
- Fix a `NullReferenceException` in every cmdlet when a variable named
  `PWD` in the scope of the caller, such as a loop variable, hid the
  automatic variable; the cmdlets now read the current location from the
  session, and only for a relative path
  ([#86](https://github.com/raandree/NTFSSecurity/issues/86))
- Fix file and folder objects passed by position, such as
  `Get-NTFSOwner $folder`, which Windows PowerShell bound as the name of the
  item, so the cmdlets looked for it in the current location
  ([#88](https://github.com/raandree/NTFSSecurity/issues/88))
- Fix `Remove-NTFSAccess` for an entry with a generic right such as
  `GenericAll`, which Windows keeps in the inherit-only entries of folders;
  it failed with "The value '269484032' is not valid"
  ([#17](https://github.com/raandree/NTFSSecurity/issues/17))

[Unreleased]: https://github.com/raandree/NTFSSecurity/compare/4.2.6...HEAD
