# Lab acceptance of 5.0.0-rc6

Acceptance of the release candidate 5.0.0-rc6 in the lab, on 2026-10-08,
before the pull request. It follows the procedure in the
[README](README.md#acceptance-of-a-release-candidate).

The candidate changed twice during the acceptance. The run of `acfe3af`
passed; the coverage report of the candidate then found three defects,
which `0df2482` and `1b9edbb` fix, and the run of `1b9edbb` passed as
well; a second review led to `7b0781f`. This record describes the run of
`7b0781f`, the last commit of the pull request that changes the module,
and names the results of the earlier runs.

## Candidate

- Branch `ai/release-5.0.0-rc6`, commit
  `7b0781ff8bb2c1ee4087a16411acd4c7070ba1fa`, 31 commits on `fcb370e`
  (5.0.0-rc5).
- Release build of that commit, packaged with
  `.github\scripts\New-ModulePackage.ps1`. The live tests imported the
  module from the extracted `NTFSSecurity.zip`. CI builds the packages that
  the tag publishes again, so their hashes differ; the live tests run once
  more against the published package.

| SHA-256 | File |
| --- | --- |
| `E99B5123F45E4F56AC005C629C2241DC616B2AAC152C17EA57A67C0823FFCA10` | `NTFSSecurity.5.0.0-rc6.nupkg` |
| `53C020EAD59467A407ED755F3D9296E9C70AFFAB184CF9CDF27AF92117FBBEE0` | `NTFSSecurity.zip` |
| `F438D7FDB3F5A1D75F5CA48D7B610EED31215FF1BF9C185C6856AA365D195C8D` | `NTFSSecurity\NTFSSecurity.dll` |
| `EE1B0DF9619C998A4482F3F79DCB2191BBEAD859660D6D924D1F333DBE7CBBCE` | `NTFSSecurity\Security2.dll` |
| `902157ABBD2E0B76DA744A918BDD174D5226C3494908ABA75F9E5DE28AE6A008` | `NTFSSecurity\ProcessPrivileges.dll` |
| `E2077AFEB38703345AE7857C1266F8B26E167ED887BFFAC8C8169A8F267BE6E9` | `NTFSSecurity\PrivilegeControl.dll` |
| `A8DA47194AB0F71232C69D01955AD93BA73C7ECEB58D0DE800CA085D4A2E18D8` | `NTFSSecurity\AlphaFS.dll` |
| `75DA9F7A54DF7011968BACB3FDF5E30B33F4C078861D1DF87BC06F5E64A962D8` | `NTFSSecurity\NTFSSecurity.psd1` |
| `3F777E9D141EE0046119DA9D5ECF88A3BC7E023726098FE2FB150528E2FB59B8` | `NTFSSecurity\NTFSSecurity.psm1` |
| `59583423241951EBE0FC2D8237D0C28C3ECC8C7CD2C115D2660F8579888632FC` | `NTFSSecurity\NTFSSecurity.Init.ps1` |
| `FB0920CC37ED858F55AFD54998DC854E27FBBE6A0177CB059CB03CFE91361197` | `NTFSSecurity\NTFSSecurity.format.ps1xml` |
| `CB6882FF91E6716605D5599E7B464C3346E461216ACED07E847621738F04FB9B` | `NTFSSecurity\NTFSSecurity.types.ps1xml` |
| `5115D0D76CA2A06795CD754539AC7EC19A70591E8C5616E7BEB5AE66E6971E6D` | `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml` |

## Tests without a lab

The Pester suite of the commit, 684 tests, against the same build. No test
failed, and every test ran in at least one configuration.

| Configuration | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 662 | 0 | 22 |
| PowerShell 7, elevated | 632 | 0 | 52 |
| Windows PowerShell 5.1, basic user | 590 | 0 | 94 |
| PowerShell 7, basic user | 560 | 0 | 124 |

The C# coverage of the four configurations, measured with AltCover on
`1b9edbb`: 68.1% of the lines and 44.3% of the branches.

## Lab

`WindowsAccessControlLab` (AutomatedLab on Hyper-V). Every machine runs
Windows Server 2025 Datacenter (10.0.26100).

| Machine | Domain | Role in the tests |
| --- | --- | --- |
| `F1ADC1` | `a.forest1.net` | Domain controller of the accounts |
| `F1AFile1` | `a.forest1.net` | Client that runs the tests |
| `F1AFile2` | `a.forest1.net` | File server with the share |
| `F1BDC1` | `b.forest1.net` | Account of another domain of the forest |
| `F2DC1` | `forest2.net` | Account of another forest |
| `F3DC1` | `forest3.net` | Account of another forest |

Readiness, checked before each run: WinRM answered on all six machines.
The four domain controllers answered LDAP (RootDSE, synchronized) and
issued a Kerberos ticket for `krbtgt`. The client and the file server
found a domain controller, had a working secure channel, and got a service
ticket for each other. The clocks were 4.3 to 5.0 seconds ahead of the
host.

Checkpoints (Production) of the six machines, taken before each run:
`ntfs-rc6-acfe3af-before-acceptance` (11:07 UTC),
`ntfs-rc6-1b9edbb-before-acceptance` (12:21 UTC), and
`ntfs-rc6-7b0781f-before-acceptance` (12:50 UTC).

## Results

`Invoke-NTFSSecurityLabTest.ps1 -ModulePath <extracted package>` in both
editions, 12:51 to 13:07 UTC. The module reported version 5.0.0-rc6 in
every role that loads it.

| Edition | Role | Passed | Failed | Skipped |
| --- | --- | ---: | ---: | ---: |
| Windows PowerShell 5.1 | Delegate | 38 | 0 | 0 |
| Windows PowerShell 5.1 | ServerAdmin | 13 | 0 | 0 |
| Windows PowerShell 5.1 | Admin | 40 | 0 | 0 |
| Windows PowerShell 5.1 | Server | 72 | 0 | 1 |
| PowerShell 7 | Delegate | 38 | 0 | 0 |
| PowerShell 7 | ServerAdmin | 13 | 0 | 0 |
| PowerShell 7 | Admin | 40 | 0 | 0 |
| PowerShell 7 | Server | 72 | 0 | 1 |

The role Server skips the check of the module version, because it doesn't
load the module. The accounts of the other domain and forests were
`B\NtfsLiveForeign`, `forest2\NtfsLiveForeign`, and
`forest3\NtfsLiveForeign`; their 13 tests passed in both editions.

The earlier runs had the same counts and no failure: `acfe3af` from 11:08
to 11:25 UTC, and `1b9edbb` from 12:23 to 12:39 UTC.

## Baseline

The published 5.0.0-rc5 from the PowerShell Gallery, whose hash the script
checks against the one the Gallery publishes, in Windows PowerShell 5.1,
11:26 to 11:34 UTC: Delegate 38 passed, ServerAdmin 13, Admin 38 passed and
2 failed, Server 72 passed and 1 skipped. The two failures are the defect
that 5.0.0-rc6 fixes: on the share, `Get-NTFSHardLink` and
`New-NTFSHardLink -PassThru` stopped with the terminating error "(50) The
request is not supported" instead of writing a `GetHardLinkError`. The new
cases find no other difference between the two versions; the local tests
cover the other fixes of 5.0.0-rc6.

## Cleanup

`Invoke-NTFSSecurityLabTest.ps1 -RemoveFixture` after each run: at 11:38
UTC after the first run and the baseline, at 12:48 UTC after the second,
and at 13:09 UTC after the third. Each check compared the lab with the 10
SIDs of the fixture's accounts and groups, read before the removal; the
same check had found the fixture before the first removal. After each
removal:

- No domain has the organizational unit `NTFSSecurityLive` or an account
  whose name starts with `NtfsLive`.
- The file server has no share `NTFSSecurityLive`, no folder
  `C:\NTFSSecurityLive` or `C:\NTFSSecurityLab`, and no local group
  `NtfsLiveLocal`.
- The client has no folder `C:\NTFSSecurityLab`.
- On both machines, Administrators, Access Control Assistance Operators,
  and Remote Management Users have no member of the fixture, and no
  profile of the fixture's accounts is left.

The three checkpoints stay on the six machines until the maintainer
deletes them.

## Not covered

- Other operating systems than Windows Server 2025, such as a Windows 11
  client and Server 2019 or 2022 file servers: Phase 3 of the quality
  gate.
- File servers that aren't Windows, such as the IBM ESS system of #34:
  only the feedback of the reporter covers them.

## After the release

The tag `5.0.0-rc6` on `b51d970`, the merge of #115, published the package
to the PowerShell Gallery on 2026-10-08 at 20:40 UTC. The **Release** job
failed after the upload: `Publish-PSResource` stopped waiting for the
Gallery after 100 seconds while the Gallery accepted the package, and its
second attempt got the error 409, "already exists". So the job didn't
create the GitHub release; rerunning the failed job creates it, as
[If a release fails](../../Docs/Contributing/05-Releasing.md#if-a-release-fails)
describes.

`Invoke-NTFSSecurityLabTest.ps1 -Version 5.0.0-rc6` downloaded the package
from the Gallery, checked it against the SHA-512 that the Gallery
publishes, and ran in both editions, 20:43 to 21:00 UTC. The SHA-256 of
`NTFSSecurity.5.0.0-rc6.nupkg` is
`83EBCADEE0698A9523661352A69B9D25F6EB2903F45A6C4FAB36F5BF4B139100`.

The live tests came from the branch of 5.0.0-rc7, which expects the
warning of `Get-NTFSEffectiveAccess` for a computer that can't be reached
to name the computer. The package failed only that test, in the role Admin
of both editions, with exactly the text that the live tests of 5.0.0-rc6
expect; every other test passed: Delegate 38, ServerAdmin 13, Admin 39,
and Server 72 with 1 skipped, in each edition. The fixture was removed at
21:03 UTC, and its removal checked as above.
