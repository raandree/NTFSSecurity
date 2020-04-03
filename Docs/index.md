# NTFSSecurity

[![Build status](https://ci.appveyor.com/api/projects/status/2gfb58t9qh655b8x?svg=true)](https://ci.appveyor.com/project/Sup3rlativ3/ntfssecurity) [![Documentation Status](https://readthedocs.org/projects/ntfssecurity/badge/?version=latest)](https://ntfssecurity.readthedocs.io/en/latest/?badge=latest)

Managing file & folder permissions with PowerShell is only a bit easier than in VBS or the command line as there are no cmdlets for most day-to-day tasks like getting a permission report or adding permission to an item. PowerShell only offers Get-Acl and Set-Acl but everything in between getting and setting the ACL is missing. This module closes the gap.

[Version History](https://github.com/raandree/NTFSSecurity/wiki/Version-History)

## Installation

You have two options:

* Download the latest release from the [releases](https://github.com/raandree/NTFSSecurity/releases) section on GitHub.
* Download the module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/NTFSSecurity):

```PowerShell
Install-Module -Name NTFSSecurity
```

Further help can be found in How to install if you face difficulties getting this module installed.

## Documentation

The cmdlets are yet not documented completely so Get-Help will not show help for all the cmdlets. This ReadTheDocs site is the first step to documenting the module.

## Tutorials

There are a number of tutorials available on the web. The below two were written by the author of the NTFSSecurity module.

[NTFSSecurity Tutorial 1 - Getting, adding and removing permissions](http://blogs.technet.com/b/fieldcoding/archive/2014/12/05/ntfssecurity-tutorial-1-getting-adding-and-removing-permissions.aspx)
[NTFSSecurity Tutorial 2 - Managing NTFS Inheritance and Using Privileges](http://blogs.technet.com/b/fieldcoding/archive/2014/12/05/ntfssecurity-tutorial-2-managing-ntfs-inheritance-and-using-privileges.aspx)
