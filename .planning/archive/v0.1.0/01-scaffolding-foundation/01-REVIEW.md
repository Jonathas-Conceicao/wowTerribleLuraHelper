---
phase: 01-scaffolding-foundation
reviewed: 2026-04-30T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - Core.lua
  - Macros.lua
  - Window.lua
  - Config.lua
  - TerribleLuraHelper.toc
  - .pkgmeta
  - .github/workflows/release.yml
  - scripts/install.bat
  - scripts/release.bat
files_skipped_declarative:
  - .gitignore
  - .luarc.json
  - README.md
  - CHANGELOG.md
  - LICENSE
findings:
  critical: 0
  warning: 0
  info: 5
  total: 5
status: clean
---

# Phase 1: Code Review Report

**Reviewed:** 2026-04-30
**Depth:** standard
**Files Reviewed:** 9 (5 declarative files skipped: `.gitignore`, `.luarc.json`, `README.md`, `CHANGELOG.md`, `LICENSE`)
**Status:** clean (5 informational notes, no blocking issues)

## Summary

Phase 1 scaffolding is solid. All hard constraints from `CLAUDE.md` are honored:

- No `SendChatMessage` (or any chat-emitting API) anywhere in the addon — `Core.lua:84` uses `print()` for the load banner, the three stub modules contain no chat ops at all.
- No `CHAT_MSG_*` registrations anywhere; no Lua code reads / indexes / matches the `msg` argument of any chat event (because no such handler exists yet — Phase 2 will add it).
- No `COMBAT_LOG_EVENT_UNFILTERED` registration anywhere.
- The SavedVariables backfill loop in `Core.lua:42-71` correctly leaves `db.window.position` untouched on existing DBs (line 66 has an explanatory comment) and does not initialize it in the fresh-install branch either (line 34 sets it to `nil` explicitly, which Lua treats as absent — matches Phase 2's expectation that nil means "use default anchor on first show").
- The grouped DB schema at `Core.lua:19-37` matches D-03 exactly: `enabled=false`, all 6 listen channels true, window with scale/locked/autoHide and position=nil, sequence={}.
- The ADDON_LOADED handler is correctly guarded by the `name ~= addonName` early return (`Core.lua:14-17`) so it does not run for every other addon's load event, and unregisters itself after the first fire (`Core.lua:86`).
- The dispatcher calls `ns:InitMacros / ns:InitWindow / ns:InitConfig` (`Core.lua:74-82`); all three stubs exist with the matching `function ns:InitX()` signature in their respective files.
- The backfill loop is idempotent: every key check is `== nil` (or `not <table>` for the three sub-tables), so running it twice on the same DB produces the same DB.
- `release.bat` correctly uses `git rev-parse --abbrev-ref HEAD` to capture the current branch (line 17), uses `setlocal enabledelayedexpansion` + `!BRANCH!` for the push (lines 2 / 29), guards both tag and push with `errorlevel` checks, and does NOT hardcode `main` anywhere — TBT's bug is not inherited.
- `install.bat` copies all 5 expected files (the .toc plus all 4 Lua files) using individual `copy /Y` lines, so a missing file is visible at install time.
- `.toc` lists files in correct load order (Core first), declares Interface 120005, and includes the registered Curse/Wago project IDs.
- `.pkgmeta` correctly excludes `scripts/`, planning/dev metadata, and references `RELEASE_NOTES.md` as the manual changelog source.

The five informational notes below are minor robustness or cosmetic observations; none block Phase 1 completion or compromise correctness.

## Info

### IN-01: Sub-table backfill checks could be type-safe rather than truthy

**File:** `Core.lua:46`, `Core.lua:54`, `Core.lua:69`
**Issue:** The three sub-table existence checks use truthy tests (`if not db.listenChannels then`, `if not db.window then`, `if not db.sequence then`). If a future migration or corrupted SavedVariables file were to leave any of these as `false` or any non-table truthy value (e.g. a string), the truthy form would either skip re-initialization (wrong) or pass through and immediately fail on the subsequent indexed assignment. A `type(...) ~= "table"` check is more defensive and matches the same intent at trivial cost.
**Fix:**
```lua
if type(db.listenChannels) ~= "table" then
    db.listenChannels = {}
end
-- and similarly for db.window and db.sequence
```
This is paranoia, not a real-world bug — Phase 1 is the only writer of these keys today and never assigns a non-table value. Defer to Phase 2 if it ever becomes load-bearing.

### IN-02: Init dispatcher guards are redundant under current invariants

**File:** `Core.lua:74-82`
**Issue:** Each Init call is wrapped in `if ns.InitMacros then ns:InitMacros() end`. Since the three stub files (`Macros.lua`, `Window.lua`, `Config.lua`) all unconditionally assign `function ns:InitX()`, and the `.toc` lists them as load-mandatory, the guard is unreachable-false in normal operation. It only fires if a stub file fails to load, in which case `print()`-ing nothing and silently skipping is arguably worse than letting Lua surface the missing-function error during ADDON_LOADED. Keeping the guards for defense-in-depth is a defensible choice; the comment at line 73 already documents the intent.
**Fix:** Either remove the guards (making a missing stub a hard error users will report) or add a `else` branch that prints a diagnostic. Not worth changing in Phase 1; flag if the same pattern appears elsewhere.

### IN-03: Cosmetic double-backslash in `SOURCE` path construction

**File:** `scripts/install.bat:2`, `scripts/release.bat:12`
**Issue:** `set "SOURCE=%~dp0..\\"` — `%~dp0` already ends in a backslash, so appending `..\\ ` yields a path with a literal `..\\` suffix. Concatenations like `"%SOURCE%TerribleLuraHelper.toc"` resolve to `...\scripts\..\\TerribleLuraHelper.toc`, which Windows handles correctly (consecutive backslashes in a path are collapsed by the file API), but it is visually noisy and inconsistent with the single trailing backslash that `%~dp0` provides.
**Fix:**
```bat
set "SOURCE=%~dp0..\"
```
Functionally identical, slightly cleaner. Inherited from TBT — fine to leave alone for parity.

### IN-04: `release.bat` does not detect detached-HEAD before pushing

**File:** `scripts/release.bat:17-21`
**Issue:** When the working tree is in a detached-HEAD state, `git rev-parse --abbrev-ref HEAD` outputs the literal string `HEAD`. The subsequent `git push origin !BRANCH! "%TAG%"` then becomes `git push origin HEAD <tag>` — git accepts this (HEAD pushes the current commit to its upstream), but the user does not get a clear signal that they tagged from a detached HEAD rather than from a branch. D-08 says the script "works from any branch"; detached HEAD is arguably outside that contract.
**Fix:** Add a guard between the rev-parse and the tag step:
```bat
if "!BRANCH!"=="HEAD" (
    echo ERROR: Cannot release from detached HEAD. Check out a branch first.
    exit /b 1
)
```
Edge-case hardening; not blocking for Phase 1.

### IN-05: `release.yml` awk cutoff produces an empty `RELEASE_NOTES.md` against the current `CHANGELOG.md`

**File:** `.github/workflows/release.yml:27`, `CHANGELOG.md`
**Issue:** The awk pattern `/^## /{if(found) exit; found=1} found` extracts the first `## ` H2 section from `CHANGELOG.md`. The current `CHANGELOG.md` has only the `# Changelog` H1 and two HTML comments — no `## ` sections at all — so running the workflow today would write an empty `RELEASE_NOTES.md`, and BigWigs Packager would publish a release with no release notes. This is **by design for Phase 1**: D-06 explicitly states no Phase 1 tag will be pushed, and D-12 says the first `## v<version> — <title>` heading is added at the v0.1.0 milestone close. Just calling it out so it does not get forgotten — the v0.1.0 milestone-close commit must add the heading before the tag is pushed, otherwise the first published release will have an empty changelog.
**Fix:** No change needed in Phase 1. Track for milestone-close: `CHANGELOG.md` must gain a `## v0.1.0 — <title>` H2 with release notes before `release.bat 0.1.0` runs.

---

_Reviewed: 2026-04-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
