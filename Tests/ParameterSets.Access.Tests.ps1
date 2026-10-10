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

            # A plain object with an AppliesTo property does not steer the pipeline to PathSimple by itself: both
            # PathComplex (default) and PathSimple can bind the object's Path/Account/AccessRights, and the module
            # resolves the ambiguity to the default set, PathComplex, silently ignoring the unmatched AppliesTo
            # property (see the report). -AppliesTo named explicitly still selects PathSimple while -Path arrives
            # through the pipeline.
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'AddSimplePipedFolder' -Directory

            Get-Item2 -Path $folder | Add-NTFSAccess -Account 'S-1-5-32-546' -AccessRights ReadData -AppliesTo ThisFolderAndSubfolders -ErrorAction Stop

            $guestsRule = @((Get-Acl -LiteralPath $folder).GetAccessRules($true, $false, $sidType) | Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-5-32-546' })
            $guestsRule | Should -HaveCount 1
            $guestsRule[0].InheritanceFlags | Should -Be ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit)
            $guestsRule[0].PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
            $guestsRule[0].FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadData) | Should -BeTrue
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
