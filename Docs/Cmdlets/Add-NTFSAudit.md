---
external help file: NTFSSecurity.dll-Help.xml
Module Name: ntfssecurity
online version:
schema: 2.0.0
---

# Add-NTFSAudit

## SYNOPSIS

Add auditing to a folder or file.

## SYNTAX

### PathComplex (Default)
```
Add-NTFSAudit [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AuditFlags <AuditFlags>] [-InheritanceFlags <InheritanceFlags>] [-PropagationFlags <PropagationFlags>]
 [-PassThru] [<CommonParameters>]
```

### PathSimple
```
Add-NTFSAudit [-Path] <String[]> [-Account] <IdentityReference2[]> [-AccessRights] <FileSystemRights2>
 [-AuditFlags <AuditFlags>] [-AppliesTo <ApplyTo>] [-PassThru] [<CommonParameters>]
```

### SDSimple
```
Add-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AuditFlags <AuditFlags>] [-AppliesTo <ApplyTo>] [-PassThru]
 [<CommonParameters>]
```

### SDComplex
```
Add-NTFSAudit [-SecurityDescriptor] <FileSystemSecurity2[]> [-Account] <IdentityReference2[]>
 [-AccessRights] <FileSystemRights2> [-AuditFlags <AuditFlags>] [-InheritanceFlags <InheritanceFlags>]
 [-PropagationFlags <PropagationFlags>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

You can apply audit policies to individual files and folders on your computer by setting the permission type to record successful access attempts or failed access attempts in the security log.

To complete this procedure, you must be signed in as a member of the built-in Administrators group or have Manage auditing and security log rights.

## EXAMPLES

### Example 1

```PowerShell
PS C:\> Add-NTFSAudit -Path C:\Data -Account 'NT AUTHORITY\Authenticated Users' -AcessRights generic All -AuditFlags Failure
```

The above command adds auditing to the folder C:\Data on any failure.
## PARAMETERS

### -AccessRights

The AccessRights parameter designates the permissions to monitor or audit. There are individual permissions as well as 'basic' permissions. See the below table for how the basic permissions permissions map the the advanced permissions in the advanced security window.

```yaml
Type: FileSystemRights2
Parameter Sets: (All)
Aliases: FileSystemRights
Accepted values: None, ReadData, ListDirectory, WriteData, CreateFiles, AppendData, CreateDirectories, ReadExtendedAttributes, WriteExtendedAttributes, ExecuteFile, Traverse, DeleteSubdirectoriesAndFiles, ReadAttributes, WriteAttributes, Write, Delete, ReadPermissions, Read, ReadAndExecute, Modify, ChangePermissions, TakeOwnership, Synchronize, FullControl, GenericAll, GenericExecute, GenericWrite, GenericRead

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Account

The Account parameter defines the account or group to apply the auditing to.

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

The AppliesTo parameter defines where the auditing will apply to and if there is any inheritance e.g "this folder only" or "this folder and subfolders".

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

### -AuditFlags

The AuditFlags parameter defines what types of events will be audited. If you would only like to audit denied access you would choose failure.

```yaml
Type: AuditFlags
Parameter Sets: (All)
Aliases:
Accepted values: None, Success, Failure

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -InheritanceFlags

The InheritanceFlags parameter defines the inheritance of the auditing.

ObjectInherit will apply the auditing to files and folders in the folder defined by the Path parameter.

ContainerInherit will apply the auditing to subfolders but not files.

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

The PassThru parameter will return the new auditing as a table. If the PassThru parameter is omitted, there is no information returned if the operation was successful.

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

The Path parameter defines where the file or container exists to apply the auditing to.

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

The PropagationFlags parameter defines how the auditing is propagated to child objects.

Inherit specifies that the auditing is propagated only to child objects. This includes both folder and file child objects.

NoPropagateInherit specifies that the auditing is not propagated to child objects.

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

### System.Security.AccessControl.AuditFlags

### System.Security.AccessControl.InheritanceFlags

### System.Security.AccessControl.PropagationFlags

### Security2.ApplyTo

## OUTPUTS

### Security2.FileSystemAccessRule2

## NOTES

## RELATED LINKS
