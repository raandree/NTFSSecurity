---
status: current
last-verified: 2026-10-04
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Work package 3 was redefined by the maintainer: no Read the Docs, the docs
stay on GitHub, and the wiki is retired (Decision 9). It is PR-ready on the
local branch `ai/docs-on-github` (`84328dc` plus Memory Bank notes). Work
package 4 (manifest and version) continues next, stacked on it, with the
maintainer's decisions recorded in `progress.md`.

## Evidence

- All 256 relative links in `Docs`, `README.md`, and `CHANGELOG.md` resolve,
  including 5 anchors checked against GitHub's slug rules; MarkdownLinkCheck
  0.2.0 (CI step 02) finds 0 broken links in `Docs` in Windows PowerShell
  5.1; markdownlint reports 0 issues in the changed pages.
- The documented manual install (`Unblock-File`, `Expand-Archive` into
  `$env:ProgramFiles\WindowsPowerShell\Modules`) was tested with the 4.2.6
  zip in a `$env:TEMP` sandbox: the module imports under `RemoteSigned`.
  `Expand-Archive` doesn't pass the download mark on; File Explorer's zip
  handler does, and the import then fails.
- The wiki stopped at 4.2.4; the Gallery has 4.2.5 (2019-07-11) and 4.2.6
  (2019-07-12), whose notes were reconstructed from `4.2.4..4.2.6`.
- The local branch `ai/read-the-docs` keeps the dropped strict-build work
  (`886c874`, `325ec76`); delete it once it is no longer wanted.

## Next step

Ask which assemblies follow the module version, then implement work
package 4 test-first on a branch stacked on `ai/docs-on-github`.
