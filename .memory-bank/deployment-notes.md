---
status: current
last-verified: 2026-11-11
owner: software-engineer
source: release gates of 5.0.0 (lab acceptance, OS matrix, publication plan), repository evidence
---

# Deployment notes

## Publish the next prerelease (rc9a is published)

State on 2026-11-11: `5.0.0-rc9a` is published and accepted (record
`Tests/Lab/Acceptance-2026-11-11-published-rc9a.md`). #135 (`c135062`, merged
13:58Z) carries rc9's code and the final release notes (Decision 21); the
maintainer pushed the lightweight tag, and the CI run `43039152538` of the tag
passed (Build and test, then Release). The Gallery has rc9a since 14:42:14Z,
GitHub since 14:42:22Z; `Test-PublishedRelease.ps1 -Version 5.0.0-rc9a`
verified the identity at 14:57Z and again in the chain. The published bytes of
rc9a:

- `NTFSSecurity.dll` SHA-256
  `EBA00A6738E9B9323F0E113582BCFFF288D152F5788A36F95D6828DC2B444BC5`
- `NTFSSecurity.zip` SHA-256 (equals the GitHub asset digest)
  `3B72CB20A1C4DA82D4BAC17E61F82AA8351732F6942D84662F482452D8447B9F`
- nupkg SHA-256
  `60436BD4636E0C218D6C94D3D081671878372E8B986336F9C007ED245A355BA8`

A label after `rc9` has to sort after it: the Gallery and PSResourceGet compare
labels as text, and NuGet.Versioning 6.9.1.3 ranks `5.0.0-rc10` below
`5.0.0-rc9` and `rc9a` and `rtm` above it, so with `rc10`, `Install-Module
-AllowPrerelease` and `Update-Module` would keep installing rc9.
`Get-ReleaseInfo.ps1` and `Publish-ModulePackage.ps1` accept a label of
letters, digits, and hyphens that starts with a letter; the lab scripts accept
letters and digits.

State on 2026-11-10: rc9 is published. #131
(`823c814`, merged 2026-10-22 08:13Z; the tree equals the validated head
`696ac38`) and #132 are merged, and the maintainer pushed the lightweight tag
`5.0.0-rc9` at `823c814` at about 08:37Z. The CI run `39749188259` of the tag
passed (Build and test, then Release without an approval step). The Gallery
has rc9 since 08:50:59Z, GitHub since 08:51:19Z. `Test-PublishedRelease.ps1
-Version 5.0.0-rc9` verified the identity at 10:54Z (and again in the chain):
the Gallery's SHA-512 matches the nupkg, the 11 module files are
byte-identical in the nupkg and the GitHub zip, and the manifest says
`5.0.0-rc9`. The published bytes of rc9:

- `NTFSSecurity.dll` SHA-256
  `464CAB365AD63CD22208B21012A5B7F0B8B630E819CF300019787A0172791198`
- `NTFSSecurity.zip` SHA-256
  `5A05BC008605D9B4B1EAB074FFC811B460FAF6D3549701D00ABA15D9208ED571`
- nupkg SHA-256
  `72CC5E28567BEC564DB052AF34C91F237ECFC9558FA2E981E201E02E16B4F8F3`

State on 2026-10-20 at 12:40 UTC: rc8 was published. #127 (`c719197`, 10:27:39Z:
the fix of `Get-NTFSEffectiveAccess`, the hard-link known limit, the label
`rc8`) and #126 are merged. The maintainer pushed the lightweight tag
`5.0.0-rc8` at `c719197` at about 10:28Z. The CI run `39408140862` of the tag
passed: Build and test, then Release without an approval step, because the
`powershell-gallery` environment has no required reviewer. The Gallery has rc8
since 10:40:58Z, GitHub since 10:41:07Z, 13 minutes after the tag.
`Test-PublishedRelease.ps1 -Version 5.0.0-rc8` verified the identity at 10:42Z:
the tag commit is on `master`, the Gallery's SHA-512 matches the downloaded
nupkg, the 11 module files are byte-identical in the nupkg and the GitHub zip,
and the manifest says `5.0.0-rc8`. The published bytes of rc8:

- `NTFSSecurity.dll` SHA-256
  `D8CB4015BF25379C77A645F82EEECA54F86219F228A5029E32E4D52FBD016E79`
- `NTFSSecurity.zip` SHA-256
  `288152E20F8CFB1B029BAC055345339970C65BD57C8BA814C2616C32D9F812BC`
- nupkg SHA-256
  `EA90E16F2152016E97BFB3D2413D29F8944704E9D4FBD5101D0A263841BC0510`

rc7 was published on 2026-10-10 (tag `fa0701b`, CI run `38051611526`, Gallery
12:30:57Z, no approval step after the same stack of merges, see `progress.md`).
Its bytes:

- `NTFSSecurity.dll` SHA-256
  `D3B7CBE362C37D1016559669CB2EFF5034A6945CA1B03DDB49F1361363D203A7`
- `NTFSSecurity.zip` SHA-256
  `9705C8CCFA0FB8FC355E401444044D94BF176729BA84104D2C423C429AC1430B`
- nupkg SHA-256
  `40922397B7CB307C64DD99960659539AF5C8AD9D2F55C6BF26E8AB434DEC8DCC`

The release notes of a prerelease are the `[Unreleased]` section of
`CHANGELOG.md`.

1. Accept the published package (next section): done for rc7 (2026-10-10),
   rc8 (2026-10-20), rc9 (2026-11-10, in four parts after a host shutdown
   and a lost secure channel), and rc9a (2026-11-11, in one driver); the
   records are `Tests/Lab/Acceptance-2026-10-10-published-rc7.md`,
   `Tests/Lab/Acceptance-2026-10-20-published-rc8.md`,
   `Tests/Lab/Acceptance-2026-11-10-published-rc9.md`, and
   `Tests/Lab/Acceptance-2026-11-11-published-rc9a.md`. A build of 5.0.0 that
   differs by more than the label needs the same cells again.
2. The rc9a change adds `5.0.0-rc9` to `$publishedVersions` in
   `Tests/Repository.Tests.ps1` (the list ended at rc8), and the stable change
   adds `5.0.0-rc9a`, as `Docs/Contributing/05-Releasing.md` says. The test
   "Should not reuse a version that the PowerShell Gallery already has" fails
   when the list holds the version of the manifest. After each tag, `git diff
   --stat <previous tag> <tag> -- NTFSSecurity Security2 PrivilegeControl
   ProcessPrivileges Log` should list only the manifest.

## Accept a published package

Local `-ModulePath` runs are validation; the gate needs the published bytes.

1. `Tests/Lab/Acceptance/Test-PublishedRelease.ps1 -Version <version>
   -OutputPath <folder>` (read-only): tag and commit on `master`, the CI run
   of the tag, the Gallery's SHA-512 against the downloaded nupkg (ordinal,
   case-sensitive base64), the nupkg against the GitHub zip file by file, and
   the identity of the manifest. Run on rc6 (dry run) and on rc7 (2026-10-10,
   12:33Z): all checks passed.
2. `Tests/Lab/Invoke-NTFSSecurityLabTest.ps1 -Version <version>` in the
   existing lab, both editions, and `Tests/Lab/Acceptance/Run-MatrixSequence.ps1
   -Version <version>` for each cell of the matrix (Decision 24; pass the file
   servers as one quoted string, `-FileServer 'OSFile19,OSFile22,OSFile25'`, and
   start `OSWin11E` shortly before, because its license period ends an hour
   after each start). Check every role from the result files with
   `Validate-LabResults.ps1`, never from the marker `DONE` of the controller.
   Dry run of the `-Version` path of the sequence runner with the published rc6
   on OSFile19 (Desktop): the mechanics work, the failing tests are the newer
   ones that rc6 predates, and the cleanup verdict was CLEAN. The first lab ran
   the final local candidate through the same stages (readiness, controller,
   `Validate-LabResults.ps1`, snapshot, `-RemoveFixture`, `Test-MatrixCleanup.ps1`
   with the four domain controllers and both machines) in one detached driver.
   Published rc7 and rc8 ran in one detached driver each: the cells, then
   `Run-MatrixLocalSuite.ps1 -ModulePath <zip-<version>\NTFSSecurity of the
   identity check> -Mode Elevated,Basic` on the host and five machines (one
   every 75 seconds: AutomatedLab imports one lab at a time), then
   `Test-MatrixCleanup.ps1 -Mode Verify` (CLEAN at the first check, so the
   cells first and the suites after them leave nothing to repair), then the
   first lab. rc8 used `Chain-Published.ps1 -Version 5.0.0-rc8 -Tag rc8
   -Evidence <folder>` (session files `qg-unknowns\scripts`, not in the kit;
   68 minutes, 10:38 to 11:47Z). It restores the saved machines of both labs
   (`Start-LabMachines.ps1`: domain controllers first, a minute for the
   directory services), waits for the version on the Gallery, freezes the files
   of the tag in a worktree, runs the identity check and the readiness checks,
   starts `OSWin11E` right before the cells, and ends with the first lab
   (`Run-LiveAcceptancePublished.ps1`, `-Version` per edition) and a read-only
   check of both labs. Launch it after the tag, arm a heartbeat, and save the
   machines again when it is done. rc7 ran the older `Run-Gate3.ps1`.
3. Remove the fixture and check the end state independently with
   `Test-MatrixCleanup.ps1`, which takes the lab name and the machine names
   (`-LabName WindowsAccessControlLab -DomainController F1ADC1, F1BDC1, F2DC1,
   F3DC1 -Machine F1AFile1, F1AFile2` for the existing lab).
4. If the published binary changes, repeat the cells; never combine runs of
   different binaries into one matrix.
5. Extended kit (Handoff 6, 2026-11-10): the files of a commit instead of the
   tag. `Chain-Extended.ps1 -Version <v> -Tag <t> -Evidence <fresh folder>
   -KitRevision <commit> [-Lab First,Matrix] [-Stage ...]` runs the published
   module with that kit and logs both identities; `-DetectVersions a,b` with
   `-DetectCandidate first|none|<version>` runs the stage `detect`, and
   `Compare-Detect.ps1` joins two runs per edition, role, and test. The hour of
   the 22H2 client holds the three cells (about 25 minutes with case 11) but
   not the suites as planned (33 minutes in the earlier record, 17 in a2): run
   them in a second chain (`Chain-SuiteOnly2.ps1` restarts the client, gates on
   a lab-account session, and starts the six suites 75 seconds apart), then
   `Chain-Extended.ps1 -Tag a2 -SidTag a1 -Stage verify-matrix`. Write the
   coverage tables with PowerShell 7 (5.1 adds a BOM and orders ties
   differently) and the manifest with `Build-EvidenceManifest.ps1`. All in the
   session files `qg-unknowns\scripts`, not in the kit.
6. One driver for the whole acceptance (2026-11-11, rc9a, 82 minutes):
   `Run-PublishedAcceptance.ps1 -Evidence <fresh folder> -Version <v>` in the
   session files `f097ed24-…\files\scripts` runs, in Windows PowerShell 5.1,
   `Chain-Extended.ps1` (machines, identity, readiness), the start of
   `OSWin11E` and the gate of its channel (`Repair-ClientChannel2.ps1`) before
   the cells, `Chain-Extended.ps1` (matrix, first-lab, verify),
   `Chain-SuiteOnly2.ps1`, and `Chain-Extended.ps1 -Tag a2 -SidTag a1 -Stage
   verify-matrix`. Create the worktree of the kit (`<evidence>\worktree`)
   before it: when `Chain-Extended.ps1` creates it, git's "Preparing worktree"
   on stderr under `$ErrorActionPreference = 'Stop'` ends the chain in 5.1.
   `Start-Process -Wait` of 5.1 also waits for the children that a chain
   starts. For the suites of `Chain-SuiteOnly2.ps1` (folders
   `s-<tag>-<machine>-<machine>`), `Export-MatrixResults.ps1` needs
   `-ReferenceMachine <tag>-LOCAL-LOCAL`; `LOCAL` matches nothing and leaves
   the comparison of the skipped tests empty. `Build-PublishedRecordTables.ps1`
   (same folder) writes the four tables of the record.

## Lab lessons

- AutomatedLab 5.61 can't add machines to an imported lab (`Add-LabMachineDefinition`
  throws "Lab is already imported"), and `New-LabDefinition` under an existing
  name overwrites its metadata. New machines go into a new lab with its own
  switch and domain, and `-LabName` of the controller selects it.
- `Install-Lab -NetworkSwitches -BaseImages` creates the switch and the base
  images first; the base images of Server 2019, Server 2022, and Windows 11 Pro
  took about two to four minutes each from the ISO files. AutomatedLab
  adds records to the hosts file of the host, which `Remove-Lab` removes.
- The VMs have no internet: take PowerShell 7 and Pester 5.7.1 from the host
  (`Copy-LabFileItem`, `Install-LabSoftwarePackage`).
- AutomatedLab ignores the exit code of `bcdboot` when it builds a base image.
  The Server 2019 image that it built on this Server 2025 host got an empty
  EFI system partition: the `bcdboot` of the host fails with exit code 193,
  "Failure when attempting to copy boot files", on the 2019 boot files, and the
  VM failed to boot (Hyper-V event 18603, "failed to boot an operating
  system"; no memory demand, no IP, heartbeat `NoContact`). Check the EFI
  system partition of a new base image before the first VM: mount the image
  read-only (`Mount-DiskImage -Access ReadOnly`) and look for
  `EFI\Microsoft\Boot\bootmgfw.efi` (the images of Server 2022 and Windows 11
  Pro had 140 and 149 files). Repair a VM, not the base: stop the VM, mount its
  own differencing disk, run the `bcdboot.exe` of the image (`D:\Windows\System32\bcdboot.exe
  D:\Windows /s H: /f UEFI`), copy `bootmgfw.efi` to `EFI\Boot\bootx64.efi`,
  dismount, and start the VM. A changed base image would invalidate its
  differencing disks.
- The tool output of the agent masks text that looks like a secret, such as
  `-Password $password`, in what it shows. Test such a line by parsing the
  file, and don't repair it from the displayed text.
- A script that a detached process runs needs its own log, an exit marker, and
  an end-state check of its own; verify cleanup from the end state, not from
  its marker.
- Extend a deployed lab with one machine like this: in a process that never ran
  `Import-Lab`, call `Import-LabDefinition`, `Add-LabMachineDefinition`, and
  `Export-LabDefinition`, then `New-LabBaseImages` and `New-LabVM -Name <machine>`.
  `Install-Lab` has no per-machine selector, and `Add-LabMachineDefinition`
  throws as soon as `Get-Lab` returns a lab. `Add-OsMatrixMachine.ps1` does it
  after it copies the lab metadata to `C:\ProgramData\AutomatedLab\Backups`.
- Windows 11 22H2 (10.0.22621) has the empty EFI system partition problem too
  (`bcdboot` exit code 193 on the host); `Repair-OsMatrixBoot.ps1` repairs it.
  After `Mount-VHD` the host gives the NTFS partition a letter on its own; don't
  assign a second one.
- Run AutomatedLab processes one after the other. Two `Import-Lab` calls at the
  same time corrupt each other (XML errors, "No machines imported").
- Check the secure channel of every domain client before the first run
  (`Test-MatrixReadiness.ps1`). Windows 11 26H1 (10.0.28000.1836) joins a
  Server 2025 domain (10.0.26100.32690) but loses the channel: the client asks
  `NetrLogonGetCapabilities` for query level 2, the domain controller answers
  `0xC0000022`, and the client denies the channel. Rejoining doesn't help.
- A process that starts from a remoting session has every privilege enabled
  and no credentials of its own, so tests that expect disabled privileges fail
  (eight per edition). Run the suite of a VM as a scheduled task with a batch
  logon at the highest run level (`Register-ScheduledTask -RunLevel Highest
  -User -Password`): that token matches a CI runner. A restricted token (a basic
  user) can't run Pester's NUnit export, because it asks WMI for the
  environment, so write the JSON summary first.
- In Windows PowerShell 5.1, `$PSScriptRoot` is empty in a parameter default of a
  script that runs with `-File`; compute it in the body. `-File` passes an array
  as one string, so split on commas. With `$ErrorActionPreference = 'Stop'`, a
  line that a native command writes to stderr and that `2>&1` redirects is a
  terminating error; let the command write its errors to stdout.
- `Get-LocalGroupMember` fails with "Failed to compare two elements in the array"
  when the group holds an orphaned SID. Add members with `Add-LocalGroupMember`
  and ignore `MemberExistsException`; read and remove members with
  `net localgroup <name>` and `net localgroup <name> <SID> /delete`. The SIDs
  of a deleted account can't be found afterwards, so keep `fixture-sids.json`
  from before the removal of the organizational unit.
- An account that is deleted and created again with the same name made the
  remote authorization managers (the client's and the file server's) answer for
  about ten minutes as if it had no groups, so `Get-NTFSEffectiveAccess` returned
  no access; when the accounts are created again within seconds, the Kerberos S4U
  logons returned the old account on the domain controller and member servers for
  7 to 15 minutes. The five remedies tried (a ticket purge, `nltest /sc_reset`, a
  DNS flush, a restart of the Kerberos service, and waiting) helped only by
  waiting. A model with one lifetime (9.95 to 10.25 minutes) fits all 43
  Admin-role runs of 27 cells; the replay and the model are in the record of the
  matrix and in Decision 24. The controller names the account of case 3 anew
  for each new fixture; a script of your own that recreates accounts needs
  unique names too.
- `Wait-LabVM` waits for a heartbeat that a client may not report: retry
  `New-LabPSSession` instead of waiting longer. After an unplanned shutdown,
  test a domain session of the lab account, not `nltest /sc_verify` and not
  `Test-ComputerSecureChannel` in a session of the local account (both stay
  stale: on 2026-11-10 the latter returned True while the lab account got
  "Access is denied" from WinRM). Repair with `Test-ComputerSecureChannel
  -Repair -Credential <lab account>` from a session of the local account, and
  judge the repair by a session of the lab account again; that worked at the
  first attempt, 6.7 minutes after the boot.
- A detached chain does not survive a shutdown of the host. On 2026-10-22 a
  planned shutdown (System event 1074, started by `svchost` `ExHost`) ended the
  first acceptance chain 14 minutes in, and the host stayed off for 19 days with
  the 19 lab machines Off, not Saved. Ask for the host to stay on for the run;
  after a death without a marker, start the whole chain again with a fresh
  evidence folder.
- Restart the evaluation client (`OSWin11E`) right before a sequence or a suite,
  not before several: it shuts down an hour after each start. The restart takes
  about two and a half minutes and may need the repair of the secure channel.
- The lab VMs stay saved (`Save-VM`) between runs. After nine days, a restore in
  two waves (the domain controllers, a minute for the directory services, then
  the other machines) passed the readiness checks of both labs at the first
  attempt, about five minutes after the start. `Start-LabMachines.ps1` restores
  them, and `Save-VM` puts them back after the run.
- `Build-Release.ps1` of the session scripts links `packages` in a worktree to
  `V:\Git\NTFSSecurity\packages` with a junction and keeps the Roslyn compiler
  under `$env:TEMP\ntfs-build`; that cache was gone on 2026-11-10, after the
  host's long power-off, so a later build must restore it first. Remove such a
  junction with `cmd /c rmdir`, never with a recursive delete, before you remove
  a worktree. The 13 junctions of the rc9 worktrees were removed on
  2026-11-10, and the real folder is intact.
