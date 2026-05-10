# Phase 5: Auto-Hide Combat Reframe - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Auto-hide-when-empty becomes in-combat-only. Out-of-combat with empty sequence → window stays visible (so the toggle being on is self-evident to the user). In-combat with empty sequence → window soft-hides via `SetAlpha(0)` (chat events stay registered; AMEND-01 invariant preserved). Combat-state transitions (`PLAYER_REGEN_*`) re-evaluate soft-hide immediately. Config-panel toggle relabels to "Auto-hide when empty in combat" with new tooltip explaining the semantics.

This phase covers 5 requirements:
- **WIN-13** — Auto-hide on, OUT of combat → visible (regardless of sequence emptiness)
- **WIN-14** — Auto-hide on, IN combat, empty → soft-hidden via `SetAlpha(0)`
- **WIN-15** — `PLAYER_REGEN_*` transitions re-evaluate soft-hide immediately, including initial-login seed via `InCombatLockdown()` at frame creation
- **CFG-14** — Auto-hide toggle relabels to "Auto-hide when empty in combat"; tooltip text updates
- **SAFE-05** — `applySoftHideState()` continues to use `SetAlpha(0)` exclusively, NEVER `win:Hide()` (preserves AMEND-01)

What this phase explicitly does NOT touch:
- Click-through / `EnableMouse` (Phase 4 — already shipped)
- Dynamic Show/Hide button label (Phase 6)
- Cheat-sheet image (Phase 6)
- Default values (Phase 4 — `db.window.autoHide` keeps its existing default of `false`; Phase 5 only changes its behavioral semantics)
- Any chat-pipeline / `msg`-handling code (permanent OOS — taint constraints)

</domain>

<decisions>
## Implementation Decisions

### Combat-state caching architecture
- **D-01:** Cached `local inCombat = false` flag at top of `Window.lua` (alongside other Lua-locals like `sequence`, `clearTimer`, `softHidden`). The `applySoftHideState()` function reads this local flag — does NOT call any combat-query API per evaluation.
- **D-02:** Initial-state seed at frame creation: in `CreateWindow()` (or `ns:InitWindow`), do `inCombat = InCombatLockdown()` once. This handles the `/reload` mid-combat case where the player is already in combat at addon load (no `PLAYER_REGEN_DISABLED` event will fire because they were already in combat — the seed catches this).
- **D-03:** A new permanent `combatFrame = CreateFrame("Frame")` in `Window.lua`, registered for BOTH `PLAYER_REGEN_DISABLED` (sets `inCombat = true` then calls `applySoftHideState()`) AND `PLAYER_REGEN_ENABLED` (sets `inCombat = false` then calls `applySoftHideState()`). The frame stays registered for the addon's lifetime — never unregistered.
- **D-04:** Do NOT reuse `Macros.lua`'s `regenFrame` (lines 86-98). That frame's handler unregisters `PLAYER_REGEN_ENABLED` after firing once (it's a fire-once retry pattern for combat-deferred macro creation). Phase 5 needs a permanent listener on both edges. Architecturally the two combat-listening frames are independent; that's fine.
- **D-05:** `applySoftHideState()`'s condition gains a third clause: `if ns.db.window.autoHide and #sequence == 0 and inCombat then` (currently: `if ns.db.window.autoHide and #sequence == 0 then`). Else-branch unchanged — exits soft-hide and restores `alpha = db.window.alpha or 1.00`.

### CFG-14 (Config.lua label + tooltip)
- **D-06:** Toggle label changes from `"Auto-hide when empty"` to `"Auto-hide when empty in combat"` (exact text — locked).
- **D-07:** Tooltip text is **Claude's Discretion** — the planner picks the wording. Recommended starting point from the v1.0.0 milestone research: *"When on, the helper window stays visible while you're out of combat (so you remember the toggle is on); in combat, it hides while the rune sequence is empty and reappears when a marker arrives."* The planner can refine wording for clarity/concision but must preserve the three semantic facts: out-of-combat = visible reminder, in-combat = hidden when empty, reappears on next marker.
- **D-08:** No `db.window.autoHide` value migration needed on upgrade. Existing users' value carries forward — the semantic shift is toward LESS hiding (was "always when empty"; now "only when empty AND in combat") which is strictly safer for existing users (they'll see the window MORE often, never less).

### SAFE-05 invariant enforcement
- **D-09:** Code comment near `applySoftHideState` referencing AMEND-01 and SAFE-05. Recommended placement: a 3-5 line block-comment immediately above the function definition. Wording must convey:
  1. Soft-hide uses `SetAlpha(0)` exclusively
  2. NEVER `win:Hide()` — that fires `OnHide` which unregisters chat events (AMEND-01 from Phase 2 verification)
  3. Reference: `.planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-VERIFICATION.md` for AMEND-01 origin
- **D-10:** Manual code review at PR time — no automated grep gate. Mirrors the SAFE-06 / D-13 pattern from Phase 4. Rationale: a precise grep for "win:Hide() inside applySoftHideState" is hard to scope correctly (`grep "win:Hide()"` would catch the legitimate calls in `ns:HideWindow`); the addon's scale doesn't warrant CI/pre-commit infrastructure for a single invariant.
- **D-11:** Verify-by-grep at PR time: `grep -n 'win:Hide()' Window.lua` should still show ONLY the existing legitimate call sites (the one inside `ns:HideWindow` at the time of Phase 5 close). Phase 5 introduces ZERO new `win:Hide()` calls.

### Verification approach (UAT)
- **D-12:** Phase 5 has multi-state combinations to test in-game. Recommended UAT checkpoints (planner finalizes):
  1. **Out-of-combat visibility** — `/lura show`, sequence empty, autoHide=on, NOT in combat → window visible (alpha = db.window.alpha)
  2. **In-combat soft-hide** — Same state, then engage a training dummy → window soft-hides (alpha=0) on `PLAYER_REGEN_DISABLED`; press a TLH macro → window reappears + slot fills (confirms chat events stayed registered through soft-hide — AMEND-01)
  3. **Combat exit re-reveal** — Exit combat (or kill dummy) → `PLAYER_REGEN_ENABLED` fires; window restores to alpha = db.window.alpha
  4. **20s self-clear in combat** — During combat, fill some slots, wait 20s for inactivity timeout → ClearAll fires → applySoftHideState evaluates → window soft-hides (autoHide=on AND empty AND in-combat); next macro press → reappears
  5. **Toggle autoHide=off while soft-hidden** — In combat, autoHide=on, empty seq → soft-hidden. Toggle autoHide=off via config panel → ns:OnAutoHideChanged fires → applySoftHideState evaluates → exits soft-hide → window restores
  6. **`/reload` mid-combat** — Engage combat, /reload → on addon load, `InCombatLockdown()` seeds `inCombat=true`; if window was visible (db.window.visible=true) and sequence empty (always true at /reload since in-memory), `RestoreWindowVisibility` → `applySoftHideState` → soft-hides correctly at alpha=0 (no flash of full-alpha window)
  7. **Config panel relabel** — Open Options > AddOns > TerribleLuraHelper, find the auto-hide checkbox; confirm label reads "Auto-hide when empty in combat" and tooltip describes the new semantics

### Claude's Discretion
- Exact tooltip wording (per D-07 — preserve the three semantic facts but feel free to tighten)
- Exact placement of the SAFE-05 reminder comment (per D-09 — directly above `applySoftHideState` is recommended)
- Whether to factor `inCombat` and the new `combatFrame` together visually (e.g. immediately after the existing `softHidden` Lua-local declaration) or place them where most contextually relevant
- Whether to add a one-line comment on the `combatFrame` registration explaining "permanent listener — NOT a fire-once retry like Macros.lua's regenFrame" (probably yes — defends future contributors against confusion)

</decisions>

<specifics>
## Specific Ideas

- The user's preferred style throughout v0.1.0 + v1.0.0: **simple/literal/no-special-cases**. Reaffirmed in v1.0.0 questioning (rejected M+ debounce, rejected death-state corpse-run handling). Phase 5 honors this — straightforward `inCombat` flag + literal `and inCombat` clause; no debouncing, no corpse-run special case, no schema migration.
- AMEND-01 is **load-bearing**. The combat-hide reframe is the single most invariant-touching change in v1.0.0. Treat the soft-hide path as immutable contract — Phase 5 ADDS to applySoftHideState's condition, never CHANGES its enforcement mechanism.
- TerribleBuffTracker has analogous `PLAYER_REGEN_*` listening patterns (per the v1.0.0 research). If the planner wants a sibling-addon reference, see `C:\Users\jonat\Repositories\TerribleBuffTracker\Display.lua` for an example of cached combat-state flags driving visibility logic.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.0.0 milestone scope
- `.planning/PROJECT.md` — Current Milestone section + Key Decisions table (especially v1.0.0 entries on auto-hide-in-combat-only reframe and the simple-rule preferences)
- `.planning/REQUIREMENTS.md` §"v1.0.0 Requirements (active — Polish & Defaults)" — full text of WIN-13, WIN-14, WIN-15, CFG-14, SAFE-05
- `.planning/ROADMAP.md` §"Phase 5: Auto-Hide Combat Reframe" — goal + 5 success criteria

### Research outputs (all v1.0.0)
- `.planning/research/SUMMARY.md` §"Feature 5" — synthesized recommendations (cached `inCombat` flag, PLAYER_REGEN_* coupling, soft-hide invariant)
- `.planning/research/ARCHITECTURE.md` §"Feature 5" — concrete integration map, build-order rationale (Phase 5 must precede Phase 6's notify-hook work because Feature 3 calls `notifyVisibilityChanged()` from `applySoftHideState()`)
- `.planning/research/PITFALLS.md` AH-1, AH-2, AH-3, AH-4 — auto-hide combat pitfall set:
  - **AH-2 (gate-level):** soft-hide MUST use SetAlpha(0), NEVER win:Hide() — the architectural gate
  - AH-1: PLAYER_REGEN_ENABLED edge cases at initial login
  - AH-3: combat boundary flicker considerations (already decided as out-of-scope per "no debounce" rule)
  - AH-4: misuse of UnitAffectingCombat vs InCombatLockdown vs PLAYER_REGEN events
- `.planning/research/STACK.md` §"COMBAT-HIDE" — verification that PLAYER_REGEN_* are stable Blizzard events, no new APIs needed

### Hard constraints (carry-over from v0.1.0; permanent)
- `CLAUDE.md` §"Hard Constraints" — never call SendChatMessage, never index msg, no COMBAT_LOG_EVENT_UNFILTERED. Phase 5 doesn't touch chat code, but constraints are absolute.
- `.planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-VERIFICATION.md` — **AMEND-01 origin**. Phase 2 amended Phase 2's chat-event registration model from "combat-gated" to "visibility-gated" via `OnShow`/`OnHide` scripts. SAFE-05 in Phase 5 is the long-term enforcement of that invariant.

### Existing code patterns (from v0.1.0 + Phase 4)
- `Window.lua` lines 46-52 — existing Lua-locals at top of file (`sequence`, `clearTimer`, `positionApplied`, `softHidden`). New `inCombat` joins this set.
- `Window.lua` lines 229-237 — existing `applySoftHideState()` definition. Phase 5 modifies the condition (single-line change: add `and inCombat`).
- `Window.lua` lines 188-189, 198-199 — existing `applySoftHideState()` callers from `FillSlot` and `ClearAll`. Phase 5 doesn't change these — they continue to fire on slot transitions; soft-hide just gains a combat-state guard.
- `Window.lua` lines 257-261 — existing `ns:OnAutoHideChanged` callback (config-panel triggers it). Phase 5 doesn't change this — soft-hide re-evaluates correctly when `db.window.autoHide` toggles.
- `Macros.lua` lines 86-98 — `regenFrame` + `armRegenRetry` pattern (referenced for awareness; Phase 5 does NOT reuse this — see D-04).

### Sibling-addon reference (optional)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\Display.lua` — analogous PLAYER_REGEN_* + cached combat-state flag pattern. Same author, same client target. Reference if the planner wants concrete code shape; not required.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `applySoftHideState()` in `Window.lua` (lines 229-237) — single-function integration point for the combat-state guard. Phase 5 changes ONE line in this function (the condition).
- Lua-locals block at top of `Window.lua` (lines 46-52) — natural place for the new `inCombat` Lua-local.
- `CreateWindow()` in `Window.lua` (lines 62-175) — natural place to seed `inCombat = InCombatLockdown()` and create the new `combatFrame`.
- `Macros.lua:regenFrame` pattern (lines 86-98) — referenced as a NEAR-MISS analog. Phase 5's `combatFrame` is structurally similar but registers for both events permanently (regenFrame fires once and unregisters). The planner should compare these side-by-side to avoid accidentally copying the unregister-after-fire pattern.

### Established Patterns
- **Lua-local flag + event-driven update:** `softHidden` is the existing example. Phase 5's `inCombat` follows the same pattern.
- **applySoftHideState as single source of truth:** Every visibility-affecting change (FillSlot, ClearAll, OnAutoHideChanged, ShowWindow soft-hide-bypass) routes through this one function. Phase 5 preserves this — combat-state changes also call `applySoftHideState()`.
- **Soft-hide invariant (AMEND-01):** Window stays `IsShown()=true` even at alpha=0 — chat events registered via OnShow stay registered. SAFE-05 protects this for Phase 5 and beyond.

### Integration Points
- **Window.lua line ~52** (Lua-locals block) — add `local inCombat = false`.
- **Window.lua `CreateWindow()`** (around line 62-75) — add `inCombat = InCombatLockdown()` after frame creation. Add `combatFrame` definition + event registration + handler (5-10 lines).
- **Window.lua `applySoftHideState()`** (line 230) — change condition from `if ns.db.window.autoHide and #sequence == 0 then` to `if ns.db.window.autoHide and #sequence == 0 and inCombat then`. Single-line edit.
- **Window.lua `applySoftHideState()`** (immediately above, line ~228) — add SAFE-05 reminder comment block (3-5 lines).
- **Config.lua** auto-hide checkbox section — change label string to "Auto-hide when empty in combat". Add/update tooltip text per D-07 (Claude's discretion).

### Existing Test Surface
- No automated test harness for WoW addons (per CLAUDE.md and Phase 4 SUMMARY). All testing is in-game smoke pass.
- Phase 5 UAT (D-12) extends the established checkpoint pattern from Phase 4 with 7 explicit checkpoints covering the multi-state matrix.
- `stylua` runs after every modified Lua file (CLAUDE.md gate).

</code_context>

<deferred>
## Deferred Ideas

- **M+ pull-boundary debounce** — out of scope per v1.0.0 questioning (literal combat-state matching). Reconsider in v1.1.0+ if real-world raid usage shows the literal flicker is annoying.
- **Death-state tracking for corpse runs** — out of scope per v1.0.0 questioning (simple rule: window reappears on PLAYER_REGEN_ENABLED regardless of player death). Reconsider in v1.1.0+ if users complain.
- **Automated grep gate for SAFE-05** — D-10 deferred. Manual PR review is sufficient at the addon's current scale. Reconsider if the addon grows enough to warrant CI infrastructure.
- **Combat-state-aware behavior beyond auto-hide** (e.g. combat-aware scale or alpha) — explicitly OOS per v1.0.0 PROJECT.md ("Combat-state-aware behavior beyond the auto-hide reframe — Only `PLAYER_REGEN_*` for auto-hide; no combat-aware scale, alpha, or other window-property changes."). Don't add other combat hooks in Phase 5.
- **Migration of existing autoHide=true users to autoHide=false** (in case the new semantics are surprising) — out of scope. Existing value carries forward; semantics shift toward LESS hiding (strictly safer).

</deferred>

---

*Phase: 05-auto-hide-combat-reframe*
*Context gathered: 2026-05-09*
