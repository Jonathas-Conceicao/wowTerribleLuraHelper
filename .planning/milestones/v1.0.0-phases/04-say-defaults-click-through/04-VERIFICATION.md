---
phase: 04-say-defaults-click-through
verified: 2026-05-09T22:00:00Z
status: passed
score: 7/7 must-haves verified
overrides_applied: 0
re_verification: null
gaps: []
deferred: []
human_verification: []
---

# Phase 4: SAY Defaults + Click-Through Verification Report

**Phase Goal:** Fresh installs get SAY-only defaults that match real pug/casual usage, existing users keep their choices untouched, and a locked helper window is fully pass-through so it never intercepts raid clicks.
**Verified:** 2026-05-09T22:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Fresh install (TerribleLuraHelperDB nil at ADDON_LOADED): db.listenChannels.SAY==true and all five other channels==false; db.macroChannel=="SAY"; TLH_* macros target /s | ✓ VERIFIED | Core.lua lines 48-66: fresh-install literal block sets SAY=true, RAID/RAID_LEADER/RAID_WARNING/INSTANCE_CHAT/INSTANCE_CHAT_LEADER all=false, macroChannel="SAY". UAT Checkpoint 1 PASS (user-confirmed). |
| 2 | Upgrade install: every existing channel value preserved exactly; existing db.macroChannel preserved; existing TLH_* macros untouched (no rebuild on upgrade) | ✓ VERIFIED | Core.lua lines 75-78: backfill loop uses `if db.listenChannels[ch] == nil then` guard — existing values never overwritten. Lines 101-103: macroChannel backfill is nil-guarded. No `ns:RegisterMacros()` call in ADDON_LOADED path. UAT Checkpoint 2 PASS (user-confirmed). |
| 3 | When db.window.locked==true: win:EnableMouse(false) is in effect; clicks pass through to UI behind | ✓ VERIFIED | Window.lua line 216: `win:EnableMouse(not locked)` — when locked=true, evaluates to EnableMouse(false). Placed after the if/else block in applyLockState (lines 205-217). UAT Checkpoint 3 PASS (user-confirmed). |
| 4 | When db.window.locked==false: win:EnableMouse(true) is in effect; window captures clicks and is draggable; lock/unlock cycle is idempotent | ✓ VERIFIED | Same line 216: when locked=false, evaluates to EnableMouse(true). All four callers (CreateWindow line 174, ToggleLocked line 221, LockWindow line 265, UnlockWindow line 270) call applyLockState — zero caller-site changes needed. UAT Checkpoint 3 steps h-j: 3+ cycles idempotent (user-confirmed). |
| 5 | Repo-wide grep `git grep "= db\." -- '*.lua' \| grep " or "` returns zero matches (SAFE-06 gate) | ✓ VERIFIED | Command run: zero matches, grep exits non-zero (no lines found). The previous violation in Config.lua line 70 (`db.listenChannels = db.listenChannels or {}`) is gone, replaced with `if db.listenChannels == nil then db.listenChannels = {} end` (Config.lua line 70-72). |
| 6 | Code comment near Core.lua LISTEN_DEFAULTS documents the `if X == nil then` requirement and references SAFE-06 (D-14); comment does NOT contain the literal anti-pattern string that would trigger the grep | ✓ VERIFIED | Core.lua lines 9-13: 5-line comment block immediately above `local LISTEN_DEFAULTS`. Text reads "SAFE-06: backfill MUST use `if db.X == nil then db.X = DEFAULT end` — never the `or` shorthand". Uses backtick-quoted prose, not a bare `= db.X or` string — grep-safe. `grep -c "SAFE-06" Core.lua` returns 1. |
| 7 | stylua --check passes on Window.lua, Core.lua, Config.lua | ✓ VERIFIED | `stylua --check Window.lua Core.lua Config.lua` exits 0. |

**Score:** 7/7 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Window.lua` | applyLockState calls win:EnableMouse(not locked) | ✓ VERIFIED | Line 216: `win:EnableMouse(not locked)` — one occurrence, after closing `end` of if/else, before outer `end`. `grep -c` returns 1. No InCombatLockdown guard added (correct per D-04/D-05). No slotFrames iteration for EnableMouse (correct per D-01/D-03). |
| `Core.lua` | LISTEN_DEFAULTS table + SAY-centric fresh-install defaults + restructured backfill loop + SAFE-06 reminder comment | ✓ VERIFIED | Line 14: `local LISTEN_DEFAULTS = {...}` declared exactly once. Lines 15-20: SAY=true, five others=false. Lines 48-66: fresh-install block mirrors LISTEN_DEFAULTS exactly. Lines 75-78: `for ch, default in pairs(LISTEN_DEFAULTS) do` with nil-guard. Lines 101-103: macroChannel backfill uses "SAY". No `macroChannel = "RAID"` remains (grep returns 0). `grep -c 'macroChannel = "SAY"'` returns 2 (fresh-install + backfill). |
| `Config.lua` | SAFE-06-compliant table-init: `if db.listenChannels == nil then db.listenChannels = {} end` | ✓ VERIFIED | Line 70-72: `if db.listenChannels == nil then db.listenChannels = {} end`. Old `or {}` form is gone. `grep -c "if db.listenChannels == nil"` returns 1. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Window.lua:applyLockState | win frame mouse-enable state | EnableMouse(not locked) called after if/else | ✓ WIRED | Line 216 in place; called by all 4 entry points (CreateWindow:174, ToggleLocked:221, LockWindow:265, UnlockWindow:270) |
| Core.lua ADDON_LOADED handler | TerribleLuraHelperDB.listenChannels (fresh + backfill) | literal table on first run; LISTEN_DEFAULTS-driven loop on upgrade | ✓ WIRED | Fresh path: lines 48-56. Backfill path: lines 72-79 using `pairs(LISTEN_DEFAULTS)`. |
| Core.lua ADDON_LOADED handler | TerribleLuraHelperDB.macroChannel | literal "SAY" in fresh-install block + nil-guarded backfill | ✓ WIRED | Fresh: line 65 `macroChannel = "SAY"`. Backfill: lines 101-103 `if db.macroChannel == nil then db.macroChannel = "SAY" end`. |

---

## Data-Flow Trace (Level 4)

Not applicable. Phase 4 changes are SavedVariables defaults and a frame property toggle — no dynamic data rendering components modified. The chat pipeline (Window.lua lines 332-353) was not touched by this phase.

---

## Behavioral Spot-Checks

Step 7b skipped: WoW addon code is not runnable outside the game client. UAT checkpoints (Task 5 D-15) provided the equivalent behavioral verification in-game; all three passed per SUMMARY.md.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SCAF-13 | 04-01-PLAN.md | listenChannels SAY-only first-run default | ✓ SATISFIED | Core.lua fresh-install block: SAY=true, RAID/RAID_LEADER/RAID_WARNING/INSTANCE_CHAT/INSTANCE_CHAT_LEADER all=false. UAT Checkpoint 1 PASS. |
| SCAF-14 | 04-01-PLAN.md | macroChannel="SAY" first-run default; TLH_* macros send to /s | ✓ SATISFIED | Core.lua line 65: `macroChannel = "SAY"`. Config.lua line 234: RegisterAddOnSetting default is "SAY" (post-review fix cc0ea6a). UAT Checkpoint 1 PASS (macros verified with /s bodies). |
| SCAF-15 | 04-01-PLAN.md | Backfill MUST NOT clobber existing user choices on upgrade | ✓ SATISFIED | Core.lua lines 75-78: `if db.listenChannels[ch] == nil then` guard preserved verbatim. macroChannel backfill: `if db.macroChannel == nil then`. No proactive RegisterMacros() call. UAT Checkpoint 2 PASS. |
| SAFE-06 | 04-01-PLAN.md | No `db.X = db.X or DEFAULT` pattern anywhere; all backfills use `if db.X == nil then` | ✓ SATISFIED | `git grep "= db\." -- '*.lua' \| grep " or "` returns zero matches. Config.lua violation fixed in 72b8a88. Comment reworded to not trigger grep (deviation documented in SUMMARY). |
| WIN-11 | 04-01-PLAN.md | Locked window: clicks pass through to UI elements behind | ✓ SATISFIED | Window.lua line 216: `win:EnableMouse(not locked)` — locked=true yields EnableMouse(false). UAT Checkpoint 3 PASS. |
| WIN-12 | 04-01-PLAN.md | Unlocked window: full mouse interaction restored; 3+ lock/unlock cycles idempotent | ✓ SATISFIED | Same line: locked=false yields EnableMouse(true). All four applyLockState callers cover every code path. UAT Checkpoint 3 PASS (3+ cycles confirmed). |

**Note on WIN-11/WIN-12 vs REQUIREMENTS.md wording:** REQUIREMENTS.md WIN-11 and WIN-12 specify that EnableMouse must also be called on all slotFrames (CT-1 cascade note). The plan's CONTEXT.md D-01/D-02/D-03 explicitly decided against this: slot frames do not have EnableMouse(true) set anywhere in the codebase (plain CreateFrame defaults to mouse-disabled), so the cascade issue is moot. This is a conscious, documented design decision — D-02 provides the full rationale, and UAT Checkpoint 3 confirmed the behavior in-game. No gap.

---

## Post-Review Fix Verification (WR-01 + IN-01)

Code review commit cc0ea6a addressed two issues found after the main implementation:

| Issue | Fixed? | Evidence |
|-------|--------|----------|
| WR-01: Config.lua:234 RegisterAddOnSetting default was "RAID" | ✓ FIXED | Config.lua line 234 now reads `"SAY"`. Diff in cc0ea6a confirms the change from `"RAID"` to `"SAY"`. Restore Defaults will now correctly reset to SAY. |
| IN-01: Dropdown tooltip led with "/raid is the default" — stale after Phase 4 | ✓ FIXED | Config.lua lines 248-251: tooltip now reads "/s is the default and works anywhere (great for pugs and casual groups); /raid works during raid encounters (raid-only); /rw requires raid leader/assist; /i sends to instance/dungeon chat." |

---

## Hard Constraint Regression Check (CLAUDE.md)

| Constraint | Status | Evidence |
|-----------|--------|----------|
| No SendChatMessage calls | ✓ CLEAN | `grep -n "SendChatMessage" Window.lua Core.lua Config.lua Macros.lua` — zero matches |
| No COMBAT_LOG_EVENT_UNFILTERED | ✓ CLEAN | `grep -n "COMBAT_LOG_EVENT_UNFILTERED" Window.lua Core.lua Config.lua Macros.lua` — zero matches |
| Chat-event handler in Window.lua untouched | ✓ CLEAN | Lines 332-353 unchanged from v0.1.0. Phase 4 modified only applyLockState (line 216), the ADDON_LOADED block in Core.lua, and the SAFE-06 guard in Config.lua. |
| applySoftHideState uses SetAlpha(0), never win:Hide() | ✓ CLEAN | Window.lua lines 230-238: applySoftHideState sets `win:SetAlpha(0)` in the soft-hide branch. The two `win:Hide()` calls in the file are in `CreateWindow` (initial hide, line 69) and `ns:HideWindow` (explicit user command, line 385) — neither is inside applySoftHideState. |
| AMEND-01: OnShow/OnHide visibility-gated chat events | ✓ CLEAN | Window.lua lines 165-171: OnShow calls ns:RegisterChatEvents(), OnHide calls ns:UnregisterChatEvents() + ManualClear(). These scripts were not modified by Phase 4. |
| Milestone branch invariant | ✓ CLEAN | `git branch --show-current` returns `milestone/1.0.0`. All Phase 4 commits (d435df6, 20fb7d5, 72b8a88, cc0ea6a) are on this branch. |
| stylua after every task | ✓ CLEAN | `stylua --check Window.lua Core.lua Config.lua` exits 0. |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | — |

The SAFE-06 comment in Core.lua lines 9-13 describes the anti-pattern in prose but does not contain a bare `= db.X or` string that would trigger the regression grep. The description uses backtick-quoted code fragments with surrounding prose, which the grep pattern `"= db\." | grep " or "` does not match.

---

## Human Verification (Completed — UAT Already Passed)

All three D-15 checkpoints were completed in-game and approved by the user prior to this verification. No further human verification is required.

**Checkpoint 1 — Fresh-install test (SCAF-13, SCAF-14):** PASS
- TerribleLuraHelperDB.listenChannels: SAY=true, all five others=false
- db.macroChannel: "SAY"
- Five TLH_* macros have bodies starting with `/s`

**Checkpoint 2 — Upgrade preserve test (SCAF-15):** PASS
- All six channel flags preserved at their v0.1.0 values
- db.macroChannel preserved as "RAID"
- Existing TLH_* macro bodies unchanged (still `/raid`-prefixed; not rebuilt)

**Checkpoint 3 — Click-through cycle test (WIN-11, WIN-12, D-06):** PASS
- Unlocked window captures clicks
- Locked window passes clicks through
- Lock/unlock cycle idempotent across 3+ repetitions
- `/lura lock` and `/lura unlock` during live combat: zero ADDON_ACTION_BLOCKED errors, zero Lua errors

---

## Gaps Summary

No gaps. All 7 must-haves verified. All 6 requirement IDs (SCAF-13, SCAF-14, SCAF-15, SAFE-06, WIN-11, WIN-12) satisfied. All 5 ROADMAP Phase 4 success criteria met. All CLAUDE.md hard constraints clean. Post-review fixes (WR-01 + IN-01) confirmed in place via commit cc0ea6a.

---

_Verified: 2026-05-09T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
