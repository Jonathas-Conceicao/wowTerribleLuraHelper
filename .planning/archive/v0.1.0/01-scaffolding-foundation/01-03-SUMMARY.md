---
phase: 01-scaffolding-foundation
plan: "03"
subsystem: infra
tags: [bigwigs-packager, github-actions, wow-addon, release-pipeline, pkgmeta]

requires:
  - phase: 01-01
    provides: repo skeleton, CHANGELOG.md, milestone/0.1.0 branch
  - phase: 01-02
    provides: addon TOC + 4 Lua files (TOC + Core.lua + Macros.lua + Window.lua + Config.lua)

provides:
  - .pkgmeta with BigWigs Packager configuration (package-as TerribleLuraHelper, RELEASE_NOTES.md manual-changelog, standard ignore list)
  - .github/workflows/release.yml — tag-push GHA workflow with CHANGELOG-cutoff awk and BigWigsMods/packager@v2
  - scripts/install.bat — copies all 5 addon files to WoW retail AddOns folder
  - scripts/release.bat — tags v<version> and pushes CURRENT branch + tag (D-08 fix)

affects:
  - milestone/0.1.0 close (run release.bat 0.1.0 after squash-merge to main)
  - future phases: any new Lua files added to TOC must also be added to install.bat

tech-stack:
  added: [BigWigsMods/packager@v2, actions/checkout@v4]
  patterns:
    - CHANGELOG-cutoff awk extracts only the first ## section into RELEASE_NOTES.md at GHA time
    - release.bat captures current branch via git rev-parse --abbrev-ref HEAD (D-08) — works from any branch
    - per-file copy /Y in install.bat (not xcopy *.lua) so missing files are visible at install time

key-files:
  created:
    - .pkgmeta
    - .github/workflows/release.yml
    - scripts/install.bat
    - scripts/release.bat
  modified: []

key-decisions:
  - "D-06: Phase 1 does NOT push a tag — release.yml and release.bat are committed but first live run is v0.1.0 at milestone-merge time"
  - "D-07: CHANGELOG-cutoff awk pattern copied verbatim from TBT: awk '/^## /{if(found) exit; found=1} found' CHANGELOG.md > RELEASE_NOTES.md"
  - "D-08: release.bat fixed to push CURRENT branch (git rev-parse --abbrev-ref HEAD) instead of hardcoded main — works from milestone/* or main"
  - "Validation strategy: grep-based checks on all structural YAML elements in release.yml — no Python/PyYAML parser invoked to avoid PATH availability footgun"

patterns-established:
  - "per-file copy /Y pattern: install.bat lists each file explicitly so any missing file fails visibly at install time (not silently skipped)"
  - "D-08 pattern: release.bat uses setlocal enabledelayedexpansion + for /f USEBACKQ + !BRANCH! delayed-expansion syntax for branch capture"

requirements-completed: [SCAF-04, SCAF-07, SCAF-08, SCAF-09]

duration: 2min
completed: 2026-04-30
---

# Phase 1 Plan 03: Release Pipeline Summary

**BigWigs Packager config (.pkgmeta), GHA tag-push workflow with CHANGELOG-cutoff awk (D-07), and local install/release scripts — with the D-08 current-branch fix that TBT's hardcoded-main version was missing**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-30T19:58:16Z
- **Completed:** 2026-04-30T19:59:34Z
- **Tasks:** 2
- **Files modified:** 4 created

## Accomplishments

- `.pkgmeta` configures BigWigs Packager with `package-as: TerribleLuraHelper`, manual-changelog from `RELEASE_NOTES.md`, and a standard ignore list (SCAF-04)
- `.github/workflows/release.yml` committed with verbatim D-07 awk and `BigWigsMods/packager@v2` — first live exercise is the v0.1.0 milestone-merge tag (SCAF-09)
- `scripts/install.bat` copies all 5 addon files (TOC + 4 Lua) to the WoW retail AddOns path using per-file `copy /Y` (SCAF-07)
- `scripts/release.bat` tags `v<version>` and pushes the current branch + tag — D-08 fix eliminates the TBT bug where `main` was hardcoded (SCAF-08)

## Task Commits

Each task was committed atomically:

1. **Task 1: Write .pkgmeta and .github/workflows/release.yml** - `930fa20` (feat)
2. **Task 2: Write scripts/install.bat and scripts/release.bat** - `eaf6bf0` (ci)

## Files Created/Modified

- `.pkgmeta` (19 lines) — BigWigs Packager YAML: `package-as: TerribleLuraHelper`, `manual-changelog: filename: RELEASE_NOTES.md`, ignore list with 9 entries. Mirrors TBT verbatim except `TerribleBuffTracker` → `TerribleLuraHelper`.
- `.github/workflows/release.yml` (29 lines) — GHA workflow: triggers on `tags: "**"`, `permissions: contents: write`, `actions/checkout@v4` with `fetch-depth: 0`, CHANGELOG-cutoff awk step, `BigWigsMods/packager@v2`. Copied verbatim from TBT — no TLH-specific changes needed (workflow is addon-agnostic).
- `scripts/install.bat` (13 lines) — Sets DEST to `%PROGRAMFILES(x86)%\World of Warcraft\_retail_\Interface\AddOns\TerribleLuraHelper`, creates dir if missing, `copy /Y` for each of the 5 files. No `.blp` icon (deferred per PROJECT.md OOS). No `xcopy *.lua` (per-file pattern for visible failure).
- `scripts/release.bat` (33 lines) — D-08-fixed version. See below for side-by-side comparison.

## D-08 Fix: Side-by-Side Comparison

**TBT (BUG — hardcoded main):**
```bat
git -C "%SOURCE%" push origin main "%TAG%"
```

**TLH (D-08 fix — current branch):**
```bat
rem D-08: push the CURRENT branch (not hardcoded main) so releases work from milestone/* branches.
for /f "tokens=* USEBACKQ" %%b in (`git -C "%SOURCE%" rev-parse --abbrev-ref HEAD`) do set "BRANCH=%%b"
if "!BRANCH!"=="" (
    echo ERROR: could not determine current branch.
    exit /b 1
)
...
git -C "%SOURCE%" push origin !BRANCH! "%TAG%"
```

The `setlocal enabledelayedexpansion` + `!BRANCH!` syntax (instead of `%BRANCH%`) is required because `%BRANCH%` expands at parse-time inside the `if "%~1"==""` block and would be empty. The empty-branch guard protects against detached-HEAD state.

## Validation Strategy

No Python/PyYAML parser was invoked for `release.yml` or `.pkgmeta`. Every required structural element has its own grep check:

- `grep -q "package-as: TerribleLuraHelper"` (pkgmeta identity)
- `grep -q "filename: RELEASE_NOTES.md"` (manual-changelog target)
- `grep -q "BigWigsMods/packager@v2"` (packager step)
- `grep -q "fetch-depth: 0"` (full history for packager)
- `grep -q "awk '/\^## /{if(found) exit; found=1} found' CHANGELOG.md"` (D-07 awk exact match)
- `grep -q "rev-parse --abbrev-ref HEAD"` (D-08 current-branch logic)

GitHub Actions itself rejects malformed YAML on the first tag-push — that is the appropriate enforcement point.

## Decisions Made

- D-06 honored: no `git tag` or `./scripts/release.bat` invocation during this plan. The release pipeline is committed but silent until the v0.1.0 milestone-merge tag.
- D-07 honored: awk pattern copied verbatim from TBT, not modified. Per the plan, this is the only mechanism translating CHANGELOG.md into per-release notes.
- D-08 applied: D-08 is the single TLH-specific divergence from TBT. All other files mirror TBT exactly (except addon name substitution).
- `.planning/` not added to .pkgmeta ignore list: BigWigs Packager only includes files listed in the TOC or the addon's directory; `.planning/` is not under the addon directory and will not be packaged.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## v0.1.0 Milestone Close Checklist

When ready to release v0.1.0:

1. Squash-merge `milestone/0.1.0` into `main`
2. Switch to `main`: `git checkout main`
3. Add a `## v0.1.0 — <title>` section to `CHANGELOG.md` describing the release
4. Commit the CHANGELOG update
5. Run `.\scripts\release.bat 0.1.0` — this will:
   - Tag `v0.1.0`
   - Push `main` + `v0.1.0` to origin
   - Trigger the GitHub Actions workflow → BigWigs Packager → GitHub Release ZIP

## Next Phase Readiness

Phase 1 is fully complete. All 4 release pipeline files are on `milestone/0.1.0`. The phase is ready for the end-of-phase smoke test:
- Run `scripts/install.bat` → `/reload` in WoW → verify load banner + `TerribleLuraHelperDB` initialized

Phase 2 (POC Port) can begin. No blockers from this plan.

---
*Phase: 01-scaffolding-foundation*
*Completed: 2026-04-30*
