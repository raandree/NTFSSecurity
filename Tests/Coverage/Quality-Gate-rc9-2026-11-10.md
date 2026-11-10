# Quality gate, the coverage of rc9, 2026-11-10

Handoff 6 of the quality gate before 5.0.0 (Decision 21, criteria 2 and 3).
The last measurement of the C# coverage was made at `2112ee3` (Handoff 5,
[the report of 2026-10-10](Quality-Gate-Unknowns-2026-10-10.md)). The code of
rc8 and rc9 was never measured. This report measures the published
5.0.0-rc9, classifies what the tests leave unvisited, tests what a test can
reach, and checks by row that no test is skipped in every configuration. It
does not close the gate: a coverage percentage never closes a gate, the stable
5.0.0 stays held, and the live tests are the subject of the addendum to the
[rc9 acceptance](../Lab/Acceptance-2026-11-10-published-rc9.md).
The agent pushed, merged, tagged, and published nothing, and changed nothing in
the module, its help file, or its manifest.

The work is on `ai/rc9-tests`, stacked on the record of the rc9 acceptance
(Decision 15). The measured bytes are the Release build of the tree of the tag
`5.0.0-rc9` (`823c814`); the tests are those of `2bfcefd`.

## Result in short

- **The code.** The tag `5.0.0-rc9` has the tree `c3ee690`, which is the tree of
  the validated `696ac38`. The product sources of the branch are those of the
  tag. The measured assemblies are a Release build of that tree; they are not
  byte-identical to the published package (which has no PDB files), but a
  comparison of the IL finds the same 1,172 types and methods, with 10
  differences that a compiler of another version or a build symbol explains
  ([Measured build against the published bytes](#measured-build-against-the-published-bytes)).
- **The coverage of the unit suite.** The tests of the tag visit 3,666 of 4,074
  sequence points (89.99%) and 1,316 of 1,410 explicit branch points (93.33%).
  With the 52 cases added here, the suite visits 3,672 of 4,074 (90.13%) and
  1,322 of 1,410 (93.76%). The denominators are equal in both runs, because
  the bytes are the same. At `2112ee3` it was 3,266 of 3,668 and 1,086 of 1,164.
- **The difference from `2112ee3`.** The product grew by 406 sequence points
  and 246 explicit branch points (33 changed C# files, +1,382 and -139 lines),
  and the number of unvisited sequence points is the same, 402: 19 methods are
  visited or gone (21 points), 10 methods have more unvisited points (13 more:
  the nine handlers of Decision 27, item 7, and one method of the
  authorization code), and 5 methods are new (8 points).
- **Every unvisited point is tested or explained.** All 169 methods that have
  an unvisited sequence point or explicit branch point are classified by 35
  rules, none is open. 23 of them lie in code that changed since `2112ee3`; each
  was read against the current source. The other 146 keep the explanation of
  the 2026-10-10 report, because their unvisited points are the same.
- **What the new tests close.** They visit 6 sequence points and 6 explicit
  branch points of the ten methods that are new in the unvisited list, and
  five of those methods have none left. The statements after
  `ThrowTerminatingError` in the four `ValidateNamedValue` (8 points) cannot
  run, and one operand of a guard in `DescribeValue` is redundant; both are
  explained. Each new test fails against a mutation of the product in a
  scratch build, and the mutations are not part of the branch.
- **Criterion 2.** In the four configurations the suite discovers 8,856 rows
  (2,214 each). 834 rows are skipped, 417 distinct rows of 214 tests, each
  skipped in two configurations and executed in the other two: 0 skipped rows
  without an executed counterpart.
- **No product defect.** None of the new tests, the probes, or the review of
  the unvisited code found one. The known limits of Decision 27 are listed in
  the `[5.0.0]` section of the CHANGELOG on `ai/release-5.0.0`; five of the
  six were reproduced on the published rc9 in both editions (the probes are in
  the evidence), and the sixth is a property of the .NET API.

## Tables

| File | Content |
| --- | --- |
| [Methods](Quality-Gate-rc9-2026-11-10-Methods.csv) | the 169 unvisited methods with source, unvisited lines and text, the status against `final9`, whether their file or their own code changed since `2112ee3`, the rule, the category, the disposition, the callers, the reason no test closes it, the residual risk, and the related tests |
| [ChangedFiles](Quality-Gate-rc9-2026-11-10-ChangedFiles.csv) | the 33 C# files that changed since `2112ee3`: lines added and removed, sequence points, visited and not, unvisited methods |
| [Reconciliation](Quality-Gate-rc9-2026-11-10-Reconciliation.csv) | the unvisited methods of `final9` against those of this measurement |
| [Runs](Quality-Gate-rc9-2026-11-10-Runs.csv) | the counts of every run: validation, coverage, and skip eligibility, for the tests of the tag and of the branch |
| [Mutations](Quality-Gate-rc9-2026-11-10-Mutations.csv) | the mutations of the new tests |
| [IL](Quality-Gate-rc9-2026-11-10-IL.csv) | the comparison of the measured assemblies with the published ones |
| [Evidence](Quality-Gate-rc9-2026-11-10-Evidence.csv) | the files outside git, with size and SHA-256 |

## Source and build identity

| Item | Value |
| --- | --- |
| Tag `5.0.0-rc9` | `823c814908a048e1607816a1041dc63357e01dfe`, tree `c3ee6904b19bffaf0a07b5072cdf9a586baddf97` |
| Validated candidate `696ac38` | the same tree |
| Tests of the first measurement | those of the tag |
| Tests of the second measurement | `2bfcefd` of `ai/rc9-tests`; no file outside `Tests`, `.memory-bank`, `Docs`, and Markdown differs from the tag |
| Build | `MSBuild` 4.0.30319 (64 bit), Roslyn 4.2.0 through `CscToolPath`, the .NET 4.5.2 reference assemblies, `Configuration=Release`, `/t:Rebuild`; 20 files in `NTFSSecurity\bin\Release` |
| Instrumentation | AltCover 9.0.145 (`net472`), OpenCover format, `localSource`, the Release PDB files copied next to the assemblies, AlphaFS and `System.Management.Automation` excluded, no `--save` |
| Published assemblies | `NTFSSecurity.dll` `464CAB36…`, `Security2.dll` `4F4FE3B9…`, `PrivilegeControl.dll` `7B6E908D…`, `ProcessPrivileges.dll` `392EB896…` |
| Measured assemblies | `NTFSSecurity.dll` `D9D7E428…`, `Security2.dll` `00047F7E…`, `PrivilegeControl.dll` `1A385F14…`, `ProcessPrivileges.dll` `504A4F4C…` |

The second measurement did not build again: the 20 Release files of the first
build (`release-pristine`, hashes in the evidence) were copied into a new
worktree at `2bfcefd`, their SHA-256 values were checked, and the tests of the
branch ran against them. The product files are the same, so the denominators
had to be equal, and they are (4,074 sequence points, 2,263 branch points of
the summary). A different denominator would have meant a different build.

## Method

1. Freeze a detached worktree at the tag, restore the compiler and AltCover
   from nuget.org with the SHA-512 values of the catalog, build Release, and
   keep the 20 files.
2. Validate: the four configurations of the CI (the elevated host and a basic
   user, in Windows PowerShell 5.1 and PowerShell 7, with the wrapper of the
   workflow), without instrumentation, to get the counts the CI reports.
3. Coverage: instrument the build in place, run the same four configurations
   one after the other, and aggregate them with `runner --collect`. The numbers
   here are sequence points. Of the branch points, only the explicit ones
   count, the ones that belong to a statement of the source; the branch summary
   of the tool adds points that no person wrote and is not read.
4. Inventory: for every method with an unvisited point, the lines, the text of
   the statement, the static callers (Mono.Cecil over the pristine
   assemblies), and whether a cmdlet reaches it. The rules of the
   classification match by class and method; the first matching rule wins.
5. Reconcile with the inventory of `final9` (Handoff 5): unchanged, moved
   (the same points on other lines), changed (other points), now visited or
   gone, and new. Tie each unvisited method to the diff of
   `2112ee3..823c814`: a method is marked as changed when a hunk touches its
   lines.
6. Skip eligibility, by row: the suite runs once more without instrumentation
   in each configuration and records every row (file, line, path, name, data)
   with its result. A skipped row is eligible when the same row runs in another
   configuration. Names in the NUnit files cannot be used for this, because
   they differ between a skipped and an executed row.

Nothing ran in the agent shell: every build and every test ran in a child
process, one configuration after the other, detached and monitored, and no lab
chain ran at the same time.

## The measurement of the tag

The tests of the tag visit 3,666 of 4,074 sequence points. The four
configurations pass with 2,162 cases each (27, 359, 58, and 390 skipped), the
counts of the CI.

| Assembly | Sequence points | Visited | Explicit branch points | Visited |
| --- | ---: | ---: | ---: | ---: |
| NTFSSecurity | 2,585 | 2,361 | 842 | 804 |
| Security2 | 1,248 | 1,080 | 490 | 448 |
| ProcessPrivileges | 219 | 205 | 66 | 54 |
| PrivilegeControl | 22 | 20 | 12 | 10 |
| All | 4,074 | 3,666 | 1,410 | 1,316 |

408 sequence points and 94 explicit branch points were unvisited, in 174
methods.

### The difference from `2112ee3`

| Measurement | Sequence points | Visited | Explicit branch points | Visited | Unvisited methods |
| --- | ---: | ---: | ---: | ---: | ---: |
| `2112ee3` (`final9`, Handoff 5) | 3,668 | 3,266 (89.04%) | 1,164 | 1,086 (93.30%) | 183 |
| 5.0.0-rc9, the tests of the tag | 4,074 | 3,666 (89.99%) | 1,410 | 1,316 (93.33%) | 174 |
| 5.0.0-rc9, the tests of `2bfcefd` | 4,074 | 3,672 (90.13%) | 1,410 | 1,322 (93.76%) | 169 |

Since the pin of Handoff 5, 33 C# files changed (+1,382 and -139 lines). The
two new files are `ParameterConversion.cs` (254 lines, 89 sequence points) and
`EnumArgumentCompleters.cs` (106 lines, 21 points); with the new tests, every
one of their 110 sequence points is visited by the unit suite. `GetChildItem2.cs`
has the matcher (`DosWildcard`) and 223 sequence points. The rc8 change of
`GetEffectivePermissions` (`25fe775`) is in `Security2\Win32\Lib.cs`; its new
lines are visited.

The reconciliation of the 402 unvisited sequence points of this measurement
with the 402 of `final9`:

| Status against `final9` | Methods | Unvisited sequence points | Explicit branch points | At `final9` |
| --- | ---: | ---: | ---: | --- |
| Unchanged | 114 | 245 | 53 | the same |
| Moved (other lines, the same points) | 40 | 74 | 15 | the same |
| Changed | 10 | 75 | 19 | 62 and 7 |
| New | 5 | 8 | 1 | none |
| Now visited, or gone | 19 | 0 | 0 | 21 and 3 |

The 19 methods that left the list are the code that the tests-only round
(#129) and the new tests of rc9 visit, and code that rc9 removed. The ten
changed methods are the nine handlers of Decision 27, item 7 (each got a
`throw;` and its check that no test reaches) and
`GetEffectivePermissions_AuthzInitializeResourceManager`, whose unvisited
set shrank. The new methods are the four `ValidateNamedValue` and `DescribeValue`.

## The unvisited points of the changed code

The unvisited methods lie in 24 of the 33 changed files and in 26 others.

| Where | Methods | Sequence points | Explicit branch points |
| --- | ---: | ---: | ---: |
| A file that changed since `2112ee3`, and the code of the method changed | 23 | 102 | 20 |
| A file that changed, the code of the method did not | 57 | 95 | 21 |
| A file that did not change | 89 | 205 | 47 |
| All | 169 | 402 | 88 |

The 146 methods whose code did not change have the same unvisited points as at
`final9`, and their explanation stands: the rule that classified them in the
2026-10-10 report matches them again. The 23 methods whose code changed are
the ones this section reads against the current source.

| Method | Status | Points (sequence/branch) | Rule |
| --- | --- | --- | --- |
| `AddAccess.ValidateNamedValue`, `RemoveAccess.ValidateNamedValue`, `AddAudit.ValidateNamedValue`, `RemoveAudit.ValidateNamedValue` | New | 2/0 each | THROW-TERMINATING-DEAD-RETURN |
| `ParameterConversion.DescribeValue` | New | 0/1 | DESCRIBE-REDUNDANT-GUARD |
| `GetAccess`, `GetEffectiveAccess`, `GetOrphanedAccess`, `GetInheritance` `.ProcessRecord` | Changed | 6/1, 9/1, 6/1, 6/3 | READ-RETRY-LATER-COMMAND |
| `AddAudit`, `ClearAudit`, `RemoveAudit`, `DisableAuditInheritance`, `EnableAuditInheritance` `.ProcessRecord` | Changed | 9/2 each | AUDIT-OWNER-RETRY |
| the closures of `AddAudit` and `RemoveAudit` | Moved | 2/0 each | AUDIT-OWNER-RETRY |
| `ClearAccess`, `DisableAccessInheritance`, `EnableAccessInheritance` `.ProcessRecord` | Moved | 3/0 each | ACCESS-GENERIC-CATCH |
| `BaseCmdletWithPrivControl.EndProcessing` | Moved | 3/1 | PRIVILEGE-DISABLE-FAILURE |
| `GetChildItem2.WriteFileSystem` | Moved | 0/1 | CHILDITEM2-NON-FOLDER |
| `GetFileHash2.ProcessRecord` | Moved | 6/0 | HASH-POLICY-AND-RETRY |
| `FileSystemAuditRule2.GetFileSystemAuditRules` | Moved | 0/1 | INHERITED-FROM-EMPTY-LIST |

### The check that a later command raises, in nine handlers

Decision 27, item 7, put the same check into the 17 handlers of the retry as
the owner: `if (IsFromLaterCommand(ex2)) { throw; }`. Eight handlers have a
test that drives them into `RestoreOwnerError` and a later command that throws
(`PipelineControl.Tests.ps1`). The check of the other nine is unvisited, and
the reason is a rule of Windows, not of the tests:

- **The four getters** (`Get-NTFSAccess`, `Get-NTFSOrphanedAccess`,
  `Get-NTFSEffectiveAccess`, `Get-NTFSInheritance`; READ-RETRY-LATER-COMMAND).
  The retry starts with `FileSystemOwner.GetOwner` (`InvokeAsOwner`,
  `BaseCmdlets.cs`), which needs the READ_CONTROL right whose denial started
  the retry. A denial that fails the first read fails that statement too, so the
  retry ends with a `ReadSecurityError` before it takes the owner, and never
  reaches the restore. Caller evidence: these are the `ProcessRecord` methods
  of cmdlets, which PowerShell calls, and the unvisited statements sit in the
  `catch` of the retry. A test would need a state of an item in which the read
  of the descriptor fails and the read of the owner does not; Windows has none,
  over a local volume or a share.
- **The five audit cmdlets** (AUDIT-OWNER-RETRY). They write the SACL, which
  Windows grants to an account that holds the Security privilege whatever the
  DACL says, and which an account without it can never write (error 1314, an
  `IOException`, not the `UnauthorizedAccessException` that starts the retry).
  The action never fails first, so the retry never starts; the 2026-10-10 report
  probed local volumes and loopback shares (elevated, `EnablePrivileges` on and
  off) and found no trigger, and the live suite visits none of these points
  either. A file server that is not a Windows server could answer differently
  (#34, out of scope).

The residual risk is the one of Decision 27: a later command that throws for
exactly the `RestoreOwnerError` record of one of these nine would be reported
as the error of the item and the loop would go on, as it did before rc9 for all
17. No state of an item leads there.

`GetInheritance` also has two guards, `if (inheritanceInfo != null)`, in the
loop of the paths and in the loop of the descriptors. Both overloads of
`FileSystemInheritanceInfo.GetFileSystemInheritanceInfo` end in `return new`,
so the other side has no input.

### The four `ValidateNamedValue` and the guard of `DescribeValue`

- **`ValidateNamedValue`** (`AddAccess.cs`, `RemoveAccess.cs`, `AddAudit.cs`,
  `RemoveAudit.cs`; 2 points each). The two points are the `return;` after
  `ThrowTerminatingError` for a named null and the closing brace of the `catch`
  that reports a bad named value. `Cmdlet.ThrowTerminatingError` always throws,
  so nothing after it can run; the `return` stays because the compiler does
  not know that. Both branches are tested: a bad named value and a named
  `$null` end the command with `InvalidParameterValue`. Residual risk: none.
- **`DescribeValue`** (`ParameterConversion.cs`, line 223, one branch point).
  `more` is set only when an eleventh element is read, which happens only while
  `shown.Count` is 10, so a collection that shows one element never has `more`
  set. The condition `shown.Count == 1 && !more` is equivalent to
  `shown.Count == 1`. The method otherwise runs for one element, several,
  more than ten, and, since the new tests, an empty collection. Residual risk:
  none.

### The moved methods, read against the current code

- `ClearAccess`, `DisableAccessInheritance`, `EnableAccessInheritance`: the
  unvisited points are the last `catch (Exception)` of the loop, as before; the
  check of rc9 sits in the retry, which the tests drive.
- `AddAudit` and `RemoveAudit` closures: the body of the retry, which repeats
  the first attempt, inside the `catch` that no run reaches.
- `BaseCmdletWithPrivControl.EndProcessing`: the failure branch of disabling a
  privilege. `DisablePrivilege` does nothing unless the privilege is enabled, so
  the branch needs `AdjustTokenPrivileges` to fail for an enabled one.
- `GetChildItem2.WriteFileSystem`: the other side of `if (di != null)`. Both
  callers pass a `DirectoryInfo`: `ProcessRecord` returns for a file before the
  call, and the recursion passes what `EnumerateDirectories` returned (read in
  the current source, lines 176 to 259).
- `GetFileHash2.ProcessRecord`: the `catch` for an algorithm that a FIPS policy
  refuses and the closing points after `InvokeAsOwner`; ownership grants
  READ_CONTROL and WRITE_DAC but never data read, so the retry can only fail.
- `FileSystemAuditRule2.GetFileSystemAuditRules`: the second operand of
  `findInheritedFrom && inheritedFrom.Count > 0`; `GetInheritedFrom` returns an
  empty list only for a descriptor without a SACL, where the loop does not run.

### The authorization code, after rc8

The rc8 fix (`25fe775`) makes `GetEffectivePermissions` hand what the
initialization of the resource manager throws to the cmdlet as
`GetEffectiveAccessError`; before, it was swallowed. The explanations of the
three methods that mention this were written before the fix and are corrected:

- `GetEffectivePermissions_AuthzInitializeResourceManager`: the success of the
  remote initialization (the host is not a domain member; the live tests and
  the unit suite on a domain member visit it) and two arms of the operands
  `isLocalComputer` and `error == ERROR_ACCESS_DENIED`, which are taken only
  when this computer itself refuses the caller. The `throw` for another error is
  visited (a name of 40,000 characters, `Access.Tests.ps1`).
- `GetEffectivePermissions_AuthzInitializeLocalResourceManager`: the `throw`
  needs a broken Authz service or an out-of-memory process; the exception now
  ends as `GetEffectiveAccessError`.
- `GetEffectivePermissions_AuthzAccessCheck`: the arm of `if (error != 0)` for a
  call that returns false with the last error 0; a failing call sets an error.

## What the new tests add

52 cases in two files, no change to the module:

| File | Cases | What they pin |
| --- | ---: | --- |
| `Tests\ParameterSets.Access.Tests.ps1` | 34 | An empty collection (array, list) for each of the four parameters, piped (8) and named (6), is rejected with `InvalidParameterValue` and named by its type; a sequence whose `GetEnumerator` or `MoveNext` throws is rejected for `-AccessType`, `-AppliesTo`, and `-InheritanceFlags`, piped and named (12); the five completers complete a word with an opening quote and no closing quote, and a quote alone, for both quotes (8, called directly, because PowerShell hands them a closing quote) |
| `Tests\ItemCmdlets.Tests.ps1` | 18 | `-Filter` with `.` and `...`, and with `a...` and `*...` (7 rows of the truth table of Windows PowerShell 5.1); six patterns with several asterisks that meet one position of a name again (`*a*a*c`, `*a*a*b`, `*a*b*a*b`, ...), pinned with the answers of Windows PowerShell 5.1; five patterns with an even run of dots at the end (`..`, `....`, `a..`, `a.b..`, `*..`), which Windows PowerShell 5.1 rejects with an error and which `Get-ChildItem2` accepts, as its page says |

The expected values of the filter rows are literal, taken from Windows
PowerShell 5.1's `Get-ChildItem -Filter` on the same names (the probe is in the
evidence); the even-dot rows use the answer of the same pattern with one dot.
The cases for the five parameters run for `Add-NTFSAccess` and
`Remove-NTFSAccess`; the audit cmdlets share the conversion.

The unit suite now has 2,214 cases in each configuration, and the skipped
counts did not change (27, 359, 58, 390).

### The mutations

A scratch copy of the worktree (without `.git`) got one change to the product
at a time, was built with the same compiler, and ran the two edited files in
Windows PowerShell 5.1 (elevated). The baseline passed 566 of 566. The
mutations are not part of the branch.

| Mutation | Tests that fail |
| --- | ---: |
| M1a: the closing quote is no longer taken off the word | 4 (12 in the first run) |
| M1b: `word.Length > 0` removed before `word[word.Length - 1]` | 8 |
| M1c: the last character of a quoted word is taken off also when it is not a quote | 8 |
| M2: `TakeOneValue` rethrows what the enumeration throws | 8 |
| M3: `DescribeValue` names an empty collection by nothing | 8 |
| M4: `pattern == "."` no longer means every item | 1 |
| M5: `trailingDotsFrom > 0` removed from the loop over the trailing dots | 3 |
| M6: `return cached` returns the opposite | 9 |

M1b survived the first set of tests: the completion tests that go through
`CommandCompletion.CompleteInput` never hand the completer a lone quote. The
direct calls were added for that, and M1b and M1c fail in the second run
(`mut-2`).

## The skip check by row

| Configuration | Discovered | Skipped | Executed | Skipped without an executed counterpart |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 2,214 | 27 | 2,187 | 0 |
| Windows PowerShell 5.1, basic user | 2,214 | 359 | 1,855 | 0 |
| PowerShell 7, elevated | 2,214 | 58 | 2,156 | 0 |
| PowerShell 7, basic user | 2,214 | 390 | 1,824 | 0 |

834 rows are skipped in all: 417 distinct rows (file, line, path, name, data)
of 214 tests, each skipped in two configurations and executed in at least one
other, so no test is skipped in every configuration that runs. 14 of the
skipped rows are in the two edited files and belong to tests that were there
before; the 52 new cases run in all four configurations.

## Measured build against the published bytes

The package has no PDB files, so AltCover cannot instrument the published
assemblies, and the measurement is of a build of the same tree. The Release
build is not reproducible byte by byte (the PDB path and the compiler
differ), so the comparison is of the code: for every type and method of the
four assemblies, `Compare-IL.ps1` (Mono.Cecil) compares the surface of the
type (attributes, base type, interfaces, fields, properties, parameters, and
the custom attributes of all of them) and, for every method, the signature and
every instruction with its operand, the local variables, and the exception
handlers.

| Assembly | Members compared | Only in one build | Different |
| --- | ---: | ---: | ---: |
| NTFSSecurity | 681 | 0 | 1 |
| Security2 | 392 | 0 | 3 |
| PrivilegeControl | 8 | 0 | 0 |
| ProcessPrivileges | 91 | 0 | 6 |

The ten differences:

| Member | Difference | Cause |
| --- | --- | --- |
| `<PrivateImplementationDetails>/__StaticArrayInitTypeSize=16` in `NTFSSecurity` and in `Security2` | `NestedAssembly` in the published build, `NestedPrivate` in the measured one | the compiler's helper type, a compiler version |
| `EffectiveAccessInfo.get_OperationFailed` | `ldnull; cgt.un` against `brfalse` and `ldc.i4.1` | the same null test of `authzException`, compiled by another version |
| `Win32.GetInheritedFrom` | the same null test, so other branch targets | as above |
| `PrivilegeAndAttributes.ToString` and `GetHashCode` | a copy of the enumeration field to a local (`ldfld`, `stloc`, `ldloca`) against `ldflda` | the same calls, compiled by another version |
| `AllocatedMemory`, `Privilege`, `PrivilegeAttributes`, `TokenAccessRights` | `SuppressMessage` attributes only in the published assembly | the attribute is conditional on `CODE_ANALYSIS`, which the CI defines |

The published `ProcessPrivileges.dll` is 512 bytes larger than the measured
one; the other three assemblies have the same size on both sides. No method
exists on one side only, and no difference changes what a statement does.
The sequence points come from the statements of the source, so the denominators
are those of the published code up to the generated code of these members.
What this does not show: a coverage run of the published bytes themselves.

## Decisions made

1. **Measure a rebuild, compare the IL.** The package has no PDB, so there is
   no way to instrument the bytes that ship. The measured tree is the tag's
   tree, and the IL comparison states what differs.
2. **Tests only.** Every gap that a test can reach got a test; nothing in the
   module, the help file, or the manifest changed. A defect would have stopped
   this line of work until the maintainer chose between rc10 and accepting it;
   none was found.
3. **Call the completers directly.** `CommandCompletion` never gives them a lone
   quote or a word without its closing quote, and the classes are public, so
   they are called as a library caller would call them.
4. **Explain, not test, the dead statements.** The four `return;` and braces
   after `ThrowTerminatingError` and the redundant operand of `DescribeValue`
   cannot run; a test would assert nothing.
5. **No re-measure of the live suite.** The live runs can add only points that
   the lab can reach and the unit suite leaves unvisited; Handoff 5 measured
   that they add 9 sequence points and 4 branch points, all of the
   effective-access code. The case 11 runs of the lab are the subject of the
   addendum to the acceptance record.
6. **Corrected explanations.** Three rules of the 2026-10-10 classification
   said that the initialization errors of the authorization manager are
   swallowed. That stopped being true in rc8 (`25fe775`); the rules say what
   the code does now.

## Open items for the maintainer

1. **Accept the explanations** of the 169 methods for criterion 3, or name the
   ones that need a test or a change. The nine handlers of item 7 and the
   authorization arms are the ones that rest on a statement about Windows;
   each statement is in the methods table with its source and its probe.
2. **Confirm the six known limits** in the `[5.0.0]` section of the CHANGELOG
   of `ai/release-5.0.0`, or name one to fix in rc10. The form of 2026-11-10
   named none. Nothing else is open from this measurement.

## Checks not run, and limits

- **A coverage run of the published bytes.** Not possible without PDB files;
  see the comparison of the IL.
- **An instrumented live run of rc9.** Handoff 5 did it for rc7; the explained
  points that the lab can reach (the audit retry, the read denial of an audit
  read) were probed over SMB without a trigger.
- **The mutations** ran in Windows PowerShell 5.1, elevated, one at a time; the
  new tests run in all four configurations.
- **A domain member.** The unit suite ran on the Hyper-V host (not a domain
  member). The suite on the machines of the matrix lab is part of the
  addendum to the acceptance record.
- **The by-row skip check** uses the unit suite on the host; the live tests in
  `Tests\Lab` are excluded from the suite and are skipped without a lab.
- **A mutation run is a sample.** The eight mutations show that the new tests
  can fail for the code they name; they do not prove that no other change is
  missed.

## Evidence outside git

`E` is `C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files`.
The [Evidence table](Quality-Gate-rc9-2026-11-10-Evidence.csv) lists every
file with its size and SHA-256, among them:

| Path | Content |
| --- | --- |
| `E\rc9-coverage\m1` | the first measurement: the frozen worktree at the tag, the 20 pristine files, the coverage XML (four runs and the aggregate), the inventory, the validation logs, `source-pin.txt` |
| `E\qg-unknowns\rc9-r1` | the second measurement: the same bytes under `2bfcefd`, the analysis, the changed-code tables, the IL comparison and the dumps of the ten differences |
| `E\qg-unknowns\eligibility-rc9-r1` | the rows of the four configurations and the comparison |
| `E\rc9-coverage\mut-1`, `E\rc9-coverage\mut-2` | the mutation runs |
| `E\rc9-coverage\probes` | the probes of the filter and the conversion, the known limits on a FAT32 volume and a NULL DACL, and the logs |
| `E\qg-unknowns\scripts` | the tools of the measurement and the analysis (inspect before reuse; they are not part of the kit) |
