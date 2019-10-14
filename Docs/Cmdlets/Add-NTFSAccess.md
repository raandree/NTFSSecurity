---
external help file: NTFSSecurity.dll-Help.xml
Module Name: ntfssecurity
online version:
schema: 2.0.0
---

# Add-NTFSAccess

## SYNOPSIS
Adds an access control entry (ACE) to an object.

## SYNTAX

### PathComplex (Default)
```
Add-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

### PathSimple
```
Add-NTFSAccess [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AccessType <AccessControlType>] [-AppliesTo <ApplyTo>] [-PassThru] [<CommonParameters>]
```

### SDSimple
```
Add-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] [-AppliesTo <ApplyTo>] [-PassThru]
 [<CommonParameters>]
```

### SDComplex
```
Add-NTFSAccess [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AccessType <AccessControlType>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION
Adds an access control entry (ACE) to an object such as a file or folder. Other examples would be an object inside of Active Directory.

## EXAMPLES

### Example 1
```powershell
PS C:\> Add-NTFSAccess -Path C:\Data -Account 'NT AUTHORITY\Authenticated Users' -AccessRights Read
```

The above command gives the read permissions to the built-in group of 'Authenticated users'

## PARAMETERS

### -AccessRights
The AccessRights parameter designates the permissions to assign. There are individual permissions as well as 'basic' permissions. See the below table for how the basic permissions permissions map the the advanced permissions.

|         Permissions         	| Basic Full Control 	| Basic Modify 	| Basic Read & Execute 	| Basic List Folder Contents 	| Basic Read 	| Basic Write 	|
|:---------------------------:	|:------------------:	|:------------:	|:--------------------:	|:--------------------------:	|:----------:	|:-----------:	|
|    Travers Folder/Execute   	|          X         	|       X      	|           X          	|              X             	|            	|             	|
|    List Folder/ Read Data   	|          X         	|       X      	|           X          	|              X             	|      X     	|             	|
|       Read Attributes       	|          X         	|       X      	|           X          	|              X             	|      X     	|             	|
|   Read Extended Attributes  	|          X         	|       X      	|           X          	|              X             	|      X     	|             	|
|   Create Files/Write Data   	|          X         	|       X      	|                      	|                            	|            	|      X      	|
|  Create Folders/Append Data 	|          X         	|       X      	|                      	|                            	|            	|      X      	|
|       Write Attributes      	|          X         	|       X      	|                      	|                            	|            	|      X      	|
|  Write Extended Attributes  	|          X         	|       X      	|                      	|                            	|            	|      X      	|
| Delete Subfolders and Files 	|          X         	|              	|                      	|                            	|            	|             	|
|            Delete           	|          X         	|       X      	|                      	|                            	|            	|             	|
|       Read Permissions      	|          X         	|       X      	|           X          	|              X             	|      X     	|      X      	|
|      Change Permissions     	|          X         	|              	|                      	|                            	|            	|             	|
|        Take Ownership       	|          X         	|              	|                      	|                            	|            	|             	|
|         Synchronize         	|          X         	|       X      	|           X          	|              X             	|      X     	|      X      	|

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
The AccessType parameter determines if the ACE allows or denies the permissions assigned.

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
{{ Fill SecurityDescriptor Description }}

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
