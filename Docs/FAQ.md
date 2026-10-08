# Frequently asked questions

Answers to questions that come up again and again in the issues. For the
background, read [Concepts](Concepts.md); for longer scripts, read
[Examples](Examples.md).

## The module fails to load with HRESULT 0x80131515

Windows blocks the assemblies of a ZIP file that was downloaded from the
internet. Install the module from the PowerShell Gallery instead, as
described in [Installation](README.md#installation), or unblock the files of
a downloaded copy with `Get-ChildItem -Recurse | Unblock-File` before you
import it.

## Access is denied, although I am an administrator

Run PowerShell elevated. Only an elevated session holds the Backup,
Restore, Take Ownership, and Security privileges, which the cmdlets enable
to read and change items that your account has no rights on. Reading or
changing audit entries always needs the Security privilege. See
[Privileges](Concepts.md#privileges) and the module setting
`EnablePrivileges` in [Module settings](Concepts.md#module-settings).

## Get-NTFSEffectiveAccess shows other rights than Explorer

`Get-NTFSEffectiveAccess` calculates the rights that the NTFS permissions
of the item grant to one account. It doesn't include share permissions,
which Explorer adds for a path on a file share, and the account must be
resolvable on the computer that runs the cmdlet. See
[Get-NTFSEffectiveAccess](Cmdlets/Get-NTFSEffectiveAccess.md).

## The root of a share loses its inherited permissions over UNC

When you change the permissions of the root folder of a share through its
UNC path, such as `\\server\share`, Windows can't reach the parent folder on
the server to inherit from. The root folder then loses its inherited
entries, or keeps them as explicit entries that no longer follow the parent
folder. `icacls` and `Set-Acl` behave the same way. Change the root folder
through its local path on the server, such as `D:\Shares\Data`, and use the
UNC path for the folders below the root. See
[#67](https://github.com/raandree/NTFSSecurity/issues/67).

## Get-ChildItem2 -Recurse runs in a loop through junctions

A junction can point to a folder above it. Use `-SkipMountPoints` and
`-SkipSymbolicLinks` to leave out junctions and symbolic links when you
walk a tree, for example before you pipe the items to `Get-NTFSAccess`.
See [Get-ChildItem2](Cmdlets/Get-ChildItem2.md).

## How do I restore permissions that I exported?

`Get-NTFSAccess` returns the account, the rights, the type, and the
inheritance and propagation flags of each entry. `Add-NTFSAccess` binds
`-Account`, `-AccessRights`, `-AccessType`, `-InheritanceFlags`, and
`-PropagationFlags` by property name, so the objects, or the rows of a CSV
file with these columns and the path, can be piped back to it. See
[Add-NTFSAccess](Cmdlets/Add-NTFSAccess.md).

## How do I apply the same audit entries to a whole folder tree?

Add the entry to the top folder only. By default, `Add-NTFSAudit` applies
it to the folder, its subfolders, and its files, so the items below inherit
it. To remove other entries from the items below, use `Clear-NTFSAudit`,
and use `Enable-NTFSAuditInheritance` where inheritance is blocked.
Changing audit entries needs an elevated session. See
[Add-NTFSAudit](Cmdlets/Add-NTFSAudit.md).

## Can I use a PowerShell drive in a path?

No. The cmdlets read and write the file system directly through the AlphaFS
library, not through the PowerShell providers, so they don't know drives
that `New-PSDrive` created, or drives of other providers such as `HKLM:`.
Use the file system path instead, such as `C:\Data` or `\\server\share`. A
relative path is resolved against the current file system location, also a
name that starts with a dot, such as `.gitignore`; before 5.0.0-rc6, the
cmdlets dropped the first two characters of such a name. See
[Long paths](Concepts.md#long-paths).

## How do I compare the permissions of two items?

Compare the properties of the entries, not the entries themselves. Each
entry that `Get-NTFSAccess` returns is an object of its own, and like the
access rules of .NET, two entries are equal only when they are the same
object, even when they grant the same rights to the same account.
`Compare-Object` with `-Property` lists the entries that only one of the
items has:

```powershell
$properties = 'Account', 'AccessRights', 'AccessControlType', 'InheritanceFlags', 'PropagationFlags'
Compare-Object -ReferenceObject (Get-NTFSAccess -Path C:\Data\A) -DifferenceObject (Get-NTFSAccess -Path C:\Data\B) -Property $properties
```

The same works for the entries of `Get-NTFSAudit`, with `AuditFlags` in
place of `AccessControlType`. See
[Get-NTFSAccess](Cmdlets/Get-NTFSAccess.md).
