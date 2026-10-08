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
    $acl = Get-Acl -LiteralPath $Path
    foreach ($sid in $Rights.Keys) {
        $identity = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $sid
        $rule = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
            $identity, [System.Security.AccessControl.FileSystemRights] $Rights[$sid],
            [System.Security.AccessControl.AccessControlType]::Deny
        )
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
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

Export-ModuleMember -Function New-TestSandbox, Assert-TestSandboxPath, Remove-TestSandbox, New-TestSandboxItem,
    Block-TestReadPermission, Block-TestWritePermission, Add-TestDenyRule, Set-TestOwner, Test-IsElevated,
    Test-PrivilegeHeld
