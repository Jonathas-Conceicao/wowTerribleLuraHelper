# Phase 8: Zone-Aware Auto Show/Hide (March of Quel'danas) - Context

**Gathered:** 2026-05-16
**Status:** Ready for planning (research recommended before plan)

<domain>
## Phase Boundary

A new event handler watches `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA`. On every fire, it queries the player's current mapID and compares against the hardcoded **March of Quel'danas raid instance** mapID(s). In zone → `ns:ShowWindow()` (same path as `/lura show`). Out of zone → `ns:HideWindow()` (same path as `/lura hide`).

**Critical scope refinement from user (2026-05-16 discuss):** "In zone" means the **March of Quel'danas RAID INSTANCE** (where the L'ura encounter lives), NOT the outdoor zone of the same name (if any exists in Midnight) and NOT Magister's Terrace or any other instance. The auto-toggle should activate across **all 4 raid difficulties** (LFR / Normal / Heroic / Mythic).

Phase 8 covers 4 requirements:
- **WIN-16** — Event registration + mapID-based zone routing through existing Show/Hide paths
- **WIN-17** — Manual `/lura show|hide` re-evaluated on next zone event; `/reload` inside the raid auto-shows
- **SCAF-19** — Hardcoded mapID constant (or set, if difficulties have distinct IDs); localization-safe; no zone-name string matching
- **SAFE-07** — Routes through `Show()` / `Hide()` (not `SetAlpha(0)`); AMEND-01 chat-event registration invariant preserved

What this phase explicitly does NOT touch:
- Verbose-marker toggle (Phase 7 — shipped this milestone)
- `db.window.visible` semantics (continues to be written by existing Show/Hide as today; transient cache of last-applied state)
- Phase 5 soft-hide-during-combat (applies orthogonally inside the raid)
- Phase 6 dynamic label refresh (already wired via `ns:NotifyWindowVisibilityChanged()` inside Show/Hide — automatic side benefit)
- Chat-event pipeline (`msg` handling — permanent OOS per CLAUDE.md taint constraints)

</domain>

<decisions>
## Implementation Decisions

### Mapping scope (user-locked 2026-05-16)

- **D-01:** "In zone" = the **March of Quel'danas raid instance mapID(s) only**. NOT the outdoor zone (if a separate outdoor zone exists in Midnight). NOT Magister's Terrace, Sunwell Plateau, or any other instance.
- **D-02:** **All 4 raid difficulties** (LFR / Normal / Heroic / Mythic) MUST trigger the auto-show. Research surface (RESEARCH.md): confirm whether the 4 difficulties share a **single mapID** (typical for WoW raids — difficulty is a separate axis via `GetInstanceInfo` / `difficultyID`) OR have **distinct mapIDs** (atypical). If single: the constant is a scalar. If multiple: the constant becomes a small set (table lookup).
- **D-03:** The mapID(s) are encoded as **hardcoded numeric literal(s)** in the addon source (`Core.lua`, or wherever the zone handler lives). Localization-safe: no `GetZoneText()`, `GetRealZoneText()`, `GetMinimapZoneText()`, or any other locale-dependent API in the in-zone check.
- **D-04:** Research MUST identify the correct mapID(s) before the plan is finalized. If research can't pin them down from documented sources, the planner should add a "verification" task to the plan that has the user run a one-line `/dump C_Map.GetBestMapForUnit("player")` inside the actual raid to capture the live mapID (and a separate ID for each difficulty if they differ).

### Handler architecture (Claude's Discretion — recommended)

- **D-05:** New **permanent `zoneFrame`** in `Core.lua`. Registers `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA` once at file-scope (or inside `ADDON_LOADED`); never unregisters. Mirrors the established pattern: `eventFrame` (ADDON_LOADED/PLAYER_LOGIN, one-shot), `regenFrame` (Macros.lua combat retry), `combatFrame` (Window.lua PLAYER_REGEN_*). The new frame is one more siblings in this set.
- **D-06:** Handler lives in `Core.lua` — alongside the existing event-dispatcher pattern (small project; adding a new file for one handler is overkill; Core.lua already owns event dispatching). Named `ns:OnZoneChanged()` (verb-prefix to match `ns:OnAutoHideChanged`, `ns:OnMacroChannelChanged`, `ns:OnVerboseMarkersChanged` — established convention).
- **D-07:** Handler **re-evaluates on every event fire**. No state tracking ("was I in zone last time?"). Rationale: Show on already-shown is a no-op at the frame level (Blizzard's `:Show()` only re-fires `OnShow` on transition); same for Hide. So redundant re-evaluations are cheap. Tracking state would add complexity without runtime savings. (Research surface: confirm `OnShow`/`OnHide` re-fire semantics — almost certainly transition-only, but worth a Q.)
- **D-08:** Handler body skeleton:
  ```lua
  function ns:OnZoneChanged()
      local mapID = C_Map.GetBestMapForUnit("player")
      if MAP_ID_LURA[mapID] then       -- table lookup if a set; equality if scalar
          ns:ShowWindow()
      else
          ns:HideWindow()
      end
  end
  ```
  Final API call (`C_Map.GetBestMapForUnit` vs `C_Map.GetMapInfo` vs others) is **research-surfaced** — pick the canonical Midnight-era API. Constant name `MAP_ID_LURA` is illustrative; planner can rename (e.g. `LURA_RAID_MAP_IDS` if set, `LURA_RAID_MAP_ID` if scalar).
- **D-09:** Frame-script:
  ```lua
  local zoneFrame = CreateFrame("Frame")
  zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  zoneFrame:SetScript("OnEvent", function() ns:OnZoneChanged() end)
  ```
  No event filtering (handler is idempotent + cheap), no `self`/`event` introspection. Top-level in Core.lua.

### Print feedback policy (Claude's Discretion — recommended)

- **D-10:** **Silent** — no chat output on zone-driven auto show/hide. Rationale: zone transitions fire automatically and frequently (every loading screen, every taxi hop in the open world); a chat print on every fire would be spammy and add no information beyond what the user can see (window appeared or disappeared). Phase 7's toggle prints because the toggle is a deliberate user action; zone-auto is automatic and should be invisible. Counterexample (Phase 4 lock toggle) also prints, but locking is a deliberate user action too. Zone-auto is the first event-driven path that doesn't print, and that's the right call.
- **D-11:** **No debug print at addon-load time** showing the detected mapID. If the user needs to capture the live mapID to verify against the constant, the UAT checkpoint can include a `/dump C_Map.GetBestMapForUnit("player")` step (or the planner can add a one-time debug print gated behind a `DEBUG = false` constant the user can flip locally — Claude's discretion for the planner).

### Initial state + interaction with existing paths

- **D-12:** **No changes to `Core.lua`'s `ADDON_LOADED → RestoreWindowVisibility` path.** At login, ADDON_LOADED fires first → `ns:RestoreWindowVisibility()` is called if `db.window.visible == true` (existing Phase 1/3 behavior). Then PLAYER_ENTERING_WORLD fires moments later → the new zone handler runs → final say. Possible brief flicker if the user logged out with `db.window.visible == true` but is now outside the raid (window briefly shows then hides within ~milliseconds) — acceptable. Symmetrically, if `db.window.visible == false` but the user is in the raid, the initial restore is a no-op (RestoreWindowVisibility is conditional on visible==true), then the zone handler shows the window. Both paths converge correctly.
- **D-13:** `db.window.visible` is **written by `ns:ShowWindow()` and `ns:HideWindow()` exactly as today** (Window.lua:450, 456). Phase 8 doesn't touch `db.window.visible`; the auto-handler just becomes another caller of those functions. Effectively `db.window.visible` becomes a transient cache of last-applied state inside the raid (not a stable user preference). This matches WIN-17's user-confirmed semantics ("auto-show if in zone" on every fire, including /reload).
- **D-14:** **Phase 5 soft-hide applies orthogonally inside the raid.** When `ns:ShowWindow()` is called by the zone handler, the existing `applySoftHideState()` inside Show resets `softHidden=false` and applies `db.window.alpha`. Combat with empty sequence inside the raid still soft-hides via the existing `combatFrame` + `applySoftHideState` path (Phase 5 WIN-14). No new logic.
- **D-15:** **Phase 6 dynamic-label refresh is automatic.** `ns:ShowWindow()` (Window.lua:451) and `ns:HideWindow()` (Window.lua:457) already call `ns:NotifyWindowVisibilityChanged()` at the end. Zone-driven visibility changes therefore trigger the existing Phase 6 label refresh if the config panel is open during the transition. **No code change needed in Phase 8** for this side benefit.

### Hard taint constraint regression guard (locked across all phases)

- **D-16:** Phase 8 does **not** touch `CHAT_MSG_*` handlers, `SendChatMessage`, `:gsub`/`:match`/`#`/`..` on any `msg` argument, or `COMBAT_LOG_EVENT_UNFILTERED`. `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA` are unrelated to chat code paths. Regression diff guard at UAT time: `git diff -- '*.lua' | grep -E '^\+.*(SendChatMessage|:gsub|:match|#msg|msg\[)'` MUST return zero lines.

### UAT checkpoints (planner finalizes; will be batched with Phase 7's UAT per user preference)

- **D-17:** Recommended UAT pass after Phase 8 implementation. Combines with Phase 7's 8 checkpoints into one in-game session at end-of-milestone.
  1. **Enter M of Q raid (LFR difficulty)** — window auto-shows within one tick of the loading-screen completion. Confirm `ns:IsWindowShown()` returns true via `/dump`. (Also verify the captured live mapID matches the hardcoded constant — if research couldn't pin it down, this is when we capture and patch it.)
  2. **Enter M of Q raid (Normal / Heroic / Mythic)** — repeat checkpoint 1 for each remaining difficulty. If they share one mapID, all three behave identically; if they have separate IDs, this catches missing entries in the constant set.
  3. **Leave M of Q raid (exit instance to outdoor world)** — window auto-hides. Confirm `OnHide` fired (chat events unregistered, sequence wiped — checked via a TLH macro press after exit: if events were unregistered, the slot stays empty).
  4. **`/reload` inside M of Q raid** — window auto-shows after the reload completes. Confirms PLAYER_ENTERING_WORLD path fires correctly at session start.
  5. **`/lura hide` while inside raid, then zone out and back in** — window auto-shows on re-entry. Confirms WIN-17 (zone-handler is source of truth; manual hide re-evaluated on next zone event).
  6. **Magister's Terrace / Sunwell Plateau / unrelated instance** — window stays HIDDEN when entering. Confirms scope: only the M of Q raid mapID triggers show, not adjacent instances.
  7. **Combat soft-hide inside M of Q raid** — enter combat with empty sequence → window soft-hides (alpha=0). Press a TLH macro → slot fills, soft-hide releases (or stays soft-hidden per WIN-14, depending on Phase 5 sequence state — confirm orthogonal behavior is preserved).
  8. **Regression guard** — `git diff` for the phase contains zero new occurrences of `SendChatMessage`, `:gsub`, `:match`, `#msg`, `msg[` indexing.

### Claude's Discretion (the planner has flexibility here)

- Exact mapID-lookup API (`C_Map.GetBestMapForUnit("player")` is the most likely choice; research will confirm or surface an alternative).
- Whether to bundle the mapID constant into a separate `MAPS = { ... }` table (if a set) or inline as `local LURA_RAID_MAP_ID = NNNN` (if scalar). Planner picks based on research outcome.
- Optional one-time debug print at addon-load time showing the detected mapID — gated behind a local `DEBUG` constant. Recommended **NO** (keeps the addon output clean); if added, must default to off and be a single line, never per-zone-event.
- Position of `zoneFrame` declaration in Core.lua — recommended at file scope after the existing `eventFrame` block.
- Whether to call `ns:OnZoneChanged()` proactively at addon-load time (e.g., at the end of ADDON_LOADED) as an additional safety net beyond the PLAYER_ENTERING_WORLD fire. Probably unnecessary (PLAYER_ENTERING_WORLD fires at login reliably), but worth a research note.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.1.0 milestone scope
- `.planning/PROJECT.md` — Current Milestone section (v1.1.0 QoL Update) + Key Decisions table.
- `.planning/REQUIREMENTS.md` §"Zone-Aware Auto Show/Hide" — full text of WIN-16, WIN-17, SCAF-19, SAFE-07.
- `.planning/ROADMAP.md` §"Phase 8: Zone-Aware Auto Show/Hide" — goal + 5 success criteria.

### Existing code that Phase 8 hooks into (NOT modified — read-only references)
- `Window.lua:441-471` — `ns:ShowWindow()` / `ns:HideWindow()` / `ns:RestoreWindowVisibility()` / `ns:IsWindowShown()`. Zone handler calls Show/Hide directly; these functions already wire `db.window.visible`, `applySoftHideState()`, and `ns:NotifyWindowVisibilityChanged()`. Phase 8 does NOT modify them.
- `Core.lua:23-126` — existing `eventFrame` ADDON_LOADED/PLAYER_LOGIN dispatcher. Phase 8 adds a sibling `zoneFrame` next to it (not inside it).
- `Core.lua:113-120` — existing `RestoreWindowVisibility` call at end of ADDON_LOADED. Phase 8 leaves this untouched; PLAYER_ENTERING_WORLD fires after ADDON_LOADED and has the final say.
- `Macros.lua:86-98` — `regenFrame` + `armRegenRetry` (reference only; Phase 8 doesn't reuse this — zone events are not combat-locked).

### Phase 7 carry-forward (shipped this milestone, code complete, UAT deferred)
- `.planning/phases/07-verbose-marker-toggle/07-CONTEXT.md` — Phase 7 decisions D-01..D-16 (verbose-marker toggle, dual-field MACROS table). Independent of Phase 8 at the code level; UAT will combine.
- `.planning/phases/07-verbose-marker-toggle/07-01-SUMMARY.md` — Phase 7 shipped 2026-05-15; 4 commits aeca02b/e9840a3/570fefe/b1fd8a2.

### v1.0.0 carry-forward (relevant invariants)
- **AMEND-01 visibility-gated chat-event registration** (PROJECT.md Key Decisions, v1.0.0 RETROSPECTIVE.md). `OnShow` registers `CHAT_MSG_*`, `OnHide` unregisters. Phase 8's zone handler MUST route through `ns:Show()` / `ns:Hide()` (which trigger OnShow/OnHide via Window.lua's `win:Show()` / `win:Hide()`). NEVER use `SetAlpha(0)` for the zone-leave case — that would not unregister chat events, defeating the invariant.
- **`db.window.visible` is the persistence key for window visibility across `/reload`** (Phase 2 / Phase 3). Phase 8 doesn't introduce new state; the auto-handler just toggles this via the existing Show/Hide paths.

### Research surfaces (RESEARCH.md will resolve these)
- WoW Midnight (Interface 120005+) raid instance mapID for "March of Quel'danas" — single ID across all 4 difficulties (typical) vs separate per difficulty (atypical). User explicitly flagged this as the most important research output.
- Canonical mapID-lookup API for the Midnight client: `C_Map.GetBestMapForUnit("player")` (likely), or alternative.
- `OnShow`/`OnHide` re-fire semantics: confirm that calling `:Show()` on an already-shown frame is a true no-op (does NOT re-fire `OnShow`) and same for `:Hide()`. Determines whether redundant zone-event fires are free.
- PLAYER_ENTERING_WORLD vs ZONE_CHANGED_NEW_AREA firing order at session start — does PLAYER_ENTERING_WORLD always fire after ADDON_LOADED's RestoreWindowVisibility? If so, the order-of-operations analysis (D-12) holds.

### Hard constraints (permanent — carry-over)
- `CLAUDE.md` §"Hard Constraints" — never call `SendChatMessage`, never index `msg` from `CHAT_MSG_*` events, no `COMBAT_LOG_EVENT_UNFILTERED`. Phase 8 doesn't touch chat code paths; regression diff guard at UAT time.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`CreateFrame("Frame")` + `RegisterEvent` + `SetScript("OnEvent", ...)` pattern** — used by `eventFrame` (Core.lua:23-27), `regenFrame` (Macros.lua:86-94), `combatFrame` (Window.lua, Phase 5). The new `zoneFrame` follows the same pattern verbatim.
- **`ns:ShowWindow()` / `ns:HideWindow()` (Window.lua:441-458)** — fully reusable as the zone handler's terminal actions. They already write `db.window.visible`, fire `OnShow`/`OnHide` (via `win:Show()` / `win:Hide()`), apply soft-hide state, and notify the config panel for live label refresh. Phase 8 calls them without modification.
- **`ns:NotifyWindowVisibilityChanged()` (Window.lua, post-Phase 6)** — auto-called by Show/Hide. Phase 8 gets the live label refresh for free.

### Established Patterns
- **Verb-prefix `ns:On*Changed()` for callbacks** — used by `OnAutoHideChanged`, `OnMacroChannelChanged`, `OnVerboseMarkersChanged` (Phase 7). New handler follows the convention: `ns:OnZoneChanged()`.
- **Hardcoded numeric constants for stable Blizzard IDs** — e.g. icon FileDataIDs in `Macros.lua:17-23` (137001..137007). Phase 8's mapID constant follows the same pattern: numeric literal, top of file or near the handler, all-caps name.
- **Top-level `local FRAME = CreateFrame(...)` declarations at file scope** — established pattern in Core.lua, Macros.lua, Window.lua. Phase 8's `zoneFrame` lives at file scope in Core.lua.
- **Permanent event listeners (never unregister)** — `combatFrame` (Window.lua, Phase 5) is the closest analog. Phase 8's `zoneFrame` follows: register once at load, listen forever, simple OnEvent script.

### Integration Points
- **`Core.lua` — new top-level block** for `zoneFrame` declaration + `ns:OnZoneChanged()` function. Insertion site: after the existing `eventFrame` `SetScript` block (~line 126) and before the `ns:PrintHelp` function (~line 134), OR at the very end of the file. Planner picks based on readability.
- **`Window.lua:441-458`** — `ns:ShowWindow()` / `ns:HideWindow()`. Phase 8 calls these. NO modifications to Window.lua are needed for Phase 8's core feature.
- **No changes to `Macros.lua` or `Config.lua`** — Phase 8 is entirely additive in Core.lua.

### Existing Test Surface
- No automated test harness for WoW addons (CLAUDE.md). All testing is in-game smoke pass per the UAT checkpoints (D-17).
- `stylua` runs after Lua-file modifications (CLAUDE.md gate). Phase 8 modifies Core.lua only (single-file change).
- UAT will be combined with Phase 7's UAT per user preference (deferred-to-milestone-end pattern).

</code_context>

<specifics>
## Specific Ideas

- **The L'ura encounter is the entire reason this addon exists.** The auto-show/hide is high-value polish: it removes the cognitive overhead of remembering `/lura show` before every pull, AND removes the noise of having the window visible in town/while questing/while doing other content. Worth getting right; worth research time on the mapID question.
- **User's style: simple/native/no-special-cases.** Phase 8 should resist the urge to add a status print, a debug toggle, a kill-switch config option, or any other "polish" beyond the four locked requirements. The feature is invisible by design — the user notices its absence (window doesn't auto-show in raid) more than its presence (window appears when they zone in, and that just feels right).
- **Multi-difficulty insight from user is non-obvious:** Even though raids typically share one mapID across difficulties, the user has flagged this as worth confirming. Research should ground-truth this (likely via wowpedia / wow-ui-source / `C_Map` source files) rather than assume.

</specifics>

<deferred>
## Deferred Ideas

- **Auto-show/hide for the outdoor M of Q zone** (if a separate outdoor zone exists in Midnight) — out of scope per D-01. L'ura is the raid; the outdoor zone (if any) isn't relevant.
- **Auto-show/hide for adjacent encounters** (Magister's Terrace, Sunwell Plateau remake, future Midnight raids) — out of scope. Only the L'ura raid (M of Q instance) in v1.1.0.
- **Configurable in-zone mapID set** (user-editable list of "always show in these zones") — out of scope. Hardcoded for v1.1.0. Future milestone could add if a second raid would benefit from the same auto-toggle.
- **Print feedback on zone auto-fires** (e.g. `TLH: Entered M of Q — showing window`) — explicitly rejected per D-10 (would be spammy and uninformative; user sees the window appear).
- **Kill-switch toggle for the zone-auto feature** — out of scope per REQUIREMENTS.md OOS list. Always on in v1.1.0.
- **Saving last manual hide/show state across `/reload`** — user explicitly picked "auto-show if in zone" over "respect manual state" during `/gsd-new-milestone` questioning.
- **Per-character verbose-marker preference** — that's a Phase 7 OOS item, unrelated to Phase 8.
- **Debug print at addon-load showing detected mapID** — optional; planner can add at their discretion (default off behind a `local DEBUG = false` constant) but not required.

</deferred>

---

*Phase: 08-zone-aware-auto-show-hide*
*Context gathered: 2026-05-16*
