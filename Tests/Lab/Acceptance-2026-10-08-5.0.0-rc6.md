# Lab acceptance of 5.0.0-rc6

Acceptance of the release candidate 5.0.0-rc6 in the lab, on 2026-10-08,
before the pull request. It follows the procedure in the
[README](README.md#acceptance-of-a-release-candidate).

## Candidate

- Branch `ai/release-5.0.0-rc6`, commit
  `acfe3af4cf184e6b12b0bf9b20a8a4d65149b01c`, 26 commits on `fcb370e`
  (5.0.0-rc5).
- Release build of that commit, packaged with
  `.github\scripts\New-ModulePackage.ps1`. The live tests imported the
  module from the extracted `NTFSSecurity.zip`. CI builds the packages that
  the tag publishes again, so their hashes differ; the live tests run once
  more against the published package.

| SHA-256 | File |
| --- | --- |
| `30F9694556CB3ADB57D0455AC8E917FA7DC405770DAD3F8C37F42337AECE6374` | `NTFSSecurity.5.0.0-rc6.nupkg` |
| `2A1E5482A67167658A33C7977D7251681F25D4EA437C06B441B5EAAC1016EF55` | `NTFSSecurity.zip` |
| `D308BD24061DEBB633F7A11C924D6347457C530924ACDD4893BEA48BEC58B63E` | `NTFSSecurity\NTFSSecurity.dll` |
| `32C8EA2A55F8721F7953A4E1DE382E1DA6D1CD4BBA844347DD1CA4DA38661D04` | `NTFSSecurity\Security2.dll` |
| `902157ABBD2E0B76DA744A918BDD174D5226C3494908ABA75F9E5DE28AE6A008` | `NTFSSecurity\ProcessPrivileges.dll` |
| `E2077AFEB38703345AE7857C1266F8B26E167ED887BFFAC8C8169A8F267BE6E9` | `NTFSSecurity\PrivilegeControl.dll` |
| `A8DA47194AB0F71232C69D01955AD93BA73C7ECEB58D0DE800CA085D4A2E18D8` | `NTFSSecurity\AlphaFS.dll` |
| `75DA9F7A54DF7011968BACB3FDF5E30B33F4C078861D1DF87BC06F5E64A962D8` | `NTFSSecurity\NTFSSecurity.psd1` |
| `3F777E9D141EE0046119DA9D5ECF88A3BC7E023726098FE2FB150528E2FB59B8` | `NTFSSecurity\NTFSSecurity.psm1` |
| `59583423241951EBE0FC2D8237D0C28C3ECC8C7CD2C115D2660F8579888632FC` | `NTFSSecurity\NTFSSecurity.Init.ps1` |
| `FB0920CC37ED858F55AFD54998DC854E27FBBE6A0177CB059CB03CFE91361197` | `NTFSSecurity\NTFSSecurity.format.ps1xml` |
| `CB6882FF91E6716605D5599E7B464C3346E461216ACED07E847621738F04FB9B` | `NTFSSecurity\NTFSSecurity.types.ps1xml` |
| `DF9657E224E1DDA6D933099A3A09F7E794391B307FD4DDD1C8358049961BF146` | `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml` |

## Tests without a lab

The Pester suite of the commit, 657 tests, against the same build. No test
failed, and every test ran in at least one configuration.

| Configuration | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 635 | 0 | 22 |
| PowerShell 7, elevated | 605 | 0 | 52 |
| Windows PowerShell 5.1, basic user | 566 | 0 | 91 |
| PowerShell 7, basic user | 536 | 0 | 121 |

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

Readiness, 11:06 to 11:07 UTC: WinRM answered on all six machines. The
four domain controllers answered LDAP (RootDSE, synchronized) and issued a
Kerberos ticket for `krbtgt`. The client and the file server found a
domain controller, had a working secure channel, and got a service ticket
for each other. The clocks were 4.3 to 5.0 seconds ahead of the host.

Checkpoint `ntfs-rc6-acfe3af-before-acceptance` (Production) of the six
machines, taken 11:07 to 11:08 UTC before the run.

## Results

`Invoke-NTFSSecurityLabTest.ps1 -ModulePath <extracted package>` in both
editions, 11:08 to 11:25 UTC. The module reported version 5.0.0-rc6 in
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

`Invoke-NTFSSecurityLabTest.ps1 -RemoveFixture`, 11:38 UTC, after the
baseline. The check compared the lab with the 10 SIDs of the fixture's
accounts and groups, read before the removal; the same check had found the
fixture before the removal:

- No domain has the organizational unit `NTFSSecurityLive` or an account
  whose name starts with `NtfsLive`.
- The file server has no share `NTFSSecurityLive`, no folder
  `C:\NTFSSecurityLive` or `C:\NTFSSecurityLab`, and no local group
  `NtfsLiveLocal`.
- The client has no folder `C:\NTFSSecurityLab`.
- On both machines, Administrators, Access Control Assistance Operators,
  and Remote Management Users have no member of the fixture, and no
  profile of the fixture's accounts is left.

The checkpoint `ntfs-rc6-acfe3af-before-acceptance` stays on the six
machines until the maintainer deletes it.

## Not covered

- Other operating systems than Windows Server 2025, such as a Windows 11
  client and Server 2019 or 2022 file servers: Phase 3 of the quality
  gate.
- File servers that aren't Windows, such as the IBM ESS system of #34:
  only the feedback of the reporter covers them.
- The package that CI publishes for the tag: the live tests run against it
  after the release, with `-Version 5.0.0-rc6`.
