---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSAccess.md
schema: 2.0.0
---

# Get-NTFSAccess

## SYNOPSIS

Gets the access control entries (ACEs) of a file, a folder, or a security descriptor.

## SYNTAX

### Path (Default)
```
Get-NTFSAccess [[-Path] <String[]>] [-Account <IdentityReference2>] [-ExcludeExplicit] [-ExcludeInherited]
 [<CommonParameters>]
```

### SD
```
Get-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account <IdentityReference2>] [-ExcludeExplicit]
 [-ExcludeInherited] [<CommonParameters>]
```

## DESCRIPTION

Reads the discretionary access control list (DACL) of a file or a folder and writes one `Security2.FileSystemAccessRule2` object for every access control entry (ACE) it contains. Each object carries the account, the rights, the access type, the inheritance and propagation flags, whether the ACE is inherited, and the path of the item it was read from.

In the `Path` parameter set the cmdlet reads the item from disk; relative paths are resolved against the current location, and when `-Path` is omitted the current location is used. In the `SD` parameter set it reads the ACEs from a `Security2.FileSystemSecurity2` object returned by `Get-NTFSSecurityDescriptor`, which also reflects changes that have not been written back yet.

By default both explicit and inherited entries are returned. `-ExcludeInherited` limits the result to the entries defined on the item itself, `-ExcludeExplicit` limits it to the entries the item inherits from its parents, and combining both returns nothing. `-Account` filters the result to a single account; an entry matches when the account resolves to the same SID.

When the module setting `GetInheritedFrom` is `$true`, which is the default in the `PrivateData` section of NTFSSecurity.psd1, the `InheritedFrom` property of every inherited entry contains the path of the folder the entry originates from. The default table view shows the account, the rights, the scope of the ACE in the wording of the Windows security dialog, the access type, and the inheritance information; setting `ShowAccountSid` to `$true` adds the SID to the account column.

## EXAMPLES

### Example 1: Get all access control entries of a folder

```PowerShell
PS C:\> Get-NTFSAccess -Path C:\Data
```

This command returns the explicit and the inherited access control entries of `C:\Data`.

### Example 2: Get only the permissions defined on the item itself

```PowerShell
PS C:\> Get-NTFSAccess -Path C:\Data -ExcludeInherited
```

This command returns the explicit access control entries of `C:\Data` and omits everything the folder inherits from its parents.

### Example 3: Find the permissions of one account in a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -Directory | Get-NTFSAccess -Account 'CONTOSO\JohnDoe' -ExcludeInherited
```

This command searches all subfolders of `C:\Data` for access control entries that were defined for a single account. `Get-ChildItem` and `Get-Item2` can be used in the same way, because the `FullName` property of their output binds to `-Path`.

### Example 4: Export the explicit permissions of a folder tree to a CSV file

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSAccess -ExcludeInherited | Export-Csv -Path C:\Backup\acl.csv -NoTypeInformation
```

This command writes a backup of all explicit access control entries below `C:\Data`. `Import-Csv C:\Backup\acl.csv | Add-NTFSAccess` recreates them, because the exported columns bind to the parameters of `Add-NTFSAccess`.

## PARAMETERS

### -Account

Specifies the account whose access control entries are returned. An account can be given as a name such as `CONTOSO\JohnDoe`, `BUILTIN\Users`, or `NT AUTHORITY\SYSTEM`, or as a SID string such as `S-1-5-32-544`. When the parameter is omitted, the entries of all accounts are returned.

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

Indicates that the access control entries defined on the item itself are omitted and only the inherited entries are returned.

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

Indicates that the inherited access control entries are omitted and only the entries defined on the item itself are returned.

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

Specifies the path of one or more files or folders whose access control entries are read. Relative paths are resolved against the current location, and the current location is used when the parameter is omitted. The parameter accepts pipeline input by value and by property name through its alias `FullName`.

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

Specifies one or more `Security2.FileSystemSecurity2` objects, as returned by `Get-NTFSSecurityDescriptor`, whose access control entries are read. This includes changes that were made to the object in memory and not written back yet.

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

One or more security descriptors returned by `Get-NTFSSecurityDescriptor`.

### Security2.IdentityReference2

The account to filter on. The parameter does not take pipeline input; it is listed here because it accepts the remaining arguments of the command line.

## OUTPUTS

### Security2.FileSystemAccessRule2

One object per access control entry, with the account, the rights, the access type, the inheritance and propagation flags, the `IsInherited` and `InheritedFrom` properties, and the path of the item.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

If the ACL of an item cannot be read because access is denied, the cmdlet tries once more after making the current account the owner of the item, and restores the previous owner afterwards. Changing the owner of an item requires the Take Ownership and Restore privileges, so this fallback only succeeds in an elevated session of an account that holds them.

Entries whose account cannot be translated into a name are returned with their SID. Use `Get-NTFSOrphanedAccess` to list only those entries.

## RELATED LINKS

[Add-NTFSAccess](Add-NTFSAccess.md)

[Remove-NTFSAccess](Remove-NTFSAccess.md)

[Get-NTFSOrphanedAccess](Get-NTFSOrphanedAccess.md)

[Get-NTFSSimpleAccess](Get-NTFSSimpleAccess.md)

[Get-NTFSEffectiveAccess](Get-NTFSEffectiveAccess.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)
