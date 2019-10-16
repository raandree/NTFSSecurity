# CORE CONCEPTS

## Overview

Before starting with the NTFSSecurity module there are some core concepts that you will need to understand.

There are two ways you can handle permissions, basic and advanced. The basic set of permissions are goups of advanced permissions that allow you to assign common role such as 'Read', 'Read/Write', or 'Full'. Advanced permissions allow you granular control of what can and can't be access or used. The advanced permissions are commonly used to build custom Role-Based Access Control tooling.

Below is an explaination taken from the fantastic site NTFS.com for each of the advanced file permissions.

### Traverse Folder/Execute File

* **Traverse Folder**: Allows or denies moving through a restricted folder to reach files and folders beneath the restricted folder in the folder hierarchy. Traverse folder takes effect only when the group or user is not granted the "Bypass traverse checking user" right in the Group Policy snap-in. This permission does not automatically allow running program files.

* **Execute File**: Allows or denies running program (executable) files.

### List Folder/Read Data

* **List Folder**: Allows or denies viewing file names and subfolder names within the folder. List Folder only affects the contents of that folder and does not affect whether the folder you are setting the permission on will be listed.

* **Read Data**: Allows or denies viewing data in files.

### Read Attributes

* Allows or denies viewing the attributes of a file or folder, for example, "read-only" and "hidden".

### Read Extended Attributes

* Allows or denies viewing the extended attributes of a file or folder. Extended attributes are defined by programs and may vary by program.

### Create Files/Write Data

* **Create Files**: Allows or denies creating files within the folder.

* **Write Data**: Allows or denies making changes to a file and overwriting existing content.

### Create Folders/Append Data

* **Create Folders**: Allows or denies creating subfolders within the folder.

* **Append Data**: Allows or denies making changes to the end of the file but not changing, deleting, or overwriting existing data.

### Write Attributes

* Allows or denies changing the attributes of a file or folder, for example, "read-only" or "hidden".

* The Write Attributes permission does not imply creating or deleting files or folders, it only includes the permission to make changes to the attributes of an existing file or folder.

### Write Extended Attributes

* Allows or denies changing the extended attributes of a file or folder. Extended attributes are defined by programs and may vary by program.

* The Write Extended Attributes permission does not imply creating or deleting files or folders, it only includes the permission to make changes to the extended attributes of an existing file or folder.

### Delete Subfolders and Files

* Allows or denies deleting subfolders and files, even if the Delete permission has not been granted on the subfolder or file.

### Delete

* Allows or denies deleting the file or folder. If you don't have Delete permission on a file or folder, you can still delete it if you have been granted Delete Subfolders and Files on the parent folder.

### Read Permissions

* Allows or denies reading permissions of a file or folder.

### Change Permissions

* Allows or denies changing permissions of the file or folder.

### Take Ownership

* Allows or denies taking ownership of the file or folder. The owner of a file or folder can always change permissions on it, regardless of any existing permissions that protect the file or folder.

You can see how the basic permissions, advanced permissions, and the NTFSSecurity module relate to one another in the below table.

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
