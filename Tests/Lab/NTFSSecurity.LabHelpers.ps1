<#
    Helpers of the live tests in a lab (README.md). NTFSSecurity.Live.Tests.ps1 dot-sources this file on the client
    and on the file server, and Invoke-NTFSSecurityLabTest.ps1 runs it on both to prepare the fixtures. Dot-sourcing
    it only defines the helpers.
#>

if (-not ('NTFSSecurityLab.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace NTFSSecurityLab
{
    // GetFileSecurity and SetFileSecurity read and write a security descriptor as Windows stores it.
    // GetNamedSecurityInfo and SetNamedSecurityInfo, which .NET and the module use, convert a DACL without the
    // auto-inherit flag when they read it, and add the flag when they write a DACL.
    public static class NativeMethods
    {
        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool GetFileSecurityW(string fileName, int requestedInformation, byte[] securityDescriptor, int length, out int lengthNeeded);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool SetFileSecurityW(string fileName, int securityInformation, byte[] securityDescriptor);

        public static byte[] GetFileSecurity(string path, int information)
        {
            int needed;
            GetFileSecurityW(path, information, null, 0, out needed);
            if (needed == 0)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            var buffer = new byte[needed];
            if (!GetFileSecurityW(path, information, buffer, buffer.Length, out needed))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            return buffer;
        }

        public static void SetFileSecurity(string path, int information, byte[] securityDescriptor)
        {
            if (!SetFileSecurityW(path, information, securityDescriptor))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
        }
    }
}
'@
}

function Get-LabSecurityDescriptor {
    <#
    .SYNOPSIS
        Returns the owner, the group, and the DACL of a file or folder as Windows stores them.
    .DESCRIPTION
        GetNamedSecurityInfo returns the owner with a DACL without the auto-inherit flag even when only the DACL is
        read, and converts such a DACL. This function reads with GetFileSecurity, which does neither.
    .PARAMETER Path
        A local path or a UNC path. The account needs the right to read the permissions.
    #>
    [CmdletBinding()]
    [OutputType([System.Security.AccessControl.RawSecurityDescriptor])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    # OWNER_SECURITY_INFORMATION, GROUP_SECURITY_INFORMATION, and DACL_SECURITY_INFORMATION
    $bytes = [NTFSSecurityLab.NativeMethods]::GetFileSecurity($Path, 7)
    New-Object -TypeName 'System.Security.AccessControl.RawSecurityDescriptor' -ArgumentList $bytes, 0
}

function Test-LabDaclAutoInherited {
    <#
    .SYNOPSIS
        Returns whether the stored DACL of a file or folder has the auto-inherit flag.
    .PARAMETER Path
        A local path or a UNC path.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $autoInherited = [System.Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInherited
    ((Get-LabSecurityDescriptor -Path $Path).ControlFlags -band $autoInherited) -ne 0
}

function Set-LabLegacyDacl {
    <#
    .SYNOPSIS
        Stores the DACL of a file or folder again, without the auto-inherit flag.
    .DESCRIPTION
        Windows adds the flag whenever SetNamedSecurityInfo writes a DACL. SetFileSecurity stores the DACL as given,
        like tools that predate Windows 2000. For such a DACL, GetNamedSecurityInfo returns the owner also when only
        the DACL is read, and NTFSSecurity before 5.0.0-rc3 wrote that owner back (#34).
    .PARAMETER Path
        A local path. The account needs the right to change the permissions.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $descriptor = Get-LabSecurityDescriptor -Path $Path
    $autoInherited = [System.Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInherited
    $descriptor.SetFlags([System.Security.AccessControl.ControlFlags]($descriptor.ControlFlags -band -bnot $autoInherited))
    $bytes = New-Object -TypeName 'byte[]' -ArgumentList $descriptor.BinaryLength
    $descriptor.GetBinaryForm($bytes, 0)
    if ($PSCmdlet.ShouldProcess($Path, 'Store the DACL without the auto-inherit flag')) {
        # DACL_SECURITY_INFORMATION
        [NTFSSecurityLab.NativeMethods]::SetFileSecurity($Path, 4, $bytes)
    }
}

function Get-LabTokenSid {
    <#
    .SYNOPSIS
        Returns the SIDs of the token that this computer creates for a domain account.
    .DESCRIPTION
        Logs the account on with Kerberos S4U, without its password, like the Effective Access tab of the advanced
        security settings does. The token holds the account and all its groups that this computer knows: nested
        domain groups and the local groups of this computer.
    .PARAMETER UserPrincipalName
        The user principal name of the account, such as user@contoso.com.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]
        $UserPrincipalName
    )

    $identity = New-Object -TypeName 'System.Security.Principal.WindowsIdentity' -ArgumentList $UserPrincipalName
    try {
        $identity.User.Value
        foreach ($group in $identity.Groups) {
            $group.Value
        }
    }
    finally {
        $identity.Dispose()
    }
}

function Get-LabGrantedRight {
    <#
    .SYNOPSIS
        Returns the access mask that the allow entries of a DACL grant to a set of SIDs.
    .DESCRIPTION
        Combines the entries that apply to the item itself and name one of the SIDs. A deny entry for one of the SIDs
        makes the function throw, because the calculation doesn't cover it.
    .PARAMETER Descriptor
        The security descriptor of the item.
    .PARAMETER Sid
        The SIDs of a token, such as the output of Get-LabTokenSid.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param (
        [Parameter(Mandatory)]
        [System.Security.AccessControl.RawSecurityDescriptor]
        $Descriptor,

        [Parameter(Mandatory)]
        [string[]]
        $Sid
    )

    $granted = 0L
    foreach ($ace in $Descriptor.DiscretionaryAcl) {
        if ($ace -isnot [System.Security.AccessControl.CommonAce] -or $ace.SecurityIdentifier.Value -notin $Sid) {
            continue
        }

        # HasFlag, because Windows PowerShell can't apply -band to an enum of the type byte.
        if ($ace.AceFlags.HasFlag([System.Security.AccessControl.AceFlags]::InheritOnly)) {
            continue
        }

        if ($ace.AceQualifier -ne [System.Security.AccessControl.AceQualifier]::AccessAllowed) {
            throw "The DACL denies $($ace.SecurityIdentifier) access, which Get-LabGrantedRight doesn't calculate."
        }

        $granted = $granted -bor ([long]$ace.AccessMask -band 0xFFFFFFFFL)
    }

    $granted
}

function Assert-LabTestTarget {
    <#
    .SYNOPSIS
        Throws unless this process runs on the client or the file server that a configuration of the lab names, and
        the folder of the run lies in the share of the lab.
    .DESCRIPTION
        The live tests change security descriptors and must never run on another computer, such as the host of the
        lab or a workstation.
    .PARAMETER Configuration
        The configuration of the run that Invoke-NTFSSecurityLabTest.ps1 wrote.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $Configuration
    )

    # Without CIM, which an account that isn't an administrator can't use in a remote session
    $domainName = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName
    if ($domainName -ne $Configuration.DomainName) {
        throw "The live tests run only on a computer of the lab domain '$($Configuration.DomainName)'."
    }

    if ($env:COMPUTERNAME -notin $Configuration.Client, $Configuration.FileServer) {
        throw "The live tests run only on '$($Configuration.Client)' and '$($Configuration.FileServer)', not on '$env:COMPUTERNAME'."
    }

    $shareRoot = '\\{0}\{1}\' -f $Configuration.FileServerFqdn, $Configuration.ShareName
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not $Configuration.SharePath.StartsWith($shareRoot, $comparison) -or
        -not $Configuration.ServerPath.StartsWith($Configuration.ShareLocalPath + '\', $comparison) -or
        $Configuration.SharePath.Contains('..') -or $Configuration.ServerPath.Contains('..')) {
        throw "The folder of the run must lie in the share '$shareRoot' of the lab."
    }
}
