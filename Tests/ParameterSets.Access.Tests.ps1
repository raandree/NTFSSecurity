<#
    Tests the parameter sets of the access cmdlets (Add-NTFSAccess, Remove-NTFSAccess, Clear-NTFSAccess,
    Get-NTFSAccess, Get-NTFSOrphanedAccess, Get-NTFSSimpleAccess, Get-NTFSEffectiveAccess) that the judged test matrix
    found untested, with the module built in NTFSSecurity\bin\Release on files in a sandbox folder. Each test closes a
    gap the matrix recorded for the row it names (state, error, pipeline, continuation, or output); it does not repeat
    what Access.Tests.ps1, PathErrors.Tests.ps1, PermissionScopes.Tests.ps1, SecurityDescriptorSets.Tests.ps1, or
    PipelineControl.Tests.ps1 already assert. The -SecurityDescriptor sets of Add-NTFSAccess and Remove-NTFSAccess have
    no per-item error handler (an open item for the maintainer); no test here makes one of those two sets fail.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force

    # Security2.FileSystemAccessRule2 for Add/Remove/Get-NTFSAccess/Get-NTFSOrphanedAccess/Get-NTFSEffectiveAccess,
    # Security2.SimpleFileSystemAccessRule for Get-NTFSSimpleAccess; Clear-NTFSAccess declares no output type (no -PassThru).
    $declaredOutputTypes = @(
        @{ Name = 'Add-NTFSAccess'; Types = @('Security2.FileSystemAccessRule2') }
        @{ Name = 'Remove-NTFSAccess'; Types = @('Security2.FileSystemAccessRule2') }
        @{ Name = 'Get-NTFSAccess'; Types = @('Security2.FileSystemAccessRule2') }
        @{ Name = 'Get-NTFSOrphanedAccess'; Types = @('Security2.FileSystemAccessRule2') }
        @{ Name = 'Get-NTFSEffectiveAccess'; Types = @('Security2.FileSystemAccessRule2') }
        @{ Name = 'Get-NTFSSimpleAccess'; Types = @('Security2.SimpleFileSystemAccessRule') }
    )

    # The 13 named -AppliesTo scopes, each as the ACE flags that PermissionScopes.Tests.ps1 also uses, so that an
    # entry a security descriptor set added can be read back with .NET independently of the cmdlet.
    $sdScopeCases = @(
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
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.psm1') -Force
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\NTFSSecurity\bin\Release\NTFSSecurity.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    $sandbox = New-TestSandbox -Name 'ParameterSetsAccess'
    Push-Location -LiteralPath $sandbox

    $privateData = (Get-Module -Name NTFSSecurity).PrivateData
    $enablePrivileges = $privateData['EnablePrivileges']
    $sidType = [System.Security.Principal.SecurityIdentifier]
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

    function Get-TestAccountScope {
        # The scopes of the explicit entries of one account, each as 'inheritance flags/propagation flags', joined by ';'
        param (
            [Parameter(Mandatory)] [System.Security.AccessControl.FileSystemSecurity] $Acl,
            [Parameter(Mandatory)] [string] $Account
        )
        @($Acl.GetAccessRules($true, $false, $sidType) |
                Where-Object -FilterScript { $_.IdentityReference.Value -eq $Account } |
                ForEach-Object -Process { '{0}/{1}' -f $_.InheritanceFlags, $_.PropagationFlags }) -join ';'
    }
}

AfterAll {
    $privateData['EnablePrivileges'] = $enablePrivileges
    Pop-Location
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Add-NTFSAccess' {
    Context 'PathComplex parameter set bound through the pipeline' {
        It 'Should add one explicit entry for each path bound through the pipeline, by FullName and by property name, leaving the rest of each item unchanged' {
            $first = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPipeFirst'
            $second = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPipeSecond'
            $third = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPipeThird'
            $before = foreach ($path in $first, $second, $third) {
                $acl = Get-Acl -LiteralPath $path
                [pscustomobject]@{ Path = $path; Owner = $acl.GetOwner($sidType).Value; Inherited = @($acl.GetAccessRules($false, $true, $sidType)).Count }
            }

            Get-Item2 -Path $first, $second | Add-NTFSAccess -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            [pscustomobject]@{ Path = $third; Account = 'S-1-1-0'; AccessRights = 'ReadData' } | Add-NTFSAccess -ErrorAction Stop

            foreach ($state in $before) {
                $acl = Get-Acl -LiteralPath $state.Path
                $acl.GetOwner($sidType).Value | Should -Be $state.Owner
                @($acl.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $state.Inherited
                $explicit = @($acl.GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
                $explicit | Should -HaveCount 1
                $explicit[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeTrue
            }
        }
    }

    Context 'PathComplex parameter set with one denied path and -PassThru' {
        BeforeAll {
            # So that an elevated session meets the same denial as a basic user (see PathErrors.Tests.ps1).
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It 'Should write one AddAceError for the blocked path, leave it unchanged, and return -PassThru entries only for the path it changed' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPassThruBlocked'
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPassThruNext'
            Block-TestWritePermission -Sandbox $sandbox -Path $blocked
            $before = (Get-Acl -LiteralPath $blocked).Sddl

            $result = @(Add-NTFSAccess -Path $blocked, $next -Account 'S-1-1-0' -AccessRights ReadData -PassThru -ErrorVariable addErrors -ErrorAction SilentlyContinue)

            $addErrors | Should -HaveCount 1
            $addErrors[0].FullyQualifiedErrorId | Should -BeLike 'AddAceError,*'
            $addErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $addErrors[0].TargetObject | Should -Be $blocked
            (Get-Acl -LiteralPath $blocked).Sddl | Should -BeExactly $before
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process {
                $_ | Should -BeOfType ([Security2.FileSystemAccessRule2])
                $_.FullName | Should -Be $next
            }
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' -and -not $_.IsInherited }) | Should -HaveCount 1
        }
    }

    # The property AppliesTo selects PathSimple, InheritanceFlags and PropagationFlags select PathComplex, and an object that
    # has none of them gets the default scope. No parameter set is the default: while PathComplex was, an object that had
    # AppliesTo bound PathComplex as well, and the cmdlet dropped the property.
    Context 'Choosing the parameter set of an object bound through the pipeline by property name' {
        It 'Should give the entry for the piped object that has <Shape> the scope <Scope>' -ForEach @(
            @{ Name = 'AddPipedThisFolderOnly'; Shape = 'AppliesTo ThisFolderOnly'; Extra = @{ AppliesTo = 'ThisFolderOnly' }; Scope = 'None/None' }
            @{ Name = 'AddPipedSubfolders'; Shape = 'AppliesTo ThisFolderAndSubfolders'; Extra = @{ AppliesTo = 'ThisFolderAndSubfolders' }; Scope = 'ContainerInherit/None' }
            @{ Name = 'AddPipedInheritOnly'; Shape = 'AppliesTo SubfoldersAndFilesOnly'; Extra = @{ AppliesTo = 'SubfoldersAndFilesOnly' }; Scope = 'ContainerInherit, ObjectInherit/InheritOnly' }
            @{ Name = 'AddPipedFlags'; Shape = 'InheritanceFlags and PropagationFlags'; Extra = @{ InheritanceFlags = 'ContainerInherit'; PropagationFlags = 'InheritOnly' }; Scope = 'ContainerInherit/InheritOnly' }
            @{ Name = 'AddPipedNoScope'; Shape = 'no scope'; Extra = @{}; Scope = 'ContainerInherit, ObjectInherit/None' }
        ) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name $Name -Directory

            [pscustomobject] (@{ Path = $folder; Account = 'S-1-5-32-546'; AccessRights = 'ReadData' } + $Extra) | Add-NTFSAccess -ErrorAction Stop

            Get-TestAccountScope -Acl (Get-Acl -LiteralPath $folder) -Account 'S-1-5-32-546' | Should -BeExactly $Scope
        }

        It 'Should reject a piped object that has both AppliesTo and InheritanceFlags with an AmbiguousParameterSet error and change nothing' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPipedBoth' -Directory
            $before = (Get-Acl -LiteralPath $folder).Sddl
            $object = [pscustomobject]@{ Path = $folder; Account = 'S-1-1-0'; AccessRights = 'ReadData'; AppliesTo = 'ThisFolderOnly'; InheritanceFlags = 'None' }

            { $object | Add-NTFSAccess -ErrorAction Stop } | Should -Throw -ErrorId 'AmbiguousParameterSet*'

            (Get-Acl -LiteralPath $folder).Sddl | Should -BeExactly $before
        }
    }

    # PowerShell resets only the parameters that the previous object bound from the pipeline. The scope that the cmdlet
    # derives from AppliesTo must therefore not stay in the fields behind InheritanceFlags and PropagationFlags: the next
    # object that has no scope, or only one flag, would get it.
    Context 'Objects with different scopes in one pipeline' {
        It 'Should give each piped path object only its own scope: AppliesTo, none, AppliesTo, one flag, none' {
            $folders = @('AddMixedThisFolderOnly', 'AddMixedNoScope', 'AddMixedInheritOnly', 'AddMixedOneFlag', 'AddMixedNoScopeAgain' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $entry = @{ Account = 'S-1-5-32-546'; AccessRights = 'ReadData' }

            @(
                [pscustomobject] ($entry + @{ Path = $folders[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ Path = $folders[1] })
                [pscustomobject] ($entry + @{ Path = $folders[2]; AppliesTo = 'SubfoldersAndFilesOnly' })
                [pscustomobject] ($entry + @{ Path = $folders[3]; InheritanceFlags = 'ContainerInherit' })
                [pscustomobject] ($entry + @{ Path = $folders[4] })
            ) | Add-NTFSAccess -ErrorAction Stop

            $scopes = $folders | ForEach-Object -Process { Get-TestAccountScope -Acl (Get-Acl -LiteralPath $_) -Account 'S-1-5-32-546' }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit, ObjectInherit/None|ContainerInherit, ObjectInherit/InheritOnly|ContainerInherit/None|ContainerInherit, ObjectInherit/None'
        }

        It 'Should give each row of a CSV file that Import-Csv reads and that has an AppliesTo column its own scope' {
            $folders = @('AddCsvThisFolderOnly', 'AddCsvSubfolders', 'AddCsvInheritOnly' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $csv = Join-Path -Path $sandbox -ChildPath 'AddCsvScopes.csv'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $csv
            Set-Content -LiteralPath $csv -Value @(
                'Path,Account,AccessRights,AppliesTo'
                ('"{0}",S-1-5-32-546,ReadData,ThisFolderOnly' -f $folders[0])
                ('"{0}",S-1-5-32-546,ReadData,ThisFolderAndSubfolders' -f $folders[1])
                ('"{0}",S-1-5-32-546,ReadData,SubfoldersAndFilesOnly' -f $folders[2])
            )

            Import-Csv -LiteralPath $csv | Add-NTFSAccess -ErrorAction Stop

            $scopes = $folders | ForEach-Object -Process { Get-TestAccountScope -Acl (Get-Acl -LiteralPath $_) -Account 'S-1-5-32-546' }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit/None|ContainerInherit, ObjectInherit/InheritOnly'
        }

        # A blank cell that Import-Csv reads is an empty string: not $null, and not a scope name. The binder cannot convert it, so
        # PathSimple does not bind, and the row gets the default scope, as an object without the property does.
        It 'Should give the row of a CSV file whose AppliesTo cell is blank the default scope, and the other rows their own' {
            $folders = @('AddCsvBlankFirst', 'AddCsvBlankCell', 'AddCsvBlankLast' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $csv = Join-Path -Path $sandbox -ChildPath 'AddCsvBlank.csv'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $csv
            Set-Content -LiteralPath $csv -Value @(
                'Path,Account,AccessRights,AppliesTo'
                ('"{0}",S-1-5-32-546,ReadData,ThisFolderOnly' -f $folders[0])
                ('"{0}",S-1-5-32-546,ReadData,' -f $folders[1])
                ('"{0}",S-1-5-32-546,ReadData,SubfoldersAndFilesOnly' -f $folders[2])
            )

            Import-Csv -LiteralPath $csv | Add-NTFSAccess -ErrorAction Stop

            $scopes = $folders | ForEach-Object -Process { Get-TestAccountScope -Acl (Get-Acl -LiteralPath $_) -Account 'S-1-5-32-546' }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit, ObjectInherit/None|ContainerInherit, ObjectInherit/InheritOnly'
        }

        # $null cannot be bound at all (ConvertFrom-Csv makes it of a trailing blank cell): the object fails, loudly, and the cmdlet goes
        # on with the next one.
        It 'Should report a binding error for the piped object whose AppliesTo is $null, leave its folder alone, and still process the other objects' {
            $folders = @('AddNullFirst', 'AddNullMiddle', 'AddNullLast' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $entry = @{ Account = 'S-1-5-32-546'; AccessRights = 'ReadData' }

            @(
                [pscustomobject] ($entry + @{ Path = $folders[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ Path = $folders[1]; AppliesTo = $null })
                [pscustomobject] ($entry + @{ Path = $folders[2]; AppliesTo = 'SubfoldersAndFilesOnly' })
            ) | Add-NTFSAccess -ErrorVariable addErrors -ErrorAction SilentlyContinue

            @($addErrors) | Should -HaveCount 1
            $addErrors[0].FullyQualifiedErrorId | Should -BeLike 'ParameterArgumentValidationErrorNullNotAllowed,*'
            $scopes = $folders | ForEach-Object -Process { Get-TestAccountScope -Acl (Get-Acl -LiteralPath $_) -Account 'S-1-5-32-546' }
            $scopes -join '|' | Should -BeExactly 'None/None||ContainerInherit, ObjectInherit/InheritOnly'
        }

        It 'Should give each piped descriptor object only its own scope: AppliesTo, then none' {
            $folders = @('AddMixedSDThisFolderOnly', 'AddMixedSDNoScope' |
                    ForEach-Object -Process { New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory })
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $folders -ErrorAction Stop)
            $entry = @{ Account = 'S-1-5-32-546'; AccessRights = 'ReadData' }

            @(
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[1] })
            ) | Add-NTFSAccess -ErrorAction Stop

            $scopes = $descriptors | ForEach-Object -Process { Get-TestAccountScope -Acl $_.SecurityDescriptor -Account 'S-1-5-32-546' }
            $scopes -join '|' | Should -BeExactly 'None/None|ContainerInherit, ObjectInherit/None'
        }
    }

    Context 'PathSimple parameter set' {
        It 'Should report a missing path''s error by category and target, still scope the next path''s entry, and keep binding -Path through the pipeline once -AppliesTo selects the set' {
            $missing = Join-Path -Path $sandbox -ChildPath ('AddSimpleMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSimpleNext'

            Add-NTFSAccess -Path $missing, $file -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorVariable addErrors -ErrorAction SilentlyContinue

            $addErrors | Should -HaveCount 1
            $addErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $addErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $addErrors[0].TargetObject | Should -Be $missing
            $fileRule = @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
            $fileRule | Should -HaveCount 1

            # -AppliesTo named explicitly selects PathSimple while -Path arrives through the pipeline.
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSimplePipedFolder' -Directory

            Get-Item2 -Path $folder | Add-NTFSAccess -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo ThisFolderAndSubfolders -ErrorAction Stop

            $guestsRule = @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-32-546' })
            $guestsRule | Should -HaveCount 1
            $guestsRule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit)
            $guestsRule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
            $guestsRule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeTrue
        }
    }

    Context 'PathComplex parameter set, additional state assertions' {
        It 'Should add an explicit allow entry for each of several accounts bound positionally, with the default scope' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddPositionalSeveral' -Directory

            Add-NTFSAccess $folder @('S-1-1-0', 'S-1-5-32-546') 'ReadData' -ErrorAction Stop

            foreach ($account in 'S-1-1-0', 'S-1-5-32-546') {
                $rule = @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq $account })
                $rule | Should -HaveCount 1
                $rule[0].AccessControlType | Should -Be ([System.Security.AccessControl.AccessControlType]::Allow)
                $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeTrue
                $rule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags] 'ContainerInherit, ObjectInherit')
                $rule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
            }
        }

        # Only an Allow entry gets Synchronize added (the page); a Deny entry written through -Path must carry
        # exactly the requested rights.
        It 'Should write a Deny entry through -Path with exactly the requested rights and no Synchronize' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddDenySynchronize'

            Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData -AccessType Deny -ErrorAction Stop

            $rule = @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
            $rule | Should -HaveCount 1
            $rule[0].AccessControlType | Should -Be ([System.Security.AccessControl.AccessControlType]::Deny)
            $rule[0].FileSystemRights | Should -Be ([System.Security.AccessControl.FileSystemRights]::ReadData)
        }
    }

    Context 'PathSimple parameter set, Deny entries and a denied write' {
        BeforeAll {
            # So that an elevated session meets the same denial as a basic user (see PathErrors.Tests.ps1).
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It 'Should report AddAceError by category and target for a denied write scoped by -AppliesTo, and leave the item unchanged' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSimpleBlocked'
            Block-TestWritePermission -Sandbox $sandbox -Path $blocked
            $before = (Get-Acl -LiteralPath $blocked).Sddl

            Add-NTFSAccess -Path $blocked -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorVariable addErrors -ErrorAction SilentlyContinue

            $addErrors | Should -HaveCount 1
            $addErrors[0].FullyQualifiedErrorId | Should -BeLike 'AddAceError,*'
            $addErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $addErrors[0].TargetObject | Should -Be $blocked
            (Get-Acl -LiteralPath $blocked).Sddl | Should -BeExactly $before
        }

        # .NET refuses to build a deny entry without rights for this parameter set too; the write-denial code path
        # above is shared with PathComplex (Access.Tests.ps1:740), so only the categorization needs its own case here.
        It 'Should write an AddAceError for a Deny entry without rights through the PathSimple set, and change nothing' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSimpleDenyNone'
            $before = (Get-Acl -LiteralPath $file).Sddl

            $result = @(Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights None -AccessType Deny -AppliesTo ThisFolderOnly -PassThru -ErrorVariable addErrors -ErrorAction SilentlyContinue)

            $result | Should -BeNullOrEmpty
            $addErrors | Should -HaveCount 1
            $addErrors[0].FullyQualifiedErrorId | Should -BeLike 'AddAceError,*'
            $addErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            (Get-Acl -LiteralPath $file).Sddl | Should -BeExactly $before
        }

        It 'Should write a Deny entry scoped by -AppliesTo with exactly the requested rights and no Synchronize' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSimpleDenyScoped' -Directory

            Add-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -AccessType Deny -AppliesTo ThisFolderAndSubfolders -ErrorAction Stop

            $rule = @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
            $rule | Should -HaveCount 1
            $rule[0].AccessControlType | Should -Be ([System.Security.AccessControl.AccessControlType]::Deny)
            $rule[0].FileSystemRights | Should -Be ([System.Security.AccessControl.FileSystemRights]::ReadData)
            $rule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit)
            $rule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
        }
    }

    Context 'SDSimple parameter set' {
        It 'Should add an entry with the scope <Name> to each of several descriptors bound through the pipeline, read back with .NET, and leave the items unchanged on disk' -ForEach $sdScopeCases {
            $first = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSdScopeFirst' -Directory
            $second = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSdScopeSecond' -Directory
            $before = foreach ($folder in $first, $second) { (Get-Acl -LiteralPath $folder).GetSecurityDescriptorSddlForm('Access') }
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $first, $second -ErrorAction Stop)

            $descriptors | Add-NTFSAccess -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo $Name -ErrorAction Stop

            for ($index = 0; $index -lt 2; $index++) {
                $rule = @($descriptors[$index].SecurityDescriptor.GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-32-546' })
                $rule | Should -HaveCount 1
                $rule[0].AccessControlType | Should -Be ([System.Security.AccessControl.AccessControlType]::Allow)
                $rule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags] $Inheritance)
                $rule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags] $Propagation)
            }
            (Get-Acl -LiteralPath $first).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $before[0]
            (Get-Acl -LiteralPath $second).GetSecurityDescriptorSddlForm('Access') | Should -BeExactly $before[1]
        }
    }

    Context 'SDComplex parameter set with several descriptors' {
        It 'Should add the entry to each of several descriptors bound through the pipeline, read back with .NET, and leave the items unchanged on disk' {
            $first = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSdComplexPipeFirst'
            $second = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSdComplexPipeSecond'
            $before = foreach ($file in $first, $second) { (Get-Acl -LiteralPath $file).Sddl }
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $first, $second -ErrorAction Stop)

            $descriptors | Add-NTFSAccess -Account 'S-1-5-21-1-2-3-9501' -AccessRights ReadData, WriteData -InheritanceFlags None -PropagationFlags None -ErrorAction Stop

            for ($index = 0; $index -lt 2; $index++) {
                $rule = @($descriptors[$index].SecurityDescriptor.GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9501' })
                $rule | Should -HaveCount 1
                $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeTrue
                $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::WriteData) | Should -BeTrue
            }
            (Get-Acl -LiteralPath $first).Sddl | Should -BeExactly $before[0]
            (Get-Acl -LiteralPath $second).Sddl | Should -BeExactly $before[1]
        }
    }
}

Describe 'Remove-NTFSAccess' {
    Context 'PathComplex parameter set with one denied path and -PassThru' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It 'Should write one RemoveAceError for the blocked path, leave it unchanged, and return -PassThru entries only for the path it changed' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePassThruBlocked'
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePassThruNext'
            Add-NTFSAccess -Path $blocked, $next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            Block-TestWritePermission -Sandbox $sandbox -Path $blocked
            $before = (Get-Acl -LiteralPath $blocked).Sddl

            $result = @(Remove-NTFSAccess -Path $blocked, $next -Account 'S-1-1-0' -AccessRights ReadData -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)

            $removeErrors | Should -HaveCount 1
            $removeErrors[0].FullyQualifiedErrorId | Should -BeLike 'RemoveAceError,*'
            $removeErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $removeErrors[0].TargetObject | Should -Be $blocked
            (Get-Acl -LiteralPath $blocked).Sddl | Should -BeExactly $before
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object -Process {
                $_ | Should -BeOfType ([Security2.FileSystemAccessRule2])
                $_.FullName | Should -Be $next
            }
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' }) | Should -BeNullOrEmpty
        }
    }

    # As for Add-NTFSAccess, the property AppliesTo of the piped object selects PathSimple, and the entry that the cmdlet
    # addresses is the one of the scope it names: the rest of an entry of a wider scope stays.
    Context 'Choosing the parameter set of an object bound through the pipeline by property name' {
        It 'Should leave <Meaning> of an entry that applies to this folder, subfolders, and files when the piped object that has <Shape> removes its rights' -ForEach @(
            @{ Name = 'RemovePipedThisFolderOnly'; Shape = 'AppliesTo ThisFolderOnly'; Extra = @{ AppliesTo = 'ThisFolderOnly' }; Meaning = 'the part that only subfolders and files inherit'; Left = 'ContainerInherit, ObjectInherit/InheritOnly' }
            @{ Name = 'RemovePipedNoScope'; Shape = 'no scope'; Extra = @{}; Meaning = 'nothing'; Left = '' }
        ) {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name $Name -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop

            [pscustomobject] (@{ Path = $folder; Account = 'S-1-5-32-546'; AccessRights = 'ReadData' } + $Extra) | Remove-NTFSAccess -ErrorAction Stop

            Get-TestAccountScope -Acl (Get-Acl -LiteralPath $folder) -Account 'S-1-5-32-546' | Should -BeExactly $Left
        }

        It 'Should reject a piped object that has both AppliesTo and InheritanceFlags with an AmbiguousParameterSet error and change nothing' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePipedBoth' -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorAction Stop
            $before = (Get-Acl -LiteralPath $folder).Sddl
            $object = [pscustomobject]@{ Path = $folder; Account = 'S-1-1-0'; AccessRights = 'ReadData'; AppliesTo = 'ThisFolderOnly'; InheritanceFlags = 'None' }

            { $object | Remove-NTFSAccess -ErrorAction Stop } | Should -Throw -ErrorId 'AmbiguousParameterSet*'

            (Get-Acl -LiteralPath $folder).Sddl | Should -BeExactly $before
        }
    }

    # As for Add-NTFSAccess: the scope that the cmdlet derives from AppliesTo must not stay for the next object.
    Context 'Objects with different scopes in one pipeline' {
        It 'Should remove from each piped path object the entry of its own scope: AppliesTo, none, AppliesTo, none' {
            $folders = @('RemoveMixedFirst', 'RemoveMixedSecond', 'RemoveMixedThird', 'RemoveMixedFourth' | ForEach-Object -Process {
                    $folder = New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory
                    Add-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop
                    $folder
                })
            $entry = @{ Account = 'S-1-5-32-546'; AccessRights = 'ReadData' }

            @(
                [pscustomobject] ($entry + @{ Path = $folders[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ Path = $folders[1] })
                [pscustomobject] ($entry + @{ Path = $folders[2]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ Path = $folders[3] })
            ) | Remove-NTFSAccess -ErrorAction Stop

            $remaining = $folders | ForEach-Object -Process { Get-TestAccountScope -Acl (Get-Acl -LiteralPath $_) -Account 'S-1-5-32-546' }
            $remaining -join '|' | Should -BeExactly 'ContainerInherit, ObjectInherit/InheritOnly||ContainerInherit, ObjectInherit/InheritOnly|'
        }

        It 'Should remove from each piped descriptor object the entry of its own scope: AppliesTo, then none' {
            $folders = @('RemoveMixedSDFirst', 'RemoveMixedSDSecond' | ForEach-Object -Process {
                    $folder = New-TestSandboxItem -Sandbox $sandbox -Name $_ -Directory
                    Add-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop
                    $folder
                })
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $folders -ErrorAction Stop)
            $entry = @{ Account = 'S-1-5-32-546'; AccessRights = 'ReadData' }

            @(
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[0]; AppliesTo = 'ThisFolderOnly' })
                [pscustomobject] ($entry + @{ SecurityDescriptor = $descriptors[1] })
            ) | Remove-NTFSAccess -ErrorAction Stop

            $remaining = $descriptors | ForEach-Object -Process { Get-TestAccountScope -Acl $_.SecurityDescriptor -Account 'S-1-5-32-546' }
            $remaining -join '|' | Should -BeExactly 'ContainerInherit, ObjectInherit/InheritOnly|'
        }
    }

    Context 'PathSimple parameter set' {
        It 'Should take only the requested rights from an entry scoped by -AppliesTo without -RemoveSpecific, keep its flags, and leave another account''s entry untouched' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSimpleScope' -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop
            Add-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights Delete -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop

            Remove-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop

            $rules = (Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType)
            $everyoneRule = @($rules | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' })
            $everyoneRule | Should -HaveCount 1
            $everyoneRule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeFalse
            $everyoneRule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::WriteData) | Should -BeTrue
            $everyoneRule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags] 'ContainerInherit, ObjectInherit')
            $everyoneRule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
            $guestsRule = @($rules | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-32-546' })
            $guestsRule | Should -HaveCount 1
            $guestsRule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Delete) | Should -BeTrue
        }
    }

    Context 'PathComplex parameter set, additional state assertions' {
        It 'Should return exactly the surviving entries with -PassThru for each of several paths bound through the pipeline in one call' {
            $keeper = 'S-1-1-0'
            $target = 'S-1-5-32-546'
            $folders = @(
                New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePassThruCountFirst' -Directory
                New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePassThruCountSecond' -Directory
            )
            foreach ($folder in $folders) {
                Add-NTFSAccess -Path $folder -Account $keeper -AccessRights ReadData -ErrorAction Stop
                Add-NTFSAccess -Path $folder -Account $target -AccessRights ReadData -ErrorAction Stop
            }
            # The independent oracle: every rule of the item that isn't the one being removed.
            $expected = foreach ($folder in $folders) {
                @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $true, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -ne $target }).Count
            }

            $result = @(Get-Item2 -Path $folders | Remove-NTFSAccess -Account $target -AccessRights ReadData -PassThru -ErrorAction Stop)

            for ($index = 0; $index -lt $folders.Count; $index++) {
                $folderResult = @($result | Where-Object -FilterScript { $_.FullName -eq $folders[$index] })
                $folderResult | Should -HaveCount $expected[$index]
                $folderResult | ForEach-Object -Process { $_ | Should -BeOfType ([Security2.FileSystemAccessRule2]) }
                @($folderResult | Where-Object -FilterScript { $_.Account.Sid -eq $target }) | Should -BeNullOrEmpty
                @($folderResult | Where-Object -FilterScript { $_.Account.Sid -eq $keeper }) | Should -HaveCount 1
            }
        }

        It 'Should remove the entries of several accounts bound positionally, leaving another account untouched' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemovePositionalSeveral' -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            Add-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights ReadData -ErrorAction Stop
            Add-NTFSAccess -Path $folder -Account 'S-1-5-21-1-2-3-9701' -AccessRights ReadData -ErrorAction Stop

            Remove-NTFSAccess $folder @('S-1-1-0', 'S-1-5-32-546') 'ReadData' -ErrorAction Stop

            $rules = (Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType)
            @($rules | Where-Object -FilterScript { $_.IdentityReference.Value -in 'S-1-1-0', 'S-1-5-32-546' }) | Should -BeNullOrEmpty
            @($rules | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9701' }) | Should -HaveCount 1
        }
    }

    Context 'PathSimple parameter set, a Deny entry and pipeline errors' {
        BeforeAll {
            # So that an elevated session meets the same denial as a basic user (see PathErrors.Tests.ps1). Harmless
            # for the Deny-reduction test below, which never hits a permission denial.
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It 'Should take only the requested rights from a Deny entry scoped by -AppliesTo without -RemoveSpecific, and keep its flags' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSimpleDenyReduce' -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-5-21-1-2-3-9702' -AccessRights Modify -AccessType Deny -AppliesTo ThisFolderAndSubfolders -ErrorAction Stop

            Remove-NTFSAccess -Path $folder -Account 'S-1-5-21-1-2-3-9702' -AccessRights ReadData -AccessType Deny -AppliesTo ThisFolderAndSubfolders -ErrorAction Stop

            $rule = @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9702' })
            $rule | Should -HaveCount 1
            $rule[0].AccessControlType | Should -Be ([System.Security.AccessControl.AccessControlType]::Deny)
            $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeFalse
            $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::WriteData) | Should -BeTrue
            $rule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit)
            $rule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
        }

        It 'Should report a missing path''s and a denied path''s errors by category and target, and still scope the surviving paths'' entries, all bound through the pipeline' {
            $missing = Join-Path -Path $sandbox -ChildPath ('RemoveSimpleMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSimpleBlocked' -Directory
            $survivor1 = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSimpleSurvivor1' -Directory
            $survivor2 = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSimpleSurvivor2' -Directory
            foreach ($folder in $blocked, $survivor1, $survivor2) {
                Add-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorAction Stop
            }
            Block-TestWritePermission -Sandbox $sandbox -Path $blocked
            $before = (Get-Acl -LiteralPath $blocked).Sddl
            # Property-name binding of -Path, like the piped objects of the Add-NTFSAccess pipeline tests; -Account,
            # -AccessRights and -AppliesTo come from the call itself and apply to every piped object alike.
            $paths = foreach ($value in $missing, $blocked, $survivor1, $survivor2) { [pscustomobject]@{ Path = $value } }

            $result = @($paths | Remove-NTFSAccess -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly -PassThru -ErrorVariable removeErrors -ErrorAction SilentlyContinue)

            $removeErrors | Should -HaveCount 2
            $missingError = @($removeErrors | Where-Object -FilterScript { $_.TargetObject -eq $missing })
            $missingError | Should -HaveCount 1
            $missingError[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $missingError[0].CategoryInfo.Category | Should -Be 'OpenError'
            $blockedError = @($removeErrors | Where-Object -FilterScript { $_.TargetObject -eq $blocked })
            $blockedError | Should -HaveCount 1
            $blockedError[0].FullyQualifiedErrorId | Should -BeLike 'RemoveAceError,*'
            $blockedError[0].CategoryInfo.Category | Should -Be 'WriteError'
            (Get-Acl -LiteralPath $blocked).Sddl | Should -BeExactly $before
            foreach ($survivor in $survivor1, $survivor2) {
                @((Get-Acl -LiteralPath $survivor).GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -BeNullOrEmpty
                @($result | Where-Object -FilterScript { $_.FullName -eq $survivor }) | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'SDSimple parameter set' {
        It 'Should take only the requested rights from an entry scoped by -AppliesTo on a descriptor without -RemoveSpecific, keep its flags, and leave the item on disk unchanged until Set-NTFSSecurityDescriptor' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSdSimpleReduce' -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-5-21-1-2-3-9602' -AccessRights Modify -AppliesTo ThisFolderAndSubfolders -ErrorAction Stop
            $before = (Get-Acl -LiteralPath $folder).Sddl
            $sd = Get-NTFSSecurityDescriptor -Path $folder -ErrorAction Stop

            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'S-1-5-21-1-2-3-9602' -AccessRights ReadData -AppliesTo ThisFolderAndSubfolders -ErrorAction Stop

            $rule = @($sd.SecurityDescriptor.GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9602' })
            $rule | Should -HaveCount 1
            $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeFalse
            $rule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::WriteData) | Should -BeTrue
            $rule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit)
            $rule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
            (Get-Acl -LiteralPath $folder).Sddl | Should -BeExactly $before

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop

            $onDisk = @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9602' })
            $onDisk | Should -HaveCount 1
            $onDisk[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeFalse
        }

        It 'Should remove the matching entry from each of several descriptors bound through the pipeline for the Simple parameter set, leaving the items unchanged on disk' {
            $folders = @(
                New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSdSimplePipeFirst' -Directory
                New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSdSimplePipeSecond' -Directory
            )
            foreach ($folder in $folders) {
                Add-NTFSAccess -Path $folder -Account 'S-1-5-21-1-2-3-9603' -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorAction Stop
            }
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $folders -ErrorAction Stop)

            $descriptors | Remove-NTFSAccess -Account 'S-1-5-21-1-2-3-9603' -AccessRights ReadData -AppliesTo ThisFolderOnly -RemoveSpecific -ErrorAction Stop

            foreach ($sd in $descriptors) {
                @($sd.SecurityDescriptor.GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9603' }) | Should -BeNullOrEmpty
            }
            foreach ($folder in $folders) {
                @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9603' }) | Should -HaveCount 1
            }
        }
    }

    Context 'SDComplex parameter set' {
        It 'Should remove an on-disk entry from a descriptor in memory only, and write the change through only when Set-NTFSSecurityDescriptor runs' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSdWriteThrough'
            Add-NTFSAccess -Path $file -Account 'S-1-5-21-1-2-3-9601' -AccessRights ReadData -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            Remove-NTFSAccess -SecurityDescriptor $sd -Account 'S-1-5-21-1-2-3-9601' -AccessRights ReadData -ErrorAction Stop

            @($sd.SecurityDescriptor.GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9601' }) | Should -BeNullOrEmpty
            @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9601' }) | Should -HaveCount 1

            Set-NTFSSecurityDescriptor -SecurityDescriptor $sd -ErrorAction Stop

            @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9601' }) | Should -BeNullOrEmpty
        }

        It 'Should remove the matching entry from each of several descriptors bound through the pipeline for the Complex parameter set, leaving the items unchanged on disk' {
            $files = @(
                New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSdComplexPipeFirst'
                New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveSdComplexPipeSecond'
            )
            foreach ($file in $files) {
                Add-NTFSAccess -Path $file -Account 'S-1-5-21-1-2-3-9604' -AccessRights ReadData -ErrorAction Stop
            }
            $descriptors = @(Get-NTFSSecurityDescriptor -Path $files -ErrorAction Stop)

            $descriptors | Remove-NTFSAccess -Account 'S-1-5-21-1-2-3-9604' -AccessRights ReadData -ErrorAction Stop

            foreach ($sd in $descriptors) {
                @($sd.SecurityDescriptor.GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9604' }) | Should -BeNullOrEmpty
            }
            foreach ($file in $files) {
                @((Get-Acl -LiteralPath $file).GetAccessRules($true, $false, $sidType) |
                        Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-21-1-2-3-9604' }) | Should -HaveCount 1
            }
        }
    }
}

Describe 'Clear-NTFSAccess' {
    Context 'Path parameter set on folders bound through the pipeline' {
        It 'Should clear each piped folder''s explicit entries, including an inherit-only one, and leave inherited entries and the owner untouched' {
            $folders = foreach ($name in 'ClearPipeFirst', 'ClearPipeSecond') {
                $folder = New-TestSandboxItem -Sandbox $sandbox -Name $name -Directory
                Add-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly -ErrorAction Stop
                Add-NTFSAccess -Path $folder -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo SubfoldersAndFilesOnly -ErrorAction Stop
                $folder
            }
            $before = foreach ($folder in $folders) {
                $acl = Get-Acl -LiteralPath $folder
                [pscustomobject]@{ Path = $folder; Owner = $acl.GetOwner($sidType).Value; Inherited = @($acl.GetAccessRules($false, $true, $sidType)).Count }
            }
            foreach ($state in $before) {
                $state.Inherited | Should -BeGreaterThan 0
            }

            Get-Item2 -Path $folders | Clear-NTFSAccess -ErrorAction Stop

            foreach ($state in $before) {
                $acl = Get-Acl -LiteralPath $state.Path
                @($acl.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
                @($acl.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $state.Inherited
                $acl.AreAccessRulesProtected | Should -BeFalse
                $acl.GetOwner($sidType).Value | Should -Be $state.Owner
            }
        }
    }

    Context 'Path parameter set errors' {
        BeforeAll {
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It 'Should report a missing path''s ReadFileError and a blocked path''s ClearAclError, each by category and target' {
            $missing = Join-Path -Path $sandbox -ChildPath ('ClearMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing

            Clear-NTFSAccess -Path $missing -ErrorVariable missingErrors -ErrorAction SilentlyContinue

            $missingErrors | Should -HaveCount 1
            $missingErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $missingErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $missingErrors[0].TargetObject | Should -Be $missing

            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'ClearBlocked'
            Block-TestWritePermission -Sandbox $sandbox -Path $blocked
            $before = (Get-Acl -LiteralPath $blocked).Sddl

            Clear-NTFSAccess -Path $blocked -ErrorVariable blockedErrors -ErrorAction SilentlyContinue

            $blockedErrors | Should -HaveCount 1
            $blockedErrors[0].FullyQualifiedErrorId | Should -BeLike 'ClearAclError,*'
            $blockedErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $blockedErrors[0].TargetObject | Should -Be $blocked
            (Get-Acl -LiteralPath $blocked).Sddl | Should -BeExactly $before
        }
    }

    Context 'SD parameter set bound through the pipeline' {
        It 'Should clear each piped descriptor''s explicit entries in memory, leave the items unchanged until Set-NTFSSecurityDescriptor, and keep the owner' {
            $files = foreach ($name in 'ClearSdFirst', 'ClearSdSecond') {
                $file = New-TestSandboxItem -Sandbox $sandbox -Name $name
                Add-NTFSAccess -Path $file -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
                $file
            }
            $before = foreach ($file in $files) {
                $acl = Get-Acl -LiteralPath $file
                [pscustomobject]@{ Path = $file; Owner = $acl.GetOwner($sidType).Value; Inherited = @($acl.GetAccessRules($false, $true, $sidType)).Count; Sddl = $acl.Sddl }
            }

            $descriptors = @(Get-NTFSSecurityDescriptor -Path $files -ErrorAction Stop)
            $descriptors | Clear-NTFSAccess -ErrorAction Stop

            for ($index = 0; $index -lt $descriptors.Count; $index++) {
                $sd = $descriptors[$index]
                $state = $before[$index]
                @($sd.SecurityDescriptor.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
                @($sd.SecurityDescriptor.GetAccessRules($false, $true, $sidType)) | Should -HaveCount $state.Inherited
                $sd.SecurityDescriptor.AreAccessRulesProtected | Should -BeFalse
                (Get-Acl -LiteralPath $state.Path).Sddl | Should -BeExactly $state.Sddl
            }

            Set-NTFSSecurityDescriptor -SecurityDescriptor $descriptors -ErrorAction Stop

            foreach ($state in $before) {
                $acl = Get-Acl -LiteralPath $state.Path
                @($acl.GetAccessRules($true, $false, $sidType)) | Should -BeNullOrEmpty
                $acl.GetOwner($sidType).Value | Should -Be $state.Owner
            }
        }
    }
}

Describe 'Get-NTFSAccess' {
    Context 'Path parameter set' {
        It 'Should return the same entries for a folder bound through the pipeline and by position, and report a missing path''s error by category and target' {
            $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAccessPositionParent' -Directory
            Add-NTFSAccess -Path $parent -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            $child = Join-Path -Path $parent -ChildPath 'Child'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            New-Item -ItemType Directory -Path $child | Out-Null
            $expected = @(Get-NTFSAccess -Path $child -ErrorAction Stop | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.IsInherited })

            $pipedResult = @(Get-Item2 -Path $child | Get-NTFSAccess -ErrorAction Stop)
            $positionalFolder = Get-ChildItem -LiteralPath $parent -Directory
            $positionalResult = @(Get-NTFSAccess $positionalFolder -ErrorAction Stop)

            ($pipedResult | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.IsInherited }) -join ';' | Should -Be ($expected -join ';')
            $pipedResult | ForEach-Object -Process { $_.FullName | Should -Be $child }
            ($positionalResult | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Account.Sid, $_.AccessRights, $_.IsInherited }) -join ';' | Should -Be ($expected -join ';')
            $positionalResult | ForEach-Object -Process { $_.FullName | Should -Be $child }

            $missing = Join-Path -Path $sandbox -ChildPath ('GetAccessMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing

            Get-NTFSAccess -Path $missing -ErrorVariable getErrors -ErrorAction SilentlyContinue

            $getErrors | Should -HaveCount 1
            $getErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $getErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $getErrors[0].TargetObject | Should -Be $missing
        }
    }

    Context 'Path parameter set without -Path' {
        It 'Should return the entries of the current location as actual Security2.FileSystemAccessRule2 objects when -Path is omitted' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAccessNoPath' -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            $expected = @(Get-NTFSAccess -Path $folder -ErrorAction Stop)

            Push-Location -LiteralPath $folder
            try {
                $result = @(Get-NTFSAccess -ErrorAction Stop)
            }
            finally {
                Pop-Location
            }

            $result | Should -HaveCount $expected.Count
            $result | ForEach-Object -Process {
                $_ | Should -BeOfType ([Security2.FileSystemAccessRule2])
                $_.FullName | Should -Be $folder
            }
            @($result | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' -and -not $_.IsInherited }) | Should -HaveCount 1
        }
    }

    Context 'SD parameter set' {
        It 'Should filter an entry added to a descriptor in memory by -Account, partition it with -ExcludeInherited and -ExcludeExplicit, and read two descriptors bound through the pipeline' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAccessSdFilter'
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            Add-NTFSAccess -SecurityDescriptor $sd -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop

            $bySd = @(Get-NTFSAccess -SecurityDescriptor $sd -Account 'S-1-1-0' -ErrorAction Stop)
            $byPath = @(Get-NTFSAccess -Path $file -Account 'S-1-1-0' -ErrorAction Stop)
            $bySd | Should -HaveCount 1
            $bySd[0].IsInherited | Should -BeFalse
            $byPath | Should -BeNullOrEmpty
            $explicitOnly = @(Get-NTFSAccess -SecurityDescriptor $sd -ExcludeInherited -ErrorAction Stop)
            @($explicitOnly | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' }) | Should -HaveCount 1
            $inheritedOnly = @(Get-NTFSAccess -SecurityDescriptor $sd -ExcludeExplicit -ErrorAction Stop)
            @($inheritedOnly | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' }) | Should -BeNullOrEmpty

            $file2 = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAccessSdFilter2'
            $expectedFirst = @(Get-NTFSAccess -Path $file -ErrorAction Stop).Count
            $expectedSecond = @(Get-NTFSAccess -Path $file2 -ErrorAction Stop).Count

            $piped = @(Get-NTFSSecurityDescriptor -Path $file, $file2 -ErrorAction Stop | Get-NTFSAccess -ErrorAction Stop)

            @($piped | Where-Object -FilterScript { $_.FullName -eq $file }) | Should -HaveCount $expectedFirst
            @($piped | Where-Object -FilterScript { $_.FullName -eq $file2 }) | Should -HaveCount $expectedSecond
        }
    }

    Context 'Path parameter set, unreadable folder' {
        BeforeAll {
            # Forcing EnablePrivileges off reproduces the same denial as a basic user for an elevated session, as
            # PathErrors.Tests.ps1 does for the same scenario, and as the Get-NTFSOrphanedAccess test below does.
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Get-NTFSAccess, Get-NTFSAudit, Get-NTFSEffectiveAccess, Get-NTFSInheritance, and Get-NTFSSecurityDescriptor
        # all report a failed ownership retry as ReadSecurityError categorized as WriteError (GetAccess.cs); this is
        # the module's convention. A characterization test: the behavior is already correct, only not yet pinned for
        # this cmdlet (6a). Unlike Get-NTFSOrphanedAccess, whose own category for the same failure is ReadError.
        It 'Should write a ReadSecurityError categorized as WriteError after a failed ownership retry, and still return the next path''s entries' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAccessUnreadable'
            Block-TestReadPermission -Sandbox $sandbox -Path $blocked
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'GetAccessUnreadableNext'
            Add-NTFSAccess -Path $next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop

            $result = @(Get-NTFSAccess -Path $blocked, $next -ErrorVariable accessErrors -ErrorAction SilentlyContinue)

            $accessErrors | Should -HaveCount 1
            $accessErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $accessErrors[0].CategoryInfo.Category | Should -Be 'WriteError'
            $accessErrors[0].TargetObject | Should -Be $blocked
            @($result | Where-Object -FilterScript { $_.FullName -eq $next -and $_.Account.Sid -eq 'S-1-1-0' -and -not $_.IsInherited }) | Should -HaveCount 1
        }
    }
}

Describe 'Get-NTFSOrphanedAccess' {
    Context 'Path parameter set' {
        It 'Should mark an orphaned entry explicit on its own folder and inherited on a child, partitioned by -ExcludeInherited and -ExcludeExplicit' {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedInheritableFolder' -Directory
            Add-NTFSAccess -Path $folder -Account 'S-1-5-21-1-2-3-9101' -AccessRights ReadData -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop
            $child = Join-Path -Path $folder -ChildPath 'Child.txt'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            Set-Content -LiteralPath $child -Value 'Child'

            $folderResult = @(Get-NTFSOrphanedAccess -Path $folder -ErrorAction Stop)
            $childResult = @(Get-NTFSOrphanedAccess -Path $child -ErrorAction Stop)

            $folderResult | Should -HaveCount 1
            $folderResult[0].IsInherited | Should -BeFalse
            $childResult | Should -HaveCount 1
            $childResult[0].IsInherited | Should -BeTrue
            @(Get-NTFSOrphanedAccess -Path $child -ExcludeInherited -ErrorAction Stop) | Should -BeNullOrEmpty
            @(Get-NTFSOrphanedAccess -Path $folder -ExcludeExplicit -ErrorAction Stop) | Should -BeNullOrEmpty
        }

        It 'Should write a ReadFileError for a missing path, still return the orphaned entry of the next path, and accept both bound through the pipeline' {
            $missing = Join-Path -Path $sandbox -ChildPath ('OrphanedMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $withOrphan = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedNext'
            Add-NTFSAccess -Path $withOrphan -Account 'S-1-5-21-1-2-3-9102' -AccessRights ReadData -ErrorAction Stop

            $result = @(Get-NTFSOrphanedAccess -Path $missing, $withOrphan -ErrorVariable orphanErrors -ErrorAction SilentlyContinue)

            $orphanErrors | Should -HaveCount 1
            $orphanErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $orphanErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $orphanErrors[0].TargetObject | Should -Be $missing
            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType ([Security2.FileSystemAccessRule2])
            $result[0].FullName | Should -Be $withOrphan
            "$($result[0].Account.Sid)" | Should -Be 'S-1-5-21-1-2-3-9102'

            $withOrphan2 = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedNext2'
            Add-NTFSAccess -Path $withOrphan2 -Account 'S-1-5-21-1-2-3-9103' -AccessRights ReadData -ErrorAction Stop

            $pipedResult = @(Get-Item2 -Path $withOrphan, $withOrphan2 | Get-NTFSOrphanedAccess -ErrorAction Stop)

            $pipedResult | Should -HaveCount 2
            @($pipedResult | Where-Object -FilterScript { $_.FullName -eq $withOrphan }) | Should -HaveCount 1
            @($pipedResult | Where-Object -FilterScript { $_.FullName -eq $withOrphan2 }) | Should -HaveCount 1
        }
    }

    Context 'Path parameter set, unreadable folder' {
        BeforeAll {
            # Forcing EnablePrivileges off reproduces the same denial as a basic user for an elevated session, as
            # PathErrors.Tests.ps1 does for the same scenario.
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        # Unlike Get-NTFSAccess, ReadSecurityError of this cmdlet has one consistent category after a failed
        # ownership retry: ReadError (GetOrphanedAccess.cs), so it is safe to pin.
        It 'Should write a ReadSecurityError categorized as ReadError after a failed ownership retry, and still return the next path''s orphaned entry' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedUnreadable'
            Block-TestReadPermission -Sandbox $sandbox -Path $blocked
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedUnreadableNext'
            Add-NTFSAccess -Path $next -Account 'S-1-5-21-1-2-3-9301' -AccessRights ReadData -ErrorAction Stop

            $result = @(Get-NTFSOrphanedAccess -Path $blocked, $next -ErrorVariable orphanErrors -ErrorAction SilentlyContinue)

            $orphanErrors | Should -HaveCount 1
            $orphanErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadSecurityError,*'
            $orphanErrors[0].CategoryInfo.Category | Should -Be 'ReadError'
            $orphanErrors[0].TargetObject | Should -Be $blocked
            $result | Should -HaveCount 1
            "$($result[0].Account.Sid)" | Should -Be 'S-1-5-21-1-2-3-9301'
        }
    }

    Context 'SD parameter set' {
        It 'Should filter a descriptor''s orphaned entries by -Account, report both orphaned Sids by default, exclude them all with -ExcludeExplicit, and read two descriptors bound through the pipeline' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedSdFile'
            Add-NTFSAccess -Path $file -Account 'S-1-5-21-1-2-3-9201' -AccessRights ReadData -ErrorAction Stop
            Add-NTFSAccess -Path $file -Account 'S-1-5-21-1-2-3-9202' -AccessRights ReadData -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            $filtered = @(Get-NTFSOrphanedAccess -SecurityDescriptor $sd -Account 'S-1-5-21-1-2-3-9202' -ErrorAction Stop)
            $default = @(Get-NTFSOrphanedAccess -SecurityDescriptor $sd -ErrorAction Stop)
            $excludeExplicit = @(Get-NTFSOrphanedAccess -SecurityDescriptor $sd -ExcludeExplicit -ErrorAction Stop)

            $filtered | Should -HaveCount 1
            "$($filtered[0].Account.Sid)" | Should -Be 'S-1-5-21-1-2-3-9202'
            ($default | ForEach-Object -Process { "$($_.Account.Sid)" } | Sort-Object) -join ',' | Should -Be (('S-1-5-21-1-2-3-9201', 'S-1-5-21-1-2-3-9202' | Sort-Object) -join ',')
            $excludeExplicit | Should -BeNullOrEmpty

            $file2 = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedSdFile2'
            Add-NTFSAccess -Path $file2 -Account 'S-1-5-21-1-2-3-9203' -AccessRights ReadData -ErrorAction Stop

            $piped = @(Get-NTFSSecurityDescriptor -Path $file, $file2 -ErrorAction Stop | Get-NTFSOrphanedAccess -ErrorAction Stop)

            @($piped | Where-Object -FilterScript { $_.FullName -eq $file }) | Should -HaveCount 2
            @($piped | Where-Object -FilterScript { $_.FullName -eq $file2 }) | Should -HaveCount 1
        }
    }

    Context 'SD parameter set, -ExcludeInherited and an in-memory change' {
        It 'Should return the explicit entry with -ExcludeInherited and still report an entry added to the descriptor only in memory' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'OrphanedSdMemory'
            Add-NTFSAccess -Path $file -Account 'S-1-5-21-1-2-3-9401' -AccessRights ReadData -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            $explicitOnly = @(Get-NTFSOrphanedAccess -SecurityDescriptor $sd -ExcludeInherited -ErrorAction Stop)

            $explicitOnly | Should -HaveCount 1
            "$($explicitOnly[0].Account.Sid)" | Should -Be 'S-1-5-21-1-2-3-9401'

            Add-NTFSAccess -SecurityDescriptor $sd -Account 'S-1-5-21-1-2-3-9402' -AccessRights ReadData -ErrorAction Stop

            $afterMemoryChange = @(Get-NTFSOrphanedAccess -SecurityDescriptor $sd -ErrorAction Stop)

            ($afterMemoryChange | ForEach-Object -Process { "$($_.Account.Sid)" } | Sort-Object) -join ',' |
                Should -Be (('S-1-5-21-1-2-3-9401', 'S-1-5-21-1-2-3-9402' | Sort-Object) -join ',')
            # The disk copy stays as it was: only the descriptor in memory saw the second account.
            @(Get-NTFSOrphanedAccess -Path $file -ErrorAction Stop) | Should -HaveCount 1
        }
    }
}

Describe 'Get-NTFSSimpleAccess' {
    Context 'Path parameter set, unreadable folder' {
        BeforeAll {
            # Without this, an elevated session auto-enables the Backup privilege in BeginProcessing (every
            # BaseCmdletWithPrivControl cmdlet does, see EnableFileSystemPrivileges) and that alone, with no retry
            # logic in this cmdlet, bypasses the owner-rights read denial below; forcing it off reproduces the same
            # denial as a basic user, like PathErrors.Tests.ps1 does for its own read-denial cases.
            $privateData['EnablePrivileges'] = $false
        }

        AfterAll {
            $privateData['EnablePrivileges'] = $enablePrivileges
        }

        It 'Should report an unreadable folder''s error by category and target and still report the next folder''s entries' {
            $blocked = New-TestSandboxItem -Sandbox $sandbox -Name 'SimpleBlocked' -Directory
            Block-TestReadPermission -Sandbox $sandbox -Path $blocked
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'SimpleNext' -Directory
            Add-NTFSAccess -Path $next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop

            $result = @(Get-NTFSSimpleAccess -Path $blocked, $next -IncludeRootFolder:$false -ErrorVariable simpleErrors -ErrorAction SilentlyContinue)

            $simpleErrors | Should -HaveCount 1
            $simpleErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadError,*'
            $simpleErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $simpleErrors[0].TargetObject | Should -Be $blocked
            @($result | Where-Object -FilterScript { $_.FullName -eq $blocked }) | Should -BeNullOrEmpty
            @($result | Where-Object -FilterScript { $_.FullName -eq $next }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Path parameter set, missing path' {
        # Unlike the unreadable-folder case above, a missing path needs no retry and no privilege change: this cmdlet
        # does not retry as the owner, so the ReadError of a missing path was pinned by ErrorId only until now.
        It 'Should report a missing path''s error by category and target and still report the next folder''s entries' {
            $missing = Join-Path -Path $sandbox -ChildPath ('SimpleMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'SimpleMissingNext' -Directory
            Add-NTFSAccess -Path $next -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop

            $result = @(Get-NTFSSimpleAccess -Path $missing, $next -IncludeRootFolder:$false -ErrorVariable simpleErrors -ErrorAction SilentlyContinue)

            $simpleErrors | Should -HaveCount 1
            $simpleErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadError,*'
            $simpleErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $simpleErrors[0].TargetObject | Should -Be $missing
            @($result | Where-Object -FilterScript { $_.FullName -eq $next }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SD parameter set' {
        It 'Should filter and partition a descriptor''s entries like the equivalent -Path call, and read two descriptors bound through the pipeline' {
            $parent = New-TestSandboxItem -Sandbox $sandbox -Name 'SimpleSdParent' -Directory
            Add-NTFSAccess -Path $parent -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo ThisFolderSubfoldersAndFiles -ErrorAction Stop
            $child = Join-Path -Path $parent -ChildPath 'Child'
            Assert-TestSandboxPath -Sandbox $sandbox -Path $child
            New-Item -ItemType Directory -Path $child | Out-Null
            Add-NTFSAccess -Path $child -Account 'S-1-1-0' -AccessRights ReadData -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $child -ErrorAction Stop

            $bySd = @(Get-NTFSSimpleAccess -SecurityDescriptor $sd -ErrorAction Stop)
            $byPath = @(Get-NTFSSimpleAccess -Path $child -IncludeRootFolder:$false -ErrorAction Stop)
            (($bySd | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Identity.Sid, $_.AccessRights, $_.AccessControlType }) | Sort-Object) -join ';' |
                Should -Be ((($byPath | ForEach-Object -Process { '{0}|{1}|{2}' -f $_.Identity.Sid, $_.AccessRights, $_.AccessControlType }) | Sort-Object) -join ';')

            $filtered = @(Get-NTFSSimpleAccess -SecurityDescriptor $sd -Account 'S-1-1-0' -ErrorAction Stop)
            $filtered | Should -HaveCount 1
            $explicitOnly = @(Get-NTFSSimpleAccess -SecurityDescriptor $sd -ExcludeInherited -ErrorAction Stop)
            $inheritedOnly = @(Get-NTFSSimpleAccess -SecurityDescriptor $sd -ExcludeExplicit -ErrorAction Stop)
            ($explicitOnly.Count + $inheritedOnly.Count) | Should -Be $bySd.Count
            @($explicitOnly | Where-Object -FilterScript { $_.Identity.Sid -eq 'S-1-1-0' }) | Should -HaveCount 1
            @($inheritedOnly | Where-Object -FilterScript { $_.Identity.Sid -eq 'S-1-5-32-546' }) | Should -HaveCount 1

            $piped = @(Get-NTFSSecurityDescriptor -Path $child, $parent -ErrorAction Stop | Get-NTFSSimpleAccess -ErrorAction Stop)

            @($piped | Where-Object -FilterScript { $_.FullName -eq $child }) | Should -HaveCount $bySd.Count
            @($piped | Where-Object -FilterScript { $_.FullName -eq $parent }) | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-NTFSEffectiveAccess' {
    Context 'Path parameter set' {
        It 'Should report an allowed right as present and a denied right as absent for a protected DACL' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'EffectiveRights'
            Disable-NTFSAccessInheritance -Path $file -RemoveInheritedAccessRules -ErrorAction Stop
            Add-NTFSAccess -Path $file -Account $currentUser -AccessRights ReadData -ErrorAction Stop
            Add-NTFSAccess -Path $file -Account $currentUser -AccessRights WriteData -AccessType Deny -ErrorAction Stop

            $result = Get-NTFSEffectiveAccess -Path $file -WarningAction SilentlyContinue -ErrorAction Stop

            $result.AccessRights.HasFlag([Security2.FileSystemRights2]::ReadData) | Should -BeTrue
            $result.AccessRights.HasFlag([Security2.FileSystemRights2]::WriteData) | Should -BeFalse
        }

        It 'Should return one result per item bound through the pipeline, in order' {
            $first = New-TestSandboxItem -Sandbox $sandbox -Name 'EffectivePipeFirst'
            $second = New-TestSandboxItem -Sandbox $sandbox -Name 'EffectivePipeSecond'

            $result = @(Get-Item2 -Path $first, $second | Get-NTFSEffectiveAccess -Account 'S-1-5-32-546' -WarningAction SilentlyContinue -ErrorAction Stop)

            $result | Should -HaveCount 2
            $result[0].FullName | Should -Be $first
            $result[1].FullName | Should -Be $second
        }

        It 'Should write nothing for a missing path and only the succeeding path''s result in the same call' {
            $missing = Join-Path -Path $sandbox -ChildPath ('EffectiveMissing-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
            Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
            $next = New-TestSandboxItem -Sandbox $sandbox -Name 'EffectiveMissingNext'

            $result = @(Get-NTFSEffectiveAccess -Path $missing, $next -Account 'S-1-1-0' -WarningAction SilentlyContinue -ErrorVariable accessErrors -ErrorAction SilentlyContinue)

            $accessErrors | Should -HaveCount 1
            $accessErrors[0].FullyQualifiedErrorId | Should -BeLike 'ReadFileError,*'
            $accessErrors[0].CategoryInfo.Category | Should -Be 'OpenError'
            $accessErrors[0].TargetObject | Should -Be $missing
            $result | Should -HaveCount 1
            $result[0].FullName | Should -Be $next
        }
    }

    Context 'SecurityDescriptor parameter set' {
        It 'Should follow a descriptor changed only in memory while the -Path result stays on disk, and read two descriptors bound through the pipeline' {
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'EffectiveSdFile'
            Disable-NTFSAccessInheritance -Path $file -RemoveInheritedAccessRules -ErrorAction Stop
            Add-NTFSAccess -Path $file -Account $currentUser -AccessRights FullControl -ErrorAction Stop
            $sd = Get-NTFSSecurityDescriptor -Path $file -ErrorAction Stop

            $pathBefore = Get-NTFSEffectiveAccess -Path $file -WarningAction SilentlyContinue -ErrorAction Stop
            $sdBefore = Get-NTFSEffectiveAccess -SecurityDescriptor $sd -WarningAction SilentlyContinue -ErrorAction Stop
            $pathBefore.AccessRights.HasFlag([Security2.FileSystemRights2]::WriteData) | Should -BeTrue
            $sdBefore.AccessRights.HasFlag([Security2.FileSystemRights2]::WriteData) | Should -BeTrue

            Add-NTFSAccess -SecurityDescriptor $sd -Account $currentUser -AccessType Deny -AccessRights WriteData -ErrorAction Stop

            $sdAfter = Get-NTFSEffectiveAccess -SecurityDescriptor $sd -WarningAction SilentlyContinue -ErrorAction Stop
            $pathAfter = Get-NTFSEffectiveAccess -Path $file -WarningAction SilentlyContinue -ErrorAction Stop
            $sdAfter.AccessRights.HasFlag([Security2.FileSystemRights2]::WriteData) | Should -BeFalse
            $pathAfter.AccessRights.HasFlag([Security2.FileSystemRights2]::WriteData) | Should -BeTrue

            $file2 = New-TestSandboxItem -Sandbox $sandbox -Name 'EffectiveSdFile2'
            Disable-NTFSAccessInheritance -Path $file2 -RemoveInheritedAccessRules -ErrorAction Stop
            Add-NTFSAccess -Path $file2 -Account $currentUser -AccessRights FullControl -ErrorAction Stop

            $piped = @(Get-NTFSSecurityDescriptor -Path $file, $file2 -ErrorAction Stop | Get-NTFSEffectiveAccess -WarningAction SilentlyContinue -ErrorAction Stop)

            $piped | Should -HaveCount 2
        }
    }
}

Describe 'Declared output types and parameter set boundaries' {
    It '<Name> should declare <Types> as its output type' -ForEach $declaredOutputTypes {
        @((Get-Command -Name $Name).OutputType.Name) | Should -Be $Types
    }

    It '<_> should require -AppliesTo only in the Simple parameter sets, -InheritanceFlags/-PropagationFlags only in the Complex parameter sets, and reject combining -AppliesTo with -InheritanceFlags without changing the item' -ForEach @(
        'Add-NTFSAccess', 'Remove-NTFSAccess'
    ) {
        $parameterSets = (Get-Command -Name $_).ParameterSets

        foreach ($setName in 'PathSimple', 'SDSimple') {
            $parameterSet = $parameterSets | Where-Object -Property Name -EQ -Value $setName
            ($parameterSet.Parameters | Where-Object -Property Name -EQ -Value 'AppliesTo').IsMandatory | Should -BeTrue
            $parameterSet.Parameters.Name | Should -Not -Contain 'InheritanceFlags'
            $parameterSet.Parameters.Name | Should -Not -Contain 'PropagationFlags'
        }
        foreach ($setName in 'PathComplex', 'SDComplex') {
            $parameterSet = $parameterSets | Where-Object -Property Name -EQ -Value $setName
            $parameterSet.Parameters.Name | Should -Not -Contain 'AppliesTo'
            $parameterSet.Parameters.Name | Should -Contain 'InheritanceFlags'
            $parameterSet.Parameters.Name | Should -Contain 'PropagationFlags'
        }

        $file = New-TestSandboxItem -Sandbox $sandbox -Name ('Boundary{0}' -f $_.Replace('-', ''))
        $before = (Get-Acl -LiteralPath $file).Sddl

        { & $_ -Path $file -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly -InheritanceFlags None -ErrorAction Stop } |
            Should -Throw -ErrorId 'AmbiguousParameterSet*'

        (Get-Acl -LiteralPath $file).Sddl | Should -BeExactly $before
    }
}
