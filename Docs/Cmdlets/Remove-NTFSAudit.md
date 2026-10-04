---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Remove-NTFSAudit.md
schema: 2.0.0
---

# Remove-NTFSAudit

## SYNOPSIS

Removes an audit entry from a file or folder.

## SYNTAX

### PathComplex (Default)
```
Remove-NTFSAudit [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AuditFlags <AuditFlags>] [-InheritanceFlags <InheritanceFlags>] [-PropagationFlags <PropagationFlags>]
 [-PassThru] [<CommonParameters>]
```

### PathSimple
```
Remove-NTFSAudit [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AuditFlags <AuditFlags>] -AppliesTo <ApplyTo> [-PassThru] [<CommonParameters>]
```

### SDSimple
```
Remove-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AuditFlags <AuditFlags>] -AppliesTo <ApplyTo> [-PassThru]
 [<CommonParameters>]
```

### SDComplex
```
Remove-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AuditFlags <AuditFlags>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Remove-NTFSAudit` cmdlet removes an audit entry from the system access control list (SACL) of a file or folder. The cmdlet builds an audit entry from `-Account`, `-AccessRights`, `-AuditFlags`, and the inheritance and propagation flags, and removes that entry from the SACL. The audit entries of the account are matched by their inheritance and propagation flags, and the requested access rights and audit flags are then taken away from them: an entry that audits further rights keeps those rights and disappears only when nothing is left. To remove an entry completely, pass the same values that `Get-NTFSAudit` reports for it.

Because the inheritance and propagation flags take part in the match, they must describe the entry you want to remove. `-AppliesTo ThisFolderOnly` removes an entry that is not inherited by child items, which is also the shape of every audit entry on a file, while the default of the complex parameter sets removes an entry that applies to the folder, its subfolders, and its files. An entry that an item inherits from a parent folder is stored on that parent, so remove it there, or use `Clear-NTFSAudit` with `-DisableInheritance` to drop the inherited entries on the item.

In the `PathSimple` and `PathComplex` parameter sets the cmdlet reads the security descriptor of every item in `-Path` and writes it back right away. In the `SDSimple` and `SDComplex` parameter sets it changes an in-memory `Security2.FileSystemSecurity2` object that `Get-NTFSSecurityDescriptor` returned, and the change reaches the file system only when you pass the object to `Set-NTFSSecurityDescriptor`. `PathComplex` is the default parameter set. A command without `-AppliesTo` uses a `Complex` set, also when it works on a security descriptor. Before 5.0.0, a command that used `-SecurityDescriptor` without `-AppliesTo`, `-InheritanceFlags`, or `-PropagationFlags` failed, because PowerShell couldn't choose between the two `SD` sets.

When you omit them, `-AuditFlags` is `Success, Failure`, `-InheritanceFlags` is `ContainerInherit, ObjectInherit`, `-PropagationFlags` is `None`. All parameters bind by property name, and `-Path` also binds by value and through its `FullName` alias, so you can pipe the output of `Get-NTFSAudit`, `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` into the cmdlet. The cmdlet writes no object unless you use `-PassThru`.

## EXAMPLES

### Example 1: Remove an audit entry from a folder

```PowerShell
PS C:\> Remove-NTFSAudit -Path C:\Data -Account 'CONTOSO\Domain Users' -AccessRights FullControl -AuditFlags Failure
```

This command removes the entry that audits failed access of `CONTOSO\Domain Users` to `C:\Data`, its subfolders, and its files.

### Example 2: Remove an audit entry that applies to one folder

```PowerShell
PS C:\> Remove-NTFSAudit -Path C:\Data -Account Everyone -AccessRights Delete, DeleteSubdirectoriesAndFiles -AuditFlags Success -AppliesTo ThisFolderOnly
```

This command removes the entry that audits successful deletions in the folder `C:\Data` itself. Use the same `-AppliesTo` value to remove an audit entry from a file, because audit entries on files are never inherited by child items.

### Example 3: Remove the audit entries of one account

```PowerShell
PS C:\> Get-NTFSAudit -Path C:\Data -Account 'CONTOSO\JohnDoe' -ExcludeInherited | Remove-NTFSAudit
```

This command reads the explicit audit entries of `CONTOSO\JohnDoe` and pipes them back into `Remove-NTFSAudit`, which removes each of them from the item it came from. The path, account, access rights, audit flags, and inheritance flags all bind from the properties of the piped entries.

### Example 4: Remove an audit entry from a security descriptor

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Remove-NTFSAudit -SecurityDescriptor $sd -Account 'CONTOSO\JohnDoe' -AccessRights Modify -AuditFlags Success, Failure -AppliesTo SubfoldersAndFilesOnly
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

This command removes the entry from the in-memory security descriptor of `C:\Data` and then writes the descriptor back to the file system.

## PARAMETERS

### -AccessRights

Specifies the audited access rights to remove. The value accepts the basic rights such as `Read`, `Write`, `Modify`, and `FullControl` as well as the individual rights such as `Delete` or `WriteAttributes`, and it accepts a comma-separated list that combines them. Rights that an existing entry audits beyond the ones you specify stay in place. For the meaning of each right, see [Concepts](../Concepts.md).

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

Specifies the accounts whose audit entries are removed. The value is an account name such as `CONTOSO\JohnDoe`, `CONTOSO\Domain Users`, `BUILTIN\Users`, or `Everyone`, or a SID string such as `S-1-5-32-545`. A SID is the only way to address an entry whose account no longer resolves to a name. When you pass several accounts, the cmdlet removes one entry per account.

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

Specifies the scope of the audit entry to remove with a single value instead of the `-InheritanceFlags` and `-PropagationFlags` pair, in the same wording the Advanced Security Settings dialog uses. The value must describe the entry as `Get-NTFSAudit` reports it, otherwise nothing is removed. Without `-AppliesTo`, the cmdlet uses `-InheritanceFlags` and `-PropagationFlags`, whose defaults describe `ThisFolderSubfoldersAndFiles`.

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

Specifies which audited access attempts are removed from the entry. `Success` removes the auditing of successful attempts, `Failure` removes the auditing of denied attempts, and `Success, Failure` removes both. An entry that audits the flag you did not specify stays in place with that flag. The default is `Success, Failure`.

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

Specifies the inheritance flags of the audit entry to remove. `ContainerInherit` addresses an entry that child folders inherit, `ObjectInherit` an entry that child files inherit, and `None` an entry that stays on the item itself. The values can be combined, and the default is `ContainerInherit, ObjectInherit`. The flags must match the entry as `Get-NTFSAudit` reports it, otherwise nothing is removed.

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

Indicates that the cmdlet writes the access control entries of the processed item or descriptor to the pipeline after the change. All entries are returned, explicit and inherited ones, not only the entry that was removed. Without this switch the cmdlet returns nothing when the operation succeeds. See the OUTPUTS section for which entries each parameter set returns.

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

Specifies the files or folders the audit entry is removed from. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

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

Specifies the propagation flags of the audit entry to remove. `None` addresses an entry that applies to the item itself and to all inheriting child items, `InheritOnly` an entry that applies to the child items only, and `NoPropagateInherit` an entry whose inheritance stops at the direct children. The values `InheritOnly` and `NoPropagateInherit` can be combined, and the default is `None`.

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

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. The cmdlet removes the audit entry from the system access control list (SACL) of the in-memory object; pass the object to `Set-NTFSSecurityDescriptor` to write the change to the file system.

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

You can pipe paths to this cmdlet, or objects that have a `Path` or `FullName` property, such as the output of `Get-NTFSAudit`, `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2`.

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

Without `-PassThru` the cmdlet writes nothing. With `-PassThru` the cmdlet writes all audit entries of the item or the security descriptor, explicit and inherited ones, as `Security2.FileSystemAuditRule2` objects. Before 5.0.0, the `Path` sets wrote the access entries of the item instead.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Reading and writing the SACL requires the Security privilege (`SeSecurityPrivilege`, "Manage auditing and security log"), so run this cmdlet in an elevated session of an account that holds that privilege. Without it, the cmdlet writes a non-terminating `RemoveAceError` whose message states that a required privilege is not held by the client, and the item is left unchanged.

If the security descriptor cannot be read or written because access is denied, the cmdlet takes ownership of the item, repeats the operation, and restores the previous owner. If the second attempt fails as well, the cmdlet writes an error, and the ownership change is not rolled back.

The cmdlet reports no error when no entry matches the supplied values. Compare the result with `Get-NTFSAudit` to confirm that the entry is gone.

## RELATED LINKS

[Get-NTFSAudit](Get-NTFSAudit.md)

[Add-NTFSAudit](Add-NTFSAudit.md)

[Clear-NTFSAudit](Clear-NTFSAudit.md)

[Get-NTFSOrphanedAudit](Get-NTFSOrphanedAudit.md)

[Remove-NTFSAccess](Remove-NTFSAccess.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
