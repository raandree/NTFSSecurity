---
external help file: NTFSSecurity.dll-Help.xml
Module Name: ntfssecurity
online version:
schema: 2.0.0
---

# Get-Privileges

## SYNOPSIS

{{ Fill in the Synopsis }}

## SYNTAX

```
Get-Privileges [<CommonParameters>]
```

## DESCRIPTION

{{ Fill in the Description }}

## EXAMPLES

### Example 1

```PowerShell
PS C:\> Get-Privileges

-------------------------------------------------------------------------
| Privilege                     | PrivilegeAttributes | PriviliegeState |
|-------------------------------|---------------------|-----------------|
| IncreaseQuota                 | Disabled            | Disabled        |
| Security                      | Enabled             | Enabled         |
| TakeOwnership                 | Enabled             | Enabled         |
| LoadDriver                    | Disabled            | Disabled        |
| SystemProfile                 | Disabled            | Disabled        |
| SystemTime                    | Disabled            | Disabled        |
| ProfileSingleProcess          | Disabled            | Disabled        |
| IncreaseBasePriority          | Disabled            | Disabled        |
| CreatePageFile                | Disabled            | Disabled        |
| Backup                        | Enabled             | Enabled         |
| Restore                       | Enabled             | Enabled         |
| Shutdown                      | Disabled            | Disabled        |
| Debug                         | Enabled             | Enabled         |
| SystemEnvironment             | Disabled            | Disabled        |
| ChangeNotify EnabledByDefault | Enabled             | Enabled         |
| RemoteShutdown                | Disabled            | Disabled        |
| Undock                        | Disabled            | Disabled        |
| ManageVolume                  | Disabled            | Disabled        |
| Impersonate EnabledByDefault  | Enabled             | Enabled         |
| CreateGlobal EnabledByDefault | Enabled             | Enabled         |
| IncreaseWorkingSet            | Disabled            | Disabled        |
| TimeZone                      | Disabled            | Disabled        |
| CreateSymbolicLink            | Disabled            | Disabled        |
-------------------------------------------------------------------------
```

The above command gets the privliges.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### ProcessPrivileges.PrivilegeAndAttributes

## NOTES

## RELATED LINKS
