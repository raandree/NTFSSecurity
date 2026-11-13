# NTFSSecurity

| Branch | Build | Last commit | Latest release |
| --- | --- | --- | --- |
| master | [![CI status of master][ci-badge]][ci-runs] | [![Last commit on master][last-commit-badge]][commits] | [![Latest GitHub release][release-badge]][latest-release] [![PowerShell Gallery version][gallery-version-badge]][gallery] |

[![Open issues][issues-badge]][issues]
[![GitHub release downloads][github-downloads-badge]][releases]
[![PowerShell Gallery downloads][gallery-downloads-badge]][gallery]

[ci-badge]: https://github.com/raandree/NTFSSecurity/actions/workflows/ci.yml/badge.svg?branch=master
[ci-runs]: https://github.com/raandree/NTFSSecurity/actions/workflows/ci.yml?query=branch%3Amaster
[last-commit-badge]: https://img.shields.io/github/last-commit/raandree/NTFSSecurity/master
[commits]: https://github.com/raandree/NTFSSecurity/commits/master
[release-badge]: https://img.shields.io/github/v/release/raandree/NTFSSecurity
[latest-release]: https://github.com/raandree/NTFSSecurity/releases/latest
[gallery-version-badge]: https://img.shields.io/powershellgallery/v/NTFSSecurity
[gallery]: https://www.powershellgallery.com/packages/NTFSSecurity
[issues-badge]: https://img.shields.io/github/issues/raandree/NTFSSecurity
[issues]: https://github.com/raandree/NTFSSecurity/issues
[github-downloads-badge]: https://img.shields.io/github/downloads/raandree/NTFSSecurity/total?label=GitHub%20downloads
[releases]: https://github.com/raandree/NTFSSecurity/releases
[gallery-downloads-badge]: https://img.shields.io/powershellgallery/dt/NTFSSecurity?label=PowerShell%20Gallery%20downloads

> [!IMPORTANT]
> NTFSSecurity will be archived soon. Please move to
> [WindowsAccessControl](https://github.com/raandree/WindowsAccessControl),
> which is also on the PowerShell Gallery:
> `Install-Module -Name WindowsAccessControl`.

A PowerShell module for managing the permissions, audit settings,
inheritance, and ownership of files and folders on NTFS volumes.

PowerShell offers only `Get-Acl` and `Set-Acl`; everything between reading
and writing an access control list is up to you. NTFSSecurity closes this gap
with cmdlets for everyday tasks, such as permission reports, adding or
removing a single permission, repairing inheritance, and taking ownership.

## Installation

Install the module from the
[PowerShell Gallery](https://www.powershellgallery.com/packages/NTFSSecurity):

```powershell
Install-Module -Name NTFSSecurity
```

You can also download a release from the
[releases page](https://github.com/raandree/NTFSSecurity/releases) and
install it without the PowerShell Gallery; see
[Installation](Docs/README.md#installation).

The module runs on Windows in Windows PowerShell 5.1 and PowerShell 7.

## Quick start

```powershell
# Show the permissions of a folder
Get-NTFSAccess -Path C:\Data

# Give an account the Modify permission on a folder, its subfolders, and files
Add-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe' -AccessRights Modify

# Remove the explicit permissions of that account again
Get-NTFSAccess -Path C:\Data -Account 'CONTOSO\JohnDoe' -ExcludeInherited |
    Remove-NTFSAccess

# List the explicit permissions in a folder tree, including long paths
Get-ChildItem2 -Path C:\Data -Recurse | Get-NTFSAccess -ExcludeInherited
```

## Documentation

Read the documentation in the
[wiki](https://github.com/raandree/NTFSSecurity/wiki), which is generated
from the `Docs` folder, or in the folder itself:

- [Overview](Docs/README.md): features, requirements, and the list of cmdlets
- [Concepts](Docs/Concepts.md): security descriptors, access rights,
  inheritance, privileges, long paths, and module settings
- [Examples](Docs/Examples.md): common tasks
- [Cmdlet reference](Docs/Cmdlets): one page per cmdlet
- [Contributor guide](Docs/Contributing.md)

The module author's tutorials from 2014 are still a good introduction,
although some cmdlet names have changed since:

- [NTFSSecurity Tutorial 1 - Getting, adding and removing permissions](https://learn.microsoft.com/en-us/archive/blogs/fieldcoding/ntfssecurity-tutorial-1-getting-adding-and-removing-permissions)
- [NTFSSecurity Tutorial 2 - Managing NTFS Inheritance and Using Privileges](https://learn.microsoft.com/en-us/archive/blogs/fieldcoding/ntfssecurity-tutorial-2-managing-ntfs-inheritance-and-using-privileges)

## Version history

See [CHANGELOG.md](CHANGELOG.md) for changes since version 4.2.6 and the
[version history](Docs/Version-History.md) for 4.2.6 and earlier releases.

## License

NTFSSecurity is licensed under the [MIT license](LICENSE).
