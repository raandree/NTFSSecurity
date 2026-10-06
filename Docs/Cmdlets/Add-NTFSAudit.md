---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Add-NTFSAudit.md
schema: 2.0.0
---

# Add-NTFSAudit

## SYNOPSIS

Adds an audit entry to a file or folder.

## SYNTAX

### PathComplex (Default)
```
Add-NTFSAudit [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AuditFlags <AuditFlags>] [-InheritanceFlags <InheritanceFlags>] [-PropagationFlags <PropagationFlags>]
 [-PassThru] [<CommonParameters>]
```

### PathSimple
```
Add-NTFSAudit [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AuditFlags <AuditFlags>] -AppliesTo <ApplyTo> [-PassThru] [<CommonParameters>]
```

### SDSimple
```
Add-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AuditFlags <AuditFlags>] -AppliesTo <ApplyTo> [-PassThru]
 [<CommonParameters>]
```

### SDComplex
```
Add-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AuditFlags <AuditFlags>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Add-NTFSAudit` cmdlet adds an audit entry to the system access control list (SACL) of a file or folder. Windows then writes an event to the security log when the audited account uses one of the audited access rights on the item. `-AuditFlags Success` audits successful attempts, `-AuditFlags Failure` audits failed attempts, and the default audits both. For what the individual access rights permit, see [Concepts](../Concepts.md).

In the `PathSimple` and `PathComplex` parameter sets the cmdlet reads the security descriptor of every item in `-Path`, adds the entry, and writes the descriptor back right away. In the `SDSimple` and `SDComplex` parameter sets it adds the entry to an in-memory `Security2.FileSystemSecurity2` object that `Get-NTFSSecurityDescriptor` returned; that change only reaches the file system when you pass the object to `Set-NTFSSecurityDescriptor`. The simple sets describe the scope of the entry with the single `-AppliesTo` parameter, the complex sets with `-InheritanceFlags` and `-PropagationFlags`.

`PathComplex` is the default parameter set. A command without `-AppliesTo` uses a `Complex` set, also when it works on a security descriptor. Before 5.0.0, a command that used `-SecurityDescriptor` without `-AppliesTo`, `-InheritanceFlags`, or `-PropagationFlags` failed, because PowerShell couldn't choose between the two `SD` sets.

When you omit them, `-AuditFlags` is `Success, Failure`, `-InheritanceFlags` is `ContainerInherit, ObjectInherit`, `-PropagationFlags` is `None`, and `-AppliesTo` is `ThisFolderSubfoldersAndFiles`, so both the simple and the complex set audit the item, its subfolders, and its files by default. Inheritance applies to folders only: when the item is a file, the cmdlet stores the entry without inheritance and propagation flags.

`-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` binds to it, and the remaining parameters bind by property name. The cmdlet writes no object unless you use `-PassThru`.

## EXAMPLES

### Example 1: Audit failed access to a folder

```PowerShell
PS C:\> Add-NTFSAudit -Path C:\Data -Account 'CONTOSO\Domain Users' -AccessRights FullControl -AuditFlags Failure
```

This command audits every failed attempt of the group `CONTOSO\Domain Users` to use one of the rights contained in `FullControl` on `C:\Data`. Because `-AppliesTo` and the inheritance parameters are omitted, the entry applies to the folder, its subfolders, and its files.

### Example 2: Audit successful deletions in one folder

```PowerShell
PS C:\> Add-NTFSAudit -Path C:\Data -Account Everyone -AccessRights Delete, DeleteSubdirectoriesAndFiles -AuditFlags Success -AppliesTo ThisFolderOnly
```

This command audits successful deletions performed by any account in the folder `C:\Data`. `-AppliesTo ThisFolderOnly` keeps the entry from being inherited by subfolders and files.

### Example 3: Audit several folders from the pipeline

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Directory | Add-NTFSAudit -Account 'BUILTIN\Users' -AccessRights ReadData -AuditFlags Success -PassThru
```

This command adds the same audit entry to every subfolder of `C:\Data` and returns all audit entries of each folder afterwards, including the inherited ones, so that you can check the result.

### Example 4: Add an audit entry to a security descriptor

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Add-NTFSAudit -SecurityDescriptor $sd -Account 'CONTOSO\JohnDoe' -AccessRights Modify -AuditFlags Success, Failure -AppliesTo SubfoldersAndFilesOnly
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

This command adds an audit entry for `CONTOSO\JohnDoe` to the in-memory security descriptor of `C:\Data` and then writes the descriptor back. The entry applies to the subfolders and files of `C:\Data` but not to the folder itself.

## PARAMETERS

### -AccessRights

Specifies the access rights to audit. The value accepts the basic rights such as `Read`, `Write`, `Modify`, and `FullControl` as well as the individual rights such as `Delete` or `WriteAttributes`, and it accepts a comma-separated list that combines them. For the meaning of each right, see [Concepts](../Concepts.md).

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

### -Account

Specifies the accounts whose access to the item is audited. The value is an account name such as `CONTOSO\JohnDoe`, `CONTOSO\Domain Users`, `BUILTIN\Users`, or `Everyone`, or a SID string such as `S-1-5-32-545`. When you pass several accounts, the cmdlet adds one audit entry per account.

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

Specifies the scope of the audit entry with a single value instead of the `-InheritanceFlags` and `-PropagationFlags` pair, in the same wording the Advanced Security Settings dialog uses. `ThisFolderOnly` audits the folder itself, `ThisFolderSubfoldersAndFiles` audits the folder and everything below it, `SubfoldersAndFilesOnly` audits the content but not the folder itself, and the values ending in `OneLevel` limit inheritance to the direct children. Without `-AppliesTo`, the cmdlet uses `-InheritanceFlags` and `-PropagationFlags`, whose defaults describe `ThisFolderSubfoldersAndFiles`.

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

### -AuditFlags

Specifies which access attempts are audited. `Success` audits attempts that succeeded, `Failure` audits attempts that were denied, and `Success, Failure` audits both. The default is `Success, Failure`.

```yaml
Type: AuditFlags
Parameter Sets: (All)
Aliases:
Accepted values: None, Success, Failure

Required: False
Position: Named
Default value: Success, Failure
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -InheritanceFlags

Specifies which child items inherit the audit entry. `ContainerInherit` passes the entry on to child folders, `ObjectInherit` passes it on to child files, and `None` keeps the entry on the item itself. The values can be combined, and the default is `ContainerInherit, ObjectInherit`. Use `-PropagationFlags` to control whether the entry also applies to the item itself and how far it propagates.

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

Indicates that the cmdlet writes the audit entries of the processed item to the pipeline after the change. All entries are returned, explicit and inherited ones, not only the entry that was added. Without this switch the cmdlet returns nothing when the operation succeeds. See the OUTPUTS section for which entries each parameter set returns.

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

Specifies the files or folders the audit entry is added to. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

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

Specifies how the inheritance selected with `-InheritanceFlags` propagates. `None` applies the entry to the item itself and to all inheriting child items, `InheritOnly` applies it to the inheriting child items but not to the item itself, and `NoPropagateInherit` limits inheritance to the direct children. The values `InheritOnly` and `NoPropagateInherit` can be combined, and the default is `None`. The parameter has no effect when `-InheritanceFlags` is `None`.

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

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. The cmdlet adds the audit entry to the system access control list (SACL) of the in-memory object; pass the object to `Set-NTFSSecurityDescriptor` to write the change to the file system.

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

You can pipe paths to this cmdlet, or objects that have a `Path` or `FullName` property, such as the output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2`.

### Security2.FileSystemSecurity2[]

You can pipe the security descriptors that `Get-NTFSSecurityDescriptor` returns to this cmdlet.

### Security2.IdentityReference2[]

The accounts passed to `-Account` are converted to this type from an account name or a SID string. The parameter binds by property name through its own name and its aliases `IdentityReference` and `ID`, so the `Account` property of the entries this module returns supplies the value.

### Security2.FileSystemRights2

The value passed to `-AccessRights` is converted to this type. The parameter binds by property name, so an object with an `AccessRights` or `FileSystemRights` property supplies the value.

### System.Security.AccessControl.AuditFlags

The value passed to `-AuditFlags` is converted to this type and binds by property name.

### System.Security.AccessControl.InheritanceFlags

The value passed to `-InheritanceFlags` is converted to this type and binds by property name in the `PathComplex` and `SDComplex` parameter sets.

### System.Security.AccessControl.PropagationFlags

The value passed to `-PropagationFlags` is converted to this type and binds by property name in the `PathComplex` and `SDComplex` parameter sets.

### Security2.ApplyTo

The value passed to `-AppliesTo` is converted to this type and binds by property name in the `PathSimple` and `SDSimple` parameter sets.

## OUTPUTS

### Security2.FileSystemAuditRule2

Without `-PassThru` the cmdlet writes nothing. With `-PassThru` the cmdlet writes all audit entries of the item or the security descriptor, explicit and inherited ones, as `Security2.FileSystemAuditRule2` objects. Before 5.0.0, the `SecurityDescriptor` sets wrote the access entries of the descriptor instead. An item whose audit entries could not be changed produces only an error; before 5.0.0, `-PassThru` also wrote its unchanged entries.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Writing the SACL requires the Security privilege (`SeSecurityPrivilege`, "Manage auditing and security log"), so run this cmdlet in an elevated session of an account that holds that privilege. Without it, the cmdlet writes a non-terminating `AddAceError` whose message states that a required privilege is not held by the client, and the item is left unchanged.

If the security descriptor cannot be read or written because access is denied, the cmdlet takes ownership of the item, repeats the operation, and restores the previous owner. If the second attempt fails as well, the cmdlet restores the previous owner and writes an error. Before 5.0.0, the account that ran the cmdlet stayed the owner of the item in that case.

In the `Path` parameter sets, the cmdlet reads and writes only the SACL of the item and leaves its owner, its group, and its DACL as they are. Before 5.0.0, it also wrote the owner and the DACL back, which failed with error 1307, "This security ID may not be assigned as the owner of this object", when the account may not assign that owner, such as on some file servers. In an elevated session, it could also store the inherited access entries of the item as explicit entries.

`-Path` or `-SecurityDescriptor`, `-Account`, and `-AccessRights` are positional parameters at positions 1, 2, and 3, like in `Remove-NTFSAudit`. Before 5.0.0, `-Account` and `-AccessRights` were both declared at position 2, so a command that passed them by position failed.

An audit entry alone does not create events. Windows writes the events to the security log only while the "Audit object access" policy, or the corresponding "Audit File System" advanced audit policy, is enabled for success, failure, or both. That policy is a Windows setting and is not managed by this module.

## RELATED LINKS

[Get-NTFSAudit](Get-NTFSAudit.md)

[Remove-NTFSAudit](Remove-NTFSAudit.md)

[Clear-NTFSAudit](Clear-NTFSAudit.md)

[Get-NTFSOrphanedAudit](Get-NTFSOrphanedAudit.md)

[Add-NTFSAccess](Add-NTFSAccess.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
