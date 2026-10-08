---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/New-NTFSSymbolicLink.md
schema: 2.0.0
---

# New-NTFSSymbolicLink

## SYNOPSIS

Creates a symbolic link to an existing file or folder.

## SYNTAX

```
New-NTFSSymbolicLink [-Path] <String> [-Target] <String> [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `New-NTFSSymbolicLink` cmdlet creates a symbolic link that redirects to another file or folder. `-Path` is the new link that the cmdlet creates, and `-Target` is the existing item that the link points to. Read the command as "create *Path*, which points to *Target*". Both parameters are required.

Before it creates the link, the cmdlet inspects the target and creates a file symbolic link when the target is a file and a directory symbolic link when the target is a folder, so you do not select the link type yourself. `-Target` must exist when the link is created, and `-Path` must not exist yet, so the cmdlet never overwrites an existing item.

Relative paths are resolved against the current location before the link is created, which means that the link always stores an absolute target path.

To create several links, pipe objects with the properties `Path` and `Target` to the cmdlet, one link per object. For a link that it can't create, the cmdlet writes a non-terminating error and continues with the next object.

By default the cmdlet produces no output. With `-PassThru` it returns an object for the new link: a file object for a link to a file, and a folder object for a link to a folder.

## EXAMPLES

### Example 1: Create a symbolic link to a file

```PowerShell
PS C:\> New-NTFSSymbolicLink -Path C:\Data\Report-Current.txt -Target C:\Data\Archive\Report-2026.txt
```

This command creates the symbolic link `Report-Current.txt`, which redirects to the existing file `Report-2026.txt`. Because the target is a file, the cmdlet creates a file symbolic link.

### Example 2: Create a symbolic link to a folder

```PowerShell
PS C:\> New-NTFSSymbolicLink -Path C:\Data\Current -Target C:\Data\Archive\2026
```

This command creates the symbolic link `C:\Data\Current`, which redirects to the existing folder `C:\Data\Archive\2026`. Because the target is a folder, the cmdlet creates a directory symbolic link, and paths below `C:\Data\Current` resolve to the corresponding items in the target folder.

### Example 3: Create a link and return it

```PowerShell
PS C:\> New-NTFSSymbolicLink -Path C:\Data\Current -Target C:\Data\Archive\2026 -PassThru
```

This command creates the link and returns an object for the new link, which you can use to confirm the result in a script.

### Example 4: Verify that the link resolves

```PowerShell
PS C:\> Test-Path2 -Path C:\Data\Current\Report.txt -PathType Leaf
```

This command tests a path that leads through the symbolic link. It returns `$true` when the link resolves and the file exists in the target folder.

### Example 5: Create several links from a list

```PowerShell
PS C:\> Import-Csv -Path C:\Data\Links.csv | New-NTFSSymbolicLink
```

This command creates one symbolic link for each row of `Links.csv`, which has the columns `Path` and `Target`. For a row whose link it can't create, the cmdlet writes an error and continues with the next row.

## PARAMETERS

### -PassThru

Indicates that the cmdlet returns an object for the new link. By default, this cmdlet produces no output. The returned object is a file object for a link to a file and a folder object for a link to a folder.

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

Specifies the path of the new symbolic link that the cmdlet creates. The path must not exist yet. Relative paths are resolved against the current location.

```yaml
Type: String
Parameter Sets: (All)
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Target

Specifies the path of the existing file or folder that the new link points to. The target must exist when the link is created and determines whether the cmdlet creates a file symbolic link or a directory symbolic link. Relative paths are resolved against the current location, so the link stores an absolute target path.

```yaml
Type: String
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

### System.String

You can pass the path of the new link and the path of the target as strings.

### System.Management.Automation.PSObject

You can pipe objects whose `Path` or `FullName` property names the new link and whose `Target` property names its target, such as the rows of a CSV file that `Import-Csv` reads.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

With `-PassThru`, the cmdlet writes a file object for a new link to a file. Without `-PassThru`, the cmdlet writes nothing.

### Alphaleonis.Win32.Filesystem.DirectoryInfo

With `-PassThru`, the cmdlet writes a folder object for a new link to a folder. Before 5.0.0, it wrote a file object for those links as well.

## NOTES

Creating a symbolic link on Windows requires the "Create symbolic links" user right, `SeCreateSymbolicLinkPrivilege`, which is granted to the Administrators group by default. Without that right, Windows rejects the operation with error 1314, "A required privilege is not held by the client", so run the cmdlet from an elevated session or grant the right to the account. Windows Developer Mode doesn't change this: it lets accounts without that right create symbolic links only in programs that request it, such as `mklink`, and the cmdlet doesn't.

Unlike a hard link, a symbolic link is a separate file system entry that stores a path, so it can point to an item on another volume and the link and its target can be managed independently. The cmdlet still requires the target to exist at the moment the link is created. If the target is removed later, the link remains and stops resolving.

If `-Path` already exists, `-Target` is missing, or a path contains a character that Windows doesn't allow, such as `|`, the cmdlet writes a non-terminating `CreateSymbolicLinkError` with the category `ResourceExists`, `ObjectNotFound`, or `InvalidArgument`, leaves the file system unchanged, and continues with the next object from the pipeline. It checks `-Path` before `-Target`, and the error for an existing `-Path` or a missing `-Target` names that path. When Windows refuses the link, such as with error 1314 without the right to create symbolic links, the cmdlet writes a `CreateSymbolicLinkError` as well.

Deleting a symbolic link removes the link only and leaves the target untouched. Delete a directory symbolic link as a link rather than recursively, so that the content of the target folder is not affected.

Before 5.0.0-rc7, `-Path` and `-Target` were optional: without `-Path`, the cmdlet failed with an index error, and without `-Target`, it created a link to the current folder. It stopped with a terminating error for an existing `-Path` or a link that Windows refused, in Windows PowerShell also for a path with a character that Windows doesn't allow, and every object piped to it failed with `GetDefaultValueFailed`. It checked `-Target` before `-Path`, and its errors for an existing `-Path` and a missing `-Target` named no path.

## RELATED LINKS

[New-NTFSHardLink](New-NTFSHardLink.md)

[Get-NTFSHardLink](Get-NTFSHardLink.md)

[Get-ChildItem2](Get-ChildItem2.md)

[Test-Path2](Test-Path2.md)
