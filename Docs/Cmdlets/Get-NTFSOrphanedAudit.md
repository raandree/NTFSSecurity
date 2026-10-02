---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSOrphanedAudit.md
schema: 2.0.0
---

# Get-NTFSOrphanedAudit

## SYNOPSIS

Gets the audit entries whose account cannot be resolved.

## SYNTAX

### Path
```
Get-NTFSOrphanedAudit [[-Path] <String[]>] [-Account <IdentityReference2>] [-ExcludeExplicit]
 [-ExcludeInherited] [<CommonParameters>]
```

### SD
```
Get-NTFSOrphanedAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account <IdentityReference2>]
 [-ExcludeExplicit] [-ExcludeInherited] [<CommonParameters>]
```

## DESCRIPTION

The `Get-NTFSOrphanedAudit` cmdlet returns the audit entries of a file or folder whose account cannot be translated into a name. An entry is called orphaned when its security identifier (SID) is still stored in the system access control list (SACL) but Windows cannot map that SID to a user or group, which usually happens after the account was deleted. Orphaned entries are shown with their SID instead of a name, and they keep auditing a security principal that no longer exists.

An entry is reported as orphaned whenever the name resolution fails at that moment, not only when the account is really gone. A domain account whose domain controller cannot be reached, an account from a domain whose trust relationship is broken, and an account from a forest the computer currently cannot contact all look exactly like a deleted account. Verify that an account no longer exists before you remove its entries with `Remove-NTFSAudit`.

The cmdlet is built on `Get-NTFSAudit` and reads the SACL of every item in `-Path`, using the current location when you omit the parameter. `-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` binds to it. `-ExcludeExplicit` and `-ExcludeInherited` narrow the entries that are examined, and `-Verbose` reports how many orphaned entries each item has and their total.

`Get-NTFSOrphanedAudit` inherits the `-Account` and `-SecurityDescriptor` parameters from `Get-NTFSAudit`, but it does not evaluate them. The entries are always read from the items in `-Path`, so a command that passes `-SecurityDescriptor` examines the current location instead of the descriptor.

## EXAMPLES

### Example 1: Find orphaned audit entries in a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOrphanedAudit
```

This command examines every item below `C:\Data` and returns the audit entries whose account cannot be resolved.

### Example 2: Find orphaned entries that are set on the item itself

```PowerShell
PS C:\> Get-NTFSOrphanedAudit -Path C:\Data -ExcludeInherited
```

This command skips the audit entries that `C:\Data` inherits from its parent and reports only the orphaned entries that are set on the folder itself. Those are the entries that can be removed on this item.

### Example 3: Collect the orphaned entries for a report

```PowerShell
PS C:\> $orphaned = Get-NTFSOrphanedAudit -Path C:\Data -Verbose
PS C:\> $orphaned | Select-Object FullName, Account, AccessRights, AuditFlags
```

This command stores the result in a variable and then lists the item, the unresolved SID, the audited rights, and the audit flags of every orphaned entry. Storing the result first is necessary because the cmdlet writes one collection per item rather than one object per entry.

### Example 4: Check the current location

```PowerShell
PS C:\> Get-NTFSOrphanedAudit
```

This command examines the current location, because `-Path` is omitted.

## PARAMETERS

### -Account

Specifies an account in the base cmdlet `Get-NTFSAudit`. `Get-NTFSOrphanedAudit` inherits the parameter but does not evaluate it, so the result always contains the entries of every account whose SID cannot be resolved.

```yaml
Type: IdentityReference2
Parameter Sets: (All)
Aliases: IdentityReference, ID

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeExplicit

Indicates that the entries that are set on the item itself are left out, so that only inherited entries are examined. By default the cmdlet examines explicit and inherited entries.

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

### -ExcludeInherited

Indicates that the entries the item inherits from a parent folder are left out, so that only the explicit entries are examined. By default the cmdlet examines explicit and inherited entries.

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

Specifies the files or folders that are examined. Relative paths are resolved against the current location, and when you omit the parameter the cmdlet uses the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

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

Specifies one or more security descriptors in the base cmdlet `Get-NTFSAudit`. `Get-NTFSOrphanedAudit` inherits the parameter but does not read from it; the cmdlet always examines the items in `-Path` and therefore the current location when `-Path` is omitted. Use `Get-NTFSAudit -SecurityDescriptor` to inspect the audit entries of a security descriptor.

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

Security descriptors bind to the inherited `-SecurityDescriptor` parameter, but this cmdlet does not read their audit entries.

### Security2.IdentityReference2

An account name or a SID string binds to the inherited `-Account` parameter, which this cmdlet does not evaluate.

## OUTPUTS

### Security2.FileSystemAuditRule2

The cmdlet returns the audit entries whose account SID cannot be translated into a name, each with the item, the unresolved account, the audited access rights, the audit flags, and the inheritance information. The entries of an item are written as a single collection rather than one object per entry, so store the result in a variable before you filter or format it; an item without orphaned entries still produces one empty collection, and a command placed directly after this cmdlet in the pipeline receives the collection instead of the individual entries.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Reading the SACL requires the Security privilege (`SeSecurityPrivilege`, "Manage auditing and security log"), so run this cmdlet in an elevated session of an account that holds that privilege. Without it the cmdlet reads the security descriptor without its SACL and reports no orphaned entries at all, which looks the same as a tree that has none.

If an item cannot be read, the cmdlet writes a warning and continues with the next item. Unlike `Get-NTFSAudit`, it does not try to take ownership of the item when access is denied.

## RELATED LINKS

[Get-NTFSAudit](Get-NTFSAudit.md)

[Remove-NTFSAudit](Remove-NTFSAudit.md)

[Clear-NTFSAudit](Clear-NTFSAudit.md)

[Add-NTFSAudit](Add-NTFSAudit.md)

[Get-NTFSOrphanedAccess](Get-NTFSOrphanedAccess.md)
