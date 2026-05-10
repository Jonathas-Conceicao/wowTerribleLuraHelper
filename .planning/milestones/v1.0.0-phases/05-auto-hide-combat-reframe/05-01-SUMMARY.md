---
phase: 05-auto-hide-combat-reframe
plan: 01
status: complete
completed: 2026-05-10
requirements:
  - WIN-13
  - WIN-14
  - WIN-15
  - CFG-14
  - SAFE-05
key-files:
  created: []
  modified:
    - Window.lua
    - Config.lua
commits:
  - 86a4218  # Task 1: Window.lua combat-state coupling
  - 8186260  # Task 2: Config.lua relabel + new tooltip
  - f5bd880  # Post-UAT amendment: shortened toggle label to "Auto-hide"
amendments:
  - id: AMEND-05-01
    date: 2026-05-10
    decision: D-06
    description: |
      Original D-06 locked the toggle label as "Auto-hide when empty in combat".
      Post-UAT, user reported the label was too long for the toggle row.
      Shortened to "Auto-hide" — the tooltip still carries the full semantic
      detail (out-of-combat = visible reminder, in-combat = hides when empty,
      reappears on next marker), so the shorter label is sufficient.
---

# Phase 5 SUMMARY — Auto-Hide Combat Reframe

## What Was Built

Auto-hide-when-empty became in-combat-only. The toggle's semantics shifted: out of combat with an empty rune sequence the window now stays visible (so the toggle being on is self-evident to the user as a "this addon is on, but nothing to show yet" reminder); in combat with an empty sequence it soft-hides as before via `SetAlpha(0)`. Combat-state transitions (`PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`) trigger immediate re-evaluation. Config-panel toggle relabeled.

## Code Changes

**Window.lua** (commit `86a4218`):
- Added `local inCombat = false` to the Lua-locals block (joins `softHidden`, `sequence`, `clearTimer`, `positionApplied`).
- Added permanent `combatFrame = CreateFrame("Frame")` in `CreateWindow()`, registered for BOTH `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`. OnEvent handler sets `inCombat = (event == "PLAYER_REGEN_DISABLED")` then calls `applySoftHideState()`. Frame stays registered for the addon lifetime (does NOT mirror Macros.lua's fire-once `regenFrame` pattern — explicit comment block warns future contributors against the copy-confusion).
- Seeded `inCombat = InCombatLockdown()` at frame-creation time. Handles `/reload` mid-combat: at addon load, `InCombatLockdown()` returns true if the player is in combat (no `PLAYER_REGEN_DISABLED` would fire otherwise because they're already in combat).
- Extended `applySoftHideState()`'s condition: `if ns.db.window.autoHide and #sequence == 0 and inCombat then` (single-token addition; else-branch unchanged).
- Added 5-line SAFE-05 / AMEND-01 reminder block-comment immediately above `applySoftHideState` referencing `.planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-VERIFICATION.md` (the AMEND-01 origin doc).

**Config.lua** (commits `8186260` + `f5bd880`):
- Auto-hide checkbox label: `"Auto-hide when empty"` → `"Auto-hide"` (post-UAT amendment to D-06; original plan said `"Auto-hide when empty in combat"` but real-world panel layout showed that was too long).
- Tooltip rewritten: `"When on, the helper window stays visible while you're out of combat so you remember the toggle is on. In combat, it hides while the rune sequence is empty and reappears automatically when the next marker arrives."` (preserves the three D-07 semantic facts: out-of-combat = visible reminder, in-combat = hidden when empty, reappears on next marker).

## Decisions Honored

| D-ID | Decision | How implemented |
|------|----------|-----------------|
| D-01 | Cached `local inCombat` flag | Lua-local in `Window.lua` |
| D-02 | Seeded via `InCombatLockdown()` at frame creation | Inline in `CreateWindow()` |
| D-03 | New permanent `combatFrame` on both PLAYER_REGEN_* edges | One frame, two RegisterEvent calls, OnEvent that maps event name to flag |
| D-04 | Do NOT reuse Macros.lua's `regenFrame` | Explicit code comment contrasting the patterns |
| D-05 | `and inCombat` single-token condition extension | Yes — else-branch unchanged |
| D-06 | Locked label `"Auto-hide when empty in combat"` | **AMENDED** post-UAT to `"Auto-hide"` (see frontmatter AMEND-05-01) |
| D-07 | Tooltip preserves three semantic facts | Yes — all three present |
| D-09 | SAFE-05 reminder block-comment above applySoftHideState | 5-line comment with AMEND-01 origin reference |
| D-10..D-11 | Manual PR-review for SAFE-05 (no automated CI gate) | grep -c 'win:Hide()' Window.lua = 2 (unchanged) |
| D-12 | 7 UAT checkpoints | All 7 passed in human verification (2026-05-10) |

## Verification (must_haves cross-check)

All 9 plan must_haves verified — see `05-VERIFICATION.md`.

## UAT (D-12 — 7 checkpoints, user-verified 2026-05-10)

1. Out-of-combat visibility — ✓
2. In-combat soft-hide + AMEND-01 chat-event survival (macro press while soft-hidden fills slot) — ✓
3. Combat exit re-reveal — ✓
4. 20s self-clear during combat — ✓
5. Toggle autoHide=off while soft-hidden — ✓ (implicit — user reported "auto-hide working as expected")
6. `/reload` mid-combat (D-02 InCombatLockdown seed test) — ✓ (explicit re-test confirmed no full-alpha flash)
7. Config panel relabel + tooltip — ✓ (deferred to AMEND-05-01 then re-verified post-amendment)

## Deviations / Notes

- **AMEND-05-01** (label shortening) — post-UAT user request. Documented in frontmatter; tooltip unchanged so the semantic detail remains user-discoverable.
- Phase 5 and Phase 6 UAT were combined per user request (Phase 5 UAT deferred during initial Phase 5 execute; both verified together on 2026-05-10 after Phase 6's bug-fix iterations).
- Phase 6 added `ns:NotifyWindowVisibilityChanged` to Window.lua's exports and 3 call sites (ShowWindow/HideWindow/RestoreWindowVisibility). Phase 5's `applySoftHideState` was NOT modified to call notify (per Phase 6 D-12 engineering-truth model: soft-hide doesn't change `IsShown()`, label stays correct).

## Next

Phase 6 closes immediately after this one (same UAT session). v1.0.0 milestone wraps after Phase 6 SUMMARY/VERIFICATION + final PROJECT.md evolution.

---

*Phase 5 complete: 2026-05-10*
