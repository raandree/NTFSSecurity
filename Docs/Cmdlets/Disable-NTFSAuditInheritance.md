---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Disable-NTFSAuditInheritance.md
schema: 2.0.0
---

# Disable-NTFSAuditInheritance

## SYNOPSIS

Blocks the inheritance of audit rules on a file or folder.

## SYNTAX

### Path (Default)
```
Disable-NTFSAuditInheritance [[-Path] <String[]>] [-RemoveInheritedAccessRules] [-PassThru]
 [<CommonParameters>]
```

### SecurityDescriptor
```
Disable-NTFSAuditInheritance [-SecurityDescriptor] <FileSystemSecurity2[]> [-RemoveInheritedAccessRules]
 [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Disable-NTFSAuditInheritance` cmdlet protects the system access control list (SACL) of a file or folder, so that the audit rules of the parent folder no longer apply to the item. From then on, only the audit rules stored in the item's own SACL decide which access attempts are written to the security event log.

By default, the audit rules that the item currently inherits are copied into its SACL before inheritance is blocked, so the auditing behavior stays the same. The `-RemoveInheritedAccessRules` switch discards the inherited audit rules instead of copying them, which leaves only the audit rules that were already explicit on the item. Despite its name, the switch acts on audit rules, not on access rules.

In the `Path` parameter set the cmdlet reads the audit section of the item's security descriptor, changes it, and writes it back to disk immediately. In the `SecurityDescriptor` parameter set it changes the `Security2.FileSystemSecurity2` object in memory only; nothing reaches the file system until you pass that object to `Set-NTFSSecurityDescriptor`.

Reading and writing the audit section requires the Security privilege, so run this cmdlet in an elevated session. `-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, `Get-Item2`, and `Get-NTFSInheritance` binds to it. The cmdlet affects only the audit rules; use `Disable-NTFSAccessInheritance` for the access rules.

## EXAMPLES

### Example 1: Block audit inheritance and keep the current auditing

```PowerShell
PS C:\> Disable-NTFSAuditInheritance -Path C:\Data\Projects
```

This command protects the SACL of `C:\Data\Projects` and copies the audit rules that the folder inherited from `C:\Data` into its own SACL. Auditing continues to work the same way, but later changes to the audit rules of `C:\Data` no longer reach the folder.

### Example 2: Block audit inheritance and discard the inherited rules

```PowerShell
PS C:\> Disable-NTFSAuditInheritance -Path C:\Data\Projects -RemoveInheritedAccessRules -PassThru
```

This command protects the SACL and removes the inherited audit rules instead of copying them, so the folder is audited only by the rules that were already explicit on it. `-PassThru` returns the resulting state, in which `AuditInheritanceEnabled` is `$false`.

### Example 3: Block audit inheritance on every subfolder

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Directory | Disable-NTFSAuditInheritance
```

This command pipes every subfolder of `C:\Data` to the cmdlet, which binds the `FullName` property of each item to `-Path`. Each folder keeps its current audit rules as explicit rules.

### Example 4: Change a security descriptor in memory

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data\Projects
PS C:\> Disable-NTFSAuditInheritance -SecurityDescriptor $sd
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

The first two commands read the security descriptor and protect its SACL in memory, which does not change anything on disk. The third command writes the descriptor back and applies the change.

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

Specifies the path of one or more files or folders whose audit inheritance is blocked. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, `Get-Item2`, and `Get-NTFSInheritance` binds to it. The cmdlet does nothing when no path is supplied, either directly or from the pipeline.

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

Indicates that the audit rules the item currently inherits are discarded. Despite its name, the switch acts on the audit rules in the SACL, not on access rules. By default, when the switch is omitted, the inherited audit rules are copied into the item's own SACL as explicit rules and auditing continues unchanged.

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

### System.Object

By default this cmdlet returns no output. With `-PassThru` it writes one `Security2.FileSystemInheritanceInfo` object per item, which reports the `AccessInheritanceEnabled` and `AuditInheritanceEnabled` state after the change.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

The audit section of a security descriptor can only be read and written with the Security privilege (`SeSecurityPrivilege`), which an account can only use in an elevated session. Without it, the cmdlet writes a non-terminating error that reports Windows error 1314, "A required privilege is not held by the client", and the audit rules of the item stay unchanged.

If the descriptor cannot be opened because the account has no permission to the item, the cmdlet takes ownership of the item, applies the change, and sets the previous owner back. That fallback only succeeds when the account can take ownership of the item and restore the original owner; a missing Security privilege is not an access problem and is not repaired by it.

A path that does not exist produces a non-terminating error and the cmdlet continues with the remaining paths.

Before 5.0.0, the cmdlet enabled the privileges even when `EnablePrivileges` was `$false`, and left them enabled.

Before 5.0.0, `-PassThru` returned the unchanged state of an item also when the change failed, and stopped the command when the item could not be read.

## RELATED LINKS

[Enable-NTFSAuditInheritance](Enable-NTFSAuditInheritance.md)

[Get-NTFSInheritance](Get-NTFSInheritance.md)

[Set-NTFSInheritance](Set-NTFSInheritance.md)

[Disable-NTFSAccessInheritance](Disable-NTFSAccessInheritance.md)

[Get-NTFSAudit](Get-NTFSAudit.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
