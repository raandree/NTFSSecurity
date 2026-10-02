---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSEffectiveAccess.md
schema: 2.0.0
---

# Get-NTFSEffectiveAccess

## SYNOPSIS

Gets the rights an account effectively has on a file or folder.

## SYNTAX

### Path (Default)
```
Get-NTFSEffectiveAccess [[-Path] <String[]>] [[-Account] <IdentityReference2>] [-ServerName <String>]
 [-ExcludeNoneAccessEntries] [<CommonParameters>]
```

### SecurityDescriptor
```
Get-NTFSEffectiveAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [[-Account] <IdentityReference2>]
 [-ServerName <String>] [-ExcludeNoneAccessEntries] [<CommonParameters>]
```

## DESCRIPTION

Calculates the rights an account really has on a file or a folder and writes the result as a single `Security2.FileSystemAccessRule2` object per item. The cmdlet evaluates the complete discretionary access control list (DACL) of the item against the group memberships of the account with the Windows Authorization API, so allow entries, deny entries, and inherited entries are combined the same way the Windows access check combines them. This is the equivalent of the "Effective Access" tab of the advanced security dialog.

The calculation covers the NTFS permissions of the item only. Share permissions are stored in a separate security descriptor and are not part of the result, so access over a network share can be more restrictive than this cmdlet reports.

When `-Account` is omitted, the account that runs the session is used. `-ServerName` selects the computer whose authorization manager resolves the group memberships of the account and defaults to `localhost`; when the remote authorization manager of the named computer cannot be reached, the cmdlet falls back to the local one and warns that the result is based on the group memberships known on this computer and may be inaccurate. Reading effective access relies on the Security privilege, and the cmdlet warns when the account does not hold it or the privilege is disabled.

Although `-Path` is optional, the cmdlet writes nothing when the parameter is omitted; pass a path or pipe items in. The `SecurityDescriptor` parameter set is accepted by the parameter binder but produces no output, so use `-Path` to query effective access.

## EXAMPLES

### Example 1: Get the effective access of the current user

```PowerShell
PS C:\> Get-NTFSEffectiveAccess -Path C:\Data
```

This command returns the rights the account that runs the session has on `C:\Data`, combining all allow and deny entries of the folder.

### Example 2: Get the effective access of another account

```PowerShell
PS C:\> Get-NTFSEffectiveAccess -Path C:\Data -Account 'CONTOSO\JohnDoe'
```

This command returns the rights of a domain user on `C:\Data`. A group such as `CONTOSO\Domain Users` or `BUILTIN\Users` can be used in the same way.

### Example 3: Compare the effective access of a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -Directory | Get-NTFSEffectiveAccess -Account 'CONTOSO\JohnDoe'
```

This command shows for every subfolder of `C:\Data` what an account is allowed to do there, which makes the folders visible where inheritance is broken or a deny entry applies.

### Example 4: Calculate effective access with the group memberships of a file server

```PowerShell
PS C:\> Get-NTFSEffectiveAccess -Path \\FileServer\Data -Account 'CONTOSO\JohnDoe' -ServerName FileServer
```

This command asks the authorization manager of the file server to resolve the group memberships of the account, which gives a more accurate result than the local fallback.

## PARAMETERS

### -Account

Specifies the account the effective access is calculated for. An account can be given as a name such as `CONTOSO\JohnDoe`, `BUILTIN\Users`, or `NT AUTHORITY\SYSTEM`, or as a SID string such as `S-1-5-32-544`. The default is the account that runs the current session.

```yaml
Type: IdentityReference2
Parameter Sets: (All)
Aliases: NTAccount, IdentityReference

Required: False
Position: 2
Default value: Current user
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ExcludeNoneAccessEntries

Indicates that items on which the account has no rights at all are left out of the result. In this release the switch does not suppress anything: the cmdlet writes a result for every item it processes, even when the calculated access mask is `None`.

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

Specifies the path of one or more files or folders the effective access is calculated for. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its alias `FullName`. The cmdlet writes nothing when no path is supplied.

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

This parameter is accepted by the parameter binder but has no effect. The cmdlet produces no output in this parameter set; use `-Path` instead.

A security descriptor contains information about the owner of the object, and the primary group of an object. The security descriptor also contains two access control lists (ACL). The first list is called the discretionary access control lists (DACL), and describes who should have access to an object and what type of access to grant. The second list is called the system access control lists (SACL) and defines what type of auditing to record for an object.

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

### -ServerName

Specifies the computer whose authorization manager resolves the group memberships of the account. The default is `localhost`. Name the computer that stores the item when you query a network path, because the group memberships known there determine the result; if that computer cannot be reached, the cmdlet falls back to the local authorization manager and warns that the result may be inaccurate.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: localhost
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

One or more paths of files or folders, piped by value or by the property `FullName`.

### Security2.FileSystemSecurity2[]

Security descriptors are accepted by the parameter binder but produce no result in this cmdlet.

### Security2.IdentityReference2

The account the effective access is calculated for, piped by the property `Account`, `NTAccount`, or `IdentityReference`.

## OUTPUTS

### Security2.FileSystemAccessRule2

One object per item, with the calculated rights in `AccessRights` and the account in `Account`. The object describes a result, not an entry of the ACL, so it is always of the access type `Allow`, it is never inherited, and it carries no inheritance or propagation flags.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Reading effective access needs the Security privilege. In a session that does not hold it, the cmdlet warns before it starts and the calculation may fail with an error. Use `Enable-Privileges` in an elevated session to enable the privilege, and `Get-Privileges` to see which privileges the session holds.

## RELATED LINKS

[Get-NTFSAccess](Get-NTFSAccess.md)

[Get-NTFSSimpleAccess](Get-NTFSSimpleAccess.md)

[Get-NTFSInheritance](Get-NTFSInheritance.md)

[Enable-Privileges](Enable-Privileges.md)

[Get-Privileges](Get-Privileges.md)
