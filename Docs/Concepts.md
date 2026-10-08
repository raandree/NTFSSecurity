# Concepts

This page explains the Windows security concepts that the NTFSSecurity
cmdlets work with: security descriptors, accounts, access rights,
inheritance, privileges, long paths, and the module settings. Read it before
you change permissions on production data.

## Security descriptors

Every file and folder on an NTFS volume has a security descriptor. The module
manages three of its parts:

| Part | Purpose | Cmdlets |
| --- | --- | --- |
| Owner | The account that owns the item. The owner can always read and change the item's permissions. | `Get-NTFSOwner`, `Set-NTFSOwner` |
| Discretionary access control list (DACL) | Access control entries (ACEs) that allow or deny access. | `Get-NTFSAccess`, `Add-NTFSAccess`, `Remove-NTFSAccess`, `Clear-NTFSAccess` |
| System access control list (SACL) | Audit entries that tell Windows which access attempts to write to the Security event log. | `Get-NTFSAudit`, `Add-NTFSAudit`, `Remove-NTFSAudit`, `Clear-NTFSAudit` |

Each entry is either explicit, which means it is set on the item itself, or
inherited from a parent folder. Inheritance is controlled separately for the
DACL and the SACL; see [Inheritance](#inheritance).

Most cmdlets accept either `-Path` or `-SecurityDescriptor`:

- With `-Path`, the cmdlet reads or writes the item directly. `-Path`
  accepts pipeline input, so you can pipe the output of `Get-ChildItem`,
  `Get-ChildItem2`, or `Get-Item2` into the cmdlet.
- With `-SecurityDescriptor`, the cmdlet changes a security descriptor object
  that you got from `Get-NTFSSecurityDescriptor`. Nothing is written to disk
  until you pass the object to `Set-NTFSSecurityDescriptor`, so you can make
  several changes and write them in one step.

When you pass a security descriptor to `Add-NTFSAccess`, `Remove-NTFSAccess`,
`Add-NTFSAudit`, or `Remove-NTFSAudit` without `-AppliesTo`, the cmdlet uses
the `-InheritanceFlags` and `-PropagationFlags` parameters and their defaults,
as it does for a path. Before 5.0.0, such a command failed, because PowerShell
couldn't choose between the two security descriptor parameter sets.

## Accounts

The `-Account` parameter accepts an account name, such as
`CONTOSO\JohnDoe`, `BUILTIN\Users`, or `NT AUTHORITY\SYSTEM`, or a security
identifier (SID) string, such as `S-1-5-32-545`. The output shows the account
name when Windows can resolve the SID.

An entry whose SID no longer resolves to an account is called orphaned.
This happens when an account was deleted. `Get-NTFSOrphanedAccess` and
`Get-NTFSOrphanedAudit` list such entries. A SID can also fail to resolve
temporarily, for example when a domain controller is unreachable, so check
the results before you remove them.

## Access rights

The `-AccessRights` parameter takes a `FileSystemRights2` value. You can
combine values by passing a list, for example
`-AccessRights Delete, DeleteSubdirectoriesAndFiles`.

PowerShell also accepts any unambiguous prefix of a value name, so `Full`
binds to `FullControl` and `Mod` binds to `Modify`. Use the full names in
scripts.

### Basic permissions

The basic permissions on the **Security** tab of the file or folder
properties are combinations of the advanced permissions:

| `-AccessRights` value | Includes | Basic permission |
| --- | --- | --- |
| `Read` | `ListDirectory`, `ReadAttributes`, `ReadExtendedAttributes`, `ReadPermissions` | Read |
| `ReadAndExecute` | `Read` and `Traverse` | Read & execute |
| `Write` | `CreateFiles`, `CreateDirectories`, `WriteAttributes`, `WriteExtendedAttributes` | Write |
| `Modify` | `ReadAndExecute`, `Write`, and `Delete` | Modify |
| `FullControl` | `Modify`, `DeleteSubdirectoriesAndFiles`, `ChangePermissions`, `TakeOwnership`, and `Synchronize` | Full control |

### Advanced permissions

Several advanced permissions have two names because the same bit means
something different for files and for folders. The output always shows the
first name in the table.

| `-AccessRights` value | Shown as | Advanced permission | Effect |
| --- | --- | --- | --- |
| `ListDirectory`, `ReadData` | `ListDirectory` | List folder / read data | List the contents of a folder; read the data of a file. |
| `CreateFiles`, `WriteData` | `CreateFiles` | Create files / write data | Create files in a folder; change or overwrite the data of a file. |
| `CreateDirectories`, `AppendData` | `CreateDirectories` | Create folders / append data | Create subfolders; append data to the end of a file. |
| `Traverse`, `ExecuteFile` | `Traverse` | Traverse folder / execute file | Move through a folder to reach items below it; run a program file. |
| `ReadAttributes` | `ReadAttributes` | Read attributes | Read attributes such as read-only and hidden. |
| `WriteAttributes` | `WriteAttributes` | Write attributes | Change attributes such as read-only and hidden. |
| `ReadExtendedAttributes` | `ReadExtendedAttributes` | Read extended attributes | Read the extended attributes that programs define. |
| `WriteExtendedAttributes` | `WriteExtendedAttributes` | Write extended attributes | Change the extended attributes that programs define. |
| `DeleteSubdirectoriesAndFiles` | `DeleteSubdirectoriesAndFiles` | Delete subfolders and files | Delete items in a folder, even without `Delete` on those items. |
| `Delete` | `Delete` | Delete | Delete the item. |
| `ReadPermissions` | `ReadPermissions` | Read permissions | Read the owner and the permissions. |
| `ChangePermissions` | `ChangePermissions` | Change permissions | Change the permissions. |
| `TakeOwnership` | `TakeOwnership` | Take ownership | Make yourself the owner. |
| `Synchronize` | `Synchronize` | Not shown | Wait on a file handle. |

Windows adds `Synchronize` to every allow entry except `FullControl`, which
already contains it. Reading an entry back therefore shows, for example,
`Modify, Synchronize`.

Windows also merges entries that have the same account, type, and
inheritance settings. Adding `Read` and then `Write` for the same account
results in one entry with both rights.

The generic rights `GenericRead`, `GenericWrite`, `GenericExecute`, and
`GenericAll` are mapped by Windows to the file rights above. On a folder that
passes the entry on to its children, Windows stores two entries: one with the
mapped rights for the folder and one that keeps the generic right for the
child items.

`Get-NTFSSimpleAccess` works on folders only. It condenses the rights of each
entry into the simple values `Read`, `Write`, and `Delete`. For every folder
after the first one, it reports only the entries that differ from the parent
folder, which shows where the permissions change in a folder tree.

## Inheritance

A folder passes its inheritable entries on to its child items. You can stop
an item from inheriting entries, separately for access entries and for audit
entries:

- `Disable-NTFSAccessInheritance` blocks inheritance. By default, it copies
  the inherited entries as explicit entries; `-RemoveInheritedAccessRules`
  drops them instead.
- `Enable-NTFSAccessInheritance` restores inheritance and keeps the explicit
  entries unless you use `-RemoveExplicitAccessRules`.
- `Get-NTFSInheritance` and `Set-NTFSInheritance` read and set both
  settings at once. Like the dedicated cmdlets without their switches,
  `Set-NTFSInheritance` keeps the entries; before 5.0.0, it removed the
  inherited access entries when it turned access inheritance off, and the
  explicit audit entries when it turned audit inheritance on.
  The audit equivalents of the dedicated cmdlets are
  `Disable-NTFSAuditInheritance` and `Enable-NTFSAuditInheritance`, with
  the switches `-RemoveInheritedAuditRules` and `-RemoveExplicitAuditRules`.

### The AppliesTo parameter

Whether and how an entry is passed on is defined by its inheritance flags
and propagation flags. The `-AppliesTo` parameter of `Add-NTFSAccess`,
`Remove-NTFSAccess`, `Add-NTFSAudit`, and `Remove-NTFSAudit` sets both with
the names that the **Applies to** list in the **Advanced Security Settings**
dialog uses:

| `-AppliesTo` value | `InheritanceFlags` | `PropagationFlags` | Applies to |
| --- | --- | --- | --- |
| `ThisFolderOnly` | `None` | `None` | This folder only |
| `ThisFolderSubfoldersAndFiles` | `ContainerInherit, ObjectInherit` | `None` | This folder, subfolders and files |
| `ThisFolderAndSubfolders` | `ContainerInherit` | `None` | This folder and subfolders |
| `ThisFolderAndFiles` | `ObjectInherit` | `None` | This folder and files |
| `SubfoldersAndFilesOnly` | `ContainerInherit, ObjectInherit` | `InheritOnly` | Subfolders and files only |
| `SubfoldersOnly` | `ContainerInherit` | `InheritOnly` | Subfolders only |
| `FilesOnly` | `ObjectInherit` | `InheritOnly` | Files only |

Each value also exists with the suffix `OneLevel`, for example
`ThisFolderAndSubfoldersOneLevel`. These values add the `NoPropagateInherit`
propagation flag, which passes the entry on to the direct children only. In
the dialog, this is the check box **Only apply these permissions to objects
and/or containers within this container**.

The flags mean:

- `ContainerInherit`: child folders inherit the entry.
- `ObjectInherit`: child files inherit the entry.
- `InheritOnly`: the entry applies only to the children, not to the item
  that holds it.
- `NoPropagateInherit`: the entry is passed on one level only.

`Add-NTFSAccess` and `Add-NTFSAudit` use `ThisFolderSubfoldersAndFiles` by
default. Files have no children, so entries on files are stored without
inheritance flags.

## Privileges

Windows grants the following privileges to the local Administrators group.
They bypass the permission checks that would otherwise stop you from reading
or changing an item:

| Privilege | Windows name | What it allows |
| --- | --- | --- |
| Backup | `SeBackupPrivilege` | Read any file or folder, regardless of its permissions. |
| Restore | `SeRestorePrivilege` | Write any file or folder and set any account as the owner. |
| Take ownership | `SeTakeOwnershipPrivilege` | Make yourself the owner of any item. |
| Security | `SeSecurityPrivilege` | Read and change audit entries (the SACL). |

A privilege can only be enabled if the account holds it and the PowerShell
session runs elevated (**Run as administrator**).

The access, audit, inheritance, owner, and security descriptor cmdlets enable
these privileges automatically while they run and disable the ones they
enabled when they finish, also when a later command such as
`Select-Object -First` or a terminating error stops the pipeline early. A
privilege that another command in the pipeline, such as `Disable-Privileges`,
has disabled in the meantime stays disabled, and a privilege that a cmdlet
can't disable when it finishes gives a warning. If a
privilege cannot be enabled, the cmdlet continues without it. You can turn
this behavior off with the `EnablePrivileges` module setting. Before 5.0.0,
the inheritance cmdlets were an exception: they always tried to enable the
privileges, and when `EnablePrivileges` was `$false`, they left them enabled.
And before 5.0.0, every cmdlet left the privileges enabled in the session when
the pipeline stopped early, and stopped with the error "Priviledge already
disabled" when another command in the pipeline had disabled one of them.

`Enable-Privileges` enables the four privileges for the current PowerShell
process until you run `Disable-Privileges` or close the session.
`Get-Privileges` lists the privileges of the current process and their
state.

When reading or changing an item fails with an access-denied error, most of
these cmdlets make the current user the owner of the item, retry, and then
restore the previous owner, also when the retry fails. Before 5.0.0, a failed
retry left the current user as the owner. Taking ownership needs the Take
Ownership right on the item or the Take Ownership privilege, and setting the
previous owner back needs the Restore privilege unless that owner is the user
or one of its groups. When the owner of an item changes, Windows removes its
entries for OWNER RIGHTS, so the retry removes such entries as well. For
reading, the retry doesn't help: the cmdlet must read the owner first, which
needs the same right as reading the permissions.

Reading or changing audit entries always requires the Security privilege.
Without it, the audit cmdlets fail, and `Get-NTFSEffectiveAccess` warns that
it might not be able to read the effective permissions.

## Long paths

Windows PowerShell 5.1 cannot handle paths longer than 260 characters;
`Get-ChildItem` fails on them. The cmdlets `Get-ChildItem2`, `Get-Item2`,
`Copy-Item2`, `Move-Item2`, `Remove-Item2`, and `Test-Path2` use the
[AlphaFS](https://github.com/alphaleonis/AlphaFS) library and work with long
paths. Their output binds to the `-Path` parameter of the NTFSSecurity
cmdlets, which handle long paths as well:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSAccess -ExcludeInherited
```

The module defines the aliases `dir2` for `Get-ChildItem2`, `gi2` for
`Get-Item2`, and `rm2` and `del2` for `Remove-Item2`.

## Extended file and folder objects

The module extends the `FileInfo` and `DirectoryInfo` objects that
`Get-Item` and `Get-ChildItem` return. These members are not available on
the AlphaFS objects that the `*-Item2` cmdlets return.

| Member | Type | Available on | Description |
| --- | --- | --- | --- |
| `Owner` | Property | Files and folders | The owner of the item. |
| `IsInheritanceBlocked` | Property | Files and folders | `$true` if the item does not inherit access entries. |
| `LengthOnDisk` | Property | Files | The file size rounded up to whole clusters of the volume. Before 5.0.0, `Size` was an alias. |
| `EnableInheritance()` | Method | Files and folders | Turns on access inheritance. |
| `DisableInheritance()` | Method | Files and folders | Turns off access inheritance. Pass `$false` to drop the inherited entries instead of copying them. |
| `GetHash()` | Method | Files | Returns the SHA1 hash of the file as a hexadecimal string. |

Access entries returned by `Get-NTFSAccess` have an additional `AccountType`
property. When the current user is a domain account, reading the property
queries Active Directory and returns the object class of the account, such
as `user` or `group`; otherwise, the property is empty.

## Module settings

The `PrivateData` section of `NTFSSecurity.psd1` contains switches that
change the module's behavior:

| Setting | Default | Effect |
| --- | --- | --- |
| `EnablePrivileges` | `$true` | The security cmdlets enable the Backup, Restore, Take Ownership, and Security privileges while they run. |
| `GetInheritedFrom` | `$true` | `Get-NTFSAccess` and `Get-NTFSAudit` fill the `InheritedFrom` property with the path of the folder that an inherited entry comes from. |
| `GetFileSystemModeProperty` | `$true` | `Get-ChildItem2` adds the `Mode` property to its output. |
| `IdentifyHardLinks` | `$true` | `Get-ChildItem2` adds a `HardLinkCount` property to each file. |
| `ShowAccountSid` | `$false` | The default table output of access and audit entries shows the SID next to the account name. |

`GetInheritedFrom`, `GetFileSystemModeProperty`, and `IdentifyHardLinks`
cost extra work for every item. Turn them off to speed up large folder
trees when you don't need the information.

To change a setting for the current session only, change the value after
you import the module:

```powershell
(Get-Module -Name NTFSSecurity).PrivateData.ShowAccountSid = $true
```

To change the default, edit `NTFSSecurity.psd1` in the module folder.
