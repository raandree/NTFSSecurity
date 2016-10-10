@{
	ModuleToProcess = 'NTFSSecurity.psm1'

	ModuleVersion = '4.2.3'

	GUID = 'cd303a6c-f405-4dcb-b1ce-fbc2c52264e9'

	Author = 'Raimund Andree'

	CompanyName = 'Raimund Andree'

	Copyright = '2015'

	Description = 'Windows PowerShell Module for managing file and folder security on NTFS volumes'

	PowerShellVersion = '2.0'

	DotNetFrameworkVersion = '3.5'

	ScriptsToProcess = @('NTFSSecurity.Init.ps1')

	TypesToProcess = @('NTFSSecurity.types.ps1xml')

	FormatsToProcess = @()

	NestedModules = @('NTFSSecurity.dll')

	AliasesToExport = '*'

	CmdletsToExport = 'Add-NTFSAccess',
		'Clear-NTFSAccess',
		'Disable-NTFSAccessInheritance',
		'Enable-NTFSAccessInheritance',
		'Get-NTFSAccess',
		'Get-NTFSEffectiveAccess',
		'Get-NTFSOrphanedAccess',
		'Get-NTFSSimpleAccess',
		'Remove-NTFSAccess',
		'Show-NTFSSimpleAccess',
	#----------------------------------------------
		'Add-NTFSAudit',
		'Clear-NTFSAudit',
		'Disable-NTFSAuditInheritance',
		'Enable-NTFSAuditInheritance',
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

	ModuleList = @('NTFSSecurity.dll')

	FileList = @('NTFSSecurity.dll', 'NTFSSecurity.types.ps1xml', 'NTFSSecurity.format.ps1xml', 'NTFSSecurity.Init.ps1', 'NTFSSecurity.psm1')

	PrivateData = @{ 
		EnablePrivileges = $true
		GetInheritedFrom = $true
		GetFileSystemModeProperty = $true
		ShowAccountSid = $false

		PSData = @{
			Tags = @('AccessControl', 'ACL', 'DirectorySecurity', 'FileSecurity', 'FileSystem', 'FileSystemSecurity', 'NTFS', 'Module', 'AccessRights')
            LicenseUri = 'https://ntfssecurity.codeplex.com/license'
            ProjectUri = 'https://ntfssecurity.codeplex.com'
		}
	}
}