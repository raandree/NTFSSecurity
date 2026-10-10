---
status: proposed
date: 2026-10-09
last-verified: 2026-10-10
owner: shared
source: agent decisions under the maintainer's delegation of 2026-10-09 (Handoff 2); the scope follows Decision 21, phase 3
---

# Decision 24: The operating-system matrix lab

- Context: Decision 21 requires the live tests on more operating systems,
  "such as a Windows 11 client and Server 2019 and 2022 file servers", and the
  published package must pass them. Every machine of `WindowsAccessControlLab`
  is Server 2025. Handoff 2 asks for the maintainer's approval of scope and
  topology before new VMs. On 2026-10-09 at 21:21 UTC the maintainer, going to
  bed, wrote "you can do whatever is required with the lab" and told the agent
  to decide and report later. The agent took that as the approval for the
  minimal matrix below and for nothing broader. It is the agent's decision, so
  the status stays `proposed` until the maintainer confirms it.
- Choice:
  1. Cells: a Windows 11 client with each file server (Server 2019 Datacenter
     10.0.17763.1217, Server 2022 Datacenter 10.0.20348.4773, Server 2025
     Datacenter 10.0.26100.32690), the module in Windows PowerShell 5.1 and
     PowerShell 7 in every cell. The client was planned as Windows 11 Pro
     26H1 (10.0.28000.1836). It cannot keep a secure channel to the Server 2025
     domain controller (see "What the deployment showed"), so the domain client
     is `OSWin11E`, Windows 11 Enterprise Evaluation 22H2 (10.0.22621.525), and
     the 26H1 machine `OSWin11` stays in the lab outside the domain for runs of
     the module's own tests. The reference cell of Decision 20 (Server 2025
     client and file server in `WindowsAccessControlLab`) stays as it is.
     Server 2019 and 2022 as clients are extra cells, to run the module on the
     older .NET Framework builds (Server 2019 has 4.7.2).
  2. Topology: a separate AutomatedLab lab `NtfsSecurityOsMatrixLab` with its
     own internal switch (`192.168.12.0/24`) and its own forest `osmatrix.net`:
     `OSDC1` (Server 2025, root domain controller), `OSFile19`, `OSFile22`,
     `OSFile25`, `OSWin11E`, and `OSWin11`. `Deploy-OsMatrixLab.ps1` deploys it
     with the maintainer's AutomatedLab and the VM path `V:\AutomatedLab-VMs`;
     `Add-OsMatrixMachine.ps1` adds a machine to the deployed lab; the
     payloads of the existing lab (PowerShell 7.6.3 and Pester 5.7.1 from the
     host, because the VMs have no internet) come from
     `Complete-OsMatrixLab.ps1`.
  3. Case 9 (accounts of other domains and forests) needs trusts to the
     forests of the existing lab, so the matrix cells run with
     `-ForeignDomainController @()`; the existing lab keeps that case. The final
     candidate ran it there (run `fl1`: 245 passed, 0 failed, 1 skipped per
     edition, 16 case-9 tests per edition).
  4. The controller of the repository runs in every cell with `-LabName`,
     `-DomainController`, `-FileServer`, and `-Client`. The matrix showed three
     defects of its setup and removal, fixed in `7d47316`: a recursive delete
     fails with "The directory is not empty" on Windows Server 2019 (and the
     stderr line ended the script before any retry, because `2>&1` under `Stop`
     is terminating in Windows PowerShell 5.1), `Get-LocalGroupMember` fails on
     an orphaned SID, and a vanished profile failed the client cleanup.
  5. The module's own behavior tests run on every machine as well
     (`Run-MatrixLocalSuite.ps1`), elevated and as a basic user, in both
     editions, as scheduled tasks so that the token matches a CI runner. This
     found three defects of the module, fixed in two commits on
     `ai/quality-gate-lab-matrix`: `Get-NTFSInheritance -SecurityDescriptor`
     and `Get-NTFSEffectiveAccess -ServerName ''` (`962887a`, two fixes), and
     `Get-NTFSEffectiveAccess` for a user who isn't an administrator on a
     computer in a domain (`fdd7a8b`, with a live test for the ServerAdmin
     role). The maintainer decides which of them belong to rc7.
- Why a separate lab: AutomatedLab 5.61 refuses to add machines to an
  imported lab, and defining a lab under an existing name would overwrite the
  metadata of its 13 machines. A separate lab leaves every shared machine,
  switch, domain, and account untouched, which Handoff 2 requires. Inside the
  new lab, a machine can be added with `Import-LabDefinition`,
  `Add-LabMachineDefinition`, and `Export-LabDefinition`, followed by the steps
  that `Install-Lab` runs for one machine; `Add-OsMatrixMachine.ps1` does this
  after it copies the lab metadata.
- Cost and rollback: six VMs (4 GB for the domain controller and both clients,
  3 GB for each file server), four new base images, measured at 17.8 GB for
  the differencing disks and 42.4 GB for the base images (about 60 GB on `V:`;
  my first estimate of 100 GB was too high). The deployment added twelve lines
  to the hosts file of the host, which `Remove-Lab` removes. To remove the
  matrix, run `Remove-Lab -Name NtfsSecurityOsMatrixLab` from AutomatedLab;
  nothing else depends on it. No existing machine, checkpoint, or lab was
  changed. A copy of the lab metadata from before the sixth machine is in
  `C:\ProgramData\AutomatedLab\Backups` (administrators only).
- What the deployment showed (the agent's decisions D11 to D23 of the night
  log, each reversible):
  - The base image of a Server 2019 or a Windows 11 22H2 machine had an empty
    EFI system partition: the `bcdboot` of the Server 2025 host fails with
    exit code 193 on their boot files, and AutomatedLab ignores the exit code,
    so the generation 2 machine fails with Hyper-V event 18603. The images of
    Server 2022 and Windows 11 26H1 are fine. `Repair-OsMatrixBoot.ps1` runs
    the `bcdboot` of the image itself on the differencing disk of the one
    machine and starts it.
  - The AutomatedLab driver sat in its file-server job wait with idle remote
    runspaces after all features were installed, so I stopped it and ran the
    rest by script.
  - Windows 11 26H1 (10.0.28000.1836) joins the domain but cannot keep the
    Netlogon secure channel to the Server 2025 domain controller
    (10.0.26100.32690). The client calls `NetrLogonGetCapabilities` with query
    level 2, which the protocol document describes as a check of the flags the
    client sent; the controller answers `STATUS_ACCESS_DENIED` (level 1 and
    `NetrServerAuthenticate` succeed), and the client denies the channel
    (`NlConfirmRequestedCapabilities: denying access ... 0xc0000022`).
    `Test-ComputerSecureChannel -Repair` can't help. Windows 11 22H2 against the
    same controller works (secure channel, Kerberos, readiness). This is an
    environment finding about two Microsoft builds, not about NTFSSecurity; the
    maintainer may want to know it for his own labs.
  - The Windows 11 Enterprise Evaluation 22H2 image (`OSWin11E`) is in
    notification mode from its first day and shuts down an hour after every
    start (`wlms.exe`, 0xC004F009 "grace time expired"): its install time was
    recorded on a clock about seven hours ahead, which was then corrected. One
    of its two rearms didn't help. After an unplanned shutdown its machine
    account password no longer matched (domain logons fail with 0xC000018D,
    `nltest /sc_verify` says `ERROR_INVALID_PASSWORD`);
    `Test-ComputerSecureChannel -Repair` with the lab account fixed it, and
    `/sc_verify` kept showing the old status afterwards, so test a domain
    session instead. A run on this machine has to stay under an hour from its
    start.
  - A profile of an account that a probe's scheduled task used stayed loaded on
    one server until it restarted; the probe now uses a new account name for
    every run.
  - The matrix cells of the live controller failed in the effective-access tests
    of the Admin role in the Windows Server 2022 cell (`rc7f`, `rc7h`, `rc7i`,
    and `rc7j`) in cells that followed each other, where the fixture was removed
    after a cell and created again with the same account names. This looked like
    a regression of the module (the audit read of `962887a` was the first suspect)
    until a replay of the same cells with the baseline and the final candidate
    alternating (`ab0` to `ab6`) failed the baseline in two of three cells and
    the final candidate in one of three (not counting the warm-up `ab0`). In a
    failing cell the remote
    authorization managers (the client's and the file server's) returned no
    groups for the current account while the Kerberos S4U logon, the name
    resolution, and the local manager were right in the same second. One model,
    in which a remote manager answers for an account name for about ten minutes
    after its first request, fits all 43 Admin-role runs of 27 cells; the
    predictions that I wrote down before three of the replay cells held (the
    weakest is `ab6`, 10.5 minutes after its entry, above the lifetimes that
    fit). The mechanism in Windows isn't known. The controller now gives a new
    fixture a new name for the account of case 3 (`1dec389`); four more cells
    with it (`ab7` to `ab10`) passed, two of them at positions where the model
    predicts a failure for a reused name. The record has the evidence.
- Result: [the record](../../Tests/Lab/Acceptance-2026-10-10-os-matrix.md). The
  final candidate (`fdd7a8b`) passes the module's suite on all five machines
  and the host in all four configurations, and the live cells (see the record).
  The published 5.0.0-rc7 passed the same stages on 2026-10-10 with the same
  counts: the three cells (1,374 passed, 0 failed, 12 skipped), the suite in 24
  runs, and the first lab with case 9 (245 / 0 / 1 per edition); see
  [its record](../../Tests/Lab/Acceptance-2026-10-10-published-rc7.md).
- Open: the maintainer confirms or changes the matrix and decides whether to
  keep the VMs after 5.0.0. A stable 5.0.0 is a new build, so the release
  procedure accepts the last prerelease; a changed binary needs the same cells
  again. The newest Windows 11 build that can join a Server 2025 domain here is
  22H2; a domain cell with 26H1 needs a newer domain controller build or a fix
  of the mismatch. All three module fixes went into rc7 (#119; `962887a` holds
  two, `fdd7a8b` one, and they don't revert separately). The maintainer also
  decides whether the evaluation client stays (it needs a start shortly before
  every run) or is replaced by a client with a license that doesn't expire.
