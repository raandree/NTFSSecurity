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
  configuration is removed. The GitHub wiki is retired: its version history
  and installation steps moved to `Docs/Version-History.md` and
  `Docs/README.md`, and the maintainer turns the wiki off.
- Rationale: One source of truth that is versioned with the code, reviewed
  in pull requests, and checked by AppVeyor. The Read the Docs project
  `ntfssecurity` belongs to `Sup3rlativ3` and points to a fork that no
  longer exists; a wiki is edited outside pull requests and CI.
- Consequences: `online version` links stay on GitHub (Decision 4). Section
  anchors follow GitHub's rules. `Docs/index.md` became `Docs/README.md`, so
  that GitHub shows it when you open the `Docs` folder.
- Rejected: taking over or re-importing the Read the Docs project with a
  strict MkDocs build (prepared on the local branch `ai/read-the-docs`, not
  merged), and publishing `Docs` to the wiki.
