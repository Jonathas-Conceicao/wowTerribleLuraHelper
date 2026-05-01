---
phase: 02-poc-port-macros-window-commands
plan: "01"
subsystem: macros-schema
tags: [macros, schema, combat-lockdown, savedbariables]
dependency_graph:
  requires: [01-03-SUMMARY.md]
  provides: [db.window.alpha field, ns:RegisterMacros, ns:InitMacros, ns:OnRegenEnabled]
  affects: [02-02-PLAN.md (reads db.window.alpha at frame creation)]
tech_stack:
  added: []
  patterns: [combat-lockdown-deferral, printed-once-lua-local, idempotent-macro-create-edit]
key_files:
  created: []
  modified:
    - Core.lua
    - Macros.lua
decisions:
  - D-27: db.sequence removed from schema and backfill — in-memory only via Window.lua local
  - D-33: Macros.lua is a near-verbatim port of POC lines 42-78
  - D-34: macrosPrintedThisSession is a Lua local upvalue, not stored in DB
  - D-35: db.window.alpha = 1.00 added to Core.lua defaults table
  - D-36: Plan 02-01 adds schema field only; Window.lua (02-02) calls SetAlpha
  - D-37: alpha backfill uses same nil-check pattern as other db.window fields
  - SAFE-03: InCombatLockdown() guard at top of ns:RegisterMacros, PLAYER_REGEN_ENABLED retry
metrics:
  duration_minutes: 15
  completed_date: "2026-04-30"
  tasks_completed: 3
  files_modified: 2
---

# Phase 2 Plan 01: Macros + Schema Cleanup Summary

**One-liner:** 5 TLH_* macros with idempotent Create/EditMacro, InCombatLockdown deferral, and db.window.alpha=1.00 schema field added to Core.lua.

## What Was Built

### Core.lua — 4 surgical schema edits

1. **Removed** `sequence = {}` from the `TerribleLuraHelperDB` defaults table (D-27: sequence is in-memory only, lives in Window.lua as a Lua local).
2. **Added** `alpha = 1.00` to the `window = { ... }` defaults block, after `position = nil` (D-35).
3. **Removed** the `if not db.sequence then db.sequence = {} end` backfill block (D-27 cleanup).
4. **Added** `if db.window.alpha == nil then db.window.alpha = 1.00 end` to the backfill loop, after the existing `autoHide` backfill (D-37).

The schema block for `window` is now: `scale`, `locked`, `autoHide`, `position`, `alpha`. The top-level defaults table is now: `enabled`, `listenChannels`, `window` (no `sequence`).

### Macros.lua — full implementation (was a 10-line stub)

Verbatim port of POC lines 42-78 with three adjustments per D-33:

- **MACROS table** (5 entries): `TLH_Diamond/137003`, `TLH_Triangle/137004`, `TLH_Circle/137002`, `TLH_Cross/137007`, `TLH_T/137001`. Bodies are `/raid {rt#}` player-macro strings — never called from Lua code.
- **`macrosPrintedThisSession`** (Lua local upvalue): replaces POC's `scriptFrame._luraMacrosPrinted`. Tracks the "drag to action bar" hint on first successful registration per session (D-34).
- **`registrationDeferred`** (Lua local upvalue): set to `true` when `InCombatLockdown()` blocks the initial attempt; cleared on successful run.

**Three module exports on `ns`:**

| Export | Purpose |
|--------|---------|
| `ns:RegisterMacros()` | Re-runnable entry point. Returns `false` if combat-blocked (sets `registrationDeferred`). Phase 3 "Recreate Macros" button calls this (MACR-04). |
| `ns:InitMacros()` | Called by Core.lua dispatcher. Tries `RegisterMacros()` immediately; if blocked, creates a one-shot Frame that listens for `PLAYER_REGEN_ENABLED` and retries (SAFE-03 / MACR-03). |
| `ns:OnRegenEnabled()` | Public API for external retry calls; checks `registrationDeferred` before calling `RegisterMacros()`. |

## Commits

| Task | Commit | Files | Description |
|------|--------|-------|-------------|
| 1 + 2 + 3 | `018db02` | Core.lua, Macros.lua | feat(02): macros + schema cleanup (MACR-01..05, SAFE-03) |

## Verification Results

| Check | Result |
|-------|--------|
| `grep -q "alpha = 1.00" Core.lua` | PASS |
| `grep -qE "if db.window.alpha == nil then" Core.lua` | PASS |
| `! grep -qE "^\s*sequence = \{\}" Core.lua` | PASS |
| `! grep -qE "if not db.sequence then" Core.lua` | PASS |
| `stylua --check Core.lua Macros.lua` | PASS |
| All 5 macro names in Macros.lua | PASS |
| All 5 FileDataIDs in Macros.lua | PASS |
| `InCombatLockdown()` guard present | PASS |
| `PLAYER_REGEN_ENABLED` retry present | PASS |
| `GetMacroIndexByName` / `CreateMacro` / `EditMacro` present | PASS |
| `drag them to your action bar` hint present | PASS |
| `macrosPrintedThisSession` local present | PASS |
| All 3 `ns:*` exports defined | PASS |
| `! grep -rE "SendChatMessage" *.lua` | PASS |
| `! grep -rnE "msg:(gsub|match|find|len|sub|format|rep)" *.lua` | PASS |
| `! grep -q "TerribleLuraHelperDB.macros" Macros.lua` | PASS |
| `git diff Window.lua Config.lua` empty | PASS |

## Deviations from Plan

None — plan executed exactly as written. The four Core.lua edits were applied surgically without touching any other logic. The Macros.lua content matches the plan's drop-in implementation verbatim; stylua reformatted the multi-line `print(string.format(...))` call into its canonical style (nested `string.format` inside `print` with consistent indentation), which is functionally identical.

## Known Stubs

None. All 5 macros are fully wired. `ns:RegisterMacros()` is callable by Phase 3's "Recreate Macros" button (MACR-04) without any further modification.

## Handoff to 02-02

`db.window.alpha` is now in the SavedVariables schema and backfill loop. Plan 02-02 (`Window.lua`) can call `win:SetAlpha(db.window.alpha)` at frame creation time (D-36) — the field is guaranteed to be `1.00` on fresh installs and on upgrades from pre-alpha DBs.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at new trust boundaries were introduced beyond the planned `db.window.alpha` field (T-02-01 in plan's threat register, disposition: accept).

## Self-Check: PASSED

- `C:\Users\jonat\Repositories\TerribleLuraHelper\Core.lua` — exists and contains `alpha = 1.00`
- `C:\Users\jonat\Repositories\TerribleLuraHelper\Macros.lua` — exists and contains all 5 macro entries + 3 ns exports
- Commit `018db02` exists on `milestone/0.1.0`
- `Window.lua` and `Config.lua` unmodified (confirmed via `git diff`)
