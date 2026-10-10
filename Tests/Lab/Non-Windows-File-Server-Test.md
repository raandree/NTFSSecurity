# Test NTFSSecurity on a file server that isn't Windows

This page is for people who reported [#34][issue-34] on a NetApp, EMC, IBM, or
other file server and who offered to test a fix. It takes about 20 minutes.
Two people may share the work: a storage administrator, who prepares and
removes a test folder, and a user without administrator rights on the file
server, who runs the module. The commands are the ones that the
[live tests](README.md) run on Windows file servers (case 1).

## Keep it safe

- Use only a new folder that you create for this test. Never run these
  commands on real data, on the root of a share, or on a home folder: they
  change permissions.
- The test removes nothing outside that folder. When you finish, the
  storage administrator deletes the folder.
- Don't send passwords, API keys, file contents, or complete security
  descriptors. Replace the names of servers, domains, and accounts with
  placeholders, such as `FILER`, `DOMAIN`, and `testuser`. Well-known SIDs,
  such as `S-1-5-32-544`, can stay.

## What you need

- The exact package to test. The maintainer names it in the issue; this page
  says `5.0.0-rc7` as an example. Install it in a new PowerShell session and
  don't load another version of NTFSSecurity in the same session:

  ```powershell
  Install-Module -Name NTFSSecurity -RequiredVersion 5.0.0-rc7 -AllowPrerelease -Scope CurrentUser
  Import-Module -Name NTFSSecurity
  (Get-Module -Name NTFSSecurity).Version
  (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path -Path (Get-Module -Name NTFSSecurity).ModuleBase -ChildPath 'NTFSSecurity.dll')).Hash
  ```

- A domain group that has Full Control on the test folder, and a user who is
  a member of that group but not an administrator (or root) of the file
  server. This is the setup in which the error 1307 happened.
- Windows PowerShell 5.1 or PowerShell 7. Say which one you used.

## 1. Prepare the test folder (storage administrator)

Create the folder and one subfolder for each command. The user who runs the
module in step 2 must not own these folders: in the failing setup the folder
is owned by `BUILTIN\Administrators`, or by the owner that your file server
shows for administrators, and the user may not assign that owner. Replace the
first two lines.

```powershell
$root = '\\FILER\share\ntfssecurity-test'
$group = 'DOMAIN\ntfssecurity-test-group'

$names = 'AddAccess', 'RemoveAccess', 'ClearAccess', 'DisableInheritance', 'EnableInheritance', 'SetInheritance', 'SetSecurityDescriptor'
New-Item -ItemType Directory -Path $root | Out-Null
icacls $root /grant "${group}:(OI)(CI)F" | Out-Null
foreach ($name in $names) { New-Item -ItemType Directory -Path (Join-Path $root $name) | Out-Null }
icacls "$root\RemoveAccess" /grant 'Everyone:(OI)(CI)RX' | Out-Null
icacls "$root\ClearAccess" /grant 'Everyone:(OI)(CI)RX' | Out-Null
icacls "$root\EnableInheritance" /inheritance:d | Out-Null

(Get-Acl -LiteralPath $root).Owner
```

The last line shows the owner. If it is the account that runs the module in
step 2, the test can't show the error: let another administrator create the
folders. If `icacls` fails for you at this step, stop and tell us.

## 2. Run the commands (the user without administrator rights)

Run this in the new session in which you imported NTFSSecurity. It only
changes the seven subfolders. Each command writes an error, if there is one,
instead of stopping.

```powershell
$root = '\\FILER\share\ntfssecurity-test'
$everyone = 'Everyone'
$ErrorActionPreference = 'Continue'

function Show-State ([string] $Name) {
    $path = Join-Path $root $Name
    '--- {0}: owner {1}' -f $Name, ((Get-Acl -LiteralPath $path).GetOwner([System.Security.Principal.SecurityIdentifier]).Value)
    icacls $path
}

foreach ($name in 'AddAccess', 'RemoveAccess', 'ClearAccess', 'DisableInheritance', 'EnableInheritance', 'SetInheritance', 'SetSecurityDescriptor') { Show-State $name }   # before

Add-NTFSAccess -Path "$root\AddAccess" -Account $everyone -AccessRights ReadData
Remove-NTFSAccess -Path "$root\RemoveAccess" -Account $everyone -AccessRights ReadAndExecute -InheritanceFlags 'ContainerInherit, ObjectInherit' -PropagationFlags None
Clear-NTFSAccess -Path "$root\ClearAccess"
Disable-NTFSAccessInheritance -Path "$root\DisableInheritance"
Enable-NTFSAccessInheritance -Path "$root\EnableInheritance"
Set-NTFSInheritance -Path "$root\SetInheritance" -AccessInheritanceEnabled $false
$descriptor = Get-NTFSSecurityDescriptor -Path "$root\SetSecurityDescriptor"
Add-NTFSAccess -SecurityDescriptor $descriptor -Account $everyone -AccessRights ReadData
Set-NTFSSecurityDescriptor -SecurityDescriptor $descriptor

foreach ($name in 'AddAccess', 'RemoveAccess', 'ClearAccess', 'DisableInheritance', 'EnableInheritance', 'SetInheritance', 'SetSecurityDescriptor') { Show-State $name }   # after
```

What a good result looks like, for each of the seven folders:

- The command wrote no error.
- The owner is the same before and after.
- Only the intended entry changed: `AddAccess` gained an entry for Everyone,
  `RemoveAccess` and `ClearAccess` lost theirs, the inheritance flags of
  `DisableInheritance`, `EnableInheritance`, and `SetInheritance` changed,
  and `SetSecurityDescriptor` gained an entry for Everyone.

## 3. Tell us what happened

Post a comment in [#34][issue-34] with:

1. The package version and the SHA-256 of `NTFSSecurity.dll` from the
   first step, and the PowerShell edition and Windows version of the
   computer that ran the commands.
2. The file server product and version, such as `ONTAP 9.x`, `PowerScale
   OneFS x.y`, or `IBM ESS x.y`, whether the path goes through DFS, and the
   SMB version if you know it.
3. For each of the seven commands: worked or failed. For a failure, the
   first line of the error and its `FullyQualifiedErrorId`, such as
   `AddAceError,NTFSSecurity.AddAccess`.
4. The owner before and after for each folder, and the `icacls` output
   before and after, with the names replaced.
5. Anything that looked different from what you expected, even if the
   commands worked.

A result that says only "works for me" can't tell us which command ran on
which setup. The list above is what we need to treat the result as a test.

## 4. Optional: confirm that your setup reproduces the error

To see that the setup is the one in which #34 happened, repeat the second
step with `4.2.6` in a new session. Reporters saw error 1307 from
`Add-NTFSAccess` in 4.2.6, and in our Windows lab 5.0.0-rc2 failed
`Add-NTFSAccess`, `Clear-NTFSAccess`, and `Set-NTFSSecurityDescriptor` the
same way. Create a new test folder first, because the first run changed some
of the seven folders. Don't run the two versions in the same session.

## 5. Remove the test folder (storage administrator)

Delete the folder `ntfssecurity-test` with its subfolders. Check its path
first, so that you delete only the test folder.

[issue-34]: https://github.com/raandree/NTFSSecurity/issues/34
