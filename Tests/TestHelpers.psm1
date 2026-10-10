<#
    Shared helpers for the Pester tests. A test that changes files, links, ACLs, owners, audit entries, or
    inheritance works in its own sandbox folder below $env:TEMP\NTFSSecurity.Tests: it creates the sandbox with
    New-TestSandbox, sets the location to it, checks every target with Assert-TestSandboxPath before the change,
    and removes the sandbox with Remove-TestSandbox.
#>

$script:sandboxRoot = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'NTFSSecurity.Tests'

function New-TestSandbox {
    <#
    .SYNOPSIS
        Creates an empty sandbox folder for one test file or block and returns its full path.
    #>
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only creates sandboxes.'
        )]
        [CmdletBinding()]
    [OutputType([string])]
    param (
        [ValidatePattern('^[\w-]+$')]
        [string]
        $Name = 'Sandbox'
    )

    $path = Join-Path -Path $script:sandboxRoot -ChildPath ('{0}-{1}' -f $Name, [guid]::NewGuid().ToString('N').Substring(0, 8))
    (New-Item -ItemType Directory -Path $path -Force).FullName
}

function Assert-TestSandboxPath {
    <#
    .SYNOPSIS
        Throws unless each path is inside the given sandbox, which itself must be a sandbox of New-TestSandbox.
        Relative paths resolve against the current location.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]
        $Path
    )

    begin {
        $sandboxFullName = [IO.Path]::GetFullPath($Sandbox).TrimEnd('\')
        $rootFullName = [IO.Path]::GetFullPath($script:sandboxRoot).TrimEnd('\') + '\'
        if (-not $sandboxFullName.StartsWith($rootFullName, [StringComparison]::OrdinalIgnoreCase) -or
            $sandboxFullName.Length -le $rootFullName.Length) {
            throw "'$Sandbox' is not a test sandbox below '$rootFullName'."
        }
        $sandboxPrefix = $sandboxFullName + '\'
    }

    process {
        foreach ($item in $Path) {
            $location = (Get-Location -PSProvider FileSystem).ProviderPath
            $fullName = [IO.Path]::GetFullPath([IO.Path]::Combine($location, $item)).TrimEnd('\')
            if (-not ($fullName + '\').StartsWith($sandboxPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to change '$fullName', which is outside the test sandbox '$sandboxFullName'."
            }

            # A link inside the sandbox can point outside of it, so no folder of the path may be a link.
            $parent = [IO.Path]::GetDirectoryName($fullName)
            while ($parent -and $parent.Length -gt $sandboxFullName.Length) {
                if ([IO.Directory]::Exists($parent) -and
                    ([IO.File]::GetAttributes($parent) -band [IO.FileAttributes]::ReparsePoint)) {
                    throw "Refusing to change '$fullName', because its folder '$parent' is a link."
                }
                $parent = [IO.Path]::GetDirectoryName($parent)
            }
        }
    }
}

function Remove-TestSandbox {
    <#
    .SYNOPSIS
        Removes a sandbox of New-TestSandbox: first its links, without following them, then its ACL changes, then
        the folder.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only removes sandboxes.'
    )]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $Sandbox
    )

    # A setup that failed before New-TestSandbox returned leaves nothing to remove. Before 5.0.0-rc6, the binding error
    # hid the error of the setup (#110).
    if ([string]::IsNullOrEmpty($Sandbox)) {
        return
    }

    Assert-TestSandboxPath -Sandbox $Sandbox -Path $Sandbox
    if (-not (Test-Path -LiteralPath $Sandbox)) {
        return
    }

    # icacls reports items it cannot reset on stderr, which Windows PowerShell turns into a terminating error when
    # the caller uses ErrorAction Stop. Such items can still be deleted through the rights on their folder.
    $ErrorActionPreference = 'Continue'

    # The prefix lets .NET in Windows PowerShell reach paths longer than 260 characters (#110).
    $longPathPrefix = '\\?\'

    # Windows PowerShell 5.1 and icacls /T follow directory links, so the links go first. A folder that denies
    # listing its content gets its own ACL reset, without /T, before it is listed.
    $pending = New-Object -TypeName 'System.Collections.Generic.Stack[string]'
    $pending.Push($longPathPrefix + $Sandbox)
    while ($pending.Count -gt 0) {
        $folder = $pending.Pop()
        try {
            $entries = [IO.Directory]::GetFileSystemEntries($folder)
        }
        catch {
            & icacls.exe $folder.Substring($longPathPrefix.Length) /reset /C /Q *> $null
            $entries = [IO.Directory]::GetFileSystemEntries($folder)
        }
        foreach ($entry in $entries) {
            $attributes = [IO.File]::GetAttributes($entry)
            if ($attributes -band [IO.FileAttributes]::ReparsePoint) {
                if ($attributes -band [IO.FileAttributes]::Directory) {
                    [IO.Directory]::Delete($entry, $false)
                }
                else {
                    [IO.File]::Delete($entry)
                }
            }
            elseif ($attributes -band [IO.FileAttributes]::Directory) {
                $pending.Push($entry)
            }
        }
    }
    & icacls.exe $Sandbox /reset /T /C /Q *> $null
    Get-ChildItem -LiteralPath $Sandbox -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object -Process {
        # Windows PowerShell returns items below paths longer than 260 characters that it can't change; rd removes them.
        try {
            $_.Attributes = [IO.FileAttributes]::Normal
        }
        catch {
            Write-Verbose -Message "Keeping the attributes of '$($_.FullName)': $($_.Exception.Message)"
        }
    }
    Remove-Item -LiteralPath $Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $Sandbox) {
        # Windows PowerShell can't remove paths longer than 260 characters; rd can with the prefix, and the links are
        # gone already.
        & cmd.exe /d /c ('rd /s /q "{0}{1}"' -f $longPathPrefix, $Sandbox) *> $null
    }

    if (Test-Path -LiteralPath $Sandbox) {
        Write-Error -Message "The sandbox '$Sandbox' could not be removed."
    }

    try {
        # Fails while another sandbox exists, also one of a test run in parallel
        [IO.Directory]::Delete($script:sandboxRoot, $false)
    }
    catch {
        Write-Verbose -Message "Keeping '$script:sandboxRoot': $($_.Exception.Message)"
    }
}

function New-TestSandboxItem {
    <#
    .SYNOPSIS
        Creates a file or folder with a unique name in the sandbox and returns its full path.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to sandboxes.'
    )]
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [ValidatePattern('^[\w-]+$')]
        [string]
        $Name = 'Item',

        [switch]
        $Directory
    )

    $path = Join-Path -Path $Sandbox -ChildPath ('{0}-{1}' -f $Name, [guid]::NewGuid().ToString('N').Substring(0, 8))
    Assert-TestSandboxPath -Sandbox $Sandbox -Path $path
    if ($Directory) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
    else {
        Set-Content -LiteralPath $path -Value $Name
    }
    $path
}

function Block-TestReadPermission {
    <#
    .SYNOPSIS
        Denies the owner of an item in the sandbox to read its security descriptor, so that reading it fails.
    .DESCRIPTION
        Adds a deny entry for OWNER RIGHTS (S-1-3-4) with ReadPermissions, which replaces the implicit right of the
        owner to read the security descriptor. Remove-TestSandbox resets it.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]
        $Path
    )

    Add-TestDenyRule -Sandbox $Sandbox -Path $Path -Rights @{ 'S-1-3-4' = 'ReadPermissions' }
}

function Block-TestWritePermission {
    <#
    .SYNOPSIS
        Denies the owner of an item in the sandbox to change its permissions, so that writing its DACL fails.
    .DESCRIPTION
        Adds a deny entry for OWNER RIGHTS (S-1-3-4) with ChangePermissions, which replaces the implicit right of the
        owner to write the DACL. Taking ownership drops that entry, so the current user is also denied
        TakeOwnership; without a privilege, an attempt of the module to take ownership and try again fails as well.
        Reading the item and its security descriptor still works, and Remove-TestSandbox deletes the item through
        the rights on its folder.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    Add-TestDenyRule -Sandbox $Sandbox -Path $Path -Rights @{
        'S-1-3-4' = 'ChangePermissions'
        $currentUser = 'TakeOwnership'
    }
}

function Add-TestDenyRule {
    <#
    .SYNOPSIS
        Adds deny entries to an item in the sandbox in one write, so that an entry cannot block writing the next.
    .PARAMETER Rights
        The rights to deny, keyed by the SID of the account.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]
        $Path,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $Rights
    )

    Assert-TestSandboxPath -Sandbox $Sandbox -Path $Path
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $acl = Get-Acl -LiteralPath $Path
    foreach ($sid in $Rights.Keys) {
        $identity = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $sid
        $rule = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
            $identity, [System.Security.AccessControl.FileSystemRights] $Rights[$sid],
            [System.Security.AccessControl.AccessControlType]::Deny
        )
        $acl.AddAccessRule($rule)
    }
    # Not Set-Acl: it compares AreAuditRulesProtected with AreAccessRulesProtected, so it also writes the audit
    # section of an item whose DACL is protected, which fails without the Security privilege. With the privilege, it
    # writes all sections and drops the audit entries. SetAccessControl writes only the DACL, the section that changed.
    if ($PSVersionTable.PSEdition -eq 'Core') {
        [System.IO.FileSystemAclExtensions]::SetAccessControl($item, $acl)
    }
    else {
        $item.SetAccessControl($acl)
    }
}

function Set-TestOwner {
    <#
    .SYNOPSIS
        Makes an account the owner of an item in the sandbox, also an account that only the Restore privilege lets
        the user assign.
    .DESCRIPTION
        Runs icacls, which enables the Restore privilege in its own process, so that the privileges of the test
        process stay as they are. Remove-TestSandbox deletes the item through the rights on its folder.
    .PARAMETER Sid
        The SID of the new owner, such as that of NT SERVICE\TrustedInstaller.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to sandboxes.'
    )]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]
        $Path,

        [Parameter(Mandatory)]
        [ValidatePattern('^S-1-\d+(-\d+)+$')]
        [string]
        $Sid
    )

    Assert-TestSandboxPath -Sandbox $Sandbox -Path $Path
    # icacls reports a failure on stderr, which Windows PowerShell turns into a terminating error when the caller uses
    # ErrorAction Stop; the exit code decides instead.
    $ErrorActionPreference = 'Continue'
    # icacls resolves a relative path against the working folder of the process, not the location of PowerShell.
    $location = (Get-Location -PSProvider FileSystem).ProviderPath
    $fullName = [IO.Path]::GetFullPath([IO.Path]::Combine($location, $Path))
    $output = & icacls.exe $fullName /setowner "*$Sid" /Q 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "icacls could not make '$Sid' the owner of '$fullName' (exit code $LASTEXITCODE): $output"
    }
}

function Set-TestNullDacl {
    <#
    .SYNOPSIS
        Replaces the DACL of an item in the sandbox with a NULL DACL, which gives everyone every access.
    .DESCRIPTION
        Neither Set-Acl nor icacls can write a NULL DACL, so the helper calls SetNamedSecurityInfo. The DACL is
        protected, so the item inherits no entries. Everyone can delete the item, so Remove-TestSandbox removes it.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only writes to sandboxes.'
    )]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]
        $Path
    )

    Assert-TestSandboxPath -Sandbox $Sandbox -Path $Path
    $location = (Get-Location -PSProvider FileSystem).ProviderPath
    $fullName = [IO.Path]::GetFullPath([IO.Path]::Combine($location, $Path))
    # Assert-TestSandboxPath checks the folders of the path for links, not the item itself, and the native call follows a
    # link: a junction to a folder outside the sandbox would give everyone every access to that folder.
    $attributes = try { [IO.File]::GetAttributes($fullName) } catch { $null }
    if ($null -ne $attributes -and ($attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing to change '$fullName', because it is a link."
    }

    if (-not ('NtfsSecurityTests.NativeAcl' -as [type])) {
        Add-Type -TypeDefinition @'
namespace NtfsSecurityTests
{
    public static class NativeAcl
    {
        [System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
        private static extern uint SetNamedSecurityInfoW(string objectName, int objectType, uint securityInfo,
            System.IntPtr owner, System.IntPtr group, System.IntPtr dacl, System.IntPtr sacl);

        // SE_FILE_OBJECT, with DACL_SECURITY_INFORMATION and PROTECTED_DACL_SECURITY_INFORMATION and no DACL
        public static uint SetNullDacl(string path)
        {
            return SetNamedSecurityInfoW(path, 1, 0x00000004u | 0x80000000u,
                System.IntPtr.Zero, System.IntPtr.Zero, System.IntPtr.Zero, System.IntPtr.Zero);
        }
    }
}
'@
    }

    $result = [NtfsSecurityTests.NativeAcl]::SetNullDacl($fullName)
    if ($result -ne 0) {
        throw "SetNamedSecurityInfo could not set a NULL DACL on '$fullName' (error $result)."
    }
}

function Test-IsElevated {
    <#
    .SYNOPSIS
        Returns $true when the process runs elevated as an administrator.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $principal = New-Object -TypeName 'Security.Principal.WindowsPrincipal' -ArgumentList (
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PrivilegeHeld {
    <#
    .SYNOPSIS
        Returns $true when the access token of the process holds the privilege, enabled or not.
    .PARAMETER Name
        The privilege name, such as SeSecurityPrivilege or SeBackupPrivilege.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^Se\w+Privilege$')]
        [string]
        $Name
    )

    # The column names are localized; the privilege names in the first column are not.
    $output = & whoami.exe /priv /fo csv 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    [bool] ($output | Select-Object -Skip 1 | ConvertFrom-Csv -Header 'Name', 'Description', 'State' |
            Where-Object -Property Name -EQ -Value $Name)
}

function Test-AdminShareAvailable {
    <#
    .SYNOPSIS
        Returns $true when the process can open the administrative share of the drive of the sandboxes, such as
        \\localhost\C$, which Windows treats as a network path and as another volume. Only administrators can.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $drive = [IO.Path]::GetTempPath().Substring(0, 1)
    (Test-IsElevated) -and [bool] (Test-Path -LiteralPath ('\\localhost\{0}$\' -f $drive) -ErrorAction SilentlyContinue)
}

function ConvertTo-TestAdminSharePath {
    <#
    .SYNOPSIS
        Returns the path of an item in a sandbox on the administrative share of its drive, such as
        \\localhost\C$\Users\...\File.txt. It checks the local path with Assert-TestSandboxPath first, so that a test
        reaches only items of its sandbox through the share.
    .PARAMETER Sandbox
        The sandbox folder that New-TestSandbox returned.
    .PARAMETER Path
        The full local path of the item.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]
        $Path
    )

    Assert-TestSandboxPath -Sandbox $Sandbox -Path $Path
    '\\localhost\{0}${1}' -f $Path.Substring(0, 1), $Path.Substring(2)
}

function New-TestDriveMapping {
    <#
    .SYNOPSIS
        Maps a free drive letter to a folder of the sandbox with subst and returns the root of the drive, such as Z:\.
        Returns nothing when the process cannot define a drive letter, as the restricted token of a basic user cannot.
    .DESCRIPTION
        For Windows and for the module, the root of the mapped drive is the root folder of a drive, so that a test can
        change it without changing a volume. The helper checks the folder with Assert-TestSandboxPath first and unmaps
        the letter again, with an error, when a marker file of the folder is not visible through it, so that a mapping
        that points elsewhere is never used. Remove the mapping with Remove-TestDriveMapping.
    .PARAMETER Sandbox
        The sandbox folder that New-TestSandbox returned.
    .PARAMETER Path
        The full path of the folder to map, in the sandbox.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only maps sandbox folders.'
    )]
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]
        $Path
    )

    Assert-TestSandboxPath -Sandbox $Sandbox -Path $Path
    $marker = [guid]::NewGuid().ToString('N')
    $markerPath = Join-Path -Path $Path -ChildPath $marker
    Assert-TestSandboxPath -Sandbox $Sandbox -Path $markerPath
    Set-Content -LiteralPath $markerPath -Value $marker
    $subst = Join-Path -Path $env:SystemRoot -ChildPath 'System32\subst.exe'

    # A test run in parallel can map a letter at the same moment, which makes subst fail for that letter.
    foreach ($letter in 'Z', 'Y', 'X', 'W', 'V', 'U', 'T', 'S') {
        $root = '{0}:\' -f $letter
        if (Test-Path -LiteralPath $root) {
            continue
        }

        & $subst ('{0}:' -f $letter) $Path *> $null
        if ($LASTEXITCODE -ne 0) {
            continue
        }

        if (Test-Path -LiteralPath (Join-Path -Path $root -ChildPath $marker)) {
            return $root
        }

        & $subst ('{0}:' -f $letter) /d *> $null
        throw "The drive '$root' does not show the sandbox folder '$Path'."
    }
}

function Remove-TestDriveMapping {
    <#
    .SYNOPSIS
        Removes a mapping of New-TestDriveMapping.
    .PARAMETER Root
        The root of the drive that New-TestDriveMapping returned, such as Z:\.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only removes its own mapping.'
    )]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Z]:\\$')]
        [string]
        $Root
    )

    & (Join-Path -Path $env:SystemRoot -ChildPath 'System32\subst.exe') $Root.TrimEnd('\') /d *> $null
    if (Test-Path -LiteralPath $Root) {
        Write-Error -Message "The drive mapping '$Root' could not be removed."
    }
}

function Test-DriveMappingAvailable {
    <#
    .SYNOPSIS
        Returns $true when the process can define a drive letter for a folder with subst, which the restricted token of
        the basic-user runner cannot.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $sandbox = New-TestSandbox -Name 'DriveProbe'
    try {
        $root = New-TestDriveMapping -Sandbox $sandbox -Path $sandbox
        if ($root) {
            Remove-TestDriveMapping -Root $root
        }

        [bool] $root
    }
    finally {
        Remove-TestSandbox -Sandbox $sandbox
    }
}

Export-ModuleMember -Function New-TestSandbox, Assert-TestSandboxPath, Remove-TestSandbox, New-TestSandboxItem,
    Block-TestReadPermission, Block-TestWritePermission, Add-TestDenyRule, Set-TestOwner, Set-TestNullDacl, Test-IsElevated,
    Test-PrivilegeHeld, Test-AdminShareAvailable, ConvertTo-TestAdminSharePath, New-TestDriveMapping,
    Remove-TestDriveMapping, Test-DriveMappingAvailable
