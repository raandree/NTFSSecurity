<#
    Tests the public object APIs used with cmdlet output, without changing an item's security descriptor.
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
    $sandbox = New-TestSandbox -Name 'ObjectApis'
    $objectPath = Join-Path -Path $sandbox -ChildPath 'Rule.txt'
    $identity = [Security2.IdentityReference2] 'S-1-1-0'
    $sid = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList 'S-1-1-0'
}

AfterAll {
    Remove-TestSandbox -Sandbox $sandbox
    Remove-Module -Name NTFSSecurity -Force -ErrorAction SilentlyContinue
}

Describe 'Rule constructors with a path' {
    It 'Should preserve the supplied path and name of an <Kind> rule' -ForEach @(
        @{ Kind = 'access' }
        @{ Kind = 'audit' }
    ) {
        if ($Kind -eq 'access') {
            $raw = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                $sid, [System.Security.AccessControl.FileSystemRights]::ReadData,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $rule = New-Object -TypeName 'Security2.FileSystemAccessRule2' -ArgumentList $raw, $objectPath
        }
        else {
            $raw = New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
                $sid, [System.Security.AccessControl.FileSystemRights]::ReadData,
                [System.Security.AccessControl.AuditFlags]::Success
            )
            $rule = New-Object -TypeName 'Security2.FileSystemAuditRule2' -ArgumentList $raw, $objectPath
        }

        $rule.FullName | Should -BeExactly $objectPath
        $rule.Name | Should -BeExactly 'Rule.txt'
        $rule.InheritanceEnabled = $true
        $rule.InheritedFrom = $sandbox
        $rule.InheritanceEnabled | Should -BeTrue
        $rule.InheritedFrom | Should -BeExactly $sandbox
        $rule.GetHashCode() | Should -Be $raw.GetHashCode()
    }
}

Describe 'Simplified audit entries' {
    It 'Should reduce <Rights> to <Expected>' -ForEach @(
        @{ Rights = 'None'; Expected = 'None' }
        @{ Rights = 'ReadData'; Expected = 'Read' }
        @{ Rights = 'Read'; Expected = 'Read' }
        @{ Rights = 'CreateFiles'; Expected = 'Write' }
        @{ Rights = 'AppendData'; Expected = 'Write' }
        @{ Rights = 'ReadExtendedAttributes'; Expected = 'Read' }
        @{ Rights = 'WriteExtendedAttributes'; Expected = 'Write' }
        @{ Rights = 'ExecuteFile'; Expected = 'Read' }
        @{ Rights = 'DeleteSubdirectoriesAndFiles'; Expected = 'Delete' }
        @{ Rights = 'ReadAttributes'; Expected = 'Read' }
        @{ Rights = 'WriteAttributes'; Expected = 'Write' }
        @{ Rights = 'Delete'; Expected = 'Delete' }
        @{ Rights = 'ReadPermissions'; Expected = 'Read' }
        @{ Rights = 'ChangePermissions'; Expected = 'Write' }
        @{ Rights = 'TakeOwnership'; Expected = 'Write' }
        @{ Rights = 'Synchronize'; Expected = 'Read' }
        @{ Rights = 'FullControl'; Expected = 'Read, Write, Delete' }
        @{ Rights = 'GenericRead'; Expected = 'Read' }
        @{ Rights = 'GenericWrite'; Expected = 'Write' }
        @{ Rights = 'GenericExecute'; Expected = 'Read' }
        @{ Rights = 'GenericAll'; Expected = 'Read, Write, Delete' }
    ) {
        $rule = New-Object -TypeName 'Security2.SimpleFileSystemAuditRule' -ArgumentList (
            $objectPath, $identity, [Security2.FileSystemRights2] $Rights
        )

        $rule.AccessRights | Should -Be ([Security2.SimpleFileSystemAccessRights] $Expected)
        $rule.FullName | Should -BeExactly $objectPath
        $rule.Name | Should -BeExactly 'Rule.txt'
        $rule.Identity.Sid | Should -BeExactly 'S-1-1-0'
    }

    It 'Should compare audit entries reflexively and symmetrically, never as access entries' {
        $first = New-Object -TypeName 'Security2.SimpleFileSystemAuditRule' -ArgumentList (
            $objectPath, $identity, [Security2.FileSystemRights2]::Read
        )
        $second = New-Object -TypeName 'Security2.SimpleFileSystemAuditRule' -ArgumentList (
            $objectPath, $identity, [Security2.FileSystemRights2]::Read
        )
        $access = New-Object -TypeName 'Security2.SimpleFileSystemAccessRule' -ArgumentList (
            $objectPath, $identity, [Security2.FileSystemRights2]::Read,
            [System.Security.AccessControl.AccessControlType]::Allow
        )

        $first.Equals($first) | Should -BeTrue
        $first.Equals($second) | Should -BeTrue
        $second.Equals($first) | Should -BeTrue
        $first.GetHashCode() | Should -Be $second.GetHashCode()
        $first.Equals($access) | Should -BeFalse
        $access.Equals($first) | Should -BeFalse
        $first.Equals($null) | Should -BeFalse
        $first.Equals('Read') | Should -BeFalse
        $second.AccessControlType = 'Deny'
        $first.Equals($second) | Should -BeFalse
    }

    It 'Should preserve the path, account and ReadData when converting an audit entry' {
        $raw = New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
            $sid, [System.Security.AccessControl.FileSystemRights]::ReadData,
            [System.Security.AccessControl.AuditFlags]::Success
        )
        $wrapped = New-Object -TypeName 'Security2.FileSystemAuditRule2' -ArgumentList $raw, $objectPath

        $simple = $wrapped.ToSimpleFileSystemAuditRule2()

        $simple.FullName | Should -BeExactly $objectPath
        $simple.Identity.Sid | Should -BeExactly 'S-1-1-0'
        $simple.AccessRights | Should -Be ([Security2.SimpleFileSystemAccessRights]::Read)
        $wrapped.ToString() | Should -BeExactly $raw.ToString()
    }
}

Describe 'Identity comparisons and conversions' {
    It 'Should compare <Value> with the identity by SID or resolved name' -ForEach @(
        @{ Value = 'self'; Expected = $true }
        @{ Value = 'same SID'; Expected = $true }
        @{ Value = 'different SID'; Expected = $false }
        @{ Value = 'SecurityIdentifier'; Expected = $true }
        @{ Value = 'NTAccount'; Expected = $true }
        @{ Value = 'SID string'; Expected = $true }
        @{ Value = 'account name'; Expected = $true }
        @{ Value = 'different string'; Expected = $false }
        @{ Value = 'null'; Expected = $false }
        @{ Value = 'other type'; Expected = $false }
    ) {
        $other = switch ($Value) {
            'self' { $identity }
            'same SID' { [Security2.IdentityReference2] 'S-1-1-0' }
            'different SID' { [Security2.IdentityReference2] 'S-1-5-32-546' }
            'SecurityIdentifier' { $sid }
            'NTAccount' { $sid.Translate([System.Security.Principal.NTAccount]) }
            'SID string' { 'S-1-1-0' }
            'account name' { $identity.AccountName.ToUpperInvariant() }
            'different string' { 'NTFSSecurity-not-an-account' }
            'null' { $null }
            'other type' { 42 }
        }

        $identity.Equals($other) | Should -Be $Expected
    }

    It 'Should compare null operands and distinct instances through both operators' {
        $same = [Security2.IdentityReference2] 'S-1-1-0'
        $different = [Security2.IdentityReference2] 'S-1-5-32-546'

        [Security2.IdentityReference2]::op_Equality($null, $null) | Should -BeTrue
        [Security2.IdentityReference2]::op_Equality($identity, $null) | Should -BeFalse
        [Security2.IdentityReference2]::op_Equality($null, $identity) | Should -BeFalse
        [Security2.IdentityReference2]::op_Equality($identity, $same) | Should -BeTrue
        [Security2.IdentityReference2]::op_Inequality($identity, $identity) | Should -BeFalse
        [Security2.IdentityReference2]::op_Inequality($identity, $null) | Should -BeTrue
        [Security2.IdentityReference2]::op_Inequality($null, $identity) | Should -BeTrue
        [Security2.IdentityReference2]::op_Inequality($identity, $different) | Should -BeTrue
        [Security2.IdentityReference2]::op_Inequality($identity, $same) | Should -BeFalse
        $identity.GetHashCode() | Should -Be $same.GetHashCode()
    }

    It 'Should round-trip native identities and the binary SID without changing the account' {
        $account = $sid.Translate([System.Security.Principal.NTAccount])
        $fromSid = [Security2.IdentityReference2]::op_Explicit($sid)
        $fromAccount = [Security2.IdentityReference2]::op_Explicit($account)

        $fromSid.Sid | Should -BeExactly 'S-1-1-0'
        $fromAccount.Sid | Should -BeExactly $fromSid.Sid
        ([System.Security.Principal.SecurityIdentifier] $fromSid).Value | Should -BeExactly 'S-1-1-0'
        ([System.Security.Principal.NTAccount] $fromAccount).Value | Should -BeExactly $account.Value
        $binarySid = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList (
            $fromSid.GetBinaryForm(), 0
        )
        $binarySid.Value | Should -BeExactly 'S-1-1-0'
    }
}

Describe 'Unrepresentable inheritance flags' {
    It 'Should reject propagation flags without inheritance instead of inventing an AppliesTo value' {
        $failure = $null
        try {
            $null = [Security2.FileSystemSecurity2]::ConvertToApplyTo('None', 'InheritOnly')
        }
        catch {
            $failure = $_.Exception.GetBaseException()
        }

        $failure | Should -BeOfType [Security2.RightsConverionException]
        $failure.Message | Should -BeExactly 'The combination of InheritanceFlags and PropagationFlags could not be translated'
    }
}
Describe 'Privilege output comparisons and formatting' {
    It 'Should compare boxed and typed privilege values consistently without accepting an attributes enum' {
        $values = @(Get-Privileges)
        $values.Count | Should -BeGreaterThan 0
        $first = $values[0].PSObject.BaseObject
        $copy = $values[0].PSObject.BaseObject
        # PowerShell prefers the typed overload; reflection selects the public boxed-object contract explicitly.
        $equalsObject = [ProcessPrivileges.PrivilegeAndAttributes].GetMethod('Equals', [type[]] @([object]))

        $equalsObject.Invoke($first, [object[]] @($copy)) | Should -BeTrue
        $first.Equals($copy) | Should -BeTrue
        [ProcessPrivileges.PrivilegeAndAttributes]::op_Equality($first, $copy) | Should -BeTrue
        [ProcessPrivileges.PrivilegeAndAttributes]::op_Inequality($first, $copy) | Should -BeFalse
        $first.GetHashCode() | Should -Be $copy.GetHashCode()
        $equalsObject.Invoke($first, [object[]] @($null)) | Should -BeFalse
        $equalsObject.Invoke($first, [object[]] @('Backup')) | Should -BeFalse
        $equalsObject.Invoke($first, [object[]] @([ProcessPrivileges.PrivilegeAttributes]::Disabled)) | Should -BeFalse
    }

    It 'Should format the collection with one aligned privilege and attributes row per value' {
        $control = New-Object -TypeName 'Security2.PrivilegeControl'
        $values = $control.GetPrivileges()
        $expectedWidth = ($values | ForEach-Object { $_.Privilege.ToString().Length } | Measure-Object -Maximum).Maximum

        $text = $values.ToString()

        $rows = @($text.TrimEnd("`r", "`n") -split '\r?\n')
        $rows | Should -HaveCount $values.Count
        for ($index = 0; $index -lt $values.Count; $index++) {
            $value = $values[$index]
            $rows[$index] | Should -BeExactly ('{0} => {1}' -f $value.Privilege.ToString().PadRight($expectedWidth),
                $value.PrivilegeAttributes)
        }
    }
}

Describe 'Legacy effective-permission output objects' {
    It 'Should retain a <Mask> mask and report the supplied path and identity without a native access check' -ForEach @(
        @{ Mask = 0; ObjectName = 'Effective.txt' }
        @{ Mask = 1; ObjectName = 'Effective.txt' }
        @{ Mask = 3; ObjectName = $null }
    ) {
        $path = if ($ObjectName) { Join-Path -Path $sandbox -ChildPath $ObjectName } else { $null }
        $entry = New-Object -TypeName 'Security2.FileSystemEffectivePermissionEntry' -ArgumentList (
            $identity, [uint32] $Mask, $path
        )

        $entry.Account.Sid | Should -BeExactly 'S-1-1-0'
        $entry.AccessMask | Should -Be $Mask
        [int] $entry.AccessRights | Should -Be $Mask
        $entry.FullName | Should -BeExactly ([string] $path)
        $entry.Name | Should -BeExactly $ObjectName
        $entry.AccessAsString | Should -Not -BeNullOrEmpty
        if ($Mask -eq 0) {
            $entry.AccessAsString | Should -Be @('None')
        }
        else {
            $entry.AccessAsString | Should -Not -Contain 'None'
        }
    }
}
Describe 'Simplified entry comparison branches' {
    It 'Should distinguish identities, rights and types in <Kind> entries and keep equal hashes consistent' -ForEach @(
        @{ Kind = 'access' }
        @{ Kind = 'audit' }
    ) {
        $typeName = if ($Kind -eq 'access') { 'Security2.SimpleFileSystemAccessRule' } else { 'Security2.SimpleFileSystemAuditRule' }
        $arguments = @($objectPath, $identity, [Security2.FileSystemRights2]::Read)
        if ($Kind -eq 'access') { $arguments += [System.Security.AccessControl.AccessControlType]::Allow }
        $first = New-Object -TypeName $typeName -ArgumentList $arguments
        $equal = New-Object -TypeName $typeName -ArgumentList $arguments
        $arguments[1] = [Security2.IdentityReference2] 'S-1-5-32-546'
        $differentIdentity = New-Object -TypeName $typeName -ArgumentList $arguments
        $arguments[1] = $identity
        $arguments[2] = [Security2.FileSystemRights2]::Delete
        $differentRights = New-Object -TypeName $typeName -ArgumentList $arguments

        $first.Equals($equal) | Should -BeTrue
        $first.GetHashCode() | Should -Be $equal.GetHashCode()
        $first.Equals($differentIdentity) | Should -BeFalse
        $first.Equals($differentRights) | Should -BeFalse
        $first.Equals($null) | Should -BeFalse
        $equal.AccessControlType = 'Deny'
        $first.Equals($equal) | Should -BeFalse
        $first.Name | Should -BeExactly 'Rule.txt'
    }

    It 'Should reduce the generic <Rights> mask in access entries' -ForEach @(
        @{ Rights = 'GenericRead'; Expected = 'Read' }
        @{ Rights = 'GenericWrite'; Expected = 'Write' }
        @{ Rights = 'GenericExecute'; Expected = 'Read' }
        @{ Rights = 'GenericAll'; Expected = 'Read, Write, Delete' }
    ) {
        $entry = New-Object -TypeName 'Security2.SimpleFileSystemAccessRule' -ArgumentList (
            $objectPath, $identity, [Security2.FileSystemRights2] $Rights,
            [System.Security.AccessControl.AccessControlType]::Allow
        )

        $entry.AccessRights | Should -Be ([Security2.SimpleFileSystemAccessRights] $Expected)
    }

    It 'Should convert an identity implicitly to its resolved display name and reject an unresolved name' {
        $conversion = [Security2.IdentityReference2].GetMethods([Reflection.BindingFlags] 'Public, Static') |
            Where-Object { $_.Name -eq 'op_Implicit' -and $_.ReturnType -eq [string] }
        $conversion.Invoke($null, [object[]] @($identity.PSObject.BaseObject)) | Should -BeExactly $identity.ToString()
        $unresolved = [Security2.IdentityReference2] 'S-1-5-21-1-2-3-1001'
        $unresolved.Equals('Not-resolved') | Should -BeFalse
        $identity.Equals($identity.AccountName) | Should -BeTrue
    }

    It 'Should compare different privilege values as unequal' {
        $constructor = [ProcessPrivileges.PrivilegeAndAttributes].GetConstructor(
            [Reflection.BindingFlags] 'NonPublic, Instance', $null,
            [type[]] @([ProcessPrivileges.Privilege], [ProcessPrivileges.PrivilegeAttributes]), $null
        )
        $first = $constructor.Invoke(@([ProcessPrivileges.Privilege]::Backup, [ProcessPrivileges.PrivilegeAttributes]::Disabled))
        $different = $constructor.Invoke(@([ProcessPrivileges.Privilege]::Restore, [ProcessPrivileges.PrivilegeAttributes]::Disabled))

        $first.Equals($different) | Should -BeFalse
        [ProcessPrivileges.PrivilegeAndAttributes]::op_Inequality($first, $different) | Should -BeTrue
    }
}

Describe 'Access rule helpers that take a path' {
    BeforeAll {
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $noInheritance = [System.Security.AccessControl.InheritanceFlags]::None
        $noPropagation = [System.Security.AccessControl.PropagationFlags]::None
        $users = [Security2.IdentityReference2] 'S-1-5-32-545'

        function Get-ExplicitEntries {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseSingularNouns', '', Justification = 'The helper returns the explicit entries of an item.'
            )]
            param ([string] $Path, [string] $Account = 'S-1-1-0')

            $acl = Get-Acl -LiteralPath $Path
            @($acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq $Account })
        }

        function New-AccountList {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only creates a list.'
            )]
            param ()

            $accounts = New-Object -TypeName 'System.Collections.Generic.List[Security2.IdentityReference2]'
            $accounts.Add($identity)
            $accounts.Add($users)
            , $accounts
        }
    }

    It 'Should add an allow entry with Synchronize to a <Kind> by its path' -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AddByPath' -Directory:$Directory

        $rule = [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation
        )

        $rule.Account.Sid | Should -BeExactly 'S-1-1-0'
        $entries = @(Get-ExplicitEntries -Path $path)
        $entries | Should -HaveCount 1
        $entries[0].AccessControlType | Should -Be 'Allow'
        $entries[0].FileSystemRights | Should -Be ([System.Security.AccessControl.FileSystemRights] 'ReadData, Synchronize')
    }

    # The overload for several accounts is an iterator, so it writes nothing until the caller enumerates the result.
    It 'Should add the entries of several accounts to a <Kind> by its path only when the result is enumerated' -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AddListByPath' -Directory:$Directory
        $accounts = New-AccountList

        $pending = [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
            $path, $accounts, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation
        )

        @(Get-ExplicitEntries -Path $path) | Should -BeNullOrEmpty
        @(Get-ExplicitEntries -Path $path -Account 'S-1-5-32-545') | Should -BeNullOrEmpty
        @($pending) | Should -HaveCount 2
        @(Get-ExplicitEntries -Path $path) | Should -HaveCount 1
        @(Get-ExplicitEntries -Path $path -Account 'S-1-5-32-545') | Should -HaveCount 1
    }

    It 'Should add the deny entries of several accounts without Synchronize when the result is enumerated' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'DenyListByPath'
        $accounts = New-AccountList
        $deny = [System.Security.AccessControl.AccessControlType]::Deny

        @([Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
                $path, $accounts, [Security2.FileSystemRights2]::ReadData, $deny, $noInheritance, $noPropagation
            )) | Should -HaveCount 2

        foreach ($account in 'S-1-1-0', 'S-1-5-32-545') {
            $entries = @(Get-ExplicitEntries -Path $path -Account $account)
            $entries | Should -HaveCount 1
            $entries[0].AccessControlType | Should -Be 'Deny'
            $entries[0].FileSystemRights | Should -Be ([System.Security.AccessControl.FileSystemRights]::ReadData)
        }
    }

    It 'Should add and remove a deny entry by its path without adding Synchronize' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'DenyByPath'
        $deny = [System.Security.AccessControl.AccessControlType]::Deny

        [void] [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::ReadData, $deny, $noInheritance, $noPropagation
        )

        $entries = @(Get-ExplicitEntries -Path $path)
        $entries | Should -HaveCount 1
        $entries[0].AccessControlType | Should -Be 'Deny'
        $entries[0].FileSystemRights | Should -Be ([System.Security.AccessControl.FileSystemRights]::ReadData)

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::ReadData, $deny, $noInheritance, $noPropagation
        )

        @(Get-ExplicitEntries -Path $path) | Should -BeNullOrEmpty
    }

    It 'Should return no entries for an empty DACL when the sources of inherited entries are requested' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'EmptyDacl'
        Clear-NTFSAccess -Path $path -DisableInheritance -ErrorAction Stop

        $rules = @([Security2.FileSystemAccessRule2]::GetFileSystemAccessRules($path, $true, $true, $true))

        $rules | Should -BeNullOrEmpty
    }

    It 'Should add the entry of a rule that carries its path' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AddRule'
        $raw = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
            $sid, [System.Security.AccessControl.FileSystemRights]::ReadData, $allow
        )
        $rule = New-Object -TypeName 'Security2.FileSystemAccessRule2' -ArgumentList $raw, $path

        [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule($rule)

        @(Get-ExplicitEntries -Path $path) | Should -HaveCount 1
    }

    # RemoveSpecific removes only an entry that matches exactly; without it, Windows removes the named rights from the
    # matching entry.
    It 'Should remove only an exactly matching entry of a <Kind> with removeSpecific and the named rights without it' -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveByPath' -Directory:$Directory
        [void] [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2] 'ReadData, WriteData', $allow, $noInheritance, $noPropagation
        )

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation, $true
        )
        @(Get-ExplicitEntries -Path $path)[0].FileSystemRights |
            Should -Be ([System.Security.AccessControl.FileSystemRights] 'ReadData, WriteData, Synchronize')

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation, $false
        )
        @(Get-ExplicitEntries -Path $path)[0].FileSystemRights |
            Should -Be ([System.Security.AccessControl.FileSystemRights] 'WriteData, Synchronize')

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::WriteData, $allow, $noInheritance, $noPropagation, $true
        )
        @(Get-ExplicitEntries -Path $path) | Should -BeNullOrEmpty
    }

    It 'Should remove the entries of several accounts of a <Kind> by path' -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveListByPath' -Directory:$Directory
        $accounts = New-AccountList
        @([Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
                $path, $accounts, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation
            )) | Should -HaveCount 2

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRule(
            $path, $accounts, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation, $false
        )

        @(Get-ExplicitEntries -Path $path) | Should -BeNullOrEmpty
        @(Get-ExplicitEntries -Path $path -Account 'S-1-5-32-545') | Should -BeNullOrEmpty
    }

    It 'Should remove the entry that a rule object describes from an item' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveRuleObject'
        [void] [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation
        )
        $raw = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
            $sid, [System.Security.AccessControl.FileSystemRights]::ReadData, $allow
        )
        $item = New-Object -TypeName 'Alphaleonis.Win32.Filesystem.FileInfo' -ArgumentList $path

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRule($item, $raw, $false)

        @(Get-ExplicitEntries -Path $path) | Should -BeNullOrEmpty
    }

    It 'Should return the explicit entries of a folder, and its inherited ones when asked, by its path' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'GetByPath' -Directory
        [void] [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
            $path, $identity, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation
        )

        $explicit = @([Security2.FileSystemAccessRule2]::GetFileSystemAccessRules($path, $true, $false, $false))
        $all = @([Security2.FileSystemAccessRule2]::GetFileSystemAccessRules($path, $true, $true, $true))

        $explicit | Should -HaveCount 1
        $explicit[0].Account.Sid | Should -BeExactly 'S-1-1-0'
        $all.Count | Should -BeGreaterThan 1
        @($all | Where-Object -FilterScript { $_.Account.Sid -eq 'S-1-1-0' }) | Should -HaveCount 1
    }
}

Describe 'Audit rule helpers that take a path' -Skip:(-not $holdsSecurityPrivilege) {
    BeforeAll {
        $success = [System.Security.AccessControl.AuditFlags]::Success
        $noInheritance = [System.Security.AccessControl.InheritanceFlags]::None
        $noPropagation = [System.Security.AccessControl.PropagationFlags]::None
        $users = [Security2.IdentityReference2] 'S-1-5-32-545'

        function Get-AuditEntries {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseSingularNouns', '', Justification = 'The helper returns the audit entries of an item.'
            )]
            param ([string] $Path, [string] $Account = 'S-1-1-0')

            $descriptor = Get-NTFSSecurityDescriptor -Path $Path
            @($descriptor.SecurityDescriptor.GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq $Account })
        }
    }

    It 'Should add an audit entry to a <Kind> by its path' -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditByPath' -Directory:$Directory

        $rule = [Security2.FileSystemAuditRule2]::AddFileSystemAuditRule(
            $path, $identity, [Security2.FileSystemRights2]::Delete, $success, $noInheritance, $noPropagation
        )

        $rule.Account.Sid | Should -BeExactly 'S-1-1-0'
        $entries = @(Get-AuditEntries -Path $path)
        $entries | Should -HaveCount 1
        $entries[0].AuditFlags | Should -Be 'Success'
        $entries[0].FileSystemRights | Should -Be ([System.Security.AccessControl.FileSystemRights]::Delete)
    }

    It 'Should add the entries of several accounts to a <Kind> by its path only when the result is enumerated, and remove them again' -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditListByPath' -Directory:$Directory
        $accounts = New-Object -TypeName 'System.Collections.Generic.List[Security2.IdentityReference2]'
        $accounts.Add($identity)
        $accounts.Add($users)

        $pending = [Security2.FileSystemAuditRule2]::AddFileSystemAuditRule(
            $path, $accounts, [Security2.FileSystemRights2]::Delete, $success, $noInheritance, $noPropagation
        )

        @(Get-AuditEntries -Path $path) | Should -BeNullOrEmpty
        @($pending) | Should -HaveCount 2
        @(Get-AuditEntries -Path $path) | Should -HaveCount 1
        @(Get-AuditEntries -Path $path -Account 'S-1-5-32-545') | Should -HaveCount 1
        [Security2.FileSystemAuditRule2]::RemoveFileSystemAuditRule(
            $path, $identity, [Security2.FileSystemRights2]::Delete, $success, $noInheritance, $noPropagation, $true
        )
        @(Get-AuditEntries -Path $path) | Should -BeNullOrEmpty
        @(Get-AuditEntries -Path $path -Account 'S-1-5-32-545') | Should -HaveCount 1
        [Security2.FileSystemAuditRule2]::RemoveFileSystemAuditRule(
            $path, $users, [Security2.FileSystemRights2]::Delete, $success, $noInheritance, $noPropagation, $false
        )
        @(Get-AuditEntries -Path $path -Account 'S-1-5-32-545') | Should -BeNullOrEmpty
    }

    It 'Should name the item of a rule, replay it, read it by path, and remove it by its rule object' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditReplay'
        $raw = New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
            $sid, [System.Security.AccessControl.FileSystemRights]::Delete, $success
        )
        $item = New-Object -TypeName 'Alphaleonis.Win32.Filesystem.FileInfo' -ArgumentList $path
        $rule = New-Object -TypeName 'Security2.FileSystemAuditRule2' -ArgumentList $raw, $item
        $rule.FullName | Should -BeExactly $path
        $rule.Name | Should -BeExactly (Split-Path -Path $path -Leaf)

        [Security2.FileSystemAuditRule2]::AddFileSystemAuditRule($rule)

        @(Get-AuditEntries -Path $path) | Should -HaveCount 1
        $found = @([Security2.FileSystemAuditRule2]::GetFileSystemAuditRules($path, $true, $true))
        $found | Should -HaveCount 1
        $found[0].Account.Sid | Should -BeExactly 'S-1-1-0'
        [Security2.FileSystemAuditRule2]::RemoveFileSystemAuditRule($item, $raw)
        @(Get-AuditEntries -Path $path) | Should -BeNullOrEmpty
    }

    It 'Should remove a rule object from an item without audit entries and change nothing' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditNothing'
        $raw = New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
            $sid, [System.Security.AccessControl.FileSystemRights]::Delete, $success
        )
        $item = New-Object -TypeName 'Alphaleonis.Win32.Filesystem.FileInfo' -ArgumentList $path
        $before = (Get-Acl -LiteralPath $path).Sddl

        [Security2.FileSystemAuditRule2]::RemoveFileSystemAuditRule($item, $raw)

        (Get-Acl -LiteralPath $path).Sddl | Should -BeExactly $before
        @(Get-AuditEntries -Path $path) | Should -BeNullOrEmpty
    }
}

Describe 'Inheritance helpers that take a path' {
    It 'Should block and restore the access inheritance of a <Kind> by its path' -ForEach @(
        @{ Kind = 'file'; Directory = $false; Remove = $false }
        @{ Kind = 'folder'; Directory = $true; Remove = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritanceByPath' -Directory:$Directory
        $inherited = @((Get-Acl -LiteralPath $path).GetAccessRules($false, $true, [System.Security.Principal.SecurityIdentifier])).Count
        $inherited | Should -BeGreaterThan 0

        [Security2.FileSystemInheritanceInfo]::DisableAccessInheritance($path, $Remove)

        $acl = Get-Acl -LiteralPath $path
        $acl.AreAccessRulesProtected | Should -BeTrue
        @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])).Count |
            Should -Be $(if ($Remove) { 0 } else { $inherited })

        [Security2.FileSystemInheritanceInfo]::EnableAccessInheritance($path, $Remove)

        $acl = Get-Acl -LiteralPath $path
        $acl.AreAccessRulesProtected | Should -BeFalse
        @($acl.GetAccessRules($false, $true, [System.Security.Principal.SecurityIdentifier])).Count | Should -Be $inherited
    }

    It 'Should read the access inheritance of a file by its path and keep what the caller sets on the result' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'InheritanceInfo'

        $info = [Security2.FileSystemInheritanceInfo]::GetFileSystemInheritanceInfo($path)

        $info.AccessInheritanceEnabled | Should -BeTrue
        $info.Item.FullName | Should -BeExactly $path
        $info.AccessInheritanceEnabled = $false
        $info.AuditInheritanceEnabled = $true
        $info.Item = New-Object -TypeName 'Alphaleonis.Win32.Filesystem.FileInfo' -ArgumentList $path
        $info.AccessInheritanceEnabled | Should -BeFalse
        $info.AuditInheritanceEnabled | Should -BeTrue
        (Get-Acl -LiteralPath $path).AreAccessRulesProtected | Should -BeFalse
    }

    It 'Should block and restore the audit inheritance of a <Kind> by its path' -Skip:(-not $holdsSecurityPrivilege) -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AuditInheritanceByPath' -Directory:$Directory
        (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -BeTrue

        [Security2.FileSystemInheritanceInfo]::DisableAuditInheritance($path, $false)

        (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -BeFalse

        [Security2.FileSystemInheritanceInfo]::EnableAuditInheritance($path, $false)

        (Get-NTFSInheritance -Path $path).AuditInheritanceEnabled | Should -BeTrue
    }
}

Describe 'Owner and descriptor objects' {
    It 'Should name the item and the account of an owner object' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'OwnerObject'

        $owner = Get-NTFSOwner -Path $path

        $owner.Item.FullName | Should -BeExactly $path
        $owner.FullName | Should -BeExactly $path
        $owner.Account.Sid | Should -BeExactly $owner.Owner.Sid
    }

    It 'Should read the owner of a drive root also for a lowercase drive letter' {
        $root = [IO.Path]::GetPathRoot($sandbox)
        $expected = (Get-NTFSOwner -Path $root).Owner.Sid

        $owner = Get-NTFSOwner -Path $root.ToLowerInvariant()

        $owner.Owner.Sid | Should -BeExactly $expected
    }

    It 'Should name the item of a descriptor and write it to a folder by its path' {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorSource' -Directory
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorTarget' -Directory
        Add-NTFSAccess -Path $source -Account 'S-1-1-0' -AccessRights ReadData -AppliesTo ThisFolderOnly
        $descriptor = Get-NTFSSecurityDescriptor -Path $source

        $descriptor.Name | Should -BeExactly (Split-Path -Path $source -Leaf)
        $descriptor.Write([string] $target)

        @((Get-Acl -LiteralPath $target).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
    }

    It 'Should name the missing path when it writes a descriptor to an item that does not exist' {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'DescriptorMissingSource'
        $missing = Join-Path -Path $sandbox -ChildPath ('Missing-{0}' -f [guid]::NewGuid().ToString('N'))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing
        $descriptor = Get-NTFSSecurityDescriptor -Path $source

        $failure = { $descriptor.Write($missing) } | Should -Throw -PassThru

        $failure.Exception.GetBaseException() | Should -BeOfType [System.IO.FileNotFoundException]
        $failure.Exception.GetBaseException().FileName | Should -BeExactly $missing
    }

    It 'Should leave both flags unset for an AppliesTo value that no case names' {
        $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit
        $propagation = [System.Security.AccessControl.PropagationFlags]::InheritOnly

        [Security2.FileSystemSecurity2]::ConvertToFileSystemFlags(
            [Enum]::ToObject([Security2.ApplyTo], 99), [ref] $inheritance, [ref] $propagation
        )

        $inheritance | Should -Be 'None'
        $propagation | Should -Be 'None'
    }
}

Describe 'Generic access rights and identity errors' {
    It 'Should map the generic mask <Mask> to the file system rights <Expected>' -ForEach @(
        @{ Mask = '80000000'; Expected = '00120089' }
        @{ Mask = '40000000'; Expected = '00120116' }
        @{ Mask = '20000000'; Expected = '001200A0' }
        @{ Mask = '10000000'; Expected = '001F01FF' }
        @{ Mask = 'C0000000'; Expected = '0012019F' }
        @{ Mask = '80010000'; Expected = '00130089' }
        @{ Mask = '001F01FF'; Expected = '001F01FF' }
        @{ Mask = '00120089'; Expected = '00120089' }
        @{ Mask = '02000000'; Expected = '02000000' }
        @{ Mask = '82000000'; Expected = '02120089' }
        @{ Mask = '00000000'; Expected = '00000000' }
    ) {
        $rights = [Security2.FileSystemSecurity2]::MapGenericRightsToFileSystemRights([Convert]::ToUInt32($Mask, 16))

        [int] $rights | Should -Be ([Convert]::ToInt32($Expected, 16))
    }

    It 'Should reject <Case> when it creates an identity' -ForEach @(
        @{ Case = 'an empty value'; Value = ''; Expected = [System.ArgumentException] }
        @{ Case = 'a SID with too many sub authorities'; Value = ('S-1-' + (('1-' * 20) + '1')); Expected = [System.InvalidCastException] }
        @{ Case = 'an account that does not exist'; Value = 'NTFSSecurityNoSuchAccount'; Expected = [System.Security.Principal.IdentityNotMappedException] }
    ) {
        $failure = { [Security2.IdentityReference2]::new($Value) } | Should -Throw -PassThru

        # PowerShell wraps the exception of a constructor, which here wraps the cause of an invalid SID in turn.
        $failure.Exception.InnerException | Should -BeOfType $Expected
    }
}
