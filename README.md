### Summary
Managing permissions with PowerShell is only a bit easier than in VBS or the command line as there are no cmdlets for most day-to-day tasks like getting a permission report or adding permission to an item. PowerShell only offers Get-Acl and Set-Acl but everything in between getting and setting the ACL is missing. This module closes the gap.

### [Version History](https://github.com/raandree/NTFSSecurity/wiki/Version-History)

### Installation
You have two options:
1. Download the latest release from [the releases section](https://github.com/raandree/NTFSSecurity/releases).
2. Download the module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/NTFSSecurity): Install-Module -Name NTFSSecurity

Further help can be found in [How to install](https://github.com/raandree/NTFSSecurity/wiki/How-to-install) if you face difficulties getting this module installed.

### Documentation
The cmdlets are yet not documented completely so Get-Help will not show help for all the cmdlets. Providing documentation is planned though.

Additional documentation is available:
* [NTFSSecurity Tutorial 1 - Getting, adding and removing permissions](https://docs.microsoft.com/en-us/archive/blogs/fieldcoding/ntfssecurity-tutorial-1-getting-adding-and-removing-permissions)
* [NTFSSecurity Tutorial 2 - Managing NTFS Inheritance and Using Privileges](https://docs.microsoft.com/en-us/archive/blogs/fieldcoding/ntfssecurity-tutorial-2-managing-ntfs-inheritance-and-using-privileges)
