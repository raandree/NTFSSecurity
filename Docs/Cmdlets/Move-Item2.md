---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Move-Item2.md
schema: 2.0.0
---

# Move-Item2

## SYNOPSIS

Moves a file or folder to another location, including paths longer than 260 characters.

## SYNTAX

```
Move-Item2 [-Path] <String[]> [-Destination] <String> [-Force] [-PassThru <Boolean>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION

The `Move-Item2` cmdlet moves the items in `-Path` to the location in `-Destination`. It is the long-path counterpart of the built-in `Move-Item` cmdlet: it works through the AlphaFS library (`Alphaleonis.Win32.Filesystem`), so source and destination may be longer than the 260-character `MAX_PATH` limit. Files and folders can both be moved, and a folder is moved with everything it contains.

How `-Destination` is interpreted depends on what is already there. If the value names an existing folder, the cmdlet keeps the name of the source item and moves it into that folder. In every other case the value is the full path of the new item, which lets you move and rename in one step, or rename an item in place. `-Destination` is resolved against the current location once, when the cmdlet starts.

Without `-Force`, the cmdlet checks whether the destination file already exists and writes a `DestinationFileAlreadyExists` error instead of overwriting it; the move itself then runs with the `CopyAllowed` option, which allows a file to move to a different volume. With `-Force`, the move runs with the `ReplaceExisting` option and overwrites an existing destination item.

The cmdlet supports `-WhatIf` and `-Confirm`, and it writes nothing to the pipeline unless you specify `-PassThru $true`.

## EXAMPLES

### Example 1: Move a file into a folder

```PowerShell
PS C:\> Move-Item2 -Path C:\Data\report.docx -Destination C:\Data\Archive
```

Moves `report.docx` into the existing folder `C:\Data\Archive`, where it keeps its name.

### Example 2: Rename an item

```PowerShell
PS C:\> Move-Item2 -Path C:\Data\Archive\report.docx -Destination C:\Data\Archive\report-2026.docx
```

Moves the file to a new path inside the same folder, which renames it.

### Example 3: Move a folder with a very long path

```PowerShell
PS C:\> Move-Item2 -Path C:\Data\Projects\Archive\2026\Q1\Reports\Regional\Northwest -Destination C:\Data\Archive\Northwest -PassThru $true
```

Moves the folder and everything it contains, even when the paths below it exceed 260 characters, and returns the folder object at its new location.

### Example 4: Preview a move operation

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -File -Filter '*.tmp' | Move-Item2 -Destination C:\Data\Temp -WhatIf
```

Shows which temporary files the cmdlet would move into `C:\Data\Temp` without moving anything. Remove `-WhatIf` to carry the operation out.

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Destination

Specifies the target of the move operation. If the value names an existing folder, the cmdlet moves the item into that folder under its current name; otherwise the value is the full path of the new item. The path is resolved against the current location once, when the cmdlet starts, so pass an absolute path when you supply `-Destination` through the pipeline.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Force

Indicates that the cmdlet replaces an existing destination item. Without `-Force`, an existing destination file causes the error `DestinationFileAlreadyExists` and the item is not moved.

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

### -PassThru

Specifies whether the cmdlet returns an object for each item that it moved. This parameter is typed `Boolean` rather than a switch, so it needs an explicit value, as in `-PassThru $true`. By default, the cmdlet produces no output. The returned object describes the item at its new location.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path

Specifies the path of one or more items to move. Relative paths are resolved against the current location, and wildcard characters are not supported. The parameter accepts pipeline input by value and by the property name `FullName`, so you can pipe the output of `Get-ChildItem2` or `Get-Item2` into this cmdlet.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -WhatIf

Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

You can pipe one or more paths to this cmdlet, either as strings or as objects that have a `FullName` property, such as the output of `Get-ChildItem2` or `Get-Item2`.

### System.String

You can pipe an object that has a `Destination` property to supply the target of the move operation.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

By default this cmdlet returns nothing. With `-PassThru $true` it returns a file object for each file that it moved, pointing at the new location.

### Alphaleonis.Win32.Filesystem.DirectoryInfo

With `-PassThru $true` the cmdlet returns a folder object for each folder that it moved, pointing at the new location.

## NOTES

`Move-Item2` moves through the AlphaFS library (`Alphaleonis.Win32.Filesystem`), which is why it handles source and destination paths that exceed the 260-character `MAX_PATH` limit of the built-in `Move-Item` cmdlet.

Before 5.0.0, `-PassThru` also wrote the item when `-WhatIf` or a declined confirmation skipped the operation.

The cmdlet chooses between two mutually exclusive move options. Without `-Force` it moves with `CopyAllowed`, which permits a file to cross volume boundaries because Windows then copies and deletes it. With `-Force` it moves with `ReplaceExisting`, which overwrites the destination but does not request `CopyAllowed`, so a move across volumes can fail when `-Force` is specified.

If a path in `-Path` does not exist or the destination file exists and `-Force` is missing, the cmdlet writes a non-terminating error and continues with the next path. Before 5.0.0, it skipped the remaining paths that were passed in the same call.

## RELATED LINKS

[Copy-Item2](Copy-Item2.md)

[Remove-Item2](Remove-Item2.md)

[Get-ChildItem2](Get-ChildItem2.md)

[Get-Item2](Get-Item2.md)

[Test-Path2](Test-Path2.md)
