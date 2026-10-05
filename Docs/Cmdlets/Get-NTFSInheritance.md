---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSInheritance.md
schema: 2.0.0
---

# Get-NTFSInheritance

## SYNOPSIS

Gets the inheritance state of the access rules and the audit rules of a file or folder.

## SYNTAX

### Path (Default)
```
Get-NTFSInheritance [[-Path] <String[]>] [<CommonParameters>]
```

### SecurityDescriptor
```
Get-NTFSInheritance [-SecurityDescriptor] <FileSystemSecurity2[]> [<CommonParameters>]
```

## DESCRIPTION

The `Get-NTFSInheritance` cmdlet reports whether a file or folder inherits access rules from its parent folder and whether it inherits audit rules. For each item it writes one `Security2.FileSystemInheritanceInfo` object with the `Name`, `FullName`, `AccessInheritanceEnabled`, and `AuditInheritanceEnabled` properties, plus the underlying file system object in the `Item` property. The default table view shows `Name`, `AccessInheritanceEnabled`, and `AuditInheritanceEnabled`.

`AccessInheritanceEnabled` is `$false` when the discretionary access control list (DACL) of the item is protected, which is the state that `Disable-NTFSAccessInheritance` produces. `AuditInheritanceEnabled` reports the same for the system access control list (SACL), which holds the audit rules. When the audit section cannot be read because the session does not hold the Security privilege, `AuditInheritanceEnabled` is `$null` and its column stays empty; the access value is still reported and no error is written.

In the `Path` parameter set the cmdlet reads the security descriptor of each item from disk. In the `SecurityDescriptor` parameter set it reads the state from the `Security2.FileSystemSecurity2` objects that `Get-NTFSSecurityDescriptor` returns, without touching the file system. A descriptor that was read without its audit section, because the session doesn't hold the Security privilege, reports `AuditInheritanceEnabled` as `$null`, like the `Path` parameter set.

`-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` binds to it. Relative paths are resolved against the current location, and when no path is supplied at all, the cmdlet reports the current location.

## EXAMPLES

### Example 1: Get the inheritance state of a folder

```PowerShell
PS C:\> Get-NTFSInheritance -Path C:\Data\Projects
```

This command reports whether `C:\Data\Projects` inherits access rules and audit rules from `C:\Data`. In a session that does not hold the Security privilege, the `AuditInheritanceEnabled` column stays empty.

### Example 2: Find the items whose access inheritance is blocked

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSInheritance | Where-Object { -not $_.AccessInheritanceEnabled }
```

This command walks the whole tree below `C:\Data` and returns only the items whose DACL is protected. These are the places where the permission model of the tree is interrupted and permissions have to be maintained separately.

### Example 3: Report the current location

```PowerShell
PS C:\> Get-NTFSInheritance
```

This command reports the inheritance state of the current location, because `-Path` is omitted and no item arrives from the pipeline.

### Example 4: Read the state from a security descriptor

```PowerShell
PS C:\> Get-NTFSSecurityDescriptor -Path C:\Data\Projects | Get-NTFSInheritance
```

This command reads the security descriptor once and reports its inheritance state from memory. The access value is always accurate; the audit value is only meaningful when the descriptor was retrieved with its audit section, which requires the Security privilege.

## PARAMETERS

### -Path

Specifies the path of one or more files or folders to report on. Relative paths are resolved against the current location, and the current location is used when the parameter is omitted and no item arrives from the pipeline. The parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` binds to it.

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

This cmdlet reads the inheritance state from the descriptor in memory and does not access the file system for it.

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

For each item the cmdlet writes one object with the `Name`, `FullName`, `Item`, `AccessInheritanceEnabled`, and `AuditInheritanceEnabled` properties. `AccessInheritanceEnabled` and `AuditInheritanceEnabled` are `$true` when the item inherits the rules of the corresponding section from its parent folder, and `AuditInheritanceEnabled` is `$null` when the audit section could not be read.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Reading the audit section (SACL) of an item requires the Security privilege (`SeSecurityPrivilege`), which an account can only use in an elevated session. Without it, the cmdlet still reports the access state and sets `AuditInheritanceEnabled` to `$null` instead of writing an error.

Before 5.0.0, a security descriptor that was read without its audit section reported `AuditInheritanceEnabled` as `$true`.

If the security descriptor of an item cannot be opened because the account has no permission to it, the cmdlet takes ownership of the item, reads the state, and sets the previous owner back. That fallback only succeeds when the account can take ownership of the item and restore the original owner; otherwise the cmdlet writes an error and continues with the next item.

A path that does not exist produces a non-terminating error and the cmdlet continues with the remaining paths.

Before 5.0.0, the cmdlet enabled the privileges even when `EnablePrivileges` was `$false`, and left them enabled.

## RELATED LINKS

[Set-NTFSInheritance](Set-NTFSInheritance.md)

[Enable-NTFSAccessInheritance](Enable-NTFSAccessInheritance.md)

[Disable-NTFSAccessInheritance](Disable-NTFSAccessInheritance.md)

[Enable-NTFSAuditInheritance](Enable-NTFSAuditInheritance.md)

[Disable-NTFSAuditInheritance](Disable-NTFSAuditInheritance.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)
