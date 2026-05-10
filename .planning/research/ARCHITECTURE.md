# Architecture Research

**Domain:** WoW addon — v1.0.0 polish features integrated into existing 4-file flat addon
**Researched:** 2026-05-09
**Confidence:** HIGH — all integration points derived from direct source reading of the shipped codebase; no external lookups required

---

## Standard Architecture

### System Overview (existing, v0.1.0)

```
┌─────────────────────────────────────────────────────────────┐
│                      Core.lua                                │
│  ADDON_LOADED → DB defaults/backfill → Init dispatch        │
│  PLAYER_LOGIN → InitMacros                                   │
│  Slash dispatcher (/lura, /tlh) → ns:ShowWindow/HideWindow  │
│                   LockWindow/UnlockWindow/etc.               │
└──────────┬───────────────────┬─────────────────────────────┘
           │ ns:Init*          │ ns:Show/Hide/Lock/Unlock
           ▼                   ▼
┌──────────────────┐  ┌────────────────────────────────────┐
│   Macros.lua     │  │           Window.lua               │
│  TLH_* creation  │  │  Frame, slots, lock button         │
│  InCombatLockdown│  │  Soft-hide (alpha=0, no Hide())    │
│  PLAYER_REGEN    │  │  Chat pipeline (taint-safe)        │
│  deferral        │  │  20s self-clear (C_Timer)          │
│  ns:RegisterMacros│  │  Position persistence              │
│  ns:DeleteMacros │  │  Exports: SetWindowScale/Alpha,    │
│  ns:OnMacroChannel│  │  OnAutoHideChanged, LockWindow,   │
│    Changed       │  │  UnlockWindow, ShowWindow,         │
└──────────────────┘  │  HideWindow, IsWindowShown,        │
                      │  RestoreWindowVisibility, FillSlot,│
                      │  ClearAll, applySoftHideState      │
                      └────────────┬───────────────────────┘
                                   │ ns:* exports consumed by
                                   ▼
                      ┌────────────────────────────────────┐
                      │           Config.lua               │
                      │  Settings.RegisterVerticalLayout   │
                      │  Category + 4 sections             │
                      │  Chat channels / Window /          │
                      │  Macros / Slash commands           │
                      │  Buttons: Lock, Show/Hide,         │
                      │  Recreate, Delete                  │
                      └────────────────────────────────────┘

SavedVariables: TerribleLuraHelperDB
  .listenChannels  { SAY, RAID, RAID_LEADER, RAID_WARNING,
                    INSTANCE_CHAT, INSTANCE_CHAT_LEADER }
  .window          { scale, alpha, locked, autoHide,
                    position, visible }
  .macroChannel    string
```

### Component Responsibilities (v0.1.0 baseline)

| Component | Responsibility | Key invariant |
|-----------|----------------|---------------|
| Core.lua | DB init/backfill, slash dispatch, session-restore | DB written once at ADDON_LOADED; window visibility is the on/off switch |
| Macros.lua | TLH_* macro CRUD, InCombatLockdown deferral | CreateMacro/EditMacro never called in combat; PLAYER_REGEN_ENABLED retries |
| Window.lua | Frame lifecycle, soft-hide, taint-safe chat pipeline, lock state, position | chat events registered iff win:IsShown(); soft-hide keeps events registered at alpha=0 |
| Config.lua | Settings panel, settings-to-ns-export wiring | Settings framework writes DB; Config.lua only calls ns:* exports, never writes DB itself |

---

## v1.0.0 Feature Integration Map

### Feature 1: Click-through when locked

**Files modified:** `Window.lua` only. No new files.

**Integration point:** `applyLockState` (Window.lua, currently lines 205-216).

**Current code path:**
```lua
applyLockState = function()
    local locked = ns.db.window.locked
    if locked then
        win:SetMovable(false)
        win:RegisterForDrag()   -- clears drag registration
        lockBtn:Hide()
    else
        win:SetMovable(true)
        win:RegisterForDrag("LeftButton")
        lockBtn:Show()
    end
end
```

**Minimal diff:** Add `win:EnableMouse(not locked)` inside each branch:
```lua
applyLockState = function()
    local locked = ns.db.window.locked
    if locked then
        win:EnableMouse(false)      -- NEW: pass all clicks through
        win:SetMovable(false)
        win:RegisterForDrag()
        lockBtn:Hide()
    else
        win:EnableMouse(true)       -- NEW: restore interactivity
        win:SetMovable(true)
        win:RegisterForDrag("LeftButton")
        lockBtn:Show()
    end
end
```

**Interaction with soft-hide (alpha=0):** Soft-hide sets `win:SetAlpha(0)` but does NOT touch `EnableMouse`. Today's soft-hidden window is invisible but still mouse-interactive (it can be accidentally clicked if the user doesn't know the window is there at alpha=0). After this change: if the window is locked while soft-hidden, `EnableMouse(false)` means it is both invisible and fully pass-through — no accidental clicks during combat. If unlocked while soft-hidden, the window is invisible but still draggable/clickable. This is the correct behavior (unlocked = user actively managing the window, not a normal raid state).

**Interaction with `RegisterForDrag`:** `RegisterForDrag()` (no args) already clears drag registration when locked. `EnableMouse(false)` is the stronger guard — with mouse disabled, the `OnDragStart` handler can never fire regardless of `RegisterForDrag` state. Both lines are still needed: `RegisterForDrag()` ensures clean state for `OnDragStart`/`OnDragStop` handler semantics; `EnableMouse(false)` provides the pass-through guarantee.

**Callers of applyLockState** (all still valid, no caller changes needed):
- `CreateWindow()` — calls it at frame creation (applies initial DB state)
- `ns:ToggleLocked()` — lock button OnClick
- `ns:LockWindow()` — slash command + config button
- `ns:UnlockWindow()` — slash command + config button

**Soft-hide invariant:** Unaffected. `applySoftHideState` only touches `win:SetAlpha`; does not touch `EnableMouse`. The two state axes (soft-hide and lock) are independent.

**AMEND-01 invariant:** Unaffected. `EnableMouse` has no effect on `chatFrame` or `RegisterEvent`/`UnregisterEvent`. Chat event registration is governed solely by `win:IsShown()` via OnShow/OnHide.

---

### Feature 2: Symbol reference image at top of config panel

**Files modified:** `Config.lua` only. No new files (assuming texture asset already placed in addon root or `textures/` subfolder and listed in `.toc`).

**Integration point:** `ns:InitConfig` / the `EventUtil.ContinueOnAddOnLoaded` callback body, specifically the ordering of `RegisterChannelToggles`, `RegisterWindowControls`, etc. (Config.lua lines 324-340).

**Where in layout:** Vertical layout stacks initializers in registration order. To anchor the image above all controls, add the texture initializer FIRST, before `RegisterChannelToggles`. The Settings vertical layout has no "pin to top" primitive — insertion order is the only ordering mechanism (confirmed by SETTINGS_API.md footgun §10).

**Implementation pattern — `Settings.CreateElementInitializer`:**

The Settings framework does not ship a built-in image/texture initializer. The canonical approach for non-standard widgets is `Settings.CreateElementInitializer(templateName, data)` followed by `layout:AddInitializer(initializer)`. This requires an XML template that defines a Frame/Texture and a Mixin. The mixin receives `data` in its `Init` method.

Required additions to the addon:
1. One `.xml` file (e.g., `Textures.xml` or inline in a new `SymbolReference.xml`) defining a frame template with a `Texture` sub-element.
2. The `.xml` file listed in `.toc` before `Config.lua`.
3. One `Settings.CreateElementInitializer("TLHSymbolReferenceTemplate", { texturePath = "Interface\\AddOns\\TerribleLuraHelper\\textures\\cheatsheet" })` call in Config.lua.

**Alternative — frame attached directly to the panel:** The Settings vertical layout exposes `layout:AddInitializer(...)` as the only way to append widgets. There is no `layout:GetFrame()` or equivalent to parent a raw frame to the panel's scroll-child. Attempting to parent a raw Frame to `UIParent` and then reposition it relative to a settings element is fragile (panel scroll offsets, panel open/close lifecycle). `CreateElementInitializer` is the correct path.

**Sizing strategy:** Fixed width matching the panel's content area (approximately 600px on default UI scale), fixed height derived from image aspect ratio. The template's `OnLoad` or `Init` mixin should call `self:SetWidth(600)` and `self:SetHeight(600 / aspectRatio)`. Do not stretch to panel width dynamically — the panel width varies with UI scale and the texture aspect ratio must be preserved for the cheat-sheet to be readable.

**Hard gate:** Per PROJECT.md, the real image asset must be present before this feature ships. If the asset is absent, the `RegisterSymbolReference` call (or whatever wraps the initializer) should be gated with an asset existence check or simply omitted. Do not ship a placeholder.

**Config.lua registration order (after change):**
```lua
-- Inside EventUtil.ContinueOnAddOnLoaded callback:
RegisterSymbolReference(layout)       -- NEW: image at top
RegisterChannelToggles(category, layout, db)
RegisterWindowControls(category, layout, db)
RegisterMacroSection(category, layout, db)
RegisterCommandHelp(category, layout)
```

**AMEND-01 invariant:** Unaffected (Config.lua touches no chat events).

---

### Feature 3: Dynamic Show/Hide button label

**Files modified:** `Window.lua` (adds notify hook export), `Config.lua` (subscribes to hook in panel OnShow, unsubscribes in panel OnHide).

**Problem with current implementation:** The Show/Hide button's `buttonText` function (Config.lua lines 199-204) is evaluated once by `SettingsButtonControlMixin:EvaluateName` at initializer `Init` time — i.e., when the panel first opens. If the window is shown/hidden via slash command or auto-hide while the panel is already open, the button label goes stale. EvaluateName is not called again until the panel re-opens.

**Rejected approach — OnUpdate poll:** Anti-pattern. Per-frame Lua is hot-path cost for a purely cosmetic label refresh.

**Rejected approach — SETTINGS_PANEL_OPEN event:** Only fires when the panel opens, not on every state change while it's open.

**Correct approach: ns notify hook (option b from the question)**

`Window.lua` adds a single notification hook. Every code path that changes window visibility calls it. `Config.lua` subscribes a label-refresh callback while the panel is open.

**New export in Window.lua:**
```lua
-- Notification hook: any subscriber registered here is called
-- whenever window visibility changes (Show, Hide, soft-hide state
-- change). Config.lua registers/unregisters during panel open/close.
ns.onWindowVisibilityChanged = nil   -- single subscriber slot (only Config needs it)

local function notifyVisibilityChanged()
    if ns.onWindowVisibilityChanged then
        ns.onWindowVisibilityChanged()
    end
end
```

A single-subscriber slot (one function reference, not a list) is sufficient because only Config.lua needs this notification. A registry (table of callbacks) would be over-engineering for one subscriber.

**Call sites in Window.lua** that must call `notifyVisibilityChanged()`:
1. `ns:ShowWindow()` — after `win:Show()` and alpha restore
2. `ns:HideWindow()` — after `win:Hide()`
3. `applySoftHideState()` — after `win:SetAlpha(0)` (entering soft-hide) and after `win:SetAlpha(db.alpha)` (exiting soft-hide); IsWindowShown returns true in both cases so the button label doesn't change, BUT if the consumer wants to distinguish soft-hidden from fully-shown it needs the notification. For the Show/Hide label specifically, `IsWindowShown()` is the query — soft-hide does not change that — so `applySoftHideState` notifications are optional. Include them for correctness/future-proofing, but the label only cares about `win:IsShown()`.
4. `ns:RestoreWindowVisibility()` — after `win:Show()` (session restore on ADDON_LOADED)

The OnShow/OnHide frame scripts do not need to call `notifyVisibilityChanged` because they are triggered by the same `win:Show()`/`win:Hide()` calls that already notify via the wrappers above.

**Config.lua subscription — where to wire:**

The Settings panel does not have a built-in OnShow/OnHide hook per-category. The standard approach is to register a `SETTINGS_PANEL_OPEN` event (LOW confidence per SETTINGS_API.md) or to hook into the category's `OnShow`/`OnHide` via the layout frame. The simpler, verified approach: use `Settings.SetOnValueChangedCallback` with a no-op proxy for a dummy setting, or — more robustly — hook the panel frame directly.

Concrete approach: After `Settings.RegisterAddOnCategory(category)`, call `Settings.GetCategoryFrame(category):HookScript("OnShow", ...)` and `... :HookScript("OnHide", ...)`. This is the pattern used in the Blizzard source for per-category lifecycle. If `GetCategoryFrame` is not a public method on the category object (needs in-game verification), fall back to using `ADDON_ACTION_FORBIDDEN` avoidance and hooking `SettingsPanel:HookScript("OnShow", ...)` while checking `SettingsPanel.currentCategory == ns.settingsCategoryID`.

The safest approach that requires no frame archaeology: store a local `showHideButton` reference in the closure where it's created, then call `showHideButton:SetText(buttonText())` directly from the notify callback:

```lua
-- In RegisterWindowControls, capture the button reference:
local showHideBtn   -- forward reference

local function OnClick()
    if ns:IsWindowShown() then ns:HideWindow() else ns:ShowWindow() end
end
local function evaluateLabel()
    return ns:IsWindowShown() and "Hide window" or "Show window"
end
-- ... CreateSettingsButtonInitializer as before ...

-- Register notify hook when panel section is built:
ns.onWindowVisibilityChanged = function()
    if showHideBtn then
        showHideBtn:SetText(evaluateLabel())
    end
end
```

The Settings framework creates the actual Button widget inside `SettingsButtonControlMixin:Init` and does not expose it via the initializer API. To get a reference to the button widget, hook `SettingsButtonControlMixin:Init` via `hooksecurefunc` or — simpler — store the button ref in the OnClick closure via upvalue when the initializer fires.

**Simplest fully-correct approach:** Use `SettingsButtonControlMixin:Init` hooksecurefunc to capture `self.Button` and store it. Then `ns.onWindowVisibilityChanged` calls `capturedButton:SetText(evaluateLabel())`. This is a one-time hook at panel creation and requires no OnShow/OnHide lifecycle management.

```lua
-- After CreateSettingsButtonInitializer:
local capturedShowHideButton
hooksecurefunc(SettingsButtonControlMixin, "Init", function(self)
    -- Only capture for our specific initializer (match by button text)
    if self.data and self.data.name == "" and self.data.buttonText ~= nil then
        -- fragile match — prefer a unique sentinel in data instead
        capturedShowHideButton = self.Button
    end
end)
```

A cleaner sentinel: set a unique key on the initializer's data table (e.g., `data.tlhShowHideButton = true`) before passing to `CreateSettingsButtonInitializer`. Then the hook checks `self.data.tlhShowHideButton` to identify the right button.

**Build-order dependency:** The notify hook (`ns.onWindowVisibilityChanged`) must be defined in Window.lua and the call sites patched BEFORE the dynamic-label wiring in Config.lua can work. Window.lua loads before Config.lua (per `.toc` load order). So: implement Feature 3 Window.lua changes first, then the Config.lua wiring.

**AMEND-01 invariant:** Unaffected. The notify hook is a Lua function call, not an event.

**Soft-hide invariant:** `ns:IsWindowShown()` returns true during soft-hide (win:IsShown() is true; alpha=0 is an opacity change, not a hide). The button label correctly reads "Hide window" while soft-hidden, which is accurate — `/lura hide` is what will hide it.

---

### Feature 4: SAY-centric defaults (with backfill safety)

**Files modified:** `Core.lua` only. No new files.

**Integration point:** The DB defaults block (Core.lua lines 33-53) and the backfill loop (lines 55-90).

**How to detect fresh DB vs existing DB:** The existing pattern already handles this correctly via Lua's nil-check idiom. A "fresh DB" means `TerribleLuraHelperDB` was nil at ADDON_LOADED (i.e., the addon has never run before, or the user deleted their SavedVariables). An "existing DB" means the table exists and its keys have user-chosen values.

**Fresh DB path** (lines 33-53): The `if not TerribleLuraHelperDB then` block. Change defaults here:
- `listenChannels.SAY = true` — already true in current defaults; keep.
- `listenChannels.RAID = true` → `false` — change.
- `listenChannels.RAID_LEADER = true` → `false` — change.
- `listenChannels.RAID_WARNING = true` → `false` — change.
- `listenChannels.INSTANCE_CHAT = true` → `false` — change.
- `listenChannels.INSTANCE_CHAT_LEADER = true` → `false` — change.
- `macroChannel = "RAID"` → `"SAY"` — change.

**Existing DB backfill path** (lines 55-90): The backfill loop currently sets any missing channel key to `true`. This must change to set it to the new per-key default:

```lua
-- Current (wrong for v1.0.0 — backfills missing keys as true):
for _, ch in ipairs({ "SAY", "RAID", ... }) do
    if db.listenChannels[ch] == nil then
        db.listenChannels[ch] = true
    end
end

-- Correct for v1.0.0 — per-key defaults matching fresh-install defaults:
local CHANNEL_DEFAULTS = {
    SAY = true,
    RAID = false,
    RAID_LEADER = false,
    RAID_WARNING = false,
    INSTANCE_CHAT = false,
    INSTANCE_CHAT_LEADER = false,
}
for ch, default in pairs(CHANNEL_DEFAULTS) do
    if db.listenChannels[ch] == nil then
        db.listenChannels[ch] = default
    end
end
```

The `macroChannel` backfill (line 87-89) changes from `"RAID"` to `"SAY"`:
```lua
if db.macroChannel == nil then
    db.macroChannel = "SAY"   -- was "RAID"
end
```

**No schema-version field needed:** The nil-check backfill already distinguishes "key was never written" (nil = first time this key exists for this user) from "key has a user value" (non-nil). A schema-version field would only be needed if we wanted to force-reset a key that already exists with an old value — which is explicitly not what we want here ("must NOT clobber existing user choices on upgrade").

**Upgrade scenario correctness:** An existing user's DB has all six channel keys set to `true` (the v0.1.0 fresh-install default). After upgrade, the backfill loop finds all six keys non-nil and touches nothing. The user keeps their existing `all channels = true` setting. Only users who never had a DB (fresh install on v1.0.0) or who somehow had a missing channel key (e.g., a future new channel added) get the new SAY-only defaults. This is the correct behavior.

**AMEND-01 invariant:** Unaffected (Core.lua does not touch chat events).

---

### Feature 5: Auto-hide reframe to in-combat-only

**Files modified:** `Window.lua` (primary), `Core.lua` (event registration for PLAYER_REGEN_*).

**Current behavior:** `applySoftHideState` soft-hides whenever `autoHide=true AND #sequence==0`, regardless of combat state.

**New behavior:** Soft-hide only when `autoHide=true AND #sequence==0 AND InCombatLockdown()`.

**Where to register PLAYER_REGEN_ENABLED/DISABLED:**

Option A: In `Core.lua`, add to the `eventFrame` that already handles `ADDON_LOADED` and `PLAYER_LOGIN`.
Option B: In `Window.lua`, add a new dedicated frame (like `chatFrame`) for the regen events.
Option C: Reuse `regenFrame` from Macros.lua — this is the wrong option; that frame has a single-purpose handler that unregisters after firing.

**Recommended: Window.lua, new dedicated frame.** Rationale: the combat state drives `applySoftHideState`, which is a Window.lua-internal function. Keeping the PLAYER_REGEN_* listeners in Window.lua avoids cross-file coupling and keeps the auto-hide logic self-contained. Core.lua's eventFrame is for addon lifecycle (ADDON_LOADED, PLAYER_LOGIN) — mixing persistent combat-state events there is a separation-of-concerns violation.

```lua
-- In Window.lua, alongside chatFrame:
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    -- Re-evaluate soft-hide on every combat-state transition.
    -- applySoftHideState already checks autoHide + #sequence;
    -- now it also checks InCombatLockdown().
    applySoftHideState()
end)
```

These events should be registered unconditionally (not gated on window visibility or autoHide), because the combat state must be known at any time to evaluate the soft-hide condition correctly when window visibility or autoHide changes. The cost is two event registrations; at 0-line OnEvent bodies that just call applySoftHideState(), the hot-path cost is negligible.

**`applySoftHideState` change:**

```lua
-- Current:
applySoftHideState = function()
    if ns.db.window.autoHide and #sequence == 0 then
        softHidden = true
        win:SetAlpha(0)
    else
        softHidden = false
        win:SetAlpha(ns.db.window.alpha or 1.00)
    end
end

-- New:
applySoftHideState = function()
    if ns.db.window.autoHide and #sequence == 0 and InCombatLockdown() then
        softHidden = true
        win:SetAlpha(0)
    else
        softHidden = false
        win:SetAlpha(ns.db.window.alpha or 1.00)
    end
end
```

**Edge cases:**

| Scenario | Before change | After change | Correct? |
|----------|--------------|--------------|----------|
| autoHide=on, out of combat, sequence empty, window open | soft-hidden (alpha=0) | visible (alpha=db.alpha) | Yes — user sees the toggle is active |
| autoHide=on, in combat, sequence empty, window open | soft-hidden (alpha=0) | soft-hidden (alpha=0) | Yes — unchanged combat behavior |
| autoHide=on, in combat, sequence fills (FillSlot called) | exits soft-hide | exits soft-hide | Yes — applySoftHideState re-evaluated by FillSlot |
| autoHide=on, combat ends (PLAYER_REGEN_ENABLED), sequence empty | remains soft-hidden until next event | combatFrame fires → applySoftHideState → exits soft-hide, shows window | Yes — window reappears at combat end |
| autoHide=on, combat ends, sequence non-empty | visible | visible | Yes — already not soft-hidden |
| autoHide toggled ON while in combat, sequence empty | N/A (was out-of-combat visible) | immediately enters soft-hide (OnAutoHideChanged → applySoftHideState, InCombatLockdown=true) | Yes — correct in-combat behavior |
| autoHide toggled ON while out of combat, sequence empty | immediately enters soft-hide | remains visible (InCombatLockdown=false) | Yes — correct out-of-combat behavior |
| autoHide toggled OFF while in combat, sequence empty | immediately exits soft-hide | immediately exits soft-hide | Yes — user explicitly disabled |
| autoHide toggled OFF while soft-hidden | exits soft-hide | exits soft-hide | Yes — unchanged |

**Config.lua label/tooltip update:** The auto-hide checkbox label and tooltip must be updated:
- Label: "Auto-hide when empty in combat" (was "Auto-hide when empty")
- Tooltip: "When enabled, the helper window hides while in combat and no runes are showing. Outside combat, the window stays visible as a reminder that auto-hide is active." (was the old tooltip about hiding whenever empty)

This is a pure string change in `RegisterWindowControls` (Config.lua, the `Settings.RegisterAddOnSetting` call for `TLH_AUTO_HIDE` and the `Settings.CreateCheckbox` tooltip argument).

**AMEND-01 invariant:** Unaffected. The new `combatFrame` only calls `applySoftHideState`; it does not touch `chatFrame` or the CHAT_MSG_* event registration. Chat events remain governed exclusively by `win:OnShow`/`win:OnHide`.

**Soft-hide invariant:** Preserved. `applySoftHideState` still uses `alpha=0` (not `Hide()`), so chat events stay registered during soft-hide regardless of combat state.

---

## Recommended Project Structure (unchanged from v0.1.0)

```
TerribleLuraHelper/
├── Core.lua                 # DB init/backfill (Feature 4 here), slash dispatch
├── Macros.lua               # TLH_* macros (no v1.0.0 changes)
├── Window.lua               # Frame, click-through (Feature 1), notify hook
│                            #   (Feature 3), combat frame (Feature 5)
├── Config.lua               # Settings panel, dynamic label (Feature 3),
│                            #   image initializer (Feature 2), label update (Feature 5)
├── TerribleLuraHelper.toc   # + new .xml file if Feature 2 uses XML template
├── textures/
│   └── cheatsheet.tga       # Feature 2 asset (hard gate — must exist)
└── [SymbolReference.xml]    # Feature 2: frame template for image widget (if needed)
```

---

## Architectural Patterns

### Pattern 1: Single-subscriber notify hook (Feature 3)

**What:** Window.lua exposes `ns.onWindowVisibilityChanged = nil`. Every visibility-changing code path in Window.lua calls a module-local `notifyVisibilityChanged()` function that invokes the registered callback if present. Config.lua sets the callback while building the panel (or when the panel opens) and clears it when the panel closes.

**When to use:** When one module needs to react to state changes in another module, and the dependency is one-to-one. Avoids event-system overhead for internal cross-module coordination.

**Trade-offs:** Simple and zero-overhead. Does not scale to multiple subscribers (use a table of callbacks if needed). Acceptable here because Config.lua is the only consumer.

### Pattern 2: applyLockState as the single lock-state applier (Feature 1)

**What:** All four callers of lock-change (`ToggleLocked`, `LockWindow`, `UnlockWindow`, `CreateWindow`) route through the single `applyLockState` local. Adding `EnableMouse` here means all four callers get it for free with a one-line change.

**When to use:** Any time multiple code paths must produce identical side effects on a shared state axis. Adding the side effect once to the applier is safer than adding it to every caller.

**Trade-offs:** No trade-offs for this pattern at this scale.

### Pattern 3: combatFrame for persistent combat-state listener (Feature 5)

**What:** A dedicated `CreateFrame("Frame")` registered permanently for `PLAYER_REGEN_ENABLED` and `PLAYER_REGEN_DISABLED`, calling `applySoftHideState()` on every transition.

**When to use:** When a module needs to react to combat-state changes persistently (not one-shot like Macros.lua's `regenFrame`). The dedicated frame keeps the handler localized to Window.lua without entangling Core.lua's lifecycle eventFrame.

**Trade-offs:** Two additional permanent event registrations. Cost is negligible (handler is a one-liner). Contrast with Macros.lua's `regenFrame`, which is single-shot (unregisters after firing) — do not reuse it for this purpose.

---

## Data Flow

### Visibility change flow (v1.0.0 with notify hook)

```
Slash command (/lura show) or config button click
    ↓
ns:ShowWindow() [Window.lua]
    → win:Show()
    → win:SetAlpha(db.alpha)
    → db.window.visible = true
    → notifyVisibilityChanged()
        → ns.onWindowVisibilityChanged() [if set by Config.lua]
            → capturedShowHideButton:SetText("Hide window")
    → win:OnShow fires → ns:RegisterChatEvents()
```

### Auto-hide combat-state flow (v1.0.0)

```
PLAYER_REGEN_DISABLED fires (combat starts)
    ↓
combatFrame:OnEvent [Window.lua]
    → applySoftHideState()
        → autoHide=true AND #sequence==0 AND InCombatLockdown()=true
        → win:SetAlpha(0), softHidden=true
        → notifyVisibilityChanged() [optional — IsWindowShown still true]

PLAYER_REGEN_ENABLED fires (combat ends)
    ↓
combatFrame:OnEvent [Window.lua]
    → applySoftHideState()
        → InCombatLockdown()=false → condition false
        → win:SetAlpha(db.alpha), softHidden=false
        → notifyVisibilityChanged()
```

### Chat event pipeline (unchanged, documented for invariant reference)

```
CHAT_MSG_SAY / CHAT_MSG_RAID / etc.
    ↓
chatFrame:OnEvent [Window.lua] — only if win:IsShown()
    → db.listenChannels[event:sub(10)] filter (event string op, NOT msg)
    → C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)
    → sequence[#sequence+1] = processed
    → FillSlot(#sequence, processed)
        → slot.fs:SetText(processed) [C-level, taint-safe]
        → applySoftHideState() [exits soft-hide if sequence non-empty]
    → ScheduleClear() [20s C_Timer]
```

---

## Scaling Considerations

Not applicable to a WoW addon (single-client, no server, no user-count scaling dimension). The relevant "scaling" concern is performance during boss combat:

| Concern | Current | v1.0.0 change | Impact |
|---------|---------|---------------|--------|
| Per-frame OnUpdate | None (no OnUpdate handlers) | None added | Zero hot-path cost |
| Event registrations | 6 CHAT_MSG_* (when shown) | +2 PLAYER_REGEN_* (permanent) | Negligible |
| Lua allocations per chat event | ~2 (processed string + sequence slot) | Zero new | None |
| Notify hook call | None | 1 nil-check + 1 function call per visibility change | Negligible (visibility changes are rare) |

---

## Anti-Patterns

### Anti-Pattern 1: Touching EnableMouse in applySoftHideState

**What people do:** Mirror the lock state inside `applySoftHideState` to ensure click-through while soft-hidden.

**Why it's wrong:** The two state axes (lock state and soft-hide state) are independent. `applySoftHideState` runs on every FillSlot/ClearAll/autoHide toggle — adding lock-state logic there creates accidental coupling. A filled-sequence ClearAll cycle would incorrectly re-enable mouse on a locked window.

**Do this instead:** `EnableMouse` lives only in `applyLockState`. `applySoftHideState` never touches `EnableMouse`. The lock state persists through soft-hide transitions because `applyLockState` is only called on actual lock-state changes.

### Anti-Pattern 2: OnUpdate poll for dynamic button label

**What people do:** Register an OnUpdate on the settings panel frame that checks `IsWindowShown()` every frame and sets the button text if it changed.

**Why it's wrong:** OnUpdate fires every frame (~60x/sec during raid). A Lua function call + string comparison + conditional SetText per frame is unnecessary garbage for a label that changes at most a few times per session.

**Do this instead:** Notify hook (Feature 3 pattern). One function call per state change event, not per frame.

### Anti-Pattern 3: Writing db.* from SetValueChangedCallback in Config.lua

**What people do:** In the Settings callback, write `ns.db.window.autoHide = value` before calling `ns:OnAutoHideChanged(value)`.

**Why it's wrong:** `Settings.RegisterAddOnSetting` already writes the value to `ns.db` before the callback fires. Double-writing is harmless but signals a misunderstanding of the framework; any future refactoring that changes the DB key name will create a silent mismatch.

**Do this instead:** Never write `db.*` in a Settings callback. Trust the framework to have written it; call the `ns:*` export to apply the new value to live state.

### Anti-Pattern 4: Reusing Macros.lua's regenFrame for combat-state auto-hide

**What people do:** Register `PLAYER_REGEN_ENABLED`/`PLAYER_REGEN_DISABLED` on `regenFrame` (Macros.lua) to avoid creating a new frame.

**Why it's wrong:** `regenFrame`'s handler unregisters `PLAYER_REGEN_ENABLED` after firing (`self:UnregisterEvent("PLAYER_REGEN_ENABLED")`). Using it for a persistent listener requires removing that unregister call, which changes Macros.lua behavior and creates cross-file coupling. Window.lua would depend on Macros.lua's internal frame, a dependency inversion.

**Do this instead:** Create a dedicated `combatFrame` in Window.lua (Feature 5 pattern). Frames are cheap; cross-file frame sharing is expensive in maintenance cost.

---

## Build Order

This ordering minimizes rework and ensures each feature's dependencies are in place before the feature is implemented:

**1. Feature 4: SAY-centric defaults (Core.lua)**
- Standalone, touches only the DB defaults and backfill loop.
- No dependencies on any other v1.0.0 feature.
- Lowest risk — string and table literal changes only.

**2. Feature 1: Click-through when locked (Window.lua)**
- Standalone, isolated to `applyLockState`.
- No dependencies on other v1.0.0 features.
- Two-line addition; easy to verify by testing lock/unlock cycle.

**3. Feature 5: Auto-hide reframe (Window.lua + Config.lua label)**
- Window.lua portion (new `combatFrame` + `applySoftHideState` change) is standalone.
- Config.lua label/tooltip string update is standalone.
- No dependency on Feature 3 (notify hook).
- Must be implemented before Feature 3 to keep the Window.lua diff clean (combatFrame calls `notifyVisibilityChanged` once that function exists — easy to add the call in a single pass).

**4. Feature 3: Notify hook + dynamic label (Window.lua call sites + Config.lua wiring)**
- Depends on Feature 5 being done first so the `combatFrame` `OnEvent` handler already exists and can be given its `notifyVisibilityChanged()` call in one pass.
- Window.lua adds `ns.onWindowVisibilityChanged`, `notifyVisibilityChanged()`, and call sites.
- Config.lua adds the subscription and button-capture logic.
- This is the most complex feature; do it last among the Window/Config features.

**5. Feature 2: Symbol reference image (Config.lua + XML + asset)**
- Completely independent of all other features; touches only the top of `ns:InitConfig`.
- Listed last because it has the hard external dependency (real image asset must exist).
- If the asset is not ready, this feature is skipped until it is.

**Summary table:**

| Order | Feature | File(s) | Dependency |
|-------|---------|---------|------------|
| 1 | SAY defaults | Core.lua | None |
| 2 | Click-through | Window.lua | None |
| 3 | Auto-hide reframe | Window.lua, Config.lua | None (but do before Feature 3) |
| 4 | Dynamic label | Window.lua, Config.lua | Feature 3 Window.lua changes done |
| 5 | Symbol image | Config.lua, XML, textures/ | Real asset available |

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Window.lua → Config.lua | `ns.onWindowVisibilityChanged` callback slot | NEW (Feature 3). Window.lua owns the slot; Config.lua sets/clears it. |
| Window.lua → PLAYER_REGEN_* | `combatFrame` permanent listener | NEW (Feature 5). Self-contained in Window.lua. |
| Window.lua: applyLockState | `win:EnableMouse(not locked)` | NEW (Feature 1). No cross-file boundary. |
| Core.lua → DB defaults | `listenChannels.*` and `macroChannel` values changed | NEW (Feature 4). Backfill loop updated. |
| Config.lua → Window.lua | All existing `ns:*` export calls | UNCHANGED. |
| Slash dispatch → Window/Config | `ns:ShowWindow`, `ns:HideWindow`, `ns:LockWindow`, `ns:UnlockWindow` | UNCHANGED. Each caller must call `notifyVisibilityChanged()` after Feature 3. |

### Invariants That Must Not Break

| Invariant | Source | Verification |
|-----------|--------|--------------|
| Chat events registered iff `win:IsShown()` | AMEND-01 | `EnableMouse(false)` does not affect `chatFrame:RegisterEvent`. Confirmed: separate frames. |
| Soft-hide keeps chat events registered | Phase 3 design | `applySoftHideState` uses `SetAlpha(0)`, never `Hide()`. Feature 5 preserves this. |
| `msg` string never indexed, matched, or concatenated | CLAUDE.md hard constraint | No new code touches `msg`. |
| `SendChatMessage` never called | CLAUDE.md hard constraint | No new code calls it. |
| `CreateMacro`/`EditMacro` guarded by `InCombatLockdown` | SAFE-03 | No Macros.lua changes in v1.0.0. |
| DB written by Settings framework, not by callbacks | Phase 3 design | Feature 5 Config.lua change is a string literal only; does not add a DB write. |

---

## Sources

- `Window.lua` (shipped v0.1.0) — direct source reading, HIGH confidence
- `Config.lua` (shipped v0.1.0) — direct source reading, HIGH confidence
- `Core.lua` (shipped v0.1.0) — direct source reading, HIGH confidence
- `.planning/research/SETTINGS_API.md` — verified against `wow-ui-source@12.0.1`, HIGH confidence for Settings API patterns
- `.planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-VERIFICATION.md` — AMEND-01 (visibility-gated chat events) documented here
- `wow-ui-source` `Blizzard_SettingControls.lua:702-708` — `EvaluateName` behavior (called once at Init, not on every panel show), HIGH confidence

---
*Architecture research for: TerribleLuraHelper v1.0.0 polish features*
*Researched: 2026-05-09*
