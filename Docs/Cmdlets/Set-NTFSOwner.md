---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Set-NTFSOwner.md
schema: 2.0.0
---

# Set-NTFSOwner

## SYNOPSIS

Sets the owner of a file or folder.

## SYNTAX

### Path (Default)
```
Set-NTFSOwner [[-Path] <String[]>] [-Account] <IdentityReference2> [-PassThru] [<CommonParameters>]
```

### SecurityDescriptor
```
Set-NTFSOwner [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2> [-PassThru]
 [<CommonParameters>]
```

## DESCRIPTION

The `Set-NTFSOwner` cmdlet writes the account given in `-Account` into the owner field of the security descriptor of a file or folder.

The two parameter sets differ in where the change lands. With `-Path`, the cmdlet reads the owner section of the item, replaces the owner, and writes the change to the file system immediately. With `-SecurityDescriptor`, it changes only the descriptor in memory; the new owner reaches the file system when you pass the descriptor to `Set-NTFSSecurityDescriptor`.

The cmdlet returns nothing unless you use `-PassThru`, which returns the owner of each processed item as a `Security2.FileSystemOwner` object. `-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem2`, `Get-Item2`, and `Get-ChildItem` binds to it. Relative paths are resolved against the current location, and omitting `-Path` leaves the cmdlet without work to do.

Every item is processed on its own. When a path does not exist or the owner cannot be written, the cmdlet writes a non-terminating error and continues with the next item. Windows itself decides whether the change is allowed: taking ownership requires the Take Ownership right on the item or the Take Ownership privilege (`SeTakeOwnershipPrivilege`), and assigning ownership to an account other than your own requires the Restore privilege (`SeRestorePrivilege`). The module tries to enable both privileges while the cmdlet runs, as described in the Notes section.

## EXAMPLES

### Example 1: Set the owner of a folder

```PowerShell
PS C:\> Set-NTFSOwner -Path C:\Data -Account 'CONTOSO\JohnDoe'
```

This command makes `CONTOSO\JohnDoe` the owner of the `C:\Data` folder and writes the change immediately.

### Example 2: Set the owner of a folder tree and show the result

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Set-NTFSOwner -Account 'BUILTIN\Administrators' -PassThru
```

This command makes the local Administrators group the owner of every file and folder below `C:\Data`. The `-PassThru` parameter returns the new owner of each item.

### Example 3: Change the owner in a security descriptor and write it back

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Set-NTFSOwner -SecurityDescriptor $sd -Account 'BUILTIN\Administrators'
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

The first two commands read the security descriptor of `C:\Data` and change its owner in memory. The third command writes the descriptor, which applies the new owner together with every other change made to `$sd`.

### Example 4: Set the owner by security identifier

```PowerShell
PS C:\> Set-NTFSOwner -Path C:\Data\Report.docx -Account 'S-1-5-32-544'
```

This command makes the account with the security identifier `S-1-5-32-544`, which is the local Administrators group, the owner of the file. Use a SID when an account name cannot be resolved on the current computer.

## PARAMETERS

### -Account

Specifies the account that becomes the new owner. The value is a `Security2.IdentityReference2` object, which the module creates from an account name such as `CONTOSO\JohnDoe` or `BUILTIN\Administrators`, or from a security identifier such as `S-1-5-32-544`. An account name that cannot be resolved fails during parameter binding.

```yaml
Type: IdentityReference2
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PassThru

Indicates that the cmdlet returns the owner of each processed item as a `Security2.FileSystemOwner` object. Without this parameter, the cmdlet produces no output.

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

Specifies the path of one or more files or folders whose owner you want to change. The change is written to the file system immediately. Relative paths are resolved against the current location. When you omit this parameter, the cmdlet does nothing.

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

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. The cmdlet changes the owner only in memory; pass the descriptor to `Set-NTFSSecurityDescriptor` to write the change to the file system.

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

You can pipe one or more paths to this cmdlet. Objects that expose a `Path` or `FullName` property, such as the output of `Get-ChildItem2` and `Get-Item2`, bind to `-Path` as well.

### Security2.FileSystemSecurity2[]

You can pipe security descriptors that `Get-NTFSSecurityDescriptor` returned to this cmdlet.

### Security2.IdentityReference2

An account binds to `-Account` by property name, so an object that exposes an `Account` property supplies the new owner.

## OUTPUTS

### Security2.FileSystemOwner

The cmdlet returns one object per processed item only when you use `-PassThru`. It contains the item in `Item`, its path in `FullName`, and the new owner in `Owner` and `Account`.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

Without those privileges, Windows allows the change only when your account already holds the Take Ownership right on the item, and it refuses to assign ownership to another account. In a session that is not elevated, setting an owner other than your own account therefore fails with a non-terminating error.

## RELATED LINKS

[Get-NTFSOwner](Get-NTFSOwner.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)

[Enable-Privileges](Enable-Privileges.md)
