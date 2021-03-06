---
external help file: NTFSSecurity.dll-Help.xml
Module Name: ntfssecurity
online version:
schema: 2.0.0
---

# Remove-NTFSAccess

## SYNOPSIS

{{ Fill in the Synopsis }}

## SYNTAX

### PathComplex (Default)
```
Remove-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

### PathSimple
```
Remove-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] [-AppliesTo <ApplyTo>] [-PassThru] [<CommonParameters>]
```

### SDSimple
```
Remove-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] [-AppliesTo <ApplyTo>] [-PassThru]
 [<CommonParameters>]
```

### SDComplex
```
Remove-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
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

### -AccessRights

{{ Fill AccessRights Description }}

```yaml
Type: FileSystemRights2
Parameter Sets: (All)
Aliases: FileSystemRights
Accepted values: None, ReadData, ListDirectory, WriteData, CreateFiles, AppendData, CreateDirectories, ReadExtendedAttributes, WriteExtendedAttributes, ExecuteFile, Traverse, DeleteSubdirectoriesAndFiles, ReadAttributes, WriteAttributes, Write, Delete, ReadPermissions, Read, ReadAndExecute, Modify, ChangePermissions, TakeOwnership, Synchronize, FullControl, GenericAll, GenericExecute, GenericWrite, GenericRead

Required: True
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AccessType

{{ Fill AccessType Description }}

```yaml
Type: AccessControlType
Parameter Sets: (All)
Aliases: AccessControlType
Accepted values: Allow, Deny

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Account

{{ Fill Account Description }}

```yaml
Type: IdentityReference2[]
Parameter Sets: (All)
Aliases: IdentityReference, ID

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -AppliesTo

{{ Fill AppliesTo Description }}

```yaml
Type: ApplyTo
Parameter Sets: PathSimple, SDSimple
Aliases:
Accepted values: ThisFolderOnly, ThisFolderSubfoldersAndFiles, ThisFolderAndSubfolders, ThisFolderAndFiles, SubfoldersAndFilesOnly, SubfoldersOnly, FilesOnly, ThisFolderSubfoldersAndFilesOneLevel, ThisFolderAndSubfoldersOneLevel, ThisFolderAndFilesOneLevel, SubfoldersAndFilesOnlyOneLevel, SubfoldersOnlyOneLevel, FilesOnlyOneLevel

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -InheritanceFlags

{{ Fill InheritanceFlags Description }}

```yaml
Type: InheritanceFlags
Parameter Sets: PathComplex, SDComplex
Aliases:
Accepted values: None, ContainerInherit, ObjectInherit

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
Parameter Sets: PathComplex, PathSimple
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -PropagationFlags

{{ Fill PropagationFlags Description }}

```yaml
Type: PropagationFlags
Parameter Sets: PathComplex, SDComplex
Aliases:
Accepted values: None, NoPropagateInherit, InheritOnly

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SecurityDescriptor

The SecurityDescriptor parameter allows passing an security descriptor or an array or security descriptors.

A security descriptor contains information about the owner of the object, and the primary group of an object. The security descriptor also contains two access control lists (ACL). The first list is called the discretionary access control lists (DACL), and describes who should have access to an object and what type of access to grant. The second list is called the system access control lists (SACL) and defines what type of auditing to record for an object.

```yaml
Type: FileSystemSecurity2[]
Parameter Sets: SDSimple, SDComplex
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

### Security2.IdentityReference2[]

### Security2.FileSystemRights2

### System.Security.AccessControl.AccessControlType

### System.Security.AccessControl.InheritanceFlags

### System.Security.AccessControl.PropagationFlags

### Security2.ApplyTo

## OUTPUTS

### Security2.FileSystemAccessRule2

## NOTES

## RELATED LINKS
