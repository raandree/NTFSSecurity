---
status: current
last-verified: 2026-10-10
owner: software-engineer
source: release gates of 5.0.0 (lab acceptance, OS matrix, publication plan), repository evidence
---

# Deployment notes

## Publish the next prerelease (rc7)

State on 2026-10-10 at 09:59 UTC: #116 (rc7, head `d25647d`) is merged into
`master` (merge commit `8a6be9f`, 09:10:12Z). #117 (head `f11ff41`, base
`ai/release-5.0.0-rc7`) was **closed without a merge** at 09:10:16Z: the
`--delete-branch` of `gh pr merge 116` deleted its base branch, and GitHub
closed it (events `base_ref_deleted`, then `closed`) instead of retargeting it.
Nothing is lost: `ai/quality-gate-coverage` is intact at `f11ff41`, and
`master` still lacks its change (25 files). #118 (draft, head `83149ee`, base
`ai/quality-gate-coverage`) and #119 (draft, head `49734ef`, base
`ai/quality-gate-paths`) are open and green. A simulated merge chain
(`git merge-tree --write-tree`, no ref written) with merge commits
(Decision 15) is conflict-free at every step: the coverage branch into `master`
gives the tree of `f11ff41`, #118 then gives `b1dc006`, and #119 gives
`62aa1ae`, the tree of the matrix branch. The manifest says `5.0.0` with
`Prerelease = 'rc7'`, and `$publishedVersions` in `Tests/Repository.Tests.ps1`
lists the versions up to rc6, as it must before rc7 is published.

The branch `ai/quality-gate-lab-matrix` (draft #119) is stacked on #118. It
holds three fixes of the module in two commits (`962887a` has two, `fdd7a8b`
one). `fdd7a8b` reverts cleanly on its own; `962887a` doesn't
revert while `fdd7a8b` stays (the two conflict in `Security2/Win32/Lib.cs` and
`CHANGELOG.md`), and its two fixes go together. The branch also holds the kit of the
operating-system matrix, the changes of the live controller, and the record
(Decision 24). rc7 contains the module fixes only if the branch is merged after
#118 and before the tag; otherwise they go to the next prerelease. The
maintainer decides.

Do not delete a head branch while another open pull request uses it as its
base. On 2026-10-10 the deletion through `gh pr merge --delete-branch` closed
#117 instead of retargeting it. The open reports `cli/cli#1168` and
`cli/cli#14223` show the same two events and say that GitHub retargets only
when the branch is deleted with the button on the pull request page. The
latter also reports, and this was not tried here, that `gh pr edit --base`
refuses a closed pull request and that `gh pr reopen` refuses while the base
branch is missing. A new pull request from the same head is the repair.

1. Open a new pull request from `ai/quality-gate-coverage` to `master` (it
   replaces #117, same head and title), wait for its CI, and merge it with
   **Create a merge commit**. Do not delete the branch yet.
2. Retarget #118 (`gh pr edit 118 --base master`), mark it ready, and merge it
   the same way. Then do the same for #119 if its module fixes go into rc7.
   A retarget doesn't start CI again (`pull_request` in `ci.yml` has the
   default event types), and the merge result is the tree that CI tested.
3. Delete the head branches only after the last pull request that uses one as
   its base is merged or retargeted.
4. Tag the merge commit on `master` with `5.0.0-rc7` and push the tag. The
   `release` job checks the tag against the manifest and builds nothing new:
   it publishes the package that the `build` job tested. Approve the
   deployment of the `powershell-gallery` environment if it asks.
5. After the publication, add `5.0.0-rc7` to `$publishedVersions` with the
   next change that goes to `master`.

## Accept a published package

Local `-ModulePath` runs are validation; the gate needs the published bytes.

1. `Tests/Lab/Acceptance/Test-PublishedRelease.ps1 -Version <version>
   -OutputPath <folder>` (read-only): tag and commit on `master`, the CI run
   of the tag, the Gallery's SHA-512 against the downloaded nupkg (ordinal,
   case-sensitive base64), the nupkg against the GitHub zip file by file, and
   the identity of the manifest. Dry run on rc6: all checks passed.
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
3. Remove the fixture and check the end state independently with
   `Test-MatrixCleanup.ps1`, which takes the lab name and the machine names
   (`-LabName WindowsAccessControlLab -DomainController F1ADC1, F1BDC1, F2DC1,
   F3DC1 -Machine F1AFile1, F1AFile2` for the existing lab).
4. If the published binary changes, repeat the cells; never combine runs of
   different binaries into one matrix.

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
  waiting (see `techContext.md`). The controller names the account of case 3 anew
  for each new fixture; a script of your own that recreates accounts needs unique
  names too.
- Restart the evaluation client (`OSWin11E`) right before a sequence or a suite,
  not before several: it shuts down an hour after each start. The restart takes
  about two and a half minutes and may need the repair of the secure channel.
