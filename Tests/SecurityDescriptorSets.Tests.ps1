<#
    Tests the SecurityDescriptor parameter sets that no other test file covers, with the module built in
    NTFSSecurity\bin\Release on files in a sandbox folder. The cmdlets change a descriptor of Get-NTFSSecurityDescriptor
    in memory only, and the item changes when Set-NTFSSecurityDescriptor writes the descriptor; the cmdlets that read
    return what their Path parameter set returns. Tests of audit entries need the Security privilege and skip without
    it.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $holdsSecurityPrivilege = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'SecurityDescriptorSets'
    Push-Location -LiteralPath $sandbox
    $sidType = [System.Security.Principal.SecurityIdentifier]

    function Get-ExplicitAccessCount {
        param ([System.Security.AccessControl.FileSystemSecurity] $Acl)

        @($Acl.GetAccessRules($true, $false, $sidType)).Count
    }
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Cmdlets that change a security descriptor in memory' {
    It 'Clear-NTFSAccess should remove the explicit access entries of the descriptor' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearAccess'
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
        $sd = Get-NTFSSecurityDescriptor -Path $file

        Clear-NTFSAccess -SecurityDescriptor $sd -ErrorAction Stop

        Get-ExplicitAccessCount -Acl $sd.SecurityDescriptor | Should -Be 0
        Get-ExplicitAccessCount -Acl (Get-Acl -LiteralPath $file) | Should -Be 1
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        Get-ExplicitAccessCount -Acl (Get-Acl -LiteralPath $file) | Should -Be 0
    }

    # Like the Path parameter set, the cmdlet doesn't copy the inherited entries, so the DACL ends up empty.
    It 'Clear-NTFSAccess -DisableInheritance should leave the descriptor with an empty, protected DACL' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearAccessProtected'
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
        $daclBefore = (Get-Acl -LiteralPath $file).GetSecurityDescriptorSddlForm('Access')
        $sd = Get-NTFSSecurityDescriptor -Path $file

        Clear-NTFSAccess -SecurityDescriptor $sd -DisableInheritance -ErrorAction Stop

        $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeTrue
        @($sd.SecurityDescriptor.GetAccessRules($true, $true, $sidType)) | Should -BeNullOrEmpty
        (Get-Acl -LiteralPath $file).GetSecurityDescriptorSddlForm('Access') | Should -Be $daclBefore
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        $acl = Get-Acl -LiteralPath $file
        $acl.AreAccessRulesProtected | Should -BeTrue
        @($acl.GetAccessRules($true, $true, $sidType)) | Should -BeNullOrEmpty
    }

    It 'Disable-NTFSAccessInheritance should protect the DACL of the descriptor and keep the inherited entries' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'DisableAccess'
        $inheritedCount = @((Get-Acl -LiteralPath $file).GetAccessRules($false, $true, $sidType)).Count
        $inheritedCount | Should -BeGreaterThan 0
        $sd = Get-NTFSSecurityDescriptor -Path $file

        Disable-NTFSAccessInheritance -SecurityDescriptor $sd -ErrorAction Stop

        $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeTrue
        (Get-Acl -LiteralPath $file).AreAccessRulesProtected | Should -BeFalse
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        $acl = Get-Acl -LiteralPath $file
        $acl.AreAccessRulesProtected | Should -BeTrue
        Get-ExplicitAccessCount -Acl $acl | Should -Be $inheritedCount
    }

    It 'Enable-NTFSAccessInheritance should let the DACL of the descriptor inherit' {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'EnableAccess'
        Disable-NTFSAccessInheritance -Path $file -RemoveInheritedAccessRules
        $sd = Get-NTFSSecurityDescriptor -Path $file

        Enable-NTFSAccessInheritance -SecurityDescriptor $sd -ErrorAction Stop

        $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeFalse
        (Get-Acl -LiteralPath $file).AreAccessRulesProtected | Should -BeTrue
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        $acl = Get-Acl -LiteralPath $file
        $acl.AreAccessRulesProtected | Should -BeFalse
        @($acl.GetAccessRules($false, $true, $sidType)) | Should -Not -BeNullOrEmpty
    }

    It 'Clear-NTFSAudit should remove the explicit audit entries of the descriptor' -Skip:(-not $holdsSecurityPrivilege) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearAudit'
        Add-NTFSAudit -Path $file -Account 'S-1-1-0' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
        $sd = Get-NTFSSecurityDescriptor -Path $file

        Clear-NTFSAudit -SecurityDescriptor $sd -ErrorAction Stop

        @($sd.SecurityDescriptor.GetAuditRules($true, $false, $sidType)) | Should -BeNullOrEmpty
        @(Get-NTFSAudit -Path $file -ExcludeInherited) | Should -HaveCount 1
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        @(Get-NTFSAudit -Path $file -ExcludeInherited) | Should -BeNullOrEmpty
    }

    It 'Enable-NTFSAuditInheritance should let the SACL of the descriptor inherit' -Skip:(-not $holdsSecurityPrivilege) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'EnableAudit'
        Disable-NTFSAuditInheritance -Path $file
        $sd = Get-NTFSSecurityDescriptor -Path $file
        $sd.SecurityDescriptor.AreAuditRulesProtected | Should -BeTrue

        Enable-NTFSAuditInheritance -SecurityDescriptor $sd -ErrorAction Stop

        $sd.SecurityDescriptor.AreAuditRulesProtected | Should -BeFalse
        (Get-NTFSInheritance -Path $file).AuditInheritanceEnabled | Should -BeFalse
        Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop
        (Get-NTFSInheritance -Path $file).AuditInheritanceEnabled | Should -BeTrue
    }
}

Describe 'Cmdlets that read a security descriptor in memory' {
    BeforeAll {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'Read'
        Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData
    }

    It 'Get-NTFSAccess should return the entries that it returns for the path' {
        $expected = @(Get-NTFSAccess -Path $file | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.IsInherited })

        $result = @(Get-NTFSSecurityDescriptor -Path $file | Get-NTFSAccess -ErrorAction Stop)

        $result | Should -Not -BeNullOrEmpty
        ($result | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.IsInherited }) -join ';' | Should -Be ($expected -join ';')
        $result | ForEach-Object -Process { $_.FullName | Should -Be $file }
    }

    It 'Get-NTFSOwner should return the owner that it returns for the path' {
        $expected = (Get-NTFSOwner -Path $file).Owner.Sid

        $result = @(Get-NTFSSecurityDescriptor -Path $file | Get-NTFSOwner -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].Owner.Sid | Should -Be $expected
        $result[0].FullName | Should -Be $file
    }

    It 'Get-NTFSAudit should return the audit entries that it returns for the path' -Skip:(-not $holdsSecurityPrivilege) {
        Add-NTFSAudit -Path $file -Account 'S-1-1-0' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None
        $expected = @(Get-NTFSAudit -Path $file | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.AuditFlags })

        $result = @(Get-NTFSSecurityDescriptor -Path $file | Get-NTFSAudit -ErrorAction Stop)

        $result | Should -HaveCount 1
        ($result | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.AuditFlags }) -join ';' | Should -Be ($expected -join ';')
    }
}
