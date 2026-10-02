---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-NTFSHardLink.md
schema: 2.0.0
---

# Get-NTFSHardLink

## SYNOPSIS

Gets all hard links that refer to the same file as the specified path.

## SYNTAX

```
Get-NTFSHardLink [[-Path] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

On an NTFS volume, a file is a block of data that one or more directory entries, called hard links, refer to. The `Get-NTFSHardLink` cmdlet asks the file system for every hard link of the file that `-Path` points to and writes a file object for each of them, including the name that you passed in.

A file that has only one name returns a single object. A file that has additional hard links returns one object per name, which lets you find all the places on the volume from which the same data is reachable. The file system reports the links relative to the root of the volume, and the cmdlet combines them with the root of the path you specify, so the result contains full paths. All hard links of a file are always on the same volume as the file.

`-Path` must point to a file. A folder causes an error, because NTFS does not support hard links to folders. If you omit `-Path`, the cmdlet falls back to the current location, which is a folder and therefore produces the same error, so always pass the path of a file.

The parameter accepts an array of paths and takes pipeline input by value and by property name through its `FullName` alias. `Get-ChildItem2` adds a `HardLinkCount` property to each file as long as the `IdentifyHardLinks` entry in the `PrivateData` section of the module manifest is `$true`, which lets you select the files that have more than one name before you resolve them.

## EXAMPLES

### Example 1: Get all names of a file

```PowerShell
PS C:\> Get-NTFSHardLink -Path C:\Data\Report.txt
```

This command returns one object for every hard link of `Report.txt`, including `Report.txt` itself. If the file has no additional links, the command returns that single file.

### Example 2: List the full paths of all hard links

```PowerShell
PS C:\> Get-NTFSHardLink -Path C:\Data\Report.txt | Select-Object -ExpandProperty FullName
```

This command returns the full path of every name under which the data of `Report.txt` is reachable on the volume.

### Example 3: Resolve the hard links of all multi-link files in a folder

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Where-Object { $_.HardLinkCount -gt 1 } | Get-NTFSHardLink
```

This command uses the `HardLinkCount` property that `Get-ChildItem2` adds to files to select the files that have more than one name, and then resolves all names of each of them.

### Example 4: Count the names of a file

```PowerShell
PS C:\> (Get-NTFSHardLink -Path C:\Data\Report.txt).Count
```

This command returns the number of hard links that refer to the data of `Report.txt`. A result of `1` means that deleting the file releases its data.

## PARAMETERS

### -Path

Specifies the path of one or more files whose hard links you want to resolve. The path must point to a file; folders cause an error. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

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

You can pipe one or more file path strings, or objects that have a `FullName` property such as the output of `Get-ChildItem2` and `Get-Item2`, to this cmdlet.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

The cmdlet writes one file object per hard link of the file, extended with a `Mode` property that renders the file attributes in the same notation as `Get-ChildItem2`.

### Alphaleonis.Win32.Filesystem.DirectoryInfo

The cmdlet never writes folder objects, because it rejects folders with the error `The item must be a file`.

## NOTES

Hard links exist only within a single NTFS volume. Every object that this cmdlet returns therefore refers to a path on the volume of the file that you passed in.

Because all hard links of a file share the same data, they also share the file content, the file size, and the time stamps. The security descriptor is stored with the file as well, so changing permissions through one name changes them for every name.

The cmdlet resolves paths through the AlphaFS library and therefore also works with paths that exceed the 260-character `MAX_PATH` limit.

## RELATED LINKS

[New-NTFSHardLink](New-NTFSHardLink.md)

[New-NTFSSymbolicLink](New-NTFSSymbolicLink.md)

[Get-ChildItem2](Get-ChildItem2.md)

[Get-Item2](Get-Item2.md)
