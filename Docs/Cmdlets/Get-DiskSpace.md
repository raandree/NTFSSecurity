---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-DiskSpace.md
schema: 2.0.0
---

# Get-DiskSpace

## SYNOPSIS

Gets size, free space, and cluster information for the volumes of a computer.

## SYNTAX

```
Get-DiskSpace [[-DriveLetter] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

The `Get-DiskSpace` cmdlet returns one `DiskSpaceInfo` object per volume. The object describes how large the volume is, how much space is free, and how the volume is organized into sectors and clusters.

When you omit `-DriveLetter`, the cmdlet enumerates all volumes of the computer, including volumes that have no drive letter, and returns the ones that report a total size greater than zero. Volumes that report a size of zero, such as an empty removable drive, are skipped silently, and a volume whose details cannot be read produces a warning instead of an object.

Each returned object exposes the following properties:

- `DriveName`: the volume the object describes.
- `TotalNumberOfBytes`, `TotalNumberOfFreeBytes`, and `FreeBytesAvailable`: the size of the volume, the free space on it, and the free space that is available to the account that runs the cmdlet, all as 64-bit byte counts.
- `TotalSizeUnitSize`, `UsedSpaceUnitSize`, and `AvailableFreeSpaceUnitSize`: the same figures formatted as readable strings.
- `UsedSpacePercent` and `AvailableFreeSpacePercent`: used and free space as formatted percentage strings.
- `BytesPerSector`, `SectorsPerCluster`, `ClusterSize`, `TotalNumberOfClusters`, and `NumberOfFreeClusters`: the sector and cluster layout of the volume.

The percentage and unit-size properties are strings that are meant for display. Use the byte and cluster properties when you need to calculate or compare values.

The cmdlet only reads volume information and does not change anything on disk. `-DriveLetter` does not accept pipeline input.

## EXAMPLES

### Example 1: Get the disk space of every volume

```PowerShell
PS C:\> Get-DiskSpace
```

This command returns one object for every volume of the computer, including volumes that are mounted without a drive letter.

### Example 2: Get the disk space of a single drive

```PowerShell
PS C:\> Get-DiskSpace -DriveLetter C:
```

This command returns the size and free space of drive C. The drive letter must be written as a letter followed by a colon.

### Example 3: Show a readable summary of two drives

```PowerShell
PS C:\> Get-DiskSpace -DriveLetter C:, D: | Select-Object -Property DriveName, TotalSizeUnitSize, AvailableFreeSpaceUnitSize, AvailableFreeSpacePercent
```

This command returns the formatted size and free space strings of drives C and D, which are easier to read than the raw byte counts.

### Example 4: Find volumes with little free space

```PowerShell
PS C:\> Get-DiskSpace | Where-Object { $_.TotalNumberOfFreeBytes -lt 10GB }
```

This command returns every volume that has less than 10 GB of free space. The filter uses `TotalNumberOfFreeBytes` because the percentage properties are formatted strings and cannot be compared numerically.

## PARAMETERS

### -DriveLetter

Specifies one or more drives to query. Each value must be a single letter followed by a colon, such as `C:`; other forms, including `C` and `C:\`, are rejected. When you omit this parameter, the cmdlet queries all volumes of the computer, including volumes without a drive letter.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

This cmdlet does not accept pipeline input. Pass the drives to query with the `-DriveLetter` parameter.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.DiskSpaceInfo

The cmdlet writes one `DiskSpaceInfo` object per queried volume that reports a total size greater than zero. The object carries the size, free space, percentage, and cluster properties that are listed in the description.

## NOTES

A volume that cannot be queried, for example a drive that is not ready, produces a warning that names the volume. Use `-WarningAction SilentlyContinue` to suppress those warnings when you query all volumes.

Because the cmdlet enumerates volumes rather than drive letters when `-DriveLetter` is omitted, the result can contain volumes that are mounted into a folder or that have no mount point at all.

## RELATED LINKS

[Get-ChildItem2](Get-ChildItem2.md)

[Get-Item2](Get-Item2.md)

[Get-FileHash2](Get-FileHash2.md)
