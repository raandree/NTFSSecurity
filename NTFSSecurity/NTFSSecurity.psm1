New-Alias -Name dir2 -Value Get-ChildItem2 -ErrorAction SilentlyContinue
New-Alias -Name gi2 -Value Get-Item2 -ErrorAction SilentlyContinue
New-Alias -Name rm2 -Value Remove-Item2  -ErrorAction SilentlyContinue
New-Alias -Name del2 -Value Remove-Item2 -ErrorAction SilentlyContinue

Export-ModuleMember -Alias * -Function * -Cmdlet *