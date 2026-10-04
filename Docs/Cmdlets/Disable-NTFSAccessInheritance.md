---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Disable-NTFSAccessInheritance.md
schema: 2.0.0
---

# Disable-NTFSAccessInheritance

## SYNOPSIS

Blocks the inheritance of access rules on a file or folder.

## SYNTAX

### Path (Default)
```
Disable-NTFSAccessInheritance [[-Path] <String[]>] [-RemoveInheritedAccessRules] [-PassThru]
 [<CommonParameters>]
```

### SecurityDescriptor
```
Disable-NTFSAccessInheritance [-SecurityDescriptor] <FileSystemSecurity2[]> [-RemoveInheritedAccessRules]
 [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Disable-NTFSAccessInheritance` cmdlet protects the discretionary access control list (DACL) of a file or folder, so that the access rules of the parent folder no longer apply to the item. From then on, only the access rules stored in the item's own DACL grant or deny access to it.

By default, the rules that the item currently inherits are copied into its DACL before inheritance is blocked. The effective permissions therefore stay the same, and the copies become explicit rules that you can change or remove individually. The `-RemoveInheritedAccessRules` switch discards the inherited rules instead of copying them. If the item has no explicit rules of its own, that leaves an empty DACL, which denies access to everyone except the owner, so check the item with `Get-NTFSAccess` before you use the switch.

In the `Path` parameter set the cmdlet reads the access section of the item's security descriptor, changes it, and writes it back to disk immediately. In the `SecurityDescriptor` parameter set it changes the `Security2.FileSystemSecurity2` object in memory only; nothing reaches the file system until you pass that object to `Set-NTFSSecurityDescriptor`.

`-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, `Get-Item2`, and `Get-NTFSInheritance` binds to it. Relative paths are resolved against the current location. The cmdlet affects only the access rules; use `Disable-NTFSAuditInheritance` for the audit rules.

## EXAMPLES

### Example 1: Block inheritance and keep the current permissions

```PowerShell
PS C:\> Disable-NTFSAccessInheritance -Path C:\Data\Projects
```

This command protects the DACL of `C:\Data\Projects` and copies the access rules that the folder inherited from `C:\Data` into its own DACL. The effective permissions do not change, but later permission changes on `C:\Data` no longer reach the folder.

### Example 2: Block inheritance and discard the inherited rules

```PowerShell
PS C:\> Disable-NTFSAccessInheritance -Path C:\Data\Projects -RemoveInheritedAccessRules -PassThru
```

This command protects the DACL and removes the inherited access rules instead of copying them, which leaves only the rules that were already explicit on the folder. `-PassThru` returns the resulting state, in which `AccessInheritanceEnabled` is `$false`.

### Example 3: Block inheritance on every subfolder

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Directory | Disable-NTFSAccessInheritance -PassThru
```

This command pipes every subfolder of `C:\Data` to the cmdlet, which binds the `FullName` property of each item to `-Path`. Each folder keeps its current permissions as explicit rules, and `-PassThru` reports the new state of each of them.

### Example 4: Change a security descriptor in memory

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data\Projects
PS C:\> Disable-NTFSAccessInheritance -SecurityDescriptor $sd
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

The first two commands read the security descriptor and protect its DACL in memory, which does not change anything on disk. The third command writes the descriptor back and applies the change.

## PARAMETERS

### -PassThru

Indicates that the cmdlet returns a `Security2.FileSystemInheritanceInfo` object for each processed item. By default, this cmdlet produces no output. The state is read after the change was attempted, so an object is also written when the change failed.

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

Specifies the path of one or more files or folders whose access inheritance is blocked. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, `Get-Item2`, and `Get-NTFSInheritance` binds to it. The cmdlet does nothing when no path is supplied, either directly or from the pipeline.

```yaml
Type: String[]
Parameter Sets: Path
Aliases: FullName

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -RemoveInheritedAccessRules

Indicates that the access rules the item currently inherits are discarded. By default, when the switch is omitted, those rules are copied into the item's own DACL as explicit rules and the effective permissions stay the same. With the switch, the item keeps only the access rules that were already explicit on it, which can be none at all.

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

### -SecurityDescriptor

The SecurityDescriptor parameter allows passing an security descriptor or an array or security descriptors.

A security descriptor contains information about the owner of the object, and the primary group of an object. The security descriptor also contains two access control lists (ACL). The first list is called the discretionary access control lists (DACL), and describes who should have access to an object and what type of access to grant. The second list is called the system access control lists (SACL) and defines what type of auditing to record for an object.

This cmdlet changes the descriptor in memory only. Pass the object to `Set-NTFSSecurityDescriptor` to write the change to the file system.

```yaml
Type: FileSystemSecurity2[]
Parameter Sets: SecurityDescriptor
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

You can pipe one or more path strings, or objects that have a `FullName` property such as the output of `Get-ChildItem2`, `Get-Item2`, and `Get-ChildItem`, to this cmdlet.

### Security2.FileSystemSecurity2[]

You can pipe the security descriptors that `Get-NTFSSecurityDescriptor` returns to this cmdlet.

## OUTPUTS

### Security2.FileSystemInheritanceInfo

By default this cmdlet returns no output. With `-PassThru` it writes one `Security2.FileSystemInheritanceInfo` object per item, which reports the `AccessInheritanceEnabled` and `AuditInheritanceEnabled` state after the change.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Blocking access inheritance requires permission to change the DACL of the item, which the owner of an item always has. If the descriptor cannot be opened, the cmdlet takes ownership of the item, applies the change, and sets the previous owner back. That fallback only succeeds when the account can take ownership of the item and restore the original owner; otherwise the cmdlet writes an error and continues with the next item.

A path that does not exist produces a non-terminating error and the cmdlet continues with the remaining paths.

Before 5.0.0, the cmdlet enabled the privileges even when `EnablePrivileges` was `$false`, and left them enabled.

Before 5.0.0, `-PassThru` returned the unchanged state of an item also when the change failed, and stopped the command when the item could not be read.

## RELATED LINKS

[Enable-NTFSAccessInheritance](Enable-NTFSAccessInheritance.md)

[Get-NTFSInheritance](Get-NTFSInheritance.md)

[Set-NTFSInheritance](Set-NTFSInheritance.md)

[Disable-NTFSAuditInheritance](Disable-NTFSAuditInheritance.md)

[Get-NTFSAccess](Get-NTFSAccess.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
