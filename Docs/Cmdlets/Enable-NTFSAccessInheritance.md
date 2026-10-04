---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Enable-NTFSAccessInheritance.md
schema: 2.0.0
---

# Enable-NTFSAccessInheritance

## SYNOPSIS

Restores the inheritance of access rules on a file or folder.

## SYNTAX

### Path (Default)
```
Enable-NTFSAccessInheritance [[-Path] <String[]>] [-PassThru] [-RemoveExplicitAccessRules] [<CommonParameters>]
```

### SecurityDescriptor
```
Enable-NTFSAccessInheritance [-SecurityDescriptor] <FileSystemSecurity2[]> [-PassThru]
 [-RemoveExplicitAccessRules] [<CommonParameters>]
```

## DESCRIPTION

The `Enable-NTFSAccessInheritance` cmdlet removes the protection from the discretionary access control list (DACL) of a file or folder, so that the item inherits access rules from its parent folder again.

By default, the access rules that are stored directly on the item are kept, and the inherited rules are added to them. An item that was processed by `Disable-NTFSAccessInheritance` therefore ends up with the inherited rules twice: once as the explicit copies that were created when inheritance was blocked, and once as true inherited rules. The `-RemoveExplicitAccessRules` switch deletes every access rule that is stored directly on the item, which leaves only the inherited rules and restores the permission model of the parent folder.

In the `Path` parameter set the cmdlet reads the access section of the item's security descriptor, changes it, and writes it back to disk immediately. In the `SecurityDescriptor` parameter set it changes the `Security2.FileSystemSecurity2` object in memory only; nothing reaches the file system until you pass that object to `Set-NTFSSecurityDescriptor`.

`-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, `Get-Item2`, and `Get-NTFSInheritance` binds to it. Relative paths are resolved against the current location. The cmdlet affects only the access rules; use `Enable-NTFSAuditInheritance` for the audit rules.

## EXAMPLES

### Example 1: Restore inheritance and keep the explicit rules

```PowerShell
PS C:\> Enable-NTFSAccessInheritance -Path C:\Data\Projects
```

This command lets `C:\Data\Projects` inherit the access rules of `C:\Data` again. The rules that are stored directly on the folder stay in place and are added to the inherited ones.

### Example 2: Restore inheritance and drop the explicit rules

```PowerShell
PS C:\> Enable-NTFSAccessInheritance -Path C:\Data\Projects -RemoveExplicitAccessRules -PassThru
```

This command removes every access rule that is stored directly on the folder and lets it inherit from `C:\Data` again, so the folder ends up with exactly the permissions of its parent. `-PassThru` returns the resulting state, in which `AccessInheritanceEnabled` is `$true`.

### Example 3: Repair a whole folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSInheritance | Where-Object { -not $_.AccessInheritanceEnabled } | Enable-NTFSAccessInheritance -RemoveExplicitAccessRules
```

This command finds every item below `C:\Data` whose access inheritance is blocked and restores it. `Get-NTFSInheritance` writes objects with a `FullName` property, which binds to `-Path`.

### Example 4: Change a security descriptor in memory

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data\Projects
PS C:\> Enable-NTFSAccessInheritance -SecurityDescriptor $sd -RemoveExplicitAccessRules
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

The first two commands read the security descriptor and restore inheritance in memory, which does not change anything on disk. The third command writes the descriptor back and applies the change.

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

Specifies the path of one or more files or folders whose access inheritance is restored. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, `Get-Item2`, and `Get-NTFSInheritance` binds to it. The cmdlet does nothing when no path is supplied, either directly or from the pipeline.

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

### -RemoveExplicitAccessRules

Indicates that every access rule stored directly on the item is removed when inheritance is restored, so that the item ends up with the inherited rules only. By default, when the switch is omitted, the explicit rules are kept and the inherited rules are added to them, which usually duplicates the rules that `Disable-NTFSAccessInheritance` copied earlier.

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

Restoring access inheritance requires permission to change the DACL of the item, which the owner of an item always has. If the descriptor cannot be opened, the cmdlet takes ownership of the item, applies the change, and sets the previous owner back. That fallback only succeeds when the account can take ownership of the item and restore the original owner; otherwise the cmdlet writes an error and continues with the next item.

A path that does not exist produces a non-terminating error and the cmdlet continues with the remaining paths.

Before 5.0.0, the cmdlet enabled the privileges even when `EnablePrivileges` was `$false`, and left them enabled.

Before 5.0.0, `-PassThru` returned the unchanged state of an item also when the change failed, and stopped the command when the item could not be read.

## RELATED LINKS

[Disable-NTFSAccessInheritance](Disable-NTFSAccessInheritance.md)

[Get-NTFSInheritance](Get-NTFSInheritance.md)

[Set-NTFSInheritance](Set-NTFSInheritance.md)

[Enable-NTFSAuditInheritance](Enable-NTFSAuditInheritance.md)

[Get-NTFSAccess](Get-NTFSAccess.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
