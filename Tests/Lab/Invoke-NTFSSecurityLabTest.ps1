<#
.SYNOPSIS
    Runs the live tests of NTFSSecurity in an AutomatedLab lab against versions of the module.

.DESCRIPTION
    Prepares what NTFSSecurity.Live.Tests.ps1 needs in a lab with a domain controller, a file server, and a client of
    one domain, and runs the tests for each module version and PowerShell edition: on the client as the accounts of the
    roles Delegate, ServerAdmin, and Admin, then on the file server in the role Server. Each version runs in its own
    process. README.md describes the cases; the results and a summary go to a new folder in OutputPath.

    The script changes only the lab: the organizational unit NTFSSecurityLive with the accounts and groups of the
    tests, the local group NtfsLiveLocal and members of Administrators on the file server, members of Administrators
    and Remote Management Users on the client, the share NTFSSecurityLive, and the folders C:\NTFSSecurityLive and
    C:\NTFSSecurityLab. -RemoveFixture removes them again. The passwords of the accounts exist only in this process.

.PARAMETER LabName
    The name of the AutomatedLab lab.

.PARAMETER DomainController
    The domain controller that manages the accounts of the tests.

.PARAMETER FileServer
    The file server with the share. Its domain must be the domain of the domain controller.

.PARAMETER Client
    The computer that runs the tests. Its domain must be the domain of the domain controller.

.PARAMETER ForeignDomainController
    Domain controllers of other domains or forests, one per domain. The script creates the account NtfsLiveForeign in
    each of their domains, and the tests grant it access to share folders by SID and by name. The domains need a trust
    with the domain of the file server. Pass an empty array to leave these tests out.

.PARAMETER Version
    The versions of NTFSSecurity on the PowerShell Gallery to test, such as 5.0.0-rc4.

.PARAMETER ModulePath
    A folder with a build of the module, such as NTFSSecurity\bin\Release, to test as the version 'local'.

.PARAMETER Edition
    The PowerShell editions to test in: Desktop (Windows PowerShell 5.1) and Core (PowerShell 7).

.PARAMETER OutputPath
    The folder for the downloaded packages and the results.

.PARAMETER RemoveFixture
    Removes everything the script added to the lab, and runs no test.

.EXAMPLE
    .\Tests\Lab\Invoke-NTFSSecurityLabTest.ps1 -Version 5.0.0-rc2, 5.0.0-rc4 -Confirm:$false

    Runs the live tests against 5.0.0-rc2 and 5.0.0-rc4 in both PowerShell editions.

.EXAMPLE
    .\Tests\Lab\Invoke-NTFSSecurityLabTest.ps1 -RemoveFixture

    Removes the accounts, the share, and the folders of the live tests from the lab.

.NOTES
    Run it in an elevated Windows PowerShell 5.1 session on the Hyper-V host of the lab, with AutomatedLab.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Test')]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $LabName = 'WindowsAccessControlLab',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $DomainController = 'F1ADC1',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $FileServer = 'F1AFile2',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Client = 'F1AFile1',

    [Parameter()]
    [AllowEmptyCollection()]
    [string[]]
    $ForeignDomainController = @('F1BDC1', 'F2DC1', 'F3DC1'),

    [Parameter(ParameterSetName = 'Test')]
    [ValidatePattern('^\d+\.\d+\.\d+(-[0-9A-Za-z]+)?$')]
    [string[]]
    $Version = @('5.0.0-rc2', '5.0.0-rc4'),

    [Parameter(ParameterSetName = 'Test')]
    [ValidateScript({ Test-Path -LiteralPath (Join-Path -Path $_ -ChildPath 'NTFSSecurity.psd1') -PathType Leaf })]
    [string]
    $ModulePath,

    [Parameter(ParameterSetName = 'Test')]
    [ValidateSet('Desktop', 'Core')]
    [string[]]
    $Edition = @('Desktop', 'Core'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputPath = (Join-Path -Path $env:TEMP -ChildPath 'NTFSSecurityLab'),

    [Parameter(Mandatory, ParameterSetName = 'Remove')]
    [switch]
    $RemoveFixture
)

$ErrorActionPreference = 'Stop'

$currentPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList (
    [System.Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This script must run in an elevated (Run as Administrator) PowerShell session.'
}

$shareName = 'NTFSSecurityLive'
$shareLocalPath = 'C:\NTFSSecurityLive'
$payloadPath = 'C:\NTFSSecurityLab'
$organizationalUnitName = 'NTFSSecurityLive'
$roleAccounts = [ordered]@{
    Delegate    = 'NtfsLiveDelegate'
    ServerAdmin = 'NtfsLiveServerAdmin'
    Admin       = 'NtfsLiveAdmin'
}
$subjectBaseName = 'NtfsLiveSubject'
$orphanAccount = 'NtfsLiveOrphan'
$foreignAccount = 'NtfsLiveForeign'
# The rights that the entries of the foreign accounts grant on the folder of case 9, by position
$foreignRights = 'ReadAndExecute', 'Modify', 'Write'
$localGroupName = 'NtfsLiveLocal'
# The members of NtfsLiveInner follow when the name of the account of case 3 is known
$groupMembers = @{
    NtfsLiveDelegates = @('NtfsLiveDelegate')
    NtfsLiveInner     = @()
    NtfsLiveOuter     = @('NtfsLiveInner')
}
# A name that no DNS server resolves (RFC 2606)
$unreachableServerName = 'ntfssecurity-live.invalid'
# ReadAndExecute through the nested domain groups, Write through the local group of the file server, with Synchronize
$expectedFileServerRights = 0x1201BFL
$expectedClientRights = 0x1200A9L
$testFiles = 'NTFSSecurity.Live.Tests.ps1', 'NTFSSecurity.LabHelpers.ps1', 'Start-NTFSSecurityLiveTest.ps1' |
    ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath $_ }

function Write-LabProgress {
    param ([string] $Message)

    Write-Information -MessageData ('[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $Message) -InformationAction Continue
}

function New-LabPassword {
    <#
    .SYNOPSIS
        Returns a random password that meets the complexity rules of a domain.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a string in memory only.'
    )]
    [CmdletBinding()]
    [OutputType([securestring])]
    param ()

    $bytes = New-Object -TypeName 'byte[]' -ArgumentList 24
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }

    # Base64 has upper case and lower case letters and digits; the suffix adds the other classes.
    $password = New-Object -TypeName 'System.Security.SecureString'
    foreach ($character in ([Convert]::ToBase64String($bytes) + '!a1Z').ToCharArray()) {
        $password.AppendChar($character)
    }

    $password.MakeReadOnly()
    $password
}

function Get-NTFSSecurityPackage {
    <#
    .SYNOPSIS
        Downloads a version of NTFSSecurity from the PowerShell Gallery, checks its hash, and extracts the module.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Version,

        [Parameter(Mandatory)]
        [string]
        $Destination
    )

    $entry = Invoke-RestMethod -Uri ("https://www.powershellgallery.com/api/v2/Packages(Id='NTFSSecurity',Version='{0}')" -f $Version)
    $expectedHash = [string]$entry.entry.properties.PackageHash
    if ($entry.entry.properties.PackageHashAlgorithm -ne 'SHA512' -or -not $expectedHash) {
        throw "The PowerShell Gallery has no SHA512 hash for NTFSSecurity $Version."
    }

    $package = Join-Path -Path $Destination -ChildPath "NTFSSecurity.$Version.nupkg"
    if (-not (Test-Path -LiteralPath $package)) {
        Invoke-WebRequest -Uri "https://www.powershellgallery.com/api/v2/package/NTFSSecurity/$Version" -OutFile $package -UseBasicParsing
    }

    $sha512 = [System.Security.Cryptography.SHA512]::Create()
    try {
        $actualHash = [Convert]::ToBase64String($sha512.ComputeHash([System.IO.File]::ReadAllBytes($package)))
    }
    finally {
        $sha512.Dispose()
    }

    if ($actualHash -ne $expectedHash) {
        Remove-Item -LiteralPath $package
        throw "The package of NTFSSecurity $Version doesn't have the hash that the PowerShell Gallery publishes."
    }

    # Expand-Archive of Windows PowerShell rejects the extension .nupkg.
    $folder = Join-Path -Path $Destination -ChildPath $Version
    $moduleFolder = Join-Path -Path $folder -ChildPath 'NTFSSecurity'
    if (Test-Path -LiteralPath $folder) {
        Remove-Item -LiteralPath $folder -Recurse -Force
    }

    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($package, $moduleFolder)
    foreach ($name in '_rels', 'package', '[Content_Types].xml', 'NTFSSecurity.nuspec') {
        $item = Join-Path -Path $moduleFolder -ChildPath $name
        if (Test-Path -LiteralPath $item) {
            Remove-Item -LiteralPath $item -Recurse -Force
        }
    }

    $moduleVersion = Get-LabModuleVersion -Path $moduleFolder
    if ($moduleVersion -ne $Version) {
        throw "The package of NTFSSecurity $Version contains the version $moduleVersion."
    }

    [pscustomobject]@{
        Label         = $Version
        Folder        = $folder
        ModuleVersion = $moduleVersion
    }
}

function Get-LabModuleVersion {
    <#
    .SYNOPSIS
        Returns the version of the module in a folder, with the prerelease label, from its manifest.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $Path -ChildPath 'NTFSSecurity.psd1')
    $moduleVersion = $manifest.ModuleVersion
    if ($manifest.PrivateData.PSData.Prerelease) {
        $moduleVersion = '{0}-{1}' -f $moduleVersion, $manifest.PrivateData.PSData.Prerelease
    }

    $moduleVersion
}

function ConvertFrom-LabTestResult {
    <#
    .SYNOPSIS
        Returns the tests of a result file that Start-NTFSSecurityLiveTest.ps1 wrote, with their result and message.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string]
        $Json
    )

    # Windows PowerShell returns a JSON array as one object, which foreach enumerates.
    $tests = ConvertFrom-Json -InputObject $Json
    foreach ($test in $tests) {
        [pscustomobject]@{
            Name    = $test.Name
            Result  = $test.Result
            Message = [string]$test.Message
        }
    }
}

#region Remote script blocks
# Runs on the domain controller: returns the names of the accounts of case 3 that the organizational unit already has.
$findSubjectScript = {
    param ($OrganizationalUnitName, $BaseName)

    $ErrorActionPreference = 'Stop'
    Import-Module -Name ActiveDirectory
    $domain = Get-ADDomain
    $path = 'OU={0},{1}' -f $OrganizationalUnitName, $domain.DistinguishedName
    if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OrganizationalUnitName)" -SearchBase $domain.DistinguishedName -SearchScope OneLevel -Server $domain.PDCEmulator) {
        Get-ADUser -LDAPFilter "(sAMAccountName=$BaseName*)" -SearchBase $path -Server $domain.PDCEmulator | ForEach-Object -Process { $_.SamAccountName }
    }
}

# Runs on the domain controller: creates or updates the accounts and groups in their organizational unit, pushes them
# to the other domain controllers of the domain, and returns their SIDs.
$accountScript = {
    param ($OrganizationalUnitName, [hashtable] $Password, [hashtable] $GroupMember)

    $ErrorActionPreference = 'Stop'
    Import-Module -Name ActiveDirectory
    $domain = Get-ADDomain
    $server = $domain.PDCEmulator
    $path = 'OU={0},{1}' -f $OrganizationalUnitName, $domain.DistinguishedName
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OrganizationalUnitName)" -SearchBase $domain.DistinguishedName -SearchScope OneLevel -Server $server)) {
        New-ADOrganizationalUnit -Name $OrganizationalUnitName -Path $domain.DistinguishedName -ProtectedFromAccidentalDeletion $false -Server $server
    }

    foreach ($name in $Password.Keys) {
        $user = Get-ADUser -LDAPFilter "(sAMAccountName=$name)" -Server $server
        if ($user -and $user.DistinguishedName -notlike "*,$path") {
            throw "The account '$name' exists outside '$path'."
        }

        if ($user) {
            Set-ADAccountPassword -Identity $user -Reset -NewPassword $Password[$name] -Server $server
            Enable-ADAccount -Identity $user -Server $server
        }
        else {
            New-ADUser -Name $name -SamAccountName $name -UserPrincipalName "$name@$($domain.DNSRoot)" -Path $path -AccountPassword $Password[$name] -Enabled $true -PasswordNeverExpires $true -Server $server
        }
    }

    # All groups exist before the memberships are set, because a group can be a member of another one.
    $groups = @{}
    foreach ($name in $GroupMember.Keys) {
        $group = Get-ADGroup -LDAPFilter "(sAMAccountName=$name)" -Server $server
        if ($group -and $group.DistinguishedName -notlike "*,$path") {
            throw "The group '$name' exists outside '$path'."
        }

        if (-not $group) {
            $group = New-ADGroup -Name $name -SamAccountName $name -GroupScope Global -GroupCategory Security -Path $path -Server $server -PassThru
        }

        $groups[$name] = $group
    }

    foreach ($name in $GroupMember.Keys) {
        $group = $groups[$name]
        $current = @(Get-ADGroupMember -Identity $group -Server $server | ForEach-Object -Process { $_.SamAccountName })
        $wanted = @($GroupMember[$name])
        $missing = @($wanted | Where-Object -FilterScript { $_ -notin $current })
        $extra = @($current | Where-Object -FilterScript { $_ -notin $wanted })
        if ($missing) {
            Add-ADGroupMember -Identity $group -Members $missing -Server $server
        }

        if ($extra) {
            Remove-ADGroupMember -Identity $group -Members $extra -Server $server -Confirm:$false
        }
    }

    # The other domain controllers replicate on their own schedule, and the computers of the domain may ask them.
    $partners = @(Get-ADDomainController -Filter * -Server $server | Where-Object -FilterScript { $_.HostName -ne $server })
    foreach ($partner in $partners) {
        foreach ($object in Get-ADObject -SearchBase $path -Filter * -Server $server) {
            Sync-ADObject -Object $object.DistinguishedName -Source $server -Destination $partner.HostName
        }
    }

    $sids = @{}
    foreach ($name in @($Password.Keys) + @($GroupMember.Keys)) {
        $sids[$name] = (Get-ADObject -LDAPFilter "(sAMAccountName=$name)" -Properties objectSid -Server $server).objectSid.Value
    }

    $current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    [pscustomobject]@{
        DomainName  = $domain.DNSRoot
        NetBiosName = $domain.NetBIOSName
        Sids        = $sids
        InstallName = $current.Name
        InstallSid  = $current.User.Value
    }
}

# Runs on the domain controller: creates the account whose entry becomes orphaned in a run.
$newOrphanScript = {
    param ($OrganizationalUnitName, $Name, [securestring] $Password)

    $ErrorActionPreference = 'Stop'
    Import-Module -Name ActiveDirectory
    $domain = Get-ADDomain
    $server = $domain.PDCEmulator
    $path = 'OU={0},{1}' -f $OrganizationalUnitName, $domain.DistinguishedName
    # A run that stopped early may have left the account.
    Get-ADUser -LDAPFilter "(sAMAccountName=$Name)" -SearchBase $path -Server $server | Remove-ADUser -Server $server -Confirm:$false
    $user = New-ADUser -Name $Name -SamAccountName $Name -Path $path -AccountPassword $Password -Enabled $false -Server $server -PassThru
    [pscustomobject]@{
        Sid  = $user.SID.Value
        Guid = $user.ObjectGUID.Guid
    }
}

# Runs on the domain controller: deletes the account and waits until no domain controller of the domain knows it.
# Sync-ADObject can't push a deleted object, so the other domain controllers pull the domain partition.
$removeOrphanScript = {
    param ($Guid)

    $ErrorActionPreference = 'Stop'
    Import-Module -Name ActiveDirectory
    $domain = Get-ADDomain
    $server = $domain.PDCEmulator
    Remove-ADUser -Identity $Guid -Server $server -Confirm:$false
    foreach ($partner in @(Get-ADDomainController -Filter * -Server $server | Where-Object -FilterScript { $_.HostName -ne $server })) {
        $deadline = (Get-Date).AddMinutes(3)
        while (Get-ADObject -Filter "ObjectGUID -eq '$Guid'" -Server $partner.HostName) {
            if ((Get-Date) -gt $deadline) {
                throw "The domain controller $($partner.HostName) still knows the deleted account after 3 minutes."
            }

            $null = & repadmin.exe /replicate $partner.HostName $server $domain.DistinguishedName 2>&1
            Start-Sleep -Seconds 10
        }
    }
}

# Runs on a domain controller of another domain or forest: the account that the tests of case 9 grant access to.
$foreignAccountScript = {
    param ($OrganizationalUnitName, $Name, [securestring] $Password)

    $ErrorActionPreference = 'Stop'
    Import-Module -Name ActiveDirectory
    $domain = Get-ADDomain
    $server = $domain.PDCEmulator
    $path = 'OU={0},{1}' -f $OrganizationalUnitName, $domain.DistinguishedName
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OrganizationalUnitName)" -SearchBase $domain.DistinguishedName -SearchScope OneLevel -Server $server)) {
        New-ADOrganizationalUnit -Name $OrganizationalUnitName -Path $domain.DistinguishedName -ProtectedFromAccidentalDeletion $false -Server $server
    }

    $user = Get-ADUser -LDAPFilter "(sAMAccountName=$Name)" -Server $server
    if ($user -and $user.DistinguishedName -notlike "*,$path") {
        throw "The account '$Name' exists outside '$path'."
    }

    if ($user) {
        Set-ADAccountPassword -Identity $user -Reset -NewPassword $Password -Server $server
        Enable-ADAccount -Identity $user -Server $server
    }
    else {
        $user = New-ADUser -Name $Name -SamAccountName $Name -UserPrincipalName "$Name@$($domain.DNSRoot)" -Path $path -AccountPassword $Password -Enabled $true -PasswordNeverExpires $true -Server $server -PassThru
    }

    [pscustomobject]@{
        DomainName        = $domain.DNSRoot
        Name              = '{0}\{1}' -f $domain.NetBIOSName, $Name
        UserPrincipalName = '{0}@{1}' -f $Name, $domain.DNSRoot
        Sid               = $user.SID.Value
    }
}

# Runs on the file server once: the local group, the members of Administrators, the share, and the tools folder.
$fileServerSetupScript = {
    param ($ShareName, $ShareLocalPath, $PayloadPath, $LocalGroupName, $SubjectSid, $AdministratorSid, $DelegatesSid)

    $ErrorActionPreference = 'Stop'
    if (-not (Get-LocalGroup -Name $LocalGroupName -ErrorAction SilentlyContinue)) {
        $null = New-LocalGroup -Name $LocalGroupName -Description 'NTFSSecurity live tests'
    }

    # Add the members and ignore the error for a member that exists. A check with Get-LocalGroupMember would fail with "Failed to
    # compare two elements in the array" in Windows PowerShell 5.1 as soon as the group holds an orphaned SID, for example that of
    # an account that an earlier run deleted.
    try {
        Add-LocalGroupMember -Name $LocalGroupName -Member $SubjectSid
    }
    catch {
        if ($_.Exception.GetType().Name -ne 'MemberExistsException') {
            throw
        }
    }

    foreach ($sid in $AdministratorSid) {
        try {
            Add-LocalGroupMember -SID 'S-1-5-32-544' -Member $sid
        }
        catch {
            if ($_.Exception.GetType().Name -ne 'MemberExistsException') {
                throw
            }
        }
    }

    if (-not (Test-Path -LiteralPath $ShareLocalPath)) {
        $null = New-Item -ItemType Directory -Path $ShareLocalPath
    }

    # The folders of earlier runs, also those with paths longer than 260 characters, which PowerShell 7 removes. A recursive removal can
    # fail with "The directory is not empty" while another process, such as a virus scanner, still holds a handle to an item that was
    # just deleted (seen on Windows Server 2019), so it is repeated. The command writes its errors to its output: a line on stderr would
    # end this script at once, because the error action here is Stop and 2>&1 turns that line into a terminating error.
    $command = '$errors = @(); Get-ChildItem -LiteralPath ''__PATH__'' -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable errors; $errors | ForEach-Object -Process { "$_" }'.Replace('__PATH__', $ShareLocalPath)
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
    $attempt = 0
    do {
        $attempt++
        if ($attempt -gt 1) {
            Start-Sleep -Seconds 5
        }

        $output = & (Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe') -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
    } while (@(Get-ChildItem -LiteralPath $ShareLocalPath -Force -ErrorAction SilentlyContinue).Count -gt 0 -and $attempt -lt 6)

    if (@(Get-ChildItem -LiteralPath $ShareLocalPath -Force -ErrorAction SilentlyContinue).Count -gt 0) {
        throw "The folders of earlier runs could not be removed in $attempt attempts: $output"
    }

    # Administrators and the system own the share; the delegated group may read it, and the folders of the cases grant
    # what each case needs.
    $administrators = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-5-32-544'
    $acl = New-Object -TypeName 'System.Security.AccessControl.DirectorySecurity'
    $acl.SetOwner($administrators)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($entry in @(
            @{ Sid = 'S-1-5-32-544'; Rights = 'FullControl' }
            @{ Sid = 'S-1-5-18'; Rights = 'FullControl' }
            @{ Sid = $DelegatesSid; Rights = 'ReadAndExecute' }
        )) {
        $identity = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $entry.Sid
        $acl.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList $identity, $entry.Rights, 'ContainerInherit, ObjectInherit', 'None', 'Allow'))
    }

    Set-Acl -LiteralPath $ShareLocalPath -AclObject $acl
    if (-not (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
        $null = New-SmbShare -Name $ShareName -Path $ShareLocalPath -FullAccess 'Everyone' -Description 'NTFSSecurity live tests'
    }

    foreach ($folder in 'Tests', 'Configuration') {
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $PayloadPath -ChildPath $folder) -Force
    }

    (Get-LocalGroup -Name $LocalGroupName).SID.Value
}

# Runs on the client once: the members of Administrators and Remote Management Users, and an empty payload folder.
$clientSetupScript = {
    param ($PayloadPath, $AdministratorSid, $RemoteUserSid)

    $ErrorActionPreference = 'Stop'
    foreach ($membership in @(
            @{ Group = 'S-1-5-32-544'; Members = $AdministratorSid }
            @{ Group = 'S-1-5-32-580'; Members = $RemoteUserSid }
        )) {
        foreach ($sid in $membership.Members) {
            # See the file server setup: Get-LocalGroupMember fails on an orphaned SID.
            try {
                Add-LocalGroupMember -SID $membership.Group -Member $sid
            }
            catch {
                if ($_.Exception.GetType().Name -ne 'MemberExistsException') {
                    throw
                }
            }
        }
    }

    if (Test-Path -LiteralPath $PayloadPath) {
        Remove-Item -LiteralPath $PayloadPath -Recurse -Force
    }

    foreach ($folder in 'Modules', 'Tests', 'Configuration') {
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $PayloadPath -ChildPath $folder) -Force
    }
}

# Runs on the file server for each run: creates the folders of the cases below the share and returns what the
# configuration needs. Each case and operation gets its own folder, so that the tests don't depend on each other.
$fixtureScript = {
    param ($HelperScript, $ShareLocalPath, $RunId, $Sid, $SubjectPrincipalName, $LongPathSegment, $ForeignAccount)

    $ErrorActionPreference = 'Stop'
    . ([scriptblock]::Create($HelperScript))
    $root = Join-Path -Path $ShareLocalPath -ChildPath $RunId
    if (Test-Path -LiteralPath $root) {
        throw "The folder '$root' exists already."
    }

    $administrators = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-5-32-544'

    function New-AccessRule {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an object in memory only.'
        )]
        param ([string] $Sid, [string] $Rights)

        $identity = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $Sid
        New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList $identity, $Rights, 'ContainerInherit, ObjectInherit', 'None', 'Allow'
    }

    function New-FixtureFolder {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Runs in the fixture that the script confirmed.'
        )]
        param ([string] $RelativePath, [object[]] $AccessRule = @(), [switch] $Protected, [switch] $RemoveInherited,
            [switch] $Audit, [switch] $LegacyDacl, [switch] $InheritableAudit, [switch] $ProtectedAudit)

        $path = Join-Path -Path $root -ChildPath $RelativePath
        $null = New-Item -ItemType Directory -Path $path -Force
        $acl = Get-Acl -LiteralPath $path
        $acl.SetOwner($administrators)
        if ($Protected) {
            $acl.SetAccessRuleProtection($true, -not $RemoveInherited)
        }

        foreach ($rule in $AccessRule) {
            $acl.AddAccessRule($rule)
        }

        # Not Set-Acl: in Windows PowerShell, it also writes an empty, protected SACL, which drops the audit entries
        # that the folder inherits. SetAccessControl writes only the sections that changed.
        [System.IO.Directory]::SetAccessControl($path, $acl)
        if ($Audit -or $InheritableAudit -or $ProtectedAudit) {
            $auditAcl = Get-Acl -LiteralPath $path -Audit
            $everyone = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-1-0'
            if ($Audit) {
                $auditAcl.AddAuditRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList $everyone, 'Delete', 'None', 'None', 'Success'))
            }

            # An entry that the subfolders created afterwards inherit
            if ($InheritableAudit) {
                $auditAcl.AddAuditRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList $everyone, 'Delete', 'ContainerInherit, ObjectInherit', 'None', 'Failure'))
            }

            if ($ProtectedAudit) {
                $auditAcl.SetAuditRuleProtection($true, $false)
            }

            [System.IO.Directory]::SetAccessControl($path, $auditAcl)
        }

        # Set-Acl adds the auto-inherit flag, so the DACL is stored again without it at the end.
        if ($LegacyDacl) {
            Set-LabLegacyDacl -Path $path -Confirm:$false
        }

        if ((Get-LabSecurityDescriptor -Path $path).Owner.Value -ne 'S-1-5-32-544') {
            throw "Administrators don't own '$path'."
        }

        if ((Test-LabDaclAutoInherited -Path $path) -eq [bool]$LegacyDacl) {
            throw "The DACL of '$path' has the wrong auto-inherit flag."
        }

        $path
    }

    $null = New-Item -ItemType Directory -Path $root
    $delegatesFullControl = New-AccessRule -Sid $Sid.NtfsLiveDelegates -Rights 'FullControl'

    # Case 1 (#34): the delegated group has Full Control on folders that Administrators own.
    foreach ($variant in 'LegacyDacl', 'AutoInheritedDacl') {
        foreach ($operation in 'AddAccess', 'RemoveAccess', 'ClearAccess', 'DisableInheritance', 'EnableInheritance',
            'SetInheritance', 'SetSecurityDescriptor') {
            $rules = @($delegatesFullControl)
            if ($operation -eq 'RemoveAccess') {
                $rules += New-AccessRule -Sid 'S-1-1-0' -Rights 'ReadAndExecute'
            }

            $null = New-FixtureFolder -RelativePath "Case1\$variant\$operation" -AccessRule $rules -Protected:($operation -eq 'EnableInheritance') -LegacyDacl:($variant -eq 'LegacyDacl')
        }
    }

    # Case 2: the same Full Control, and an audit entry on the folders whose entry the tests read or remove.
    foreach ($auditRole in 'Admin', 'ServerAdmin', 'Delegate') {
        $null = New-FixtureFolder -RelativePath "Case2\$auditRole\GetAudit" -AccessRule $delegatesFullControl -Audit
        $null = New-FixtureFolder -RelativePath "Case2\$auditRole\AddAudit" -AccessRule $delegatesFullControl
        $null = New-FixtureFolder -RelativePath "Case2\$auditRole\RemoveAudit" -AccessRule $delegatesFullControl -Audit
    }

    # Case 3: only these entries, so that the expected rights are known.
    $effectivePath = New-FixtureFolder -RelativePath 'Case3\EffectiveAccess' -Protected -RemoveInherited -AccessRule @(
        New-AccessRule -Sid 'S-1-5-32-544' -Rights 'FullControl'
        New-AccessRule -Sid 'S-1-5-18' -Rights 'FullControl'
        New-AccessRule -Sid $Sid.NtfsLiveOuter -Rights 'ReadAndExecute'
        New-AccessRule -Sid $Sid.LocalGroup -Rights 'Write'
    )
    $effectiveDescriptor = Get-LabSecurityDescriptor -Path $effectivePath
    $fileServerRights = Get-LabGrantedRight -Descriptor $effectiveDescriptor -Sid @(Get-LabTokenSid -UserPrincipalName $SubjectPrincipalName)

    # Case 4: an entry for the account that the domain controller deletes next, and a file that inherits it.
    $orphanPath = New-FixtureFolder -RelativePath 'Case4\OrphanedAccess' -AccessRule (New-AccessRule -Sid $Sid.Orphan -Rights 'Modify')
    Set-Content -LiteralPath (Join-Path -Path $orphanPath -ChildPath 'File.txt') -Value 'Orphan'
    $orphanAuditPath = New-FixtureFolder -RelativePath 'Case4\OrphanedAudit' -AccessRule $delegatesFullControl
    $orphanAuditAcl = Get-Acl -LiteralPath $orphanAuditPath -Audit
    $orphanIdentity = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $Sid.Orphan
    $orphanAuditAcl.AddAuditRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList $orphanIdentity, 'Delete', 'None', 'None', 'Success'))
    [System.IO.Directory]::SetAccessControl($orphanAuditPath, $orphanAuditAcl)

    # A file whose path on the share is longer than 260 characters, created by PowerShell 7, which handles such paths.
    $longPath = New-FixtureFolder -RelativePath 'LongPath'
    $longRelativePath = ($LongPathSegment -join '\') + '\File.txt'
    $command = '$ErrorActionPreference = ''Stop''; $file = ''{0}''; $null = New-Item -ItemType Directory -Path (Split-Path -Path $file -Parent) -Force; Set-Content -LiteralPath $file -Value ''LongPath''' -f (Join-Path -Path $longPath -ChildPath $longRelativePath)
    $output = & (Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe') -NoProfile -NonInteractive -EncodedCommand ([Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))) 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "The long path could not be created: $output"
    }

    $whatIfPath = New-FixtureFolder -RelativePath 'WhatIf'
    Set-Content -LiteralPath (Join-Path -Path $whatIfPath -ChildPath 'Source.txt') -Value 'Source' -NoNewline
    Set-Content -LiteralPath (Join-Path -Path $whatIfPath -ChildPath 'Destination.txt') -Value 'Destination' -NoNewline

    # Case 5: the owner cmdlets, and case 6: the audit inheritance cmdlets and Clear-NTFSAudit below a folder whose
    # audit entry the subfolders inherit, on folders that Administrators own and the delegated group fully controls.
    foreach ($role in 'Admin', 'ServerAdmin', 'Delegate') {
        foreach ($operation in 'GetOwner', 'TakeOwnership', 'AssignOwner') {
            $null = New-FixtureFolder -RelativePath "Case5\$role\$operation" -AccessRule $delegatesFullControl
        }

        $null = New-FixtureFolder -RelativePath "Case6\$role" -AccessRule $delegatesFullControl -InheritableAudit
        $null = New-FixtureFolder -RelativePath "Case6\$role\DisableAuditInheritance"
        $null = New-FixtureFolder -RelativePath "Case6\$role\EnableAuditInheritance" -ProtectedAudit
        $null = New-FixtureFolder -RelativePath "Case6\$role\ClearAudit" -Audit
        $null = New-FixtureFolder -RelativePath "Case6\$role\GetInheritance" -Protected
    }

    # Case 7: the item cmdlets in a folder that the delegated group fully controls.
    $itemsPath = New-FixtureFolder -RelativePath 'Case7\Items' -AccessRule $delegatesFullControl
    foreach ($name in 'Source', 'Move', 'Remove') {
        Set-Content -LiteralPath (Join-Path -Path $itemsPath -ChildPath "$name.txt") -Value $name -NoNewline
    }

    $null = New-Item -ItemType Directory -Path (Join-Path -Path $itemsPath -ChildPath 'Folder')
    Set-Content -LiteralPath (Join-Path -Path $itemsPath -ChildPath 'Folder\File.txt') -Value 'File' -NoNewline

    $hiddenPath = New-FixtureFolder -RelativePath 'Case7\Hidden' -AccessRule $delegatesFullControl
    $hiddenFile = Join-Path -Path $hiddenPath -ChildPath 'Only.txt'
    Set-Content -LiteralPath $hiddenFile -Value 'Hidden' -NoNewline
    [System.IO.File]::SetAttributes($hiddenFile, [System.IO.FileAttributes]::Hidden)

    # Case 8: the link cmdlets.
    $linksPath = New-FixtureFolder -RelativePath 'Case8\Links' -AccessRule $delegatesFullControl
    Set-Content -LiteralPath (Join-Path -Path $linksPath -ChildPath 'Target.txt') -Value 'Target' -NoNewline
    $null = New-Item -ItemType Directory -Path (Join-Path -Path $linksPath -ChildPath 'TargetFolder')

    # Case 9: a subfolder with an entry of its own for Get-NTFSSimpleAccess, and the accounts of other domains.
    $null = New-FixtureFolder -RelativePath 'Case9\Simple' -AccessRule $delegatesFullControl
    $null = New-FixtureFolder -RelativePath 'Case9\Simple\Child' -AccessRule (New-AccessRule -Sid $Sid.Subject -Rights 'Modify')
    $foreignPath = New-FixtureFolder -RelativePath 'Case9\Foreign' -AccessRule @(
        foreach ($account in $ForeignAccount) {
            New-AccessRule -Sid $account.Sid -Rights $account.Rights
        }
    )
    $null = New-FixtureFolder -RelativePath 'Case9\ForeignAdd' -AccessRule $delegatesFullControl
    $null = New-FixtureFolder -RelativePath 'Case9\ForeignRemove' -AccessRule @(
        foreach ($account in $ForeignAccount) {
            New-AccessRule -Sid $account.Sid -Rights 'ReadAndExecute'
        }
    )

    # Case 10: the behavior that the fixes of the quality gate before 5.0.0 changed. The tests create their items below the
    # folder of their role, which the delegated group fully controls. Administrators own the folder Locked, whose
    # permissions the delegated account denies itself, and the files that Set-NTFSOwner changes: a file that the account
    # created would be owned by the account already.
    $null = New-FixtureFolder -RelativePath 'Case10' -AccessRule $delegatesFullControl
    $null = New-FixtureFolder -RelativePath 'Case10\Locked'
    foreach ($role in 'Admin', 'ServerAdmin', 'Delegate') {
        foreach ($style in 'Select', 'Throw') {
            foreach ($ownerFolder in "SetOwner-$style", "SetOwner-Debug$style") {
                $ownerPath = New-FixtureFolder -RelativePath "Case10\$role\LaterCommand\$ownerFolder"
                foreach ($name in 'First', 'Second') {
                    $file = Join-Path -Path $ownerPath -ChildPath "$name.txt"
                    Set-Content -LiteralPath $file -Value $name -NoNewline
                    if ((Get-LabSecurityDescriptor -Path $file).Owner.Value -ne 'S-1-5-32-544') {
                        throw "Administrators don't own '$file'."
                    }
                }
            }
        }
    }

    # The rights that the file server's own token of each foreign account gets on the folder, like case 3. A token
    # that the file server can't create is reported as -1, which fails only the effective-access test of the account.
    $foreignDescriptor = Get-LabSecurityDescriptor -Path $foreignPath
    $foreignEffectiveRights = @{}
    foreach ($account in $ForeignAccount) {
        try {
            $foreignEffectiveRights[$account.Sid] = Get-LabGrantedRight -Descriptor $foreignDescriptor -Sid @(Get-LabTokenSid -UserPrincipalName $account.UserPrincipalName)
        }
        catch {
            $foreignEffectiveRights[$account.Sid] = -1L
        }
    }

    [pscustomobject]@{
        ServerPath             = $root
        FileServerRights       = $fileServerRights
        EffectiveAccessSddl    = $effectiveDescriptor.GetSddlForm('All')
        LongPath               = $longRelativePath
        ForeignEffectiveRights = $foreignEffectiveRights
    }
}

# Runs on the client for each run: the rights that the client's own token for the account grants on the folder of
# case 3, and whether the client still resolves the SID of the deleted account.
$clientOracleScript = {
    param ($HelperScript, $EffectiveAccessSddl, $SubjectPrincipalName, $OrphanSid)

    $ErrorActionPreference = 'Stop'
    . ([scriptblock]::Create($HelperScript))
    $descriptor = New-Object -TypeName 'System.Security.AccessControl.RawSecurityDescriptor' -ArgumentList $EffectiveAccessSddl
    $orphanResolved = $true
    try {
        $null = (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $OrphanSid).Translate([System.Security.Principal.NTAccount])
    }
    catch [System.Security.Principal.IdentityNotMappedException] {
        $orphanResolved = $false
    }

    [pscustomobject]@{
        ClientRights   = Get-LabGrantedRight -Descriptor $descriptor -Sid @(Get-LabTokenSid -UserPrincipalName $SubjectPrincipalName)
        OrphanResolved = $orphanResolved
    }
}

# Runs on the client and the file server: writes the configuration of a run.
$writeConfigurationScript = {
    param ($Path, $Json)

    $ErrorActionPreference = 'Stop'
    Set-Content -LiteralPath $Path -Value $Json -Encoding UTF8
}

# Runs on the client as the account of a role, or on the file server: runs the tests of the role in a new process.
$runScript = {
    param ($Edition, $TestPath, $ModulePath, $ConfigurationPath, $Role)

    $executable = if ($Edition -eq 'Core') {
        Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe'
    }
    else {
        Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    $resultPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('NTFSSecurityLive-{0}.json' -f [guid]::NewGuid().ToString('N'))
    $arguments = @(
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass'
        '-File', (Join-Path -Path $TestPath -ChildPath 'Start-NTFSSecurityLiveTest.ps1')
        '-ConfigurationPath', $ConfigurationPath, '-Role', $Role, '-ResultPath', $resultPath
    )
    if ($ModulePath) {
        $arguments += '-ModulePath', $ModulePath
    }

    $output = & $executable @arguments 2>&1 | ForEach-Object -Process { "$_" }
    $exitCode = $LASTEXITCODE
    $result = if (Test-Path -LiteralPath $resultPath) { Get-Content -LiteralPath $resultPath -Raw }
    Remove-Item -LiteralPath $resultPath -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Account  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        ExitCode = $exitCode
        Output   = $output -join [Environment]::NewLine
        Result   = $result
    }
}

# Runs on the file server after the tests of a run: the stored owner, group, and DACL, and the SACL of each folder.
$stateScript = {
    param ($HelperScript, $Root)

    $ErrorActionPreference = 'Stop'
    . ([scriptblock]::Create($HelperScript))
    foreach ($folder in Get-ChildItem -LiteralPath $Root -Directory -Recurse -Depth 2) {
        [pscustomobject]@{
            Path   = $folder.FullName.Substring($Root.Length + 1)
            Stored = (Get-LabSecurityDescriptor -Path $folder.FullName).GetSddlForm('All')
            Sacl   = (Get-Acl -LiteralPath $folder.FullName -Audit).GetSecurityDescriptorSddlForm('Audit')
        }
    }
}
# Runs on the domain controller: the SIDs of the accounts in the organizational unit, for -RemoveFixture.
$accountSidScript = {
    param ($OrganizationalUnitName)

    $ErrorActionPreference = 'Stop'
    Import-Module -Name ActiveDirectory
    $domain = Get-ADDomain
    $path = 'OU={0},{1}' -f $OrganizationalUnitName, $domain.DistinguishedName
    if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OrganizationalUnitName)" -SearchBase $domain.DistinguishedName -SearchScope OneLevel -Server $domain.PDCEmulator) {
        Get-ADUser -Filter * -SearchBase $path -Server $domain.PDCEmulator | ForEach-Object -Process { $_.SID.Value }
    }
}

$removeFileServerScript = {
    param ($ShareName, $ShareLocalPath, $PayloadPath, $LocalGroupName, $Sid)

    $ErrorActionPreference = 'Stop'
    if (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue) {
        Remove-SmbShare -Name $ShareName -Force
    }

    foreach ($path in $ShareLocalPath, $PayloadPath) {
        # PowerShell 7 removes the symbolic links of the tests without following them, which Windows PowerShell 5.1 doesn't do. A recursive
        # removal can still fail with "The directory is not empty" while another process, such as a virus scanner, holds a handle to an item
        # that was just deleted (seen on Windows Server 2019); a moment later nothing is left. So the removal is repeated before it fails.
        # The command writes its errors to its output: a line on stderr would end this script at once (see the setup of the file server).
        $command = '$errors = @(); Remove-Item -LiteralPath ''__PATH__'' -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable errors; $errors | ForEach-Object -Process { "$_" }'.Replace('__PATH__', $path)
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
        $attempt = 0
        while ((Test-Path -LiteralPath $path) -and $attempt -lt 6) {
            $attempt++
            if ($attempt -gt 1) {
                Start-Sleep -Seconds 5
            }

            $output = & (Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe') -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
        }

        if (Test-Path -LiteralPath $path) {
            throw "'$path' could not be removed in $attempt attempts: $output"
        }

        if ($attempt -gt 1) {
            "'$path' was removed in $attempt attempts."
        }
    }

    if (Get-LocalGroup -Name $LocalGroupName -ErrorAction SilentlyContinue) {
        Remove-LocalGroup -Name $LocalGroupName
    }

    foreach ($accountSid in $Sid) {
        Remove-LocalGroupMember -SID 'S-1-5-32-544' -Member $accountSid -ErrorAction SilentlyContinue
    }
}

$removeClientScript = {
    param ($PayloadPath, $Sid)

    $ErrorActionPreference = 'Stop'
    foreach ($group in 'S-1-5-32-544', 'S-1-5-32-580') {
        foreach ($accountSid in $Sid) {
            Remove-LocalGroupMember -SID $group -Member $accountSid -ErrorAction SilentlyContinue
        }
    }

    # A profile that is gone in the meantime needs no removal; one that is still there after the error does.
    foreach ($userProfile in @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object -FilterScript { $_.SID -in $Sid })) {
        try {
            Remove-CimInstance -InputObject $userProfile
        }
        catch {
            if (Get-CimInstance -ClassName Win32_UserProfile -Filter ("SID = '{0}'" -f $userProfile.SID) -ErrorAction SilentlyContinue) {
                throw
            }
        }
    }

    if (Test-Path -LiteralPath $PayloadPath) {
        Remove-Item -LiteralPath $PayloadPath -Recurse -Force
    }
}

$removeAccountScript = {
    param ($OrganizationalUnitName)

    $ErrorActionPreference = 'Stop'
    Import-Module -Name ActiveDirectory
    $domain = Get-ADDomain
    $unit = Get-ADOrganizationalUnit -LDAPFilter "(ou=$OrganizationalUnitName)" -SearchBase $domain.DistinguishedName -SearchScope OneLevel -Server $domain.PDCEmulator
    if ($unit) {
        Remove-ADOrganizationalUnit -Identity $unit -Recursive -Server $domain.PDCEmulator -Confirm:$false
    }
}
#endregion Remote script blocks

Import-Module -Name AutomatedLab -ErrorAction Stop
Import-Lab -Name $LabName -NoValidation -NoDisplay
$machines = foreach ($name in $DomainController, $FileServer, $Client) {
    $machine = Get-LabVM -ComputerName $name
    if (-not $machine) {
        throw "The lab '$LabName' has no machine '$name'."
    }

    $machine
}

if (@($machines | ForEach-Object -Process { $_.DomainName } | Select-Object -Unique).Count -ne 1) {
    throw 'The domain controller, the file server, and the client must belong to one domain.'
}

foreach ($name in $ForeignDomainController) {
    $machine = Get-LabVM -ComputerName $name
    if (-not $machine) {
        throw "The lab '$LabName' has no machine '$name'."
    }

    if ($machine.DomainName -eq $machines[0].DomainName) {
        throw "The foreign domain controller '$name' must belong to another domain than the file server."
    }
}

if (@($ForeignDomainController | ForEach-Object -Process { (Get-LabVM -ComputerName $_).DomainName } | Select-Object -Unique).Count -ne @($ForeignDomainController).Count) {
    throw 'Each foreign domain controller must belong to a domain of its own.'
}

$helperScript = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'NTFSSecurity.LabHelpers.ps1') -Raw
$labCommand = @{
    NoDisplay   = $true
    PassThru    = $true
    ErrorAction = 'Stop'
}

if ($RemoveFixture) {
    if (-not $PSCmdlet.ShouldProcess("lab '$LabName'", 'Remove the accounts, the share, and the folders of the live tests')) {
        return
    }

    $accountSids = @(Invoke-LabCommand -ComputerName $DomainController -ActivityName 'Read the accounts' -ScriptBlock $accountSidScript -ArgumentList $organizationalUnitName @labCommand)
    $removed = Invoke-LabCommand -ComputerName $FileServer -ActivityName 'Remove the share and the folders' -ScriptBlock $removeFileServerScript -ArgumentList $shareName, $shareLocalPath, $payloadPath, $localGroupName, $accountSids @labCommand
    foreach ($message in @($removed)) {
        Write-LabProgress "${FileServer}: $message"
    }
    $null = Invoke-LabCommand -ComputerName $Client -ActivityName 'Remove the members and the folder' -ScriptBlock $removeClientScript -ArgumentList $payloadPath, $accountSids @labCommand
    $null = Invoke-LabCommand -ComputerName $DomainController -ActivityName 'Remove the accounts' -ScriptBlock $removeAccountScript -ArgumentList $organizationalUnitName @labCommand
    foreach ($computer in $ForeignDomainController) {
        $null = Invoke-LabCommand -ComputerName $computer -ActivityName 'Remove the account of another domain' -ScriptBlock $removeAccountScript -ArgumentList $organizationalUnitName @labCommand
    }

    Write-LabProgress "Removed the live tests from the lab '$LabName'."
    return
}

$labels = @($Version) + @(if ($ModulePath) { 'local' })
if (-not $PSCmdlet.ShouldProcess("lab '$LabName'", "Prepare the live tests and run them against $($labels -join ', ')")) {
    return
}

$resultFolder = Join-Path -Path $OutputPath -ChildPath ('Results\{0:yyyyMMdd-HHmmss}' -f (Get-Date))
$packageFolder = Join-Path -Path $OutputPath -ChildPath 'Packages'
$null = New-Item -ItemType Directory -Path $resultFolder, $packageFolder -Force
Write-LabProgress "START live tests in the lab '$LabName' against $($labels -join ', ') in $($Edition -join ', '); results in $resultFolder"

$modules = @(
    foreach ($item in $Version) {
        Get-NTFSSecurityPackage -Version $item -Destination $packageFolder
    }

    if ($ModulePath) {
        $folder = Join-Path -Path $packageFolder -ChildPath 'local'
        if (Test-Path -LiteralPath $folder) {
            Remove-Item -LiteralPath $folder -Recurse -Force
        }

        $null = New-Item -ItemType Directory -Path $folder
        Copy-Item -LiteralPath (Resolve-Path -LiteralPath $ModulePath).ProviderPath -Destination (Join-Path -Path $folder -ChildPath 'NTFSSecurity') -Recurse
        [pscustomobject]@{
            Label         = 'local'
            Folder        = $folder
            ModuleVersion = Get-LabModuleVersion -Path (Join-Path -Path $folder -ChildPath 'NTFSSecurity')
        }
    }
)

Write-LabProgress 'Preparing the accounts, the file server, and the client'
# When an account is deleted and created again with the same name, the remote authorization managers of the client and of the file server, which
# Get-NTFSEffectiveAccess asks for its default -ServerName and for the name of the file server, keep answering for about ten minutes as if the new
# account had no groups (Synchronize only), whichever version of the module runs. The local manager and a Kerberos S4U logon of the account, which
# the oracle uses, are right at that moment (Decision 24). So a new fixture gets a name for the account of case 3 that an earlier fixture is unlikely
# to have used (four random digits); a fixture that exists keeps its account.
$existingSubjects = @(Invoke-LabCommand -ComputerName $DomainController -ActivityName 'Look for the account of case 3' -ScriptBlock $findSubjectScript -ArgumentList $organizationalUnitName, $subjectBaseName @labCommand)
$subjectAccount = if ($existingSubjects) { [string]$existingSubjects[0] } else { '{0}{1:D4}' -f $subjectBaseName, (Get-Random -Minimum 0 -Maximum 10000) }
$groupMembers['NtfsLiveInner'] = @($subjectAccount)
$passwords = @{}
foreach ($name in @($roleAccounts.Values) + $subjectAccount) {
    $passwords[$name] = New-LabPassword
}

$directory = Invoke-LabCommand -ComputerName $DomainController -ActivityName 'Prepare the accounts' -ScriptBlock $accountScript -ArgumentList $organizationalUnitName, $passwords, $groupMembers @labCommand
$sids = $directory.Sids
$foreignAccounts = @(
    for ($index = 0; $index -lt @($ForeignDomainController).Count; $index++) {
        $account = Invoke-LabCommand -ComputerName $ForeignDomainController[$index] -ActivityName 'Prepare the account of another domain' -ScriptBlock $foreignAccountScript -ArgumentList $organizationalUnitName, $foreignAccount, (New-LabPassword) @labCommand
        [pscustomobject]@{
            DomainName        = $account.DomainName
            Name              = $account.Name
            UserPrincipalName = $account.UserPrincipalName
            Sid               = $account.Sid
            Rights            = $foreignRights[$index % $foreignRights.Count]
        }
    }
)
$localGroupSid = Invoke-LabCommand -ComputerName $FileServer -ActivityName 'Prepare the file server' -ScriptBlock $fileServerSetupScript -ArgumentList $shareName, $shareLocalPath, $payloadPath, $localGroupName, $sids[$subjectAccount], @($sids['NtfsLiveServerAdmin'], $sids['NtfsLiveAdmin']), $sids['NtfsLiveDelegates'] @labCommand
$null = Invoke-LabCommand -ComputerName $Client -ActivityName 'Prepare the client' -ScriptBlock $clientSetupScript -ArgumentList $payloadPath, @($sids['NtfsLiveDelegate'], $sids['NtfsLiveAdmin']), @($sids['NtfsLiveServerAdmin']) @labCommand
foreach ($computer in $Client, $FileServer) {
    Copy-LabFileItem -Path $testFiles -ComputerName $computer -DestinationFolderPath (Join-Path -Path $payloadPath -ChildPath 'Tests')
}

foreach ($module in $modules) {
    Copy-LabFileItem -Path $module.Folder -ComputerName $Client -DestinationFolderPath (Join-Path -Path $payloadPath -ChildPath 'Modules') -Recurse
}

$expectedFiles = @($modules | ForEach-Object -Process { Join-Path -Path $payloadPath -ChildPath ('Modules\{0}\NTFSSecurity\NTFSSecurity.psd1' -f $_.Label) }) +
    @($testFiles | ForEach-Object -Process { Join-Path -Path $payloadPath -ChildPath ('Tests\{0}' -f (Split-Path -Path $_ -Leaf)) })
$missingFiles = @(Invoke-LabCommand -ComputerName $Client -ActivityName 'Check the payload' -ScriptBlock {
        param ($Path)

        $Path | Where-Object -FilterScript { -not (Test-Path -LiteralPath $_ -PathType Leaf) }
    } -ArgumentList (, $expectedFiles) @labCommand)
if ($missingFiles.Count -gt 0) {
    throw "The client lacks these files: $($missingFiles -join ', ')"
}

$credentials = @{}
foreach ($role in $roleAccounts.Keys) {
    $userName = '{0}\{1}' -f $directory.NetBiosName, $roleAccounts[$role]
    $credentials[$role] = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList $userName, $passwords[$roleAccounts[$role]]
}

$clientAddress = (Get-LabVM -ComputerName $Client).IpV4Address
$fileServerFqdn = '{0}.{1}' -f $FileServer, $directory.DomainName
$subjectPrincipalName = '{0}@{1}' -f $subjectAccount, $directory.DomainName
$longPathSegments = 1..6 | ForEach-Object -Process { 'Segment{0:D2}-{1}' -f $_, ('x' * 40) }
$summary = New-Object -TypeName 'System.Collections.Generic.List[object]'

foreach ($module in $modules) {
    foreach ($runEdition in $Edition) {
        $runId = '{0}-{1}-{2:yyyyMMddHHmmss}' -f $module.Label, $runEdition, (Get-Date)
        Write-LabProgress "Run ${runId}: preparing the folders"
        $orphan = Invoke-LabCommand -ComputerName $DomainController -ActivityName 'Create the orphan account' -ScriptBlock $newOrphanScript -ArgumentList $organizationalUnitName, $orphanAccount, (New-LabPassword) @labCommand
        $fixtureSids = @{
            NtfsLiveDelegates = $sids['NtfsLiveDelegates']
            NtfsLiveOuter     = $sids['NtfsLiveOuter']
            LocalGroup        = [string]$localGroupSid
            Orphan            = $orphan.Sid
            Subject           = $sids[$subjectAccount]
        }
        $fixture = Invoke-LabCommand -ComputerName $FileServer -ActivityName 'Create the folders of the run' -ScriptBlock $fixtureScript -ArgumentList $helperScript, $shareLocalPath, $runId, $fixtureSids, $subjectPrincipalName, $longPathSegments, $foreignAccounts @labCommand
        $null = Invoke-LabCommand -ComputerName $DomainController -ActivityName 'Delete the orphan account' -ScriptBlock $removeOrphanScript -ArgumentList $orphan.Guid @labCommand
        $oracle = Invoke-LabCommand -ComputerName $Client -ActivityName 'Calculate the rights on the client' -ScriptBlock $clientOracleScript -ArgumentList $helperScript, $fixture.EffectiveAccessSddl, $subjectPrincipalName, $orphan.Sid @labCommand
        if ($oracle.OrphanResolved) {
            throw "The client still resolves the SID $($orphan.Sid) of the deleted account."
        }

        if ($fixture.FileServerRights -ne $expectedFileServerRights -or $oracle.ClientRights -ne $expectedClientRights) {
            throw ('The tokens of {0} grant 0x{1:X} on the file server and 0x{2:X} on the client instead of 0x{3:X} and 0x{4:X}.' -f
                $subjectAccount, [long]$fixture.FileServerRights, [long]$oracle.ClientRights, $expectedFileServerRights, $expectedClientRights)
        }

        $configuration = [ordered]@{
            RunId                 = $runId
            ModuleVersion         = $module.ModuleVersion
            Edition               = $runEdition
            DomainName            = $directory.DomainName
            Client                = $Client
            FileServer            = $FileServer
            FileServerFqdn        = $fileServerFqdn
            ShareName             = $shareName
            ShareLocalPath        = $shareLocalPath
            SharePath             = '\\{0}\{1}\{2}' -f $fileServerFqdn, $shareName, $runId
            ServerPath            = $fixture.ServerPath
            UnreachableServerName = $unreachableServerName
            LongPath              = $fixture.LongPath
            EffectiveAccess       = [ordered]@{
                FileServerRights = [long]$fixture.FileServerRights
                ClientRights     = [long]$oracle.ClientRights
            }
            ForeignAccounts       = @(
                foreach ($account in $foreignAccounts) {
                    [ordered]@{
                        Name            = $account.Name
                        DomainName      = $account.DomainName
                        Sid             = $account.Sid
                        Rights          = $account.Rights
                        EffectiveRights = [long]$fixture.ForeignEffectiveRights[$account.Sid]
                    }
                }
            )
            Accounts              = [ordered]@{
                Delegate    = [ordered]@{ Name = $credentials['Delegate'].UserName; Sid = $sids['NtfsLiveDelegate']; ClientAdministrator = $true; FileServerAdministrator = $false }
                ServerAdmin = [ordered]@{ Name = $credentials['ServerAdmin'].UserName; Sid = $sids['NtfsLiveServerAdmin']; ClientAdministrator = $false; FileServerAdministrator = $true }
                Admin       = [ordered]@{ Name = $credentials['Admin'].UserName; Sid = $sids['NtfsLiveAdmin']; ClientAdministrator = $true; FileServerAdministrator = $true }
                Server      = [ordered]@{ Name = $directory.InstallName; Sid = $directory.InstallSid; ClientAdministrator = $true; FileServerAdministrator = $true }
                Subject     = [ordered]@{ Name = '{0}\{1}' -f $directory.NetBiosName, $subjectAccount; Sid = $sids[$subjectAccount] }
                Orphan      = [ordered]@{ Name = '{0}\{1}' -f $directory.NetBiosName, $orphanAccount; Sid = $orphan.Sid }
            }
        }
        $json = $configuration | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath (Join-Path -Path $resultFolder -ChildPath "$runId.json") -Value $json
        $configurationPath = Join-Path -Path $payloadPath -ChildPath "Configuration\$runId.json"
        foreach ($computer in $Client, $FileServer) {
            $null = Invoke-LabCommand -ComputerName $computer -ActivityName 'Write the configuration' -ScriptBlock $writeConfigurationScript -ArgumentList $configurationPath, $json @labCommand
        }

        $runs = @(
            foreach ($role in $roleAccounts.Keys) {
                @{ Role = $role; Edition = $runEdition; ModulePath = Join-Path -Path $payloadPath -ChildPath ('Modules\{0}\NTFSSecurity' -f $module.Label) }
            }
            @{ Role = 'Server'; Edition = 'Desktop'; ModulePath = '' }
        )
        foreach ($run in $runs) {
            Write-LabProgress "Run ${runId}: role $($run.Role)"
            $arguments = $run.Edition, (Join-Path -Path $payloadPath -ChildPath 'Tests'), $run.ModulePath, $configurationPath, $run.Role
            if ($run.Role -eq 'Server') {
                $outcome = Invoke-LabCommand -ComputerName $FileServer -ActivityName 'Run the tests of the role Server' -ScriptBlock $runScript -ArgumentList $arguments @labCommand
            }
            else {
                $session = New-PSSession -ComputerName $clientAddress -Credential $credentials[$run.Role] -Authentication Credssp
                try {
                    $outcome = Invoke-Command -Session $session -ScriptBlock $runScript -ArgumentList $arguments
                }
                finally {
                    Remove-PSSession -Session $session
                }
            }

            $baseName = '{0}-{1}' -f $runId, $run.Role
            Set-Content -LiteralPath (Join-Path -Path $resultFolder -ChildPath "$baseName.log") -Value $outcome.Output
            $cases = @()
            if ($outcome.Result) {
                Set-Content -LiteralPath (Join-Path -Path $resultFolder -ChildPath "$baseName.result.json") -Value $outcome.Result
                $cases = @(ConvertFrom-LabTestResult -Json $outcome.Result)
            }

            $failures = @($cases | Where-Object -FilterScript { $_.Result -eq 'Failed' })
            $entry = [pscustomobject]@{
                Version  = $module.Label
                Edition  = $runEdition
                Role     = $run.Role
                Account  = $outcome.Account
                ExitCode = $outcome.ExitCode
                Passed   = @($cases | Where-Object -FilterScript { $_.Result -eq 'Passed' }).Count
                Failed   = $failures.Count
                Skipped  = @($cases | Where-Object -FilterScript { $_.Result -notin 'Passed', 'Failed' }).Count
                Failures = @($failures | ForEach-Object -Process { [pscustomobject]@{ Name = $_.Name; Message = $_.Message } })
            }
            $summary.Add($entry)
            Write-LabProgress ('Run {0}: role {1} as {2}: {3} passed, {4} failed, {5} skipped, exit code {6}' -f
                $runId, $run.Role, $entry.Account, $entry.Passed, $entry.Failed, $entry.Skipped, $entry.ExitCode)
        }

        $state = Invoke-LabCommand -ComputerName $FileServer -ActivityName 'Read the security descriptors of the run' -ScriptBlock $stateScript -ArgumentList $helperScript, $fixture.ServerPath @labCommand
        $state | Select-Object -Property Path, Stored, Sacl | ConvertTo-Json -Depth 3 |
            Set-Content -LiteralPath (Join-Path -Path $resultFolder -ChildPath "$runId-State.json")
    }
}

$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $resultFolder -ChildPath 'Summary.json')
$report = New-Object -TypeName 'System.Collections.Generic.List[string]'
$report.Add('# NTFSSecurity live tests')
$report.Add('')
$report.Add(('Lab `{0}`: client `{1}`, file server `{2}`, domain controller `{3}`.' -f $LabName, $Client, $FileServer, $DomainController))
$report.Add('')
$report.Add('| Version | Edition | Role | Passed | Failed | Skipped |')
$report.Add('| --- | --- | --- | ---: | ---: | ---: |')
foreach ($entry in $summary) {
    $report.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $entry.Version, $entry.Edition, $entry.Role, $entry.Passed, $entry.Failed, $entry.Skipped))
}

foreach ($entry in $summary | Where-Object -FilterScript { $_.Failed -gt 0 -or -not $_.Passed }) {
    $report.Add('')
    $report.Add(('## {0}, {1}, {2}' -f $entry.Version, $entry.Edition, $entry.Role))
    $report.Add('')
    foreach ($failure in $entry.Failures) {
        $report.Add(('- {0}: {1}' -f $failure.Name, (($failure.Message -split '\r?\n')[0])))
    }

    if (-not $entry.Passed -and -not $entry.Failures) {
        $report.Add('- No test ran; see the log of the role.')
    }
}

Set-Content -LiteralPath (Join-Path -Path $resultFolder -ChildPath 'Summary.md') -Value $report
Write-LabProgress "DONE live tests; results in $resultFolder"
$summary
