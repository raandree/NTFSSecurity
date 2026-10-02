---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-Item2.md
schema: 2.0.0
---

# Get-Item2

## SYNOPSIS

Gets the file or folder at a specified path, including paths longer than 260 characters.

## SYNTAX

```
Get-Item2 [[-Path] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

The `Get-Item2` cmdlet gets the item at a location and returns an `Alphaleonis.Win32.Filesystem.FileInfo` object for a file or an `Alphaleonis.Win32.Filesystem.DirectoryInfo` object for a folder. It is the long-path counterpart of the built-in `Get-Item` cmdlet: it works through the AlphaFS library (`Alphaleonis.Win32.Filesystem`) instead of `System.IO`, so it also reaches items whose path is longer than the 260-character `MAX_PATH` limit.

If you omit `-Path`, the cmdlet returns the item for the current location. Relative paths and the `.` and `..` notations are resolved against the current location as well. Wildcard characters are not supported, so each value of `-Path` must name one existing file or folder. For a path that does not exist, the cmdlet writes a non-terminating error and continues with the remaining paths.

Every returned object carries an additional `Mode` property that reports the directory, archive, read-only, hidden, and system attributes in the same `darhs` notation that `Get-ChildItem` uses. Because the objects expose a `FullName` property and the `-Path` parameters of the NTFSSecurity cmdlets have the alias `FullName`, you can pipe the result straight into cmdlets such as `Get-NTFSAccess`, `Add-NTFSAccess`, or `Get-NTFSOwner`.

## EXAMPLES

### Example 1: Get a folder

```PowerShell
PS C:\> Get-Item2 -Path C:\Data
```

Returns the `DirectoryInfo` object for the `C:\Data` folder.

### Example 2: Read the permissions of a deeply nested file

```PowerShell
PS C:\> Get-Item2 -Path C:\Data\Projects\Archive\2026\Q1\Reports\Regional\Summary.docx | Get-NTFSAccess
```

Gets the file and pipes it to `Get-NTFSAccess`, which binds the `FullName` property of the object to its own `-Path` parameter. The command also works when the full path is longer than 260 characters.

### Example 3: Get several items from the pipeline

```PowerShell
PS C:\> 'C:\Data', 'C:\Data\Reports' | Get-Item2 | Select-Object Mode, LastWriteTime, FullName
```

Pipes two paths into the cmdlet and shows the attribute mode, the last write time, and the full path of each item.

### Example 4: Use the alias and the positional parameter

```PowerShell
PS C:\> gi2 C:\Data\report.docx
```

Uses the `gi2` alias and passes the path positionally to get a single file.

## PARAMETERS

### -Path

Specifies the path of one or more files or folders. Relative paths are resolved against the current location, and wildcard characters are not supported. If you omit this parameter, the cmdlet returns the item for the current location.

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

You can pipe one or more paths to this cmdlet, either as strings or as objects that have a `FullName` property, such as the output of `Get-ChildItem2` or `Get-Item2`.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

The cmdlet returns this object for every path that points to a file, extended with a `Mode` property.

### Alphaleonis.Win32.Filesystem.DirectoryInfo

The cmdlet returns this object for every path that points to a folder, extended with a `Mode` property.

## NOTES

`Get-Item2` builds on the AlphaFS library (`Alphaleonis.Win32.Filesystem`), which is why it reaches files and folders whose path exceeds the 260-character `MAX_PATH` limit that the built-in `Get-Item` cmdlet is bound to. The objects it returns are AlphaFS objects, not `System.IO` objects, and the other NTFSSecurity cmdlets accept them directly through the `FullName` alias of their `-Path` parameters.

The module defines the alias `gi2` for this cmdlet.

`Get-Item2` always adds the `Mode` property. The `GetFileSystemModeProperty` setting in the `PrivateData` section of the module manifest controls only `Get-ChildItem2`.

## RELATED LINKS

[Get-ChildItem2](Get-ChildItem2.md)

[Copy-Item2](Copy-Item2.md)

[Move-Item2](Move-Item2.md)

[Remove-Item2](Remove-Item2.md)

[Test-Path2](Test-Path2.md)

[Get-NTFSAccess](Get-NTFSAccess.md)
