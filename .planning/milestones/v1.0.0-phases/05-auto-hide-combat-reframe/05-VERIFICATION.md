---
status: passed
phase: 05-auto-hide-combat-reframe
verified: 2026-05-10
score: 9/9 must_haves verified
mode: human + grep cross-check (UAT-confirmed by user)
---

# Phase 5 VERIFICATION — Auto-Hide Combat Reframe

## Status: PASSED

All 9 must_haves from `05-01-PLAN.md` verified against the actual codebase. All 7 D-12 UAT checkpoints confirmed by user on 2026-05-10. One post-UAT amendment (AMEND-05-01 — toggle label shortened) documented in SUMMARY.md.

## must_haves Cross-Check

| # | Truth | Verification |
|---|-------|--------------|
| 1 | `local inCombat` exists in Window.lua's Lua-locals block; `inCombat = InCombatLockdown()` seeds at frame-creation | `grep -n "local inCombat" Window.lua` → present near Lua-locals block; `grep -n "inCombat = InCombatLockdown()" Window.lua` → present inside CreateWindow |
| 2 | `combatFrame` registered for BOTH PLAYER_REGEN_* edges; permanent (no UnregisterEvent) | `grep -n "combatFrame:RegisterEvent" Window.lua` returns 2 matches (PLAYER_REGEN_DISABLED + PLAYER_REGEN_ENABLED); no `combatFrame:UnregisterEvent` calls anywhere |
| 3 | `applySoftHideState`'s condition reads `... and inCombat then`; else-branch unchanged | Confirmed via Read: `if ns.db.window.autoHide and #sequence == 0 and inCombat then` |
| 4 | SAFE-05/AMEND-01 reminder block-comment above applySoftHideState | Present (5 lines referencing AMEND-01 origin in `02-VERIFICATION.md`) |
| 5 | `grep -n 'win:Hide()' Window.lua` shows only existing legitimate sites | `grep -c "win:Hide()" Window.lua` = 2 (line 73 init in CreateWindow, line ~440 in ns:HideWindow) |
| 6 | Config.lua auto-hide checkbox label reads "Auto-hide"; tooltip describes new semantics | Confirmed: `grep 'Auto-hide' Config.lua` — label is "Auto-hide" (per AMEND-05-01 shortening); tooltip preserves three semantic facts |
| 7 | SAFE-06 carry-forward: `git grep "= db\." -- '*.lua' \| grep " or "` returns zero matches | Verified: exit code 1 (no matches) |
| 8 | `stylua --check Window.lua Core.lua Config.lua` exits 0 | Verified |
| 9 | In-game UAT (D-12 — 7 checkpoints) | All 7 confirmed by user 2026-05-10 (see SUMMARY.md UAT table) |

## ROADMAP Phase 5 Success Criteria Cross-Check

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Auto-hide on + out of combat: window visible-when-empty | ✓ UAT CP-1 |
| 2 | Auto-hide on + in combat + empty: soft-hidden via SetAlpha(0); macro press fills slot (AMEND-01 preserved) | ✓ UAT CP-2 |
| 3 | PLAYER_REGEN_* transitions re-evaluate immediately, including initial-login seed | ✓ UAT CP-3 + CP-6 (mid-combat /reload seed test) |
| 4 | Config-panel checkbox label updated; tooltip explains semantics | ✓ UAT CP-7 (after AMEND-05-01 label shortening) |
| 5 | applySoftHideState uses SetAlpha(0) exclusively — no win:Hide() | ✓ grep verification (win:Hide() count = 2, both legitimate) |

## Requirement Traceability

| REQ-ID | Description | Status |
|--------|-------------|--------|
| WIN-13 | Auto-hide on, out of combat → visible | Verified — UAT CP-1, condition check |
| WIN-14 | Auto-hide on, in combat, empty → soft-hidden via SetAlpha(0) | Verified — UAT CP-2, applySoftHideState body unchanged |
| WIN-15 | PLAYER_REGEN_* re-evaluate immediately, with InCombatLockdown seed | Verified — UAT CP-2/CP-3/CP-6 |
| CFG-14 | Auto-hide toggle relabeled + tooltip updated | Verified — UAT CP-7 (post-AMEND-05-01) |
| SAFE-05 | applySoftHideState uses SetAlpha(0), never win:Hide() | Verified — grep + code review (06-REVIEW.md) |

## Hard-Constraint Regression Check

- No new `SendChatMessage` call sites — grep zero in all Lua files
- No `COMBAT_LOG_EVENT_UNFILTERED` registration — grep zero
- No msg-argument indexing in Window.lua chat handler (lines 331-353 unchanged from v0.1.0)
- AMEND-01 invariant: `applySoftHideState` body uses SetAlpha(0) only — no win:Hide() introduced
- SAFE-06 carry-forward: zero `= db.X or DEFAULT` patterns in *.lua files

## Code Review (06-REVIEW.md)

The combined Phase 5 + Phase 6 code review (commit `01945c1`) returned 0 critical, 1 warning, 2 info — all docs-only. Three clarity comments added; zero code-behavior changes.

## Notes

- AMEND-05-01 (label shortening) was a post-UAT user request; the original D-06 label "Auto-hide when empty in combat" was too long for the toggle row.
- Phase 5 + Phase 6 UAT were combined per user request — both verified together on 2026-05-10.

---

*Phase 5 verified: 2026-05-10*
