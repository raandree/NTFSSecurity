---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Remove-NTFSAccess.md
schema: 2.0.0
---

# Remove-NTFSAccess

## SYNOPSIS

Removes rights from the access control entries (ACEs) of a file, a folder, or a security descriptor.

## SYNTAX

### PathComplex (Default)
```
Remove-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-RemoveSpecific] [-PassThru] [<CommonParameters>]
```

### PathSimple
```
Remove-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] -AppliesTo <ApplyTo> [-RemoveSpecific] [-PassThru] [<CommonParameters>]
```

### SDSimple
```
Remove-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] -AppliesTo <ApplyTo> [-RemoveSpecific]
 [-PassThru] [<CommonParameters>]
```

### SDComplex
```
Remove-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-RemoveSpecific] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

Removes the rights in `-AccessRights` from the access control entries (ACEs) of a file or a folder. An entry is addressed by the account in `-Account`, the access type in `-AccessType`, and the inheritance and propagation flags, which are given either as `-AppliesTo` or as `-InheritanceFlags` and `-PropagationFlags`.

Only the specified rights are taken away: when an entry grants more than `-AccessRights` names, the remaining rights stay in place, and the entry disappears only when all of its rights are removed. An `Allow` entry is always matched with the `Synchronize` right added to the specified rights. The flags must describe the entry as it exists on the item; when they do not, Windows splits the entry instead of removing the rights, so use the values that `Get-NTFSAccess` reports for the entry you want to change. With `-RemoveSpecific`, the cmdlet removes only an entry that matches exactly.

Inherited entries cannot be removed from the item that inherits them. Remove them from the folder named in the `InheritedFrom` property, or run `Disable-NTFSAccessInheritance` on the item first, which copies the inherited entries into it as explicit ones that this cmdlet can then remove.

The cmdlet has four parameter sets. The `Path` sets read the item from disk and write the changed DACL back immediately, while the `SD` sets change a `Security2.FileSystemSecurity2` object returned by `Get-NTFSSecurityDescriptor` in memory until `Set-NTFSSecurityDescriptor` writes it back. The `Simple` sets take `-AppliesTo`, the `Complex` sets take `-InheritanceFlags` and `-PropagationFlags`, and `PathComplex` is the default. A command without `-AppliesTo` uses a `Complex` set, also when it works on a security descriptor. Before 5.0.0, a command that used `-SecurityDescriptor` without `-AppliesTo`, `-InheritanceFlags`, or `-PropagationFlags` failed, because PowerShell couldn't choose between the two `SD` sets. All relevant parameters bind by property name, so the output of `Get-NTFSAccess` and `Get-NTFSOrphanedAccess` can be piped directly into this cmdlet. The cmdlet writes no output unless `-PassThru` is used.

## EXAMPLES

### Example 1: Remove a permission from a folder

```PowerShell
PS C:\> Remove-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe' -AccessRights Modify
```

This command removes the modify rights of an account from `C:\Data`. The entry is matched with the default values of the remaining parameters, which are the access type `Allow` and the inheritance flags `ContainerInherit, ObjectInherit` with no propagation flags.

### Example 2: Take a single right away from an existing entry

```PowerShell
PS C:\> Remove-NTFSAccess -Path C:\Data -Account 'CONTOSO\Domain Users' -AccessRights DeleteSubdirectoriesAndFiles -AppliesTo ThisFolderSubfoldersAndFiles
```

This command removes one right from the entry of a domain group and leaves the other rights of that entry untouched.

### Example 3: Remove all explicit permissions of an account

```PowerShell
PS C:\> Get-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe' -ExcludeInherited | Remove-NTFSAccess
```

This command removes every access control entry that was defined for an account on `C:\Data`. The piped objects supply the path, the account, the rights, the access type, and the flags, so each entry is matched exactly as it exists.

### Example 4: Clean up orphaned entries in a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOrphanedAccess -ExcludeInherited | Remove-NTFSAccess
```

This command removes the access control entries of deleted accounts from all items below `C:\Data`. `-ExcludeInherited` makes sure that each entry is removed where it is defined instead of where it is inherited.

## PARAMETERS

### -AccessRights

Specifies the rights to remove from the matching access control entry. The parameter accepts basic rights such as `Read`, `ReadAndExecute`, `Modify`, and `FullControl`, granular rights such as `CreateFiles`, `Traverse`, or `WriteAttributes`, and any combination of them. Rights that the entry grants but that are not listed here remain in place. For how the values relate to the Windows security dialog, see [Concepts](../Concepts.md).

```yaml
Type: FileSystemRights2
Parameter Sets: (All)
Aliases: FileSystemRights
Accepted values: None, ReadData, ListDirectory, WriteData, CreateFiles, AppendData, CreateDirectories, ReadExtendedAttributes, WriteExtendedAttributes, ExecuteFile, Traverse, DeleteSubdirectoriesAndFiles, ReadAttributes, WriteAttributes, Write, Delete, ReadPermissions, Read, ReadAndExecute, Modify, ChangePermissions, TakeOwnership, Synchronize, FullControl, GenericAll, GenericExecute, GenericWrite, GenericRead

Required: True
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AccessType

Specifies whether an `Allow` or a `Deny` entry is addressed. The default is `Allow`. An entry of the other type is not touched.

```yaml
Type: AccessControlType
Parameter Sets: (All)
Aliases: AccessControlType
Accepted values: Allow, Deny

Required: False
Position: Named
Default value: Allow
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Account

Specifies one or more accounts or groups whose entries are changed. An account can be given as a name such as `CONTOSO\JohnDoe`, `BUILTIN\Users`, or `NT AUTHORITY\SYSTEM`, or as a SID string such as `S-1-5-21-1234567890-1234567890-1234567890-1001`, which is how the entries of deleted accounts are addressed.

```yaml
Type: IdentityReference2[]
Parameter Sets: (All)
Aliases: IdentityReference, ID

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AppliesTo

Specifies the scope of the entry that is addressed, in the wording of the Windows security dialog, for example `ThisFolderOnly`, `ThisFolderAndSubfolders`, or `SubfoldersAndFilesOnly`. The cmdlet translates the value into the equivalent inheritance and propagation flags, so this parameter and the pair `-InheritanceFlags` and `-PropagationFlags` are two ways to describe the same entry. Use the scope that `Get-NTFSAccess` shows in the "Applies to" column of the entry.

```yaml
Type: ApplyTo
Parameter Sets: PathSimple, SDSimple
Aliases:
Accepted values: ThisFolderOnly, ThisFolderSubfoldersAndFiles, ThisFolderAndSubfolders, ThisFolderAndFiles, SubfoldersAndFilesOnly, SubfoldersOnly, FilesOnly, ThisFolderSubfoldersAndFilesOneLevel, ThisFolderAndSubfoldersOneLevel, ThisFolderAndFilesOneLevel, SubfoldersAndFilesOnlyOneLevel, SubfoldersOnlyOneLevel, FilesOnlyOneLevel

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -InheritanceFlags

Specifies the inheritance flags of the entry that is addressed. `ContainerInherit` marks an entry that child folders inherit, `ObjectInherit` marks an entry that child files inherit, and `None` marks an entry that is not inherited at all. The default is `ContainerInherit, ObjectInherit`, which is the scope `ThisFolderSubfoldersAndFiles`. Entries on files always carry `None`.

```yaml
Type: InheritanceFlags
Parameter Sets: PathComplex, SDComplex
Aliases:
Accepted values: None, ContainerInherit, ObjectInherit

Required: False
Position: Named
Default value: ContainerInherit, ObjectInherit
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PassThru

Indicates that the cmdlet writes the access control entries of every processed item, explicit and inherited, after the change. Without this switch the cmdlet produces no output.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path

Specifies the path of one or more files or folders whose access control entries are changed. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its alias `FullName`.

```yaml
Type: String[]
Parameter Sets: PathComplex, PathSimple
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -PropagationFlags

Specifies the propagation flags of the entry that is addressed. `None` marks an entry that is inherited by all levels allowed by its inheritance flags, `InheritOnly` marks an entry that does not apply to the item it is defined on, and `NoPropagateInherit` marks an entry that is only inherited by the direct children of the folder. The default is `None`.

```yaml
Type: PropagationFlags
Parameter Sets: PathComplex, SDComplex
Aliases:
Accepted values: None, NoPropagateInherit, InheritOnly

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SecurityDescriptor

Specifies one or more `Security2.FileSystemSecurity2` objects, as returned by `Get-NTFSSecurityDescriptor`, whose access control entries are changed. The change is made in memory only; use `Set-NTFSSecurityDescriptor` to write it to the file system.

A security descriptor contains information about the owner of the object, and the primary group of an object. The security descriptor also contains two access control lists (ACL). The first list is called the discretionary access control lists (DACL), and describes who should have access to an object and what type of access to grant. The second list is called the system access control lists (SACL) and defines what type of auditing to record for an object.

```yaml
Type: FileSystemSecurity2[]
Parameter Sets: SDSimple, SDComplex
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -RemoveSpecific

Indicates that the cmdlet removes only an entry that matches the account, the access rights, the access type, and the inheritance and propagation flags exactly, and leaves all other entries unchanged. Without this switch, the cmdlet takes the specified rights away from the matching entries.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

One or more paths of files or folders, piped by value or by the property `FullName`.

### Security2.FileSystemSecurity2[]

One or more security descriptors returned by `Get-NTFSSecurityDescriptor`.

### Security2.IdentityReference2[]

The accounts whose entries are changed, bound from a property named `Account`, `IdentityReference`, or `ID`. The output of `Get-NTFSAccess` and `Get-NTFSOrphanedAccess` supplies `Account`.

### Security2.FileSystemRights2

The rights to remove, piped by the property `AccessRights` or `FileSystemRights`.

### System.Security.AccessControl.AccessControlType

The type of the entry, piped by the property `AccessType` or `AccessControlType`.

### System.Security.AccessControl.InheritanceFlags

The inheritance flags of the entry, piped by the property `InheritanceFlags` in the `Complex` parameter sets.

### System.Security.AccessControl.PropagationFlags

The propagation flags of the entry, piped by the property `PropagationFlags` in the `Complex` parameter sets.

### Security2.ApplyTo

The scope of the entry, piped by the property `AppliesTo` in the `Simple` parameter sets.

## OUTPUTS

### Security2.FileSystemAccessRule2

With `-PassThru`, the cmdlet writes all access control entries, explicit and inherited, of every item it changed; an item it could not change produces only an error. Before 5.0.0, `-PassThru` also wrote the unchanged entries of such an item. Without `-PassThru` it writes nothing.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

If the ACL of an item cannot be written because access is denied, the cmdlet tries once more after making the current account the owner of the item, and restores the previous owner afterwards. Changing the owner of an item requires the Take Ownership and Restore privileges, so this fallback only succeeds in an elevated session of an account that holds them.

Removing rights from an entry that does not exist is not an error; the cmdlet leaves the ACL unchanged.

In the `Path` parameter sets, the cmdlet writes only the DACL of the item and leaves its owner, its group, and its SACL as they are. Before 5.0.0, it could also write the owner back, which failed with error 1307, "This security ID may not be assigned as the owner of this object", when the account may not assign that owner, such as on some file servers.

An entry with a generic right, such as `GenericAll`, can be removed, for example by piping it from `Get-NTFSAccess`. Windows keeps generic rights in the inherit-only entries of folders. Before 5.0.0, the cmdlet failed for such an entry with the error "The value '269484032' is not valid for this usage of the type FileSystemRights".

Before 5.0.0, the `-RemoveSpecific` switch was missing, although version 4.1 had introduced it.

A path that does not exist produces the non-terminating error `ReadFileError`, and the cmdlet continues with the next path. Before 5.0.0, the cmdlet also wrote a misleading `RemoveAceError` for that path, and with `-PassThru` it stopped with a `NullReferenceException`.

## RELATED LINKS

[Get-NTFSAccess](Get-NTFSAccess.md)

[Add-NTFSAccess](Add-NTFSAccess.md)

[Clear-NTFSAccess](Clear-NTFSAccess.md)

[Get-NTFSOrphanedAccess](Get-NTFSOrphanedAccess.md)

[Disable-NTFSAccessInheritance](Disable-NTFSAccessInheritance.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
