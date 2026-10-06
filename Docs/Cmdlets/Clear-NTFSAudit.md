---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Clear-NTFSAudit.md
schema: 2.0.0
---

# Clear-NTFSAudit

## SYNOPSIS

Removes all explicit audit entries from a file or folder.

## SYNTAX

### Path (Default)
```
Clear-NTFSAudit [-Path] <String[]> [-DisableInheritance] [<CommonParameters>]
```

### SD
```
Clear-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-DisableInheritance] [<CommonParameters>]
```

## DESCRIPTION

The `Clear-NTFSAudit` cmdlet removes every audit entry that is set on a file or folder itself from its system access control list (SACL). Entries that the item inherits from a parent folder are left alone, because they are stored on that parent. Add `-DisableInheritance` to protect the item from its parent and to drop the inherited entries as well, which leaves the item without any auditing.

In the `Path` parameter set the cmdlet reads the security descriptor of every item in `-Path`, removes the entries, and writes the descriptor back right away. Relative paths are resolved against the current location, and the parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` binds to it. In the `SD` parameter set the cmdlet changes an in-memory `Security2.FileSystemSecurity2` object that `Get-NTFSSecurityDescriptor` returned, and the change reaches the file system only when you pass the object to `Set-NTFSSecurityDescriptor`.

To remove a single audit entry instead of all of them, use `Remove-NTFSAudit`. The cmdlet writes no object; use `Get-NTFSAudit` to check the result.

## EXAMPLES

### Example 1: Remove the explicit audit entries of a folder

```PowerShell
PS C:\> Clear-NTFSAudit -Path C:\Data
```

This command removes every audit entry that is set on `C:\Data` itself. The entries that the folder inherits from its parent stay in place.

### Example 2: Remove all auditing from a folder

```PowerShell
PS C:\> Clear-NTFSAudit -Path C:\Data -DisableInheritance
```

This command removes the explicit audit entries of `C:\Data` and then stops the folder from inheriting audit entries, discarding the inherited entries instead of copying them to the folder.

### Example 3: Clear the audit entries of a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Clear-NTFSAudit
```

This command pipes every item below `C:\Data` into `Clear-NTFSAudit` and removes the audit entries that are set on those items themselves.

### Example 4: Clear the audit entries of a security descriptor

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Clear-NTFSAudit -SecurityDescriptor $sd
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

This command removes the explicit audit entries from the in-memory security descriptor of `C:\Data` and then writes the descriptor back to the file system.

## PARAMETERS

### -DisableInheritance

Indicates that the item no longer inherits audit entries from its parent folder. The inherited entries are discarded rather than copied to the item, so the item is left with no audit entries at all. Without this switch the item keeps inheriting audit entries from its parent.

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

Specifies the files or folders whose audit entries are removed. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

```yaml
Type: String[]
Parameter Sets: Path
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -SecurityDescriptor

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. The cmdlet removes the explicit audit entries from the system access control list (SACL) of the in-memory object; pass the object to `Set-NTFSSecurityDescriptor` to write the change to the file system.

```yaml
Type: FileSystemSecurity2[]
Parameter Sets: SD
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

## OUTPUTS

### System.Object

This cmdlet writes nothing to the pipeline. Use `Get-NTFSAudit` to check which audit entries an item has after the operation.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Reading and writing the SACL requires the Security privilege (`SeSecurityPrivilege`, "Manage auditing and security log"), so run this cmdlet in an elevated session of an account that holds that privilege. Without it, the cmdlet writes a non-terminating `ClearAclError` whose message states that a required privilege is not held by the client, and the item is left unchanged. Before 5.0.0, the cmdlet read the security descriptor without its SACL in that situation, found no audit entries to remove, and finished without an error although nothing was changed.

In the `Path` parameter set, the cmdlet reads and writes only the SACL of the item and leaves its owner, its group, and its DACL as they are; it writes nothing for an item without a SACL. Before 5.0.0, it also wrote the owner back, which failed with error 1307, "This security ID may not be assigned as the owner of this object", when the account may not assign that owner, such as on some file servers.

A security descriptor that was read without the Security privilege doesn't contain the audit entries. With such a descriptor, the cmdlet writes a `ReadSecurityError` and changes nothing, like `Get-NTFSAudit`; before 5.0.0, it wrote no error.

If the security descriptor cannot be read or written because access is denied, the cmdlet takes ownership of the item, repeats the operation, and restores the previous owner. If the second attempt fails as well, the cmdlet restores the previous owner and writes an error. Before 5.0.0, the account that ran the cmdlet stayed the owner of the item in that case.

## RELATED LINKS

[Get-NTFSAudit](Get-NTFSAudit.md)

[Add-NTFSAudit](Add-NTFSAudit.md)

[Remove-NTFSAudit](Remove-NTFSAudit.md)

[Disable-NTFSAuditInheritance](Disable-NTFSAuditInheritance.md)

[Enable-NTFSAuditInheritance](Enable-NTFSAuditInheritance.md)

[Clear-NTFSAccess](Clear-NTFSAccess.md)
