# Phase 3: Config Panel & Integration - Context

**Gathered:** 2026-05-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 fills `Config.lua` with a `Settings.RegisterAddOnCategory` panel under Options > AddOns, and wires every v1 configuration knob (six channel toggles, scale slider, alpha slider, auto-hide toggle, two action buttons, command-examples block) through to the live runtime. `/lura config` (and `/tlh config`) opens the panel directly. All settings persist via SavedVariables.

In scope: CFG-01..10, CMD-05, WIN-08, WIN-10. Plus two slash-command additions (`/lura lock`, `/lura unlock`) that emerged from this discussion.

Out of scope: any work that touches the chat-event pipeline, the macro registration logic, or the slot-fill/ClearAll path beyond what auto-hide and the recreate-macros button require.

</domain>

<decisions>
## Implementation Decisions

### Panel registration & overall shape (locked by SETTINGS_API.md research)
- **D-01:** Use the modern Settings API. Single `Settings.RegisterVerticalLayoutCategory("TerribleLuraHelper")` + `Settings.RegisterAddOnCategory(category)` — no canvas, no deprecated `InterfaceOptions_AddCategory`.
- **D-02:** Defer ALL `Settings.*` calls inside `EventUtil.ContinueOnAddOnLoaded(addonName, ...)` so SavedVariables are loaded. Top-level chunk in `Config.lua` registers the callback; everything else runs inside it.
- **D-03:** Cache `category:GetID()` on the namespace (`ns.settingsCategoryID`) at registration time. `/lura config` uses `Settings.OpenToCategory(ns.settingsCategoryID)` (the ID is a number — never pass the category name).
- **D-04:** Bind every persisted setting with `Settings.RegisterAddOnSetting` (NOT proxy). The framework auto-defaults the key on registration AND writes new values back on every change — no addon-side direct DB writes from change callbacks (CFG-09 is satisfied automatically).
- **D-05:** Argument order for `RegisterAddOnSetting` is the post-11.0.2 signature: `(categoryTbl, variable, variableKey, variableTbl, variableType, name, defaultValue)`. Old guides on the open web have it wrong.

### Layout order (vertical stack, top-down)
- **D-06:** Section "Chat channels" → 6 checkboxes (SAY, RAID, RAID_LEADER, RAID_WARNING, INSTANCE_CHAT, INSTANCE_CHAT_LEADER).
- **D-07:** Section "Window" → Scale slider, Alpha slider, "Auto-hide when empty" checkbox (in that order).
- **D-08:** Section "Actions" → "Recreate Macros" button, "Lock/Unlock window" button (label dynamic per current `db.window.locked` state).
- **D-09:** Section "Slash commands" → 8 sub-headers, one per command (see D-25 for the canonical list). Each header's tooltip describes the command.

### Channel toggles (CFG-02, CFG-03)
- **D-10:** DB key names match the existing schema written by Phase 1 / amended in Phase 2: `SAY`, `RAID`, `RAID_LEADER`, `RAID_WARNING`, `INSTANCE_CHAT`, `INSTANCE_CHAT_LEADER`. NOT `INSTANCE`/`INSTANCE_LEADER` as the original SETTINGS_API.md research example showed — keys must align with `event:sub(10)` in `Window.lua` chat handler.
- **D-11:** UI labels can be friendly: "Listen on /say", "Listen on /raid", "Listen on /raid (leader)", "Listen on /rw", "Listen on /instance", "Listen on /instance (leader)".
- **D-12:** Channel-toggle change callback is a no-op for chat-event registration. Filtering already happens at message time in Window.lua via `db.listenChannels[event:sub(10)]`. The framework writes the new boolean and the next incoming message reads it. No reload required, no event re-registration.
- **D-13:** All six channels default to `true`. Existing schema already does this; the panel registration uses `defaultValue = true` for symmetry but never actually overwrites since the keys exist.

### Scale & Alpha sliders (CFG-04, CFG-10, WIN-08, WIN-10)
- **D-14:** Scale slider: range 0.50–2.00, step 0.05, default 1.00. Live update via `setting:SetValueChangedCallback(function(_, v) ns:SetWindowScale(v) end)` where `ns:SetWindowScale(v)` calls `win:SetScale(v)` if `win` exists.
- **D-15:** Alpha slider: range 0.20–1.00, step 0.05, default 1.00. Live update similar — `ns:SetWindowAlpha(v)` writes through and applies live UNLESS the window is currently in soft-hide state (see D-19).
- **D-16:** Both sliders use `Settings.CreateSliderOptions(min, max, step)` + `:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)` for the right-side percentage label.
- **D-17:** Both `ns:SetWindowScale` and `ns:SetWindowAlpha` are new exports on `ns`, defined in `Window.lua` (not `Config.lua`). Config.lua just calls them. Keeps Window.lua the single owner of the frame.

### Auto-hide-when-empty (CFG-05) — soft-hide model
- **D-18:** Auto-hide is implemented as a **soft-hide** (alpha=0), NOT `win:Hide()`. Chat events stay registered while soft-hidden so the window can auto-reappear on next slot fill. This was the chosen path during discuss after Phase 2's AMEND-01 (visibility-gated chat events).
- **D-19:** `Window.lua` adds a Lua local `softHidden` flag and a helper `applySoftHideState()`:
  - Soft-hide enters when `db.window.autoHide == true` AND `#sequence == 0`. Sets `softHidden = true`, calls `win:SetAlpha(0)`.
  - Soft-hide exits when either `db.window.autoHide == false` OR `#sequence > 0`. Sets `softHidden = false`, calls `win:SetAlpha(db.window.alpha)`.
  - Called from: end of `FillSlot` (sequence > 0 → exit), end of `ClearAll` (sequence == 0 → maybe enter), the autoHide setting's change callback, and `ns:ShowWindow()`.
- **D-20:** `ns:ShowWindow()` always exits soft-hide and sets `win:SetAlpha(db.window.alpha)`. Explicit `/lura show` should produce a visible window even if `autoHide=on` and slots are empty — visibility is a UX confirmation that the addon is engaged. The next 20s self-clear re-enters soft-hide if `autoHide=on`.
- **D-21:** Alpha slider when `softHidden=true`: the change callback updates `db.window.alpha` but does NOT call `win:SetAlpha(value)` (the soft-hide override is in effect). The new alpha applies the next time soft-hide exits.
- **D-22:** Toggling `autoHide` to `true` while window is shown and sequence is empty → enter soft-hide immediately. Toggling to `false` while soft-hidden → exit immediately.

### Action buttons (CFG-06, CFG-07)
- **D-23:** "Recreate Macros" button OnClick checks `InCombatLockdown()`; if true, prints a `|cffaa44ffTLH|r:` notice that the macros will retry on `PLAYER_REGEN_ENABLED` (matches Phase 2's existing combat-deferral path) and returns. Otherwise calls `ns:RegisterMacros()` and prints "Macros recreated." regardless of the `macrosPrintedThisSession` once-per-session flag (explicit user action always confirms). Tooltip: "Recreates the five TLH_* player macros if you've deleted or edited them."
- **D-24:** "Lock/Unlock window" button uses the dynamic `buttonText` function pattern from SETTINGS_API.md research §4 — re-evaluated on `Init`, so the label is correct each time the panel reopens. OnClick calls `ns:ToggleLocked()` (already exported by Window.lua). Section name "Window"; tooltip: "Toggles whether the helper window can be dragged."

### Slash commands (CMD-05 + new commands from this discussion)
- **D-25:** Canonical slash command surface is now 8 commands (was 6). Add `/lura lock` and `/lura unlock` so the user has a slash-level escape hatch when the on-window Lock button is hidden (after Phase 2's AMEND-05 the button only appears when unlocked):
  - `/lura` — toggle window visibility
  - `/lura show` — show window
  - `/lura hide` — hide window + wipe
  - `/lura lock` — lock window (disable drag)
  - `/lura unlock` — unlock window (enable drag)
  - `/lura config` — open Options > AddOns > TerribleLuraHelper
  - `/lura help` — print this list
  - `/tlh` — alias for `/lura` (same subcommands)
- **D-26:** `/lura lock` and `/lura unlock` are direct setters (not toggles). Implementation: add `ns:LockWindow()` and `ns:UnlockWindow()` exports on Window.lua that set `db.window.locked` and call `applyLockState()`. Slash dispatcher routes the new tokens to these.
- **D-27:** `/lura config` opens the panel via `Settings.OpenToCategory(ns.settingsCategoryID)`; if the ID is somehow not yet captured (extremely unlikely — registration is synchronous w/r/t ADDON_LOADED), print a "settings not yet ready" notice and return.
- **D-28:** Update `ns:PrintHelp` in `Core.lua` to include all 8 commands, matching the panel's help-block content (single source of truth for the command list).

### File structure & boundaries
- **D-29:** `Config.lua` is a single file containing the EventUtil-deferred registration block plus 5 helper-style functions (one per logical group): `RegisterChannelToggles`, `RegisterScaleSlider`, `RegisterAlphaSlider`, `RegisterAutoHideToggle`, `RegisterActionButtons`, `RegisterCommandHelp`. Keeps Config.lua focused on "wire the panel" — no runtime logic lives here.
- **D-30:** Runtime logic edits land in: `Window.lua` (soft-hide state machine, `ns:SetWindowScale`, `ns:SetWindowAlpha`, `ns:LockWindow`, `ns:UnlockWindow`); `Core.lua` (slash dispatcher gains `lock`/`unlock` cases; `ns:PrintHelp` updated). `Macros.lua` is untouched; the recreate-macros button calls `ns:RegisterMacros()` directly and prints from the button's OnClick handler (so the once-per-session flag in Macros.lua doesn't suppress the explicit confirmation).
- **D-31:** Single plan delivers everything (Config.lua + Window.lua amendments + Core.lua amendments). Research is comprehensive; total LoC estimate is ~280 across files.

### Live-update interactions during combat
- **D-32:** `SetScale` and `SetAlpha` on a non-secure frame work in combat. Slider drags during combat are fine. The "Recreate Macros" button is the only combat-restricted control, guarded per D-23.

### Schema / migration
- **D-33:** `db.channels` (referenced as a possible holder name in SETTINGS_API.md research) does NOT exist. Existing schema uses `db.listenChannels`. The panel binds to `db.listenChannels` directly via the variableTbl arg. No schema migration needed.
- **D-34:** ~~No new fields land in `TerribleLuraHelperDB`.~~ AMENDED by D-35 below: one new field `db.macroChannel` is added in Phase 3. All other Phase 3 settings already exist.

### Macro target channel (CFG-11) — added 2026-05-01 after UI-SPEC review
- **D-35:** New DB field `db.macroChannel` (string, default `"RAID"`). Allowed values: `"RAID"`, `"RAID_WARNING"`, `"SAY"`. Added to defaults table AND backfill loop in `Core.lua` (mirrors how `db.window.alpha` was added in Phase 2 / 02-01).
- **D-36:** New control: dropdown via `Settings.CreateDropdown(category, setting, generator, tooltip)`. Generator returns a `Settings.CreateControlTextContainer()` populated with `("RAID", "/raid")`, `("RAID_WARNING", "/rw")`, `("SAY", "/s")`. Setting registered with `Settings.VarType.String`, default `"RAID"`.
- **D-37:** On dropdown change: `setting:SetValueChangedCallback(function(_, value) ns:OnMacroChannelChanged(value) end)`. `ns:OnMacroChannelChanged` calls `ns:RegisterMacros()` (which is already idempotent and uses the new `db.macroChannel` value). If `InCombatLockdown()` is true, the existing combat-deferral path in `Macros.lua` (lines 33-36) handles retry on `PLAYER_REGEN_ENABLED` — same path as the panel button uses.
- **D-38:** `Macros.lua` `MACROS` table no longer hardcodes the slash prefix. The table holds `{ name, rt, icon }` rows; the body is built at registration time:
  ```lua
  local CHANNEL_PREFIX = { RAID = "/raid", RAID_WARNING = "/rw", SAY = "/s" }
  local prefix = CHANNEL_PREFIX[ns.db.macroChannel] or "/raid"
  local body = prefix .. " {rt" .. row.rt .. "}"
  ```
  This is constant-string concatenation by us, NOT touching `msg` from a chat event — fully safe per CLAUDE.md hard constraints.

### Section restructure (UI organization) — added 2026-05-01 after UI-SPEC review
- **D-39:** Final 4 panel sections (replaces the original "Chat channels / Window / Actions / Slash commands" of D-06..D-09):
  1. **Chat channels** (unchanged — 6 listen toggles)
  2. **Window** (scale slider, alpha slider, auto-hide checkbox, **lock/unlock button moved here from "Actions"** — natural fit since all four govern the helper window)
  3. **Macros** (new section — macro target channel dropdown, recreate/update button)
  4. **Slash commands** (unchanged — 8 help entries)
- **D-40:** Recreate-macros button text changes from `"Recreate macros"` → `"Recreate / update macros"`. The underlying logic is already idempotent (EditMacro for existing, CreateMacro for missing); the new wording communicates this. Button left-side `name` becomes `"Macros"` (already was). Tooltip stays the same.

### Claude's Discretion
- Tooltip wording for individual checkboxes/sliders/buttons — match the Blizzard panel tone (concise, single sentence, action-focused). The strings in SETTINGS_API.md research are reasonable starting points.
- Internal helper-function naming (`RegisterChannelToggles` etc.) — the research uses these exact names; planner can keep or refactor as long as Config.lua stays single-file and registration runs in order.
- Whether to print a small "panel registered" load-time line. Default: silent. The Phase 1 banner `TerribleLuraHelper loaded.` already confirms load.

</decisions>

<specifics>
## Specific Ideas

- The L'ura void/light palette established in Phase 2 (midnight-navy bg `0.05, 0.07, 0.18`, cream-gold filled border `1.0, 0.92, 0.7`, parchment-grey idle border `0.65, 0.62, 0.55`) is OUT OF SCOPE for the panel itself — Blizzard's Settings panel renders with its own native chrome. The palette only applies to the helper window.
- Auto-hide UX rationale: "the window is mostly invisible and pops in when L'ura runes arrive" matches the original spec intent. Soft-hide via alpha=0 preserves that with the new visibility-gated chat-event model.
- Slash-command symmetry: `/lura lock` and `/lura unlock` follow the show/hide naming pattern. Direct setters (not toggles) so users can bind keys for predictable single-direction commands.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Settings API
- `.planning/research/SETTINGS_API.md` — comprehensive research doc, verified against `wow-ui-source@12.0.1`. Has copy-pastable code patterns for every control type Phase 3 needs. Adapt the channel-toggle holder-table name to `listenChannels` (per D-10/D-33) and drop the `/lura clear` line from the help block (per D-25).

### Phase 2 amendments that affect Phase 3
- `.planning/phases/02-poc-port-macros-window-commands/02-VERIFICATION.md` frontmatter `post_execution_amendments` — AMEND-01 (visibility-gated chat events), AMEND-02 (`db.enabled` removed), AMEND-05 (lock button hidden when locked), AMEND-06 (default unlocked).
- `.planning/phases/02-poc-port-macros-window-commands/02-CONTEXT.md` "Post-execution amendments" section — TL;DR of the same.

### Project / requirements
- `.planning/PROJECT.md` — Config panel section under "Active" lists the v1 knobs.
- `.planning/REQUIREMENTS.md` §"Config Panel" — CFG-01..CFG-10 wording.
- `.planning/ROADMAP.md` Phase 3 — success criteria.

### Reference code
- `Window.lua` — current OnShow/OnHide pattern; ns:ShowWindow / ns:HideWindow / ns:ToggleLocked / ns:WipeSequence exports; FillSlot / ClearAll path that the soft-hide hooks must integrate with.
- `Macros.lua` `ns:RegisterMacros()` — the recreate-macros button's target.
- `Core.lua` `ns:PrintHelp()` and slash dispatcher — the surfaces gaining `/lura lock` and `/lura unlock`.
- `C:\Users\jonat\Repositories\wow-ui-source\Interface\AddOns\Blizzard_Settings_Shared\` — Blizzard source for any in-flight verification against `version.txt = 12.0.1.66337`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ns:RegisterMacros()` in `Macros.lua` — recreate-macros button calls this directly, no wrapper needed.
- `ns:ToggleLocked()` in `Window.lua` — already exported; lock/unlock button calls it. New `ns:LockWindow` / `ns:UnlockWindow` are thin wrappers around `applyLockState()`.
- `ns:ShowWindow` / `ns:HideWindow` — existing exports; `/lura config` opens the panel without changing window visibility.
- `EventUtil.ContinueOnAddOnLoaded` — the gate for SavedVariables-dependent registration.
- Existing `db.listenChannels`, `db.window.{scale, alpha, locked, autoHide, position}` in the schema — the panel binds to these directly. No schema additions required.

### Patterns to Mirror
- `Macros.lua` combat-lockdown deferral pattern (`InCombatLockdown()` early-return + `PLAYER_REGEN_ENABLED` retry frame) — the recreate-macros button uses the early-return half (the retry frame is already armed by `ns:InitMacros` once per session).
- `Window.lua` chat-event-registration tied to OnShow/OnHide — Phase 3 does NOT touch this; channel filter operates on the same handler that already exists.

### Anti-patterns Observed
- `InterfaceOptions_AddCategory` — DEAD CODE in 12.0; never use it. (See SETTINGS_API.md footgun §7.)
- Passing the category *name* to `Settings.OpenToCategory` — must be the category *ID* (number from `category:GetID()`).
- Calling `Settings.RegisterAddOnSetting` outside `EventUtil.ContinueOnAddOnLoaded` — hard error from the assert at `Blizzard_Setting.lua:417` if `db` is nil at registration time.

</code_context>

---

## Post-execution amendments

Phase 2 set the precedent of capturing post-execution design changes in the verification doc's frontmatter. If Phase 3 picks up similar amendments during execution, they'll land in `03-VERIFICATION.md`.

---

*Phase: 03-config-panel-integration*
*Context gathered: 2026-05-01*
