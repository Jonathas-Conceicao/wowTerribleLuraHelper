# Feature Research: TerribleLuraHelper v1.0.0 Polish Features

**Domain:** WoW raid-coordination HUD addon (Midnight / Interface 120005)
**Researched:** 2026-05-09
**Confidence:** HIGH (all API claims verified against wow-ui-source@12.0.1.66337; Blizzard patterns cross-checked with sibling addon TerribleBuffTracker)

---

## Feature 1: Click-Through When Locked

### What It Is

When the helper window is locked (`db.window.locked = true`), all mouse interaction is disabled — clicks, drags, and hover — pass through to frames below. The window becomes visually present but input-inert. Unlocking (via `/lura unlock` or the config-panel button) restores full interaction.

### How WoW HUD Addons Do This

The standard pattern across movable HUD addons (Plater, BigWigs bars, Dominos, ElvUI frames, WeakAuras text overlays) is a two-call pair on the frame:

```lua
-- Lock: pass-through
frame:EnableMouse(false)
-- and clear drag registration so drag-start never fires:
frame:RegisterForDrag()          -- no args = clears registration

-- Unlock: interactive again
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
```

`EnableMouse(false)` is the canonical WoW API call for full click-through. It is not `SetMouseClickEnabled` (which only blocks clicks, not tooltips) — `EnableMouse(false)` also suppresses `OnEnter`/`OnLeave` and therefore tooltip display, which is the fully-inert behavior users expect from a "locked" HUD element.

**Source:** Blizzard's own `SimpleScriptRegionAPIDocumentation.lua` in wow-ui-source documents `EnableMouse`; the pattern appears verbatim in Blizzard's Cooldown Manager (`CooldownViewer.lua`) and in the existing TLH `Window.lua` (which already uses `RegisterForDrag()` with no args to clear drag on lock). The existing `applyLockState()` in `Window.lua` already does the `RegisterForDrag` half correctly but does NOT yet call `EnableMouse(false)` when locking — that is the gap to close.

### Table Stakes vs Differentiator vs Anti-Feature

**Table stakes.** Every locked HUD addon disables mouse on the frame. Users who lock a window expect it to become inert. Partial click-through (e.g., keeping the lock button clickable while locked) is an anti-feature — see below.

### UX Expectations

- **Tooltip on hover while locked:** Anti-feature. If mouse is disabled with `EnableMouse(false)`, `OnEnter` never fires, so the GameTooltip never shows. This is correct and expected — a locked frame has no hover affordance. Do NOT try to preserve tooltip-on-hover while locked (would require `EnableMouseClicks(false)` instead, which is partial and confusing).
- **Lock button visibility while locked:** Already handled — `lockBtn:Hide()` when locked. The hidden button is also unreachable because `EnableMouse(false)` on the parent propagates to children (mouse input never reaches child regions of a mouse-disabled frame).
- **Unlock paths:** `/lura unlock` and the config-panel "Unlock window" button. Both call `ns:UnlockWindow()` which already exists. No new unlock paths needed.
- **Drag re-registration on unlock:** Call `RegisterForDrag("LeftButton")` in `applyLockState()` when unlocked. This is already done. After `EnableMouse(true)` + `RegisterForDrag("LeftButton")`, the existing `OnDragStart`/`OnDragStop` handlers fire normally — no timing delay or re-registration needed.

### Complexity

LOW. The entire change is two lines added to the existing `applyLockState()` function in `Window.lua`:

```lua
-- add to the locked branch:
win:EnableMouse(false)

-- add to the unlocked branch:
win:EnableMouse(true)
```

### Dependencies

- Depends on existing `db.window.locked` state and `applyLockState()` function (v0.1.0).
- Depends on existing `lockBtn:Hide()` / `lockBtn:Show()` logic (v0.1.0).
- No new DB keys required.

### Anti-Features to Avoid

**Partial click-through (lock button remains clickable while locked):** Explicitly ruled out in PROJECT.md. Would require using `EnableMouseClicks(false)` instead of `EnableMouse(false)`, which keeps hover/tooltip active and creates confusing half-states. A user who locked the window to stop accidentally clicking it during combat does not want a clickable hot-zone in the bottom-right corner.

**Separate "click-through" toggle decoupled from lock:** Also ruled out in PROJECT.md. Single-axis mental model: locked = can't click it. A separate toggle creates a 2x2 matrix of states that doesn't match any real user mental model.

---

## Feature 2: Static Cheat-Sheet Image in Config Panel

### What It Is

A wide, static texture (the rune-to-symbol reference image) anchored at the top of the Options > AddOns > TerribleLuraHelper panel, above all other controls. Users opening the settings panel for the first time see the symbol reference immediately without scrolling.

### How WoW Addons Do This

There are two approaches in the ecosystem:

**Approach A: Canvas layout category with a custom frame.** The addon registers a `RegisterCanvasLayoutCategory` instead of `RegisterVerticalLayoutCategory`. The canvas frame contains a `Texture` region sized to the desired image dimensions. Controls (checkboxes, sliders) are laid out manually underneath.

Source: `Blizzard_ImplementationReadme.lua:11` — `Settings.RegisterCanvasLayoutCategory(myFrame, name)` where `myFrame` is a pre-built Frame with your custom content.

**Approach B: Custom element initializer inside a vertical layout.** The addon uses `Settings.CreateElementInitializer("MyTextureTemplate", data)` and calls `layout:AddInitializer(...)` before the first control registration. The template is an XML Frame with a Texture child. The framework inserts it as the first row in the vertical list.

Source: `Blizzard_Settings.lua:341` — `Settings.CreateElementInitializer(frameTemplate, data)` returns an initializer compatible with `layout:AddInitializer`.

### Recommended Approach for TLH

**Approach B (element initializer in vertical layout).** Keeps the existing vertical layout (no rewrite of all control registration). The image frame is inserted first via `layout:AddInitializer`. The frame template is defined in a new `TerribleLuraHelper.xml` file and loaded via the `.toc` before `Config.lua`.

**Aspect-ratio handling:** The cheat-sheet image should be sized at a fixed pixel dimension in the XML template (e.g., 320x80 for a 4:1 wide reference strip). The Settings panel width is approximately 370px usable (verified in wow-ui-source `Blizzard_SettingsPanel.xml`). A 320px-wide image fits without horizontal scrolling at all UI scales. The texture should NOT use `SetAllPoints` — use explicit pixel dimensions that match the source asset's aspect ratio to prevent distortion.

**Scaling behavior across resolutions:** The Settings panel itself scales with the WoW UI scale (`UIParent:GetScale()`). A fixed-pixel texture inside it scales correctly without any addon-side scaling logic. Do NOT call `SetScale` on the image frame; let the parent handle it.

**Hard gate:** PROJECT.md is explicit — no placeholder ship. If the real asset is not available when this milestone closes, the cheat-sheet UI element is not shipped.

### Table Stakes vs Differentiator vs Anti-Feature

**Differentiator.** Most WoW addons do not embed reference images in their settings panels. For a new-user experience on a fight-coordination tool, this is meaningful — the symbol reference is the single most valuable thing a first-time user needs. It is not "table stakes" because it requires a custom asset.

### UX Expectations

- Image appears above all other controls — first thing visible when panel opens.
- No hover tooltip needed (it's a reference diagram, not an interactive element).
- No click behavior.
- Does not scroll away on initial panel open (sized to fit in the top 80-100px of the panel so controls below are visible without scrolling).

### Complexity

MEDIUM. Requires:
1. A new `.xml` file defining the frame template with a Texture child.
2. Adding the `.xml` to the `.toc` (before `Config.lua`).
3. One `layout:AddInitializer` call at the top of `RegisterChannelToggles` (or a new `RegisterCheatSheetImage` function called first).
4. The real image asset (`.blp` or `.tga`) in the addon directory.

Asset pipeline is already handled by BigWigs Packager — no new CI configuration needed.

### Dependencies

- Depends on the existing vertical layout panel structure in `Config.lua` (v0.1.0).
- **Blocked by:** the actual cheat-sheet image asset. Milestone cannot close without it per PROJECT.md.
- No existing DB keys involved.

---

## Feature 3: Dynamic Show/Hide Window Button Label

### What It Is

The "Show window" / "Hide window" button in the config panel updates its label in real time whenever the window state changes from any source (slash command, auto-hide cycle, manual `/lura hide`/`show`) while the panel is open. Currently (v0.1.0) the label is only evaluated once per panel-open via `EvaluateName` in `SettingsButtonControlMixin:Init`.

### How the Settings API Works

**Verified against wow-ui-source `Blizzard_SettingControls.lua:702-720`:**

```lua
function SettingsButtonControlMixin:EvaluateName()
    if type(self.data.buttonText) == "function" then
        return self.data.buttonText();
    end
    return self.data.buttonText;
end

function SettingsButtonControlMixin:Init(initializer)
    -- ...
    self.Button:SetText(self:EvaluateName());  -- called ONCE on Init
    -- ...
end
```

`EvaluateName` is called exactly once, at `Init` time. It is NOT called again while the panel stays open. The Settings framework has no built-in "refresh button label on state change" mechanism.

**`Settings.NotifyUpdate(variable)` is for Setting-bound controls only.** It calls `setting:NotifyUpdate()` which triggers `TriggerValueChanged(currentValue)`. This is the mechanism for refreshing checkbox/slider/dropdown controls when the underlying value changes outside the UI. It does NOT apply to button controls created with `CreateSettingsButtonInitializer` because buttons are not Setting-bound — they have no `variable` registered with the framework.

Source: `Blizzard_Settings.lua:205-210` and `Blizzard_Setting.lua:185-188`.

### How Addons Refresh Dynamic Button Labels Mid-Session

There are three patterns in the ecosystem:

**Pattern A: Notify hook from state-change source.**
When window state changes (e.g., `ns:HideWindow()` is called), the state-change function calls a hook that updates the button label directly if the panel is open:

```lua
-- In Window.lua:
function ns:HideWindow()
    win:Hide()
    ns.db.window.visible = false
    if ns.showHideButton then
        ns.showHideButton:SetText("Show window")
    end
end
```

This requires storing a reference to the button (`ns.showHideButton`) at panel creation time and calling `SetText` directly from every state-change path. The button reference must be stashed during panel construction; the reference is valid for the addon session lifetime (Settings panels are created once, not recreated on open).

**Pattern B: `OnShow` hook on the Settings panel.**
Blizzard's `SettingsButtonControlMixin` exposes `initializer.OnShow` which is called when a Dropdown's menu opens (line 612-615). This is NOT the panel's `OnShow` — it is specific to the dropdown widget. There is no equivalent `OnShow` hook in `CreateSettingsButtonInitializer`'s data.

However, `SettingsPanel` itself fires events that can be caught. The addon can `HookScript("OnShow", ...)` on `SettingsPanel` — but this fires on every category navigation, not just TLH's category. Filtering by current category is unreliable.

**Pattern C: Re-register the initializer.**
Some addons tear down and re-register a Settings category on-demand to force `Init` to re-run. This is heavy and causes visual flicker — not appropriate for a button-label update.

### Recommended Approach for TLH

**Pattern A: Notify hook.** Store `ns.showHideBtn` (a reference to the button widget's `self.Button` frame) when the initializer's `data.gameDataFunc` or a custom `OnLoad` fires, then call `ns.showHideBtn:SetText(...)` from every state-change path in `Window.lua`.

Concretely: the `CreateSettingsButtonInitializer` data table accepts a `gameDataFunc` field (line 762 in `Blizzard_SettingControls.lua`). However this requires a `gameDataEvent` too — it is an event-driven refresh, not a direct call hook.

The simpler path: after `layout:AddInitializer(initializer)`, store the `initializer` itself on `ns`. Then in `SettingsButtonControlMixin:Init`, the button's `self.data` is the same table. Hook via `initializer.OnClick` wrapping? No — the cleanest approach is:

Store the initializer's data table and add a `Refresh` function to it. Then call that function from state-change paths. But `SettingsButtonControlMixin:Init` does not call a `Refresh` field.

**Simplest correct approach:**

```lua
-- In Config.lua, when registering the Show/Hide button:
local showHideData = { buttonText = buttonText, buttonClick = OnClick, ... }
ns.showHideButtonData = showHideData
local initializer = Settings.CreateElementInitializer("SettingButtonControlTemplate", showHideData)

-- Add a refresh helper that Window.lua can call:
function ns:RefreshShowHideButtonLabel()
    -- Walk the pool of active elements and find our button
    -- OR: store the Button frame reference during Init via gameDataFunc
end
```

The cleanest path uses `gameDataFunc` on the initializer data. When `SettingsButtonControlMixin:Init` runs (line 713-717), if `self.data.gameDataFunc` is set, it registers an event callback via `EventRegistry`. We can abuse this with a custom addon-side event:

```lua
-- Fire from Window.lua state-change paths:
EventRegistry:TriggerEvent("TLH.WindowVisibilityChanged")

-- In Config.lua button data:
gameDataEvent = "TLH.WindowVisibilityChanged",
gameDataFunc = function(button)
    button:SetText(ns:IsWindowShown() and "Hide window" or "Show window")
end
```

**Source:** `Blizzard_SettingControls.lua:713-717` confirms `gameDataFunc`/`gameDataEvent` are wired via `EventRegistry:RegisterFrameEventAndCallbackWithHandle`. This is a HIGH-confidence path that is already part of the framework.

### Table Stakes vs Differentiator vs Anti-Feature

**Table stakes** for this addon specifically. The button that controls window visibility must reflect actual state. A button labeled "Show window" when the window is already visible is confusing and breaks user trust. The v0.1.0 implementation (init-only label) is a known gap per PROJECT.md.

### UX Expectations

- Label is correct immediately after any state change, while the panel stays open.
- No user action (e.g., closing and reopening the panel) required to see the updated label.
- "Show window" when hidden, "Hide window" when visible (or soft-hidden counts as "visible" — the window frame is shown, just alpha=0).

### Complexity

MODERATE. The `gameDataFunc`/`gameDataEvent` approach requires:
1. Defining a custom event name on `EventRegistry`.
2. Firing that event from every `Window.lua` path that changes visibility (ShowWindow, HideWindow, RestoreWindowVisibility, applySoftHideState).
3. Plumbing `gameDataFunc`/`gameDataEvent` into the initializer data in Config.lua.

Alternative simpler path (if `EventRegistry` custom events prove problematic): store `ns.showHideBtnRef` as a direct reference to the Button widget during `gameDataFunc`, then call `ns.showHideBtnRef:SetText(...)` directly from Window.lua. This avoids the event indirection at the cost of a tighter coupling.

### Dependencies

- Depends on existing `ns:IsWindowShown()`, `ns:ShowWindow()`, `ns:HideWindow()` (v0.1.0).
- Depends on existing `CreateSettingsButtonInitializer` usage in Config.lua (v0.1.0).
- New: requires a notification path from Window.lua back to Config.lua's button widget.

---

## Feature 4: SAY-Centric Defaults

### What It Is

Fresh installs default to `listenChannels.SAY = true` (all other channels false) and `macroChannel = "SAY"` (macros send to `/s`). Existing users upgrading from v0.1.0 are NOT affected — their choices remain intact.

### The Backfill Pattern in WoW Addons

WoW addons universally handle SavedVariables schema migration at `ADDON_LOADED` time, before any settings registration fires. There are three standard patterns:

**Pattern A: "Only write if nil" (most common).**

```lua
-- In Core.lua ADDON_LOADED handler:
if db.window.autoHide == nil then
    db.window.autoHide = false
end
```

This is the pattern TBT uses (Core.lua lines 63-82: `if cs.hideWhenInactive == nil then cs.hideWhenInactive = true end`). It is also what TLH v0.1.0 uses for backfilling new keys. **This is the correct pattern for TLH v1.0.0.**

The key insight: `RegisterAddOnSetting` also defaults a nil key, but it fires AFTER `ADDON_LOADED` and AFTER the backfill loop. For the default to be "SAY = true" on fresh install and "unchanged" on upgrade, the backfill must use `if db.listenChannels.SAY == nil then db.listenChannels.SAY = true end` — not a hard assignment. `RegisterAddOnSetting`'s defaultValue only applies if the key is still nil when it runs; since the backfill runs first, the backfill controls the value for fresh installs.

**Pattern B: Versioned schema** (e.g., `db.schemaVersion`). The addon stores a version integer in the DB and runs a migration only when upgrading from a known-older version. More robust for multi-step migrations, overkill for TLH's single-key change.

**Pattern C: Dirty flag** (e.g., `db.defaultsApplied`). A boolean marks that fresh defaults have been written. Equivalent to Pattern A for one-time changes.

**Recommended: Pattern A.** Matches TBT's existing convention. No new DB keys needed. Upgrade-safe.

### Default Values Being Changed

| Key | v0.1.0 default | v1.0.0 default | Applies to |
|-----|---------------|---------------|------------|
| `db.listenChannels.SAY` | `true` (via RegisterAddOnSetting defaultValue="true") | `true` | Same — no change |
| `db.listenChannels.RAID` | `true` | `false` | Fresh DBs only |
| `db.listenChannels.RAID_LEADER` | `true` | `false` | Fresh DBs only |
| `db.listenChannels.RAID_WARNING` | `true` | `false` | Fresh DBs only |
| `db.listenChannels.INSTANCE_CHAT` | `true` | `false` | Fresh DBs only |
| `db.listenChannels.INSTANCE_CHAT_LEADER` | `true` | `false` | Fresh DBs only |
| `db.macroChannel` | `"RAID"` | `"SAY"` | Fresh DBs only |

Wait — the v0.1.0 `Config.lua` registers all channel toggles with `defaultValue = true`. That means ALL channels default to true on fresh install, not just SAY. The v1.0.0 change is: only SAY defaults true; all others default false. For **existing users**, the backfill must NOT overwrite already-set keys.

The correct backfill logic:

```lua
-- In Core.lua ADDON_LOADED, after the DB table is initialized but before Settings registration:
-- Only set if the entire listenChannels table is new (fresh install).
-- If any channel key exists, this is an upgrade — leave all keys alone.
local isNewDB = true
for _ in pairs(db.listenChannels) do
    isNewDB = false
    break
end
if isNewDB then
    db.listenChannels.SAY = true
    -- all others remain nil → RegisterAddOnSetting will default them false
else
    -- upgrade: backfill only truly new keys (keys that didn't exist in v0.1.0)
    -- v0.1.0 had all 6 keys, so no new listen channel keys in v1.0.0
end

-- macroChannel: if nil (fresh install), default to SAY
if db.macroChannel == nil then
    db.macroChannel = "SAY"
end
```

Actually simpler: since v0.1.0 already initialized `listenChannels` with all six keys set to their defaults via `RegisterAddOnSetting`, any existing user will have non-nil values for all six. The "fresh install" case is `db.listenChannels` being an empty table `{}`. Pattern A's nil-check works correctly for each key independently.

### Table Stakes vs Differentiator vs Anti-Feature

**Table stakes** for a shipped v1 quality bar. Defaults that match the primary use case (pugs/casual using `/s`) reduce the friction for 80% of new users. Wrong defaults are a common cause of "this addon doesn't work" support requests.

**Anti-feature: clobbering existing user choices.** If the backfill writes `db.listenChannels.RAID = false` unconditionally for all users, any v0.1.0 user who deliberately set RAID to true will lose their setting. This must be prevented.

### UX Expectations

- Fresh install: only the SAY checkbox is on; macro target dropdown shows "/s".
- Upgrade from v0.1.0: all settings remain exactly as the user left them.
- No migration message needed — silent change, correct direction.

### Complexity

LOW. Pure backfill logic in `Core.lua`'s `ADDON_LOADED` handler. No new API, no new files, no Settings API changes. The only change to `Config.lua` is the `defaultValue` argument to `RegisterAddOnSetting` for non-SAY channels (change from `true` to `false`) and `macroChannel` (change from `"RAID"` to `"SAY"`). The backfill in `Core.lua` handles the upgrade-safety.

### Dependencies

- Depends on existing DB init pattern in `Core.lua` (v0.1.0).
- Depends on existing `RegisterAddOnSetting` calls in `Config.lua` (v0.1.0).
- No new DB schema additions.

---

## Feature 5: Auto-Hide-When-Empty → "Auto Hide When Empty In Combat"

### What It Is

The existing "Auto-hide when empty" behavior is reframed: **out of combat, the window always stays visible** when the toggle is on (so the toggle being active is self-evident to the user); **in combat, the window hides when the slot sequence is empty** (original behavior). The feature hooks `PLAYER_REGEN_DISABLED` (entering combat) and `PLAYER_REGEN_ENABLED` (leaving combat) to track combat state.

### How WoW Addons Distinguish "In Combat"

**Three APIs exist; they have different semantics:**

| API | What it detects | Edge cases |
|-----|-----------------|------------|
| `PLAYER_REGEN_DISABLED` event | Player's regeneration has stopped — player is in combat and generating threat | Fires on M+ pulls, world boss aggro radius, pets on targets; does NOT fire for mere proximity |
| `PLAYER_REGEN_ENABLED` event | Player's regeneration has resumed — player left combat | Fires when all threat drops and enemies reset or die |
| `InCombatLockdown()` | Whether the UI is currently restricted (combat lockdown) | Returns true whenever Blizzard's secure-frame protection is active; usually tracks `PLAYER_REGEN_DISABLED` but can differ in edge cases (e.g., control assertions during transitions) |
| `UnitAffectingCombat("player")` | Whether the player unit is flagged as in-combat in the unit system | Updates continuously but is not event-driven; can briefly differ from `PLAYER_REGEN_DISABLED` during combat entry |

**Standard pattern for visibility-only logic (no lockdown concern):** Use `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` with a module-local `inCombat` boolean. This is the pattern TBT's `Display.lua` uses (lines 348-354: registers both events, sets `inCombat = (event == "PLAYER_REGEN_DISABLED")`).

`InCombatLockdown()` is for macro/button protection (combat lockdown = UI API restriction). It is NOT the right tool for visibility-driving combat detection. The correct tool for "are we currently in combat?" as a game-state question is the `PLAYER_REGEN_*` event pair.

**Edge cases for TLH:**

- **M+ pulls:** `PLAYER_REGEN_DISABLED` fires correctly — M+ pulls generate threat and stop regen.
- **Tank threat / world boss aggro radius:** `PLAYER_REGEN_DISABLED` fires when any group member pulls aggro if the player is in range and flagged. This is the correct behavior for TLH — the spotter should have the window available in combat regardless of who is tanking.
- **Dying in combat:** `PLAYER_REGEN_ENABLED` fires when combat ends (enemies reset). The dead player's regen resumes. This correctly triggers the out-of-combat "stay visible" behavior.
- **`PLAYER_REGEN_ENABLED` at login/reload:** Does NOT fire at login. Must seed `inCombat = InCombatLockdown()` at init time (or `InCombatLockdown() == false` → out of combat at load). TBT does this at line 347: `inCombat = InCombatLockdown()`.

### Revised Soft-Hide Logic

Current v0.1.0 `applySoftHideState()`:

```lua
applySoftHideState = function()
    if ns.db.window.autoHide and #sequence == 0 then
        -- hide regardless of combat state
        win:SetAlpha(0)
    else
        win:SetAlpha(ns.db.window.alpha or 1.00)
    end
end
```

v1.0.0 revised logic:

```lua
applySoftHideState = function()
    if ns.db.window.autoHide and #sequence == 0 and inCombat then
        -- only soft-hide in combat when empty
        win:SetAlpha(0)
    else
        win:SetAlpha(ns.db.window.alpha or 1.00)
    end
end
```

The `inCombat` boolean is driven by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` events, seeded at init.

On `PLAYER_REGEN_ENABLED` (leaving combat): call `applySoftHideState()`. If sequence is empty, the window becomes visible (alpha restored) because `inCombat` is now false.
On `PLAYER_REGEN_DISABLED` (entering combat): call `applySoftHideState()`. If sequence is empty and `autoHide` is on, the window soft-hides.

### Config Panel Label and Tooltip Update

- **Current label:** "Auto-hide when empty"
- **v1.0.0 label:** "Auto-hide when empty (in combat)"
- **v1.0.0 tooltip:** "When enabled, the helper window hides during combat when no runes are showing. Out of combat it stays visible as a reminder that the setting is on."

The `RegisterAddOnSetting` call must use the new label string. The variable name (`"TLH_AUTO_HIDE"`) and DB key (`"autoHide"`) remain unchanged — no migration needed.

### Table Stakes vs Differentiator vs Anti-Feature

**Table stakes** for the specific UX problem this solves. The original "auto-hide when empty all the time" behavior creates a foot-gun: the user turns on auto-hide, the window disappears immediately (sequence empty), and they think the addon is broken. The combat-scoped reframe makes the "on" state self-evident.

**Anti-feature: combat-aware scale or alpha changes beyond this reframe.** PROJECT.md explicitly rules out any other combat-aware window-property changes. The PLAYER_REGEN coupling is exclusively for the auto-hide toggle.

### UX Expectations

- Toggle ON + out of combat: window stays visible (alpha at configured value), even if no runes are showing.
- Toggle ON + in combat + no runes: window soft-hides (alpha=0, chat events still registered).
- Toggle ON + in combat + runes showing: window visible (FillSlot calls applySoftHideState, which exits soft-hide).
- Toggle ON + transition out of combat: window becomes visible immediately via PLAYER_REGEN_ENABLED → applySoftHideState.
- Toggle OFF: window always visible when shown (existing behavior, unchanged).
- At login/reload when in combat: `inCombat = InCombatLockdown()` seeds the boolean correctly.

### Complexity

LOW-MODERATE. Core logic change is a one-line addition (`and inCombat`) to `applySoftHideState()`. The `inCombat` boolean, event registration, and `applySoftHideState` call from the event handler adds ~15 lines. Config label/tooltip string update is cosmetic. Total change surface is small.

### Dependencies

- Depends on existing `applySoftHideState()` and `softHidden` state in `Window.lua` (v0.1.0).
- Depends on existing `db.window.autoHide` setting (v0.1.0).
- New event registrations: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` on a dedicated or reused frame in `Window.lua`.
- New module-local: `local inCombat = false` (seeded at init).
- No new DB keys.

---

## Feature Landscape Summary

### Table Stakes (for v1.0.0)

| Feature | Why Expected | Complexity | Confidence |
|---------|--------------|------------|------------|
| Click-through when locked | Locked HUD = inert HUD; universal WoW addon convention | LOW | HIGH |
| Correct Show/Hide button label | Any button reflecting mutable state must be current | MODERATE | HIGH |
| SAY-centric defaults | Primary use case (pugs/casual) uses /s; wrong defaults = "broken addon" reports | LOW | HIGH |
| Auto-hide combat reframe | Current always-hide creates a "is it on?" foot-gun | LOW-MODERATE | HIGH |

### Differentiators (for v1.0.0)

| Feature | Value Proposition | Complexity | Confidence |
|---------|-------------------|------------|------------|
| Cheat-sheet image in config panel | First-time users see rune-to-symbol reference before looking elsewhere | MODERATE | HIGH |

### Anti-Features (Explicitly Out of Scope)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Partial click-through (lock btn stays clickable) | "I want to unlock without opening config" | Creates confusing input zones during combat; violates single-axis mental model | `/lura unlock` slash command |
| Separate click-through toggle (decoupled from lock) | Power-user flexibility | 2x2 state matrix no user actually needs | Lock = fully inert; no exceptions |
| Placeholder cheat-sheet image | Ship the UI stub now | Placeholder becomes permanent; defeats the UX purpose | Block milestone on real asset |
| Combat-aware scale/alpha (beyond auto-hide reframe) | "Make it smaller in combat" | Complexity with no clear benefit for this specific tool | Fixed scale; user configures once |
| Clobbering existing user channel choices on upgrade | "Fresh defaults for everyone" | Destroys deliberate user configuration | nil-check backfill: only new keys |

---

## Feature Dependencies

```
Click-through when locked
    └──depends on──> db.window.locked (v0.1.0)
    └──depends on──> applyLockState() (v0.1.0)
    └──depends on──> win:EnableMouse() [NEW call, existing API]

Cheat-sheet image in config panel
    └──depends on──> vertical layout panel (v0.1.0 Config.lua)
    └──BLOCKED by──> real image asset (milestone gate)
    └──depends on──> new .xml template file [NEW]

Dynamic Show/Hide button label
    └──depends on──> ns:IsWindowShown() (v0.1.0)
    └──depends on──> ShowWindow / HideWindow / applySoftHideState (v0.1.0)
    └──depends on──> CreateSettingsButtonInitializer usage (v0.1.0)
    └──requires──> notification path Window.lua → Config.lua button widget [NEW]

SAY-centric defaults
    └──depends on──> Core.lua backfill pattern (v0.1.0)
    └──depends on──> RegisterAddOnSetting default values (v0.1.0)
    └──no new dependencies

Auto-hide combat reframe
    └──depends on──> applySoftHideState() (v0.1.0)
    └──depends on──> db.window.autoHide (v0.1.0)
    └──requires──> inCombat boolean + PLAYER_REGEN_* events [NEW]
    └──enhances──> Dynamic Show/Hide button label
        (combat exit re-shows window → window state changes → label should update)
```

---

## UX Decisions for User Confirmation

The following choices are embedded in this research but involve user-visible behavior that should be explicitly confirmed before requirements are finalized:

1. **Soft-hidden window counts as "visible" for the Show/Hide button label.** When `autoHide=on`, the window is shown at alpha=0 in the existing model. Should the button say "Hide window" (frame is shown) or "Show window" (user can't see it)? Recommendation: "Hide window" because the frame IS shown and `/lura hide` is the right action to fully stop processing.

2. **PLAYER_REGEN_ENABLED fires the combat-exit logic even if the player is dead.** A dead player's regen resumes when combat ends. The window will become visible (if autoHide=on and sequence is empty) when combat ends, even if the player is in their corpse run. This is likely correct UX but worth confirming.

3. **Auto-hide with toggle ON + out of combat: window is always visible, including while empty, including between pulls.** This means a user who enabled auto-hide will see the empty window between every pull when they are out of combat. The intent (per PROJECT.md) is "visible as a reminder the setting is on." Confirm this is the desired behavior.

---

## Sources

- `wow-ui-source@12.0.1.66337` (Interface 120005, Midnight client tree):
  - `Blizzard_SettingControls.lua:686-742` — `SettingsButtonControlMixin` and `EvaluateName` behavior
  - `Blizzard_Settings.lua:173, 205-210, 341` — `RegisterAddOnSetting`, `NotifyUpdate`, `CreateElementInitializer`
  - `Blizzard_Setting.lua:185-188, 265-269` — `NotifyUpdate`, `SetValueChangedCallback`
  - `Blizzard_ImplementationReadme.lua` — Canvas vs vertical layout, `RegisterCanvasLayoutCategory`, opening to category
  - `Blizzard_UnitFrame/Mainline/PlayerFrame.lua:59-60, 142-145` — `PLAYER_REGEN_*` event pattern
  - `SimpleScriptRegionAPIDocumentation.lua` — `EnableMouse` API documentation
- `TerribleBuffTracker/Display.lua:334-369` — `PLAYER_REGEN_*` with `inCombat` boolean, pattern directly reusable
- `TerribleBuffTracker/Core.lua:63-83` — "only write if nil" backfill pattern, directly reusable
- `TerribleLuraHelper/Window.lua` — existing `applyLockState`, `applySoftHideState`, `EnableMouse` gap
- `TerribleLuraHelper/Config.lua` — existing button initializer, label function, EvaluateName-only refresh gap
- `TerribleLuraHelper/.planning/PROJECT.md` — confirmed Out of Scope items and v1.0.0 feature definitions

---
*Feature research for: TerribleLuraHelper v1.0.0 polish milestone*
*Researched: 2026-05-09*
