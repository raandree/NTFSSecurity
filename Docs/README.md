# NTFSSecurity

NTFSSecurity is a PowerShell module for managing the permissions, audit
settings, inheritance, and ownership of files and folders on NTFS volumes.

PowerShell offers only `Get-Acl` and `Set-Acl`; everything between reading
and writing an access control list is up to you. NTFSSecurity closes this gap
with task-level cmdlets that work with the PowerShell pipeline.

## Features

- Read, add, remove, and clear access entries and audit entries.
- Show the effective access of an account and find orphaned entries.
- Inspect, enable, and disable inheritance.
- Get and set the owner of files and folders.
- Change several entries in memory and write them in one step.
- Enable the Backup, Restore, Take Ownership, and Security privileges to
  work on items that you can't otherwise access.
- Work with paths longer than 260 characters.
- Create hard links and symbolic links, list the hard links of a file, and
  get file hashes and disk space.

## Requirements

- Windows with NTFS volumes.
- Windows PowerShell 5.1 or PowerShell 7. `Get-FileHash2` works only in
  Windows PowerShell.
- An elevated session for audit operations, owner changes, and access to
  items that your account can't open. See
  [Privileges](Concepts.md#privileges).

## Installation

Install the module from the
[PowerShell Gallery](https://www.powershellgallery.com/packages/NTFSSecurity):

```powershell
Install-Module -Name NTFSSecurity
```

To try a prerelease of the next version, add `-AllowPrerelease`. A
prerelease is for testing; don't use it in production.

You can also install a release without the PowerShell Gallery. Download
`NTFSSecurity.zip` from the
[releases page](https://github.com/raandree/NTFSSecurity/releases) on GitHub
and extract it into a module folder. In an elevated session, these commands
install the module for all users of Windows PowerShell 5.1 and PowerShell 7:

```powershell
Unblock-File -Path .\NTFSSecurity.zip
Expand-Archive -Path .\NTFSSecurity.zip -DestinationPath "$env:ProgramFiles\WindowsPowerShell\Modules"
```

`Unblock-File` removes the mark that Windows adds to downloaded files. If you
extract a marked zip file with File Explorer, the extracted files keep the
mark, and the execution policy `RemoteSigned` stops the module from loading.

The zip file contains the folder `NTFSSecurity`. Remove an older copy of that
folder first. To install the module only for yourself, extract it into a
folder of `$env:PSModulePath` in your profile instead, for example
`Documents\WindowsPowerShell\Modules` for Windows PowerShell 5.1 or
`Documents\PowerShell\Modules` for PowerShell 7.

## Getting started

```powershell
Import-Module -Name NTFSSecurity
Get-Command -Module NTFSSecurity
Get-NTFSAccess -Path C:\Windows
```

Read [Concepts](Concepts.md) for the background and [Examples](Examples.md)
for common tasks. Every cmdlet has a reference page with all parameters and
examples; see the [cmdlet list](#cmdlets). The [FAQ](FAQ.md) answers
questions that come up again and again.

## Cmdlets

### Permissions

| Cmdlet | Description |
| --- | --- |
| [Get-NTFSAccess](Cmdlets/Get-NTFSAccess.md) | Gets the access control entries (ACEs) of a file, a folder, or a security descriptor. |
| [Add-NTFSAccess](Cmdlets/Add-NTFSAccess.md) | Adds an access control entry (ACE) to a file, a folder, or a security descriptor. |
| [Remove-NTFSAccess](Cmdlets/Remove-NTFSAccess.md) | Removes rights from the access control entries (ACEs) of a file, a folder, or a security descriptor. |
| [Clear-NTFSAccess](Cmdlets/Clear-NTFSAccess.md) | Removes all explicit access control entries from a file or folder. |
| [Get-NTFSEffectiveAccess](Cmdlets/Get-NTFSEffectiveAccess.md) | Gets the rights an account effectively has on a file or folder. |
| [Get-NTFSOrphanedAccess](Cmdlets/Get-NTFSOrphanedAccess.md) | Gets the access control entries whose account cannot be resolved to a name. |
| [Get-NTFSSimpleAccess](Cmdlets/Get-NTFSSimpleAccess.md) | Gets the permissions of folders reduced to read, write, and delete. |

### Auditing

| Cmdlet | Description |
| --- | --- |
| [Get-NTFSAudit](Cmdlets/Get-NTFSAudit.md) | Gets the audit entries of a file or folder. |
| [Add-NTFSAudit](Cmdlets/Add-NTFSAudit.md) | Adds an audit entry to a file or folder. |
| [Remove-NTFSAudit](Cmdlets/Remove-NTFSAudit.md) | Removes an audit entry from a file or folder. |
| [Clear-NTFSAudit](Cmdlets/Clear-NTFSAudit.md) | Removes all explicit audit entries from a file or folder. |
| [Get-NTFSOrphanedAudit](Cmdlets/Get-NTFSOrphanedAudit.md) | Gets the audit entries whose account cannot be resolved. |

### Inheritance

| Cmdlet | Description |
| --- | --- |
| [Get-NTFSInheritance](Cmdlets/Get-NTFSInheritance.md) | Gets the inheritance state of the access rules and the audit rules of a file or folder. |
| [Set-NTFSInheritance](Cmdlets/Set-NTFSInheritance.md) | Sets the inheritance of the access rules and the audit rules of a file or folder. |
| [Enable-NTFSAccessInheritance](Cmdlets/Enable-NTFSAccessInheritance.md) | Restores the inheritance of access rules on a file or folder. |
| [Disable-NTFSAccessInheritance](Cmdlets/Disable-NTFSAccessInheritance.md) | Blocks the inheritance of access rules on a file or folder. |
| [Enable-NTFSAuditInheritance](Cmdlets/Enable-NTFSAuditInheritance.md) | Restores the inheritance of audit rules on a file or folder. |
| [Disable-NTFSAuditInheritance](Cmdlets/Disable-NTFSAuditInheritance.md) | Blocks the inheritance of audit rules on a file or folder. |

### Owner and security descriptor

| Cmdlet | Description |
| --- | --- |
| [Get-NTFSOwner](Cmdlets/Get-NTFSOwner.md) | Gets the owner of a file or folder. |
| [Set-NTFSOwner](Cmdlets/Set-NTFSOwner.md) | Sets the owner of a file or folder. |
| [Get-NTFSSecurityDescriptor](Cmdlets/Get-NTFSSecurityDescriptor.md) | Gets the security descriptor of a file or folder. |
| [Set-NTFSSecurityDescriptor](Cmdlets/Set-NTFSSecurityDescriptor.md) | Writes a security descriptor to the file or folder it was read from. |

### Privileges

| Cmdlet | Description |
| --- | --- |
| [Get-Privileges](Cmdlets/Get-Privileges.md) | Gets the privileges in the access token of the current PowerShell process. |
| [Enable-Privileges](Cmdlets/Enable-Privileges.md) | Enables the file system privileges in the access token of the current PowerShell process. |
| [Disable-Privileges](Cmdlets/Disable-Privileges.md) | Disables the file system privileges in the access token of the current PowerShell process. |

### Files and folders with long paths

| Cmdlet | Description |
| --- | --- |
| [Get-ChildItem2](Cmdlets/Get-ChildItem2.md) | Gets the files and folders in one or more folders, including paths longer than 260 characters. |
| [Get-Item2](Cmdlets/Get-Item2.md) | Gets the file or folder at a specified path, including paths longer than 260 characters. |
| [Copy-Item2](Cmdlets/Copy-Item2.md) | Copies a file to another location, including paths longer than 260 characters. |
| [Move-Item2](Cmdlets/Move-Item2.md) | Moves a file or folder to another location, including paths longer than 260 characters. |
| [Remove-Item2](Cmdlets/Remove-Item2.md) | Deletes a file or folder, including paths longer than 260 characters. |
| [Test-Path2](Cmdlets/Test-Path2.md) | Determines whether a file or folder exists at the specified path. |

### Links, hashes, and disk space

| Cmdlet | Description |
| --- | --- |
| [Get-NTFSHardLink](Cmdlets/Get-NTFSHardLink.md) | Gets all hard links that refer to the same file as the specified path. |
| [New-NTFSHardLink](Cmdlets/New-NTFSHardLink.md) | Creates a hard link to an existing file. |
| [New-NTFSSymbolicLink](Cmdlets/New-NTFSSymbolicLink.md) | Creates a symbolic link to an existing file or folder. |
| [Get-FileHash2](Cmdlets/Get-FileHash2.md) | Gets the hash value of one or more files. |
| [Get-DiskSpace](Cmdlets/Get-DiskSpace.md) | Gets size, free space, and cluster information for the volumes of a computer. |

## Tutorials

The author of the module wrote two tutorials in 2014. Some cmdlet names in
them have changed since; use the cmdlet reference for the current names.

- [NTFSSecurity Tutorial 1 - Getting, adding and removing permissions](https://learn.microsoft.com/en-us/archive/blogs/fieldcoding/ntfssecurity-tutorial-1-getting-adding-and-removing-permissions)
- [NTFSSecurity Tutorial 2 - Managing NTFS Inheritance and Using Privileges](https://learn.microsoft.com/en-us/archive/blogs/fieldcoding/ntfssecurity-tutorial-2-managing-ntfs-inheritance-and-using-privileges)

## Version history

See the [changelog](../CHANGELOG.md) for the changes since 4.2.6 and the
[version history](Version-History.md) for 4.2.6 and earlier.

## Contributing

Contributions are welcome. See the [contributor guide](Contributing.md).

## License

NTFSSecurity is licensed under the [MIT license](../LICENSE).
