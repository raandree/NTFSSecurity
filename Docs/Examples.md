# Examples

These examples show common tasks with the NTFSSecurity module. Replace the
sample paths and accounts with your own. For background, see
[Concepts](Concepts.md).

Changing permissions on items you don't own, changing owners, and every
audit operation need an elevated PowerShell session. See
[Privileges](Concepts.md#privileges).

## Read permissions

Get the access entries of a folder:

```powershell
Get-NTFSAccess -Path C:\Data
```

Get the access entries of every item in a folder:

```powershell
Get-ChildItem -Path C:\Data | Get-NTFSAccess
```

Get only the explicit entries in a folder tree, including items with paths
longer than 260 characters:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSAccess -ExcludeInherited
```

Get the entries of one account, either with `-Account` or with
`Where-Object`:

```powershell
Get-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe'
Get-NTFSAccess -Path C:\Data | Where-Object { $_.Account -like '*JohnDoe*' }
```

## Grant permissions

Give an account the Modify permission on a folder, its subfolders, and its
files:

```powershell
Add-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe' -AccessRights Modify
```

Give a group read access to a folder and its subfolders, but not to the
files:

```powershell
Add-NTFSAccess -Path C:\Data -Account 'CONTOSO\Domain Users' -AccessRights ReadAndExecute -AppliesTo ThisFolderAndSubfolders
```

Deny a group the right to delete anything in a folder:

```powershell
Add-NTFSAccess -Path C:\Data\Public -Account 'CONTOSO\Interns' -AccessRights Delete, DeleteSubdirectoriesAndFiles -AccessType Deny
```

## Remove permissions

Remove an entry by account and rights:

```powershell
Remove-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe' -AccessRights Modify
```

Remove all explicit entries of an account by piping them to
`Remove-NTFSAccess`:

```powershell
Get-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe' -ExcludeInherited | Remove-NTFSAccess
```

## Back up and restore permissions

Save the explicit entries of a folder and everything below it to a CSV file:

```powershell
$items = @(Get-Item2 -Path C:\Data) + @(Get-ChildItem2 -Path C:\Data -Recurse)
$items | Get-NTFSAccess -ExcludeInherited | Export-Csv -Path C:\Backup\permissions.csv -NoTypeInformation
```

Restore the entries. Each row contains the path, account, rights, type, and
inheritance settings of one entry, which `Add-NTFSAccess` binds by property
name:

```powershell
Import-Csv -Path C:\Backup\permissions.csv | Add-NTFSAccess
```

Restoring adds the saved entries. It doesn't remove entries that were added
after the backup.

## Find and remove orphaned entries

List entries whose account no longer exists:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOrphanedAccess
```

Remove them:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOrphanedAccess | Remove-NTFSAccess
```

Review the list before you remove anything. An account also looks orphaned
when Windows can't resolve it temporarily, for example because a domain
controller is unreachable.

## Check effective access

Show the access that the current user has on a folder:

```powershell
Get-NTFSEffectiveAccess -Path C:\Data
```

Show the access of another account, by name or by SID:

```powershell
Get-NTFSEffectiveAccess -Path C:\Data -Account 'CONTOSO\JohnDoe'
Get-NTFSEffectiveAccess -Path C:\Data -Account S-1-5-32-545
```

## Manage inheritance

Find the folders that don't inherit permissions from their parent:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse -Directory | Get-NTFSInheritance | Where-Object { -not $_.AccessInheritanceEnabled }
```

Turn inheritance back on for a whole folder tree. Explicit entries stay in
place:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse | Enable-NTFSAccessInheritance
```

Block inheritance on a folder. The inherited entries are copied as explicit
entries:

```powershell
Disable-NTFSAccessInheritance -Path C:\Data\Finance
```

Reset a folder to inherited permissions only:

```powershell
Enable-NTFSAccessInheritance -Path C:\Data\Finance -RemoveExplicitAccessRules
```

## Manage ownership

List the owners of all items in a folder tree:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOwner
```

Make the local Administrators group the owner of a folder. This needs an
elevated session:

```powershell
Set-NTFSOwner -Path C:\Data -Account 'BUILTIN\Administrators'
```

## Make several changes in one write

Get the security descriptor once, change it in memory, and write it back.
With security descriptor input, specify `-AppliesTo` (or the inheritance and
propagation flags) so that PowerShell can choose the parameter set:

```powershell
$sd = Get-NTFSSecurityDescriptor -Path C:\Data
$sd | Add-NTFSAccess -Account 'CONTOSO\JohnDoe' -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndFiles
$sd | Remove-NTFSAccess -Account 'CONTOSO\Interns' -AccessRights ReadAndExecute -AppliesTo ThisFolderSubfoldersAndFiles
$sd | Set-NTFSSecurityDescriptor
```

## Audit access

Log every successful and failed attempt to delete items in a folder. This
needs an elevated session, and Windows only writes the events when the
**Audit File System** policy is enabled:

```powershell
Add-NTFSAudit -Path C:\Data\Finance -Account 'Everyone' -AccessRights Delete, DeleteSubdirectoriesAndFiles
Get-NTFSAudit -Path C:\Data\Finance
```

## Work with long paths

Find files whose full path is longer than 260 characters and show their
permissions:

```powershell
Get-ChildItem2 -Path C:\Data -Recurse -File | Where-Object { $_.FullName.Length -gt 260 } | Get-NTFSAccess
```

## Use privileges

List the privileges of the current PowerShell process:

```powershell
Get-Privileges
```

In an elevated session, enable the Backup, Restore, Take Ownership, and
Security privileges for the rest of the session, and disable them again
when you're done:

```powershell
Enable-Privileges
Get-ChildItem2 -Path D:\Shares -Recurse | Get-NTFSAccess -ExcludeInherited
Disable-Privileges
```
