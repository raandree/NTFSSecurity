---
status: accepted
date: 2026-10-21
last-verified: 2026-10-21
owner: shared
source: maintainer answers of 2026-10-21 (fix scope B, items 3 to 7 change, review on; designs chosen in the third form); probes of 2026-10-21 on the published rc8
---

# Decision 27: The open items before 5.0.0, and the piped optional parameters

- Context: the tests-only round left no plain test gap (#129). On 2026-10-21
  the maintainer chose to fix the silent default scope of a piped `AppliesTo`
  before 5.0.0 (rc9) and to go through the other open items one by one. rc9
  is the last prerelease: a change after its acceptance needs rc10, and after
  5.0.0 the repository is archived (Decision 18). So this is the last moment
  to change any of the items below, and unchanged means accepted.
- Status: accepted. The scope and the designs are chosen (see "The
  maintainer's choices", both tables). Every recommendation in the tables is
  the agent's; the last column of the table of the other items stays empty,
  because the choices are listed below. The details of fix B that the
  maintainer did not see (error id, terminating or not) are the agent's design
  and are flagged for the independent review.

## New finding: the flaw is a family

PowerShell skips a property of a piped object whose value it cannot convert to
the type of an optional parameter, and the parameter keeps its default. A named
call fails loudly; the same value on a piped object does not. Probe
`p-unconvertible-optional-params.ps1`, the published rc8, both editions (the
only difference is how `ReadData` prints):

| Piped property | What rc8 does |
| --- | --- |
| `AccessType = 'Deny'` | A Deny entry, as intended |
| `AccessType = 'Denyy'` (typo), or a blank CSV cell | **An Allow entry**, no message |
| `AuditFlags = 'Failurre'` | Success and Failure are audited (the default), no message |
| `InheritanceFlags` or `PropagationFlags = 'Typo'` | Ignored; the default flags (`ContainerInherit`, `ObjectInherit`) |
| `AppliesTo = 'Typo'`, a blank cell, or `99` | Ignored; the broader default scope |
| `Remove-NTFSAccess` with `AccessType = 'Denyy'` | Looks for an Allow entry: the Deny entry stays, no message |
| `Get-FileHash2` with `Algorithm = 'SHA999'` | SHA256, no message |
| `-AccessType Denyy` as a named parameter | A binding error, as it should be |

The decision of 2026-10-21 covers `AppliesTo` only. A typo for `Deny` that
creates an Allow entry is at least as serious, and it has the same cause.

## Options for the fix

Prototypes (`p-proto-appliesto-shapes.ps1`, `p-proto-object3.ps1`), both
editions, same attribute shape as `Add-NTFSAccess`:

| Shape | Result |
| --- | --- |
| One parameter set with optional parameters | Does not help: the binder skips the unconvertible value there too |
| `AppliesTo` as `object` alone | Loud for a bad scope, but a CSV row with `AppliesTo` and `InheritanceFlags` is no longer `AmbiguousParameterSet`: the scope silently wins |
| `AppliesTo`, `InheritanceFlags`, `PropagationFlags`, and `AccessType` or `AuditFlags` as `object`, converted in the cmdlet with `LanguagePrimitives.ConvertTo` | Loud for every bad value (a non-terminating error for that object, the next object goes on, nothing carries over); `AppliesTo` with flags is `AmbiguousParameterSet` for every mix of strings and enums; valid values unchanged |

| Option | What it is | Cost |
| --- | --- | --- |
| A | `AppliesTo` only (the decision as asked) | Leaves the Deny-to-Allow flip |
| B | The family in the four cmdlets (recommended): `AppliesTo`, `InheritanceFlags`, `PropagationFlags`, `AccessType` (access), `AuditFlags` (audit) | See below |
| C | B and `Get-FileHash2 -Algorithm` | B plus one cmdlet of low severity |
| D | No code change: pages and CHANGELOG say that piped values are not checked | Weak for a permissions tool |

Consequences of B: the help shows `<Object>` for these parameters (the pages
list the values; an argument completer keeps tab completion); a named call
with a bad value is an error record of the cmdlet instead of a terminating
binding error; a blank cell for any of them is an error, not the default; a
`$null` `AccessType` stays the default (Allow); the pipeline conflict check is
now uniform. The work: tests first (the pins of the silent behavior change),
four cmdlets, four pages, the help file, the CHANGELOG, rc9, and the
acceptance (about 70 minutes with `Chain-Published.ps1`). An independent
review is recommended: public behavior and the permission scope.

## The other open items

| # | Item | What a user can notice | If changed | Recommended | Choice |
| --- | --- | --- | --- | --- | --- |
| 2 | The help says that a local standard user who asks about a domain account still gets "Access is denied" | Nothing changes in behavior | Docs only; rides with rc9 | Do it in rc9 | |
| 3 | Library-only items of the DLL that no cmdlet reaches: the `FileSecurity` conversions always throw; the `RemoveAll` filters ignore the account list (#113); the lazy path overloads; a `PrivilegeEnabler` that is not disposed stays enabled; the unused registry model and helper classes; `PipelineControl.IsEnd`; one unvisited catch in `Enable-Privileges` | Only .NET callers of the DLL | Code change and rc9 | Accept; list as known limits of the .NET API | |
| 4 | `Get-ChildItem2 -Filter` dot patterns differ from `Get-ChildItem` (`Report.*` misses `Report`; `Rep*.` returns nothing) | Documented, pinned by tests | New matching code and rc9 | Accept as documented | |
| 5 | The `-SecurityDescriptor` sets of the four add and remove cmdlets end with a terminating error when the change throws; the `-Path` sets write an error per item and go on (7 test rows stay unpinned) | A failing change to a descriptor in memory stops the cmdlet | Per-item handlers and rc9 | Accept | |
| 6 | Three small inconsistencies: the error category of `Get-NTFSAccess` after a failed ownership retry (`WriteError` there, `OpenError` elsewhere); `Get-NTFSOrphanedAccess` warns where its siblings write an error; `Set-NTFSSecurityDescriptor` takes `-Path` at position 2, its siblings at 1 | Scripts that check a category or pass a path by position | A breaking change for such scripts, and rc9 | Accept | |
| 7 | Seventeen owner-restore handlers do not pass on what a later command raises, in the rare case that it throws only for the `RestoreOwnerError` record | Rare | One check per handler, an elevated-only test, rc9 | Accept | |
| 8 | The ownership retry and the read denial of an audit write over SMB have no trigger on a Windows file server | None known | A seam (a design change), or the answer of a non-Windows server (#34) | Accept; #34 decides on 2026-11-02 | |
| 9 | Eight getters of piped parameters that no test binds by property name | None (tests only) | Tests only, no rc9 | Do it after the code of rc9 is final; the fix tests cover `AccessType`, `AuditFlags`, and `Algorithm` | |
| 10 | Lab and process only: the ACL of the lab stage folders under `C:\`, rollback checkpoints that report Standard, a publication recovery that never ran against the Gallery, test helpers that accept a link, the cleanup list (AppVeyor, Read the Docs, wiki, `test/transfer`, old checkpoints) | Not shipped | n/a | Accept; the cleanup before the archive is the maintainer's | |
| 11 | The deferred reviews of rc3 to rc7 (`progress.md`, open work 3) | Not new | n/a | Accept | |

Decided before: the hard-link names under another root stay a documented known
limit (Decision 21); Decisions 22 and 24 are accepted; #34 is decided on
2026-11-02 (Decision 23).

## The maintainer's choices, 2026-10-21

| Question | Answer |
| --- | --- |
| Scope of the fix of the piped optional parameters | B: the family in the four cmdlets (`AppliesTo`, `InheritanceFlags`, `PropagationFlags`, `AccessType`, `AuditFlags`) |
| Items to change in rc9 | 3 (library-only items), 4 (`Get-ChildItem2 -Filter` dot patterns), 5 (descriptor sets report per descriptor), 6 (three inconsistencies), 7 (17 owner-restore handlers) |
| Items accepted as recommended | 8 (audit retry and read denial over SMB; #34 decides on 2026-11-02), 10, 11. Items 2 and 9 need no decision: the help sentence goes into rc9, and the tests for the eight getters follow when the code of rc9 is final |
| Independent review of the rc9 change | Yes (`review: on`) |

The design choices, third form, 2026-10-21 (each is the recommended default
except where noted):

| Item | Choice |
| --- | --- |
| 3 | Fix 3.1 (`FileSecurity` and `DirectorySecurity` conversions), 3.2 (`RemoveAll` honors the account list), 3.3 (the path overloads write at once), 3.10 (malformed `EnablePrivileges` setting). Not fixed: 3.4 (`PrivilegeEnabler` never disposed: high risk, stays a known limit of the .NET API), 3.6 (registry model and helpers: kept, Decisions 21 and 22), 3.9 (`PipelineControl.IsEnd`: kept) |
| 4 | Option B: one matcher in the cmdlet with the Windows PowerShell 5.1 dot rules on the real names (8.3 short names stay ignored, invariant culture), in both editions |
| 6a | Keep `WriteError` for `ReadSecurityError` after a failed ownership retry, and pin it with a test |
| 6b | `Get-NTFSOrphanedAccess` writes an error for a read failure other than access denied: `ReadSecurityError`, `OpenError`, target the path |
| 6c | `Set-NTFSSecurityDescriptor -SecurityDescriptor` at position 1 (cosmetic) |
| B details | Not asked; the agent's design, see the row B below. `Get-FileHash2 -Algorithm` stays out (option C was not chosen) and is listed as a known limit |

What follows: the work goes test-first into one branch, one commit per item, so
that any item can be dropped. A defect that the review finds is fixed before rc9 is tagged; a defect
that the acceptance finds needs rc10. One acceptance (about 70 minutes with
`Chain-Published.ps1`) covers rc9 as a whole.

## Designs proposed, 2026-10-21

Five read-only research threads read the code, the tests, and the docs. The
sheet below is their result, verified in part by the probes above. Fix B is
decided; the rest is to be chosen. Recommended defaults are the agent's.

| # | Design | Recommended | Alternatives and risks |
| --- | --- | --- | --- |
| B | `AppliesTo`, `InheritanceFlags`, `PropagationFlags`, `AccessType` (access cmdlets), `AuditFlags` (audit cmdlets) become `object` parameters; ProcessRecord converts them with `LanguagePrimitives.ConvertTo` into locals. One shared error: id `InvalidParameterValue`, category `InvalidArgument` (the category of the binder's own errors and of `AttributesEmpty`), message with the value, the parameter, and the valid names (a blank value has its own message). Revised before the build: a bad value on the command line stays a terminating error, as the binder made it (checked in `BeginProcessing`, so a `try`/`catch` around a named call still works); a bad value on a piped object is a non-terminating error per path (per descriptor in the `-SecurityDescriptor` sets), target that path, no item of that record is changed, and the next object goes on. A null `AccessType` or `AuditFlags` stays the default. Argument completers (`IArgumentCompleter`, available in the referenced Windows PowerShell 5.0 assembly) keep tab completion. Docs: `Type: Object`, help from `New-ExternalHelp`, the CHANGELOG paragraph at lines 247 to 258 | As described | `Get-FileHash2 -Algorithm` has the same flaw (option C, not chosen). The error of a named call now comes from the cmdlet, not the binder (other id, same terminating effect) |
| 5 | In the four `-SecurityDescriptor` branches, a `try/catch (Exception)` around the change of each descriptor writes `AddAceError` or `RemoveAceError`, category `WriteError`, target the descriptor, message of the exception, and goes on; the later-command check of item 7 goes into the same catch. Lines: `AddAccess.cs` 176 to 184, `RemoveAccess.cs` 177 to 185, `AddAudit.cs` 175 to 185, `RemoveAudit.cs` 176 to 186 | As described | Tests: a failing descriptor followed by a valid one; the 7 unpinned rows |
| 7 | One `IsFromLaterCommand(ex)` check, rethrowing, in each of the 17 outer handlers (the pattern of `SetSecurityDescriptor.cs` 72 to 101): `AddAccess`, `RemoveAccess`, `ClearAccess`, `GetAccess`, `GetOrphanedAccess`, `GetEffectiveAccess`, `AddAudit`, `RemoveAudit`, `ClearAudit`, `GetFileHash2`, the six inheritance cmdlets, and `SetSecurityDescriptor` | As described | Tests: one parameterized elevated-only test (a later command that throws on the `RestoreOwnerError` record), like the existing `restoreOwnerCases` |
| 3.1 | `FileSystemSecurity2` conversions from `FileSecurity` and `DirectorySecurity` keep the given descriptor | Fix | Remove the operators: breaking public API. Medium risk |
| 3.2 | `RemoveFileSystemAccessRuleAll` and `RemoveFileSystemAuditRuleAll` honor the account list | Fix | High risk for external callers (they remove entries); the cmdlets pass no list. Tests for both rule types |
| 3.3 | The path and several accounts overloads of the two add methods write at once, like their siblings | Fix | Medium risk (the moment of an exception changes) |
| 3.4 | `PrivilegeEnabler` no longer keeps an undisposed instance reachable | Defer unless the maintainer insists | High risk: token state in every cmdlet; a finalizer test is not deterministic; every cmdlet disposes its enabler today |
| 3.6 | The registry model (about 500 lines), `FileSystemFlags`, `FileSystemEffectivePermissionEntry`, and two raw descriptor readers | Keep and document (Decisions 21 and 22) | Removal breaks unknown .NET callers of the public DLL |
| 3.9 | `PipelineControl.IsEnd` | Keep as defense in depth | A change touches the pipeline semantics of all cmdlets for no known defect |
| 3.10 | The malformed `EnablePrivileges` setting: one validation in the base class, the dead catch removed | Fix | Medium risk (base class) |
| 4 | `Get-ChildItem2 -Filter`. A: pass the pattern unchanged to AlphaFS (the Windows PowerShell 5.1 rules; brings back the 8.3 short-name matches that a past fix removed). B: one cmdlet-side matcher with the Win32 dot rules on the real names and a broad enumeration (about 40 lines; costs a larger enumeration over SMB). D: keep as documented | B | Even `Get-ChildItem` differs between the editions here, so "aligned" needs a stated policy: the Windows PowerShell 5.1 dot rules on real names, in both editions |
| 6a | `Get-NTFSAccess`, the category of `ReadSecurityError` after a failed ownership retry: `WriteError` in `Get-NTFSAudit`, `Get-NTFSEffectiveAccess`, `Get-NTFSInheritance`, and `Get-NTFSSecurityDescriptor` too, so it is the majority convention | Keep, and pin it with a test | `OpenError` would break scripts that check the category, and make the module inconsistent unless six cmdlets change |
| 6b | `Get-NTFSOrphanedAccess` warns for a read failure other than access denied | An error: `ReadSecurityError`, `OpenError`, target the path | Breaks `-WarningAction` users; `-ErrorAction Stop` newly stops |
| 6c | `Set-NTFSSecurityDescriptor` has `-SecurityDescriptor` at position 2 and no other positional parameter | Position 1 | Cosmetic: a lone positional parameter binds first whatever its number |

## Assumption flagged for the maintainer's review

- The lab suite: he answered "not sure, you pick". The agent took the
  recommendation: run the full suite (1,615 cases per configuration) on the
  lab machine classes now, against the published rc8, so that an OS-specific
  finding can still go into rc9 instead of forcing rc10. It changes nothing in
  the repository or the product. Evidence: `suite-newtests` in the session
  folder. Result (2026-10-21, 09:10 to 09:33 UTC): 24 runs on six machine
  classes (Windows Server 2019, 2022, and 2025, Windows 11 22H2 and 26H1, and
  the host), 0 failures. Every run gained exactly 121 cases against the rc8
  acceptance, and the four new files give the counts of the CI runner (elevated
  Desktop: Access 74/0, Audit 55/2, Inheritance 72/1, Items 90/0, executed and
  skipped). No OS-specific finding. The machines are saved again, and
  `OSWin11E` is off.

## Built in rc9, the review, and the known limits

- How: four implementers worked in separate worktrees (WI-1 the five piped
  parameters and item 5, WI-2 item 7 and the three inconsistencies, WI-3 the
  library items, WI-4 the filter), test first, one commit per item. The agent
  integrated them, ran the whole suite on the integrated tree, and had three
  read-only reviewers read it (brief `rc9\REVIEW-BRIEF.md` in the session
  folder). The findings became follow-up commits, and the branch `ai/rc9` was
  rebuilt with `git cherry-pick` in the order of each chain, so every fix sits
  in the commit of its item and any item can still be dropped.
- Round 2 (brief `rc9\REVIEW-BRIEF-2.md`): two reviewers read the final tree
  (scope A the four add and remove cmdlets, scope B everything else), then
  checked the fixes of their own findings. No Blocker and no Major; nine Minor
  findings: five wrong or incomplete statements in the pages and the CHANGELOG
  (a script block "was silently ignored" when it was evaluated per object;
  `-AppliesTo $null` keeps the binder's error; the carry-over of the scope
  affected only objects with one flags property; the descriptor sets that go
  on after a failing descriptor are a breaking change; the PowerShell 7 list of
  patterns was too narrow), the trailing blank and `..` of the filter
  (documented, not changed), a stale header of two test files, the completers
  without `CultureInvariant` (fixed), and a list for `-AccessType` and
  `-AppliesTo` whose numbers PowerShell combines bit by bit (the maintainer
  chose on 2026-10-21 to reject it in rc9; older than rc9, the same in
  4.2.6). Two more checks of the fixes found that the rejection could be
  bypassed through other kinds of collection (a hash set, a queue, the keys of
  a dictionary, a LINQ result, a one-element collection that holds a comma
  string), that a collection that holds itself never returned (the binder of
  rc8 ends the host with a stack overflow on it), and that the message named
  the type, not the typo: fixed in `e39aeed` and `da41a8e`, each with tests
  that were red first (32 and 28 rows). Final suite on `de67883`: 2,116 cases
  per configuration, 0 failed in four configurations (rc8: 1,615); the pages
  and the help file are a fixpoint; PSScriptAnalyzer finds nothing in the 11
  changed scripts; the public surface equals the validated candidate; a matrix
  of valid shapes differs from the published rc8 in exactly 9 list rows.

What the review found:

| Finding | What became of it |
| --- | --- |
| Blocker: a `*` before a dot has to stop at the LAST dot, the matcher stopped at the first; `*.??` missed `archive.tar.gz`. The differential check ran on 8.3 names, which have one dot, and could not see it | Fixed; a differential check over 732,630 multi-dot pairs found no mismatch; the tests pin the multi-dot shapes |
| Major: with `object` parameters, a `$null`, DBNull, or blank value of the OTHER parameter group binds in both sets, so a CSV row with a blank cell of the other group is `AmbiguousParameterSet` (rc8 skipped the cell and created the entry) | Documented and pinned. **Flagged:** the alternative is a restructure of the parameter sets, a larger public change; the maintainer was told that the agent goes on with the documentation and has not objected |
| Major: a named `$null` (`-AccessType $rule.AccessTpye`) silently selected the default | Fixed: a terminating `InvalidParameterValue` for a name in `BoundParameters` whose value is `$null` |
| Minor: a script block is no longer delay-bound; the completers returned nothing for a quoted or wildcard word | Documented and pinned; the completers are fixed |
| Minor: since 3.1, `-SecurityDescriptor (Get-Acl $f)` binds, and then threw from the inherited-from lookup and marked the audit section as read; the null guard of `Name` was not pinned; `Get-NTFSInheritance` wrote its object in a `finally` after it rethrew the exception of a later command | Fixed; the guard is pinned through reflection, because a PowerShell property read turns a throwing getter into `$null` |
| Filter: platyPS removed paired asterisks of a paragraph; the PowerShell 7 claim was too broad; the CHANGELOG said nothing of the new `?`; a pattern of more than 32,767 characters ended the host with a stack overflow; one sentence contradicted itself | Fixed: one asterisk per paragraph, the exact shapes, the CHANGELOG sentence, `[ValidateLength(0,32767)]` |

Known limits, kept and to be stated to the maintainer:

- `Get-NTFSEffectiveAccess` on a FAT32 volume or on an item with a NULL DACL
  ends with an `ArgumentOutOfRangeException` (mask 2097151). Found by a probe,
  not caused by rc9, not fixed.
- The error branch of 6b (`Get-NTFSOrphanedAccess` cannot read an item) has no
  deterministic trigger: a locked file, a long path, a dangling junction, and a
  FAT32 VHD were tried. It is reviewed, not pinned.
- Item 7: 9 of the 17 handlers have no test. The getters' own
  `FileSystemOwner.GetOwner` needs the same read right that the test takes
  away, and the audit cmdlets write the SACL whatever the DACL says, so the
  action never fails first.
- `Get-FileHash2 -Algorithm` keeps the silent default of a piped value that
  does not convert (option C was not chosen). The settings `GetInheritedFrom`,
  `GetFileSystemModeProperty`, and `IdentifyHardLinks` still read their value
  with an unchecked cast, as `EnablePrivileges` did. `PrivilegeEnabler` (3.4)
  stays undisposed, a known limit of the .NET API.
- In PowerShell 7, the case folding of `-Filter` differs from NTFS for a few
  exotic letters (finding F7 of the review; not fixed).
