### Summary
Managing permissions with PowerShell is only a bit easier than in VBS or the command line as there are no cmdlets for most day-to-day tasks like getting a permission report or adding permission to an item. PowerShell only offers Get-Acl and Set-Acl but everything in between getting and setting the ACL is missing. This module closes the gap.

### [Version History](https://github.com/raandree/NTFSSecurity/wiki/Version-History)

### Installation
You have two options:
1. Download the latest release from [here](https://github.com/raandree/NTFSSecurity/releases).
2. Download the module from the PowerShell Gallery: Install-Module -Name NTFSSecurity

Further help can be found in [How to install](https://github.com/raandree/NTFSSecurity/wiki/How-to-install) if you face difficulties getting this module installed.

### Documentation
The cmdlets are yet not documented completely so Get-Help will not show help for all the cmdlets. Providing documentation is planned tough.

Additional documentation is available:
* [NTFSSecurity Tutorial 1 - Getting, adding and removing permissions](http://blogs.technet.com/b/fieldcoding/archive/2014/12/05/ntfssecurity-tutorial-1-getting-adding-and-removing-permissions.aspx)
* [NTFSSecurity Tutorial 2 - Managing NTFS Inheritance and Using Privileges](http://blogs.technet.com/b/fieldcoding/archive/2014/12/05/ntfssecurity-tutorial-2-managing-ntfs-inheritance-and-using-privileges.aspx)
