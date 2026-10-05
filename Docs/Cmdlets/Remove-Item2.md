---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Remove-Item2.md
schema: 2.0.0
---

# Remove-Item2

## SYNOPSIS

Deletes a file or folder, including paths longer than 260 characters.

## SYNTAX

```
Remove-Item2 [[-Path] <String[]>] [-Force] [-Recurse] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

The `Remove-Item2` cmdlet deletes the files and folders in `-Path`. It is the long-path counterpart of the built-in `Remove-Item` cmdlet: it works through the AlphaFS library (`Alphaleonis.Win32.Filesystem`), so it also deletes items whose path exceeds the 260-character `MAX_PATH` limit. The items are deleted permanently and are not moved to the Recycle Bin.

Relative paths and the `.` and `..` notations are resolved against the current location, and wildcard characters are not supported. `-Path` has no default value: if you omit it, the cmdlet does nothing. Use `-Recurse` to delete a folder that is not empty and `-Force` to delete items that have the read-only attribute.

The cmdlet supports `-WhatIf` and `-Confirm`, and it writes nothing to the pipeline unless you specify `-PassThru`.

## EXAMPLES

### Example 1: Delete a file

```PowerShell
PS C:\> Remove-Item2 -Path C:\Data\report.docx
```

Deletes a single file. If the file is read-only, the command fails with a `DeleteError` until you add `-Force`.

### Example 2: Delete a folder tree with very long paths

```PowerShell
PS C:\> Remove-Item2 -Path C:\Data\Projects\Archive -Recurse -Force
```

Deletes the folder with everything it contains, including read-only files and files whose path is too long for the built-in `Remove-Item` cmdlet.

### Example 3: Preview what would be deleted

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -File -Filter '*.tmp' | Remove-Item2 -WhatIf
```

Lists every temporary file below `C:\Data` and shows which of them the cmdlet would delete. Remove `-WhatIf` to delete them.

### Example 4: Delete items and keep a record of them

```PowerShell
PS C:\> rm2 -Path C:\Data\Logs\old.log -PassThru | Select-Object -ExpandProperty FullName
```

Uses the `rm2` alias and returns the object of the deleted file, from which the command takes the full path for a log. Since the item no longer exists, only its path information is still meaningful; properties such as `Length` are empty.

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

### -Force

Indicates that the cmdlet also deletes items that have the read-only attribute. Without `-Force`, a read-only item causes a `DeleteError`. Combine `-Force` with `-Recurse` to delete a folder that contains read-only files.

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

Indicates that the cmdlet returns an object for each item that it deleted. By default, the cmdlet produces no output. The object describes a path that no longer exists, so use it for logging rather than for further file operations. `-PassThur`, the name of this parameter in NTFSSecurity 4.2.6 and earlier, still works as an alias.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: PassThur

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path

Specifies the path of one or more items to delete. Relative paths are resolved against the current location, and wildcard characters are not supported. The parameter has no default value, so the cmdlet deletes nothing if you omit it. It accepts pipeline input by value and by the property name `FullName`, so you can pipe the output of `Get-ChildItem2` or `Get-Item2` into this cmdlet.

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

### -Recurse

Indicates that the cmdlet deletes a folder together with everything it contains. Without `-Recurse`, a folder that is not empty causes a `DeleteError`. The parameter has no effect on files.

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

## OUTPUTS

### System.Object

By default this cmdlet returns nothing. With `-PassThru` it returns an `Alphaleonis.Win32.Filesystem.FileInfo` or `Alphaleonis.Win32.Filesystem.DirectoryInfo` object for each item that it deleted.

## NOTES

`Remove-Item2` deletes through the AlphaFS library (`Alphaleonis.Win32.Filesystem`), which is why it reaches items whose path exceeds the 260-character `MAX_PATH` limit of the built-in `Remove-Item` cmdlet. Deletion is permanent; the cmdlet does not use the Recycle Bin.

The module defines the aliases `rm2` and `del2` for this cmdlet.

A path that does not exist causes the error `FileNotFound`, and a deletion that the file system rejects causes a `DeleteError`. In both cases the cmdlet continues with the next path. Before 5.0.0, a path that did not exist made the cmdlet skip the remaining paths that were passed in the same call.

## RELATED LINKS

[Copy-Item2](Copy-Item2.md)

[Move-Item2](Move-Item2.md)

[Get-ChildItem2](Get-ChildItem2.md)

[Get-Item2](Get-Item2.md)

[Test-Path2](Test-Path2.md)
