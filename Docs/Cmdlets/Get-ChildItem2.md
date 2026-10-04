---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-ChildItem2.md
schema: 2.0.0
---

# Get-ChildItem2

## SYNOPSIS

Gets the files and folders in one or more folders, including paths longer than 260 characters.

## SYNTAX

```
Get-ChildItem2 [[-Path] <String[]>] [[-Filter] <String>] [-Recurse] [-Directory] [-File]
 [-Attributes <FileAttributes>] [-Hidden] [-System] [-ReadOnly] [-Force] [-SkipMountPoints]
 [-SkipSymbolicLinks] [-Depth <Int32>] [<CommonParameters>]
```

## DESCRIPTION

The `Get-ChildItem2` cmdlet lists the files and folders in the folders that you specify with `-Path`. It returns an `Alphaleonis.Win32.Filesystem.FileInfo` object for every file and an `Alphaleonis.Win32.Filesystem.DirectoryInfo` object for every folder. The cmdlet is the long-path counterpart of the built-in `Get-ChildItem` cmdlet: it enumerates the file system through the AlphaFS library (`Alphaleonis.Win32.Filesystem`) instead of `System.IO`, so it also returns items whose path is longer than the 260-character `MAX_PATH` limit.

If you omit `-Path`, the cmdlet lists the current location. Relative paths and the `.` and `..` notations are resolved against the current location. Each path must name a folder, and wildcard characters are not supported. The parameter accepts pipeline input by value and by the property name `FullName`, so you can pipe folders from `Get-ChildItem2` or `Get-Item2` into another `Get-ChildItem2` call, and you can pipe the result into `Get-NTFSAccess` and the other NTFSSecurity cmdlets.

By default the cmdlet returns the immediate content of each folder and omits hidden items. Use `-Recurse` to walk the whole tree, `-Depth` to limit how deep the recursion goes, `-Filter` to restrict the result by name, `-Directory` or `-File` to restrict it by item type, and `-Force`, `-Hidden`, `-System`, `-ReadOnly`, or `-Attributes` to restrict it by file attributes.

Two settings in the `PrivateData` section of the module manifest change the objects that this cmdlet emits. `GetFileSystemModeProperty` adds the `Mode` property, which shows the directory, archive, read-only, hidden, and system attributes in `darhs` notation. `IdentifyHardLinks` adds a `HardLinkCount` property to every file object. Both are `$true` by default and are read once when the cmdlet starts.

A folder that the cmdlet cannot read produces a non-terminating error, and the enumeration continues with the next folder. If a folder cannot be opened while `-Recurse` looks for subfolders, the cmdlet reports the problem as a verbose message instead, so run the command with the `-Verbose` common parameter if you need to know which branches were skipped.

## EXAMPLES

### Example 1: Find files with a path longer than MAX_PATH

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -File | Where-Object { $_.FullName.Length -gt 260 }
```

Walks the whole folder tree below `C:\Data` and returns the files whose full path is too long for the built-in `Get-ChildItem` cmdlet.

### Example 2: Read the permissions of every subfolder

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -Directory | Get-NTFSAccess
```

Lists every subfolder of `C:\Data` and pipes the objects to `Get-NTFSAccess`, which binds their `FullName` property to its own `-Path` parameter and returns the access control entries of each folder.

### Example 3: Limit the depth of a recursive listing

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse -Depth 1 -Filter '*.log'
```

Returns the log files in `C:\Data` and in its immediate subfolders. Without `-Depth`, the command would descend through the entire tree.

### Example 4: List hidden system files

```PowerShell
PS C:\> dir2 -Path C:\Data -Attributes Hidden, System
```

Uses the `dir2` alias and returns the items of `C:\Data` that have both the hidden and the system attribute.

## PARAMETERS

### -Attributes

Specifies a set of file attributes. The cmdlet returns only the items that have all the attributes you list; separate several values with commas, as in `-Attributes Hidden, System`. When you use this parameter, the cmdlet ignores `-Force`, `-Hidden`, `-System`, and `-ReadOnly`, and it returns matching hidden items without `-Force`.

```yaml
Type: FileAttributes
Parameter Sets: (All)
Aliases:
Accepted values: ReadOnly, Hidden, System, Directory, Archive, Device, Normal, Temporary, SparseFile, ReparsePoint, Compressed, Offline, NotContentIndexed, Encrypted, IntegrityStream, NoScrubData

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Depth

Specifies how many additional levels of subfolders a recursive listing covers. `-Depth` takes effect only together with `-Recurse`: `-Depth 0` limits the result to the content of the folders in `-Path`, `-Depth 1` adds one more level of subfolders, and so on. If you omit the parameter, `-Recurse` walks the entire tree.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Directory

Indicates that the cmdlet returns only folders. If you specify `-Directory` and `-File` together, `-Directory` wins. The parameter restricts the returned items only; `-Recurse` still descends into every subfolder.

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

### -File

Indicates that the cmdlet returns only files. The parameter is ignored if you also specify `-Directory`.

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

### -Filter

Specifies a name pattern that an item must match to be returned. The pattern supports the `*` and `?` wildcard characters, and the match ignores case. The default value is `*`, which returns every item. The pattern is applied to the name of each item, not to its path, and during a recursive listing it restricts only the returned items; the cmdlet still descends into every subfolder.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force

Indicates that the cmdlet also returns hidden items. Without `-Force`, hidden items are left out of the result. The parameter is ignored when you use `-Attributes`.

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

### -Hidden

Indicates that the cmdlet returns only hidden items. You do not need `-Force` in addition, because `-Hidden` implies it.

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

Specifies the folders whose content you want to list. Relative paths are resolved against the current location, and wildcard characters are not supported. If you omit this parameter, the cmdlet lists the current location. A value that points to a file returns that file, like `Get-ChildItem`, unless you use `-Directory`.

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

### -ReadOnly

Indicates that the cmdlet returns only items that have the read-only attribute. Hidden read-only items appear in the result only if you add `-Force`.

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

### -Recurse

Indicates that the cmdlet lists the content of all subfolders as well. Without `-Recurse`, only the immediate content of each folder in `-Path` is returned. Use `-Depth` to limit how far the recursion goes.

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

### -SkipMountPoints

Indicates that the cmdlet does not descend into volume mount points. The mount point itself is still returned as an item of its parent folder. The parameter takes effect only together with `-Recurse`.

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

### -SkipSymbolicLinks

Indicates that the cmdlet does not descend into folders that are symbolic links. The link itself is still returned as an item of its parent folder. The parameter takes effect only together with `-Recurse`, and it protects a recursive listing against loops that symbolic links can create.

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

### -System

Indicates that the cmdlet returns only items that have the system attribute. System files are often hidden as well, so combine this parameter with `-Force` or `-Hidden` to see them.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

You can pipe one or more folder paths to this cmdlet, either as strings or as objects that have a `FullName` property, such as the output of `Get-ChildItem2` or `Get-Item2`.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

The cmdlet returns this object for every file it finds. Depending on the module settings, the object carries the additional properties `Mode` and `HardLinkCount`.

### Alphaleonis.Win32.Filesystem.DirectoryInfo

The cmdlet returns this object for every folder it finds. Depending on the module settings, the object carries the additional property `Mode`.

## NOTES

`Get-ChildItem2` enumerates the file system through the AlphaFS library (`Alphaleonis.Win32.Filesystem`), which is why it returns items whose path exceeds the 260-character `MAX_PATH` limit that the built-in `Get-ChildItem` cmdlet is bound to. The objects are AlphaFS objects, not `System.IO` objects, and the other NTFSSecurity cmdlets accept them directly because their `-Path` parameters have the alias `FullName`.

The module defines the alias `dir2` for this cmdlet.

The default table view shows the `Mode`, `Inherits`, `LastWriteTime`, `Size(M)`, and `Name` columns. `Inherits` is `False` for an item whose access inheritance is disabled. Before 5.0.0, the column showed `True` for every item.

The `PrivateData` section of the module manifest `NTFSSecurity.psd1` contains two settings that this cmdlet reads when it starts. `GetFileSystemModeProperty` adds the calculated `Mode` property to every item. `IdentifyHardLinks` adds the `HardLinkCount` property to every file, which requires an extra call into the file system for each file and therefore slows down large listings noticeably. Set either value to `$false` in the manifest and import the module again if you prefer the faster enumeration over the additional properties.

A folder that cannot be read produces a non-terminating error with the ID `DirUnauthorizedAccessError` for an access denial or `DirUnspecifiedError` for any other failure, and a path that does not exist produces the error `FileNotFound`. In each case the cmdlet continues with the next path. Failures that occur while `-Recurse` collects the subfolders of a folder are reported as verbose messages only, not as errors.

Before 5.0.0, a `-Path` value that points to a file stopped the cmdlet with an `InvalidCastException`.

## RELATED LINKS

[Get-Item2](Get-Item2.md)

[Copy-Item2](Copy-Item2.md)

[Move-Item2](Move-Item2.md)

[Remove-Item2](Remove-Item2.md)

[Test-Path2](Test-Path2.md)

[Get-NTFSAccess](Get-NTFSAccess.md)
