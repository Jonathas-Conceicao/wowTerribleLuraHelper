# Phase 2: POC Port (Macros, Window, Commands) - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Lift the POC at `WeakerScripts/Samples/LuraPatternHelper.lua` into the standalone addon. Phase 2 fills `Macros.lua` and `Window.lua` (Phase 1 stubs), implements the slash-command dispatcher in `Core.lua`, and wires up the chat-event piggyback pipeline that converts `{rt#}` markers into rendered raid icons on the smile-arc helper window. Adds the `/lura show/hide` enable/disable processing semantics that the POC doesn't have, and tightens scope to in-memory state (no SavedVariables sequence persistence).

In scope: macro registration with combat-lockdown deferral, helper window (smile-arc layout, lock/unlock button, drag-position persistence, 20s self-clear, modern Blizzard frame template), slash commands (`/lura` + subcommands + `/tlh` alias + `/lura help`), chat-event handler with channel filter (uses `db.listenChannels[event:sub(10)]` per D-05).

Out of scope (Phase 3): Settings panel registration, `/lura config` actually opening the panel (the slash command stub returns "config UI lands in Phase 3" until Phase 3), live scale-slider updates, auto-hide-when-empty behavior, recreate-macros button, channel-toggle UI checkboxes.

</domain>

<decisions>
## Implementation Decisions

### Lock Button (WIN-05)

- **D-14:** Lock/unlock button is a small padlock-icon button positioned **immediately to the left of the close-X** in the top-right of the title bar. Open-padlock when unlocked (drag enabled), closed-padlock when locked (drag disabled). Mirrors WoW's MovableFrames / Edit-Mode convention.
- **D-15:** Default state on a fresh DB: `db.window.locked = true` (already in Phase 1 SavedVariables defaults). Window must be unlocked once before the user can drag it. The padlock click toggles `db.window.locked` and rebinds the drag handlers (`RegisterForDrag` / `SetMovable`).
- **D-16:** The padlock button reuses Blizzard's built-in lock/unlock textures where available (e.g. `Interface/Buttons/LockButton-Locked-Up`, `LockButton-Unlocked-Up`) so the styling matches native UI. Planner picks the exact texture if a more current set exists in 12.0.

### Window Frame Template (WIN-01..05)

- **D-17:** Drop the POC's `BackdropTemplate` + custom purple coloring. Use a modern Blizzard frame template — `BasicFrameTemplateWithInset` is the recommended target (title bar with built-in close button, content inset area for the smile-arc, no portrait area we don't need). Planner verifies this is the right template by reading `wow-ui-source` (style reference path in CLAUDE.md) — accept `BasicFrameTemplate` (no inset) or `PortraitFrameTemplate` if the planner finds a better fit. **Do NOT use ButtonFrameTemplate** unless an icon portrait is added (currently OOS).
- **D-18:** The smile-arc layout (slot positions, 1-5 numeric labels, BOSS center, TANK above slot 3) ports verbatim from the POC. The template change affects chrome (title bar, close button, backdrop) only — the slot geometry inside the inset area stays the same.
- **D-19:** Window title text: `Terrible L'ura Helper` (matches POC). Color → planner picks (template's default title color is fine; no need to force POC's purple).

### Window Position Persistence (WIN-09)

- **D-20:** On `OnDragStop` (after `StopMovingOrSizing`), capture the position via `frame:GetPoint()` (returns `point, relativeTo, relativePoint, x, y`) and store in `db.window.position` as a 5-tuple table: `{point, relativeTo == nil and "UIParent" or relativeTo:GetName(), relativePoint, x, y}`. Storing the relativeTo *name* (string) avoids retaining a frame reference that may become stale across `/reload`.
- **D-21:** On window first-show, if `db.window.position` exists, apply via `frame:ClearAllPoints(); frame:SetPoint(unpack({point, _G[relativeToName] or UIParent, relativePoint, x, y}))`. Falls back to `_G[relativeToName] or UIParent` for stale references. Default anchor when `db.window.position` is nil: `CENTER UIParent CENTER 200 80` (matches POC exactly).
- **D-22:** No off-screen guard for v1. WoW's `SetClampedToScreen(true)` (which the POC sets) handles edge cases automatically — the window can't drag past screen edges.

### Slash Command Surface (CMD-01..06, CMD-07 NEW)

Final v1 command set:

- `/lura show` — enable processing + show window (D-23)
- `/lura hide` — disable processing + clear sequence (in-memory) + hide window (D-24)
- `/lura config` — open Options > AddOns > TerribleLuraHelper page (Phase 3 wires this; Phase 2's stub prints `"Config panel lands in Phase 3."`)
- `/lura help` — print the slash command list to chat with brief descriptions (NEW — adds CMD-07 to REQUIREMENTS.md)
- `/lura` (no args) — pure toggle: enabled → run hide path, disabled → run show path (D-25)
- `/tlh` — full alias for `/lura` with identical subcommand parsing and dispatch (D-26)

**DROPPED:**
- `/lura clear` (CMD-04 in REQUIREMENTS.md before this discuss) — removed. `/lura hide` does a clean wipe + disable; the 20s inactivity self-clear handles the "between pulls" use case automatically. Simpler command surface.

### State Edge Cases (CMD-01..03, SAFE-04)

- **D-23 (mid-combat /lura show):** When `/lura show` fires while combat is already active (`InCombatLockdown()` true), register the `CHAT_MSG_*` events immediately. The user starts catching markers from that point onward. Markers that fired before `/lura show` are simply missed — that's fine; the user opted in late.
- **D-24 (/lura hide wipe):** `/lura hide` (and the addon-disabled state generally) triggers a full wipe — clears the in-memory sequence, hides the window, unregisters the `CHAT_MSG_*` events. No DB write. Predictable mental model: hide = disable + clean slate.
- **D-25 (/lura toggle):** Bare `/lura` is a pure toggle. If `db.enabled` is true, run the hide path; if false, run the show path. No clever 3-state cycle.
- **D-26 (/tlh dispatch):** `/tlh` shares a single dispatch function with `/lura`. Implementation detail: register `SLASH_TLH1 = "/tlh"`, `SLASH_TLH2 = "/lura"` (or two SlashCmdList entries pointing at the same handler) — planner picks the cleaner pattern.

### State Storage Model (WIN-07 SCOPE CHANGE)

- **D-27:** Sequence is **in-memory only** — stored in `ns.sequence` (or local upvalue), NOT in `TerribleLuraHelperDB`. `/reload` rebuilds Lua state, so sequence is lost after reload. `/lura hide` clears it. The 20s inactivity timer clears it.
  - **WIN-07 ("sequence persists across /reload") is DROPPED** — moved to Out of Scope in REQUIREMENTS.md with reason "user opted for in-memory-only state — simpler, avoids disk writes for transient combat data".
  - **`db.sequence = {}` in Phase 1's Core.lua schema becomes dead code** — Phase 2's first task removes it from the defaults table AND any backfill loop entry that touches it. The amendment lands in `Core.lua` on the milestone branch.
  - The "no string ops on msg" constraint (SAFE-02) still applies — sequence still stores opaque post-processed `|T...|t` strings; we just don't write them to disk.

### Inactivity Timeout (WIN-06)

- **D-28:** Inactivity timeout bumped from **15s → 20s**. WIN-06 amended in REQUIREMENTS.md. Reason: 20s gives a slightly safer margin for slow message arrival during high-latency raid combat.
- **D-29:** Timer hardcoded for v1 — still no config option (matches the OOS in PROJECT.md). The literal `20` lives as a named constant near the top of `Window.lua` (e.g. `local INACTIVITY_TIMEOUT = 20`) so a future v2 can promote it without spelunking.

### Window Alpha (NEW — added after Phase 2 UI-SPEC; mirrors scale slider pattern)

- **D-35:** New SavedVariables field `db.window.alpha` (range 0.20–1.00, default 1.00). Phase 2's first cleanup task adds `alpha = 1.00` to `Core.lua`'s grouped schema **alongside removing `db.sequence`** (per D-27). The DB backfill loop adds the same `if cs.alpha == nil then cs.alpha = 1.00 end` style entry so existing DBs get the new field.
- **D-36:** Phase 2's `Window.lua` reads `db.window.alpha` once at frame creation: `win:SetAlpha(db.window.alpha)`. No live update logic in Phase 2 — the slider lives in Phase 3 (CFG-10), and Phase 3 owns the `frame:SetAlpha(value)` change-callback wire-up. This mirrors the scale-slider plumbing pattern (`db.window.scale` → Phase 2 reads at creation; Phase 3 adds the slider per CFG-04).
- **D-37:** Range chosen: **0.20–1.00** (not 0.10), step **0.05**. Below 0.20 the slot icons become unreadable in raid encounters with bright background effects; 0.20 is the practical floor. Default `1.00` keeps the window fully opaque on first install.
- **REQUIREMENTS.md updated:** WIN-10 added (Phase 3 owns the live update; Phase 2 the default-read), CFG-10 added (Phase 3 slider UI), SCAF-03 schema description amended retroactively.

### Chat-Event Pipeline (WIN-03, SAFE-01..04)

- **D-30:** Verbatim port of POC's chat handler (POC lines 250-271). The `msg` argument is passed opaquely through `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` (the Blizzard-secure helper, exempt from taint check) directly into `FontString:SetText`. **Zero string operations on `msg` in Lua code** (SAFE-02).
- **D-31:** Channel filtering (CFG-03 in Phase 3, but plumbed in Phase 2): the chat-event handler always receives all 6 events when registered, but checks `db.listenChannels[event:sub(10)]` before processing. If `false`, drop the event. The filter table key matches the event suffix exactly per D-05 — no translation table.
- **D-32:** Event registration gating combines TWO flags:
  - Combat state: `PLAYER_REGEN_DISABLED` enables, `PLAYER_REGEN_ENABLED` disables (mirrors POC).
  - Addon-enabled state: `db.enabled == true` is also required.
  - Truth table (combat × enabled): `(true, true)` → register; `(true, false)` → unregister/skip; `(false, *)` → unregister.
  - **D-23 caveat:** if `/lura show` fires during combat, immediately register the events even though `PLAYER_REGEN_DISABLED` already fired (we missed it). Symmetric: `/lura hide` mid-combat unregisters immediately.

### Macros (MACR-01..05)

- **D-33:** Verbatim port of POC's macro registration (POC lines 42-78). The 5 macros + raid-marker FileDataIDs + idempotent CreateMacro/EditMacro pattern + InCombatLockdown + PLAYER_REGEN_ENABLED retry — all unchanged.
- **D-34:** First-session "drag the macros" hint print (POC's `_luraMacrosPrinted` pattern) ports as-is. Track the printed-once flag in a Lua local, not in the DB — printing once per session matches the POC's behavior.

### Claude's Discretion

- Exact Blizzard frame template within the "modern" set (`BasicFrameTemplateWithInset` recommended; planner can pick `BasicFrameTemplate` or `PortraitFrameTemplate` if it finds a better fit while reading `wow-ui-source`).
- Padlock button textures (Blizzard built-in lock/unlock atlas paths).
- Slash command help text formatting and color codes for `/lura help` output.
- Module-internal organization of `Window.lua` (single function vs split into create/show/clear/etc.).
- Whether to expose `INACTIVITY_TIMEOUT` and other named constants at module top or scoped near use.
- Title-bar color (modern templates have a default; OK to keep that).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context (locked decisions)
- `.planning/PROJECT.md` — Core Value, Constraints, Out of Scope (especially: no `SendChatMessage` ever, no `msg` string ops, no `COMBAT_LOG_EVENT_UNFILTERED`, Interface 120005)
- `.planning/REQUIREMENTS.md` — Phase 2 owns MACR-01..05, WIN-01..06, WIN-08, WIN-09, CMD-01..03, CMD-05..07, SAFE-01..04 (note: WIN-07 dropped, CMD-04 dropped, CMD-07 added — see Phase 2 amendments below)
- `.planning/ROADMAP.md` — Phase 2 success criteria
- `.planning/phases/01-scaffolding-foundation/01-CONTEXT.md` — Phase 1 locked decisions D-01..D-13 (especially D-03 grouped DB schema, D-05 channel keys match event suffixes)
- `CLAUDE.md` — workflow rules (milestone/0.1.0 + squash-merge + stylua), hard taint constraints

### Functional spec
- `C:\Users\jonat\Repositories\WeakerScripts\Samples\LuraPatternHelper.lua` — the POC, full functional spec for runtime behavior. **Read the module-header docstring before any other code path** — it documents *why* each piece is shaped the way it is. Phase 2 deviations from the POC are explicitly listed in this CONTEXT.md (D-17 backdrop, D-23-25 state semantics, D-27 in-memory-only, D-28 timeout, /lura help, dropping /lura clear). Everything else is verbatim port.

### WoW API references
- `C:\Users\jonat\Repositories\wow-ui-source` (filesystem) — Blizzard UI source for frame template selection (D-17). Specifically:
  - `Interface\FrameXML\BasicFrameTemplate.xml` (or current location in 12.0) for `BasicFrameTemplate` / `BasicFrameTemplateWithInset`
  - `Interface\AddOns\Blizzard_*` for any portrait/inset/title-bar-button conventions
- `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` is the Blizzard-secure helper used for chat icon expansion — taint-safe. POC line 261. Do NOT use `ChatFrame_ReplaceIconAndGroupExpressions` (older alias).

### Sibling addon scaffolding (carried from Phase 1)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\Core.lua` — namespace + ADDON_LOADED + DB defaults pattern (Phase 1 already mirrored this; Phase 2 should match the same code style)

</canonical_refs>

<code_context>
## Existing Code Insights (this codebase)

### Reusable Assets (Phase 1 deliverables)
- `Core.lua` (already exists) — namespace, ADDON_LOADED handler, grouped DB schema with backfill loop, dispatcher (`ns:InitMacros`, `ns:InitWindow`, `ns:InitConfig`), load banner. Phase 2 adds slash command registration here (in the same file, beneath the existing handler).
- `Macros.lua` (stub) — has `local addonName, ns = ...`, header comment, `function ns:InitMacros() end`. Phase 2 fills the function body.
- `Window.lua` (stub) — same shape as Macros.lua. Phase 2 fills the body.
- `Config.lua` (stub) — Phase 3 territory; do not touch in Phase 2.
- `TerribleLuraHelper.toc` — load order is Core → Macros → Window → Config (D-02 from Phase 1). Phase 2 adds nothing new to the .toc.
- `db.window.position` field already exists at `nil` in Core.lua's Phase 1 schema (per D-04). Phase 2 reads/writes it.

### Established Patterns
- **Namespace:** `local addonName, ns = ...` first line of every Lua file. Phase 2 functions hang off `ns.`
- **Backfill loop in Core.lua's ADDON_LOADED** (Phase 1) — Phase 2 amends to **remove the `db.sequence = {}` default** entry per D-27 (and add the corresponding cleanup if there was a sequence-specific backfill check).
- **Dispatcher pattern:** Core.lua's ADDON_LOADED calls `ns:InitMacros()` and `ns:InitWindow()` (Phase 2 fills) and `ns:InitConfig()` (Phase 3 fills). Order matters — Macros first (creates macros if out of combat), then Window (creates frame, hidden by default), then Config (no-op stub in Phase 2).
- **Combat-safe boundary:** anything that creates macros or modifies frame protection state must be guarded by `InCombatLockdown()`. Window creation does NOT need this guard (it's just a regular Frame).

### Integration Points
- `Core.lua`'s slash command dispatcher (Phase 2 adds) calls into `ns:WindowShow()`, `ns:WindowHide()`, `ns:RegisterMacros()`, `ns:PrintHelp()` etc.
- The `db.listenChannels` table (Phase 1) is read by Phase 2's chat handler.
- The `db.window.{scale, locked, position, autoHide}` fields are read by Phase 2's window code (autoHide is read but the corresponding behavior is Phase 3's responsibility — Phase 2 just respects the flag if set; Phase 3 adds the UI to set it).

</code_context>

<specifics>
## Specific Ideas / References

- **POC line numbers worth quoting:** macro registration (POC 42-78), window creation (POC 90-178), chat handler (POC 240-271), slash dispatcher (POC 280-293). The planner should reference these line ranges when describing what to port.
- **The padlock icon textures should match Blizzard's** — concrete suggestion: `Interface/Buttons/LockButton-Locked-Up.blp` and `LockButton-Unlocked-Up.blp` (12.0 still uses these; planner verifies via wow-ui-source).
- **`/lura help` output format** — should mirror TBT's load-banner color scheme (cyan addon name + colored commands), and list each command with a one-line description. Example:
  ```
  |cffaa44ffTerribleLuraHelper|r commands:
    |cffffd700/lura show|r       Enable + show window
    |cffffd700/lura hide|r       Disable + hide window
    |cffffd700/lura config|r     Open Options > AddOns > TLH
    |cffffd700/lura help|r       Show this help
    |cffffd700/lura|r            Toggle enabled/disabled
  |cffffd700/tlh|r is an alias for |cffffd700/lura|r with the same subcommands.
  ```
  Planner can refine; this is a starting point.

</specifics>

<deferred>
## Deferred Ideas

- **Configurable inactivity timeout** — still OOS per PROJECT.md. D-28 only changes the literal from 15s to 20s; doesn't add a config option.
- **Sequence persistence across /reload** — explicitly dropped per D-27. Was WIN-07 in REQUIREMENTS.md; now Out of Scope.
- **`/lura clear` standalone command** — dropped per the slash-command revision. Was CMD-04; merged into `/lura hide` (which already wipes).
- **Off-screen window position guard** — `SetClampedToScreen` handles it; no Phase 2 code needed.
- **Auto-hide-when-empty hook in Phase 2** — user opted to leave this entirely to Phase 3. Phase 2's window code does NOT pre-plumb the auto-hide behavior. Phase 3 adds both the UI checkbox AND the window-hide logic.
- **Custom addon icon (.blp)** — still OOS in PROJECT.md.

</deferred>

---

## Post-execution amendments (2026-05-01)

The CONTEXT decisions above reflect what was *planned*. During execution
+ in-game smoke testing several decisions were superseded. Authoritative
record lives in `02-VERIFICATION.md` frontmatter under `post_execution_amendments`.
TL;DR:

- **AMEND-01**: D-23, D-24, D-32, SAFE-04 — combat-gated chat-event registration replaced with visibility-gated (`OnShow` registers, `OnHide` unregisters + wipes).
- **AMEND-02**: D-25 — `db.enabled` removed from schema; `win:IsShown()` is the single source of truth.
- **AMEND-03**: macro registration moved from `ADDON_LOADED` to `PLAYER_LOGIN` (CreateMacro is unreliable at ADDON_LOADED).
- **AMEND-04**: D-15, D-17 — chrome rebuilt to plain `BackdropTemplate` with solid midnight-navy backdrop; no title bar, no close button.
- **AMEND-05**: D-14, D-16 — lock button is text "Lock" at bottom-right, hidden when locked.
- **AMEND-06**: D-22 — default window state changed from locked to unlocked.
- **AMEND-07, AMEND-08**: slot palette retheme (warm parchment-grey → cream-gold) + window dimensions / slot positions retuned for non-overlapping smile-arc.

The original CONTEXT decisions remain useful as historical artifacts of what was discussed; the amendments are the actual shipped behavior.

---

*Phase: 02-poc-port-macros-window-commands*
*Context gathered: 2026-04-30*
*Amendments captured: 2026-05-01*
