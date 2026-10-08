---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Test-Path2.md
schema: 2.0.0
---

# Test-Path2

## SYNOPSIS

Determines whether a file or folder exists at the specified path.

## SYNTAX

```
Test-Path2 [-Path] <String[]> [-PathType <TestPathType>] [<CommonParameters>]
```

## DESCRIPTION

The `Test-Path2` cmdlet returns `$true` when an item exists at the specified path and `$false` when it does not. It resolves paths with the AlphaFS library instead of the Windows PowerShell file system provider, so it also reports items whose full path exceeds the 260-character `MAX_PATH` limit, where the built-in `Test-Path` cmdlet returns `$false`.

The `-PathType` parameter narrows the test. `Any`, the default, returns `$true` for a file and for a folder, `Container` returns `$true` only for a folder, and `Leaf` returns `$true` only for a file. A path that does not exist returns `$false` for every `-PathType` value.

`-Path` accepts an array of paths and writes one Boolean value for each of them, in the order in which they are passed. The parameter takes pipeline input by value and by property name through its `FullName` alias, so the output of `Get-ChildItem2`, `Get-Item2`, and `Get-ChildItem` binds to it. Relative paths are resolved against the current location.

## EXAMPLES

### Example 1: Test whether a file exists

```PowerShell
PS C:\> Test-Path2 -Path C:\Data\Report.txt
```

This command returns `$true` when `Report.txt` exists in the `C:\Data` folder, regardless of whether it is a file or a folder.

### Example 2: Test whether a path is a folder

```PowerShell
PS C:\> Test-Path2 -Path C:\Data -PathType Container
```

This command returns `$true` only when `C:\Data` exists and is a folder. If `C:\Data` is a file, the command returns `$false`.

### Example 3: Test several paths at once

```PowerShell
PS C:\> Test-Path2 -Path C:\Data\Report.txt, C:\Data\Archive\Report.txt -PathType Leaf
```

This command tests both paths and writes one Boolean value for each of them, in the order in which they are given.

### Example 4: Test paths that come from the pipeline

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Test-Path2 -PathType Leaf
```

This command pipes every item below `C:\Data` to `Test-Path2`, which binds the `FullName` property of each item to `-Path` and reports `$true` for the files and `$false` for the folders.

## PARAMETERS

### -Path

Specifies one or more paths to test. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

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

### -PathType

Specifies the kind of item that the path must point to. `Any`, the default, matches a file and a folder, `Container` matches only a folder, and `Leaf` matches only a file.

```yaml
Type: TestPathType
Parameter Sets: (All)
Aliases:
Accepted values: Any, Container, Leaf

Required: False
Position: Named
Default value: Any
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

You can pipe one or more path strings, or objects that have a `FullName` property such as the output of `Get-ChildItem2` and `Get-Item2`, to this cmdlet.

### NTFSSecurity.TestPathType

You can supply the `-PathType` value through a pipeline object that has a `PathType` property.

## OUTPUTS

### System.Boolean

For each path, the cmdlet writes `$true` when the item exists and matches `-PathType`, and `$false` otherwise.

## NOTES

The cmdlet resolves paths through the AlphaFS library, which is not bound by the 260-character `MAX_PATH` limit of the Windows PowerShell file system provider. Use `Test-Path2` instead of `Test-Path` when a path can be longer than that limit.

A path that does not exist is not an error condition. The cmdlet writes `$false` and continues with the next path. This also applies to a path with a character that Windows doesn't allow in names, such as `|` or `<`; before 5.0.0, such a path stopped the cmdlet with the terminating error "Illegal characters in path" in Windows PowerShell.

## RELATED LINKS

[Get-Item2](Get-Item2.md)

[Get-ChildItem2](Get-ChildItem2.md)

[Get-FileHash2](Get-FileHash2.md)

[Remove-Item2](Remove-Item2.md)
