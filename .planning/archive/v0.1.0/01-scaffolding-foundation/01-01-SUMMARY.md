---
phase: 01-scaffolding-foundation
plan: 01
subsystem: repo-meta
tags: [gitignore, luarc, license, readme, changelog, claude-md, milestone-branch]
dependency_graph:
  requires: []
  provides:
    - milestone/0.1.0 branch (on origin)
    - .gitignore (*.zip, .claude/, emacs swap exclusions)
    - .luarc.json (Lua 5.1 + vscode-wow-api workspace)
    - LICENSE (WTFPL v2, Copyright 2026 Jonathas-Conceicao)
    - README.md (description, install, slash commands)
    - CHANGELOG.md (bootstrap header, ## format comment)
    - CLAUDE.md (verified — all 8 SCAF-11 checks pass)
  affects:
    - Plan 01-02 (addon scaffolding depends on .luarc.json for editor support)
    - Plan 01-03 (release pipeline depends on .gitignore patterns and CHANGELOG ## heading format for awk cutoff)
tech_stack:
  added: []
  patterns:
    - WTFPL v2 license (verbatim copy from TerribleBuffTracker)
    - LF line endings (git autocrlf normalizes to CRLF on Windows checkout)
key_files:
  created:
    - .gitignore
    - .luarc.json
    - LICENSE
    - README.md
    - CHANGELOG.md
  modified: []
  verified_only:
    - CLAUDE.md (all 8 SCAF-11 grep checks passed; no patches required)
decisions:
  - milestone/0.1.0 branch created from main at 55e2b03 and immediately pushed to origin
  - CLAUDE.md required no patches — all SCAF-11 constraints already satisfied by /gsd-new-project output
  - Line endings: TBT source files use CRLF; TLH files written with LF by Write tool; git autocrlf converts on commit (content is byte-identical modulo line endings, confirmed with diff -b)
metrics:
  duration: 131s
  completed: 2026-04-30T19:50:37Z
  tasks_completed: 3
  tasks_total: 3
  files_created: 5
  files_modified: 0
  files_verified: 1
---

# Phase 1 Plan 1: Repo Skeleton & milestone/0.1.0 Branch Summary

**One-liner:** Opened milestone/0.1.0 branch from main, mirrored TBT's .gitignore/.luarc.json/LICENSE verbatim, bootstrapped README and CHANGELOG stubs, verified CLAUDE.md satisfies all 8 SCAF-11 constraints with no patches needed.

## Branch Operation

- Created `milestone/0.1.0` from `main` at commit `55e2b03` (docs(01): plan phase 1)
- Immediately pushed with `-u` to `https://github.com/Jonathas-Conceicao/wowTerribleLuraHelper.git`
- Subsequent plan commits land on this branch; `main` is untouched

## Files Added

| File | Source | Content Match | Notes |
|------|--------|---------------|-------|
| `.gitignore` | TerribleBuffTracker/.gitignore | Verbatim (diff -b clean) | *.zip, .claude/, emacs swap rules |
| `.luarc.json` | TerribleBuffTracker/.luarc.json | Verbatim (diff -b clean) | Lua 5.1, vscode-wow-api library, 7 globals |
| `LICENSE` | TerribleBuffTracker/LICENSE | Verbatim (diff -b clean) | WTFPL v2, Copyright (C) 2026 Jonathas-Conceicao |
| `README.md` | Per D-11 spec | — | 20 lines; description, Install, Slash Commands, License sections |
| `CHANGELOG.md` | Per D-12 spec | — | # Changelog header + awk-cutoff format comment; no version entries |

## CLAUDE.md Verification (SCAF-11)

All 8 required checks passed with no patches required:

| Check | Pattern | Result |
|-------|---------|--------|
| No-SendChatMessage constraint | `grep -q "SendChatMessage"` | PASS |
| msg constraint phrasing | `grep -qE '(read|index|gsub|match|concatenate|pattern-test).*\bmsg\b'` | PASS |
| Chat lockdown phrasing | `grep -q "chat.*lockdown"` | PASS |
| Milestone branch workflow | `grep -q "milestone/"` | PASS |
| Squash-merge workflow | `grep -qE "[Ss]quash.merge"` | PASS |
| Stylua rule | `grep -q "stylua"` | PASS |
| Architecture file map (Core.lua) | `grep -q "Core\.lua"` | PASS |
| Style reference | `grep -q "wow-ui-source"` | PASS |

**Conclusion:** CLAUDE.md satisfies SCAF-11 as written; no modifications were made.

## Commits on milestone/0.1.0

```
78420e7 docs(01): add README and CHANGELOG, verify CLAUDE.md (SCAF-10, SCAF-11)
5187e95 chore(01): add .gitignore, .luarc.json, LICENSE
```

Both commits are on `milestone/0.1.0` and not reachable from `main` (verified via `git log milestone/0.1.0 ^main --oneline`).

## Requirements Addressed

- **SCAF-05:** .gitignore with *.zip, .claude/, emacs swap rules — satisfied
- **SCAF-06:** .luarc.json with Lua 5.1 + vscode-wow-api — satisfied
- **SCAF-10:** LICENSE, README.md, CHANGELOG.md — satisfied
- **SCAF-11:** CLAUDE.md verified against full checklist — satisfied
- **SCAF-12:** milestone/0.1.0 branch created and published on origin — satisfied

## Deviations from Plan

None — plan executed exactly as written.

**Notes:**
- The `git ls-remote` verification on origin showed the old branch-creation hash initially because the push of the plan's commits happened after verification; a follow-up `git push` updated origin to `78420e7`.
- Line ending differences between TBT (CRLF) and TLH (LF from Write tool) are expected on Windows with git autocrlf enabled. Content is byte-identical modulo line endings (`diff -b` clean).

## Known Stubs

None — this plan contains no code files and no UI-rendering stubs.

## Threat Flags

None — only documentation and repo-metadata files were created.

## Self-Check: PASSED

Files verified:
- .gitignore: EXISTS
- .luarc.json: EXISTS
- LICENSE: EXISTS
- README.md: EXISTS
- CHANGELOG.md: EXISTS
- CLAUDE.md: EXISTS (unchanged)

Commits verified:
- 5187e95: EXISTS (chore(01): add .gitignore, .luarc.json, LICENSE)
- 78420e7: EXISTS (docs(01): add README and CHANGELOG, verify CLAUDE.md)

Branch verified:
- HEAD is on milestone/0.1.0
- Branch pushed to origin
