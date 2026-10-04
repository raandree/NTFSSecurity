@{
    RootModule             = 'NTFSSecurity.psm1'

    ModuleVersion          = '5.0.0'

    GUID                   = 'cd303a6c-f405-4dcb-b1ce-fbc2c52264e9'

    Author                 = 'Raimund Andree'

    CompanyName            = 'Raimund Andree'

    Copyright              = '2018'

    Description            = 'Windows PowerShell Module for managing file and folder security on NTFS volumes'

    PowerShellVersion      = '5.1'

    CompatiblePSEditions   = 'Core', 'Desktop'

    DotNetFrameworkVersion = '4.5.2'

    ScriptsToProcess       = @('NTFSSecurity.Init.ps1')

    TypesToProcess         = @('NTFSSecurity.types.ps1xml')

    FormatsToProcess       = @()

    NestedModules          = @('NTFSSecurity.dll')

    AliasesToExport        = '*'

    CmdletsToExport        = 'Add-NTFSAccess',
    'Clear-NTFSAccess',
    'Get-NTFSAccess',
    'Get-NTFSEffectiveAccess',
    'Get-NTFSOrphanedAccess',
    'Get-NTFSSimpleAccess',
    'Remove-NTFSAccess',
    #----------------------------------------------
    'Add-NTFSAudit',
    'Clear-NTFSAudit',
    'Get-NTFSAudit',
    'Get-NTFSOrphanedAudit',
    'Remove-NTFSAudit',
    #----------------------------------------------
    'Disable-NTFSAccessInheritance',
    'Disable-NTFSAuditInheritance',
    'Enable-NTFSAccessInheritance',
    'Enable-NTFSAuditInheritance',
    'Get-NTFSInheritance',
    'Set-NTFSInheritance',
    #----------------------------------------------
    'Get-NTFSOwner',
    'Set-NTFSOwner',
    #----------------------------------------------
    'Get-NTFSSecurityDescriptor',
    'Set-NTFSSecurityDescriptor',
    #----------------------------------------------
    'Disable-Privileges',
    'Enable-Privileges',
    'Get-Privileges',
    #----------------------------------------------
    'Copy-Item2',
    'Get-ChildItem2',
    'Get-Item2',
    'Move-Item2',
    'Remove-Item2',
    #----------------------------------------------
    'Test-Path2',
    #----------------------------------------------
    'Get-NTFSHardLink',
    'New-NTFSHardLink',
    'New-NTFSSymbolicLink',
    #----------------------------------------------
    'Get-DiskSpace',
    'Get-FileHash2'

    FileList               = @(
        'NTFSSecurity.psd1'
        'NTFSSecurity.psm1'
        'NTFSSecurity.Init.ps1'
        'NTFSSecurity.dll'
        'Security2.dll'
        'PrivilegeControl.dll'
        'ProcessPrivileges.dll'
        'AlphaFS.dll'
        'NTFSSecurity.types.ps1xml'
        'NTFSSecurity.format.ps1xml'
        'en-US\NTFSSecurity.dll-Help.xml'
    )

    PrivateData            = @{ 
        EnablePrivileges          = $true
        GetInheritedFrom          = $true
        GetFileSystemModeProperty = $true
        ShowAccountSid            = $false
        IdentifyHardLinks         = $true

        PSData                    = @{
            Tags         = @('AccessControl', 'ACL', 'DirectorySecurity', 'FileSecurity', 'FileSystem', 'FileSystemSecurity', 'NTFS', 'Module', 'AccessRights')
            LicenseUri   = 'https://github.com/raandree/NTFSSecurity/blob/master/LICENSE'
            ProjectUri   = 'https://github.com/raandree/NTFSSecurity'
            ReleaseNotes = 'https://github.com/raandree/NTFSSecurity/blob/master/CHANGELOG.md'
            # Remove the prerelease label for the final release, see Docs/Contributing/05-Releasing.md
            Prerelease   = 'rc1'
        }
    }
}