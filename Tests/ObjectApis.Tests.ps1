<#
    Tests the public object APIs used with cmdlet output, without changing an item's security descriptor.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between blocks.'
)]
param ()

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
