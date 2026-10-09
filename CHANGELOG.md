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
- Describe the module as a PowerShell module in the manifest, which the
  PowerShell Gallery shows; it said Windows PowerShell, although the module
  supports PowerShell 7 as well
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
- **Breaking:** `Get-ChildItem2 -Attributes` returns the items that have any
  of the listed attributes, like `Get-ChildItem`; it returned only the items
  that had all of them. A call that lists several attributes now returns
  more items, including hidden and system items when those are in the
  list, so review calls whose result is deleted or whose permissions are
  changed. To get the old result, filter with `Where-Object`, as the cmdlet
  page shows. An empty value, such as `0`, is now an error; it returned
  every item, also the hidden ones
  ([#5](https://github.com/raandree/NTFSSecurity/issues/5))
- **Breaking:** remove the alias `Size` of `LengthOnDisk` from the files of
  `Get-ChildItem`, which made the import fail in Windows PowerShell when
  another module had added a `Size` member; use `LengthOnDisk`
  ([#82](https://github.com/raandree/NTFSSecurity/issues/82))
- Write only the sections of a security descriptor that changed since it
  was read in `Set-NTFSSecurityDescriptor`, such as the DACL after
  `Add-NTFSAccess -SecurityDescriptor`; a descriptor without changes writes
  nothing, and `-Verbose` names the sections that the cmdlet writes. The
  cmdlet wrote every section that `Get-NTFSSecurityDescriptor` had read,
  also an unchanged owner, which failed with error 1307 where the account
  may not assign that owner
  ([#34](https://github.com/raandree/NTFSSecurity/issues/34))
- Document that `Get-NTFSEffectiveAccess -ServerName` works only for the
  administrators of the named computer and the members of its group Access
  Control Assistance Operators; any other account gets the error "Access is
  denied" and no result
- **Breaking:** require `-Path` and `-Target` in `New-NTFSHardLink` and
  `New-NTFSSymbolicLink`. Without `-Path`, they failed with an index error;
  without `-Target`, they used the current location, so
  `New-NTFSSymbolicLink -Path Link` created a link to the current folder
- **Breaking:** write a non-terminating error in `New-NTFSHardLink` and
  `New-NTFSSymbolicLink` for a link that they can't create, such as for an
  existing `-Path`, a missing `-Target`, or a path with a character that
  Windows doesn't allow, and continue with the next link; they stopped
  with a terminating error. A script that relies on the stop needs
  `-ErrorAction Stop`
- Name the computer in the warning of `Get-NTFSEffectiveAccess` when the
  computer of `-ServerName` can't be reached

### Deprecated

- Deprecate NTFSSecurity as a whole: the project will be archived soon.
  Move to
  [WindowsAccessControl](https://github.com/raandree/WindowsAccessControl),
  which is also on the PowerShell Gallery. The description of NTFSSecurity
  in the PowerShell Gallery says so as well
- Deprecate the `-PassThur` alias of `Remove-Item2`; use `-PassThru`
- Deprecate the `MACTripleDES` value of `Get-FileHash2 -Algorithm`: it uses
  a random key, so its result differs on every call; the cmdlet now warns
  when you use it

### Fixed

- Retain the supplied path in the public access- and audit-rule constructors
  so their `FullName`, `Name`, and simplified audit conversions identify
  the item
- Reduce `ReadData` to `Read` in simplified audit entries, and compare them
  with audit entries rather than access entries, preserving equality with
  themselves and with equivalent simplified audit objects
- Compare boxed privilege output values by their privilege and attributes;
  the object overload rejected privilege values and recursively compared
  an attributes enum instead
- Fix `Clear-NTFSAccess -DisableInheritance` and `Set-NTFSSecurityDescriptor`,
  which reported a `RestoreOwnerError` for an owner that had not changed:
  after they took ownership of an item that the user owned already and left a
  DACL without the right to set an owner, they failed to set the same owner
  back
- Fix `InheritedFrom` of `Get-NTFSAccess` and `Get-NTFSAudit` for an entry
  whose folder Windows cannot name, such as for an item that was deleted
  after it was read or a folder above it that the user cannot read: the text
  read `unknown paren`, and the explicit entries showed it as well. An
  inherited entry now shows `unknown parent`, and an explicit entry no source;
  the failed lookup no longer leaks its native buffer
- Fix `Remove-Item2`, `Copy-Item2`, `Move-Item2`, `Set-NTFSOwner`,
  `Set-NTFSSecurityDescriptor`, `Get-NTFSSecurityDescriptor`,
  `Get-NTFSSimpleAccess`, `Get-FileHash2`, `Get-DiskSpace`, and
  `Get-ChildItem2` below the first folder, which went on with the next item
  when a later command ended the pipeline: a `break` or `continue`,
  `Select-Object -First`, or a `throw` was handled as a failure of the item,
  so that `Remove-Item2 -PassThru | Select-Object -First 1` removed every
  item, and the caller never saw the `throw`. They now stop and write no
  error, and the error of the later command reaches the caller
- Fix `Get-ChildItem2 -Filter`, which read a bracket as the start of a
  character class, so that it did not return a file with brackets in its name,
  such as `Report[1].txt`, for that name; only `*` and `?` are wildcards. A
  null `-Filter` is rejected as a parameter error
- Fix `Get-ChildItem2 -Filter *.*`, which returned only the items with a dot
  in their names and dropped the other files and folders, most folders among
  them, instead of every item as `Get-ChildItem` does
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
- Fix `Enable-NTFSAuditInheritance`, `Disable-NTFSAuditInheritance`, and
  `Set-NTFSInheritance -AuditInheritanceEnabled`, which failed with "Access
  is denied" for a file or folder without audit entries, also in an elevated
  session with the Security privilege
- Fix `Add-NTFSAccess`, `Remove-NTFSAccess`, `Clear-NTFSAccess`,
  `Add-NTFSAudit`, `Clear-NTFSAudit`, `Enable-NTFSAccessInheritance`,
  `Disable-NTFSAccessInheritance`, and `Set-NTFSInheritance`, which wrote the
  owner of an item back with the entries they changed; where the account may
  not assign that owner, such as on some file servers, they failed with
  "(1307) This security ID may not be assigned as the owner of this object".
  They now write only the DACL or the SACL
  ([#34](https://github.com/raandree/NTFSSecurity/issues/34))
- Fix `Add-NTFSAccess`, `Add-NTFSAudit`, and `Clear-NTFSAudit`, which in an
  elevated session could store the inherited access entries of an item as
  explicit entries, and `Get-NTFSSecurityDescriptor`, which could return
  them without their inherited flag, so that `Set-NTFSSecurityDescriptor`
  stored them as explicit entries as well
- Fix `Clear-NTFSAudit`, which finished without an error but changed nothing
  in a session without the Security privilege; it now writes an error, like
  the other audit cmdlets
- Fix the cmdlets for the root of a drive, such as `C:\`, or of a volume,
  such as `\\?\Volume{GUID}\`, which read and changed the security
  descriptor of the drive, a device object, instead of that of its root
  folder, so that `Get-NTFSAccess` showed other entries than Explorer
  ([#41](https://github.com/raandree/NTFSSecurity/issues/41))
- Fix `Add-NTFSAudit`, `Remove-NTFSAudit`, and `Clear-NTFSAudit` with a
  security descriptor that was read without the audit entries; they now
  write an error like `Get-NTFSAudit` instead of changing the missing entries
  without one ([#109](https://github.com/raandree/NTFSSecurity/issues/109))
- Fix `Get-NTFSEffectiveAccess`, which blamed a missing Security privilege
  for every failure while the privilege wasn't enabled; the error now names
  the cause that Windows reported
  ([#109](https://github.com/raandree/NTFSSecurity/issues/109))
- Fix `Copy-Item2` and `Move-Item2`, which wrote an error with `-WhatIf` when
  the destination file existed, so that `-WhatIf -ErrorAction Stop` stopped
  the preview; they now name the existing file in a verbose message
  ([#108](https://github.com/raandree/NTFSSecurity/issues/108))
- Fix `Remove-NTFSAudit`, which failed with "(5) Access is denied" for a file
  or folder without audit entries
- Fix `Set-NTFSSecurityDescriptor`, which set the previous owner back after it
  had taken ownership to write a descriptor that sets a new owner, so that
  the new owner was lost or the write failed with error 1307
- Fix the `Write` method of a `Security2.FileSystemSecurity2` object for
  another item, which wrote every section of the descriptor, also an owner
  that Windows returns with the DACL; it now writes the sections that the
  descriptor was read with
  ([#34](https://github.com/raandree/NTFSSecurity/issues/34))
- Fix `Disable-Privileges`, which warned that it couldn't disable the
  privileges that the access token doesn't hold, and the declared output type
  of `Get-FileHash2`, which named the AlphaFS `FileInfo` instead of the type
  name of its objects
  ([#111](https://github.com/raandree/NTFSSecurity/issues/111))
- Fix `Get-NTFSEffectiveAccess`, which returned no access when the computer
  of `-ServerName` couldn't be reached, although it warned that it had
  calculated the result on this computer; it now returns that result
- Fix `Test-Path2`, which stopped with the terminating error "Illegal
  characters in path" in Windows PowerShell for a path with a character
  that Windows doesn't allow in names, such as `|`; it now returns `$false`
  for such a path, as in PowerShell 7, and writes the reason as a debug
  message
- Fix the cmdlets that enable the Backup, Restore, Take Ownership, and
  Security privileges, which left them enabled in the session when a later
  command, such as `Select-Object -First`, or a terminating error stopped
  the pipeline early; they now disable them also then
- Fix the cmdlets that enable the privileges, which stopped with the error
  "Priviledge already disabled" and left the other privileges enabled when
  another command in the pipeline, such as `Disable-Privileges`, had
  disabled one of them; a privilege that they can't disable now gives a
  warning, and they still disable the others
- Fix `Get-NTFSSimpleAccess`, which showed no rights for an entry that
  grants only `ReadData`, and which left out the parent folder of a
  relative path with a single folder name, although `-IncludeRootFolder` is
  on by default
- Fix `Copy-Item2` and `Move-Item2`, which didn't detect a folder at the
  destination, so that a copy failed in the middle after it had copied a
  part of the folder, and which reported a missing destination folder with
  an error that named the source item
  ([#21](https://github.com/raandree/NTFSSecurity/issues/21)); they now
  write `DestinationFileAlreadyExists` and an error that names the missing
  folder, and with `-WhatIf` a verbose message that names it. `Copy-Item2`
  no longer creates the missing folders of the destination when it copies a
  folder, which the prereleases of 5.0.0 did
- Fix `Get-NTFSHardLink`, which stopped for all remaining paths at a folder
  and at a file on a network share, where Windows can't list the names of
  a file, and `New-NTFSHardLink -PassThru`, which stopped with a
  terminating error on a share after it had created the link; both now
  write a non-terminating `GetHardLinkError`
- Fix `-PassThru` of `Set-NTFSSecurityDescriptor`, which returned nothing
  for a descriptor that the cmdlet wrote as the owner, and which turned a
  failed read after a successful write into another attempt of the write
  and a `WriteSdError`; it now writes a `ReadSecurityError` for that read
- Fix `Get-NTFSOrphanedAccess`, which reported an item that it couldn't
  read as an `AddAceError`; it now writes a `ReadSecurityError`, like
  `Get-NTFSAccess`
- Fix every cmdlet for a relative path that starts with a dot but not with
  `.\`, such as `.gitignore`: the cmdlets dropped its first two characters
  and read, changed, or removed the item with the shorter name, such as
  `itignore`, when one existed
- Fix comparing the objects of the access, audit, and security descriptor
  cmdlets: `-eq` and `-contains`, and in PowerShell 7 also
  `Select-Object -Unique` and `Compare-Object`, stopped with an
  `InvalidCastException`, and a security descriptor as the key of a
  hashtable with a `NullReferenceException`. Two objects are now equal when
  they hold the same entry or descriptor, as in .NET. Converting a security
  descriptor to `FileSecurity` or `DirectorySecurity` returned `$null`
- Fix `InheritedFrom` of `Get-NTFSAccess` and `Get-NTFSAudit`: with
  `-ExcludeExplicit`, each inherited entry showed the source of another
  entry, and `Get-NTFSAccess -SecurityDescriptor` stopped with an
  `ArgumentOutOfRangeException` for a descriptor with audit entries, such
  as one that `Get-NTFSSecurityDescriptor` reads in an elevated session
- Fix `Get-NTFSOrphanedAudit`, which returned nothing without the Security
  privilege, as for an item without orphaned entries, and wrote a warning
  for an item that it couldn't read; it now writes a `ReadSecurityError`,
  like `Get-NTFSAudit`
- Fix `Get-NTFSSimpleAccess`, which left out a folder whose parent folder it
  hadn't reported, and with it all of its subfolders, and which compared a
  drive root with the parent folder of the folder before it; such folders
  are now reported with all of their entries, and a parent folder is found
  also when its path differs in case. A folder that came after its parent
  folder a second time failed with a `ReadError`
- Fix `Move-Item2` for a folder on another volume, which Windows can't
  move: the cmdlet copied and deleted it instead, so that an empty folder
  was deleted without being created at the destination, and a folder with
  files failed with an error that named one of its files. It now writes a
  `MoveError` that names the folder and the destination, and leaves the
  folder in place
- Fix `New-NTFSHardLink` and `New-NTFSSymbolicLink`, which failed with
  `GetDefaultValueFailed` for every object piped to them, such as the rows
  of a CSV file with the columns `Path` and `Target`
- Fix the errors of `New-NTFSSymbolicLink` for an existing `-Path` and a
  missing `-Target`, and of `New-NTFSHardLink` for a folder as `-Target`,
  which named no path. `New-NTFSSymbolicLink` now checks `-Path` first,
  like `New-NTFSHardLink`
- Fix `Get-NTFSEffectiveAccess`, which warned that the result might be
  inaccurate for every name of this computer in `-ServerName` except
  `localhost` in lowercase, such as `.`, `LOCALHOST`, or the computer name,
  where the computer doesn't offer the remote access check

- Fix [Get-ChildItem2](Docs/Cmdlets/Get-ChildItem2.md) with `-Hidden`,
  which omitted the first hidden item unless `-Force` was also supplied

[Unreleased]: https://github.com/raandree/NTFSSecurity/compare/4.2.6...HEAD
