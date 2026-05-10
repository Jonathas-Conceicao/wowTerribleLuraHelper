---
phase: 04-say-defaults-click-through
plan: "01"
subsystem: ui
tags: [lua, wow-addon, savedvariables, click-through, defaults, backfill]

# Dependency graph
requires:
  - phase: 03-config-panel-integration
    provides: Config.lua Settings panel, Core.lua DB schema + backfill block, Window.lua applyLockState

provides:
  - SAY-only first-run defaults for listenChannels and macroChannel
  - LISTEN_DEFAULTS Lua-local constant table driving fresh-install + backfill
  - Click-through on locked helper window via win:EnableMouse(not locked)
  - SAFE-06 zero-match guarantee (repo-wide grep returns no db.X = db.X or DEFAULT instances)

affects: [05-auto-hide-combat-reframe, 06-dynamic-label-image]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "LISTEN_DEFAULTS file-local constant table mirrors MACROS/CHANNEL_PREFIX convention in Macros.lua"
    - "Backfill idiom: `if db.X == nil then db.X = DEFAULT end` — no `or DEFAULT` shorthand (SAFE-06)"
    - "EnableMouse(not locked) on the plain Frame window for click-through — no combat deferral needed"

key-files:
  created: []
  modified:
    - Window.lua
    - Core.lua
    - Config.lua

key-decisions:
  - "D-01: Single-line click-through — win:EnableMouse(not locked) appended after applyLockState if/else; no child-frame iteration (D-03)"
  - "D-04/D-05: No combat-deferral for EnableMouse — plain CreateFrame('Frame') is unrestricted; D-06 in-combat smoke test confirmed zero ADDON_ACTION_BLOCKED"
  - "D-09..D-11: Fresh-install literals updated in-place; LISTEN_DEFAULTS drives backfill loop; macroChannel default changed RAID→SAY"
  - "D-12: No proactive ns:RegisterMacros() on upgrade — existing macros left untouched"
  - "D-07: Silent upgrade — no chat print, no db.notifiedV1, no schemaVersion field"
  - "D-13: Manual grep at PR review is the SAFE-06 gate; no CI automation (YAGNI at current addon scale)"
  - "SAFE-06 comment reword: original comment contained the literal anti-pattern string which caused the SAFE-06 grep to match the comment itself; rewording the comment was necessary to keep the grep a true zero-or-fail gate"

patterns-established:
  - "SAFE-06 backfill idiom: always `if db.X == nil then db.X = DEFAULT end`, never `db.X = db.X or DEFAULT`"
  - "LISTEN_DEFAULTS table at file top: single source of truth for both fresh-install literals and backfill loop"
  - "Click-through via EnableMouse on the top-level window frame only — child frames inherit by default"

requirements-completed: [SCAF-13, SCAF-14, SCAF-15, SAFE-06, WIN-11, WIN-12]

# Metrics
duration: ~45min
completed: 2026-05-09
---

# Phase 4 Plan 01: SAY Defaults + Click-Through Summary

**SAY-only first-run defaults + safe upgrade backfill via LISTEN_DEFAULTS + fully click-through locked window via win:EnableMouse(not locked), with zero SAFE-06 anti-pattern instances remaining in the codebase**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-05-09
- **Completed:** 2026-05-09
- **Tasks:** 5 (3 auto + 1 automated-verify gate + 1 human-verify)
- **Files modified:** 3 (Window.lua, Core.lua, Config.lua)

## Accomplishments

- Window.lua `applyLockState` gained `win:EnableMouse(not locked)` — one line, no child-frame iteration, no combat deferral; in-combat lock/unlock produces zero `ADDON_ACTION_BLOCKED` errors (D-06 gate passed in UAT)
- Core.lua updated with `LISTEN_DEFAULTS` constant table, SAY-centric fresh-install literals (RAID/RAID_LEADER/RAID_WARNING/INSTANCE_CHAT/INSTANCE_CHAT_LEADER all `false`), restructured backfill loop using `pairs(LISTEN_DEFAULTS)`, and macroChannel default changed from `"RAID"` to `"SAY"` in both the fresh-install block and the backfill path; SAFE-06 reminder comment co-located with `LISTEN_DEFAULTS`
- Config.lua SAFE-06 violation fixed: `db.listenChannels = db.listenChannels or {}` replaced with `if db.listenChannels == nil then db.listenChannels = {} end`; repo-wide SAFE-06 grep now returns zero matches
- All three D-15 UAT checkpoints passed in-game (fresh install, upgrade preserve, click-through cycle including in-combat lock/unlock)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add click-through to Window.lua applyLockState (WIN-11, WIN-12)** - `d435df6` (feat)
2. **Task 2: Update Core.lua fresh-install defaults + LISTEN_DEFAULTS + backfill (SCAF-13, SCAF-14, SCAF-15, SAFE-06)** - `20fb7d5` (feat)
3. **Task 3: Fix SAFE-06 violation in Config.lua + reword SAFE-06 comment in Core.lua** - `72b8a88` (fix)
4. **Task 4: Final automated verification gate** — no commit (verification only; all 7 checks green)
5. **Task 5: In-game UAT — three D-15 checkpoints** — no commit (human verification; user approved)

## Files Created/Modified

- `Window.lua` — `applyLockState` appended `win:EnableMouse(not locked)` after the if/else block (WIN-11, WIN-12)
- `Core.lua` — `LISTEN_DEFAULTS` table added at file top; fresh-install literal block updated (5 channels false, macroChannel="SAY"); backfill loop restructured to `for ch, default in pairs(LISTEN_DEFAULTS)`; macroChannel backfill literal changed to "SAY"; SAFE-06 reminder comment added
- `Config.lua` — `db.listenChannels = db.listenChannels or {}` replaced with `if db.listenChannels == nil then db.listenChannels = {} end` (SAFE-06)

## Decisions Made

- Click-through implemented as a single `win:EnableMouse(not locked)` line — no child-frame iteration because slot frames have no mouse enabled today (D-01, D-02, D-03)
- No combat deferral for `EnableMouse` — plain `CreateFrame("Frame", ...)` window is unrestricted; D-06 UAT confirmed no taint issues (D-04, D-05)
- Silent upgrade (D-07, D-08): no chat print, no `db.notifiedV1`, no `db.schemaVersion`; existing user preferences flow through untouched via `if == nil` guards
- No proactive `ns:RegisterMacros()` on upgrade (D-12): existing macros left on action bars as-is
- SAFE-06 comment reworded to avoid the grep matching comment prose (see Deviations)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SAFE-06 reminder comment triggered the SAFE-06 grep itself**
- **Found during:** Task 2 (Core.lua edits) / Task 4 (automated verification gate)
- **Issue:** The original SAFE-06 reminder comment included the literal anti-pattern string `db.X = db.X or DEFAULT` as an inline example to warn future contributors. The SAFE-06 regression grep (`git grep "= db\." -- '*.lua' | grep " or "`) matched this comment line, making the zero-match gate fail on the warning comment that was designed to prevent the anti-pattern.
- **Fix:** Rewrote the comment to describe the anti-pattern and reference SAFE-06 without using the exact banned string. The warning is conveyed via: "Never `db.X = db.X or DEFAULT` — that clobbers explicit `false` values" using backticks and prose rather than a bare code pattern that the grep catches.
- **Files modified:** `Core.lua`
- **Verification:** `git grep "= db\." -- '*.lua' | grep " or "` returns zero matches (exit code 1); grep is a true zero-or-fail gate with no known-noise exclusions needed
- **Committed in:** `72b8a88` (Task 3 commit — bundled with the Config.lua SAFE-06 fix)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug: grep false-positive from comment wording)
**Impact on plan:** Necessary to make the SAFE-06 gate a clean zero-or-fail check. No scope creep; the comment still conveys the same warning to future contributors.

## Issues Encountered

None beyond the SAFE-06 comment deviation documented above. All seven automated checks passed on first attempt in Task 4. All three D-15 UAT checkpoints passed on first attempt in Task 5, including the D-06 in-combat lock/unlock gate (zero `ADDON_ACTION_BLOCKED` errors observed).

## UAT Results (Task 5 D-15 Checkpoints)

**Checkpoint 1 — Fresh-install test (SCAF-13, SCAF-14):** PASS
- `TerribleLuraHelperDB.listenChannels` = `{ SAY=true, RAID=false, RAID_LEADER=false, RAID_WARNING=false, INSTANCE_CHAT=false, INSTANCE_CHAT_LEADER=false }`
- `db.macroChannel` = `"SAY"`
- Five TLH_* macros have bodies starting with `/s ` (slash + lowercase s + space)

**Checkpoint 2 — Upgrade preserve test (SCAF-15):** PASS
- All six channel flags remained at their v0.1.0 values (all `true` in the test case)
- `db.macroChannel` remained `"RAID"`
- Existing TLH_* macros not rebuilt; bodies still start with `/raid `

**Checkpoint 3 — Click-through cycle test (WIN-11, WIN-12, D-06):** PASS
- Unlocked window captures clicks (action-bar slot beneath does NOT trigger)
- Locked window passes clicks through (action-bar slot DOES trigger)
- Lock/unlock cycle is idempotent across 3+ repetitions
- `/lura lock` and `/lura unlock` during live combat: zero `ADDON_ACTION_BLOCKED` errors, zero Lua errors; click-through active while in combat

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The three changes are: a frame mouse-enable property toggle, literal default values in the SavedVariables init block, and a guard-clause form correction. All within existing trust boundaries documented in the plan's threat model (T-04-01..T-04-05, all accepted or mitigated).

T-04-05 (ADDON_ACTION_BLOCKED risk for EnableMouse in combat) was the only `mitigate` disposition — verified PASS by Task 5 Checkpoint 3 step k.

## User Setup Required

None - no external service configuration required. Run `./scripts/install.bat` and `/reload` in WoW to pick up the changes.

## Next Phase Readiness

Phase 4 complete. All 6 requirement IDs (SCAF-13, SCAF-14, SCAF-15, SAFE-06, WIN-11, WIN-12) satisfied and verified in-game.

Phase 5 (Auto-Hide Combat Reframe) can begin. Carry-forward notes for Phase 5:
- `PLAYER_REGEN_ENABLED` is already registered in `Macros.lua` for the deferred-macro-creation retry path — Phase 5's combat-state listener can attach to the same event without conflicts.
- `applyLockState` is now the authoritative place to wire frame-property changes; Phase 5's `applySoftHideState` should follow the same pattern (called from all entry points, no ad-hoc callers).
- SAFE-06 zero-match gate is now clean — Phase 5 must not reintroduce `db.X = db.X or DEFAULT` in any new backfill paths.
- The `LISTEN_DEFAULTS` pattern (file-top local constant table → backfill loop) is the established convention for future default-sets.

---
*Phase: 04-say-defaults-click-through*
*Completed: 2026-05-09*
