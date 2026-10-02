---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Clear-NTFSAccess.md
schema: 2.0.0
---

# Clear-NTFSAccess

## SYNOPSIS

Removes all explicit access control entries from a file or folder.

## SYNTAX

### Path (Default)
```
Clear-NTFSAccess [-Path] <String[]> [-DisableInheritance] [<CommonParameters>]
```

### SD
```
Clear-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-DisableInheritance] [<CommonParameters>]
```

## DESCRIPTION

Removes every access control entry (ACE) that is defined on a file or a folder itself. Inherited entries are not touched and continue to apply, so an item whose permissions come from its parent folder keeps them.

`-DisableInheritance` additionally protects the item from its parents and discards the inherited entries instead of copying them into the item. An item that is cleared with `-DisableInheritance` therefore ends up with an empty DACL, which denies access to everyone; only its owner can still change the permissions. Grant the required rights with `Add-NTFSAccess` right after clearing, or re-enable inheritance with `Enable-NTFSAccessInheritance`.

In the `Path` parameter set the cmdlet reads the item from disk and writes the changed DACL back immediately; relative paths are resolved against the current location. In the `SD` parameter set it changes a `Security2.FileSystemSecurity2` object returned by `Get-NTFSSecurityDescriptor` in memory until `Set-NTFSSecurityDescriptor` writes it back. The cmdlet writes no output, and a failure on one item is reported as a non-terminating error while the remaining items are processed.

## EXAMPLES

### Example 1: Remove the explicit permissions of a folder

```PowerShell
PS C:\> Clear-NTFSAccess -Path C:\Data
```

This command removes all access control entries that are defined on `C:\Data` itself. The entries that the folder inherits from its parent remain in effect.

### Example 2: Remove all permissions and break inheritance

```PowerShell
PS C:\> Clear-NTFSAccess -Path C:\Data -DisableInheritance
```

This command removes the explicit entries of `C:\Data` and disables inheritance without copying the inherited entries. The folder is left with an empty DACL and is inaccessible until new permissions are granted.

### Example 3: Reset the permissions of several folders

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -Directory | Clear-NTFSAccess
```

This command removes the explicit entries of every subfolder of `C:\Data` so that all of them rely on the permissions inherited from `C:\Data`.

### Example 4: Rebuild an ACL in memory

```PowerShell
PS C:\> $sd = Get-NTFSSecurityDescriptor -Path C:\Data
PS C:\> Clear-NTFSAccess -SecurityDescriptor $sd -DisableInheritance
PS C:\> Add-NTFSAccess -SecurityDescriptor $sd -Account 'BUILTIN\Administrators' -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles
PS C:\> Set-NTFSSecurityDescriptor -SecurityDescriptor $sd
```

These commands replace the complete ACL of `C:\Data` in one write. The security descriptor is changed in memory, and the file system is only touched by `Set-NTFSSecurityDescriptor`.

## PARAMETERS

### -DisableInheritance

Indicates that inheritance is disabled after the explicit entries are removed, and that the inherited entries are discarded rather than copied into the item. Without this switch the inherited entries remain in effect.

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

Specifies the path of one or more files or folders whose explicit access control entries are removed. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its alias `FullName`.

```yaml
Type: String[]
Parameter Sets: Path
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -SecurityDescriptor

Specifies one or more `Security2.FileSystemSecurity2` objects, as returned by `Get-NTFSSecurityDescriptor`, whose explicit access control entries are removed. The change is made in memory only; use `Set-NTFSSecurityDescriptor` to write it to the file system.

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

## OUTPUTS

### System.Object

The cmdlet writes nothing. Use `Get-NTFSAccess` to inspect the result.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

If the ACL of an item cannot be written because access is denied, the cmdlet tries once more after making the current account the owner of the item, and restores the previous owner afterwards. Changing the owner of an item requires the Take Ownership and Restore privileges, so this fallback only succeeds in an elevated session of an account that holds them.

## RELATED LINKS

[Add-NTFSAccess](Add-NTFSAccess.md)

[Get-NTFSAccess](Get-NTFSAccess.md)

[Remove-NTFSAccess](Remove-NTFSAccess.md)

[Disable-NTFSAccessInheritance](Disable-NTFSAccessInheritance.md)

[Enable-NTFSAccessInheritance](Enable-NTFSAccessInheritance.md)

[Set-NTFSSecurityDescriptor](Set-NTFSSecurityDescriptor.md)
