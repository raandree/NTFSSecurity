---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSOwner.md
schema: 2.0.0
---

# Get-NTFSOwner

## SYNOPSIS

Gets the owner of a file or folder.

## SYNTAX

### Path (Default)
```
Get-NTFSOwner [[-Path] <String[]>] [<CommonParameters>]
```

### SecurityDescriptor
```
Get-NTFSOwner [-SecurityDescriptor] <FileSystemSecurity2[]> [<CommonParameters>]
```

## DESCRIPTION

The `Get-NTFSOwner` cmdlet reads the owner from the security descriptor of a file or folder and returns a `Security2.FileSystemOwner` object. That object exposes the item in the `Item` property, its full path in `FullName`, and the owning account in both the `Owner` and the `Account` property.

The `Path` parameter set reads the owner from the file system. The `SecurityDescriptor` parameter set reads the owner from a security descriptor that `Get-NTFSSecurityDescriptor` returned. The second form also shows an owner that `Set-NTFSOwner` changed in memory but that has not been written back with `Set-NTFSSecurityDescriptor` yet.

The `Path` parameter accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem2`, `Get-Item2`, and `Get-ChildItem` binds to it. Relative paths are resolved against the current location. Unlike `Get-NTFSSecurityDescriptor`, this cmdlet does not fall back to the current location: when you omit `-Path`, it returns nothing.

Every path is processed on its own. When a path does not exist or its owner cannot be read, the cmdlet writes a non-terminating error and continues with the next path.

## EXAMPLES

### Example 1: Get the owner of a folder

```PowerShell
PS C:\> Get-NTFSOwner -Path C:\Data
```

This command reads the owner of the `C:\Data` folder and returns a single `FileSystemOwner` object.

### Example 2: Get the owner of every item in a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOwner
```

This command pipes every file and folder below `C:\Data` to `Get-NTFSOwner`. The items bind to `-Path` through the `FullName` alias, so the cmdlet returns one result per item.

### Example 3: Find items that a specific account does not own

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOwner | Where-Object { $_.Account.AccountName -ne 'CONTOSO\JohnDoe' }
```

This command returns the items below `C:\Data` whose owner is not `CONTOSO\JohnDoe`. The `AccountName` property holds the resolved account name; compare the `Sid` property instead when an account cannot be resolved.

### Example 4: Read the owner from a security descriptor in memory

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Get-NTFSOwner -SecurityDescriptor $sd
```

The first command reads the security descriptor of `C:\Data` into a variable. The second command returns the owner that is stored in that descriptor without reading the file system again.

## PARAMETERS

### -Path

Specifies the path of one or more files or folders whose owner you want to read. Relative paths are resolved against the current location. When you omit this parameter, the cmdlet returns nothing.

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

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. The cmdlet reads the owner from the descriptor in memory instead of from the file system, which includes an owner that `Set-NTFSOwner -SecurityDescriptor` changed but that has not been written back yet.

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

## OUTPUTS

### Security2.FileSystemOwner

The cmdlet returns one object per item. It contains the item itself in `Item`, an `Alphaleonis.Win32.Filesystem.FileInfo` or `DirectoryInfo`, the path of the item in `FullName`, and the owning account in `Owner` and `Account`, both of type `Security2.IdentityReference2`.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

The module also adds an `Owner` script property to `System.IO.FileInfo` and `System.IO.DirectoryInfo`, so `(Get-Item C:\Data).Owner` returns the owning account as a `Security2.IdentityReference2` object as well.

## RELATED LINKS

[Set-NTFSOwner](Set-NTFSOwner.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)

[Get-NTFSAccess](Get-NTFSAccess.md)

[Get-ChildItem2](Get-ChildItem2.md)
