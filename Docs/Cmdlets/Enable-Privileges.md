---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Enable-Privileges.md
schema: 2.0.0
---

# Enable-Privileges

## SYNOPSIS

Enables the file system privileges in the access token of the current PowerShell process.

## SYNTAX

```
Enable-Privileges [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Enable-Privileges` cmdlet enables the Take Ownership, Restore, Backup, and Security privileges in the access token of the current PowerShell process. Together these privileges let the other cmdlets of the module read and change the security of files and folders that your account has no permissions on, take ownership of them, and work with audit entries.

The change affects nothing but the access token of the PowerShell process that runs the cmdlet. Other processes, other PowerShell sessions, and the computer configuration stay untouched, and the privileges are gone as soon as the process ends.

Unlike the other cmdlets of the module, `Enable-Privileges` leaves the privileges enabled after it finishes, which is the point of the cmdlet: the file system cmdlets enable the same privileges only for the duration of a single call. Calling `Enable-Privileges` is therefore useful when you want the privileges to stay enabled for a whole sequence of commands, or when you turned the automatic handling off by setting `EnablePrivileges` to `$false` in the `PrivateData` section of NTFSSecurity.psd1. When you call the cmdlet yourself, it enables the privileges regardless of that setting.

A privilege can only be enabled when it is present in the access token, which in practice means an elevated session of an account that holds the privilege, such as a member of the local Administrators group. When all four privileges are enabled, the cmdlet writes a verbose message that names them; otherwise it writes a non-terminating error that reports that the requested privileges could not be enabled and that the cmdlets of the module will only work on resources you have access to.

## EXAMPLES

### Example 1: Enable the privileges for the current session

```PowerShell
PS C:\> Enable-Privileges
```

This command enables the Take Ownership, Restore, Backup, and Security privileges in the current PowerShell process and leaves them enabled.

### Example 2: Enable the privileges and check the result

```PowerShell
PS C:\> Enable-Privileges
PS C:\> Get-Privileges | Where-Object { $_.Privilege -in 'Backup', 'Restore', 'TakeOwnership', 'Security' }
```

The second command lists the four file system privileges with their current state, which confirms whether the session now holds them in the enabled state.

### Example 3: Enable the privileges and return them in one step

```PowerShell
PS C:\> Enable-Privileges -PassThru
```

This command enables the privileges and returns all privileges of the current process, so you can see the result without a second call to `Get-Privileges`.

### Example 4: Work with enabled privileges and turn them off afterwards

```PowerShell
PS C:\> Enable-Privileges
PS C:\> Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSOwner
PS C:\> Disable-Privileges
```

The privileges stay enabled while the folder tree is read and are turned off again by the last command. Running `Disable-Privileges` when you are done keeps the session at its normal rights.

## PARAMETERS

### -PassThru

Indicates that the cmdlet returns the privileges of the current process after enabling them. Without this parameter, the cmdlet produces no output.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

This cmdlet does not accept pipeline input.

## OUTPUTS

### ProcessPrivileges.PrivilegeAndAttributes

With `-PassThru`, the cmdlet writes one `ProcessPrivileges.PrivilegeAndAttributes` object per privilege of the current process, each with a `Privilege`, a `PrivilegeAttributes`, and a `PrivilegeState` property. Without `-PassThru`, the cmdlet writes nothing. Before 5.0.0, it wrote the privileges as one collection.

## NOTES

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), the file system cmdlets of the module try to enable the Backup, Restore, Take Ownership, and Security privileges while they run and disable the privileges they enabled when they finish. `Enable-Privileges` enables the same privileges but keeps them enabled, so they remain available to every later command in the session until you run `Disable-Privileges` or close the session. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group.

The cmdlet reads the `EnablePrivileges` entry from the `PrivateData` section of the module manifest. If that entry is missing or cannot be read as a Boolean value, the cmdlet throws a parse error that points to the manifest.

## RELATED LINKS

[Disable-Privileges](Disable-Privileges.md)

[Get-Privileges](Get-Privileges.md)

[Set-NTFSOwner](Set-NTFSOwner.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)
