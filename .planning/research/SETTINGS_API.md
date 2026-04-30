# Settings Panel API for Options > AddOns (Interface 120005)

**Scope:** the *one* unknown for TerribleLuraHelper — how to register a panel under the default Game Menu's `Options > AddOns` tab and populate it with checkboxes, a slider, action buttons, and a help-text block, using only the modern `Settings.*` API.

**Verification basis:** all function signatures and patterns below are quoted from the live `wow-ui-source` checkout at `C:\Users\jonat\Repositories\wow-ui-source` (`version.txt` = `12.0.1.66337`, which is the Midnight 12.0 client tree — the same code path Interface 120005 loads). Where I cite a file path, that is the canonical source and these are not training-data guesses.

---

## TL;DR

Use `Settings.RegisterVerticalLayoutCategory(addonName)` to create the category and `Settings.RegisterAddOnCategory(category)` to land it under **Options > AddOns** (this is the `addon = true` path inside `SettingsPanel:RegisterCategory`, controlled exclusively by which register-helper you call). Bind each of the six per-channel toggles and the auto-hide toggle to `TerribleLuraHelperDB` via `Settings.RegisterAddOnSetting` — that mixin auto-defaults the SavedVariables key on registration *and* writes the new value back on every change, so we never touch the DB ourselves. Add controls with `Settings.CreateCheckbox(category, setting)` and `Settings.CreateSlider(category, setting, options)` (slider `options` come from `Settings.CreateSliderOptions(min, max, step)`). Add the two action buttons via `CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, addSearchTags)` then `layout:AddInitializer(initializer)`; the OnClick is plain Lua, free to call any addon function. The slash-command examples block uses `CreateSettingsListSectionHeaderInitializer(name, tooltip)` for the heading plus a passthrough header per command (or one fat tooltip) — section header names are searchable and render exactly the way Blizzard's own audio panel renders headings. Open the panel from a slash command with `Settings.OpenToCategory(category:GetID())` (the ID is a number stored on the category object — capture it at register-time). All registration must be deferred to `EventUtil.ContinueOnAddOnLoaded(addonName, ...)` so the SavedVariables table is loaded; do not call any of this from a top-level chunk.

---

## Recommended approach (skeleton the executor can follow)

Add a new file `Config.lua` to the addon, listed in the `.toc` **after** `Core.lua` (so the namespace's `ns.db` initializer is defined first, but the registration itself runs inside `ContinueOnAddOnLoaded` which fires after `ADDON_LOADED` for our addon — order is safe either way, but loading after Core matches the existing TBT convention).

`TerribleLuraHelper.toc` excerpt:

```toc
## Interface: 120005
## Title: TerribleLuraHelper
## Author: Jonathas-Conceicao
## SavedVariables: TerribleLuraHelperDB
## Version: @project-version@
## X-Curse-Project-ID: <fill>
## X-Wago-ID: <fill>

Core.lua
Macros.lua
Window.lua
Config.lua
```

`Config.lua` skeleton (every line below is a copy-pastable pattern; concrete examples per control are in the next section):

```lua
local addonName, ns = ...

-- IMPORTANT: defer ALL Settings.* calls until after our SavedVariables
-- have loaded. EventUtil.ContinueOnAddOnLoaded fires the callback
-- immediately if our addon is already loaded, otherwise on ADDON_LOADED.
-- This is the pattern Blizzard uses in their own implementation readme.
EventUtil.ContinueOnAddOnLoaded(addonName, function()
    -- ns.db is set in Core.lua's ADDON_LOADED handler (which runs first
    -- in the same event because the inbound order is ADDON_LOADED ->
    -- registered ContinueOnAddOnLoaded callbacks). If you ever flip the
    -- order, guard with: if not ns.db then return end.
    local db = ns.db

    -- 1. Category goes under Options > AddOns.
    local category, layout = Settings.RegisterVerticalLayoutCategory("TerribleLuraHelper")

    -- 2. Cache the numeric ID for /lura config.
    ns.settingsCategoryID = category:GetID()

    -- 3. Register settings + controls (see per-control reference below).
    ns:RegisterChannelToggles(category, layout, db)
    ns:RegisterScaleSlider(category, layout, db)
    ns:RegisterAutoHideToggle(category, layout, db)
    ns:RegisterActionButtons(category, layout)
    ns:RegisterCommandHelp(category, layout)

    -- 4. Land the category under "AddOns" (NOT Game). This is the only
    --    call that decides which subtree the panel appears in.
    Settings.RegisterAddOnCategory(category)
end)
```

**Why this shape:**
- `Settings.RegisterAddOnCategory(category)` is the *only* difference between the AddOns tab and the Game tab. Internally it calls `SettingsInbound.RegisterCategory(category, group, addon=true)`. Source: `wow-ui-source\Interface\AddOns\Blizzard_Settings_Shared\Blizzard_Settings.lua` lines 128–137.
- `Settings.RegisterVerticalLayoutCategory(name)` returns `(category, layout)` — both objects are used: `category` is what you register settings to and pass to `RegisterAddOnCategory`; `layout` is what you call `:AddInitializer(...)` on for non-setting widgets like buttons and section headers. Source: `Blizzard_Settings.lua:153`, `Blizzard_SettingsInbound.lua:84`.
- We use the **vertical layout**, not canvas. Canvas (`Settings.RegisterCanvasLayoutCategory(frame, name)`) is for fully bespoke UIs where you draw your own frame. We have ~10 widgets and zero custom-render needs, so vertical list is correct. Choosing canvas would force us to lay out every checkbox/slider by hand and to implement our own `OnRefresh`/`OnCommit`/`OnDefault` hooks (see `Blizzard_ImplementationReadme.lua:35-41`). Skip it.

---

## Per-control reference

### 1. Six per-channel listen checkboxes (`Settings.RegisterAddOnSetting` + `Settings.CreateCheckbox`)

This is the biggest win in 11.0.2: `RegisterAddOnSetting` *both* default-initializes the SavedVariables key **and** writes the new value back on every change. We never call `db.channels.SAY = value` ourselves — the framework does it through a `securecallfunction` wrapper. Source: `Blizzard_Setting.lua:413-435` (`AddOnSettingMixin:Init` and the `SecureSetValueDerived` it installs).

```lua
local CHANNELS = {
    { key = "SAY",            label = "Listen on /say" },
    { key = "RAID",           label = "Listen on /raid" },
    { key = "RAID_LEADER",    label = "Listen on /raid (leader)" },
    { key = "RAID_WARNING",   label = "Listen on /rw" },
    { key = "INSTANCE",       label = "Listen on /instance" },
    { key = "INSTANCE_LEADER", label = "Listen on /instance (leader)" },
}

function ns:RegisterChannelToggles(category, layout, db)
    -- Section header above the group.
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Chat channels"))

    -- Ensure the parent table exists. RegisterAddOnSetting handles
    -- per-key defaulting, but the holder table itself must exist.
    db.channels = db.channels or {}

    for _, ch in ipairs(CHANNELS) do
        local variable = "TLH_CHANNEL_" .. ch.key      -- unique global identifier
        local setting = Settings.RegisterAddOnSetting(
            category,           -- categoryTbl
            variable,           -- variable (must be unique; prefix with addon name)
            ch.key,             -- variableKey (key inside the holder table)
            db.channels,        -- variableTbl (the holder; framework writes here)
            Settings.VarType.Boolean,
            ch.label,           -- name (shown next to the checkbox)
            true                -- defaultValue
        )

        -- React on change. Callback runs immediately when the user
        -- toggles the box (NOT delayed until panel close).
        setting:SetValueChangedCallback(function(_, value)
            ns:OnChannelToggle(ch.key, value)  -- refresh chat-event subscriptions
        end)

        Settings.CreateCheckbox(category, setting)  -- 3rd arg = optional tooltip
    end
end
```

Sources: `Blizzard_Settings.lua:173-175` (`RegisterAddOnSetting`), `Blizzard_Settings.lua:382-390` (`CreateCheckbox` / `CreateCheckboxWithOptions`), `Blizzard_Setting.lua:265-269` (`SettingMixin:SetValueChangedCallback`).

**Why `RegisterAddOnSetting` over `RegisterProxySetting`:** the proxy variant is correct when you need to mutate non-table state (CVars, runtime caches, computed values). Our case is a flat boolean stored in our own SavedVariables — `RegisterAddOnSetting` is exactly designed for this and skips boilerplate (no manual `if db.x == nil then db.x = default end`, no `function GetValue/SetValue` pair). The proxy variant adds ~12 lines per setting for no benefit here. Reserve proxy for the slider if you want clamping (see below).

**Footgun — argument order changed in 11.0.2:** old code (10.x) had `RegisterAddOnSetting(categoryTbl, name, variable, variableType, defaultValue)`. New signature inserts `variableKey` and `variableTbl` in the middle: `(categoryTbl, variable, variableKey, variableTbl, variableType, name, defaultValue)`. Note `name` is now next-to-last, not second. This is the single most common copy-paste bug from old guides. Source: `Blizzard_Settings.lua:173`.

### 2. Window-scale slider (range 0.50–2.00, default 1.00, step 0.05)

```lua
function ns:RegisterScaleSlider(category, layout, db)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Window"))

    local setting = Settings.RegisterAddOnSetting(
        category,
        "TLH_WINDOW_SCALE",
        "scale", db,
        Settings.VarType.Number,
        "Window scale",
        1.00
    )

    setting:SetValueChangedCallback(function(_, value)
        if ns.win then ns.win:SetScale(value) end
    end)

    -- minValue, maxValue, step
    local options = Settings.CreateSliderOptions(0.50, 2.00, 0.05)

    -- The right-hand label format. MinimalSliderWithSteppersMixin.Label.Right
    -- means the value-label sits on the right of the slider (matches the
    -- audio panel). FormatPercentage is a global Blizzard helper.
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)

    Settings.CreateSlider(category, setting, options)
end
```

Sources: `Blizzard_Settings.lua:308-314` (`CreateSliderOptions` — note `steps = (maxValue - minValue) / rate`, so a step of 0.05 across 0.50–2.00 yields 30 stops), `Blizzard_Settings.lua:398-402` (`CreateSlider`), and the live example at `Blizzard_Settings_Shared\Mainline\AudioOverrides.lua:11-17` for the slider-options pattern.

**Footgun — clamping:** `CreateSliderOptions` does NOT clamp values you set programmatically. If you ever expose `/lura scale 3.0`, validate before assigning. The slider widget itself respects the bounds.

### 3. Auto-hide-when-empty checkbox

Same shape as the channel toggles. Single setting:

```lua
function ns:RegisterAutoHideToggle(category, layout, db)
    local setting = Settings.RegisterAddOnSetting(
        category,
        "TLH_AUTO_HIDE",
        "autoHide", db,
        Settings.VarType.Boolean,
        "Auto-hide when empty",
        false
    )
    setting:SetValueChangedCallback(function(_, value)
        ns:OnAutoHideChanged(value)
    end)
    Settings.CreateCheckbox(category, setting,
        "When enabled, the helper window hides while no runes are displayed (including after the 15 s self-clear) and reappears as soon as the next message fills slot 1.")
end
```

The third arg to `CreateCheckbox` is a tooltip string (or function); shows on hover. Source: `Blizzard_Settings.lua:382-390`.

### 4. Two action buttons: "Recreate Macros" and "Unlock helper window"

Buttons are *not* Setting-bound. They're plain "elements" with an OnClick. The canonical helper is `CreateSettingsButtonInitializer`. The mixin's `Init` literally does `self.Button:SetScript("OnClick", self.data.buttonClick)` — your callback is wired to a standard `UIPanelButtonTemplate` button. Source: `Blizzard_SettingControls.lua:710-723` and `Blizzard_SettingControls.lua:762-774`.

```lua
function ns:RegisterActionButtons(category, layout)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Actions"))

    -- Button 1: Recreate macros.
    -- Combat-lockdown rule: CreateMacro/EditMacro are blocked while
    -- InCombatLockdown() is true. We surface that instead of failing
    -- silently. The button itself is allowed to run any Lua (no secure-
    -- template constraint applies — these initializers are insecure,
    -- which is exactly why they can call addon code freely).
    do
        local function OnClick()
            if InCombatLockdown() then
                print("|cffaa44ffTLH|r: Can't recreate macros during combat. "
                    .. "They will be retried on PLAYER_REGEN_ENABLED, or click again after combat.")
                return
            end
            ns:RegisterMacros()  -- defined in Macros.lua
        end
        local addSearchTags = true
        local initializer = CreateSettingsButtonInitializer(
            "Macros",                 -- left-side label (shown when non-empty)
            "Recreate macros",        -- button text
            OnClick,                  -- onClick
            "Recreates the five TLH_* player macros if you've deleted or edited them. "
              .. "Disabled-on-combat: the button still appears but the action waits for combat end.",
            addSearchTags
        )
        layout:AddInitializer(initializer)
    end

    -- Button 2: Unlock helper window. Mirrors the lock toggle on the
    -- window itself; reading current state from the DB lets the label
    -- update each time the panel is shown.
    do
        local function OnClick()
            ns:ToggleWindowLock()
        end
        local function buttonText()
            if ns.db.locked then return "Unlock window" else return "Lock window" end
        end
        local initializer = CreateSettingsButtonInitializer(
            "Window",
            buttonText,                -- buttonText accepts a function — re-evaluated on Init
            OnClick,
            "Toggles whether the helper window can be dragged.",
            true
        )
        layout:AddInitializer(initializer)
    end
end
```

**Note on `buttonText` as function:** `SettingsButtonControlMixin:EvaluateName` (line 702) accepts either a string or a function and calls the function each time the control is reinitialized. For our lock-state mirror this is desirable — when the user toggles via the on-window button and *then* opens the settings panel, the label is correct.

**Why not register lock state as a Setting + SetValueChangedCallback bidirectionally?** You can, but it doubles the moving parts. The user-perception is "two buttons that do the same thing"; making the in-window button mutate `ns.db.locked` and call `Settings.NotifyUpdate("TLH_LOCKED")` works, but it's strictly heavier than the function-as-text trick above. If we ever expose `Lock` as a checkbox in the panel, switch to bidirectional. Until then, button-with-dynamic-label wins.

### 5. Read-only command-examples text block

Blizzard does not ship a "multi-line label" element. The canonical solutions, ranked:

1. **One section header per command (recommended).** `CreateSettingsListSectionHeaderInitializer(name, tooltip)` accepts a tooltip; the name appears as bold styled heading text matching the rest of the panel. We list the four commands as four headers, each with a one-line tooltip describing what it does. Pros: zero custom code, font matches Blizzard's panel exactly, works with the Settings search box. Cons: visually heavier than a single help block. Source: `Blizzard_SettingControls.lua:100-103`.

2. **Custom canvas frame via `Settings.CreateElementInitializer`.** You define an `XML` template with a `FontString` and pass the template name. Pros: pixel-perfect control, can render bullets / monospace. Cons: requires a `.xml` file and a mixin; ~30 lines of code for a static text block. Skip.

3. **A no-op disabled checkbox per command.** Hack — never do this.

Recommended pattern:

```lua
function ns:RegisterCommandHelp(category, layout)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Slash commands"))

    local CMDS = {
        { "/lura",        "Toggle the helper window (and processing) on/off." },
        { "/lura show",   "Enable processing and show the window." },
        { "/lura hide",   "Disable processing and hide the window." },
        { "/lura clear",  "Clear all five slots immediately. Does not change enabled/disabled state." },
        { "/tlh",         "Alias for /lura." },
        { "/lura config", "Open this settings panel." },
    }

    for _, c in ipairs(CMDS) do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(c[1], c[2]))
    end
end
```

If we later want a denser block, switch to option 2 (an XML-defined Frame template registered with `Settings.CreateElementInitializer("TLHCommandsHelpTemplate", {})`); but that is a milestone-2 polish, not v1.

---

## Slash-command integration — `/lura config`

Open the panel by category ID. The ID is a number returned by `category:GetID()`. Source: `Blizzard_ImplementationReadme.lua:200-211` and `SettingsUtilDocumentation.lua:14-25` (`C_SettingsUtil.OpenSettingsPanel(openToCategoryID, scrollToElementName)` is the secure backing call; `Settings.OpenToCategory` is the wrapper, see `Blizzard_Settings.lua:143-145`).

Wire it into the existing slash command in `Core.lua`:

```lua
SLASH_LURA1 = "/lura"
SLASH_LURA2 = "/tlh"
SlashCmdList["LURA"] = function(msg)
    local arg = (msg or ""):lower():match("^(%S+)") or ""
    if arg == "show" then
        ns:ShowWindow()
    elseif arg == "hide" then
        ns:HideWindow()
    elseif arg == "clear" then
        ns:ClearSequence()
    elseif arg == "config" or arg == "options" then
        if ns.settingsCategoryID then
            Settings.OpenToCategory(ns.settingsCategoryID)
        else
            -- ContinueOnAddOnLoaded hasn't fired yet — extremely unlikely
            -- in practice (settings registration is synchronous w/r/t
            -- ADDON_LOADED), but guard it.
            print("|cffaa44ffTLH|r: settings not yet ready, try again in a moment.")
        end
    else
        ns:ToggleWindow()
    end
end
```

**Footgun — passing a string to `OpenToCategory`:** older guides show `Settings.OpenToCategory("My Addon")` (the category *name*). The current secure backing call (`C_SettingsUtil.OpenSettingsPanel`) types the first arg as `number`, and the Blizzard implementation readme is explicit: "The ID needs to be retrieved from your category or subcategory using `GetID()`". Pass the *number*, not the string. Source: `SettingsUtilDocumentation.lua:21`.

---

## Footguns / known issues

1. **Argument order of `RegisterAddOnSetting` changed in 11.0.2.** Old: `(categoryTbl, name, variable, variableType, defaultValue)`. New: `(categoryTbl, variable, variableKey, variableTbl, variableType, name, defaultValue)`. Nearly every guide on the public web that predates Aug 2024 will compile but write to the wrong key (or not at all). Use the Blizzard source as the only signature reference.

2. **Combat lockdown on the "Recreate Macros" button.** `CreateMacro` and `EditMacro` are blocked when `InCombatLockdown()` returns true (see the POC for the existing handling). The Settings button itself runs fine in combat — it's plain Lua — but the macro API call inside it will silently fail. The pattern in the snippet above (early-return with an info print) is the right shape; matching the POC's existing retry on `PLAYER_REGEN_ENABLED` covers the auto-recovery path.

3. **No `secure-template` requirement for our buttons.** Settings buttons are insecure on purpose — they exist to call addon code. This contrasts with action-bar buttons (which need `SecureActionButtonTemplate`) and is why the modal in the POC works the way it does. Don't try to wrap our OnClick in a secure template.

4. **`SetValueChangedCallback` fires immediately, not on Apply.** The default commit flag for `RegisterAddOnSetting` is *no Apply requirement*; the value writes through and the callback fires the moment the user clicks the checkbox / drags the slider. This matches what we want (live preview of scale changes, immediate effect of channel toggles). Settings whose changes need to be batched can opt into `Settings.CommitFlag.Apply`, but we have no use for that. Source: `Blizzard_Settings.lua:29-39` (CommitFlag enum) and the lack of `setting:SetCommitFlags(...)` calls in `RegisterAddOnSetting`.

5. **`EventUtil.ContinueOnAddOnLoaded(addonName, ...)` is mandatory.** If you call `Settings.RegisterAddOnSetting(..., db, ...)` before `ADDON_LOADED` fires, `db` is `nil` (because SavedVariables haven't been deserialized yet) and you get a hard error from the assert at `Blizzard_Setting.lua:417` ("`'variableTbl' argument must be a table.`"). Use the wrapper.

6. **Subcategory sorting.** `Settings.RegisterAddOnCategory` lists addons alphabetically; subcategories under our category, if we ever add them, are NOT sorted unless we call `category:SetShouldSortAlphabetically(true)`. Source: `Blizzard_ImplementationReadme.lua:213-216`. v1 has no subcategories, so n/a.

7. **`InterfaceOptions_AddCategory` is removed/dead.** Pre-Dragonflight pattern. It still resolves to a function in some shim layers but does nothing useful in 12.0; the panel does not appear. Don't fall back to it. Source: the function is no longer referenced anywhere in `Blizzard_Settings_Shared`.

8. **Reusable utility code from TerribleBuffTracker?** `CDMTab.lua` is a *different* pattern — it builds a custom tab inside Blizzard's `CooldownViewerSettings` frame using `LargeSideTabButtonTemplate`, `ListHeaderThreeSliceTemplate`, and direct frame layout. None of that applies to a vanilla Options > AddOns entry. The only crossover is the same author's preference for `SavedVariables` initialization in `Core.lua`'s `ADDON_LOADED` handler (lines 14-83 of TBT's Core.lua), which we mirror exactly. The `EventUtil.ContinueAfterAllEvents(...)` pattern at the bottom of `CDMTab.lua` (line 1154) is similar in spirit to `EventUtil.ContinueOnAddOnLoaded` but waits on multiple events; we only need single-addon-loaded, so use the simpler helper.

9. **Don't forget the namespace.** TBT and the POC use `local addonName, ns = ...`. The `addonName` arg from `EventUtil.ContinueOnAddOnLoaded(addonName, ...)` MUST be the literal addon folder name (`"TerribleLuraHelper"`) — same as the one Blizzard fires with `ADDON_LOADED`. Use the `addonName` local that the loader passes in; don't hard-code a different string.

10. **Don't fight the framework on layout.** Vertical layout stacks initializers in the order you call `AddInitializer` / `Settings.CreateCheckbox` / `Settings.CreateSlider`. There is no column / grid / two-up pairing primitive (other than the bespoke `CreateSettingsCheckboxSliderInitializer` Blizzard uses internally for ping-volume — it is non-public and uses a dedicated XML template). Order your registration calls in the order you want them visible.

---

## Confidence summary

| Recommendation | Confidence | Source / rationale |
|----------------|------------|--------------------|
| `Settings.RegisterVerticalLayoutCategory(name)` returns `(category, layout)` and is the right entry point | HIGH | `wow-ui-source\Blizzard_Settings.lua:153-155`; matches `Blizzard_ImplementationReadme.lua:13` |
| `Settings.RegisterAddOnCategory(category)` is what places the panel under Options > AddOns | HIGH | `Blizzard_Settings.lua:133-137` (`addon = true` branch of `SettingsInbound.RegisterCategory`) |
| `Settings.RegisterAddOnSetting(categoryTbl, variable, variableKey, variableTbl, variableType, name, defaultValue)` writes through to SavedVariables and auto-defaults | HIGH | `Blizzard_Settings.lua:173-175` and `Blizzard_Setting.lua:413-435` (`AddOnSettingMixin:Init` + the `SecureSetVariableTblDefaultValue` / `SecureSetValueDerived` it installs) |
| `Settings.CreateCheckbox(category, setting, tooltip)` for boolean controls | HIGH | `Blizzard_Settings.lua:382-390` |
| `Settings.CreateSlider(category, setting, options)` + `Settings.CreateSliderOptions(min, max, step)` for the scale slider | HIGH | `Blizzard_Settings.lua:308-314` (slider options), `:398-402` (slider creation), live example at `AudioOverrides.lua:11-17` |
| `CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, addSearchTags)` then `layout:AddInitializer(initializer)` for action buttons; OnClick is plain Lua | HIGH | `Blizzard_SettingControls.lua:762-774` (helper) and `:710-723` (`SettingsButtonControlMixin:Init` wires `Button:SetScript("OnClick", self.data.buttonClick)`); live example `AudioOverrides.lua:29-34` |
| `setting:SetValueChangedCallback(callback)` fires immediately on user change (not deferred to Apply) | HIGH | `Blizzard_Setting.lua:265-269` registers via `Settings.SetOnValueChangedCallback` which routes through `SettingsCallbackRegistry:TriggerEvent` synchronously |
| `Settings.OpenToCategory(category:GetID())` opens the panel from a slash command; arg is a number | HIGH | `Blizzard_Settings.lua:143-145`, `SettingsUtilDocumentation.lua:21` types the arg as `number`, `Blizzard_ImplementationReadme.lua:200-211` is explicit |
| `EventUtil.ContinueOnAddOnLoaded(addonName, callback)` is the right gate for SavedVariables-dependent registration | HIGH | `Blizzard_SharedXML\EventUtil.lua:71`, used by the implementation readme example |
| `CreateSettingsListSectionHeaderInitializer(name, tooltip)` is the right element for both true headings AND the slash-command help block (via tooltip) | HIGH | `Blizzard_SettingControls.lua:100-103` confirms signature, `AudioOverrides.lua:5,40` confirms idiomatic use, repeated headers as line items is mechanically valid (each is a separate initializer) |
| In-combat handling on "Recreate Macros" — early-return with `InCombatLockdown()` check | HIGH | The POC at `LuraPatternHelper.lua:57-58` already does this; Blizzard's macro API restriction is well-known and stable |
| Existing TBT `CDMTab.lua` is *not* directly reusable (different pattern, custom tab inside CooldownViewer); only the SavedVariables-init style from `Core.lua` carries over | HIGH | Read both files in full; CDMTab uses `LargeSideTabButtonTemplate`/`hooksecurefunc` on `CooldownViewerSettings:SetDisplayMode`, neither of which applies to Options > AddOns |
| Vertical layout has no built-in two-column pairing; widgets stack in registration order | MEDIUM | True per the public API; Blizzard ships internal helpers (`CreateSettingsCheckboxSliderInitializer`) that combine controls but they are not addon-facing. Verify in-game if a paired-control look becomes a UX requirement. |
| The `buttonText` arg to `CreateSettingsButtonInitializer` accepts a function and re-evaluates on Init (used for the dynamic Lock/Unlock label) | MEDIUM | `Blizzard_SettingControls.lua:702-708` (`EvaluateName` calls the function if `type == "function"`); `:711-720` (`Init` calls `EvaluateName` once). It is NOT re-evaluated on every panel show — only when `Init` runs. If the user toggles via the in-window button while the panel is open, the panel's label won't update until the panel is reshown. If that's important, add a `setting`-backed checkbox instead of relying on the dynamic label. |
| The Settings-panel-open event (`SETTINGS_PANEL_OPEN`) is documented and could be hooked if needed | LOW | `SettingsUtilDocumentation.lua:38-46`. Not required for our use case; called out for completeness so the executor doesn't reinvent it later. |

**Verify in-game (one short test session):**
- Channel checkbox toggles persist across `/reload`.
- Scale slider live-updates the helper window without panel close.
- "Recreate Macros" button works out of combat and prints the lockdown notice when inside combat.
- `/lura config` opens the panel directly to TerribleLuraHelper.
- The panel appears under **Options > AddOns**, not under Game.

Everything else can be fully verified from the wow-ui-source tree without launching the client.
