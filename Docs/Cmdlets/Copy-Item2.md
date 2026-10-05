---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Copy-Item2.md
schema: 2.0.0
---

# Copy-Item2

## SYNOPSIS

Copies a file to another location, including paths longer than 260 characters.

## SYNTAX

```
Copy-Item2 [-Path] <String[]> [-Destination] <String> [-Force] [-PassThru <Boolean>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION

The `Copy-Item2` cmdlet copies the items in `-Path` to the location in `-Destination`. It is the long-path counterpart of the built-in `Copy-Item` cmdlet: it works through the AlphaFS library (`Alphaleonis.Win32.Filesystem`), so source and destination may be longer than the 260-character `MAX_PATH` limit.

How `-Destination` is interpreted depends on what is already there. If the value names an existing folder, the cmdlet keeps the name of the source item and copies it into that folder. In every other case the value is the full path of the new item, which lets you copy and rename in one step. `-Destination` is resolved against the current location once, when the cmdlet starts.

Without `-Force`, the cmdlet checks whether the destination file already exists and writes a `DestinationFileAlreadyExists` error instead of overwriting it. With `-Force`, an existing file is replaced. Relative paths and the `.` and `..` notations in `-Path` are resolved against the current location, and wildcard characters are not supported.

The cmdlet supports `-WhatIf` and `-Confirm`, and it writes nothing to the pipeline unless you specify `-PassThru $true`.

## EXAMPLES

### Example 1: Copy a file into a folder

```PowerShell
PS C:\> Copy-Item2 -Path C:\Data\report.docx -Destination C:\Data\Archive
```

Copies `report.docx` into the existing folder `C:\Data\Archive`, where it keeps its name. The command fails if `C:\Data\Archive\report.docx` already exists.

### Example 2: Copy and rename a file in one step

```PowerShell
PS C:\> Copy-Item2 -Path C:\Data\report.docx -Destination C:\Data\Archive\report-2026.docx -Force
```

Copies the file under a new name and, because of `-Force`, replaces an existing `report-2026.docx`.

### Example 3: Copy files with very long paths

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data\Projects -Recurse -File -Filter '*.log' | Copy-Item2 -Destination C:\Data\Logs -Force
```

Collects every log file below `C:\Data\Projects`, no matter how long its path is, and copies them all into `C:\Data\Logs`. Because each file keeps only its name, the files from the different source folders end up side by side in the target folder.

### Example 4: Preview a copy operation

```PowerShell
PS C:\> Copy-Item2 -Path C:\Data\report.docx -Destination C:\Data\Archive -WhatIf
```

Shows which operation the cmdlet would perform without copying anything.

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

Specifies the target of the copy operation. If the value names an existing folder, the cmdlet copies the item into that folder under its current name; otherwise the value is the full path of the new item. The path is resolved against the current location once, when the cmdlet starts, so pass an absolute path when you supply `-Destination` through the pipeline.

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

Indicates that the cmdlet overwrites an existing destination file. Without `-Force`, an existing file causes the error `DestinationFileAlreadyExists` and the item is not copied.

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

Specifies whether the cmdlet returns an object for each item that it copied. This parameter is typed `Boolean` rather than a switch, so it needs an explicit value, as in `-PassThru $true`. By default, the cmdlet produces no output. After a successful file copy, the returned object describes the file at the destination path.

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

Specifies the path of one or more items to copy. Relative paths are resolved against the current location, and wildcard characters are not supported. The parameter accepts pipeline input by value and by the property name `FullName`, so you can pipe the output of `Get-ChildItem2` or `Get-Item2` into this cmdlet.

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

You can pipe an object that has a `Destination` property to supply the target of the copy operation.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

By default this cmdlet returns nothing. With `-PassThru $true` it returns a file object for each file that it copied, pointing at the copy.

### Alphaleonis.Win32.Filesystem.DirectoryInfo

With `-PassThru $true` the cmdlet returns a folder object for each folder that it copied, pointing at the copy.

## NOTES

`Copy-Item2` copies through the AlphaFS library (`Alphaleonis.Win32.Filesystem`), which is why it handles source and destination paths that exceed the 260-character `MAX_PATH` limit of the built-in `Copy-Item` cmdlet.

Before 5.0.0, `-PassThru` also wrote the item when `-WhatIf` or a declined confirmation skipped the operation.

Before 5.0.0, copying a folder that contained files failed with a `CopyError` that reported a `DirectoryNotFoundException` for the first file in the folder.

If a path in `-Path` does not exist or the destination file exists and `-Force` is missing, the cmdlet writes a non-terminating error and continues with the next path. Before 5.0.0, it skipped the remaining paths that were passed in the same call.

## RELATED LINKS

[Move-Item2](Move-Item2.md)

[Remove-Item2](Remove-Item2.md)

[Get-ChildItem2](Get-ChildItem2.md)

[Get-Item2](Get-Item2.md)

[Test-Path2](Test-Path2.md)
