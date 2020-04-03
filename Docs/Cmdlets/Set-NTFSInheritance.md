---
external help file: NTFSSecurity.dll-Help.xml
Module Name: ntfssecurity
online version:
schema: 2.0.0
---

# Set-NTFSInheritance

## SYNOPSIS

{{ Fill in the Synopsis }}

## SYNTAX

### Path (Default)
```
Set-NTFSInheritance [[-Path] <String[]>] [-AccessInheritanceEnabled <Boolean>]
 [-AuditInheritanceEnabled <Boolean>] [-PassThru] [<CommonParameters>]
```

### SecurityDescriptor
```
Set-NTFSInheritance [-SecurityDescriptor] <FileSystemSecurity2[]> [-AccessInheritanceEnabled <Boolean>]
 [-AuditInheritanceEnabled <Boolean>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

{{ Fill in the Description }}

## EXAMPLES

### Example 1

```PowerShell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -AccessInheritanceEnabled

{{ Fill AccessInheritanceEnabled Description }}

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AuditInheritanceEnabled

{{ Fill AuditInheritanceEnabled Description }}

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PassThru

{{ Fill PassThru Description }}

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

{{ Fill Path Description }}

```yaml
Type: String[]
Parameter Sets: Path
Aliases: FullName

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -SecurityDescriptor

{{ Fill SecurityDescriptor Description }}

```yaml
Type: FileSystemSecurity2[]
Parameter Sets: SecurityDescriptor
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

### System.Nullable`1[[System.Boolean, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
