# Phase 5: Auto-Hide Combat Reframe - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 05-auto-hide-combat-reframe
**Areas discussed:** Combat-state architecture, CFG-14 tooltip wording, SAFE-05 enforcement gate

---

## Gray-Area Selection (multiSelect)

| Option | Description | Selected |
|--------|-------------|----------|
| Combat-state architecture | Cached Lua-local `inCombat` flag updated by PLAYER_REGEN_* events vs API call per applySoftHideState evaluation. Plus initial-state seeding source and location. | ✓ |
| CFG-14 tooltip wording | Lock exact wording now vs Claude's discretion (planner picks per research-recommended phrasing). | ✓ |
| SAFE-05 enforcement gate | How to enforce the AMEND-01 invariant (manual review vs automated grep vs comment). | ✓ |

**Outcome:** All three areas selected for discussion.

---

## Combat-state architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Cached Lua-local flag, PLAYER_REGEN_* updates (Recommended) | `local inCombat = false` in Window.lua, seeded via `InCombatLockdown()` at frame creation, updated by new permanent `combatFrame` listening to both PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED. `applySoftHideState` reads the local flag — no API call per eval. | ✓ |
| Query UnitAffectingCombat('player') per eval | No Lua-local cache; `applySoftHideState` calls `UnitAffectingCombat('player')` each time. Still need PLAYER_REGEN_* listener for re-evaluation triggers. | |
| Query InCombatLockdown() per eval | Same as above but uses InCombatLockdown(). Semantically about UI-protected-action lockdown rather than 'is player in combat'. | |

**User's choice:** Cached Lua-local flag, PLAYER_REGEN_* updates
**Notes:** Captured as D-01 through D-05 in CONTEXT.md. Matches ARCHITECTURE.md recommendation; mirrors patterns in TerribleBuffTracker. The new `combatFrame` does NOT reuse `Macros.lua`'s `regenFrame` (D-04 — Macros.lua's pattern is fire-once-and-unregister; Phase 5 needs permanent listener).

---

## CFG-14 tooltip wording

| Option | Description | Selected |
|--------|-------------|----------|
| Claude's discretion (Recommended) | Planner writes tooltip following the v1.0.0 research starting point: "When on, the helper window stays visible while you're out of combat (so you remember the toggle is on); in combat, it hides while the rune sequence is empty and reappears when a marker arrives." Refine wording in-flight. | ✓ |
| Lock exact wording now | I'll ask you for the exact text. Adds friction but locks the copy before implementation. | |

**User's choice:** Claude's discretion
**Notes:** Captured as D-07 in CONTEXT.md. Planner picks wording but must preserve the three semantic facts: out-of-combat = visible reminder, in-combat = hidden when empty, reappears on next marker. User can tweak post-merge by editing Config.lua directly.

---

## SAFE-05 enforcement gate

| Option | Description | Selected |
|--------|-------------|----------|
| Code comment + PR-review (Recommended — mirrors SAFE-06 / D-13) | Comment near `applySoftHideState` referencing AMEND-01 / SAFE-05; PR-review checks for win:Hide() introduction. Same low-overhead approach as SAFE-06's reminder comment in Core.lua. | ✓ |
| Automated grep gate in PR review | CI-ish grep check; risky because future legitimate Hide() calls would trip it. More overhead than warranted. | |
| Both — comment + automated grep | Belt-and-suspenders; matches paranoid teams' approach to load-bearing invariants. Adds task overhead vs. comment-only. | |

**User's choice:** Code comment + PR-review
**Notes:** Captured as D-09 through D-11 in CONTEXT.md. Mirrors SAFE-06 / Phase 4 D-13 pattern. The reminder comment is a 3-5 line block immediately above applySoftHideState referencing AMEND-01 origin (`02-VERIFICATION.md`). Verify-by-grep at PR time: `grep -n 'win:Hide()' Window.lua` should still show ONLY existing legitimate call sites (the one in `ns:HideWindow`).

---

## Claude's Discretion

Areas left for Claude to decide during planning/implementation:
- Exact tooltip wording (per D-07; preserve the three semantic facts)
- Exact placement of the SAFE-05 reminder comment (per D-09; directly above `applySoftHideState` recommended)
- Whether to factor `inCombat` and the new `combatFrame` together visually or place where most contextually relevant
- Whether to add a one-line comment on the `combatFrame` registration explaining "permanent listener — NOT a fire-once retry like Macros.lua's regenFrame" (probably yes; defends future contributors)

## Deferred Ideas

(All captured in CONTEXT.md `<deferred>` section; mirrored here for audit trail.)
- M+ pull-boundary debounce — already OOS per v1.0.0 questioning
- Death-state tracking for corpse runs — already OOS per v1.0.0 questioning
- Automated grep gate for SAFE-05 — defer; manual PR review sufficient
- Combat-state-aware behavior beyond auto-hide (combat-aware scale/alpha) — explicitly OOS per PROJECT.md
- Migration of existing autoHide=true users — no migration; semantics shift toward LESS hiding (strictly safer)
