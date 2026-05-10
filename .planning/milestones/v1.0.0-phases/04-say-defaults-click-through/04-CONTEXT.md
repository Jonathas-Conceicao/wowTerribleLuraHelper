# Phase 4: SAY Defaults + Click-Through - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Fresh installs get SAY-only listenChannels and macroChannel = "SAY"; existing v0.1.0 users' settings are preserved untouched on upgrade; the locked helper window is fully click-through (mouse passes through to UI behind it). Plus a code-review gate that no `db.X = db.X or DEFAULT` anti-pattern exists anywhere in the addon.

This phase covers 6 requirements:
- **SCAF-13** — listenChannels.SAY-only first-run default
- **SCAF-14** — macroChannel = "SAY" first-run default
- **SCAF-15** — backfill MUST NOT clobber existing user choices
- **SAFE-06** — no `db.X = db.X or DEFAULT` pattern (verified by grep)
- **WIN-11** — click-through when locked (window + slot frames)
- **WIN-12** — full mouse interaction restored when unlocked

What this phase explicitly does NOT touch:
- Auto-hide-when-empty-in-combat reframe (Phase 5)
- Dynamic Show/Hide button label (Phase 6)
- Cheat-sheet image (Phase 6)
- Any chat-pipeline / `msg`-handling code (permanent OOS — taint constraints)

</domain>

<decisions>
## Implementation Decisions

### Click-through implementation scope
- **D-01:** Minimal scope — `applyLockState()` in `Window.lua` gains a single `win:EnableMouse(not locked)` line (or equivalent: `EnableMouse(true)` in unlocked branch, `EnableMouse(false)` in locked branch). NO defensive iteration over `slotFrames[1..5]` or `lockBtn`.
- **D-02:** Justification — the current `Window.lua` does not call `EnableMouse(true)` on any slot frame; plain `CreateFrame("Frame", ...)` defaults to mouse-disabled. `lockBtn` already `:Hide()`s when locked (line 210), and hidden frames don't intercept clicks. Therefore touching only `win` is sufficient for full pass-through behavior today.
- **D-03:** No future-proofing iteration — if a later phase adds `EnableMouse(true)` to a child frame, that phase becomes responsible for adding the lock-state coupling for its own frame. Don't speculatively add code now for hypothetical future regressions.

### Combat-lockdown handling for `/lura lock`
- **D-04:** Call `EnableMouse(false)` immediately, no combat-deferral path. STACK.md verified `TerribleLuraHelperWindow` is plain `CreateFrame("Frame", ...)` — not protected — and `EnableMouse` is absent from warcraft.wiki.gg's authoritative restricted-API list. Multiple Blizzard built-in addons call `EnableMouse(false)` on non-protected frames at construction time from non-secure code.
- **D-05:** No mirror of Macros.lua's `regenFrame` / `armRegenRetry` pattern. Adding deferral logic would be engineering against PITFALLS.md CT-3, which was conservative about `IsProtectedFunction = true` in API metadata — but STACK.md showed that flag only applies to protected frames, not plain `Frame`s.
- **D-06:** Smoke-test gate — Phase 4 UAT must include a `/lura lock` press during a live combat encounter (training dummy or real boss) to confirm zero `ADDON_ACTION_BLOCKED` errors and correct click-through behavior. If this surfaces a problem in practice, add deferral as a Phase 4.x or v1.0.1 patch.

### Default-change rollout & user notification
- **D-07:** Silent upgrade — no chat print on first /reload after v0.1.0 → v1.0.0, no `db.notifiedV1` flag, no `db.schemaVersion` field. Users discover the new SAY-centric defaults only if they delete their SavedVariables file or check the config panel directly. Matches the addon's existing low-noise style.
- **D-08:** No schema-versioning scaffold introduced in v1.0.0. If future migrations need it, that decision is deferred to whichever future milestone first needs it. YAGNI for now.

### Backfill structure (mechanical)
- **D-09:** `Core.lua` initialization block (lines 33-53) literal `TerribleLuraHelperDB = {...}` is updated to the new defaults: `listenChannels = { SAY = true, RAID = false, RAID_LEADER = false, RAID_WARNING = false, INSTANCE_CHAT = false, INSTANCE_CHAT_LEADER = false }`, `macroChannel = "SAY"`. This is the fresh-install path — only fires when `TerribleLuraHelperDB` is nil at ADDON_LOADED.
- **D-10:** `Core.lua` listenChannels backfill loop (lines 61-65) is restructured from "default to true" to per-channel defaults via a `LISTEN_DEFAULTS` table. Each channel keeps its `if db.listenChannels[ch] == nil then db.listenChannels[ch] = LISTEN_DEFAULTS[ch] end` semantics — preserves existing user values, applies new defaults only to keys that don't yet exist (which on a v0.1.0 → v1.0.0 upgrade should be zero new keys, since v0.1.0 already wrote all six).
- **D-11:** `Core.lua` macroChannel backfill (line 87-89) literal default changes from `"RAID"` to `"SAY"`. Existing users' `db.macroChannel` is already populated (`"RAID"` from v0.1.0 first-run defaults) so the nil-check is a no-op for them — they keep `"RAID"` and their existing `/raid`-bodied macros.
- **D-12:** No proactive `ns:RegisterMacros()` call on upgrade. Existing users have working macros bound to action bars; rebuilding them silently could fail if combat is active or if the user customized the macros. Fresh installs get `/s` macros from the normal `PLAYER_LOGIN` → `ns:InitMacros()` path.

### SAFE-06 verification mechanism
- **D-13:** Manual grep at PR review time — `git grep -n "= db\." | grep " or "` must return zero matches. No CI gate, no pre-commit hook (the repo uses stylua + manual review; not heavyweight CI for a small addon).
- **D-14:** Code comment in `Core.lua` near the backfill block documenting the `if X == nil` requirement and pointing to SAFE-06 — so future contributors don't reintroduce the anti-pattern by reflex.

### Verification approach (UAT)
- **D-15:** Three explicit UAT checkpoints for Phase 4:
  1. **Fresh-install test** — delete `WTF/Account/.../SavedVariables/TerribleLuraHelperDB.lua`, `/reload`, verify `listenChannels.SAY == true` (only), `listenChannels.RAID == false` (and other channels), `macroChannel == "SAY"`, and `/macro` shows `TLH_*` macros with `/s` bodies.
  2. **Upgrade test** — preserve a v0.1.0 SavedVariables file with all-channels-true and macroChannel=RAID; install v1.0.0 (`./scripts/install.bat`), `/reload`, verify all six channel flags are still `true`, `macroChannel` is still `"RAID"`, and existing `TLH_*` macros still send `/raid`.
  3. **Click-through test** — `/lura show`, place the smile-arc window over an action bar, `/lura lock`, click an action-bar slot through the window — verify the action-bar slot receives the click; `/lura unlock`, verify clicks on the smile-arc area are captured by the window. Repeat the lock/unlock cycle 3+ times.

### Claude's Discretion
- Exact code-comment wording for the SAFE-06 reminder
- Whether to factor the new `LISTEN_DEFAULTS` table into a top-of-file local or inline within the backfill loop
- Whether the upgrade-test step adds an automated grep + manual UAT, or just one or the other
- Code-style choice for the click-through line (`win:EnableMouse(not locked)` ternary vs explicit if/else mirroring the existing `applyLockState` shape)

</decisions>

<specifics>
## Specific Ideas

- The user's preferred style throughout v0.1.0 + v1.0.0 questioning: **literal/simple/no-special-cases**. Examples: rejected M+ debounce, rejected death-state corpse-run handling, rejected partial click-through, rejected placeholder image. Carry this forward — when in doubt during planning, pick the simplest viable approach.
- Existing code already enforces SAFE-06 correctly (verified by reading Core.lua) — Phase 4 doesn't fix existing bugs; it ADDS new defaults using the same correct pattern. The grep is a regression gate, not a fix-up gate.
- `db.window.locked` defaults to `false` (unlocked) in current code — Phase 4 does NOT change that. Click-through only matters once the user actively locks the window.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.0.0 milestone scope
- `.planning/PROJECT.md` — Current Milestone section + Key Decisions table (especially the v1.0.0 entries on click-through coupling, SAY-centric defaults, and silent upgrade)
- `.planning/REQUIREMENTS.md` §"v1.0.0 Requirements (active — Polish & Defaults)" — full text of WIN-11, WIN-12, SCAF-13, SCAF-14, SCAF-15, SAFE-06
- `.planning/ROADMAP.md` §"Phase 4: SAY Defaults + Click-Through" — goal + 5 success criteria

### Research outputs (all v1.0.0)
- `.planning/research/SUMMARY.md` — synthesized recommendations across all 4 research dimensions; resolves divergent recommendations (e.g. STACK vs PITFALLS on `EnableMouse` combat safety)
- `.planning/research/STACK.md` §"CLICK-THRU" — `EnableMouse(false)` API verification, IsProtectedFunction nuance, Blizzard addon precedents
- `.planning/research/PITFALLS.md` CT-1, CT-2, CT-3 — click-through pitfalls; CT-1 ("EnableMouse does NOT cascade to children") is technically true but moot here because slot frames don't currently have mouse enabled (D-01 / D-02 rationale)
- `.planning/research/ARCHITECTURE.md` §"Feature 1" + §"Feature 4" — agrees with D-01 (minimal scope) and D-09..D-12 (backfill structure)
- `.planning/research/PITFALLS.md` DB-1 — `db.X = db.X or DEFAULT` is wrong for boolean keys (SAFE-06 rationale)

### Hard constraints (carry-over from v0.1.0)
- `CLAUDE.md` §"Hard Constraints" — never call `SendChatMessage`, never index `msg`, no `COMBAT_LOG_EVENT_UNFILTERED`. Phase 4 doesn't touch chat code, but constraints are absolute.
- `.planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-VERIFICATION.md` — AMEND-01 (visibility-gated chat-event registration). Phase 4 does NOT modify Window.lua's OnShow/OnHide; click-through is `EnableMouse` only, which doesn't trigger OnShow/OnHide.

### Existing code patterns (from v0.1.0)
- `Macros.lua` lines 86-98 — `regenFrame` + `armRegenRetry` pattern for combat-lockdown deferral. Phase 4 does NOT use this pattern (D-04 / D-05 — `EnableMouse` doesn't need it on non-protected frames). Referenced for symmetry awareness only.
- `Core.lua` lines 33-89 — existing fresh-install + backfill block. Phase 4 modifies this block in-place (D-09 / D-10 / D-11).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `applyLockState()` in `Window.lua` (lines 205-216) — the natural integration point for click-through. Already called from all four entry points (`ToggleLocked`, `LockWindow`, `UnlockWindow`, `CreateWindow`). Adding `win:EnableMouse(not locked)` here is a one-line change; zero caller-site updates.
- `Core.lua` ADDON_LOADED handler (lines 27-111) — already has the fresh-install vs backfill split; lines 33-53 are fresh-install defaults, lines 57-89 are backfill. Phase 4 modifies in-place, doesn't add new code paths.
- `Macros.lua:OnMacroChannelChanged()` already handles macro-rebuild on dropdown change. The default change in Core.lua doesn't add new flow — fresh installs hit `ns:InitMacros()` from `PLAYER_LOGIN`, which reads `db.macroChannel` via `CHANNEL_PREFIX[ns.db.macroChannel]`.

### Established Patterns
- **Backfill idiom:** `if db.X == nil then db.X = DEFAULT end` — used consistently throughout `Core.lua` for every key. Phase 4 keeps this verbatim.
- **Lua-local constant tables at top of file:** Macros.lua's `MACROS` and `CHANNEL_PREFIX` tables, Window.lua's `INACTIVITY_TIMEOUT` / `W,H` / `SLOT_POS` / `CHAT_EVENTS`. Phase 4's new `LISTEN_DEFAULTS` table follows this pattern (D-10).
- **Combat-lockdown deferral:** Macros.lua's `regenFrame` + `armRegenRetry` pattern. Phase 4 does NOT use this (D-04 / D-05 — out of scope), but notes the pattern for awareness.

### Integration Points
- **Window.lua:applyLockState()** (line 205-216) — adds `win:EnableMouse(not locked)` line. This is the entire click-through code change.
- **Core.lua initial defaults block** (line 33-53) — updates literal default values for `listenChannels` and `macroChannel`.
- **Core.lua backfill block** (line 61-65 + 87-89) — restructures listenChannels loop to per-channel defaults via `LISTEN_DEFAULTS` table; macroChannel default literal changes from `"RAID"` to `"SAY"` (the `if == nil` guard is unchanged so existing users keep their value).

### Existing Test Surface
- No automated test harness for WoW addons in this repo (or in WoW addon dev generally). All testing is in-game smoke pass per `CLAUDE.md` §Testing. Phase 4 UAT (D-15) extends the existing pattern with three new explicit checkpoints.
- `stylua` runs after every task per CLAUDE.md — Phase 4 changes go through the same gate.

</code_context>

<deferred>
## Deferred Ideas

- **Schema-versioning scaffold for migration tracking** — D-08 deferred. Reconsider in v1.1.0+ if any future milestone introduces a setting whose semantics change rather than just its default.
- **Defensive `EnableMouse` iteration over slot frames** — D-03 deferred. Add only if a future phase introduces `EnableMouse(true)` on a child frame.
- **One-time chat print on upgrade** — D-07 deferred (not selected in questioning). Could add later if user feedback shows existing users miss the SAY-centric default shift.
- **Pre-commit / CI grep automation for SAFE-06** — D-13 deferred. Manual grep at PR review is sufficient for the addon's current scale.

</deferred>

---

*Phase: 04-say-defaults-click-through*
*Context gathered: 2026-05-09*
