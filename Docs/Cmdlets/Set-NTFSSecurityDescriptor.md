---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Set-NTFSSecurityDescriptor.md
schema: 2.0.0
---

# Set-NTFSSecurityDescriptor

## SYNOPSIS

Writes a security descriptor to the file or folder it was read from.

## SYNTAX

```
Set-NTFSSecurityDescriptor [-SecurityDescriptor] <FileSystemSecurity2[]> [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Set-NTFSSecurityDescriptor` cmdlet writes a `Security2.FileSystemSecurity2` object to the file system. It is the final step of the security descriptor workflow: `Get-NTFSSecurityDescriptor` reads a descriptor into memory, cmdlets such as `Add-NTFSAccess`, `Remove-NTFSAccess`, `Set-NTFSOwner`, and `Disable-NTFSAccessInheritance` change that copy through their `-SecurityDescriptor` parameter, and this cmdlet applies all of those changes in a single write.

Each descriptor remembers the item it was read from, and the cmdlet writes it back to exactly that item. There is no parameter that redirects the write to a different path, and writing a descriptor that you did not change simply re-applies its current content.

The cmdlet produces no output unless you use `-PassThru`, which reads the item again after the write and returns a new `FileSystemSecurity2` object that reflects what is now stored on disk. Descriptors can be passed as an array or through the pipeline, and each one is processed on its own.

When the write fails because access is denied, the cmdlet takes ownership of the item with the account of the current session, writes the descriptor, and restores the previous owner. If that fails as well, it writes a non-terminating error and continues with the next descriptor. Windows checks each section separately: changing the access control list requires the Change Permissions right on the item, changing the owner requires the Take Ownership right or the Take Ownership privilege, assigning ownership to another account requires the Restore privilege, and writing audit entries requires the Security privilege.

## EXAMPLES

### Example 1: Write a changed security descriptor

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Add-NTFSAccess -SecurityDescriptor $sd -Account 'CONTOSO\JohnDoe' -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndFiles
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

The first two commands add an access control entry to the descriptor in memory, which leaves `C:\Data` untouched. The third command writes the descriptor and applies the new entry to the folder.

### Example 2: Write several descriptors in one pipeline

```PowerShell
PS C:\> $descriptors = Get-ChildItem2 -Path C:\Data | Get-NTFSSecurityDescriptor
PS C:\> $descriptors | ForEach-Object { Add-NTFSAccess -SecurityDescriptor $_ -Account 'CONTOSO\JohnDoe' -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndFiles }
PS C:\> $descriptors | Set-NTFSSecurityDescriptor
```

The descriptors of all items in `C:\Data` are read, changed in memory, and then written back. Each descriptor goes to the item it came from.

### Example 3: Write a new owner

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data\Report.docx
PS C:\> Set-NTFSOwner -SecurityDescriptor $sd -Account 'BUILTIN\Administrators'
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

This sequence changes the owner inside the descriptor and then writes the owner section to the file.

### Example 4: Verify the result after writing

```PowerShell
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -PassThru | Get-NTFSAccess
```

This command writes the descriptor, reads the item again, and lists the access control entries that are now stored on it.

## PARAMETERS

### -PassThru

Indicates that the cmdlet reads each item again after the write and returns its current security descriptor. Without this parameter, the cmdlet produces no output.

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

### -SecurityDescriptor

Specifies one or more security descriptors that `Get-NTFSSecurityDescriptor` returned. Each descriptor is written to the file or folder it was read from, including every change that was made to it in memory.

```yaml
Type: FileSystemSecurity2[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### Security2.FileSystemSecurity2[]

You can pipe one or more security descriptors that `Get-NTFSSecurityDescriptor` returned to this cmdlet.

## OUTPUTS

### Security2.FileSystemSecurity2

The cmdlet returns a descriptor per written item only when you use `-PassThru`. That descriptor is read from the item after the write, so it is a new object and not the one you passed in.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

The cmdlet always writes to the item that is stored in the descriptor, so it cannot apply the descriptor of one item to another file or folder. To copy permissions, read the descriptor of the target item, add the entries you need with `Add-NTFSAccess`, and write the target descriptor.

`Add-NTFSAccess`, `Remove-NTFSAccess`, `Add-NTFSAudit`, and `Remove-NTFSAudit` offer two parameter sets for a security descriptor, one with `-AppliesTo` and one with `-InheritanceFlags` and `-PropagationFlags`. Specify at least one of those parameters when you pass a descriptor to them; otherwise PowerShell cannot decide which parameter set to use and reports an ambiguous parameter set.

## RELATED LINKS

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)

[Add-NTFSAccess](Add-NTFSAccess.md)

[Remove-NTFSAccess](Remove-NTFSAccess.md)

[Set-NTFSOwner](Set-NTFSOwner.md)

[Disable-NTFSAccessInheritance](Disable-NTFSAccessInheritance.md)
