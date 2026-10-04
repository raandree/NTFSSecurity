---
status: current
last-verified: 2026-10-04
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Work packages 3 and 4 are PR-ready and committed locally, not pushed:
`ai/docs-on-github` (docs on GitHub, wiki retired, Decision 9) and
`ai/manifest-version` (valid manifest, version 5.0.0, Decision 10),
stacked on it. The maintainer pushes both and opens the PRs; the PR
descriptions are in the session files. Merge the docs PR first with a
merge commit.

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
- Work package 4 test first: against the previous build, all 10 new tests
  failed for the expected reasons; after the change, the AppVeyor test
  script run locally in Windows PowerShell 5.1 passed (228 of 228 Pester
  tests), and the new tests pass in PowerShell 7.6.1 (10 of 10).
- The local Release build (`packages\`, `bin\`, `obj\`) is deleted after
  the work; rebuild from the NuGet cache (`techContext.md`).

## Next step

After the maintainer pushes: read the AppVeyor results of both PRs through
the REST API. Work package 5 (code defects) starts only after the
maintainer's go-ahead.
