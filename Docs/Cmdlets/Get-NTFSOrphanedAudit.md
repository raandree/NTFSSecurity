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

`-Account` limits the result to the entries of one account, which you specify by its SID. With `-SecurityDescriptor`, the cmdlet examines a `Security2.FileSystemSecurity2` object that `Get-NTFSSecurityDescriptor` returned; a descriptor that was read without the Security privilege doesn't contain the audit entries, and the cmdlet writes an error for it.

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

This command stores the result in a variable and then lists the item, the unresolved SID, the audited rights, and the audit flags of every orphaned entry.

### Example 4: Check the current location

```PowerShell
PS C:\> Get-NTFSOrphanedAudit
```

This command examines the current location, because `-Path` is omitted.

## PARAMETERS

### -Account

Specifies the account whose orphaned audit entries are returned. Because the account cannot be resolved, specify it by its SID. When you omit the parameter, the cmdlet returns the entries of all accounts that cannot be resolved.

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

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. The cmdlet examines the in-memory objects instead of reading the items again.

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

Security descriptors that `Get-NTFSSecurityDescriptor` returned bind to `-SecurityDescriptor`, and the cmdlet examines their audit entries.

### Security2.IdentityReference2

An account name or a SID string binds to `-Account`.

## OUTPUTS

### Security2.FileSystemAuditRule2

The cmdlet returns the audit entries whose account SID cannot be translated into a name, each with the item, the unresolved account, the audited access rights, the audit flags, and the inheritance information. The cmdlet writes one object per entry.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Reading the SACL requires the Security privilege (`SeSecurityPrivilege`, "Manage auditing and security log"), so run this cmdlet in an elevated session of an account that holds that privilege. Without it, the cmdlet writes the non-terminating error `ReadSecurityError` for each item, which reports "A required privilege is not held by the client", like `Get-NTFSAudit`.

If the audit entries of an item can't be read, the cmdlet writes a `ReadSecurityError`, with the category `PermissionDenied` when access is denied, and continues with the next item; for a path that doesn't exist, it writes a `ReadError`. Like `Get-NTFSAudit`, it doesn't take ownership of the item, because ownership grants no access to the SACL.

Before 5.0.0, the cmdlet ignored `-Account` and `-SecurityDescriptor` and wrote the entries of each item as one collection.

Before 5.0.0-rc7, the cmdlet read an item without its SACL when the Security privilege was missing and reported no orphaned entries, which looked the same as an item that has none. For an item that it couldn't read, it wrote a warning instead of an error.

## RELATED LINKS

[Get-NTFSAudit](Get-NTFSAudit.md)

[Remove-NTFSAudit](Remove-NTFSAudit.md)

[Clear-NTFSAudit](Clear-NTFSAudit.md)

[Add-NTFSAudit](Add-NTFSAudit.md)

[Get-NTFSOrphanedAccess](Get-NTFSOrphanedAccess.md)
