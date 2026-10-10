<#
    Tests all permission scopes through the access and audit cmdlets, both parameter forms and both storage modes.
    Expected flags are the Windows ACE flags, independent of the module's scope converter.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canReadAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
    $scopes = @(
        @{ Name = 'ThisFolderOnly'; Inheritance = 'None'; Propagation = 'None' }
        @{ Name = 'ThisFolderSubfoldersAndFiles'; Inheritance = 'ContainerInherit, ObjectInherit'; Propagation = 'None' }
        @{ Name = 'ThisFolderAndSubfolders'; Inheritance = 'ContainerInherit'; Propagation = 'None' }
        @{ Name = 'ThisFolderAndFiles'; Inheritance = 'ObjectInherit'; Propagation = 'None' }
        @{ Name = 'SubfoldersAndFilesOnly'; Inheritance = 'ContainerInherit, ObjectInherit'; Propagation = 'InheritOnly' }
        @{ Name = 'SubfoldersOnly'; Inheritance = 'ContainerInherit'; Propagation = 'InheritOnly' }
        @{ Name = 'FilesOnly'; Inheritance = 'ObjectInherit'; Propagation = 'InheritOnly' }
        @{ Name = 'ThisFolderSubfoldersAndFilesOneLevel'; Inheritance = 'ContainerInherit, ObjectInherit'; Propagation = 'NoPropagateInherit' }
        @{ Name = 'ThisFolderAndSubfoldersOneLevel'; Inheritance = 'ContainerInherit'; Propagation = 'NoPropagateInherit' }
        @{ Name = 'ThisFolderAndFilesOneLevel'; Inheritance = 'ObjectInherit'; Propagation = 'NoPropagateInherit' }
        @{ Name = 'SubfoldersAndFilesOnlyOneLevel'; Inheritance = 'ContainerInherit, ObjectInherit'; Propagation = 'InheritOnly, NoPropagateInherit' }
        @{ Name = 'SubfoldersOnlyOneLevel'; Inheritance = 'ContainerInherit'; Propagation = 'InheritOnly, NoPropagateInherit' }
        @{ Name = 'FilesOnlyOneLevel'; Inheritance = 'ObjectInherit'; Propagation = 'InheritOnly, NoPropagateInherit' }
    )
    $activeTargets = @{
        ThisFolderOnly = @('Root')
        ThisFolderSubfoldersAndFiles = @('Root', 'File', 'Child', 'ChildFile', 'Grandchild', 'GrandchildFile')
        ThisFolderAndSubfolders = @('Root', 'Child', 'Grandchild')
        ThisFolderAndFiles = @('Root', 'File', 'ChildFile', 'GrandchildFile')
        SubfoldersAndFilesOnly = @('File', 'Child', 'ChildFile', 'Grandchild', 'GrandchildFile')
        SubfoldersOnly = @('Child', 'Grandchild')
        FilesOnly = @('File', 'ChildFile', 'GrandchildFile')
        ThisFolderSubfoldersAndFilesOneLevel = @('Root', 'File', 'Child')
        ThisFolderAndSubfoldersOneLevel = @('Root', 'Child')
        ThisFolderAndFilesOneLevel = @('Root', 'File')
        SubfoldersAndFilesOnlyOneLevel = @('File', 'Child')
        SubfoldersOnlyOneLevel = @('Child')
        FilesOnlyOneLevel = @('File')
    }
    $propagationCases = @($scopes | ForEach-Object { @{ Name = $_.Name; ActiveTargets = $activeTargets[$_.Name] } })
    $scopeNames = @($scopes.Name)
    $scopeCases = @(foreach ($scope in $scopes) {
        foreach ($source in 'Path', 'SecurityDescriptor') {
            foreach ($form in 'AppliesTo', 'Flags') {
                @{ Name = $scope.Name; Inheritance = $scope.Inheritance; Propagation = $scope.Propagation; Source = $source; Form = $form }
            }
        }
    })
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1') -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'PermissionScopes'
    Push-Location -LiteralPath $sandbox
    $account = 'S-1-5-21-1-2-3-4801'
    $keeper = 'S-1-5-21-1-2-3-4802'
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Permission scope inventory' {
    It 'Should cover every named -AppliesTo value' -ForEach @(@{ ScopeNames = $scopeNames }) {
        (@([Enum]::GetNames([Security2.ApplyTo])) | Sort-Object) -join ',' |
            Should -Be (($scopeNames | Sort-Object) -join ',')
    }
}

Describe 'Access rule scopes' {
    It 'Should add and remove <Name> using <Form> on <Source>, preserving the other account' -ForEach $scopeCases {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AccessScope' -Directory
        $before = (Get-Acl -LiteralPath $folder).GetSecurityDescriptorSddlForm('Access')
        $location = if ($Source -eq 'Path') { @{ Path = $folder } } else { @{ SecurityDescriptor = Get-NTFSSecurityDescriptor -Path $folder -ErrorAction Stop } }
        $flags = @{ InheritanceFlags = $Inheritance; PropagationFlags = $Propagation }
        $addScope = if ($Form -eq 'AppliesTo') { @{ AppliesTo = $Name } } else { $flags }
        $removeScope = if ($Form -eq 'AppliesTo') { $flags } else { @{ AppliesTo = $Name } }
        Add-NTFSAccess @location -Account $keeper -AccessRights Delete -AppliesTo ThisFolderOnly -ErrorAction Stop

        $added = @(Add-NTFSAccess @location @addScope -Account $account -AccessRights ReadData -PassThru -ErrorAction Stop |
                Where-Object -FilterScript { $_.Account.Sid -eq $account })

        $added | Should -HaveCount 1
        $added[0] | Should -BeOfType [Security2.FileSystemAccessRule2]
        $added[0].InheritanceFlags | Should -Be ([Security.AccessControl.InheritanceFlags] $Inheritance)
        $added[0].PropagationFlags | Should -Be ([Security.AccessControl.PropagationFlags] $Propagation)
        $added[0].AccessRights.HasFlag([Security2.FileSystemRights2]::ReadData) | Should -BeTrue
        [Security2.FileSystemSecurity2]::ConvertToApplyTo($added[0].InheritanceFlags, $added[0].PropagationFlags).ToString() | Should -Be $Name
        if ($Source -eq 'SecurityDescriptor') {
            (Get-Acl -LiteralPath $folder).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $before
        }

        $remaining = @(Remove-NTFSAccess @location @removeScope -Account $account -AccessRights ReadData -RemoveSpecific -PassThru -ErrorAction Stop)

        @($remaining | Where-Object -FilterScript { $_.Account.Sid -eq $account }) | Should -BeNullOrEmpty
        @($remaining | Where-Object -FilterScript { $_.Account.Sid -eq $keeper }) | Should -HaveCount 1
        @(Get-NTFSAccess @location -Account $account -ErrorAction Stop) | Should -BeNullOrEmpty
    }
}

Describe 'Access scopes on descendants' {
    It 'Should apply <Name> only to its intended descendants, including the OneLevel boundary' -ForEach $propagationCases {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Propagation' -Directory
        Add-NTFSAccess -Path $folder -Account $account -AccessRights ReadData -AppliesTo $Name -ErrorAction Stop
        $paths = [ordered]@{
            Root = $folder
            File = Join-Path -Path $folder -ChildPath 'File.txt'
            Child = Join-Path -Path $folder -ChildPath 'Child'
            ChildFile = Join-Path -Path $folder -ChildPath 'Child\File.txt'
            Grandchild = Join-Path -Path $folder -ChildPath 'Child\Grandchild'
            GrandchildFile = Join-Path -Path $folder -ChildPath 'Child\Grandchild\File.txt'
        }
        Assert-TestSandboxPath -Sandbox $sandbox -Path @($paths.Values)
        New-Item -ItemType Directory -Path $paths.Grandchild -Force | Out-Null
        foreach ($key in 'File', 'ChildFile', 'GrandchildFile') {
            Set-Content -LiteralPath $paths[$key] -Value $key
        }

        $actual = @(foreach ($key in $paths.Keys) {
            $active = @(Get-NTFSAccess -Path $paths[$key] -Account $account -ErrorAction Stop | Where-Object -FilterScript {
                    -not $_.PropagationFlags.HasFlag([Security.AccessControl.PropagationFlags]::InheritOnly) -and
                    $_.AccessRights.HasFlag([Security2.FileSystemRights2]::ReadData)
                })
            if ($active.Count -gt 0) { $key }
        })

        ($actual | Sort-Object) -join ',' | Should -Be (($ActiveTargets | Sort-Object) -join ',')
    }
}
Describe 'Audit rule scopes' -Skip:(-not $canReadAudit) {
    It 'Should add and remove <Name> using <Form> on <Source>, preserving the other account' -ForEach $scopeCases {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditScope' -Directory
        $before = (Get-Acl -LiteralPath $folder -Audit).GetSecurityDescriptorSddlForm('Audit')
        $location = if ($Source -eq 'Path') { @{ Path = $folder } } else { @{ SecurityDescriptor = Get-NTFSSecurityDescriptor -Path $folder -ErrorAction Stop } }
        $flags = @{ InheritanceFlags = $Inheritance; PropagationFlags = $Propagation }
        $addScope = if ($Form -eq 'AppliesTo') { @{ AppliesTo = $Name } } else { $flags }
        $removeScope = if ($Form -eq 'AppliesTo') { $flags } else { @{ AppliesTo = $Name } }
        Add-NTFSAudit @location -Account $keeper -AccessRights Delete -AuditFlags Failure -AppliesTo ThisFolderOnly -ErrorAction Stop

        $added = @(Add-NTFSAudit @location @addScope -Account $account -AccessRights ReadData -AuditFlags 'Success, Failure' -PassThru -ErrorAction Stop |
                Where-Object -FilterScript { $_.Account.Sid -eq $account })

        $added | Should -HaveCount 1
        $added[0] | Should -BeOfType [Security2.FileSystemAuditRule2]
        $added[0].InheritanceFlags | Should -Be ([Security.AccessControl.InheritanceFlags] $Inheritance)
        $added[0].PropagationFlags | Should -Be ([Security.AccessControl.PropagationFlags] $Propagation)
        $added[0].AuditFlags | Should -Be ([Security.AccessControl.AuditFlags] 'Success, Failure')
        [Security2.FileSystemSecurity2]::ConvertToApplyTo($added[0].InheritanceFlags, $added[0].PropagationFlags).ToString() | Should -Be $Name
        if ($Source -eq 'SecurityDescriptor') {
            (Get-Acl -LiteralPath $folder -Audit).GetSecurityDescriptorSddlForm('Audit') | Should -BeExactly $before
        }

        $remaining = @(Remove-NTFSAudit @location @removeScope -Account $account -AccessRights ReadData -AuditFlags 'Success, Failure' -RemoveSpecific -PassThru -ErrorAction Stop)

        @($remaining | Where-Object -FilterScript { $_.Account.Sid -eq $account }) | Should -BeNullOrEmpty
        @($remaining | Where-Object -FilterScript { $_.Account.Sid -eq $keeper }) | Should -HaveCount 1
        @(Get-NTFSAudit @location -Account $account -ErrorAction Stop) | Should -BeNullOrEmpty
    }
}
