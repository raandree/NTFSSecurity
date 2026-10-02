---
external help file: NTFSSecurity.dll-Help.xml
Module Name: NTFSSecurity
online version: https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/Get-Privileges.md
schema: 2.0.0
---

# Get-Privileges

## SYNOPSIS

Gets the privileges in the access token of the current PowerShell process.

## SYNTAX

```
Get-Privileges [<CommonParameters>]
```

## DESCRIPTION

The `Get-Privileges` cmdlet reads the access token of the current PowerShell process and returns one `ProcessPrivileges.PrivilegeAndAttributes` object for every privilege the token contains. Each object names the privilege in the `Privilege` property, the raw token attributes in `PrivilegeAttributes`, and the resulting state in `PrivilegeState`, which is `Enabled`, `Disabled`, or `Removed`.

The cmdlet only reads; it never changes a privilege. Use it to check whether the four privileges that NTFSSecurity depends on (Backup, Restore, Take Ownership, and Security) are available before you run the file system cmdlets, and to confirm the result of `Enable-Privileges` and `Disable-Privileges`.

Only privileges that the account holds in this session appear in the list; privileges the account does not have are not listed at all. Because Windows removes the administrative privileges from the token of a session that is not elevated, a standard session returns a much shorter list than an elevated one.

## EXAMPLES

### Example 1: List the privileges of the current session

```PowerShell
PS C:\> Get-Privileges
```

This command returns every privilege in the access token of the current PowerShell process together with its state.

### Example 2: List only the privileges that are currently enabled

```PowerShell
PS C:\> Get-Privileges | Where-Object { $_.PrivilegeState -eq 'Enabled' }
```

This command filters the result down to the privileges that are in use, which is a short list in a session that has not enabled anything.

### Example 3: Check the privileges that NTFSSecurity uses

```PowerShell
PS C:\> Get-Privileges | Where-Object { $_.Privilege -in 'Backup', 'Restore', 'TakeOwnership', 'Security' }
```

This command shows the four file system privileges. An empty result means that the session does not hold them, which is the normal case outside an elevated session.

### Example 4: Test a single privilege before taking ownership

```PowerShell
PS C:\> (Get-Privileges | Where-Object { $_.Privilege -eq 'TakeOwnership' }).PrivilegeState
```

This command returns the state of the Take Ownership privilege alone and returns nothing when the session does not hold it.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

This cmdlet does not accept pipeline input.

## OUTPUTS

### ProcessPrivileges.PrivilegeAndAttributes

The cmdlet returns one object per privilege in the token of the current process. `Privilege` names the privilege, `PrivilegeAttributes` holds the token attributes as a combination of `Disabled`, `EnabledByDefault`, `Enabled`, `Removed`, and `UsedForAccess`, and `PrivilegeState` reduces those attributes to `Enabled`, `Disabled`, or `Removed`.

## NOTES

This cmdlet reads the access token of the current PowerShell process only. It reports no privileges of other processes or sessions, and it changes nothing. Use `Enable-Privileges` and `Disable-Privileges` to change the state of the file system privileges.

Unlike the file system cmdlets of the module, `Get-Privileges` is not affected by the `EnablePrivileges` setting in the `PrivateData` section of NTFSSecurity.psd1 and never enables a privilege on its own.

## RELATED LINKS

[Enable-Privileges](Enable-Privileges.md)

[Disable-Privileges](Disable-Privileges.md)

[Set-NTFSOwner](Set-NTFSOwner.md)

[Get-NTFSSecurityDescriptor](Get-NTFSSecurityDescriptor.md)
