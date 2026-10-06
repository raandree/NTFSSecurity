---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Add-NTFSAccess.md
schema: 2.0.0
---

# Add-NTFSAccess

## SYNOPSIS

Adds an access control entry (ACE) to a file, a folder, or a security descriptor.

## SYNTAX

### PathComplex (Default)
```
Add-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

### PathSimple
```
Add-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] -AppliesTo <ApplyTo> [-PassThru] [<CommonParameters>]
```

### SDSimple
```
Add-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] -AppliesTo <ApplyTo> [-PassThru]
 [<CommonParameters>]
```

### SDComplex
```
Add-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

Adds an access control entry (ACE) to the discretionary access control list (DACL) of a file or a folder. Every account in `-Account` receives the rights in `-AccessRights`, either as an `Allow` or as a `Deny` entry.

`-AccessRights` accepts the basic rights such as `Read`, `Modify`, and `FullControl` as well as the granular rights such as `CreateFiles` or `WriteAttributes`, and several values can be combined, for example `-AccessRights ReadData, WriteData, Delete`. For the mapping between the values of this module, the rights that Windows displays, and the entries of the advanced security dialog, see [Concepts](../Concepts.md).

The cmdlet has four parameter sets. The `Path` sets read the item from disk and write the changed DACL back immediately, while the `SD` sets change a `Security2.FileSystemSecurity2` object returned by `Get-NTFSSecurityDescriptor` in memory until `Set-NTFSSecurityDescriptor` writes it back. The `Simple` sets take `-AppliesTo`, the `Complex` sets take `-InheritanceFlags` and `-PropagationFlags`; both describe the same ACE flags, and `PathComplex` is the default. A command without `-AppliesTo` uses a `Complex` set, also when it works on a security descriptor. Before 5.0.0, a command that used `-SecurityDescriptor` without `-AppliesTo`, `-InheritanceFlags`, or `-PropagationFlags` failed, because PowerShell couldn't choose between the two `SD` sets.

When `-AccessType`, `-AppliesTo`, `-InheritanceFlags`, and `-PropagationFlags` are omitted, the cmdlet adds an `Allow` ACE that applies to this folder, subfolders, and files, which corresponds to the inheritance flags `ContainerInherit, ObjectInherit` and no propagation flags. An `Allow` ACE always receives the `Synchronize` right in addition to the requested rights, inheritance and propagation flags are ignored on files, and rights for an account that already has an ACE with the same access type and the same flags are merged into that ACE. The cmdlet writes no output unless `-PassThru` is used, and a failure on one item is reported as a non-terminating error while the remaining items are processed.

`-Path` accepts pipeline input by value and by property name through its alias `FullName`, so output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` can be piped in. `-Account`, `-AccessRights`, `-AccessType`, `-InheritanceFlags`, and `-PropagationFlags` bind by property name as well, which lets you pipe `Security2.FileSystemAccessRule2` objects, or rows imported from a CSV file created from them, directly into the cmdlet.

## EXAMPLES

### Example 1: Grant read access to a folder

```PowerShell
PS C:\> Add-NTFSAccess -Path C:\Data -Account 'NT AUTHORITY\Authenticated Users' -AccessRights Read
```

This command grants read access to the built-in group of authenticated users. The ACE applies to the folder, its subfolders, and its files, because `-AppliesTo` defaults to `ThisFolderSubfoldersAndFiles`.

### Example 2: Grant full control and show the resulting ACL

```PowerShell
PS C:\> Add-NTFSAccess -Path C:\Data -Account 'CONTOSO\Domain Admins' -AccessRights FullControl -PassThru
```

This command grants full control to a domain group. `-PassThru` writes all access control entries of the folder, explicit and inherited, after the change.

### Example 3: Deny a right on a single folder

```PowerShell
PS C:\> Add-NTFSAccess -Path C:\Data -Account 'CONTOSO\Domain Users' -AccessRights CreateFiles -AccessType Deny -AppliesTo ThisFolderOnly
```

This command denies the creation of files in `C:\Data` to the members of a domain group. The ACE is not inherited by subfolders or files, because `-AppliesTo` is set to `ThisFolderOnly`.

### Example 4: Restore explicit permissions from a CSV backup

```PowerShell
PS C:\> Import-Csv -Path C:\Backup\acl.csv | Add-NTFSAccess
```

This command restores the access control entries that `Get-NTFSAccess` exported to a CSV file. The columns `FullName`, `Account`, `AccessRights`, `AccessControlType`, `InheritanceFlags`, and `PropagationFlags` bind to the matching parameters, so every row recreates the ACE it was exported from.

## PARAMETERS

### -AccessRights

Specifies the rights the ACE grants or denies. The parameter accepts basic rights such as `Read`, `ReadAndExecute`, `Modify`, and `FullControl`, granular rights such as `CreateFiles`, `Traverse`, or `WriteAttributes`, and any combination of them. An `Allow` ACE always receives `Synchronize` in addition to the specified rights. For how the values relate to the Windows security dialog, see [Concepts](../Concepts.md).

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

Specifies whether the ACE allows or denies the rights in `-AccessRights`. The default is `Allow`. A `Deny` ACE takes precedence over `Allow` ACEs that grant the same rights.

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

Specifies one or more accounts or groups the ACE applies to. An account can be given as a name such as `CONTOSO\JohnDoe`, `BUILTIN\Users`, or `NT AUTHORITY\SYSTEM`, or as a SID string such as `S-1-5-32-544`. A name that cannot be translated into a SID raises an error, a SID that cannot be translated into a name is accepted.

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

Specifies the scope of the ACE in the wording of the Windows security dialog, for example `ThisFolderOnly`, `ThisFolderAndSubfolders`, or `SubfoldersAndFilesOnly`. Without `-AppliesTo`, the cmdlet uses `-InheritanceFlags` and `-PropagationFlags`, whose defaults describe `ThisFolderSubfoldersAndFiles`. The cmdlet translates the value into the equivalent inheritance and propagation flags, so this parameter and the pair `-InheritanceFlags` and `-PropagationFlags` are two ways to describe the same ACE. The values ending in `OneLevel` limit inheritance to the direct children of the folder.

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

Specifies which kind of child objects inherit the ACE. `ContainerInherit` passes the ACE on to child folders, `ObjectInherit` passes it on to child files, and `None` keeps the ACE on the item itself. The default is `ContainerInherit, ObjectInherit`. Inheritance flags have no effect on files, where the ACE is always created with `None`.

For details about the flags, see the .NET documentation of the [InheritanceFlags Enum](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.inheritanceflags).

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

Specifies the path of one or more files or folders the ACE is added to. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its alias `FullName`.

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

Specifies how the ACE is propagated to child objects. `None` propagates the ACE to all levels that the inheritance flags allow, `InheritOnly` keeps the ACE from applying to the item it is defined on, and `NoPropagateInherit` limits inheritance to the direct children of the folder. The default is `None`, and propagation flags only have an effect in combination with `-InheritanceFlags`.

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

Specifies one or more `Security2.FileSystemSecurity2` objects, as returned by `Get-NTFSSecurityDescriptor`, that the ACE is added to. The change is made in memory only; use `Set-NTFSSecurityDescriptor` to write it to the file system.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

One or more paths of files or folders, piped by value or by the property `FullName`.

### Security2.FileSystemSecurity2[]

One or more security descriptors returned by `Get-NTFSSecurityDescriptor`.

### Security2.IdentityReference2[]

The accounts the ACE is created for, bound from a property named `Account`, `IdentityReference`, or `ID`. The output of `Get-NTFSAccess` supplies `Account`.

### Security2.FileSystemRights2

The rights of the ACE, piped by the property `AccessRights` or `FileSystemRights`.

### System.Security.AccessControl.AccessControlType

The type of the ACE, piped by the property `AccessType` or `AccessControlType`.

### System.Security.AccessControl.InheritanceFlags

The inheritance flags of the ACE, piped by the property `InheritanceFlags` in the `Complex` parameter sets.

### System.Security.AccessControl.PropagationFlags

The propagation flags of the ACE, piped by the property `PropagationFlags` in the `Complex` parameter sets.

### Security2.ApplyTo

The scope of the ACE, piped by the property `AppliesTo` in the `Simple` parameter sets.

## OUTPUTS

### Security2.FileSystemAccessRule2

With `-PassThru`, the cmdlet writes all access control entries, explicit and inherited, of every item it changed; an item it could not change produces only an error. Before 5.0.0, `-PassThru` also wrote the unchanged entries of such an item. Without `-PassThru` it writes nothing.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

If the ACL of an item cannot be written because access is denied, the cmdlet tries once more after making the current account the owner of the item, and restores the previous owner afterwards. Changing the owner of an item requires the Take Ownership and Restore privileges, so this fallback only succeeds in an elevated session of an account that holds them.

In the `Path` parameter sets, the cmdlet reads and writes only the DACL of the item and leaves its owner, its group, and its SACL as they are. Before 5.0.0, it also wrote the owner back, which failed with error 1307, "This security ID may not be assigned as the owner of this object", when the account may not assign that owner, such as on some file servers. In an elevated session, it could also store the inherited entries of the item as explicit entries.

## RELATED LINKS

[Get-NTFSAccess](Get-NTFSAccess.md)

[Remove-NTFSAccess](Remove-NTFSAccess.md)

[Clear-NTFSAccess](Clear-NTFSAccess.md)

[Get-NTFSEffectiveAccess](Get-NTFSEffectiveAccess.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
