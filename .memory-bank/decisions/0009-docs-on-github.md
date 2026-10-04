---
status: accepted
date: 2026-10-04
last-verified: 2026-10-04
owner: shared
source: maintainer decision in work package 3
---

# Decision 9: Keep the documentation on GitHub

- Choice: The documentation lives in `Docs` and `README.md`, and GitHub
  renders it. There is no documentation site: the Read the Docs and MkDocs
  configuration is removed. The wiki's version history and installation
  steps moved to `Docs/Version-History.md` and `Docs/README.md`; the wiki
  itself is now generated from `Docs` (Decision 11) instead of being turned
  off.
- Rationale: One source of truth that is versioned with the code, reviewed
  in pull requests, and checked by CI. The Read the Docs project
  `ntfssecurity` belongs to `Sup3rlativ3` and points to a fork that no
  longer exists; a hand-written wiki is edited outside pull requests and CI.
- Consequences: `online version` links stay on GitHub (Decision 4). Section
  anchors follow GitHub's rules. `Docs/index.md` became `Docs/README.md`, so
  that GitHub shows it when you open the `Docs` folder.
- Rejected: taking over or re-importing the Read the Docs project with a
  strict MkDocs build (prepared on the local branch `ai/read-the-docs`, not
  merged). Also rejected (maintainer, 2026-10-04): merging
  `Docs/Version-History.md` into `CHANGELOG.md`. Only 5 of the 22 old
  versions have a recoverable release date (PowerShell Gallery) and only 3
  have tags, so they can't follow the changelog format; the page instead
  carries the Gallery dates and notes completed from the Gallery packages.
