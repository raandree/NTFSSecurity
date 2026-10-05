---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Disable-Privileges.md
schema: 2.0.0
---

# Disable-Privileges

## SYNOPSIS

Disables the file system privileges in the access token of the current PowerShell process.

## SYNTAX

```
Disable-Privileges [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The `Disable-Privileges` cmdlet disables the Take Ownership, Restore, Backup, and Security privileges in the access token of the current PowerShell process. It is the counterpart of `Enable-Privileges`, which leaves those privileges enabled for the rest of the session.

Before it changes anything, the cmdlet checks whether at least one of the Take Ownership, Restore, and Backup privileges is currently enabled. If none of them is, it writes a non-terminating error that reports that the privileges are not enabled and does nothing. This is what happens in a session that never enabled the privileges or that does not hold them at all. A privilege that cannot be disabled produces a warning, and the cmdlet continues with the remaining privileges.

The change affects nothing but the access token of the PowerShell process that runs the cmdlet. Disabling a privilege does not remove it from the account; it only takes it out of use until something enables it again, which the file system cmdlets of the module do on their own while they run.

## EXAMPLES

### Example 1: Disable the privileges in the current session

```PowerShell
PS C:\> Disable-Privileges
```

This command disables the Take Ownership, Restore, Backup, and Security privileges in the current PowerShell process.

### Example 2: Disable the privileges and return the result

```PowerShell
PS C:\> Disable-Privileges -PassThru
```

This command disables the privileges and returns all privileges of the current process, so you can confirm their new state right away.

### Example 3: Enable the privileges for a task and turn them off afterwards

```PowerShell
PS C:\> Enable-Privileges
PS C:\> Set-NTFSOwner -Path C:\Data -Account 'BUILTIN\Administrators'
PS C:\> Disable-Privileges
```

The privileges stay enabled while the owner of the folder is changed and are turned off again by the last command, which returns the session to its normal rights.

### Example 4: Check the state of the privileges after disabling them

```PowerShell
PS C:\> Disable-Privileges
PS C:\> Get-Privileges | Where-Object { $_.Privilege -in 'Backup', 'Restore', 'TakeOwnership', 'Security' }
```

The second command lists the four file system privileges with their current state, which shows that they are no longer enabled.

## PARAMETERS

### -PassThru

Indicates that the cmdlet returns the privileges of the current process after disabling them. Without this parameter, the cmdlet produces no output.

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

When the module setting `EnablePrivileges` is `$true` (the default in the `PrivateData` section of NTFSSecurity.psd1), the file system cmdlets of the module try to enable the Backup, Restore, Take Ownership, and Security privileges while they run and disable the privileges they enabled when they finish. You therefore need `Disable-Privileges` only after an explicit `Enable-Privileges`. These privileges are only available in an elevated session of an account that holds them, such as a member of the local Administrators group.

Before 5.0.0, when `EnablePrivileges` was `$false`, the cmdlet wrote warnings that it could not disable the privileges and left them enabled.

## RELATED LINKS

[Enable-Privileges](Enable-Privileges.md)

[Get-Privileges](Get-Privileges.md)

[Set-NTFSOwner](Set-NTFSOwner.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)
