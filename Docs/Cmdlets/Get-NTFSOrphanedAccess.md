---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSOrphanedAccess.md
schema: 2.0.0
---

# Get-NTFSOrphanedAccess

## SYNOPSIS

Gets the access control entries whose account cannot be resolved to a name.

## SYNTAX

### Path
```
Get-NTFSOrphanedAccess [[-Path] <String[]>] [-Account <IdentityReference2>] [-ExcludeExplicit]
 [-ExcludeInherited] [<CommonParameters>]
```

### SD
```
Get-NTFSOrphanedAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account <IdentityReference2>]
 [-ExcludeExplicit] [-ExcludeInherited] [<CommonParameters>]
```

## DESCRIPTION

Reads the discretionary access control list (DACL) of a file or a folder like `Get-NTFSAccess` and returns only the access control entries whose account name is empty. The account name of an entry is empty when Windows cannot translate the SID stored in the entry into an account name, which is what remains after the account the entry was created for has been deleted.

An entry counts as orphaned only as long as the name resolution fails, and the cmdlet cannot tell a deleted account from an account that cannot be looked up right now. A domain controller that is unreachable, a broken trust, or a SID from a domain the computer does not know make intact entries look orphaned as well. Confirm that the accounts are really gone before you remove anything, and run the search from a computer that can resolve all domains involved.

Relative paths are resolved against the current location, and the current location is searched when `-Path` is omitted. By default both explicit and inherited entries are returned, which means that the same orphaned entry appears on every item that inherits it; `-ExcludeInherited` reports it only on the item where it is defined. With `-Verbose`, the cmdlet reports the number of orphaned entries per item and the total at the end.

`-Account` limits the result to the entries of one account, which you specify by its SID. With `-SecurityDescriptor`, the cmdlet examines a `Security2.FileSystemSecurity2` object that `Get-NTFSSecurityDescriptor` returned instead of reading the item again.

## EXAMPLES

### Example 1: Find orphaned entries in a folder

```PowerShell
PS C:\> Get-NTFSOrphanedAccess -Path C:\Data
```

This command returns the access control entries of `C:\Data` whose SID cannot be resolved, including the entries the folder inherits from its parent.

### Example 2: Search a folder tree for orphaned entries

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOrphanedAccess -ExcludeInherited
```

This command searches all files and folders below `C:\Data` and reports every orphaned entry on the item where it is defined. Without `-ExcludeInherited` the same entry would also be reported on every item that inherits it.

### Example 3: Remove orphaned entries

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOrphanedAccess -ExcludeInherited | Remove-NTFSAccess
```

This command deletes the orphaned entries from the items they are defined on. The piped objects supply the path, the SID, the rights, the access type, and the flags, so each entry is matched exactly as it exists.

## PARAMETERS

### -Account

Specifies the account whose orphaned entries are returned. Because the account cannot be resolved, specify it by its SID. When you omit the parameter, the cmdlet returns the entries of all accounts that cannot be resolved.

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

Indicates that the access control entries defined on the item itself are omitted and only the inherited entries are searched.

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

Indicates that the inherited access control entries are omitted and only the entries defined on the item itself are searched. Use this switch to report an orphaned entry once instead of on every item that inherits it.

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

Specifies the path of one or more files or folders that are searched for orphaned access control entries. Relative paths are resolved against the current location, and the current location is used when the parameter is omitted. The parameter accepts pipeline input by value and by property name through its alias `FullName`.

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

A security descriptor contains information about the owner of the object, and the primary group of an object. The security descriptor also contains two access control lists (ACL). The first list is called the discretionary access control lists (DACL), and describes who should have access to an object and what type of access to grant. The second list is called the system access control lists (SACL) and defines what type of auditing to record for an object.

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

One or more paths of files or folders, piped by value or by the property `FullName`.

### Security2.FileSystemSecurity2[]

You can pipe the security descriptors that `Get-NTFSSecurityDescriptor` returns to this cmdlet.

### Security2.IdentityReference2

An account name or a SID string binds to `-Account`.

## OUTPUTS

### Security2.FileSystemAccessRule2

One object per orphaned access control entry. The `Account` property holds the unresolved SID and reports an empty account name.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

If the ACL of an item cannot be read because access is denied, the cmdlet tries once more after making the current account the owner of the item, and restores the previous owner afterwards. Changing the owner of an item requires the Take Ownership and Restore privileges, so this fallback only succeeds in an elevated session of an account that holds them.

Before 5.0.0, the cmdlet ignored `-Account` and `-SecurityDescriptor`, and after a path whose ACL could not be read, it returned the orphaned entries of the previous item again.

## RELATED LINKS

[Get-NTFSAccess](Get-NTFSAccess.md)

[Remove-NTFSAccess](Remove-NTFSAccess.md)

[Get-NTFSOrphanedAudit](Get-NTFSOrphanedAudit.md)

[Get-NTFSSimpleAccess](Get-NTFSSimpleAccess.md)

[Get-ChildItem2](Get-ChildItem2.md)
