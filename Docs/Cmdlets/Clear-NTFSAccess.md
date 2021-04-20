---
external help file: NTFSSecurity.dll-Help.xml
Module Name: ntfssecurity
online version:
schema: 2.0.0
---

# Clear-NTFSAccess

## SYNOPSIS

Removes all access control entries from a file or folder.

## SYNTAX

### Path (Default)
```
Clear-NTFSAccess [-Path] <String[]> [-DisableInheritance] [<CommonParameters>]
```

### SD
```
Clear-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-DisableInheritance] [<CommonParameters>]
```

## DESCRIPTION

{{ Fill in the Description }}

## EXAMPLES

### Example 1

```PowerShell
PS C:\> Clear-NTFSAccess -Path C:\Data\ -DisableInheritance
```

The above example would remove all access control entries from the folder C:\Data and disable inheritance on the folder as well.

## PARAMETERS

### -DisableInheritance

The DisableInheritance parameter defines if you would like to didable the inheritance on the file or folder when clearing permissions.

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

The Path parameter defines where the file or container exists to remove the access control entries from.

```yaml
Type: String[]
Parameter Sets: Path
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -SecurityDescriptor

The SecurityDescriptor parameter allows passing an security descriptor or an array or security descriptors.

A security descriptor contains information about the owner of the object, and the primary group of an object. The security descriptor also contains two access control lists (ACL). The first list is called the discretionary access control lists (DACL), and describes who should have access to an object and what type of access to grant. The second list is called the system access control lists (SACL) and defines what type of auditing to record for an object.

```yaml
Type: FileSystemSecurity2[]
Parameter Sets: SD
Aliases:

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

### Security2.FileSystemSecurity2[]

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
