---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
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

Adds an access control entry (ACE) to an object such as a file or folder. NTFSSecurity allows you to apply basic permission groups (read, read/write, full) or advanced permissions that allow you to get granular with the permissions. See the below table for how the basic permissions map to the advanced permissions, and how NTFSSecurity handles them.

| NTFSSecurity         | AccessRight displayed        | Advanced Security Window                                                                                                  |
|------------------------------|------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| ReadData                     | ListDirectory                | List Folder / Read Data                                                                                                   |
| ListDirectory                | ListDirectory                | List Folder / Read Data                                                                                                   |
| WriteData                    | CreateFile                   | Create Files / Write Data                                                                                                 |
| CreateFiles                  | CreateFile                   | Create Files / Write Data                                                                                                 |
| AppendData                   | CreateDirectories            | Create Folders / Append Data                                                                                              |
| CreateDirectories            | CreateDirectories            | Create Folders / Append Data                                                                                              |
| ReadExtendedAttributes       | ReadExtendedAttributes       | Read Extended Attributes                                                                                                  |
| WriteExtendedAttributes      | WriteExtendedAttributes      | WriteExtendedAttributes                                                                                                   |
| ExecuteFile                  | Traverse                     | Traverse Folder / Execute File                                                                                            |
| Traverse                     | Traverse                     | Traverse Folder / Execute File                                                                                            |
| DeleteSubdirectoriesAndFiles | DeleteSubdirectoriesAndFiles | Delete Sub-folders and Files                                                                                              |
| ReadAttributes               | ReadAttributes               | Read Attributes                                                                                                           |
| WriteAttributes              | WriteAttributes              | Write Attributes                                                                                                          |
| Write                        | Write                        |  Create Files / Write Data,   Create Folders / Append Data,   Write-Attributes, Write Extended Attributes                 |
| Delete                       | Delete                       | Delete                                                                                                                    |
| ReadPermissions              | ReadPermissions              | Read Permissions                                                                                                          |
| Read                         | Read                         |  List Folder / Read Data, Read Attributes,   Read Extended Attributes, Read Permissions                                   |
| ReadAndExecute               | ReadAndExecute               |  Traverse Folder / Execute File,   List Folder / Read Data, Read Attributes,   Read Extended Attributes, Read Permissions |
| Modify                       | Modify                       |  Everything except Full Control,   Delete SubFolders and Files,   Change Permissions, Take Ownership                      |
| ChangePermissions            | ChangePermissions            | Change Permissions                                                                                                        |

## EXAMPLES

### Example 1

```PowerShell
PS C:\> Add-NTFSAccess -Path C:\Data -Account 'NT AUTHORITY\Authenticated Users' -AccessRights Read
```

The above command gives the read permissions to the built-in group of 'Authenticated users'.

### Example 2

```PowerShell
PS C:\> Add-NTFSAccess -Path C:\Data -Account 'Contoso\Domain Admins' -AccessRights Full
```

The above command gives full permissions to the domain administrators group in the contoso active directory.

### Example 3

```PowerShell
PS C:\> Add-NTFSAccess -Path C:\Data -Account 'NT AUTHORITY\Authenticated Users' -AccessRights CreateFiles -AccessType Deny -AppliesTo ThisFolderOnly
```

The above command denies the the built-in group of 'Authenticated users' from creating files in this folder only.

## PARAMETERS

### -AccessRights

The AccessRights parameter designates the permissions to assign. There are individual permissions as well as 'basic' permissions. See the below table for how the basic permissions permissions map the the advanced permissions in the advanced security window.

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

The Account parameter defines the account or group to apply the permissions to.

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

The AppliesTo parameter defines where the permissions apply to and if there is any inheritance e.g "this folder only" or "this folder and subfolders".

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

The InheritanceFlags parameter defines the inheritance of the ACLs.

ObjectInherit will apply the ACE to files and folders in the folder defined by the Path parameter.

ContainerInherit will apply the ACE to subfolders but not files.

There is more information on Microsoft Docs [here](https://docs.microsoft.com/en-us/previous-versions/dotnet/netframework-4.0/ms229747(v=vs.100)?redirectedfrom=MSDN)

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

The PassThru parameter will return the new permissions as a table. If the PassThru parameter is omitted, there is no information returned if the operation was successful.

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

The Path parameter defines where the file or container exists.

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

The PropagationFlags parameter defines how the ACE is propagated to child objects.

Inherit specifies that the ACE is propagated only to child objects. This includes both folder and file child objects.

NoPropagateInherit specifies that the ACE is not propagated to child objects.

None specifies that no inheritance flags are set.

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
