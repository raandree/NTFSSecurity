<#
#Access cmdlets
New-Alias -Name Get-Ace -Value Get-NTFSAccess -ErrorAction SilentlyContinue
New-Alias -Name Get-Access -Value Get-NTFSAccess -ErrorAction SilentlyContinue

New-Alias -Name Get-EffectiveAccess -Value Get-NTFSEffectiveAccess -ErrorAction SilentlyContinue

New-Alias -Name Add-Ace -Value Add-NTFSAccess -ErrorAction SilentlyContinue
New-Alias -Name Add-Access -Value Add-NTFSAccess -ErrorAction SilentlyContinue

New-Alias -Name Remove-Ace -Value Remove-NTFSAccess -ErrorAction SilentlyContinue
New-Alias -Name Remove-Access -Value Remove-NTFSAccess -ErrorAction SilentlyContinue

New-Alias -Name Get-OrphanedAccess -Value Get-NTFSOrphanedAccess -ErrorAction SilentlyContinue
New-Alias -Name Get-OrphanedAce -Value Get-NTFSOrphanedAccess -ErrorAction SilentlyContinue

New-Alias -Name Get-AccessInheritance -Value Get-NTFSAccessInheritance -ErrorAction SilentlyContinue

New-Alias -Name Enable-Inheritance -Value Enable-NTFSAccessInheritance -ErrorAction SilentlyContinue
New-Alias -Name Enable-AccessInheritance -Value Enable-NTFSAccessInheritance -ErrorAction SilentlyContinue

New-Alias -Name Disable-Inheritance -Value Disable-NTFSAccessInheritance -ErrorAction SilentlyContinue
New-Alias -Name Disable-AccessInheritance -Value Disable-NTFSAccessInheritance -ErrorAction SilentlyContinue

#Audit cmdlets
New-Alias -Name Get-Audit -Value Get-NTFSAudit -ErrorAction SilentlyContinue

New-Alias -Name Add-Audit -Value Add-NTFSAudit -ErrorAction SilentlyContinue

New-Alias -Name Remove-Audit -Value Remove-NTFSAudit -ErrorAction SilentlyContinue

New-Alias -Name Get-OrphanedAudit -Value Get-NTFSOrphanedAudit -ErrorAction SilentlyContinue

New-Alias -Name Get-AuditInheritance -Value Get-NTFSAuditInheritance -ErrorAction SilentlyContinue

New-Alias -Name Enable-AuditInheritance -Value Enable-NTFSAuditInheritance -ErrorAction SilentlyContinue

New-Alias -Name Disable-AuditInheritance -Value Disable-NTFSAuditInheritance -ErrorAction SilentlyContinue

#Owner cmdlets
New-Alias -Name Get-Owner -Value Get-NTFSOwner -ErrorAction SilentlyContinue

New-Alias -Name Set-Owner -Value Set-NTFSOwner -ErrorAction SilentlyContinue
#>

#Item cmdlets
New-Alias -Name dir2 -Value Get-ChildItem2 -ErrorAction SilentlyContinue
New-Alias -Name gi2 -Value Get-Item2 -ErrorAction SilentlyContinue
New-Alias -Name rm2 -Value Remove-Item2  -ErrorAction SilentlyContinue
New-Alias -Name del2 -Value Remove-Item2 -ErrorAction SilentlyContinue

Export-ModuleMember -Alias * -Function * -Cmdlet *