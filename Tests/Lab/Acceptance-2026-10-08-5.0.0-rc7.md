# Lab acceptance of 5.0.0-rc7

Acceptance of the release candidate 5.0.0-rc7 in the lab, on 2026-10-08,
before the pull request. It follows the procedure in the
[README](README.md#acceptance-of-a-release-candidate).

The candidate holds the behavior changes that Phase 2 of the quality gate
found, which the agent decided as assumptions for the maintainer's review,
and the fixes of one review. A run of the code of `4ee01e5`, packaged
before the commit that sets the label, so that it reported 5.0.0-rc6,
passed; the review then led to `7936d9f` to `dc6e9f5`. The first run of
`dc6e9f5` started without the checkpoint of step 3, so it was repeated
after the checkpoint. This record describes the repeated run of
`dc6e9f5`, the last commit of the branch that changes the module, and
names the results of the earlier runs.

## Candidate

- Branch `ai/release-5.0.0-rc7`, commit
  `dc6e9f5359bb02bd173dc2174dd7bca8add2df86`, 10 commits on `be04cb7`
  (the head of the pull request of 5.0.0-rc6, #115).
- Release build of that commit, packaged with
  `.github\scripts\New-ModulePackage.ps1`. The live tests imported the
  module from the extracted `NTFSSecurity.zip`. CI builds the packages that
  the tag publishes again, so their hashes differ; the live tests run once
  more against the published package.

| SHA-256 | File |
| --- | --- |
| `2273126D91A1A737F0EDF8350A7E90FFC4FD7CB6A1AEA8306874FC8517349C3C` | `NTFSSecurity.5.0.0-rc7.nupkg` |
| `38B39930D92EF3FCD03FD60E05E678D5645C77BB34EA677E053F78F779ECE668` | `NTFSSecurity.zip` |
| `710C83A498700AA36DAE02272E2556EEC58655DE7CA5570CE870F64DFBAF53A9` | `NTFSSecurity\NTFSSecurity.dll` |
| `8876D0AFE2156581FE31369982DD9A117FFE38C52179409FC11AC95A9A3D68C1` | `NTFSSecurity\Security2.dll` |
| `902157ABBD2E0B76DA744A918BDD174D5226C3494908ABA75F9E5DE28AE6A008` | `NTFSSecurity\ProcessPrivileges.dll` |
| `E2077AFEB38703345AE7857C1266F8B26E167ED887BFFAC8C8169A8F267BE6E9` | `NTFSSecurity\PrivilegeControl.dll` |
| `A8DA47194AB0F71232C69D01955AD93BA73C7ECEB58D0DE800CA085D4A2E18D8` | `NTFSSecurity\AlphaFS.dll` |
| `968514234BAAF16789A560C86A6F701F69E91262F1EAB62142DDF6D05A8D2A52` | `NTFSSecurity\NTFSSecurity.psd1` |
| `3F777E9D141EE0046119DA9D5ECF88A3BC7E023726098FE2FB150528E2FB59B8` | `NTFSSecurity\NTFSSecurity.psm1` |
| `59583423241951EBE0FC2D8237D0C28C3ECC8C7CD2C115D2660F8579888632FC` | `NTFSSecurity\NTFSSecurity.Init.ps1` |
| `FB0920CC37ED858F55AFD54998DC854E27FBBE6A0177CB059CB03CFE91361197` | `NTFSSecurity\NTFSSecurity.format.ps1xml` |
| `CB6882FF91E6716605D5599E7B464C3346E461216ACED07E847621738F04FB9B` | `NTFSSecurity\NTFSSecurity.types.ps1xml` |
| `3550E659932EE61A96C6049477C14FE08F131114104BBCB9551C4B1AEA605816` | `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml` |

## Tests without a lab

The Pester suite of `1063b29`, 712 tests, against the same build; the
commits after `dc6e9f5` change only tests. No test failed, and every test
ran in at least one configuration.

| Configuration | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 688 | 0 | 24 |
| PowerShell 7, elevated | 658 | 0 | 54 |
| Windows PowerShell 5.1, basic user | 612 | 0 | 100 |
| PowerShell 7, basic user | 582 | 0 | 130 |

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

Readiness, checked before the run: WinRM answered on all six machines.
The four domain controllers answered LDAP (RootDSE, synchronized) and
issued a Kerberos ticket for `krbtgt`. The client and the file server
found a domain controller, had a working secure channel, and got a service
ticket for each other. The clocks were 4.2 to 4.9 seconds ahead of the
host.

Checkpoints (Production) of the six machines, taken before the run:
`ntfs-rc7-dc6e9f5-before-acceptance` (16:24 UTC).

## Results

`Invoke-NTFSSecurityLabTest.ps1 -ModulePath <extracted package>` in both
editions, 16:24 to 16:40 UTC. The module reported version 5.0.0-rc7 in
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

The earlier runs had the same counts and no failure: the code of
`4ee01e5` from 15:32 to 15:49 UTC, and the first run of `dc6e9f5`, without
a checkpoint, from 16:04 to 16:20 UTC.

## Baseline

None. 5.0.0-rc6 isn't published yet, and the live tests changed only in
the text that they expect from the warning of `Get-NTFSEffectiveAccess`
for a computer that can't be reached, which names the computer now. The
local tests cover the other changes of 5.0.0-rc7.

## Cleanup

`Invoke-NTFSSecurityLabTest.ps1 -RemoveFixture` at 16:21 UTC, after the
first two runs, and at 16:44 UTC, after the acceptance. Each check
compared the lab with the 10 SIDs of the fixture's accounts and groups,
read before the removal, which found the fixture. After each removal:

- No domain has the organizational unit `NTFSSecurityLive` or an account
  whose name starts with `NtfsLive`.
- The file server has no share `NTFSSecurityLive`, no folder
  `C:\NTFSSecurityLive` or `C:\NTFSSecurityLab`, and no local group
  `NtfsLiveLocal`.
- The client has no folder `C:\NTFSSecurityLab`.
- On both machines, Administrators, Access Control Assistance Operators,
  and Remote Management Users have no member of the fixture, and no
  profile of the fixture's accounts is left.

The checkpoint stays on the six machines until the maintainer deletes it.

## Not covered

- Other operating systems than Windows Server 2025, such as a Windows 11
  client and Server 2019 or 2022 file servers: Phase 3 of the quality
  gate.
- File servers that aren't Windows, such as the IBM ESS system of #34:
  only the feedback of the reporter covers them.
- A folder that `Move-Item2` moves from the client to the share, another
  volume on another computer: the local tests move folders to
  `\\localhost\C$`, another volume over SMB on the same computer.
- The package that CI publishes for the tag: the live tests run against it
  after the release, with `-Version 5.0.0-rc7`.
