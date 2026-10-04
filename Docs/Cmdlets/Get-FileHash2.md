---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-FileHash2.md
schema: 2.0.0
---

# Get-FileHash2

## SYNOPSIS

Gets the hash value of one or more files.

## SYNTAX

```
Get-FileHash2 [-Path] <String[]> [[-Algorithm] <HashAlgorithms>] [<CommonParameters>]
```

## DESCRIPTION

The `Get-FileHash2` cmdlet calculates the hash value of each file that `-Path` points to and returns the file object with the result attached. The returned object is the file object of the file, extended with a `Hash` property that holds the hash as an uppercase hexadecimal string and an `Algorithm` property that names the algorithm that was used. The module's formatting data displays those objects as a table with the `Algorithm`, `Hash`, and `FullName` columns.

`-Algorithm` selects the hash algorithm and accepts `SHA1`, `SHA256`, `SHA384`, `SHA512`, `MACTripleDES`, `MD5`, and `RIPEMD160`. The default is `SHA256`.

The cmdlet hashes files only and skips paths that point to folders. A path that does not exist produces a non-terminating `ReadFileError`.

`-Path` accepts pipeline input by value and by property name through its `FullName` alias, so you can pipe the output of `Get-ChildItem2`, `Get-Item2`, or `Get-ChildItem` into the cmdlet; folders that arrive through the pipeline are skipped individually. Because the cmdlet reads files through the AlphaFS library, it also hashes files whose path exceeds the 260-character `MAX_PATH` limit. Relative paths are resolved against the current location.

## EXAMPLES

### Example 1: Get the SHA256 hash of a file

```PowerShell
PS C:\> Get-FileHash2 -Path C:\Data\Report.txt
```

This command calculates the hash of `Report.txt` with the default `SHA256` algorithm and returns the file object with the `Algorithm` and `Hash` properties attached.

### Example 2: Get the MD5 hash of a file

```PowerShell
PS C:\> Get-FileHash2 -Path C:\Data\Report.txt -Algorithm MD5
```

This command calculates the `MD5` hash of the same file. `MD5` and `SHA1` are fast but are no longer considered collision resistant, so use them for change detection rather than for security decisions.

### Example 3: Hash every file in a folder tree

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-FileHash2 -Algorithm SHA1 | Select-Object -Property Algorithm, Hash, FullName
```

This command pipes all items below `C:\Data` into `Get-FileHash2`. The cmdlet binds the `FullName` property of each item to `-Path`, hashes the files, and skips the folders.

### Example 4: Find files with identical content

```PowerShell
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-FileHash2 | Group-Object -Property Hash | Where-Object { $_.Count -gt 1 }
```

This command groups the files below `C:\Data` by hash value and returns the groups that contain more than one file, which identifies files whose content is identical.

## PARAMETERS

### -Algorithm

Specifies the hash algorithm to use. The accepted values are `SHA1`, `SHA256`, `SHA384`, `SHA512`, `MACTripleDES`, `MD5`, and `RIPEMD160`. When you omit this parameter, the cmdlet uses `SHA256`.

```yaml
Type: HashAlgorithms
Parameter Sets: (All)
Aliases:
Accepted values: SHA1, SHA256, SHA384, SHA512, MACTripleDES, MD5, RIPEMD160

Required: False
Position: 2
Default value: SHA256
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Path

Specifies the path of one or more files to hash. Folders are skipped. Relative paths are resolved against the current location. The parameter accepts pipeline input by value and by property name through its `FullName` alias.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

You can pipe one or more path strings, or objects that have a `FullName` property such as the output of `Get-ChildItem2` and `Get-Item2`, to this cmdlet.

### Security2.FileSystem.FileInfo.HashAlgorithms

You can supply the `-Algorithm` value through a pipeline object that has an `Algorithm` property.

## OUTPUTS

### Alphaleonis.Win32.Filesystem.FileInfo

For every hashed file, the cmdlet writes the file object of that file, decorated with the type name `Alphaleonis.Win32.Filesystem.FileInfo+Hash` and extended with the `Hash` and `Algorithm` note properties, so all regular file properties such as `FullName`, `Name`, and `Length` remain available.

## NOTES

The cmdlet works only in Windows PowerShell. In PowerShell 7, it fails for every algorithm with the error `Could not load type 'System.Security.Cryptography.RIPEMD160'`, because .NET no longer includes the RIPEMD-160 implementation that the cmdlet references. In PowerShell 7, use the built-in `Get-FileHash` cmdlet instead.

If the file cannot be opened because access is denied, the cmdlet takes ownership of the file with the account that runs it, calculates the hash, and restores the previous owner afterward. That fallback fails with a `GetHashError` when the account is not allowed to change the owner of the file. A file that cannot be read produces a `GetHashError` and no result.

The hash is returned as an uppercase hexadecimal string without separators, which differs from the lowercase output of some other hashing tools. Compare hash values case-insensitively.

`MACTripleDES` is a keyed message authentication code that is created with a key that is generated for each call, so its result is not reproducible across invocations and is not suitable for comparing files.

Before 5.0.0, a folder in a `-Path` array stopped the processing of that array, so the files that followed the folder were not hashed, and a file that could not be read got a result with the hash of the previous file.

## RELATED LINKS

[Get-ChildItem2](Get-ChildItem2.md)

[Get-Item2](Get-Item2.md)

[Test-Path2](Test-Path2.md)

[Copy-Item2](Copy-Item2.md)
