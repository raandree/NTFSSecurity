---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSAudit.md
schema: 2.0.0
---

# Get-NTFSAudit

## SYNOPSIS

Gets the audit entries of a file or folder.

## SYNTAX

### Path
```
Get-NTFSAudit [[-Path] <String[]>] [-Account <IdentityReference2>] [-ExcludeExplicit] [-ExcludeInherited]
 [<CommonParameters>]
```

### SD
```
Get-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account <IdentityReference2>] [-ExcludeExplicit]
 [-ExcludeInherited] [<CommonParameters>]
```

## DESCRIPTION

The `Get-NTFSAudit` cmdlet returns the audit entries that are stored in the system access control list (SACL) of a file or folder. Each entry is a `Security2.FileSystemAuditRule2` object that reports the audited account, the audited access rights, the audit flags (`Success`, `Failure`, or both), the inheritance and propagation flags, whether the entry is inherited, and the item it is inherited from. The access rights are the same values that `Add-NTFSAccess` and `Add-NTFSAudit` use; for what each right permits, see [Concepts](../Concepts.md).

In the `Path` parameter set the cmdlet reads the security descriptor of every item in `-Path`. Relative paths are resolved against the current location, and when you omit `-Path` the cmdlet uses the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` binds to it. In the `SD` parameter set the cmdlet reads the audit entries from an in-memory `Security2.FileSystemSecurity2` object that `Get-NTFSSecurityDescriptor` returned instead of reading the item again.

By default the cmdlet returns explicit and inherited entries. Use `-ExcludeInherited` to return only the entries that are set on the item itself, and `-ExcludeExplicit` to return only the entries that the item inherits from a parent folder. `-Account` filters the result to a single account; the comparison is made on the security identifier (SID), so an account name and its SID select the same entries.

The `InheritedFrom` property is filled only when the module setting `GetInheritedFrom` is `$true`, which is the default in the `PrivateData` section of `NTFSSecurity.psd1`.

## EXAMPLES

### Example 1: Get the audit entries of a folder

```PowerShell
PS C:\> Get-NTFSAudit -Path C:\Data
```

This command returns every audit entry of the folder `C:\Data`, including the entries that the folder inherits from its parent.

### Example 2: List the explicit audit entries of a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSAudit -ExcludeInherited
```

This command pipes every item below `C:\Data` into `Get-NTFSAudit` and returns only the audit entries that are set on the items themselves.

### Example 3: Filter the audit entries by account

```PowerShell
PS C:\> Get-NTFSAudit -Path C:\Data -Account 'CONTOSO\JohnDoe'
```

This command returns only the entries that audit the account `CONTOSO\JohnDoe`. Passing the SID of the account instead of its name returns the same entries.

### Example 4: Read the audit entries from a security descriptor

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Get-NTFSAudit -SecurityDescriptor $sd
```

This command reads the security descriptor of `C:\Data` once and then lists its audit entries from the in-memory object.

## PARAMETERS

### -Account

Specifies the account whose audit entries are returned. The value is an account name such as `CONTOSO\JohnDoe`, `BUILTIN\Users`, or `Everyone`, or a SID string such as `S-1-5-32-545`. Entries are matched by SID, and when you omit the parameter the entries of all accounts are returned.

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

Indicates that the entries that are set on the item itself are left out, so that only the inherited entries are returned. By default the cmdlet returns explicit and inherited entries.

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

Indicates that the entries the item inherits from a parent folder are left out, so that only the explicit entries are returned. By default the cmdlet returns explicit and inherited entries.

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

Specifies the files or folders whose audit entries are returned. Relative paths are resolved against the current location, and when you omit the parameter the cmdlet uses the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

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

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. The cmdlet reads the audit entries from the system access control list (SACL) of the in-memory object instead of reading the item from disk again.

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

### Security2.IdentityReference2

You can pass an account name or a SID string to `-Account`, which the cmdlet converts to this type. The parameter does not accept pipeline input.

## OUTPUTS

### Security2.FileSystemAuditRule2

The cmdlet returns one object per audit entry, with the audited account, the audited access rights, the audit flags, the inheritance and propagation flags, the `IsInherited` flag, and the `InheritedFrom` path. When an item has no audit entries, the cmdlet returns nothing for that item; when its SACL cannot be read, the cmdlet writes an error.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Reading the SACL requires the Security privilege (`SeSecurityPrivilege`, "Manage auditing and security log"), so run this cmdlet in an elevated session of an account that holds that privilege. Without it, the cmdlet writes the non-terminating error `ReadSecurityError` for each item, which reports "A required privilege is not held by the client". `Get-NTFSSecurityDescriptor` reads a security descriptor without its SACL when the privilege is missing; for such a descriptor, the cmdlet writes a `ReadSecurityError` as well.

If the security descriptor cannot be read because access is denied, the cmdlet takes ownership of the item, reads the descriptor again, and restores the previous owner. If the second attempt fails as well, the cmdlet writes an error, and the ownership change is not rolled back.

Before 5.0.0, the cmdlet returned no entries and no error without the Security privilege, and after a path whose security descriptor could not be read, it returned the entries of the previous item again.

## RELATED LINKS

[Add-NTFSAudit](Add-NTFSAudit.md)

[Remove-NTFSAudit](Remove-NTFSAudit.md)

[Clear-NTFSAudit](Clear-NTFSAudit.md)

[Get-NTFSOrphanedAudit](Get-NTFSOrphanedAudit.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)
