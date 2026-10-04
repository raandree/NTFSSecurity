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
        [string]
        $Sandbox
    )

    Assert-TestSandboxPath -Sandbox $Sandbox -Path $Sandbox
    if (-not (Test-Path -LiteralPath $Sandbox)) {
        return
    }

    # Windows PowerShell 5.1 follows directory links when it removes a folder recursively, so the links go first.
    & icacls.exe $Sandbox /reset /T /C /Q *> $null
    $pending = New-Object -TypeName 'System.Collections.Generic.Stack[string]'
    $pending.Push($Sandbox)
    while ($pending.Count -gt 0) {
        foreach ($entry in [IO.Directory]::GetFileSystemEntries($pending.Pop())) {
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
    Get-ChildItem -LiteralPath $Sandbox -Recurse -Force | ForEach-Object -Process {
        $_.Attributes = [IO.FileAttributes]::Normal
    }
    Remove-Item -LiteralPath $Sandbox -Recurse -Force
    try {
        # Fails while another sandbox exists, also one of a test run in parallel
        [IO.Directory]::Delete($script:sandboxRoot, $false)
    }
    catch {
        Write-Verbose -Message "Keeping '$script:sandboxRoot': $($_.Exception.Message)"
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

Export-ModuleMember -Function New-TestSandbox, Assert-TestSandboxPath, Remove-TestSandbox, Test-IsElevated, Test-PrivilegeHeld
