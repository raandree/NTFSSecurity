# Explanations of the unvisited code, by rule

Generated from the classification of the unvisited methods in the aggregated
AltCover report of source `5a5d58b`.
[Quality-Gate-Paths-2026-10-09.md](./Quality-Gate-Paths-2026-10-09.md)
describes the method and the result; the rows of every method are in the CSV
file next to it. An explanation closes a path only as far as its evidence
goes: the evidence line of each rule says whether an executed probe, a static
scan of the compiled code, or reading the source supports it.

## By category

| Category | Disposition | Methods | Unvisited sequence points | Unvisited explicit branch points |
| --- | --- | ---: | ---: | ---: |
| unused by cmdlets | Explained | 60 | 173 | 34 |
| parameter/API surface | Explained | 103 | 103 | 0 |
| environment-specific | Explained | 27 | 81 | 18 |
| defensive | Explained | 33 | 77 | 16 |
| unused by cmdlets | Open | 8 | 8 | 2 |
| **Total** | | **231** | **442** | **70** |

## By rule

### ACCESS-GENERIC-CATCH

8 method(s), 32 unvisited sequence point(s), 3 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: ClearAccess, DisableAccessInheritance, EnableAccessInheritance,
GetAccess, GetInheritance, GetOrphanedAccess, GetSecurityDescriptor,
OwnerCmdlets.GetOwner.

Evidence: an executed probe.

Why: The unvisited points are the last catch (Exception) of the per-item loop,
taken when the DACL API fails with anything but access denied after the item
was found. A read or write of the DACL on local NTFS either succeeds or fails
with access denied (covered), and the probes found no other failure for these
cmdlets: an unresolvable SID is accepted, a locked file does not matter
because the security APIs ignore share modes, and a dangling junction is read
as the link itself. One input does trigger that catch, a deny entry without
rights, which .NET refuses with an ArgumentException; Add-NTFSAccess,
Remove-NTFSAccess and Add-NTFSAudit take it and are tested (an Allow entry
without rights is accepted, because the module adds Synchronize to it). A
cmdlet that has no rights parameter, such as the read and inheritance cmdlets,
has no such input. A second trigger exists for the cmdlets that add entries:
an ACL that is full. In both editions the 1,818th entry that was added to a
security descriptor in memory, with -SecurityDescriptor, raised an
OverflowException, "Length of the access control list exceed the allowed
maximum" (probe p37: unresolvable SIDs with ReadData; 1,816 entries were
written and read back without an error, and one more added with -Path
succeeded, so the overflow itself was not run with -Path). By reading the
source, the -Path loop takes that exception in the same handler as the
zero-mask case, whereas the -SecurityDescriptor sets have no handler around
the add, so there the exception ends the cmdlet. It was not turned into a test
of its own. A volume without ACL support or a corrupt descriptor cannot be
created safely on the shared host.

Residual risk: Low: one WriteError(exception, id, category, path) and
continue, the shape that the access-denied and ReadFileError siblings of the
same loops assert and that the zero-mask tests assert for the cmdlets that add
and remove entries. The catches of the cmdlets that only read or change
inheritance have no known trigger. A catch that wraps the write of the result
is entered also when a later command raises something while it takes the
object; every catch-all whose try block writes directly passes that exception
on (a scan of the source finds no exception; it cannot see a write inside a
helper such as the owner restore of InvokeAsOwner, an accepted limitation),
and the PipelineControl tests run that part for every cmdlet.

Related tests: Access.Tests and Audit.Tests: a deny or audit entry without
rights for Add-NTFSAccess, Remove-NTFSAccess and Add-NTFSAudit (AddAceError
and RemoveAceError, ArgumentException, WriteError, target, continuation,
nothing written). PathErrors: ReadFileError, ReadSecurityError, denied write
and ownership retry, each with continuation. PipelineControl.Tests: a break, a
continue, Select-Object -First, a throw, and an error with -ErrorAction Stop
after the first object.

### ALLOCATED-MEMORY-FINALIZER

2 method(s), 3 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: AllocatedMemory.

Evidence: reading the source.

Why: AllocatedMemory is internal and used only in a using block of
GetTokenPrivileges, which disposes it and suppresses the finalizer. The
finalizer and the branch for a pointer that was released already run only for
an instance that nobody disposed.

Residual risk: None found.

Related tests: Privileges.Tests: the token handle tests list the privileges
through it.

### AUDIT-OWNER-RETRY

10 method(s), 47 unvisited sequence point(s), 2 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: AddAudit, AddAudit/<>c__DisplayClass35_0, ClearAudit,
ClearAudit/<>c__DisplayClass11_0, DisableAuditInheritance,
DisableAuditInheritance/<>c__DisplayClass15_0, EnableAuditInheritance,
EnableAuditInheritance/<>c__DisplayClass15_0, RemoveAudit,
RemoveAudit/<>c__DisplayClass39_0.

Evidence: an executed probe.

Why: The unvisited points are the catch (UnauthorizedAccessException) of an
audit write, its InvokeAsOwner retry and the closure of that retry. Local NTFS
never raises that exception for an audit change: as a basic user all seven
audit cmdlets get an IOException, error 1314 (A required privilege is not
held), in both editions (probe); with the Security privilege nothing in a DACL
can deny the privilege-only right, and a loopback administrative share ended
in no exception for all five either (probe, elevated, EnablePrivileges on and
off). The retry is the InvokeAsOwner code that the access cmdlets share, so
its success, failure and RestoreOwnerError paths run there; only the audit
closure bodies, which repeat the first attempt, are unexecuted.

Residual risk: Low to medium: an audit write that a file server answers with
access denied runs lines that no instrumented test reaches. The live lab suite
runs the audit cmdlets over SMB outside the instrumented run.

Related tests: PathErrors (denied write and ownership retry for the access
cmdlets), FileHash and SecurityDescriptor tests (ownership retry), Audit.Tests
(privilege missing or disabled).

### AUDIT-READ-DENIED

2 method(s), 6 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: AuditCmdlets.GetOrphanedAudit, GetAudit.

Evidence: an executed probe.

Why: The unvisited points are the catch (UnauthorizedAccessException) that
writes a PermissionDenied ReadSecurityError for an audit read. Without the
Security privilege Windows answers error 1314, which AlphaFS raises as an
IOException (probe as a basic user, both editions) and the generic catch of
the same loop reports as an OpenError; with the privilege, nothing denies the
read locally. An access-denied answer needs a remote file server.

Residual risk: Low: the same WriteError statement with another category.

Related tests: Audit.Tests: error without the Security privilege, descriptor
read without audit entries.

### CHILDITEM2-NON-FOLDER

1 method(s), 0 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: GetChildItem2.

Evidence: reading the source.

Why: The else of the test for a DirectoryInfo at the start of WriteFileSystem:
both callers pass one, ProcessRecord after it returned for a file, and the
recursion with the folders that EnumerateDirectories returned.

Residual risk: None found.

Related tests: ItemCmdlets.Tests: files, folders, recursion, filters, depth.

### CMDLET-GETTER

103 method(s), 103 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: parameter/API surface. Disposition: Explained.

Classes: AddAccess, AddAudit, ClearAccess, ClearAudit, CopyItem2,
DisableAccessInheritance, DisableAuditInheritance, DisablePrivileges,
EnableAccessInheritance, EnableAuditInheritance, EnablePrivileges,
GetChildItem2, GetDiskSpace, GetEffectiveAccess, GetFileHash2, GetInheritance,
GetItem2, GetSecurityDescriptor, GetSimpleAccess, MoveItem2, NewHardLink,
NewSymbolicLink, RemoveAccess, RemoveAudit, RemoveItem2, SetInheritance,
SetOwner, SetSecurityDescriptor.

Evidence: reading the source.

Why: A one-line getter of a cmdlet parameter. PowerShell binds a parameter
through its setter and the cmdlet code reads the private field, so no caller
invokes the getter. It has no logic, so a test that reads it back repeats the
field assignment and proves no behavior.

Residual risk: None found.

Related tests: Every parameter-set test binds the setters; Help.Tests and
OutputTypes.Tests read the parameter metadata.

### CODEMEMBERS-NULL-BASE

1 method(s), 1 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: FileSystemCodeMembers.

Evidence: an executed probe.

Why: The second null check tests the base object of the PSObject that the
first check let through. A PSObject cannot wrap null: new PSObject($null) and
PSObject.AsPSObject($null) throw PSArgumentNullException in both editions
(probe), and PowerShell hands a $null argument over as null, which the first
check covers.

Residual risk: None found.

Related tests: ItemCmdlets.Tests: the Mode of files, of a folder, and of no
object.

### DISKSPACE-EMPTY-VOLUME

1 method(s), 0 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: GetDiskSpace.

Evidence: reading the source.

Why: The unvisited branch skips a volume that reports zero bytes, such as a
card reader or an optical drive without media. The host has none, and a test
cannot attach one without changing the shared machine.

Residual risk: Low: the volume is skipped silently.

Related tests: ItemCmdlets.Tests: volumes with a size, drive letter without a
volume.

### EFFECTIVE-ACCESS-CATCH

2 method(s), 10 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: GetEffectiveAccess, GetEffectiveAccess/<>c__DisplayClass20_0.

Evidence: reading the source.

Why: EffectiveAccess.GetEffectiveAccess hides every failure of its Authz calls
in a result with OperationFailed, which the cmdlet turns into
GetEffectiveAccessError. The catch (Exception) blocks and the InvokeAsOwner
retry therefore see an exception only from what runs outside those calls: the
read of the descriptor of the item (EffectiveAccess.cs, the FileSystemInfo
overload) or the conversion of the account. The only local failure of the
descriptor read is access denied, which the UnauthorizedAccessException branch
handles and the tests cover; no other local trigger was found, and the
unresolved identity, which the conversion accepts, ends in OperationFailed.

Residual risk: Low: a failure of the descriptor read other than access denied,
such as an I/O error of the volume, would run the unvisited catch, which
writes one ReadEffectivePermissionError and continues like its tested
siblings.

Related tests: Access.Tests: unresolved identity for a path and a descriptor,
remote fallback, privilege warnings.

### ENABLEPRIVILEGES-INIT

1 method(s), 2 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: EnablePrivileges.

Evidence: reading the source.

Why: The branches that test whether the caller is a script named
NTFSSecurity.Init.ps1 are run by Privileges.Tests, which writes a script of
that name and of another name and runs each in a child process. The tests
check the state of the Backup privilege and the verbose message that only the
cmdlet writes, because with the setting $true the module enables the
privileges itself before the cmdlet runs: from the Init script the cmdlet
enables them for EnablePrivileges $true and does nothing for $false, from
another script it enables them for both. The script that the module ships
under that name does not call Enable-Privileges (it adds the types). What
stays unvisited is the catch that rethrows a ParseException for a malformed
EnablePrivileges value: the base BeginProcessing casts the same value first
and fails earlier, and the cmdlet takes no pipeline input, so only a consumer
of the debug or verbose stream could change the setting between the two calls.

Residual risk: Low: the catch rethrows with a message that names the setting;
it was not run.

Related tests: Privileges.Tests: Enable-Privileges in the script
NTFSSecurity.Init.ps1 (three cases), Enable-Privileges and Disable-Privileges.

### FILESECURITY-CONVERSION

2 method(s), 2 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: unused by cmdlets. Disposition: Open.

Classes: FileSystemSecurity2.

Evidence: an executed probe.

Why: The implicit conversions from FileSecurity and DirectorySecurity
construct FileSystemSecurity2 from FileInfo("") and DirectoryInfo(""), so they
always throw ArgumentException (probe: "Path is a zero-length string"). A test
of the intended behavior would fail, and a test of the actual behavior would
cement a defect in an API that no cmdlet uses.

Residual risk: Library users who convert a .NET descriptor get an exception.
Fix or remove is a maintainer decision.

Related tests: None, on purpose.

### FSSEC2-CONSTRUCTOR-FALLBACK

1 method(s), 2 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: FileSystemSecurity2.

Evidence: reading the source.

Why: The unvisited points are the last fallback of the constructor with one
argument: the DACL read alone after the DACL read together with the owner and
the group failed. The first fallback, without the SACL when the Security
privilege is missing, runs in the basic configurations. The owner and the
group need the same READ_CONTROL right as the DACL, so the third read succeeds
only where a volume or a server answers them differently.

Residual risk: Low: the descriptor that the fallback returns holds the DACL
only, and the cmdlets that need more report it.

Related tests: SecurityDescriptor.Tests and Audit.Tests: a descriptor read
without the Security privilege.

### FSSEC2-DRIVE-LETTER-CHARS

1 method(s), 0 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: FileSystemSecurity2.

Evidence: reading the source.

Why: The unvisited branch is a first character that is no letter in front of
the colon. AlphaFS normalizes the full name, so a name of two characters that
ends in a colon always begins with a drive letter, in upper or lower case
(both run); a digit or another character cannot form such a name.

Residual risk: None found.

Related tests: DriveRoot.Tests: the system drive and a mapped drive;
ObjectApis.Tests: a lowercase drive letter.

### FSSEC2-HASHCODE-NULL

1 method(s), 0 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: FileSystemSecurity2.

Evidence: reading the source.

Why: The zero is for a descriptor without a wrapped .NET descriptor. Both
constructors set it, because GetSecurity returns a descriptor or throws, and
the conversions from FileSecurity and DirectorySecurity throw before an object
exists. Only a derived class that sets the field to null reaches it.

Residual risk: None found.

Related tests: SecurityDescriptor.Tests: equality, hash code, and use as a
key.

### GENERATED-RESOURCES

6 method(s), 12 unvisited sequence point(s), 2 unvisited explicit
branch point(s). Category: unused by cmdlets. Disposition: Explained.

Classes: Properties.Resources.

Evidence: reading the source.

Why: The designer-generated resource class of two icons that no code
references.

Residual risk: None found.

Related tests: None needed.

### HARDLINK-DENIED

1 method(s), 3 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: GetHardLink.

Evidence: an executed probe.

Why: The unvisited points are the catch (UnauthorizedAccessException) of the
hard link enumeration. No local input was found that raises it: with deny
entries for ReadAttributes, ReadData and ReadPermissions for OWNER RIGHTS and
for the user, and automatic privileges off, Get-NTFSHardLink still listed the
names (probe p32, elevated, both editions), and Links.Tests asserts that
listing while the data of the file cannot be read (Get-Content fails). Whether
a denial of ReadAttributes or ReadPermissions alone could change that was not
shown: an elevated session read the permissions despite the deny entries, so
the test asserts only the refused data. The IOException of a network share,
(50), is covered.

Residual risk: Low: one WriteError with the PermissionDenied category. If a
Windows version or a file server refuses the listing, the new test fails and
this catch is reached.

Related tests: Links.Tests: the names of a file whose read rights are denied,
error for a file on a network share, for a folder and for a missing path.

### HASH-POLICY-AND-RETRY

2 method(s), 7 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: GetFileHash2, GetFileHash2/<>c__DisplayClass9_0.

Evidence: an executed probe.

Why: Two groups. The second catch around the algorithm check handles an
algorithm that a FIPS policy refuses; the policy of the host cannot be
switched in a test. The closing points after InvokeAsOwner run only when the
hash succeeds after taking ownership: ownership grants READ_CONTROL and
WRITE_DAC but never data read, so the retry can only fail, which two tests
assert. Probes looked for a way around that: with the owner changed to the
user the read still ended in access denied (error 5, plus a RestoreOwnerError
1307 for an owner that the user cannot set back), and an OWNER RIGHTS deny is
no way in either, because Windows drops that entry when the owner changes.

Residual risk: Low: the success path after the retry has no local trigger. A
file server that grants the read to the owner only would run it.

Related tests: FileHash.Tests: unavailable algorithms, unreadable file,
restore of the previous owner, failed restore.

### IDENTITY-NULL-REFERENCE

1 method(s), 0 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: IdentityReference2.

Evidence: reading the source.

Why: The unvisited branch is an IdentityReference that is neither an NTAccount
nor a SecurityIdentifier, which only null is: the .NET class has no other
public subclass. The object then has no SID and every member fails with a
NullReferenceException. No cmdlet passes null, and a test would cement that
failure.

Residual risk: Low: a library caller that passes null gets an unusable object.

Related tests: ObjectApis.Tests: identity constructors and their errors.

### INHERITED-FROM-EMPTY-LIST

1 method(s), 0 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: FileSystemAuditRule2.

Evidence: an executed probe.

Why: The access twin is tested: a NULL DACL, which Windows reads as an ACL
with no entries and .NET reports as one entry for Everyone, runs the branch
where the list of sources is empty (Access.Tests). The unvisited branch that
remains is the second operand of getInheritedFrom && inheritedFrom.Count > 0
in the audit twin. GetInheritedFrom returns one source for each entry of the
SACL that it reads, also for the fallback text of an unknown parent, and an
empty list only for a descriptor without a SACL. The loop that holds the
condition runs over the audit entries of the same SACL, so an empty list means
that the loop has no entry and does not run, as for every item without a SACL
(Audit.Tests: the item has no SACL). The setting that turns the lookup off and
the fallback cover the other outcomes. A probe shows that an integrity label
in the SACL of a folder is not part of the SACL that the module reads, so the
sources of the audit entries stay aligned with the entries (probe, both
editions).

Residual risk: Low: the two lists are aligned by position, which assumes that
the .NET API returns a rule for every entry of the ACL that Windows names a
source for; an entry type that it skips would shift the sources. No such entry
was found on NTFS, and none was tested.

Related tests: Access.Tests: InheritedFrom with the setting on and off, for an
unknown parent and for a NULL DACL; Audit.Tests: InheritedFrom of audit
entries and an item without a SACL; ObjectApis.Tests: an empty DACL.

### NATIVE-HANDLES

16 method(s), 34 unvisited sequence point(s), 6 unvisited explicit
branch point(s). Category: unused by cmdlets. Disposition: Explained.

Classes: IntPtrExtensions, SafeAuthzRMHandle, SafeHGlobalHandle,
SafeTokenHandle.

Evidence: reading the source.

Why: Native memory and handle wrappers. The overloads that the Authz and
descriptor code use run; the unvisited ones have no caller: further
AllocHGlobal overloads, InvalidHandle getters, ReleaseHandle for handles that
the module never creates, and Increment. They wrap Marshal.AllocHGlobal and
FreeHGlobal, so a test would repeat the BCL.

Residual risk: Low.

Related tests: Effective access tests run the used overloads.

### PRIVILEGE-DISABLE-FAILURE

4 method(s), 10 unvisited sequence point(s), 2 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: BaseCmdletWithPrivControl.

Evidence: reading the source.

Why: These are the failure branches of disabling a privilege. DisablePrivilege
reads the current state first and does nothing unless the privilege is
Enabled, so a privilege that another command disabled, or that the token does
not hold, never reaches them. They run only when AdjustTokenPrivileges fails
for an enabled privilege, for example for an invalid token handle; a test
would have to corrupt the process token.

Residual risk: Low: a failed cleanup is a warning that names the privilege.
The deferred review "failed privilege-disable retry" stays not reproduced.

Related tests: Privileges.Tests: another command disables a privilege, early
pipeline stop, token holds only some privileges.

### PRIVILEGE-ENABLER-RACE

1 method(s), 0 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: PrivilegeEnabler.

Evidence: reading the source.

Why: The third operand of the condition, that the adjustment returned
PrivilegeModified, is false only when another thread enabled the privilege
between the state check and the adjustment of the same call.

Residual risk: None found.

Related tests: Privileges.Tests: the first and the second enabler, a privilege
that was enabled before, and a privilege that the token does not hold.

### PRIVILEGECONTROL-DEAD-ELSE

2 method(s), 2 unvisited sequence point(s), 2 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: PrivilegeControl.

Evidence: reading the source.

Why: The unvisited points are the last else of each method, taken when the
third read of the privilege state finds none of Disabled, Removed, or Enabled.
PrivilegeState has exactly these three values and GetPrivilegeState returns
one of them, so the else can run only when another thread changes the
privilege between the reads of one call.

Residual risk: None found: the message would be Unknown Error, for a state
that cannot exist.

Related tests: Privileges.Tests: enabling and disabling a held privilege,
repeating either, and a privilege that the token does not hold.

### READ-RETRY-CLOSURE

4 method(s), 8 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: GetAccess/<>c__DisplayClass20_0, GetInheritance/<>c__DisplayClass7_0,
GetOrphanedAccess/<>c__DisplayClass1_0,
GetSecurityDescriptor/<>c__DisplayClass4_0.

Evidence: reading the source.

Why: The closure re-reads the item inside InvokeAsOwner. InvokeAsOwner reads
the owner first, which needs the same READ_CONTROL right as the read that
failed, so the retry stops before the closure runs; the documentation and
PathErrors assert the resulting ReadSecurityError. A DACL that denies reading
the DACL but not the owner cannot be built.

Residual risk: None found: the closure repeats the first attempt.

Related tests: PathErrors: An item whose owner may not read its permissions.

### REGISTRY-MODEL

34 method(s), 105 unvisited sequence point(s), 20 unvisited explicit
branch point(s). Category: unused by cmdlets. Disposition: Explained.

Classes: RegistryAccessRule2, RegistryEffectivePermissionEntry,
RegistryInheritanceInfo, RegistryKeyOpenException,
RegistryKeySetSecurityException, Win32RegistrySecurity.

Evidence: a static scan of the compiled code.

Why: The registry ACL object model of the original project. No cmdlet accepts
a registry path and no other class of the four assemblies calls it (static IL
scan). SetRegistryOwner takes ownership of registry keys, which no test may do
on the shared host, and the model is not part of the documented module
surface. Decisions 21 and 22 leave these classes to the maintainer.

Residual risk: Untested and undocumented library surface; a script that calls
it has no test behind it. Keep or remove is a maintainer decision.

Related tests: None; see the decision.

### RELATIVE-PATH-EMPTY

1 method(s), 1 unvisited sequence point(s), 1 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: BaseCmdlet.

Evidence: an executed probe.

Why: The unvisited points are the first branch, which replaces an empty path
with the current location. Every caller passes a validated value: each -Path
and -Target parameter of the cmdlets carries ValidateNotNullOrEmpty, which
rejects an empty value and an empty element of an array in both editions
(probe), and the mandatory -Destination of Copy-Item2 and Move-Item2 rejects
an empty string. A cmdlet without -Path passes the current location itself.

Residual risk: None found: only a class derived from the cmdlet base class
could pass an empty path, and it would get the current location.

Related tests: ItemCmdlets.Tests: Get-Item2 resolves ., .., and relative
names.

### REMOVEALL-ACCOUNT-FILTER

6 method(s), 6 unvisited sequence point(s), 2 unvisited explicit
branch point(s). Category: unused by cmdlets. Disposition: Open.

Classes: FileSystemAccessRule2, FileSystemAccessRule2/<>c__DisplayClass36_0,
FileSystemAccessRule2/<>c__DisplayClass36_1, FileSystemAuditRule2,
FileSystemAuditRule2/<>c__DisplayClass7_0,
FileSystemAuditRule2/<>c__DisplayClass7_1.

Evidence: reading the source.

Why: The methods run: the cmdlets call RemoveFileSystemAccessRuleAll and
RemoveFileSystemAuditRuleAll without an account list. Only the branch for a
non-null list is unvisited, and no cmdlet reaches it. That branch discards the
result of the LINQ Where that should filter the rules, so the account list has
no effect and every explicit entry is removed (the deferred #113 finding); its
predicate, Count() > 1, would also match no account that appears once, so
using the result as it stands would remove nothing.

Residual risk: Library users who pass accounts lose all entries. A test of the
intended behavior would fail; the defect stays with the maintainer (Decision
16 and #113).

Related tests: None for the account list, on purpose; the cmdlets that call
the methods without one are tested.

### TESTPATH-DEAD-CATCH

1 method(s), 6 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: TestPath2.

Evidence: an executed probe.

Why: The catch (FileNotFoundException) is dead: TryGetFileSystemInfo2 returns
false for a missing item and never throws it. The catch
(NotSupportedException) was not reproduced with a colon, wildcard, device,
long or trailing-dot path in either edition (probes); the ArgumentException of
Windows PowerShell for illegal characters is covered.

Residual risk: Low: both branches write $false or an error for a path that
cannot exist.

Related tests: ItemCmdlets.Tests: Test-Path2 with illegal characters and the
debug message.

### TOKEN-NATIVE-FAILURE

6 method(s), 11 unvisited sequence point(s), 10 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: AccessTokenHandle, Privileges, ProcessHandle.

Evidence: an executed probe.

Why: The unvisited points are the branches that throw a Win32Exception when a
native call fails, and the branches for a size query that succeeds, which it
never does. They are OpenProcessToken in the constructor of AccessTokenHandle
(internal; the token of an exited process still opens, probe), CloseHandle in
ReleaseHandle (ProcessHandle is only created with ownsHandle false, so Windows
never releases it, and AccessTokenHandle releases a handle that it opened
itself), LookupPrivilegeValue in GetLuid (the names come from a fixed
dictionary), LookupPrivilegeName in GetPrivilegeName (the LUIDs come from the
token), and the second GetTokenInformation call after the size query. A test
would have to corrupt the token handle of the process or run on a Windows
version that lacks a privilege. The failures that a caller can cause, a handle
without the right to query or to adjust privileges, run in the Privileges
tests.

Residual risk: Low: each branch throws the Win32Exception of the failed call,
the shape that the covered branches assert.

Related tests: Privileges.Tests: a handle that may only query cannot enable a
privilege, and a handle that may only adjust cannot be queried.

### UNUSED-CMDLET-HELPER

2 method(s), 8 unvisited sequence point(s), 4 unvisited explicit
branch point(s). Category: unused by cmdlets. Disposition: Explained.

Classes: BaseCmdlet.

Evidence: a static scan of the compiled code.

Why: A protected helper or an empty override without a caller in the four
assemblies (static IL scan): the System.IO variant of
BaseCmdlet.GetFileSystemInfo, which every cmdlet replaces with
GetFileSystemInfo2, and the empty BaseCmdlet.ProcessRecord that every cmdlet
overrides. Neither can be called from a test without a running cmdlet that
derives from the class, and they stay until the maintainer decides about
unused classes (Decisions 21 and 22). The scan misses generic instantiations:
it called the Extensions.ForEach and GetParent helpers unused although cmdlets
call them, so they are tested directly now (ObjectApis.Tests) and no longer
listed here.

Residual risk: Low: not reachable from a cmdlet.

Related tests: None needed; ObjectApis.Tests runs the public Extensions
helpers.

### WIN32-AUTHZ-FAILURE

4 method(s), 5 unvisited sequence point(s), 5 unvisited explicit
branch point(s). Category: environment-specific. Disposition: Explained.

Classes: Win32.

Evidence: an executed probe.

Why: The unvisited points are the failures of the Authz calls other than the
two answers that the module expects of an unreachable computer, RPC server
unavailable and endpoint not registered, and the failure of the local resource
manager that follows. Every server name that a test can give, an empty one,
one with a space, backslashes, a colon, a bracket, 300 characters, malformed
and well-formed addresses, ends in one of the two expected answers (probe),
and the local resource manager does not fail. A test would need a remote
computer that answers with another error.

Residual risk: Low: the cmdlet reports the exception as
GetEffectiveAccessError, the shape that the covered unresolved-identity case
asserts.

Related tests: Access.Tests: an unresolved identity, a computer that cannot be
reached, names of this computer, an empty name.

### WIN32-LOCAL-NAME-LOOKUP

1 method(s), 2 unvisited sequence point(s), 0 unvisited explicit
branch point(s). Category: defensive. Disposition: Explained.

Classes: Win32.

Evidence: reading the source.

Why: The unvisited points are the catch of a NetworkInformationException from
the lookup of the host and domain name of this computer, which returns false.
The lookup reads the local TCP/IP parameters, which this host has, and a test
cannot remove them.

Residual risk: None found: the name is then treated as another computer, with
the warning.

Related tests: Access.Tests: names of this computer, a computer that cannot be
reached, an empty name.

### WIN32-RAW-DESCRIPTOR

2 method(s), 14 unvisited sequence point(s), 2 unvisited explicit
branch point(s). Category: unused by cmdlets. Disposition: Explained.

Classes: Win32.

Evidence: a static scan of the compiled code.

Why: Win32 is an internal class. GetRawSecurityDescriptor is private and has
no caller, and the only caller of GetByteSecurityDescriptor is
GetRawSecurityDescriptor (static IL scan). They read a descriptor from a
handle, which the module does through AlphaFS.

Residual risk: None found: dead code. Removing it is a maintainer decision
(Decisions 21 and 22).

Related tests: None needed.
