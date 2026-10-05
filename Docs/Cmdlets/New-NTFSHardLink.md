---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/New-NTFSHardLink.md
schema: 2.0.0
---

# New-NTFSHardLink

## SYNOPSIS

Creates a hard link to an existing file.

## SYNTAX

```
New-NTFSHardLink [[-Path] <String>] [[-Target] <String>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `New-NTFSHardLink` cmdlet gives an existing file an additional name. `-Path` is the new hard link that the cmdlet creates, and `-Target` is the existing file that the new link refers to. Read the command as "create *Path*, which points to *Target*".

The cmdlet validates both ends before it creates the link. `-Path` must not exist yet, so the cmdlet never overwrites an existing file, and `-Target` must exist and must be a file. A folder as `-Target` is rejected, because NTFS supports hard links for files only. Relative paths are resolved against the current location.

After the link is created, both names refer to the same data on the volume. Writing through one name changes what the other name returns, and the file is only released when its last name is deleted.

By default the cmdlet produces no output. With `-PassThru` it returns one object for every hard link that the file has after the operation, which includes the original name and the new link, not just the link that was created.

## EXAMPLES

### Example 1: Give a file a second name

```PowerShell
PS C:\> New-NTFSHardLink -Path C:\Data\Report-Current.txt -Target C:\Data\Report-2026.txt
```

This command creates the new hard link `Report-Current.txt` for the existing file `Report-2026.txt`. Both names now refer to the same data, and no second copy of the content is stored.

### Example 2: Create a hard link with positional parameters

```PowerShell
PS C:\> New-NTFSHardLink C:\Data\Archive\Report.txt C:\Data\Report.txt
```

This command uses the positional form of the parameters. The first position is `-Path`, the new link, and the second position is `-Target`, the existing file. Both paths are on drive C, as a hard link and its target must be on the same volume.

### Example 3: Create a link and list all names of the file

```PowerShell
PS C:\> New-NTFSHardLink -Path C:\Data\Report-Current.txt -Target C:\Data\Report-2026.txt -PassThru
```

This command creates the link and then returns one object for every hard link of the file, so the output contains both `Report-2026.txt` and the new `Report-Current.txt`.

### Example 4: Verify the result

```PowerShell
PS C:\> Get-NTFSHardLink -Path C:\Data\Report-2026.txt | Select-Object -ExpandProperty FullName
```

This command lists all names of the file after the link was created, which is the same information that `-PassThru` returns.

## PARAMETERS

### -PassThru

Indicates that the cmdlet returns an object for every hard link of the file after the new link has been created, including the names that already existed. By default, this cmdlet produces no output.

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

Specifies the path of the new hard link that the cmdlet creates. The path must not exist yet, and it must be on the same NTFS volume as `-Target`. Relative paths are resolved against the current location.

```yaml
Type: String
Parameter Sets: (All)
Aliases: FullName

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Target

Specifies the path of the existing file that the new link refers to. The target must exist and must be a file; folders are rejected, because NTFS supports hard links for files only.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
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

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

With `-PassThru`, the cmdlet writes one file object per hard link of the file, extended with a `Mode` property that renders the file attributes in the same notation as `Get-ChildItem2`. Without `-PassThru`, the cmdlet writes nothing.

### Alphaleonis.Win32.Filesystem.DirectoryInfo

The cmdlet never writes folder objects, because hard links are supported for files only.

## NOTES

Windows supports hard links only for files on the same NTFS volume. A link that points to a file on another volume, or a target on a file system that does not implement hard links, cannot be created.

The cmdlet does not overwrite anything. If `-Path` already exists, or if `-Target` is missing or is a folder, the cmdlet reports an error and leaves the file system unchanged.

Because all names of a file share the same data, the number of hard links is a property of the file, not of an individual name. Use `Get-NTFSHardLink` to list them, and delete a link with `Remove-Item2` or `Remove-Item`, which removes only that name as long as other names remain.

Before 5.0.0, the error for a missing `-Target` said "The target path exist", the opposite of the cause.

## RELATED LINKS

[Get-NTFSHardLink](Get-NTFSHardLink.md)

[New-NTFSSymbolicLink](New-NTFSSymbolicLink.md)

[Get-ChildItem2](Get-ChildItem2.md)

[Remove-Item2](Remove-Item2.md)
