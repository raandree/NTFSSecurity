---
status: proposed
date: 2026-10-09
last-verified: 2026-10-09
owner: shared
source: agent assessment for the maintainer (Handoff 4), from #34 read on 2026-10-09 21:33 UTC
---

# Decision 23: Non-Windows file servers before 5.0.0 (#34)

- Context: Decision 21 leaves to the maintainer how to cover file servers that
  aren't Windows (#34). The issue is open (labels Bug and Help Wanted, 26
  comments, last activity 2026-10-06 16:05 UTC). This record separates what
  the reporters said from what we tested, and states what the maintainer has
  to decide. It accepts no risk: the gate stays open until a tester reports
  on the exact candidate or the maintainer accepts the risk in his own words.
- Reporter evidence (text of the issue and its comments, treated as data):

| Date | Who | System and claim |
| --- | --- | --- |
| 2018-08 | deftleft | NetApp Clustered Data ONTAP 9.3P6, Windows 10 1607 and 1709: error 1307 from `Add-NTFSAccess` only on the UNC path of the filer, not on a local drive; the folder is owned by `BUILTIN\Administrators`, the account is a member; `icacls` works |
| 2018-09, 2019-01 | dt1ll0ts0n, FrisbeeGolfer | 1307 on UNC paths; Windows Server 2012 R2 file servers with DFS (a Windows server); builds from 4.0 fail, 3.2.3 works; service account has Full Control and isn't an administrator |
| 2019-10, 2020-01 | Bi00, Marc408 | NetApp behind DFS; it works when the running account owns the folder |
| 2020-01, 2023-11 | jcardel | EMC filer: the owner can be set only through a share that impersonates root; other permissions work over SMB; the owner entry "Owner Rights" is his workaround |
| 2023-05 | tberta | EMC NAS, 4.2.6, no administrator rights on the NAS: 1307; Process Monitor shows the owner written in addition to the DACL, while `icacls` writes only the DACL |
| 2023-11-28 | maintainer | reproduced with a customer: the user isn't a local administrator and lacks the backup and restore privileges |
| 2026-10-05, -06 | maintainer | the fix writes only the changed section (Decision 19); rc3 announced as published on 2026-10-06 13:40 UTC; asked for a tester on NetApp or EMC |
| 2026-10-06 16:05 | jcardel | moving to IBM ESS (UNIX), owner issue "still the same" there; will test both systems and report "tomorrow" |

  No reply followed by 2026-10-09 21:33 UTC. Silence is not success. The
  2020 comments of Kluk and agonzalezm describe other causes (a script that
  wasn't run as administrator; a name that can't be translated).
- What we tested: only Windows. The lab comparison of 2026-10-07 reproduced
  the error over SMB with rc2 and showed rc4 passing; every candidate since,
  including `83149ee` on 2026-10-09, passes case 1 (a delegated account that
  doesn't own the folder: add, remove, clear, disable and enable inheritance,
  set inheritance, and security descriptor, with the owner kept) in both
  editions on Windows Server 2025. CI reproduces the error without a file
  server. The matrix of Decision 21 adds Server 2019, 2022, and Windows 11.
- What it doesn't show: whether NetApp ONTAP, Dell EMC, or IBM ESS accepts a
  write of the DACL alone from an account that isn't their administrator, and
  what else they refuse. Hypotheses, not facts: they may refuse a flag that
  the cmdlets set (for example the protected-DACL flag when the inheritance
  changes), or map the ACL differently. `Set-NTFSOwner` can't work where the
  server doesn't allow assigning an owner; that is a server policy.
- Options for the maintainer:
  1. Wait for a report on the exact candidate (rc7 once published) from both
     reporters. Safest; the stable release waits for an unknown time.
  2. Accept the untested risk, and release with the caveat below. The
     decision is security-relevant, so only the maintainer can take it; it
     doesn't go through a "not sure, you pick" answer.
  3. Both: publish rc7, ask for tests with the checklist, and choose a date
     after which you decide between 1 and 2.
- Recommendation: option 3. Nothing in the module changes for #34 meanwhile.
- Caveat for the release notes, if the risk is accepted (adjust the list of
  operating systems to what the matrix has tested): "The fix for #34, which
  writes only the section of the security descriptor that a command changes,
  was tested on Windows file servers. NetApp, EMC, and IBM ESS file servers
  weren't available for 5.0.0. If a command still fails there with error
  1307, tell us in #34. `icacls` is the fallback."
- Open: the maintainer's choice between the options, and the date. Until
  then the gate of Decision 21 for #34 is open.
- Tester checklist: `Tests/Lab/Non-Windows-File-Server-Test.md`. It uses a
  new folder that the tester controls and asks for sanitized evidence.
- Draft comment for #34 (for the maintainer to post; the agent posts
  nothing; replace the version and the link when they exist):

```text
Thanks again for offering to test, @jcardel, and thanks @tberta for the Process Monitor capture that showed the owner write. Since 5.0.0-rc3, we have published more prereleases. The one to test is 5.0.0-rc7, because it is the candidate that becomes 5.0.0. Please test it on both systems you mentioned, with an account that is not an administrator or root of the file server.

Use a new folder that you create for the test, never real data, a share root, or a home folder. The steps take about 20 minutes: <link to Tests/Lab/Non-Windows-File-Server-Test.md>. Please report the package version, the file server product and version, and for each command whether it worked, the first line of any error, and the owner before and after. Please don't post passwords, keys, file contents, or complete security descriptors, and replace names with placeholders.

A report of "it works" without these details can't tell us which command ran on which setup. If something fails, that is just as useful: the error and the owner before and after show what the file server refuses. We would like to have your result before 5.0.0. NTFSSecurity will be archived after 5.0.0.
```
