---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Set-NTFSInheritance.md
schema: 2.0.0
---

# Set-NTFSInheritance

## SYNOPSIS

Sets the inheritance of the access rules and the audit rules of a file or folder.

## SYNTAX

### Path (Default)
```
Set-NTFSInheritance [[-Path] <String[]>] [-AccessInheritanceEnabled <Boolean>]
 [-AuditInheritanceEnabled <Boolean>] [-PassThru] [<CommonParameters>]
```

### SecurityDescriptor
```
Set-NTFSInheritance [-SecurityDescriptor] <FileSystemSecurity2[]> [-AccessInheritanceEnabled <Boolean>]
 [-AuditInheritanceEnabled <Boolean>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Set-NTFSInheritance` cmdlet turns the inheritance of access rules and audit rules on or off in a single call. It reads the current state of the item first and changes a section only when the requested value differs from the current one, which makes the cmdlet suitable for repeatedly applying a desired state to a folder tree.

The cmdlet performs the same operations as `Enable-NTFSAccessInheritance`, `Disable-NTFSAccessInheritance`, `Enable-NTFSAuditInheritance`, and `Disable-NTFSAuditInheritance`, but it does not expose their switches; it uses their defaults instead. `-AccessInheritanceEnabled $false` copies the inherited access rules into the item's own DACL, `-AccessInheritanceEnabled $true` keeps the explicit access rules, `-AuditInheritanceEnabled $false` copies the inherited audit rules into the item's own SACL, and `-AuditInheritanceEnabled $true` keeps the explicit audit rules. To remove the rules instead, use `Disable-NTFSAccessInheritance -RemoveInheritedAccessRules` or `Enable-NTFSAuditInheritance -RemoveExplicitAuditRules`. Before 5.0.0, `-AccessInheritanceEnabled $false` discarded the inherited access rules, and `-AuditInheritanceEnabled $true` removed the explicit audit rules. Review scripts that used `-AccessInheritanceEnabled $false` to drop the inherited access rules: they now keep them, which leaves broader access in place; `Disable-NTFSAccessInheritance -RemoveInheritedAccessRules` gives the old result.

Omit `-AccessInheritanceEnabled` or `-AuditInheritanceEnabled` to leave that section unchanged. Changing the audit section requires the Security privilege and therefore an elevated session.

In the `Path` parameter set the cmdlet writes each changed section back to disk immediately. In the `SecurityDescriptor` parameter set it changes the `Security2.FileSystemSecurity2` object in memory only; nothing reaches the file system until you pass that object to `Set-NTFSSecurityDescriptor`. `-Path`, `-AccessInheritanceEnabled`, and `-AuditInheritanceEnabled` all accept pipeline input by property name, so a `Security2.FileSystemInheritanceInfo` object from `Get-NTFSInheritance` binds to all three at once.

## EXAMPLES

### Example 1: Block inheritance of both sections

```PowerShell
PS C:\> Set-NTFSInheritance -Path C:\Data\Projects -AccessInheritanceEnabled $false -AuditInheritanceEnabled $false
```

This command protects the DACL and the SACL of `C:\Data\Projects`. The inherited access and audit rules are copied into the folder's DACL and SACL, so the effective permissions and the auditing stay the same. Changing the audit section requires an elevated session.

### Example 2: Restore inheritance of both sections

```PowerShell
PS C:\> Set-NTFSInheritance -Path C:\Data\Projects -AccessInheritanceEnabled $true -AuditInheritanceEnabled $true -PassThru
```

This command lets the folder inherit from `C:\Data` again. The explicit access and audit rules are kept, and `-PassThru` returns the resulting state.

### Example 3: Save a state and apply it again

```PowerShell
PS C:\> $state = Get-NTFSInheritance -Path C:\Data\Projects
PS C:\> Disable-NTFSAccessInheritance -Path C:\Data\Projects
PS C:\> $state | Set-NTFSInheritance
```

The first command records the inheritance state of the folder. After the second command changed it, the third command pipes the recorded object back and restores both values, because `FullName`, `AccessInheritanceEnabled`, and `AuditInheritanceEnabled` bind by property name.

### Example 4: Change a security descriptor in memory

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data\Projects
PS C:\> Set-NTFSInheritance -SecurityDescriptor $sd -AccessInheritanceEnabled $false -AuditInheritanceEnabled $false
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

The first two commands read the security descriptor and change its inheritance in memory, which does not change anything on disk. The third command writes the descriptor back and applies the change.

## PARAMETERS

### -AccessInheritanceEnabled

Specifies whether the item inherits access rules from its parent folder. `$true` removes the protection from the DACL and keeps the access rules that are stored directly on the item; `$false` protects the DACL and copies the rules the item currently inherits into it, so the effective permissions stay the same. Before 5.0.0, `$false` discarded the inherited rules. The section is left untouched when the requested value already matches the current state. When you omit the parameter, the access section is left unchanged.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AuditInheritanceEnabled

Specifies whether the item inherits audit rules from its parent folder. `$true` removes the protection from the SACL and keeps the audit rules that are stored directly on the item (before 5.0.0, it removed them); `$false` protects the SACL and copies the inherited audit rules into it. The section is left untouched when the requested value already matches the current state. When you omit the parameter, the audit section is left unchanged. Reading and writing the audit section requires the Security privilege and therefore an elevated session.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PassThru

Indicates that the cmdlet returns a `Security2.FileSystemInheritanceInfo` object for each processed item. By default, this cmdlet produces no output. The state is read after the changes were attempted, so an object is also written when a change failed.

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

Specifies the path of one or more files or folders whose inheritance is set. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, `Get-Item2`, and `Get-NTFSInheritance` binds to it. The cmdlet does nothing when no path is supplied, either directly or from the pipeline.

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

### System.Nullable`1[[System.Boolean, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]

You can supply `-AccessInheritanceEnabled` and `-AuditInheritanceEnabled` through a pipeline object that has properties of those names, such as the `Security2.FileSystemInheritanceInfo` objects that `Get-NTFSInheritance` returns.

## OUTPUTS

### Security2.FileSystemInheritanceInfo

By default this cmdlet returns no output. With `-PassThru` it writes one `Security2.FileSystemInheritanceInfo` object per item, which reports the `AccessInheritanceEnabled` and `AuditInheritanceEnabled` state after the change.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

The audit section of a security descriptor can only be read and written with the Security privilege (`SeSecurityPrivilege`), which an account can only use in an elevated session. Without it, a requested change of `-AuditInheritanceEnabled` produces a non-terminating error that reports Windows error 1314, "A required privilege is not held by the client". The access section is processed first, so a change of `-AccessInheritanceEnabled` in the same command is applied even when the audit change fails.

If the descriptor cannot be opened because the account has no permission to the item, the cmdlet takes ownership of the item, applies the changes, and sets the previous owner back. That fallback only succeeds when the account can take ownership of the item and restore the original owner; otherwise the cmdlet writes an error and continues with the next item.

A path that does not exist produces a non-terminating error and the cmdlet continues with the remaining paths.

Before 5.0.0, omitting `-AccessInheritanceEnabled` or `-AuditInheritanceEnabled` could fail with the error "Nullable object must have a value".

Before 5.0.0, the cmdlet enabled the privileges even when `EnablePrivileges` was `$false`, and left them enabled.

Before 5.0.0, `-PassThru` returned the unchanged state of an item also when the change failed, and stopped the command when the item could not be read.

In the `Path` parameter set, the cmdlet writes only the section that it changes, the DACL or the SACL, and leaves the owner and the group of the item as they are. Before 5.0.0, a change of the access inheritance could also write the owner back, which failed with error 1307, "This security ID may not be assigned as the owner of this object", when the account may not assign that owner, such as on some file servers.

## RELATED LINKS

[Get-NTFSInheritance](Get-NTFSInheritance.md)

[Enable-NTFSAccessInheritance](Enable-NTFSAccessInheritance.md)

[Disable-NTFSAccessInheritance](Disable-NTFSAccessInheritance.md)

[Enable-NTFSAuditInheritance](Enable-NTFSAuditInheritance.md)

[Disable-NTFSAuditInheritance](Disable-NTFSAuditInheritance.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
