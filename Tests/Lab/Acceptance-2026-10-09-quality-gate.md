# Quality-gate follow-up acceptance, 2026-10-09

Further validation of NTFSSecurity before 5.0.0, on
`ai/quality-gate-coverage`, based on rc7 PR #116 (`d25647d`). This is a
local candidate, not a published release or a claim that the quality gate
is complete. Architecture and cmdlet-design choices remain with the
maintainer (Decisions 16, 21, and 22).

## Candidate and artifact identity

- Module code/test baseline: `3442194`; first-hidden-item fix: `d610372`.
- Build: Release, .NET Framework 4.5.2; manifest label `5.0.0-rc7`.
  The label has not been advanced or published by this work.
- Packages produced by `.github/scripts/New-ModulePackage.ps1`.
  All 11 files in the live-tested packaged module folder match the
  extracted `NTFSSecurity.zip` byte-for-byte by SHA-256.
- Package SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| `NTFSSecurity.5.0.0-rc7.nupkg` | `E76B80CA8CBCD4E46EB5B4C61E53BD0BFCB461881593753A69F7F90385533768` |
| `NTFSSecurity.zip` | `ACA302594BF0B84EAF6F4E45476DC4AA096F5F9105E51B1F255FB061D57E99EC` |
| `NTFSSecurity.dll` | `4587F1B2FCF2683B02D1895CEE17D0ABF4060DA758264E09AEC0CF62536E7CAC` |

## Local validation

Final uninstrumented suite, 09:31 to 09:34 UTC; separate processes with the
real CI elevated/basic-user wrappers. Every configuration discovered 914
cases (202 above rc7); no test failed. Every skipped test template has an
executed counterpart in the four-run matrix. NUnit skipped data names were
normalized, not compared positionally or as literal expanded names.

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 890 | 0 | 24 | 914 |
| Windows PowerShell 5.1, basic user | 749 | 0 | 165 | 914 |
| PowerShell 7, elevated | 860 | 0 | 54 | 914 |
| PowerShell 7, basic user | 719 | 0 | 195 | 914 |

AST parse and PSScriptAnalyzer: zero issues in all 13 changed PowerShell
files. Release build, actionlint, Markdown lint, help generation/round trip,
and relative documentation links passed. Existing compiler warnings were
retained, not suppressed to obtain a green result.

New guards cover folder deletion, read-only/locked/junction/long-path
cases, owner restoration/retry failures, all 13 permission scopes in both
forms and storage modes, descendant propagation, file/folder inheritance,
enumeration/filter/depth/link skipping, forced replacement, and descriptor
write failure/continuation. Controlled mutations made the relevant tests
fail; source was restored exactly and Release rebuilt before validation.

Reproduced product defect: `Get-ChildItem2 -Hidden` omitted the first
hidden item because implied Force was set after deciding whether to emit
it. The regression failed before the fix in all four configurations.
CI result paths were also fixed test-first. Publication recovery has 14
offline tests; no real upload occurred.

## Coverage method and remaining inventory

AltCover 9.0.145 OpenCover report of frozen `3442194`, 09:24 to 09:28 UTC:
all four configurations sequentially, no `--save`, copied Release PDBs,
AlphaFS and System.Management.Automation excluded. Percentages are visited
sequence/branch points divided by their respective totals, not unique
source-line coverage.

| Assembly | Sequence points | Sequence coverage | Branch points | Branch coverage |
| --- | ---: | ---: | ---: | ---: |
| NTFSSecurity | 1,769/2,099 | 84.28% | 605/1,051 | 57.56% |
| Security2 | 747/1,219 | 61.28% | 330/740 | 44.59% |
| ProcessPrivileges | 113/219 | 51.60% | 35/125 | 28.00% |
| PrivilegeControl | 12/22 | 54.55% | 4/17 | 23.53% |
| Aggregate | 2,641/3,559 | 74.21% | 974/1,933 | 50.39% |

rc6 aggregate was 68.14% sequence/44.32% branch coverage. Its production
code differs, so the denominators differ. The 918 unvisited points remain
visible: 244 in classes unused by cmdlets, 112 parameter-getter points,
and 562 for finer classification/testing (unused overloads, defensive,
environment-specific, and reachable paths). This is not "everything tested
or explained" yet. For example, code intelligence finds only the definition
of `MapGenericRightsToFileSystemRights`, not a caller; do not test/remove an
unused helper merely to improve a percentage.

## Lab and rollback evidence

`WindowsAccessControlLab`: F1ADC1, F1BDC1, F2DC1, F3DC1, F1AFile1 (client),
and F1AFile2 (file server), all Windows Server 2025. Before the run,
authenticated WinRM, LDAP RootDSE, Kerberos tickets, member secure channels,
and clocks passed. No VM topology or operating system was changed.

Six checkpoints named `ntfs-qg-3442194-before-acceptance` exist. Hyper-V
reports them as Standard. A temporary ProductionOnly request on F1AFile1
also succeeded but reported Standard; its original policy was restored.
Production classification remains unverified. No checkpoint was restored;
these are not verified Production rollback evidence.

## Live results

Controller ran from 09:20 to 09:51 UTC against hash-checked published rc6
and the candidate, each version/edition in new processes. The new fixture
contains exactly one hidden file: the Delegate lists it over SMB with
`-Hidden` alone, and the Server verifies its content/attribute independently.

| Version | Edition | Role | Passed | Failed | Skipped |
| --- | --- | --- | ---: | ---: | ---: |
| Candidate | Desktop | Delegate | 39 | 0 | 0 |
| Candidate | Desktop | ServerAdmin | 13 | 0 | 0 |
| Candidate | Desktop | Admin | 40 | 0 | 0 |
| Candidate | Desktop | Server | 73 | 0 | 1 |
| Candidate | Core | Delegate | 39 | 0 | 0 |
| Candidate | Core | ServerAdmin | 13 | 0 | 0 |
| Candidate | Core | Admin | 40 | 0 | 0 |
| Candidate | Core | Server | 73 | 0 | 1 |
| Published rc6 | Each edition | Delegate | 38 | 1 | 0 |
| Published rc6 | Each edition | ServerAdmin | 13 | 0 | 0 |
| Published rc6 | Each edition | Admin | 39 | 1 | 0 |
| Published rc6 | Each edition | Server | 73 | 0 | 1 |

Candidate aggregate: 330 passed, zero failed, two expected skips (Server
does not import the module). rc6 aggregate: 326 passed, four expected
failures, two skips. The only rc6 failures are Hidden and the already-known
rc7 effective-access warning-text expectation, once each per edition.

The temporary host verifier initially failed because Desktop wrapped the
JSON array and failure names included Describe prefixes. A corrected
verifier flattened the array, checked all 16 unique version/edition/role
results and exact failure names, and passed in both editions on the
unchanged results. Original raw logs/exit markers were preserved.

## Cleanup and review

RemoveFixture ran at 09:57 UTC. An overly broad host Error.Count check gave
its wrapper a failing marker despite the controller completing. Independent
read-only probes verified on all six machines: zero test OUs/users/groups,
no share or fixture folders, no test local-group memberships, no test
profiles. Cleanup is proved by end state, not that wrapper marker.

One independent read-only code review approved the diff with high
confidence and no significant issues or confirmed exploitable vulnerability.
The custom security-reviewer could not start because its configured model
was unavailable; the built-in code-review agent performed the one review.
No source changed after that pass; result-verifier repairs were temporary
host tooling only.

## Evidence and remaining release gates

Raw coverage XML, eligibility/inventory CSVs, final suite XML/logs,
mutation logs, module/package hashes, full live role results, original host
logs, corrected verification, and independent cleanup evidence are retained
in the session artifact `quality-gate-3442194-20261009`.

Remaining: finer uncovered-path inventory, Decision 22 review, integration
and CI of this branch, publication and published-package acceptance, wider
OS matrix, and non-Windows #34 feedback. All 13 deployed lab VMs remain
Server 2025. Windows 11/Server 2019/2022 ISO media exists, but detected
editions/OS cache and matrix scope are not yet verified. #34 has no reply
since 2026-10-06. Do not release stable 5.0.0 on the strength of this record.
