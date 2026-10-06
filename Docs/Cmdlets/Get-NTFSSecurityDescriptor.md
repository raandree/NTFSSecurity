---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSSecurityDescriptor.md
schema: 2.0.0
---

# Get-NTFSSecurityDescriptor

## SYNOPSIS

Gets the security descriptor of a file or folder.

## SYNTAX

```
Get-NTFSSecurityDescriptor [[-Path] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

The `Get-NTFSSecurityDescriptor` cmdlet reads the security descriptor of a file or folder into memory and returns it as a `Security2.FileSystemSecurity2` object. A security descriptor holds the owner of an item, its primary group, the discretionary access control list (DACL) that grants or denies access, and the system access control list (SACL) that controls auditing.

The returned object is the starting point of the security descriptor workflow. Many cmdlets of the module accept it through a `-SecurityDescriptor` parameter and then change the copy in memory instead of the file system, among them `Add-NTFSAccess`, `Remove-NTFSAccess`, `Clear-NTFSAccess`, `Add-NTFSAudit`, `Remove-NTFSAudit`, `Clear-NTFSAudit`, `Set-NTFSInheritance`, `Enable-NTFSAccessInheritance`, `Disable-NTFSAccessInheritance`, and `Set-NTFSOwner`. Nothing reaches the disk until you pass the descriptor to `Set-NTFSSecurityDescriptor`, which makes it possible to collect several changes and apply them in a single write; that cmdlet writes only the sections that changed. Discard the variable to discard the changes.

The cmdlet reads all sections of the descriptor. When that fails, for example because the session may not read the SACL, it falls back to the access, owner, and group sections, and then to the access section alone. When the cmdlet reads the SACL, it reads the DACL in a separate call, so that the inherited access entries keep their inherited flag. Before 5.0.0, it read the DACL together with the SACL, and Windows could return the inherited entries without that flag; a descriptor written back then stored them as explicit entries. `-Path` accepts pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem2`, `Get-Item2`, and `Get-ChildItem` binds to it. Relative paths are resolved against the current location, and when you omit `-Path` entirely, the cmdlet returns the descriptor of the current location.

Every path is processed on its own. When a path does not exist, the cmdlet writes a non-terminating error and continues with the next one. When reading the descriptor fails because access is denied, the cmdlet takes ownership of the item with the account of the current session, reads the descriptor, and restores the previous owner; if that fails as well, it writes a non-terminating error.

## EXAMPLES

### Example 1: Get the security descriptor of a folder

```PowerShell
PS C:\> Get-NTFSSecurityDescriptor -Path C:\Data
```

This command reads the security descriptor of `C:\Data` and returns it as a `FileSystemSecurity2` object.

### Example 2: Collect several changes and apply them in one write

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Add-NTFSAccess -SecurityDescriptor $sd -Account 'CONTOSO\JohnDoe' -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndFiles
PS C:\> Remove-NTFSAccess -SecurityDescriptor $sd -Account 'BUILTIN\Users' -AccessRights ReadAndExecute -AppliesTo ThisFolderSubfoldersAndFiles
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

The first three commands read the descriptor of `C:\Data` and change its access control list in memory, which leaves the folder untouched. The last command writes both changes to the folder at once.

### Example 3: Inspect the access control list of the descriptor before writing it

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Add-NTFSAccess -SecurityDescriptor $sd -Account 'CONTOSO\JohnDoe' -AccessRights FullControl -AppliesTo ThisFolderOnly
PS C:\> Get-NTFSAccess -SecurityDescriptor $sd
```

The third command lists the access control entries of the descriptor in memory, which already include the permissions that were just added. Compare the result with `Get-NTFSAccess -Path C:\Data` to see that the folder itself has not changed yet.

### Example 4: Get the security descriptor of the current location

```PowerShell
PS C:\> Set-Location -Path C:\Data
PS C:\Data> Get-NTFSSecurityDescriptor
```

Without `-Path`, the cmdlet returns the security descriptor of the current location.

## PARAMETERS

### -Path

Specifies the path of one or more files or folders whose security descriptor you want to read. Relative paths are resolved against the current location. When you omit this parameter, the cmdlet uses the current location.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: FullName

Required: False
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

## OUTPUTS

### Security2.FileSystemSecurity2

The cmdlet returns one object per item. It wraps the item in `Item` and the underlying `System.Security.AccessControl.FileSecurity` or `DirectorySecurity` object in `SecurityDescriptor`, and it exposes the path in `FullName`, the item name in `Name`, and whether the item is a file in `IsFile`.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

`Add-NTFSAccess`, `Remove-NTFSAccess`, `Add-NTFSAudit`, and `Remove-NTFSAudit` offer two parameter sets for a security descriptor, one with `-AppliesTo` and one with `-InheritanceFlags` and `-PropagationFlags`. Specify at least one of those parameters when you pass a descriptor to them; otherwise PowerShell cannot decide which parameter set to use and reports an ambiguous parameter set.

## RELATED LINKS

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)

[Get-NTFSAccess](Get-NTFSAccess.md)

[Add-NTFSAccess](Add-NTFSAccess.md)

[Get-NTFSOwner](Get-NTFSOwner.md)

[Get-NTFSInheritance](Get-NTFSInheritance.md)
