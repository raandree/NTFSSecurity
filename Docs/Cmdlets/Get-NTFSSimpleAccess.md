---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSSimpleAccess.md
schema: 2.0.0
---

# Get-NTFSSimpleAccess

## SYNOPSIS

Gets the permissions of folders reduced to read, write, and delete.

## SYNTAX

### Path
```
Get-NTFSSimpleAccess [-IncludeRootFolder] [[-Path] <String[]>] [-Account <IdentityReference2>]
 [-ExcludeExplicit] [-ExcludeInherited] [<CommonParameters>]
```

### SD
```
Get-NTFSSimpleAccess [-IncludeRootFolder] [-SecurityDescriptor] <FileSystemSecurity2[]>
 [-Account <IdentityReference2>] [-ExcludeExplicit] [-ExcludeInherited] [<CommonParameters>]
```

## DESCRIPTION

Reads the access control entries of folders and writes them as `Security2.SimpleFileSystemAccessRule` objects whose rights are reduced to the three values `Read`, `Write`, and `Delete`. Reading rights such as `ReadAttributes` or `Traverse` become `Read`, changing rights such as `CreateFiles`, `WriteAttributes`, `ChangePermissions`, or `TakeOwnership` become `Write`, and `Delete` and `DeleteSubdirectoriesAndFiles` become `Delete`; `FullControl` becomes all three. The result answers who may read, change, or delete in a folder without the detail of the full ACL.

The second simplification is that repetitions are left out. The first folder the cmdlet processes is reported with all of its entries, and for every folder that follows only the entries are reported that its parent folder does not already cover. An entry is covered when the parent has an entry for the same account and access type that includes at least the same simple rights. This makes a recursive listing show where permissions actually change instead of repeating the inherited ones on every level, and it requires the parent folder to be processed before its children, which `Get-ChildItem`, `Get-ChildItem2`, and `Get-Item2` do by default.

`-IncludeRootFolder` is on by default and adds the parent folder of the first path as the baseline for the comparison, which is why the first result usually belongs to the folder above the one that was asked for. Use `-IncludeRootFolder:$false` to start the comparison at the first path itself.

The cmdlet only processes folders; a path that points to a file is skipped silently. Relative paths are resolved against the current location, and the current location is used when `-Path` is omitted. `-ExcludeInherited` and `-ExcludeExplicit` work as in `Get-NTFSAccess`, while `-Account` and `-SecurityDescriptor` are inherited from that cmdlet and have no effect here.

## EXAMPLES

### Example 1: Get the simple permissions of a folder

```PowerShell
PS C:\> Get-NTFSSimpleAccess -Path C:\Data
```

This command shows who may read, write, or delete in `C:\Data`. The permissions of the parent folder are shown first, because `-IncludeRootFolder` is on by default.

### Example 2: Find the folders whose permissions differ

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -Directory | Get-NTFSSimpleAccess
```

This command walks the folder tree below `C:\Data` and reports only the entries that a folder does not already inherit in the same form from its parent, which reveals where permissions were added or broken.

### Example 3: Report only the permissions defined on the folder itself

```PowerShell
PS C:\> Get-NTFSSimpleAccess -Path C:\Data -ExcludeInherited -IncludeRootFolder:$false
```

This command shows the explicit entries of `C:\Data` in simplified form and leaves both the inherited entries and the parent folder out of the result.

## PARAMETERS

### -Account

This parameter is inherited from `Get-NTFSAccess` and has no effect. The cmdlet always returns the entries of all accounts.

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

Indicates that the access control entries defined on the folder itself are omitted and only the inherited entries are reported.

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

Indicates that the inherited access control entries are omitted and only the entries defined on the folder itself are reported.

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

### -IncludeRootFolder

Indicates that the parent folder of the first path is reported as well and serves as the baseline the following folders are compared against. This behavior is on by default; use `-IncludeRootFolder:$false` to start with the first path itself.

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

Specifies the path of one or more folders whose permissions are reported. Paths that point to a file are skipped. Relative paths are resolved against the current location, and the current location is used when the parameter is omitted. The parameter accepts pipeline input by value and by property name through its alias `FullName`.

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

This parameter is inherited from `Get-NTFSAccess` and has no effect. A security descriptor passed here is ignored, and the cmdlet reads the path in `-Path` or the current location instead.

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

One or more paths of folders, piped by value or by the property `FullName`.

### Security2.FileSystemSecurity2[]

Security descriptors are accepted by the parameter binder but ignored by this cmdlet.

### Security2.IdentityReference2

An account is accepted by the parameter binder but ignored by this cmdlet.

## OUTPUTS

### Security2.SimpleFileSystemAccessRule

One object per reported entry, with the folder in `FullName` and `Name`, the account in `Identity`, the access type in `AccessControlType`, and the simplified rights `Read`, `Write`, and `Delete` in `AccessRights`.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), this cmdlet tries to enable the Backup, Restore, Take Ownership, and Security privileges while it runs and disables the privileges it enabled when it finishes. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group. If a privilege cannot be enabled, the cmdlet continues without it and writes a debug message.

The simplified rights hide which exact rights an account holds. Use `Get-NTFSAccess` when you need the full access control entry, and `Get-NTFSEffectiveAccess` when you need the rights that result from all entries together.

## RELATED LINKS

[Get-NTFSAccess](Get-NTFSAccess.md)

[Get-NTFSEffectiveAccess](Get-NTFSEffectiveAccess.md)

[Get-NTFSInheritance](Get-NTFSInheritance.md)

[Get-ChildItem2](Get-ChildItem2.md)
