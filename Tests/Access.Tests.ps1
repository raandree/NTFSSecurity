<#
    Tests the access cmdlets of the module built in NTFSSecurity\bin\Release on files in a sandbox folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'Access'
    Push-Location -LiteralPath $sandbox
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NTFSAccess' {
    Context 'When a path fails after a readable path' {
        # Before 5.0.0, the cmdlet wrote the entries of the previous item again for the failing path.
        It 'Should return the entries of the first item once' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'Readable' -Directory
            $denied = New-TestSandboxItem -Sandbox $sandbox -Name 'Denied'
            Block-TestReadPermission -Sandbox $sandbox -Path $denied
            $expected = @(Get-NTFSAccess -Path $folder).Count

            $entries = @(Get-NTFSAccess -Path $folder, $denied -ErrorAction SilentlyContinue)

            @($entries | Where-Object -Property FullName -EQ -Value $folder) | Should -HaveCount $expected
        }
    }
}

Describe 'Security descriptor parameter sets' {
    BeforeAll {
        $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ParameterSets' -Directory
    }

    # Before 5.0.0, PowerShell could not choose between the SDSimple and SDComplex parameter sets.
    It '<_> should accept -SecurityDescriptor without -AppliesTo or the flag parameters' -ForEach @(
        'Add-NTFSAccess', 'Remove-NTFSAccess', 'Add-NTFSAudit', 'Remove-NTFSAudit'
    ) {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        { & $_ -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Add-NTFSAccess should apply the entry to the folder, its subfolders, and files by default' {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData

        $rule = $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
        $rule.InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags] 'ContainerInherit, ObjectInherit')
        $rule.PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
    }

    It 'Add-NTFSAccess should still take -AppliesTo for a security descriptor' {
        $sd = Get-NTFSSecurityDescriptor -Path $folder

        Add-NTFSAccess -SecurityDescriptor $sd -Account 'Everyone' -AccessRights ReadData -AppliesTo ThisFolderOnly

        $rule = $sd.SecurityDescriptor.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }
        $rule.InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::None)
    }
}
