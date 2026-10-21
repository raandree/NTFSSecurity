<#
    Tests the public object APIs used with cmdlet output, on files and folders in a sandbox folder.
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

    # tr-TR lowercases I to U+0131, so a comparison that lowercases both names with the current culture misses an account name that holds an
    # uppercase I (NT AUTHORITY, BUILTIN) when the other name has another case. The name must match in every culture.
    It 'Should compare a name with the account ignoring case in Turkish, where I and i are different letters' {
        $system = [Security2.IdentityReference2] 'S-1-5-18'
        $system.AccountName | Should -MatchExactly 'I' -Because 'the test needs an account name with an uppercase I'
        $original = [System.Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('tr-TR')
            'I'.ToLower() | Should -Be ([string][char]0x131) -Because 'the culture of the thread has to be Turkish for the test to mean anything'
            $system.Equals($system.AccountName) | Should -BeTrue
            $system.Equals($system.AccountName.ToLowerInvariant()) | Should -BeTrue
            $system.Equals($system.AccountName.ToUpperInvariant()) | Should -BeTrue
            $system.Equals('NTFSSecurity-not-an-account') | Should -BeFalse
        }
        finally {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $original
        }
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

    # Before 5.0.0, the overload that takes a path was an iterator (yield return) that changed nothing until the
    # caller enumerated the result, so a call as a statement, or an assignment that the caller never reads, wrote
    # nothing; the overloads that take an item or a FileSystemSecurity2 were never lazy. It now writes at once, like
    # its siblings, so the entries exist before $pending is ever touched.
    It 'Should add the entries of several accounts to a <Kind> by its path at once, before the result is ever enumerated' -ForEach @(
        @{ Kind = 'file'; Directory = $false }
        @{ Kind = 'folder'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'AddListByPath' -Directory:$Directory
        $accounts = New-AccountList

        $pending = [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
            $path, $accounts, [Security2.FileSystemRights2]::ReadData, $allow, $noInheritance, $noPropagation
        )

        @(Get-ExplicitEntries -Path $path) | Should -HaveCount 1
        @(Get-ExplicitEntries -Path $path -Account 'S-1-5-32-545') | Should -HaveCount 1

        $added = @($pending)
        $added | Should -HaveCount 2
        $added[0].Account.Sid | Should -BeExactly $identity.Sid
        $added[1].Account.Sid | Should -BeExactly $users.Sid
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
        $found = @([Security2.FileSystemAuditRule2]::GetFileSystemAuditRules($path, $true, $false))
        $found | Should -HaveCount 1
        $found[0].Account.Sid | Should -BeExactly 'S-1-1-0'
        $found[0].FullName | Should -BeExactly $path
    }

    # Before 5.0.0, the overload that takes a path was an iterator (yield return) that changed nothing until the
    # caller enumerated the result; it now writes at once, like its siblings, so the entries exist before $pending is
    # ever touched. This overload needs the Security privilege like its neighbors, so the whole Describe skips without it.
    It 'Should add the entries of several accounts to a <Kind> by its path at once, before the result is ever enumerated, and remove them again' -ForEach @(
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

        @(Get-AuditEntries -Path $path) | Should -HaveCount 1
        @(Get-AuditEntries -Path $path -Account 'S-1-5-32-545') | Should -HaveCount 1
        $added = @($pending)
        $added | Should -HaveCount 2
        $added[0].Account.Sid | Should -BeExactly $identity.Sid
        $added[1].Account.Sid | Should -BeExactly $users.Sid

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

    # The overloads that take a path do nothing for a path that is neither a file nor a folder.
    It '<Method> should change nothing for a path that does not exist' -ForEach @(
        @{ Method = 'EnableAccessInheritance' }
        @{ Method = 'DisableAccessInheritance' }
        @{ Method = 'EnableAuditInheritance' }
        @{ Method = 'DisableAuditInheritance' }
    ) {
        $missing = Join-Path -Path $sandbox -ChildPath ('Missing-{0}' -f [guid]::NewGuid().ToString('N'))
        Assert-TestSandboxPath -Sandbox $sandbox -Path $missing

        { [Security2.FileSystemInheritanceInfo]::$Method($missing, $true) } | Should -Not -Throw

        Test-Path -LiteralPath $missing | Should -BeFalse
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

    # The item decides where Write puts the sections that the descriptor was read with, and Name and FullName follow it.
    It 'Should write a descriptor to the item that the caller assigns' {
        $source = New-TestSandboxItem -Sandbox $sandbox -Name 'RetargetSource'
        $target = New-TestSandboxItem -Sandbox $sandbox -Name 'RetargetTarget'
        Add-NTFSAccess -Path $source -Account 'S-1-1-0' -AccessRights ReadData
        $descriptor = Get-NTFSSecurityDescriptor -Path $source
        $descriptor.Item = Get-Item2 -Path $target

        $descriptor.FullName | Should -BeExactly $target
        $descriptor.Name | Should -BeExactly (Split-Path -Path $target -Leaf)
        $descriptor.Write()

        foreach ($path in $source, $target) {
            @((Get-Acl -LiteralPath $path).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                    Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
        }
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

# Before 5.0.0, both conversions ignored the descriptor that was passed and returned a FileSystemSecurity2 that wrapped
# a FileInfo or a DirectoryInfo built from an empty path, which AlphaFS rejects, so the conversion always threw. The
# object that the fixed conversion returns has no item: FullName and Name, which have no path to report, are null,
# which reads most naturally as "nothing to name".
Describe 'The FileSystemSecurity2 conversions from FileSecurity and DirectorySecurity' {
    BeforeAll {
        function New-RawFileSystemSecurity {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory descriptor only.'
            )]
            param ([string] $Kind)

            $raw = New-Object -TypeName "System.Security.AccessControl.$Kind"
            $rule = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                $sid, [System.Security.AccessControl.FileSystemRights]::ReadData,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $raw.AddAccessRule($rule)
            $raw
        }

        # PowerShell silently turns an exception that a property getter throws into $null, without even recording a
        # non-terminating error, so a plain "$object.Property" cannot tell a getter that throws from one that
        # legitimately returns null. The getter is invoked through reflection instead, so that it throws normally.
        function Invoke-PropertyGetter {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only reads a property through reflection.'
            )]
            param ([object] $InputObject, [string] $PropertyName)

            $InputObject.GetType().GetProperty($PropertyName).GetGetMethod().Invoke($InputObject, $null)
        }
    }

    It 'Should wrap the <Kind> descriptor that was passed, report IsFile as <IsFile>, and round-trip the same instance' -ForEach @(
        @{ Kind = 'FileSecurity'; IsFile = $true }
        @{ Kind = 'DirectorySecurity'; IsFile = $false }
    ) {
        $raw = New-RawFileSystemSecurity -Kind $Kind
        $targetType = [type] "System.Security.AccessControl.$Kind"

        $wrapped = [Security2.FileSystemSecurity2] $raw

        [object]::ReferenceEquals($wrapped.SecurityDescriptor, $raw) | Should -BeTrue
        $wrapped.IsFile | Should -Be $IsFile
        [object]::ReferenceEquals(($wrapped -as $targetType), $raw) | Should -BeTrue
        $wrapped.FullName | Should -Be $null
        $wrapped.Name | Should -Be $null
    }

    It 'Should compare two <Kind> conversions of the same descriptor as equal, and of different descriptors as unequal' -ForEach @(
        @{ Kind = 'FileSecurity' }
        @{ Kind = 'DirectorySecurity' }
    ) {
        $raw = New-RawFileSystemSecurity -Kind $Kind

        $first = [Security2.FileSystemSecurity2] $raw
        $second = [Security2.FileSystemSecurity2] $raw
        $other = [Security2.FileSystemSecurity2] (New-RawFileSystemSecurity -Kind $Kind)

        $first.Equals($second) | Should -BeTrue
        $first.GetHashCode() | Should -Be $second.GetHashCode()
        $first.Equals($other) | Should -BeFalse
    }

    It 'Should throw an InvalidOperationException, not a NullReferenceException, when a <Kind> without an item is written' -ForEach @(
        @{ Kind = 'FileSecurity' }
        @{ Kind = 'DirectorySecurity' }
    ) {
        $wrapped = [Security2.FileSystemSecurity2] (New-RawFileSystemSecurity -Kind $Kind)

        $failure = { $wrapped.Write() } | Should -Throw -PassThru

        $failure.Exception.GetBaseException() | Should -BeOfType [System.InvalidOperationException]
        $failure.Exception.GetBaseException().Message | Should -BeLike '*item*'
    }

    It 'Should write a <Kind> without an item once the caller sets Item' -ForEach @(
        @{ Kind = 'FileSecurity'; Directory = $false }
        @{ Kind = 'DirectorySecurity'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'ConvertedWriteItem' -Directory:$Directory
        $wrapped = [Security2.FileSystemSecurity2] (New-RawFileSystemSecurity -Kind $Kind)
        $wrapped.Item = Get-Item2 -Path $path

        $wrapped.Write()

        @((Get-Acl -LiteralPath $path).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
    }

    It 'Should write a <Kind> without an item directly to a path' -ForEach @(
        @{ Kind = 'FileSecurity'; Directory = $false }
        @{ Kind = 'DirectorySecurity'; Directory = $true }
    ) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'ConvertedWritePath' -Directory:$Directory
        $wrapped = [Security2.FileSystemSecurity2] (New-RawFileSystemSecurity -Kind $Kind)

        $wrapped.Write([string] $path)

        @((Get-Acl -LiteralPath $path).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
                Where-Object -FilterScript { $_.IdentityReference.Value -eq 'S-1-1-0' }) | Should -HaveCount 1
    }

    # 3.1 makes a FileSystemSecurity2 without an item reachable from a .NET caller; the readers below must not meet a
    # NullReferenceException from it. Built in memory, so no privilege is needed to add the audit rule.
    It 'Should return the <RuleType> entries of a <Kind> without an item, with a null FullName' -ForEach @(
        @{ Kind = 'FileSecurity'; RuleType = 'access' }
        @{ Kind = 'DirectorySecurity'; RuleType = 'access' }
        @{ Kind = 'FileSecurity'; RuleType = 'audit' }
        @{ Kind = 'DirectorySecurity'; RuleType = 'audit' }
    ) {
        if ($RuleType -eq 'access') {
            $sd = [Security2.FileSystemSecurity2] (New-RawFileSystemSecurity -Kind $Kind)
            $found = @([Security2.FileSystemAccessRule2]::GetFileSystemAccessRules($sd, $true, $true, $false))
        }
        else {
            $raw = New-RawFileSystemSecurity -Kind $Kind
            $raw.AddAuditRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
                        $sid, [System.Security.AccessControl.FileSystemRights]::ReadData,
                        [System.Security.AccessControl.AuditFlags]::Success
                    )))
            $sd = [Security2.FileSystemSecurity2] $raw
            $found = @([Security2.FileSystemAuditRule2]::GetFileSystemAuditRules($sd, $true, $true, $false))
        }

        $found | Should -HaveCount 1
        $found[0].FullName | Should -Be $null
        $found[0].Account.Sid | Should -BeExactly 'S-1-1-0'
    }

    It 'Should throw an InvalidOperationException, not a NullReferenceException, for the source of an inherited <RuleType> entry of a descriptor without an item' -ForEach @(
        @{ RuleType = 'access' }
        @{ RuleType = 'audit' }
    ) {
        if ($RuleType -eq 'access') {
            $sd = [Security2.FileSystemSecurity2] (New-RawFileSystemSecurity -Kind 'FileSecurity')
            $failure = { [Security2.FileSystemAccessRule2]::GetFileSystemAccessRules($sd, $true, $true, $true) } |
                Should -Throw -PassThru
        }
        else {
            $raw = New-RawFileSystemSecurity -Kind 'FileSecurity'
            $raw.AddAuditRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
                        $sid, [System.Security.AccessControl.FileSystemRights]::ReadData,
                        [System.Security.AccessControl.AuditFlags]::Success
                    )))
            $sd = [Security2.FileSystemSecurity2] $raw
            $failure = { [Security2.FileSystemAuditRule2]::GetFileSystemAuditRules($sd, $true, $true, $true) } |
                Should -Throw -PassThru
        }

        $failure.Exception.GetBaseException() | Should -BeOfType [System.InvalidOperationException]
        $failure.Exception.GetBaseException().Message | Should -BeLike '*item*'
    }

    It 'Should return an owner object with a null FullName and an empty ToString for a <Kind> without an item' -ForEach @(
        @{ Kind = 'FileSecurity' }
        @{ Kind = 'DirectorySecurity' }
    ) {
        $raw = New-RawFileSystemSecurity -Kind $Kind
        $raw.SetOwner($sid)
        $sd = [Security2.FileSystemSecurity2] $raw

        $owner = [Security2.FileSystemOwner]::GetOwner($sd)

        $owner.Owner.Sid | Should -BeExactly 'S-1-1-0'
        { Invoke-PropertyGetter -InputObject $owner -PropertyName 'FullName' } | Should -Not -Throw
        (Invoke-PropertyGetter -InputObject $owner -PropertyName 'FullName') | Should -Be $null
        $owner.ToString() | Should -BeExactly ''
    }

    It 'Should return inheritance info with a null FullName and Name for a <Kind> without an item' -ForEach @(
        @{ Kind = 'FileSecurity' }
        @{ Kind = 'DirectorySecurity' }
    ) {
        $sd = [Security2.FileSystemSecurity2] (New-RawFileSystemSecurity -Kind $Kind)

        $info = [Security2.FileSystemInheritanceInfo]::GetFileSystemInheritanceInfo($sd)

        { Invoke-PropertyGetter -InputObject $info -PropertyName 'FullName' } | Should -Not -Throw
        { Invoke-PropertyGetter -InputObject $info -PropertyName 'Name' } | Should -Not -Throw
        (Invoke-PropertyGetter -InputObject $info -PropertyName 'FullName') | Should -Be $null
        (Invoke-PropertyGetter -InputObject $info -PropertyName 'Name') | Should -Be $null
        $info.AccessInheritanceEnabled | Should -BeTrue
    }

    # The Authz access check needs a descriptor with an owner and a group, like any real file has; the minimal
    # descriptor of the other tests has neither, and the call fails with "The parameter is incorrect" for either.
    It 'Should return the effective access of a <Kind> without an item, with a null FullName on the result' -ForEach @(
        @{ Kind = 'FileSecurity' }
        @{ Kind = 'DirectorySecurity' }
    ) {
        $raw = New-RawFileSystemSecurity -Kind $Kind
        $raw.SetOwner($sid)
        $raw.SetGroup($sid)
        $sd = [Security2.FileSystemSecurity2] $raw

        $result = [Security2.EffectiveAccess]::GetEffectiveAccess($sd, $identity, $null)

        if ($result.OperationFailed) {
            Set-ItResult -Skipped -Because "the Authz call could not run in this configuration: $($result.AuthzException.Message)"
            return
        }

        $result.Ace.FullName | Should -Be $null
    }
}

# Before 5.0.0, the account list of both methods was built but its filter result was never assigned anywhere, so a
# non-null list removed every explicit entry regardless of what it named; only a .NET caller that passes a list is
# affected, since the cmdlets never do.
Describe 'RemoveFileSystemAccessRuleAll and RemoveFileSystemAuditRuleAll honor the account list' {
    BeforeAll {
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $success = [System.Security.AccessControl.AuditFlags]::Success
        $accountOne = $identity
        $accountTwo = [Security2.IdentityReference2] 'S-1-5-32-545'
        $accountThree = [Security2.IdentityReference2] 'S-1-5-32-544'
        $accountsByLabel = @{ One = $accountOne; Two = $accountTwo; Three = $accountThree }

        function New-AccessSecurityFor {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory descriptor only.'
            )]
            param ([Security2.IdentityReference2[]] $Accounts)

            $raw = New-Object -TypeName 'System.Security.AccessControl.FileSecurity'
            foreach ($account in $Accounts) {
                $raw.AddAccessRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                            [System.Security.Principal.SecurityIdentifier] $account,
                            [System.Security.AccessControl.FileSystemRights]::ReadData, $allow
                        )))
            }
            $raw
        }

        function New-AuditSecurityFor {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory descriptor only.'
            )]
            param ([Security2.IdentityReference2[]] $Accounts)

            $raw = New-Object -TypeName 'System.Security.AccessControl.FileSecurity'
            foreach ($account in $Accounts) {
                $raw.AddAuditRule((New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
                            [System.Security.Principal.SecurityIdentifier] $account,
                            [System.Security.AccessControl.FileSystemRights]::ReadData, $success
                        )))
            }
            $raw
        }

        function New-IdentityList {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only creates a list.'
            )]
            param ([Security2.IdentityReference2[]] $Accounts)

            $list = New-Object -TypeName 'System.Collections.Generic.List[Security2.IdentityReference2]'
            foreach ($account in $Accounts) {
                $list.Add($account)
            }
            , $list
        }

        function Get-AccessSddl {
            param ([System.Security.AccessControl.FileSecurity] $Raw)

            $Raw.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Access)
        }

        function Get-AuditSddl {
            param ([System.Security.AccessControl.FileSecurity] $Raw)

            $Raw.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Audit)
        }

        # Builds the expected result by removing the given accounts with the .NET method directly, instead of with
        # a freshly built descriptor that only holds the remaining accounts: once an entry was added and removed
        # again, the SACL stays present but empty, while a SACL that never held an entry is absent, and the two give
        # a different SDDL for the same set of remaining entries.
        function Get-ExpectedAccessSddl {
            param ([Security2.IdentityReference2[]] $AccountsToRemove)

            $raw = New-AccessSecurityFor -Accounts $accountOne, $accountTwo, $accountThree
            foreach ($account in $AccountsToRemove) {
                $raw.RemoveAccessRuleSpecific((New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList (
                            [System.Security.Principal.SecurityIdentifier] $account,
                            [System.Security.AccessControl.FileSystemRights]::ReadData, $allow
                        )))
            }
            Get-AccessSddl $raw
        }

        function Get-ExpectedAuditSddl {
            param ([Security2.IdentityReference2[]] $AccountsToRemove)

            $raw = New-AuditSecurityFor -Accounts $accountOne, $accountTwo, $accountThree
            foreach ($account in $AccountsToRemove) {
                $raw.RemoveAuditRuleSpecific((New-Object -TypeName 'System.Security.AccessControl.FileSystemAuditRule' -ArgumentList (
                            [System.Security.Principal.SecurityIdentifier] $account,
                            [System.Security.AccessControl.FileSystemRights]::ReadData, $success
                        )))
            }
            Get-AuditSddl $raw
        }
    }

    It 'Should honor the account list when it removes access entries from a descriptor with three accounts, in memory, for <Scenario>' -ForEach @(
        @{ Scenario = 'a list with one account'; AccountsToRemove = @('One') }
        @{ Scenario = 'a list with two accounts'; AccountsToRemove = @('One', 'Two') }
        @{ Scenario = 'a null list'; AccountsToRemove = $null }
        @{ Scenario = 'an empty list'; AccountsToRemove = @() }
    ) {
        $raw = New-AccessSecurityFor -Accounts $accountOne, $accountTwo, $accountThree
        $toRemove = if ($null -eq $AccountsToRemove) { $accountOne, $accountTwo, $accountThree } else { $AccountsToRemove.ForEach({ $accountsByLabel[$_] }) }
        $expected = Get-ExpectedAccessSddl -AccountsToRemove $toRemove
        $accounts = if ($null -eq $AccountsToRemove) { $null } else { New-IdentityList -Accounts $AccountsToRemove.ForEach({ $accountsByLabel[$_] }) }

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRuleAll(([Security2.FileSystemSecurity2] $raw), $accounts)

        Get-AccessSddl $raw | Should -BeExactly $expected
    }

    It 'Should honor the account list when it removes audit entries from a descriptor with three accounts, in memory, for <Scenario>' -ForEach @(
        @{ Scenario = 'a list with one account'; AccountsToRemove = @('One') }
        @{ Scenario = 'a list with two accounts'; AccountsToRemove = @('One', 'Two') }
        @{ Scenario = 'a null list'; AccountsToRemove = $null }
        @{ Scenario = 'an empty list'; AccountsToRemove = @() }
    ) {
        $raw = New-AuditSecurityFor -Accounts $accountOne, $accountTwo, $accountThree
        $toRemove = if ($null -eq $AccountsToRemove) { $accountOne, $accountTwo, $accountThree } else { $AccountsToRemove.ForEach({ $accountsByLabel[$_] }) }
        $expected = Get-ExpectedAuditSddl -AccountsToRemove $toRemove
        $accounts = if ($null -eq $AccountsToRemove) { $null } else { New-IdentityList -Accounts $AccountsToRemove.ForEach({ $accountsByLabel[$_] }) }

        [Security2.FileSystemAuditRule2]::RemoveFileSystemAuditRuleAll(([Security2.FileSystemSecurity2] $raw), $accounts)

        Get-AuditSddl $raw | Should -BeExactly $expected
    }

    It 'Should remove only the listed account''s explicit access entries of a sandbox item, read back with .NET' {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveAllAccessByItem'
        $item = New-Object -TypeName 'Alphaleonis.Win32.Filesystem.FileInfo' -ArgumentList $path
        foreach ($account in $accountOne, $accountTwo, $accountThree) {
            [void] [Security2.FileSystemAccessRule2]::AddFileSystemAccessRule(
                $item, $account, [Security2.FileSystemRights2]::ReadData, $allow,
                [System.Security.AccessControl.InheritanceFlags]::None, [System.Security.AccessControl.PropagationFlags]::None
            )
        }

        [Security2.FileSystemAccessRule2]::RemoveFileSystemAccessRuleAll($item, (New-IdentityList -Accounts $accountOne))

        $remaining = @((Get-Acl -LiteralPath $path).GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]))
        @($remaining.IdentityReference.Value | Sort-Object) | Should -Be @(($accountTwo.Sid, $accountThree.Sid) | Sort-Object)
    }

    It 'Should remove only the listed account''s explicit audit entries of a sandbox item, read back with .NET' -Skip:(-not $holdsSecurityPrivilege) {
        $path = New-TestSandboxItem -Sandbox $sandbox -Name 'RemoveAllAuditByItem'
        $item = New-Object -TypeName 'Alphaleonis.Win32.Filesystem.FileInfo' -ArgumentList $path
        foreach ($account in $accountOne, $accountTwo, $accountThree) {
            [void] [Security2.FileSystemAuditRule2]::AddFileSystemAuditRule(
                $item, $account, [Security2.FileSystemRights2]::ReadData, $success,
                [System.Security.AccessControl.InheritanceFlags]::None, [System.Security.AccessControl.PropagationFlags]::None
            )
        }

        [Security2.FileSystemAuditRule2]::RemoveFileSystemAuditRuleAll($item, (New-IdentityList -Accounts $accountOne))

        $remaining = @((Get-Acl -LiteralPath $path -Audit).GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier]))
        @($remaining.IdentityReference.Value | Sort-Object) | Should -Be @(($accountTwo.Sid, $accountThree.Sid) | Sort-Object)
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

# The helpers of the cmdlets are public extension methods, so a script can call them. The cmdlets pass what the guards
# of ForEach refuse and a parent that is a folder, never a file; the generic method is invoked through reflection,
# because Windows PowerShell can't name the type argument of a call.
Describe 'The extension methods of the cmdlets' {
    BeforeAll {
        $forEachMethod = [NTFSSecurity.Extensions].GetMethod('ForEach').MakeGenericMethod([string])

        function New-ItemObject {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only creates an object.'
            )]
            param ([string] $Library, [string] $Path)

            if ($Library -eq 'AlphaFS') {
                [Alphaleonis.Win32.Filesystem.FileInfo]::new($Path)
            }
            else {
                [System.IO.FileInfo]::new($Path)
            }
        }
    }

    It 'ForEach should reject <Case>' -ForEach @(
        @{ Case = 'a source that is null'; NullSource = $true }
        @{ Case = 'an action that is null'; NullSource = $false }
    ) {
        $arguments = [object[]]::new(2)
        if ($NullSource) {
            $arguments[1] = [System.Action[string]] { param ($Element) $null = $Element }
        }
        else {
            $arguments[0] = [string[]] @('One')
        }

        $failure = { $forEachMethod.Invoke($null, $arguments) } | Should -Throw -PassThru

        # Reflection wraps the exception of the method, and PowerShell wraps that in turn.
        $failure.Exception.GetBaseException() | Should -BeOfType [System.ArgumentException]
    }

    It 'ForEach should run the action for each element in order' {
        $seen = New-Object -TypeName 'System.Collections.Generic.List[string]'
        $arguments = [object[]]::new(2)
        $arguments[0] = [string[]] @('One', 'Two', 'Three')
        $arguments[1] = [System.Action[string]] { param ($Element) $seen.Add($Element) }

        $forEachMethod.Invoke($null, $arguments) | Out-Null

        $seen -join ',' | Should -BeExactly 'One,Two,Three'
    }

    Context 'GetParent' {
        BeforeAll {
            $folder = New-TestSandboxItem -Sandbox $sandbox -Name 'ParentFolder' -Directory
            $file = New-TestSandboxItem -Sandbox $sandbox -Name 'ParentFile'
            $inFolder = Join-Path -Path $folder -ChildPath 'Child.txt'
            $belowFile = Join-Path -Path $file -ChildPath 'Child.txt'
            $belowMissing = Join-Path -Path $sandbox -ChildPath 'Missing\Child.txt'
        }

        It 'Should return a folder as a DirectoryInfo of <Library>' -ForEach @(
            @{ Library = 'AlphaFS'; TypeName = 'Alphaleonis.Win32.Filesystem.DirectoryInfo' }
            @{ Library = 'System.IO'; TypeName = 'System.IO.DirectoryInfo' }
        ) {
            $parent = [NTFSSecurity.Extensions]::GetParent((New-ItemObject -Library $Library -Path $inFolder))

            $parent.GetType().FullName | Should -BeExactly $TypeName
            $parent.FullName | Should -BeExactly $folder
        }

        # A FileInfo can name a path below a file, which no file system holds, so the parent path names a file.
        It 'Should return a parent path that names a file as a FileInfo of <Library>' -ForEach @(
            @{ Library = 'AlphaFS'; TypeName = 'Alphaleonis.Win32.Filesystem.FileInfo' }
            @{ Library = 'System.IO'; TypeName = 'System.IO.FileInfo' }
        ) {
            $parent = [NTFSSecurity.Extensions]::GetParent((New-ItemObject -Library $Library -Path $belowFile))

            $parent.GetType().FullName | Should -BeExactly $TypeName
            $parent.FullName | Should -BeExactly $file
        }

        It 'Should throw a FileNotFoundException for a parent that does not exist, for <Library>' -ForEach @(
            @{ Library = 'AlphaFS' }
            @{ Library = 'System.IO' }
        ) {
            $failure = { [NTFSSecurity.Extensions]::GetParent((New-ItemObject -Library $Library -Path $belowMissing)) } |
                Should -Throw -PassThru

            $failure.Exception.GetBaseException() | Should -BeOfType [System.IO.FileNotFoundException]
        }
    }
}
