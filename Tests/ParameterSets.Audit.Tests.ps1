<#
    Closes the parameter-set gaps that the judged test matrix (judged-audit.csv / judged-audit-notes.md) found for
    the audit cmdlets: pipeline binding by value and by property name, continuation past a failing path or
    descriptor, and state or output assertions beyond -PassThru, with the module built in NTFSSecurity\bin\Release
    on files in a sandbox folder. Reading and changing audit entries needs the Security privilege; tests that need
    it skip without it and run in CI, whose runners are elevated, like Audit.Tests.ps1. The -SecurityDescriptor sets
    of Add-NTFSAudit and Remove-NTFSAudit have no per-item handler around the change itself (an open maintainer
    item), so no test here pins what happens when that change throws for one of several descriptors; the only
    failure the -SecurityDescriptor scenarios below exercise is the already-handled one of a descriptor that was
    read without its audit section.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $canReadAudit = Test-PrivilegeHeld -Name 'SeSecurityPrivilege'
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'ParameterSetsAudit'
    Push-Location -LiteralPath $sandbox

    $sidType = [System.Security.Principal.SecurityIdentifier]
    $probe = 'S-1-1-0'
    $keeper = 'S-1-5-32-545'
    $entry = @{ Account = $probe; AccessRights = 'ReadData' }

    function Get-TestAuditSddl {
        param ([Parameter(Mandatory)] [string] $Path)
        (Get-Acl -LiteralPath $Path -Audit).GetSecurityDescriptorSddlForm('Audit')
    }

    function Get-TestDaclSddl {
        param ([Parameter(Mandatory)] [string] $Path)
        (Get-Acl -LiteralPath $Path).Sddl
    }

    function Get-TestAuditAcl {
        # The SACL read alone, through .NET. Get-Acl -Audit reads it together with the other sections, and on a domain
        # member that reports the SACL of an item without audit entries as protected from inheritance, which is not its
        # state (see Security2\FileSystem\FileSystemSecurity2.cs). Matches the helper of ParameterSets.Inheritance.Tests.ps1.
        param ([Parameter(Mandatory)] [string] $Path)

        $sections = [System.Security.AccessControl.AccessControlSections]::Audit
        $info = if (Test-Path -LiteralPath $Path -PathType Container) {
            New-Object -TypeName 'System.IO.DirectoryInfo' -ArgumentList $Path
        }
        else {
            New-Object -TypeName 'System.IO.FileInfo' -ArgumentList $Path
        }
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            $info.GetAccessControl($sections)
        }
        else {
            [System.IO.FileSystemAclExtensions]::GetAccessControl($info, $sections)
        }
    }

    function Get-TestAccessOnlyDescriptor {
        # A descriptor read with the Access section only, like one that Get-NTFSSecurityDescriptor returns without
        # the Security privilege: the audit cmdlets have nothing to read or change and report it the same way.
        param ([Parameter(Mandatory)] [string] $Path)
        New-Object -TypeName 'Security2.FileSystemSecurity2' -ArgumentList (
            (Get-Item2 -Path $Path), [System.Security.AccessControl.AccessControlSections]::Access
        )
    }

    function Get-TestAccountAuditRule {
        param (
            [Parameter(Mandatory)] [System.Security.AccessControl.FileSystemSecurity] $Acl,
            [Parameter(Mandatory)] [string] $Account
        )
        @($Acl.GetAuditRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq $Account })
    }

    function Get-TestAuditScope {
        # The scopes of the explicit audit entries of the probe account, each as 'inheritance flags/propagation flags', joined by ';'
        param ([Parameter(Mandatory)] [System.Security.AccessControl.FileSystemSecurity] $Acl)
        @(Get-TestAccountAuditRule -Acl $Acl -Account $probe |
                ForEach-Object -Process { '{0}/{1}' -f $_.InheritanceFlags, $_.PropagationFlags }) -join ';'
    }
}

AfterAll {
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Audit cmdlets with a security descriptor that has no audit section' {
    # TestAuditSection (#109) handles this the same way for every cmdlet that takes -SecurityDescriptor: Audit.Tests.ps1
    # line 425 already asserts the ErrorId for Add-NTFSAudit, Remove-NTFSAudit, and Clear-NTFSAudit; this data set adds
    # the category and the target, which must be the descriptor itself, not its path, and also covers Get-NTFSAudit and
    # Get-NTFSOrphanedAudit and the Simple parameter sets of Add and Remove. None of this needs the Security privilege:
    # the descriptor already carries no audit section before the cmdlet runs.
    It '<Command> should write a ReadSecurityError with category InvalidData and the descriptor as target for the <Set> set, and change nothing' -ForEach @(
        @{ Command = 'Add-NTFSAudit'; Set = 'SDSimple'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData'; AppliesTo = 'ThisFolderOnly'; PassThru = $true } }
        @{ Command = 'Add-NTFSAudit'; Set = 'SDComplex'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData'; PassThru = $true } }
        @{ Command = 'Remove-NTFSAudit'; Set = 'SDSimple'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData'; AppliesTo = 'ThisFolderOnly'; PassThru = $true } }
        @{ Command = 'Remove-NTFSAudit'; Set = 'SDComplex'; Parameters = @{ Account = 'S-1-1-0'; AccessRights = 'ReadData'; PassThru = $true } }
        @{ Command = 'Clear-NTFSAudit'; Set = 'SD'; Parameters = @{} }
        @{ Command = 'Get-NTFSAudit'; Set = 'SD'; Parameters = @{} }
        @{ Command = 'Get-NTFSOrphanedAudit'; Set = 'SD'; Parameters = @{} }
    ) {
        $file = New-TestSandboxItem -Sandbox $sandbox -Name 'NoAuditSection'
        $sd = Get-TestAccessOnlyDescriptor -Path $file

        $result = @(& $Command -SecurityDescriptor $sd @Parameters -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

        $result | Should -BeNullOrEmpty
        $auditErrors | Should -HaveCount 1
        $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
        $auditErrors[0].CategoryInfo.Category | Should -Be 'InvalidData'
        $auditErrors[0].TargetObject | Should -Be $sd
        $sd.SecurityDescriptor.GetSecurityDescriptorSddlForm('Audit') | Should -BeNullOrEmpty
    }
}

Describe 'Add-NTFSAudit' {
    Context 'Binding -Path from the pipeline by property name' {
        # The PathSimple row pipes AppliesTo, which selects the set; the PathSimpleNamed row names -AppliesTo instead, and the
        # piped object brings only the path.
        It 'Should add the audit entry for the piped <Set> object that exists, write a ReadFileError for the one that does not, and leave the DACL unchanged' -ForEach @(
            @{ Set = 'PathComplex'; ExtraProperties = @{ InheritanceFlags = 'None'; PropagationFlags = 'None' }; Named = @{} }
            @{ Set = 'PathSimple'; ExtraProperties = @{ AppliesTo = 'ThisFolderOnly' }; Named = @{} }
            @{ Set = 'PathSimpleNamed'; ExtraProperties = @{}; Named = @{ AppliesTo = 'ThisFolderOnly' } }
        ) -Skip:(-not $canReadAudit) {
            $missing = Join-Path -Path $sandbox -ChildPath ('AddPipeMissing-{0}' -f [guid]::NewGuid().ToString('N'))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $good = New-TestSandboxItem -Sandbox $sandbox -Name "AddPipeGood$Set" -Directory
            $daclBefore = Get-TestDaclSddl -Path $good

            $items = @(
                [pscustomobject] (@{ FullName = $missing; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
                [pscustomobject] (@{ FullName = $good; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
            )

            $result = @($items | Add-NTFSAudit @Named -PassThru -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $auditErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $auditErrors[0].TargetObject | Should -Be $missing
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $good
            # The default scope of a new entry is ContainerInherit and ObjectInherit; None shows that the scope was honored
            $rule = Get-TestAccountAuditRule -Acl (Get-Acl -LiteralPath $good -Audit) -Account $probe
            $rule | Should -HaveCount 1
            $rule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::None)
            Get-TestDaclSddl -Path $good | Should -BeExactly $daclBefore
        }
    }

    Context 'Binding -Account and -AuditFlags from the pipeline by property name' {
        # judged-audit.csv (Add-NTFSAudit PathComplex): no existing call binds -AuditFlags by property name, and
        # none adds for several accounts in one call; this piped object binds both at once.
        It 'Should add one audit entry for each account that the piped object names, with the AuditFlags it also names' -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPipedAuditSeveralAccounts' -Directory

            [pscustomobject]@{ FullName = $folder; Account = @($probe, $keeper); AccessRights = 'ReadData'; AuditFlags = 'Failure'; InheritanceFlags = 'None'; PropagationFlags = 'None' } | Add-NTFSAudit -ErrorAction Stop

            $acl = Get-Acl -LiteralPath $folder -Audit
            foreach ($account in $probe, $keeper) {
                $rule = Get-TestAccountAuditRule -Acl $acl -Account $account
                $rule | Should -HaveCount 1
                $rule[0].AuditFlags | Should -Be ([System.Security.AccessControl.AuditFlags]::Failure)
                $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeTrue
            }
        }
    }

    Context 'Binding -SecurityDescriptor from the pipeline by property name' {
        It 'Should add the audit entry for the piped <Set> object that has an audit section, write a ReadSecurityError for the one that does not, and leave the item on disk unchanged until Set-NTFSSecurityDescriptor writes it' -ForEach @(
            @{ Set = 'SDSimple'; ExtraProperties = @{ AppliesTo = 'ThisFolderOnly' } }
            @{ Set = 'SDComplex'; ExtraProperties = @{ InheritanceFlags = 'None'; PropagationFlags = 'None' } }
        ) -Skip:(-not $canReadAudit) {
            $badFile = New-TestSandboxItem -Sandbox $sandbox -Name "AddPipeSDBad$Set"
            $sdBad = Get-TestAccessOnlyDescriptor -Path $badFile
            # A folder, so that the scope of the entry is observable; the piped AppliesTo property binds SDSimple, as it binds
            # PathSimple for a path
            $goodFile = New-TestSandboxItem -Sandbox $sandbox -Name "AddPipeSDGood$Set" -Directory
            $auditBefore = Get-TestAuditSddl -Path $goodFile
            $daclBefore = Get-TestDaclSddl -Path $goodFile
            $sdGood = Get-NTFSSecurityDescriptor -Path $goodFile -ErrorAction Stop

            $items = @(
                [pscustomobject] (@{ SecurityDescriptor = $sdBad; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
                [pscustomobject] (@{ SecurityDescriptor = $sdGood; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
            )

            $result = @($items | Add-NTFSAudit -PassThru -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $auditErrors[0].TargetObject | Should -Be $sdBad
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $goodFile
            $rule = Get-TestAccountAuditRule -Acl $sdGood.SecurityDescriptor -Account $probe
            $rule | Should -HaveCount 1
            $rule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::None)
            Get-TestAuditSddl -Path $goodFile | Should -BeExactly $auditBefore

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sdGood -ErrorAction Stop

            (Get-TestAccountAuditRule -Acl (Get-TestAuditAcl -Path $goodFile) -Account $probe) | Should -HaveCount 1
            Get-TestAuditSddl -Path $goodFile | Should -Not -BeExactly $auditBefore
            Get-TestDaclSddl -Path $goodFile | Should -BeExactly $daclBefore
        }
    }

    # The property AppliesTo selects PathSimple, InheritanceFlags and PropagationFlags select PathComplex, and an object that
    # has none of them gets the default scope, as for Add-NTFSAccess (ParameterSets.Access.Tests.ps1).
    Context 'Choosing the parameter set of an object bound through the pipeline by property name' {
        It 'Should give the audit entry for the piped object that has <Shape> the scope <Scope>' -ForEach @(
            @{ Name = 'AddPipedAuditThisFolderOnly'; Shape = 'AppliesTo ThisFolderOnly'; Extra = @{ AppliesTo = 'ThisFolderOnly' }; Scope = 'None/None' }
            @{ Name = 'AddPipedAuditSubfolders'; Shape = 'AppliesTo ThisFolderAndSubfolders'; Extra = @{ AppliesTo = 'ThisFolderAndSubfolders' }; Scope = 'ContainerInherit/None' }
            @{ Name = 'AddPipedAuditFlags'; Shape = 'InheritanceFlags and PropagationFlags'; Extra = @{ InheritanceFlags = 'ContainerInherit'; PropagationFlags = 'InheritOnly' }; Scope = 'ContainerInherit/InheritOnly' }
            @{ Name = 'AddPipedAuditNoScope'; Shape = 'no scope'; Extra = @{}; Scope = 'ContainerInherit, ObjectInherit/None' }
        ) -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name $Name -Directory

            [pscustomobject] (@{ FullName = $folder; Account = $probe; AccessRights = 'ReadData' } + $Extra) | Add-NTFSAudit -ErrorAction Stop

            Get-TestAuditScope -Acl (Get-Acl -LiteralPath $folder -Audit) | Should -BeExactly $Scope
        }

        It 'Should reject a piped object that has both AppliesTo and InheritanceFlags with an AmbiguousParameterSet error' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPipedAuditBoth' -Directory
            $object = [pscustomobject]@{ FullName = $folder; Account = $probe; AccessRights = 'ReadData'; AppliesTo = 'ThisFolderOnly'; InheritanceFlags = 'None' }

            { $object | Add-NTFSAudit -ErrorAction Stop } | Should -Throw -ErrorId 'AmbiguousParameterSet*'
        }
    }

    # PowerShell resets only the parameters that the previous object bound from the pipeline. The scope that the cmdlet
    # derives from AppliesTo must therefore not stay in the fields behind InheritanceFlags and PropagationFlags: the next
    # object that has no scope, or only one flag, would get it (ParameterSets.Access.Tests.ps1 has the same rows).
    Context 'Objects with different scopes in one pipeline' {
        It 'Should give each piped path object only its own scope: AppliesTo, none, AppliesTo, one flag, none' -Skip:(-not $canReadAudit) {
            $folders = @('AddMixedAuditThisFolderOnly', 'AddMixedAuditNoScope', 'AddMixedAuditInheritOnly', 'AddMixedAuditOneFlag', 'AddMixedAuditNoScopeAgain' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })

            @(
                [pscustomobject] ($entry + @{ FullName = $folders[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ FullName = $folders[1] })
                [pscustomobject] ($entry + @{ FullName = $folders[2]; AppliesTo = 'SubfoldersAndFilesOnly' })
                [pscustomobject] ($entry + @{ FullName = $folders[3]; InheritanceFlags = 'ContainerInherit' })
                [pscustomobject] ($entry + @{ FullName = $folders[4] })
            ) | Add-NTFSAudit -ErrorAction Stop

            $scopes = $folders | ForEach-Object -Process { Get-TestAuditScope -Acl (Get-Acl -LiteralPath $_ -Audit) }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit, ObjectInherit/None|ContainerInherit, ObjectInherit/InheritOnly|ContainerInherit/None|ContainerInherit, ObjectInherit/None'
        }

        It 'Should give each row of a CSV file that Import-Csv reads and that has an AppliesTo column its own scope' -Skip:(-not $canReadAudit) {
            $folders = @('AddCsvAuditThisFolderOnly', 'AddCsvAuditSubfolders', 'AddCsvAuditInheritOnly' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $csv = Join-Path -Path $sandbox -ChildPath 'AddCsvAuditScopes.csv'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $csv
            Set-Content -LiteralPath $csv -Value @(
                'FullName,Account,AccessRights,AppliesTo'
                ('"{0}",{1},ReadData,ThisFolderOnly' -f $folders[0], $probe)
                ('"{0}",{1},ReadData,ThisFolderAndSubfolders' -f $folders[1], $probe)
                ('"{0}",{1},ReadData,SubfoldersAndFilesOnly' -f $folders[2], $probe)
            )

            Import-Csv -LiteralPath $csv | Add-NTFSAudit -ErrorAction Stop

            $scopes = $folders | ForEach-Object -Process { Get-TestAuditScope -Acl (Get-Acl -LiteralPath $_ -Audit) }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit/None|ContainerInherit, ObjectInherit/InheritOnly'
        }

        # A blank cell that Import-Csv reads is an empty string, not $null: the row gets the default scope (ParameterSets.Access.Tests.ps1
        # has the same rows and says why).
        It 'Should give the row of a CSV file whose AppliesTo cell is blank the default scope, and the other rows their own' -Skip:(-not $canReadAudit) {
            $folders = @('AddCsvAuditBlankFirst', 'AddCsvAuditBlankCell', 'AddCsvAuditBlankLast' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $csv = Join-Path -Path $sandbox -ChildPath 'AddCsvAuditBlank.csv'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $csv
            Set-Content -LiteralPath $csv -Value @(
                'FullName,Account,AccessRights,AppliesTo'
                ('"{0}",{1},ReadData,ThisFolderOnly' -f $folders[0], $probe)
                ('"{0}",{1},ReadData,' -f $folders[1], $probe)
                ('"{0}",{1},ReadData,SubfoldersAndFilesOnly' -f $folders[2], $probe)
            )

            Import-Csv -LiteralPath $csv | Add-NTFSAudit -ErrorAction Stop

            $scopes = $folders | ForEach-Object -Process { Get-TestAuditScope -Acl (Get-Acl -LiteralPath $_ -Audit) }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit, ObjectInherit/None|ContainerInherit, ObjectInherit/InheritOnly'
        }

        # $null cannot be bound at all: the object fails, loudly, and the cmdlet goes on with the next one.
        It 'Should report a binding error for the piped object whose AppliesTo is $null, leave its folder alone, and still process the other objects' -Skip:(-not $canReadAudit) {
            $folders = @('AddNullAuditFirst', 'AddNullAuditMiddle', 'AddNullAuditLast' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })

            @(
                [pscustomobject] ($entry + @{ FullName = $folders[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ FullName = $folders[1]; AppliesTo = $null })
                [pscustomobject] ($entry + @{ FullName = $folders[2]; AppliesTo = 'SubfoldersAndFilesOnly' })
            ) | Add-NTFSAudit -ErrorVariable auditErrors -ErrorAction SilentlyContinue

            @($auditErrors) | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ParameterArgumentValidationErrorNullNotAllowed,*'
            $scopes = $folders | ForEach-Object -Process { Get-TestAuditScope -Acl (Get-Acl -LiteralPath $_ -Audit) }
            $scopes -join '|' | Should -BeExactly 'None/None||ContainerInherit, ObjectInherit/InheritOnly'
        }

        It 'Should give each piped descriptor object only its own scope: AppliesTo, then none' -Skip:(-not $canReadAudit) {
            $folders = @('AddMixedAuditSDThisFolderOnly', 'AddMixedAuditSDNoScope' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $folders -ErrorAction Stop)

            @(
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[1] })
            ) | Add-NTFSAudit -ErrorAction Stop

            $scopes = $descriptors | ForEach-Object -Process { Get-TestAuditScope -Acl $_.SecurityDescriptor }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit, ObjectInherit/None'
        }
    }

    Context 'Conflicting parameters' {
        It 'Should reject -AppliesTo combined with -InheritanceFlags with an AmbiguousParameterSet error' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddAmbiguous'

            { Add-NTFSAudit -Path $file -Account $probe -AccessRights ReadData -AppliesTo ThisFolderOnly -InheritanceFlags None -ErrorAction Stop } |
                Should -Throw -ErrorId 'AmbiguousParameterSet,NTFSSecurity.AddAudit'
        }
    }

    Context 'Direct call of -SecurityDescriptor with -AppliesTo' {
        # Add-NTFSAudit SDSimple (judged-audit.csv): every existing call binds it only through a splat
        # (PermissionScopes.Tests.ps1) or through position (Audit.Tests.ps1); this one names the set's parameters
        # directly.
        It 'Should add the entry to the descriptor when -SecurityDescriptor, -Account, -AccessRights, and -AppliesTo are all named directly' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddDirectSDSimple'
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            $result = @(Add-NTFSAudit -SecurityDescriptor $sd -Account $probe -AccessRights ReadData -AppliesTo ThisFolderOnly -PassThru -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType [Security2.FileSystemAuditRule2]
            (Get-TestAccountAuditRule -Acl $sd.SecurityDescriptor -Account $probe) | Should -HaveCount 1
        }
    }
}

Describe 'Remove-NTFSAudit' {
    Context 'Binding -Path from the pipeline by property name' {
        # The PathSimple row pipes AppliesTo and the PathSimpleNamed row names it. Neither can tell the sets apart here: the
        # entry is on a file, where the scope does not matter. The Contexts on folders below do.
        It "Should remove the audit entry for the piped <Set> object that exists, write a ReadFileError for the one that does not, and keep the other account's entry" -ForEach @(
            @{ Set = 'PathComplex'; ExtraProperties = @{ InheritanceFlags = 'None'; PropagationFlags = 'None' }; Named = @{} }
            @{ Set = 'PathSimple'; ExtraProperties = @{ AppliesTo = 'ThisFolderOnly' }; Named = @{} }
            @{ Set = 'PathSimpleNamed'; ExtraProperties = @{}; Named = @{ AppliesTo = 'ThisFolderOnly' } }
        ) -Skip:(-not $canReadAudit) {
            $missing = Join-Path -Path $sandbox -ChildPath ('RemovePipeMissing-{0}' -f [guid]::NewGuid().ToString('N'))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $good = New-TestSandboxItem -Sandbox $sandbox -Name "RemovePipeGood$Set"
            Add-NTFSAudit -Path $good @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            Add-NTFSAudit -Path $good -Account $keeper -AccessRights Delete -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $daclBefore = Get-TestDaclSddl -Path $good

            $items = @(
                [pscustomobject] (@{ FullName = $missing; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
                [pscustomobject] (@{ FullName = $good; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
            )

            $result = @($items | Remove-NTFSAudit @Named -PassThru -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $auditErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $auditErrors[0].TargetObject | Should -Be $missing
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_.FullName | Should -Be $good }
            (Get-TestAccountAuditRule -Acl (Get-Acl -LiteralPath $good -Audit) -Account $probe) | Should -BeNullOrEmpty
            (Get-TestAccountAuditRule -Acl (Get-Acl -LiteralPath $good -Audit) -Account $keeper) | Should -HaveCount 1
            Get-TestDaclSddl -Path $good | Should -BeExactly $daclBefore
        }
    }

    Context 'Binding -SecurityDescriptor from the pipeline by property name' {
        It "Should remove the audit entry for the piped <Set> object that has an audit section, write a ReadSecurityError for the one that does not, and keep the other account's entry" -ForEach @(
            @{ Set = 'SDSimple'; ExtraProperties = @{ AppliesTo = 'ThisFolderOnly' } }
            @{ Set = 'SDComplex'; ExtraProperties = @{ InheritanceFlags = 'None'; PropagationFlags = 'None' } }
        ) -Skip:(-not $canReadAudit) {
            $badFile = New-TestSandboxItem -Sandbox $sandbox -Name "RemovePipeSDBad$Set"
            $sdBad = Get-TestAccessOnlyDescriptor -Path $badFile
            $goodFile = New-TestSandboxItem -Sandbox $sandbox -Name "RemovePipeSDGood$Set"
            Add-NTFSAudit -Path $goodFile @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            Add-NTFSAudit -Path $goodFile -Account $keeper -AccessRights Delete -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $sdGood = Get-NTFSSecurityDescriptor -Path $goodFile -ErrorAction Stop

            $items = @(
                [pscustomobject] (@{ SecurityDescriptor = $sdBad; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
                [pscustomobject] (@{ SecurityDescriptor = $sdGood; Account = $probe; AccessRights = 'ReadData' } + $ExtraProperties)
            )

            $result = @($items | Remove-NTFSAudit -PassThru -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $auditErrors[0].TargetObject | Should -Be $sdBad
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_.FullName | Should -Be $goodFile }
            (Get-TestAccountAuditRule -Acl $sdGood.SecurityDescriptor -Account $probe) | Should -BeNullOrEmpty
            (Get-TestAccountAuditRule -Acl $sdGood.SecurityDescriptor -Account $keeper) | Should -HaveCount 1
        }
    }

    # As for Add-NTFSAudit, the property AppliesTo of the piped object selects PathSimple, and the entry that the cmdlet
    # addresses is the one of the scope it names: the rest of an entry of a wider scope stays.
    Context 'Choosing the parameter set of an object bound through the pipeline by property name' {
        It 'Should leave <Meaning> of an audit entry that applies to this folder, subfolders, and files when the piped object that has <Shape> removes its rights' -ForEach @(
            @{ Name = 'RemovePipedAuditThisFolderOnly'; Shape = 'AppliesTo ThisFolderOnly'; Extra = @{ AppliesTo = 'ThisFolderOnly' }; Meaning = 'the part that only subfolders and files inherit'; Left = 'ContainerInherit, ObjectInherit/InheritOnly' }
            @{ Name = 'RemovePipedAuditNoScope'; Shape = 'no scope'; Extra = @{}; Meaning = 'nothing'; Left = '' }
        ) -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name $Name -Directory
            Add-NTFSAudit -Path $folder @entry -ErrorAction Stop

            [pscustomobject] (@{ FullName = $folder; Account = $probe; AccessRights = 'ReadData' } + $Extra) | Remove-NTFSAudit -ErrorAction Stop

            Get-TestAuditScope -Acl (Get-Acl -LiteralPath $folder -Audit) | Should -BeExactly $Left
        }

        It 'Should reject a piped object that has both AppliesTo and InheritanceFlags with an AmbiguousParameterSet error' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePipedAuditBoth' -Directory
            $object = [pscustomobject]@{ FullName = $folder; Account = $probe; AccessRights = 'ReadData'; AppliesTo = 'ThisFolderOnly'; InheritanceFlags = 'None' }

            { $object | Remove-NTFSAudit -ErrorAction Stop } | Should -Throw -ErrorId 'AmbiguousParameterSet*'
        }
    }

    # As for Add-NTFSAudit: the scope that the cmdlet derives from AppliesTo must not stay for the next object.
    Context 'Objects with different scopes in one pipeline' {
        It 'Should remove from each piped path object the entry of its own scope: AppliesTo, none, AppliesTo, none' -Skip:(-not $canReadAudit) {
            $folders = @('RemoveMixedAuditFirst', 'RemoveMixedAuditSecond', 'RemoveMixedAuditThird', 'RemoveMixedAuditFourth' | ForEach-Object -Process {
                    $folder = New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory
                    Add-NTFSAudit -Path $folder @entry -ErrorAction Stop
                    $folder
                })

            @(
                [pscustomobject] ($entry + @{ FullName = $folders[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ FullName = $folders[1] })
                [pscustomobject] ($entry + @{ FullName = $folders[2]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ FullName = $folders[3] })
            ) | Remove-NTFSAudit -ErrorAction Stop

            $remaining = $folders | ForEach-Object -Process { Get-TestAuditScope -Acl (Get-Acl -LiteralPath $_ -Audit) }
            $remaining -join '|' | Should -BeExactly 'ContainerInherit, ObjectInherit/InheritOnly||ContainerInherit, ObjectInherit/InheritOnly|'
        }

        It 'Should remove from each piped descriptor object the entry of its own scope: AppliesTo, then none' -Skip:(-not $canReadAudit) {
            $folders = @('RemoveMixedAuditSDFirst', 'RemoveMixedAuditSDSecond' | ForEach-Object -Process {
                    $folder = New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory
                    Add-NTFSAudit -Path $folder @entry -ErrorAction Stop
                    $folder
                })
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $folders -ErrorAction Stop)

            @(
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[1] })
            ) | Remove-NTFSAudit -ErrorAction Stop

            $remaining = $descriptors | ForEach-Object -Process { Get-TestAuditScope -Acl $_.SecurityDescriptor }
            $remaining -join '|' | Should -BeExactly 'ContainerInherit, ObjectInherit/InheritOnly|'
        }
    }

    Context 'Without -RemoveSpecific' {
        # Judged-audit-notes.md: "the Modify entry keeps the other rights (probe first, then pin)".
        It 'Should narrow an entry that grants more rights than it removes, instead of deleting it' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveNarrow'
            Add-NTFSAudit -Path $file -Account $probe -AccessRights Modify -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            Add-NTFSAudit -Path $file -Account $keeper -AccessRights Delete -InheritanceFlags None -PropagationFlags None -ErrorAction Stop

            Remove-NTFSAudit -Path $file @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop

            $probeRule = Get-TestAccountAuditRule -Acl (Get-Acl -LiteralPath $file -Audit) -Account $probe
            $probeRule | Should -HaveCount 1
            $probeRule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeFalse
            $probeRule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Delete) | Should -BeTrue
            (Get-TestAccountAuditRule -Acl (Get-Acl -LiteralPath $file -Audit) -Account $keeper) | Should -HaveCount 1
        }
    }

    Context 'Removing for several accounts in one call' {
        # judged-audit.csv (Remove-NTFSAudit PathComplex): no existing call removes for several accounts in one call.
        It 'Should remove the audit entry of each account that -Account names in one call, and leave another account alone' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSeveralAccounts'
            $bystander = 'S-1-5-11'
            foreach ($account in $probe, $keeper, $bystander) {
                Add-NTFSAudit -Path $file -Account $account -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            }
            $daclBefore = Get-TestDaclSddl -Path $file

            $result = @(Remove-NTFSAudit -Path $file -Account $probe, $keeper -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -PassThru -ErrorAction Stop)

            $acl = Get-Acl -LiteralPath $file -Audit
            (Get-TestAccountAuditRule -Acl $acl -Account $probe) | Should -BeNullOrEmpty
            (Get-TestAccountAuditRule -Acl $acl -Account $keeper) | Should -BeNullOrEmpty
            (Get-TestAccountAuditRule -Acl $acl -Account $bystander) | Should -HaveCount 1
            $result | Should -HaveCount 1
            $result[0].Account.Sid | Should -Be $bystander
            Get-TestDaclSddl -Path $file | Should -BeExactly $daclBefore
        }
    }

    Context 'When the item has no SACL' {
        # judged-audit.csv (Remove-NTFSAudit PathComplex): Audit.Tests.ps1:406 asserts no error only; this adds the
        # empty Audit SDDL and the unchanged DACL after the call.
        It 'Should leave the empty Audit SDDL and the DACL unchanged' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveNoSaclComplex'
            Get-TestAuditSddl -Path $file | Should -BeNullOrEmpty
            $daclBefore = Get-TestDaclSddl -Path $file

            Remove-NTFSAudit -Path $file -Account $probe -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorVariable removeErrors -ErrorAction SilentlyContinue

            $removeErrors | Should -BeNullOrEmpty
            Get-TestAuditSddl -Path $file | Should -BeNullOrEmpty
            Get-TestDaclSddl -Path $file | Should -BeExactly $daclBefore
        }
    }

    Context 'Direct call of -Path with -AppliesTo' {
        # Remove-NTFSAudit PathSimple (judged-audit.csv): every existing call binds it only through a splat
        # (PermissionScopes.Tests.ps1); this one names the set's parameters directly.
        It 'Should remove the entry from the path when -Path, -Account, -AccessRights, and -AppliesTo are all named directly' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveDirectPathSimple'
            Add-NTFSAudit -Path $file -Account $probe -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorAction Stop
            Add-NTFSAudit -Path $file -Account $keeper -AccessRights Delete -AppliesTo ThisFolderOnly -ErrorAction Stop

            $result = @(Remove-NTFSAudit -Path $file -Account $probe -AccessRights ReadData -AppliesTo ThisFolderOnly -PassThru -ErrorAction Stop)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            (Get-TestAccountAuditRule -Acl (Get-Acl -LiteralPath $file -Audit) -Account $probe) | Should -BeNullOrEmpty
            (Get-TestAccountAuditRule -Acl (Get-Acl -LiteralPath $file -Audit) -Account $keeper) | Should -HaveCount 1
        }
    }

    Context 'Direct call of -SecurityDescriptor with -AppliesTo' {
        # Remove-NTFSAudit SDSimple (judged-audit.csv): every existing call binds it only through a splat
        # (PermissionScopes.Tests.ps1); this one names the set's parameters directly.
        It 'Should remove the entry from the descriptor when -SecurityDescriptor, -Account, -AccessRights, and -AppliesTo are all named directly' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveDirectSDSimple'
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop
            Add-NTFSAudit -SecurityDescriptor $sd -Account $probe -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorAction Stop
            Add-NTFSAudit -SecurityDescriptor $sd -Account $keeper -AccessRights Delete -AppliesTo ThisFolderOnly -ErrorAction Stop

            $result = @(Remove-NTFSAudit -SecurityDescriptor $sd -Account $probe -AccessRights ReadData -AppliesTo ThisFolderOnly -PassThru -ErrorAction Stop)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            (Get-TestAccountAuditRule -Acl $sd.SecurityDescriptor -Account $probe) | Should -BeNullOrEmpty
            (Get-TestAccountAuditRule -Acl $sd.SecurityDescriptor -Account $keeper) | Should -HaveCount 1
        }
    }

    Context 'Leaving the item on disk untouched until Set-NTFSSecurityDescriptor writes the change' {
        # judged-audit.csv (Remove-NTFSAudit SDSimple and SDComplex): the pipeline test above (binding
        # -SecurityDescriptor by property name) proves only that the in-memory descriptor lost the account's rule;
        # this proves the item on disk keeps its audit section until Set-NTFSSecurityDescriptor writes it, and that
        # -PassThru returns audit rule objects for the SDComplex set too.
        It 'Should remove the entry from the <Set> descriptor only in memory, until Set-NTFSSecurityDescriptor writes it, and return audit rule objects with -PassThru' -ForEach @(
            @{ Set = 'SDSimple'; ExtraProperties = @{ AppliesTo = 'ThisFolderOnly' } }
            @{ Set = 'SDComplex'; ExtraProperties = @{ InheritanceFlags = 'None'; PropagationFlags = 'None' } }
        ) -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name "RemoveSDUntouched$Set"
            Add-NTFSAudit -Path $file @entry @ExtraProperties -ErrorAction Stop
            Add-NTFSAudit -Path $file -Account $keeper -AccessRights Delete @ExtraProperties -ErrorAction Stop
            $auditBefore = Get-TestAuditSddl -Path $file
            $daclBefore = Get-TestDaclSddl -Path $file
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            $result = @(Remove-NTFSAudit -SecurityDescriptor $sd @entry @ExtraProperties -PassThru -ErrorAction Stop)

            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process { $_ | Should -BeOfType [Security2.FileSystemAuditRule2] }
            (Get-TestAccountAuditRule -Acl $sd.SecurityDescriptor -Account $probe) | Should -BeNullOrEmpty
            Get-TestAuditSddl -Path $file | Should -BeExactly $auditBefore

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop

            (Get-TestAccountAuditRule -Acl (Get-TestAuditAcl -Path $file) -Account $probe) | Should -BeNullOrEmpty
            (Get-TestAccountAuditRule -Acl (Get-TestAuditAcl -Path $file) -Account $keeper) | Should -HaveCount 1
            Get-TestAuditSddl -Path $file | Should -Not -BeExactly $auditBefore
            Get-TestDaclSddl -Path $file | Should -BeExactly $daclBefore
        }
    }
}

Describe 'Clear-NTFSAudit' {
    Context 'Taking paths from the pipeline' {
        It 'Should clear the audit entries of each path taken from the pipeline and leave the DACL of each unchanged' -Skip:(-not $canReadAudit) {
            $first = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearPipeFirst'
            $second = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearPipeSecond'
            foreach ($path in $first, $second) {
                Add-NTFSAudit -Path $path @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            }
            $daclBefore = @((Get-TestDaclSddl -Path $first), (Get-TestDaclSddl -Path $second))

            $first, $second | Clear-NTFSAudit -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -BeNullOrEmpty
            @(Get-NTFSAudit -Path $first -ExcludeInherited) | Should -BeNullOrEmpty
            @(Get-NTFSAudit -Path $second -ExcludeInherited) | Should -BeNullOrEmpty
            Get-TestDaclSddl -Path $first | Should -BeExactly $daclBefore[0]
            Get-TestDaclSddl -Path $second | Should -BeExactly $daclBefore[1]
        }

        # judged-audit.csv (Clear-NTFSAudit Path): no existing test pipes a failing path and asserts the result of
        # the succeeding path that follows it.
        It 'Should clear the audit entries of the path that follows a missing one, and write only a ReadFileError for the missing one' -Skip:(-not $canReadAudit) {
            $missing = Join-Path -Path $sandbox -ChildPath ('ClearPipeMissing-{0}' -f [guid]::NewGuid().ToString('N'))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $good = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearPipeGoodAfterMissing'
            Add-NTFSAudit -Path $good @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $daclBefore = Get-TestDaclSddl -Path $good

            $missing, $good | Clear-NTFSAudit -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -HaveCount 1
            $clearErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $clearErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $clearErrors[0].TargetObject | Should -Be $missing
            @(Get-NTFSAudit -Path $good -ExcludeInherited) | Should -BeNullOrEmpty
            Get-TestDaclSddl -Path $good | Should -BeExactly $daclBefore
        }
    }

    Context 'With -DisableInheritance' {
        # judged-audit.csv: "-DisableInheritance on a path is passed (Audit.Tests.ps1:629) but its end state
        # (protected SACL, no copied inherited entries) is never asserted."
        It "Should protect the SACL and not copy the parent's inherited entry when clearing a child path" -Skip:(-not $canReadAudit) {
            $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearDisableParent' -Directory
            Add-NTFSAudit -Path $parent -Account $keeper -AccessRights Delete -AppliesTo ThisFolderAndFiles -AuditFlags Success -ErrorAction Stop
            $child = Join-Path -Path $parent -ChildPath 'Child.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            Set-Content -LiteralPath $child -Value 'Child'
            Add-NTFSAudit -Path $child @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            # Precondition: the parent's rule really is inherited onto the child before the test clears it.
            @(Get-NTFSAudit -Path $child -ExcludeExplicit) | Should -HaveCount 1
            $daclBefore = Get-TestDaclSddl -Path $child

            Clear-NTFSAudit -Path $child -DisableInheritance -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -BeNullOrEmpty
            (Get-TestAuditAcl -Path $child).AreAuditRulesProtected | Should -BeTrue
            @((Get-Acl -LiteralPath $child -Audit).GetAuditRules($true, $true, $sidType)) | Should -BeNullOrEmpty
            Get-TestDaclSddl -Path $child | Should -BeExactly $daclBefore
        }
    }

    Context 'Binding -SecurityDescriptor from the pipeline' {
        It 'Should clear each piped descriptor that has an audit section and continue past one that does not' -Skip:(-not $canReadAudit) {
            $badFile = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearPipeSDBad'
            $sdBad = Get-TestAccessOnlyDescriptor -Path $badFile
            $goodFile = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearPipeSDGood'
            Add-NTFSAudit -Path $goodFile @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $sdGood = Get-NTFSSecurityDescriptor -Path $goodFile -ErrorAction Stop
            $auditBefore = Get-TestAuditSddl -Path $goodFile
            $daclBefore = Get-TestDaclSddl -Path $goodFile

            $sdBad, $sdGood | Clear-NTFSAudit -ErrorVariable clearErrors -ErrorAction SilentlyContinue

            $clearErrors | Should -HaveCount 1
            $clearErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $clearErrors[0].TargetObject | Should -Be $sdBad
            @($sdGood.SecurityDescriptor.GetAuditRules($true, $false, $sidType)) | Should -BeNullOrEmpty
            Get-TestAuditSddl -Path $goodFile | Should -BeExactly $auditBefore

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sdGood -ErrorAction Stop

            @(Get-NTFSAudit -Path $goodFile -ExcludeInherited) | Should -BeNullOrEmpty
            Get-TestDaclSddl -Path $goodFile | Should -BeExactly $daclBefore
        }
    }
}

Describe 'Get-NTFSAudit' {
    Context 'With several paths' {
        # judged-audit.csv observation: Audit.Tests.ps1:70-73 no longer reproduces a failing path followed by one
        # that succeeds (the deny entry blocks the DACL, not the SACL that the cmdlet reads). A missing path does.
        It 'Should return the entries of the existing path in either position and a ReadFileError, category OpenError, for the missing one' -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAuditFolder' -Directory
            Add-NTFSAudit -Path $folder -Account $probe -AccessRights ReadData -AuditFlags Success -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $missing = Join-Path -Path $sandbox -ChildPath ('GetAuditMissing-{0}' -f [guid]::NewGuid().ToString('N'))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing

            $forward = @(Get-NTFSAudit -Path $missing, $folder -ErrorVariable forwardErrors -ErrorAction SilentlyContinue)
            $backward = @(Get-NTFSAudit -Path $folder, $missing -ErrorVariable backwardErrors -ErrorAction SilentlyContinue)

            foreach ($errors in $forwardErrors, $backwardErrors) {
                $errors | Should -HaveCount 1
                $errors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
                $errors[0].CategoryInfo.Category | Should -Be 'OpenError'
                $errors[0].TargetObject | Should -Be $missing
            }
            foreach ($result in $forward, $backward) {
                $result | Should -HaveCount 1
                $result[0] | Should -BeOfType [Security2.FileSystemAuditRule2]
                $result[0].FullName | Should -Be $folder
                $result[0].Account.Sid | Should -Be $probe
                $result[0].AccessRights.HasFlag([Security2.FileSystemRights2]::ReadData) | Should -BeTrue
                $result[0].AuditFlags | Should -Be ([System.Security.AccessControl.AuditFlags]::Success)
                $result[0].IsInherited | Should -BeFalse
                $result[0].InheritanceEnabled | Should -Be (-not (Get-Acl -LiteralPath $folder -Audit).AreAuditRulesProtected)
            }
        }
    }

    Context 'Taking paths from the pipeline' {
        It 'Should return the entries of each path object taken from the pipeline by value' -Skip:(-not $canReadAudit) {
            $first = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAuditPipeFirst'
            $second = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAuditPipeSecond'
            foreach ($path in $first, $second) {
                Add-NTFSAudit -Path $path @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            }

            $result = @(Get-Item2 -Path $first, $second | Get-NTFSAudit -ErrorAction Stop)

            ($result.FullName | Sort-Object) -join '|' | Should -Be (($first, $second | Sort-Object) -join '|')
        }
    }

    Context 'When the audit entries cannot be read' {
        # judged-audit.csv: Audit.Tests.ps1:48 asserts the ErrorId only; this adds the category and the target.
        It 'Should write a ReadSecurityError with category OpenError and the path as target without the Security privilege' -Skip:$canReadAudit {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAuditNoPrivilege'

            $entries = @(Get-NTFSAudit -Path $file -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $entries | Should -BeNullOrEmpty
            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $auditErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $auditErrors[0].TargetObject | Should -Be $file
        }
    }

    Context 'Binding -SecurityDescriptor from the pipeline' {
        It 'Should return the entries of the piped descriptor that has an audit section and continue past one that does not' -Skip:(-not $canReadAudit) {
            $badFile = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAuditSDBad'
            $sdBad = Get-TestAccessOnlyDescriptor -Path $badFile
            $goodFile = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAuditSDGood'
            Add-NTFSAudit -Path $goodFile @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $expected = @(Get-NTFSAudit -Path $goodFile -ErrorAction Stop | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.AuditFlags })
            $sdGood = Get-NTFSSecurityDescriptor -Path $goodFile -ErrorAction Stop

            $result = @($sdBad, $sdGood | Get-NTFSAudit -ErrorVariable auditErrors -ErrorAction SilentlyContinue)

            $auditErrors | Should -HaveCount 1
            $auditErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $auditErrors[0].CategoryInfo.Category | Should -Be 'InvalidData'
            $auditErrors[0].TargetObject | Should -Be $sdBad
            $result | Should -Not -BeNullOrEmpty
            ($result | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.AuditFlags }) -join ';' | Should -Be ($expected -join ';')
        }
    }

    Context 'Output of a security descriptor, independent of the Path set' {
        # judged-audit.csv (Get-NTFSAudit SD): the pipeline test above compares the SD set's output with the Path
        # set's output; this asserts concrete values instead.
        It 'Should return the entries of a security descriptor with the expected type, account, rights, flags, and inherited state' -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAuditSDValues' -Directory
            Add-NTFSAudit -Path $folder -Account $probe -AccessRights ReadData -AuditFlags Failure -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $folder -ErrorAction Stop

            $result = @(Get-NTFSAudit -SecurityDescriptor $sd -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType [Security2.FileSystemAuditRule2]
            $result[0].FullName | Should -Be $folder
            $result[0].Account.Sid | Should -Be $probe
            $result[0].AccessRights.HasFlag([Security2.FileSystemRights2]::ReadData) | Should -BeTrue
            $result[0].AuditFlags | Should -Be ([System.Security.AccessControl.AuditFlags]::Failure)
            $result[0].IsInherited | Should -BeFalse
            $result[0].InheritanceEnabled | Should -BeTrue
        }
    }
}

Describe 'Get-NTFSOrphanedAudit' {
    Context 'Taking paths from the pipeline' {
        It 'Should return the orphaned entries of each path taken from the pipeline and write a ReadError, category OpenError, for one that does not exist' -Skip:(-not $canReadAudit) {
            $orphaned = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedPipe'
            Add-NTFSAudit -Path $orphaned -Account 'S-1-5-21-1-2-3-9001' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $normal = New-TestSandboxItem -Sandbox $sandbox -Name 'NormalPipe'
            Add-NTFSAudit -Path $normal @entry -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $missing = Join-Path -Path $sandbox -ChildPath ('OrphanedMissing-{0}' -f [guid]::NewGuid().ToString('N'))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing

            $result = @($missing, $orphaned, $normal | Get-NTFSOrphanedAudit -ErrorVariable orphanedErrors -ErrorAction SilentlyContinue)

            $orphanedErrors | Should -HaveCount 1
            $orphanedErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadError,*'
            $orphanedErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $orphanedErrors[0].TargetObject | Should -Be $missing
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $orphaned
            $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-9001'
        }
    }

    Context 'Without the Security privilege' {
        # judged-audit.csv (Get-NTFSOrphanedAudit Path): Audit.Tests.ps1:304 asserts the ErrorId only; this adds
        # the category. Without the privilege, .NET throws PrivilegeNotHeldException, not UnauthorizedAccessException,
        # so the category is OpenError, like Get-NTFSAudit (Audit.Tests.ps1:48); PermissionDenied is a Limit (needs a
        # lab or a remote server).
        It 'Should write a ReadSecurityError with category OpenError and the path as target' -Skip:$canReadAudit {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedNoPrivilege'

            $result = @(Get-NTFSOrphanedAudit -Path $file -ErrorVariable orphanedErrors -ErrorAction SilentlyContinue)

            $result | Should -BeNullOrEmpty
            $orphanedErrors | Should -HaveCount 1
            $orphanedErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $orphanedErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $orphanedErrors[0].TargetObject | Should -Be $file
        }
    }

    Context 'Filtering a path with -ExcludeExplicit' {
        It 'Should return only the inherited orphaned entry with -ExcludeExplicit' -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedExcludeExplicitFolder' -Directory
            Add-NTFSAudit -Path $folder -Account 'S-1-5-21-1-2-3-9101' -AccessRights ReadData -AppliesTo ThisFolderAndFiles -ErrorAction Stop
            $child = Join-Path -Path $folder -ChildPath 'Child.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            Set-Content -LiteralPath $child -Value 'Child'
            Add-NTFSAudit -Path $child -Account 'S-1-5-21-1-2-3-9102' -AccessRights Delete -InheritanceFlags None -PropagationFlags None -ErrorAction Stop

            $all = @(Get-NTFSOrphanedAudit -Path $child -ErrorAction Stop)
            $result = @(Get-NTFSOrphanedAudit -Path $child -ExcludeExplicit -ErrorAction Stop)

            $all | Should -HaveCount 2
            $result | Should -HaveCount 1
            $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-9101'
            $result[0].IsInherited | Should -BeTrue
        }
    }

    Context 'Binding -SecurityDescriptor from the pipeline' {
        It 'Should return the orphaned entries of the piped descriptor that has an audit section and continue past one that does not' -Skip:(-not $canReadAudit) {
            $badFile = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedSDBad'
            $sdBad = Get-TestAccessOnlyDescriptor -Path $badFile
            $orphanedFile = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedSDGood'
            Add-NTFSAudit -Path $orphanedFile -Account 'S-1-5-21-1-2-3-9002' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $sdOrphaned = Get-NTFSSecurityDescriptor -Path $orphanedFile -ErrorAction Stop

            $result = @($sdBad, $sdOrphaned | Get-NTFSOrphanedAudit -ErrorVariable orphanedErrors -ErrorAction SilentlyContinue)

            $orphanedErrors | Should -HaveCount 1
            $orphanedErrors[0].TargetObject | Should -Be $sdBad
            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType [Security2.FileSystemAuditRule2]
            $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-9002'
            $result[0].FullName | Should -Be $orphanedFile
        }
    }

    Context 'Direct call of -SecurityDescriptor' {
        # Get-NTFSOrphanedAudit SD (judged-audit.csv): both existing calls bind it only because PowerShell resolves
        # a piped object with a SecurityDescriptor property to this parameter (Audit.Tests.ps1:243, :294); this one
        # names it directly.
        It 'Should return the orphaned entries when -SecurityDescriptor is named directly' -Skip:(-not $canReadAudit) {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedDirectSD'
            Add-NTFSAudit -Path $file -Account 'S-1-5-21-1-2-3-9003' -AccessRights ReadData -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            $result = @(Get-NTFSOrphanedAudit -SecurityDescriptor $sd -ErrorAction Stop)

            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType [Security2.FileSystemAuditRule2]
            $result[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-9003'
            $result[0].FullName | Should -Be $file
        }
    }

    Context '-Account and -Exclude filters with a descriptor' {
        # judged-audit.csv (Get-NTFSOrphanedAudit SD): no existing test passes -Account or -ExcludeInherited/
        # -ExcludeExplicit together with a descriptor.
        It 'Should filter the orphaned entries of a piped descriptor by -Account, -ExcludeExplicit, and -ExcludeInherited' -Skip:(-not $canReadAudit) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedSDFilterFolder' -Directory
            Add-NTFSAudit -Path $folder -Account 'S-1-5-21-1-2-3-9201' -AccessRights ReadData -AppliesTo ThisFolderAndFiles -ErrorAction Stop
            $child = Join-Path -Path $folder -ChildPath 'Child.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            Set-Content -LiteralPath $child -Value 'Child'
            Add-NTFSAudit -Path $child -Account 'S-1-5-21-1-2-3-9202' -AccessRights Delete -InheritanceFlags None -PropagationFlags None -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $child -ErrorAction Stop

            $inheritedOnly = @(Get-NTFSOrphanedAudit -SecurityDescriptor $sd -ExcludeExplicit -ErrorAction Stop)
            $explicitOnly = @(Get-NTFSOrphanedAudit -SecurityDescriptor $sd -ExcludeInherited -ErrorAction Stop)
            $byAccount = @(Get-NTFSOrphanedAudit -SecurityDescriptor $sd -Account 'S-1-5-21-1-2-3-9202' -ErrorAction Stop)

            $inheritedOnly | Should -HaveCount 1
            $inheritedOnly[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-9201'
            $explicitOnly | Should -HaveCount 1
            $explicitOnly[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-9202'
            $byAccount | Should -HaveCount 1
            $byAccount[0].Account.Sid | Should -Be 'S-1-5-21-1-2-3-9202'
        }
    }
}
