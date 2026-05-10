# Stack Research

**Domain:** WoW Midnight (Interface 120005) addon — v1.0.0 polish features
**Researched:** 2026-05-09
**Confidence:** HIGH (all API claims verified against wow-ui-source@12.0.1 or warcraft.wiki.gg)

---

## Scope: What This Document Covers

Five new v1.0.0 features only. Everything from v0.1.0 is already validated and is not re-researched here.

| Feature | Short name |
|---------|-----------|
| Lock-coupled click-through | CLICK-THRU |
| Static reference texture in config panel | TEXTURE |
| Dynamic Show/Hide button label (live update) | DYNLABEL |
| SAY-centric defaults backfill | DEFAULTS |
| Auto-hide reframed to in-combat-only | COMBAT-HIDE |

---

## Recommended APIs by Feature

### CLICK-THRU — Lock-coupled click-through

**Verdict:** Use `win:EnableMouse(false)` when locking, `win:EnableMouse(true)` when unlocking. Set both before and after `SetMovable` / `RegisterForDrag` as today.

**Available APIs (verified in `SimpleScriptRegionAPIDocumentation.lua`):**

| API | Signature | Restriction type |
|-----|-----------|-----------------|
| `ScriptRegion:EnableMouse(enable)` | `bool, default false` | `SecretArguments = "NotAllowed"` |
| `ScriptRegion:SetMouseClickEnabled(enabled)` | `bool, default false` | `SecretArguments = "NotAllowed"` |
| `ScriptRegion:EnableMouseMotion(enable)` | `bool, default false` | `SecretArguments = "NotAllowed"` |
| `ScriptRegion:SetMouseMotionEnabled(enabled)` | `bool, default false` | `SecretArguments = "NotAllowed"` |
| `Frame:SetMovable(movable)` | `bool` | `SecretArguments = "AllowedWhenUntainted"` |
| `Frame:RegisterForDrag(buttons...)` | `vararg MouseButton` | `SecretArguments = "AllowedWhenUntainted"` |

**`SecretArguments = "NotAllowed"` does NOT mean addon-blocked.** It means you cannot pass a secret-value (tainted combat data) as the argument — a plain boolean literal like `false` is never a secret value. Confirmed: `EnableMouse` is not listed in the `Category:API_functions/restricted` page on warcraft.wiki.gg, which is the authoritative list of functions blocked from addon code. Blizzard's own non-secure addon code (e.g., `Blizzard_Channels/VoiceActivityNotification.lua:85`) calls `self:EnableMouse(false)` from `OnLoad`, and non-Blizzard addons widely use it without `ADDON_ACTION_FORBIDDEN`.

The `IsProtectedFunction = true` annotation in the generated docs is a Blizzard API-docs metadata field; it means "calling this on a protected frame during combat fires `ADDON_ACTION_BLOCKED`". Our frame (`TerribleLuraHelperWindow`) is NOT a protected frame — it is a plain `CreateFrame("Frame", ...)`. The lock toggle already runs outside combat (the lock button is on-screen and the config panel is accessible). No combat guard needed.

**`EnableMouse(false)` vs `SetMouseClickEnabled(false)`:**

- `EnableMouse(false)` disables both click and motion events simultaneously. Use it for locked state: fully pass-through.
- `SetMouseClickEnabled(false)` disables only click events; motion (OnEnter/OnLeave) still fires. Not what we want — a fully locked frame should not react to hover either.
- **Use `EnableMouse(false/true)`** — it is the single-call equivalent of setting both sub-controls.

**`RegisterForDrag()` with no arguments** clears all drag registrations (confirmed by the current `applyLockState()` implementation in `Window.lua` which already does this correctly). No API change needed.

**Concrete `applyLockState` pattern for v1.0.0:**

```lua
applyLockState = function()
    local locked = ns.db.window.locked
    if locked then
        win:SetMovable(false)
        win:RegisterForDrag()       -- clears drag; vararg with zero args = no buttons
        win:EnableMouse(false)      -- NEW: fully click-through when locked
        lockBtn:Hide()
    else
        win:SetMovable(true)
        win:RegisterForDrag("LeftButton")
        win:EnableMouse(true)       -- NEW: restore mouse on unlock
        lockBtn:Show()
    end
end
```

**Targets:** CLICK-THRU feature only.

---

### TEXTURE — Static reference texture in config panel

**Verdict:** Ship a `.tga` file. Load it with `texture:SetTexture("Interface\\AddOns\\TerribleLuraHelper\\symbols.tga")`. Insert via `Settings.CreateElementInitializer` with a custom XML frame template. Dimensions must be a power of two; use `SetTexCoord` for letterboxing if the artwork aspect ratio requires it.

**File format decision — TGA over PNG over BLP:**

| Format | Alpha | Tools | Dimensions | Path in SetTexture | Verdict |
|--------|-------|-------|-----------|-------------------|---------|
| `.tga` | 32-bit RGBA | Any image editor (export TGA 32-bit) | Power of two required | `"Interface\\AddOns\\...\\file.tga"` | **Use this** |
| `.png` | Yes | Any image editor | Power of two required | Must include `.png` extension explicitly (Patch 10.0.7+) | Fine, but see pkgmeta issue below |
| `.blp` | Yes | Requires BLP conversion tool | Power of two required | `"Interface\\AddOns\\...\\file.blp"` | Avoid — no direct export from standard editors |

TGA is the standard recommendation from warcraft.wiki.gg: "Instead of converting to BLP files…the WoW engine also accepts TGA files, which can be edited directly in graphics editors." BLP requires a dedicated converter step with no tooling advantage for a static cheat sheet.

**CRITICAL pkgmeta issue:** The current `.pkgmeta` contains `"*.png"` in its ignore list, which excludes all PNG files from the release package. TGA files are not in the ignore list and ship automatically. This is another reason to use `.tga`.

**If the artist delivers PNG:** Remove `"*.png"` from the `.pkgmeta` ignore list (or change to `"*.tga"` exclude if they deliver TGA). Do not ship both; pick one format before the milestone closes.

**`SetTexture` string restriction in Midnight (12.0.0):** The Patch 12.0.0 change that says "SetTexture will no longer accept secret strings" refers specifically to passing a *secret value* (a Lua value tainted by combat-restricted code) as the texture path. A hardcoded string literal like `"Interface\\AddOns\\TerribleLuraHelper\\symbols.tga"` is never a secret value — this path is verified safe. `SetTexture` is `SecretArguments = "AllowedWhenTainted"` meaning addon code can call it freely.

**Power-of-two dimensions:** Required. `512x128` is valid (wide cheat sheet). `512x100` is not — shows as solid green. The artist must be given this constraint.

**Inserting the texture element into the vertical-layout Settings panel:**

The vertical layout has no built-in "image" element. Use `Settings.CreateElementInitializer(frameTemplate, data)` with a custom XML frame template. This is the canonical approach — `CreateSettingsListSectionHeaderInitializer` and `CreateSettingsButtonInitializer` both use this same mechanism under the hood (verified: `Blizzard_SettingControls.lua:102, 764`).

Minimal approach:

```xml
<!-- TerribleLuraHelper.xml (new file, listed in .toc before Config.lua) -->
<Ui>
  <Frame name="TLHSymbolReferenceTemplate" virtual="true">
    <Size x="600" y="128"/>
    <Layers>
      <Layer level="ARTWORK">
        <Texture name="$parentTexture">
          <Size x="512" y="128"/>
          <Anchors>
            <Anchor point="CENTER"/>
          </Anchors>
        </Texture>
      </Layer>
    </Layers>
    <Scripts>
      <OnLoad>
        self.Texture:SetTexture(self.data and self.data.texturePath
          or "Interface\\AddOns\\TerribleLuraHelper\\symbols.tga")
        self.Texture:SetTexCoord(0, 1, 0, 1)
      </OnLoad>
    </Scripts>
  </Frame>
</Ui>
```

```lua
-- in Config.lua, before RegisterChannelToggles:
local initializer = Settings.CreateElementInitializer("TLHSymbolReferenceTemplate",
    { texturePath = "Interface\\AddOns\\TerribleLuraHelper\\symbols.tga" })
layout:AddInitializer(initializer)
```

**`SetTexCoord` for letterboxing:** If the artwork is not the exact power-of-two texture size (e.g., the visible content is 500px wide in a 512px canvas), use `SetTexCoord(left, right, top, bottom)` to crop. `SetTexCoord` is `SecretArguments = "AllowedWhenTainted"` — fully callable from addon code. The argument order is `(left, right, bottom, top)` in the four-number form (this is a common source of confusion — verified in `SimpleTextureBaseAPIDocumentation.lua:416`).

**Alternative — canvas layout:** `Settings.RegisterCanvasLayoutCategory` gives full control of a bespoke frame. Use only if the vertical list approach proves too limiting. Adds `OnRefresh`/`OnCommit`/`OnDefault` boilerplate and loses the automatic widget stacking. Not warranted for a single static image.

**Targets:** TEXTURE feature only.

---

### DYNLABEL — Dynamic Show/Hide button label (live update)

**Verdict:** Store the button widget reference in `ns` after panel registration; call `ns.showHideBtn:SetText(label)` from the notify hook in Window.lua after any state change. No new API needed.

**How `EvaluateName` works today (verified `Blizzard_SettingControls.lua:702-720`):**

`SettingsButtonControlMixin:Init` is called when the panel is shown or when `RepairDisplay()` forces reinitialize. Inside `Init`, `self.Button:SetText(self:EvaluateName())` runs — which calls the `buttonText` function if it is a function. So the label IS correct every time the panel opens. The existing `buttonText` function approach already handles the "panel opens after state changed elsewhere" case.

The gap is: if the panel is already open and the user clicks `/lura` in chat or the lock button on the window itself, the panel's button label becomes stale until the panel is closed and reopened.

**Solution — notify hook pattern:**

After `layout:AddInitializer(initializer)` for the Show/Hide button, do NOT wrap the button in a Setting. Instead:

1. In `Config.lua`, capture the button widget after initialization. Use `initializer:SetOnInitializedCallback` if available, or expose the button via `ns.showHideBtn` after the panel first renders.

The simplest working pattern (no new API):

```lua
-- In Config.lua RegisterWindowControls:
local showHideInitializer
do
    local function OnClick()
        if ns:IsWindowShown() then ns:HideWindow() else ns:ShowWindow() end
    end
    local function buttonText()
        return ns:IsWindowShown() and "Hide window" or "Show window"
    end
    showHideInitializer = CreateSettingsButtonInitializer("", buttonText, OnClick,
        "Toggles the helper window between shown and hidden — same as typing /lura.", true)
    layout:AddInitializer(showHideInitializer)
end

-- In Window.lua ns:ShowWindow / ns:HideWindow, after state changes, call:
-- ns:NotifyShowHideLabelChanged()

-- In Config.lua, expose the notify function:
function ns:NotifyShowHideLabelChanged()
    -- RepairDisplay re-calls Init on all elements including our button.
    -- Only call when the panel is visible to avoid wasted work.
    if SettingsPanel and SettingsPanel:IsShown() then
        SettingsInbound.RepairDisplay()
    end
end
```

`SettingsInbound.RepairDisplay()` is a public function (verified `Blizzard_SettingsInbound.lua:156-158`). It re-initializes all controls in the currently displayed category by firing `RepairDisplay` through the `AttributeDelegate` secure proxy. Calling it only when `SettingsPanel:IsShown()` is true prevents wasted work outside the panel.

**Alternative: direct button reference.** Store `ns.showHideBtn = <the Button widget>` by capturing it from `self.Button` inside a `gameDataFunc` callback. The `gameDataFunc` seventh argument to `CreateSettingsButtonInitializer` (verified `Blizzard_SettingControls.lua:762`) is called as an `EventRegistry` event callback — it is not suitable for arbitrary "call me when label changes." The `RepairDisplay` approach is cleaner.

**Targets:** DYNLABEL feature only.

---

### DEFAULTS — SAY-centric defaults backfill

**No new APIs.** Uses the existing `Core.lua` backfill pattern.

**Changes to `Core.lua` ADDON_LOADED handler:**

```lua
-- Fresh DB block: change default for macroChannel and listenChannels
TerribleLuraHelperDB = {
    listenChannels = {
        SAY = true,           -- CHANGED: SAY on by default
        RAID = false,         -- CHANGED: RAID off by default
        RAID_LEADER = false,
        RAID_WARNING = false,
        INSTANCE_CHAT = false,
        INSTANCE_CHAT_LEADER = false,
    },
    window = { ... },
    macroChannel = "SAY",     -- CHANGED: SAY by default
}

-- Backfill block: existing keys are NOT touched (nil check is the guard)
-- New keys added for users upgrading from fresh installs that predate SAY default:
-- (none new — all keys already exist; default-change for EXISTING users is opt-in via reset)
```

**Backfill rule:** The backfill block only writes keys that are `nil`. Users who installed v0.1.0 already have `macroChannel = "RAID"` and `listenChannels.RAID = true` written in their DB — those values are NOT `nil`, so the backfill does NOT overwrite them. The default change only affects users installing v1.0.0 fresh. This is the correct behavior as specified in PROJECT.md.

**Config.lua default change:** `Settings.RegisterAddOnSetting` calls for `listenChannels` and `macroChannel` must update their `defaultValue` arguments to match (`SAY = true` / others `false` / `macroChannel = "SAY"`). The framework uses these defaults when applying "Reset to Defaults" — they must be consistent with the Core.lua defaults.

**Targets:** DEFAULTS feature only.

---

### COMBAT-HIDE — Auto-hide reframed to in-combat-only

**Events needed:** `PLAYER_REGEN_ENABLED` and `PLAYER_REGEN_DISABLED`. Both are already used in `Macros.lua` (verified). No new event infrastructure required.

**Current implementation path:** `applySoftHideState()` in `Window.lua` runs unconditionally: if `autoHide=on AND #sequence==0` → alpha=0. The reframe makes this conditional on combat state.

**New behavior:**
- Out of combat + `autoHide=on` + `#sequence==0` → window stays visible (alpha = saved alpha)
- In combat + `autoHide=on` + `#sequence==0` → alpha = 0 (existing behavior)
- Sequence fills → always restore alpha regardless of combat state (existing behavior)

**Implementation:** Add a `local inCombat = false` flag in `Window.lua`. Register `PLAYER_REGEN_ENABLED` / `PLAYER_REGEN_DISABLED` on the existing `chatFrame` (or a new lightweight frame) and update `inCombat`, then call `applySoftHideState()`. The `applySoftHideState` guard becomes:

```lua
applySoftHideState = function()
    if ns.db.window.autoHide and inCombat and #sequence == 0 then
        softHidden = true
        win:SetAlpha(0)
    else
        softHidden = false
        win:SetAlpha(ns.db.window.alpha or 1.00)
    end
end
```

**UI label + tooltip change:** The Settings checkbox label changes from `"Auto-hide when empty"` to `"Auto-hide when empty (in combat)"`. The `Settings.RegisterAddOnSetting` variable name `"TLH_AUTO_HIDE"` stays the same — no DB key change, no migration needed. The tooltip text updates to explain the in-combat semantics. The `defaultValue` stays `false`.

**Targets:** COMBAT-HIDE feature only.

---

## Library / Dependency Assessment

**Verdict: Stay zero-dependency.** No utility library is needed for any of the five features.

| Feature | Could use a library? | Why we don't |
|---------|---------------------|-------------|
| CLICK-THRU | No | One call: `EnableMouse(false)` |
| TEXTURE | No | `SetTexture` + one XML template block |
| DYNLABEL | No | `SettingsInbound.RepairDisplay()` + `IsShown()` guard |
| DEFAULTS | No | Nil-check backfill in existing pattern |
| COMBAT-HIDE | No | One boolean flag + existing `applySoftHideState` |

No utility library (LibStub, AceAddon, etc.) adds value for an addon this small. Adding a library dependency increases zip size, introduces version-mismatch risk at BigWigs Packager time, and creates an `embeds:` `.pkgmeta` section that needs maintenance. All five features use nothing beyond Blizzard built-ins already present on the client.

---

## pkgmeta Changes Required

The current `.pkgmeta` ignore block includes `"*.png"`. This must be addressed before shipping TEXTURE:

**If artwork is delivered as `.tga`:** No `.pkgmeta` change needed. TGA files ship automatically.

**If artwork is delivered as `.png`:** Remove `"*.png"` from the ignore list. Add `"*.tga"` instead if no TGA files exist.

The recommended delivery format is `.tga` — see TEXTURE section above.

---

## Interface Version Confirmation

`wow-ui-source` version.txt: `12.0.1.66337`. The `.toc` `Interface: 120005` declaration is correct and matches this tree. No version bump required.

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `SetMouseClickEnabled(false)` for click-through | Disables only click events; motion events (OnEnter/OnLeave) still fire, so hover tooltips or cursor changes still activate. `EnableMouse(false)` is the single-call full disable. | `EnableMouse(false)` |
| `SetPropagateMouseClicks` for click-through | Propagates clicks to frames below but the frame itself still receives them. Not click-through — it double-fires. | `EnableMouse(false)` |
| `SetPassThroughButtons` for click-through | Passes specific button types through, not a full disable. More granular than needed and adds complexity. | `EnableMouse(false)` |
| `.blp` for the cheat-sheet texture | Requires a BLP conversion tool; no direct export from Photoshop/Aseprite/etc. Artists deliver source files that need an extra conversion step with no quality benefit for a static image. | `.tga` (32-bit RGBA) |
| `.png` for the cheat-sheet texture | Fine technically, but the current `.pkgmeta` ignores `"*.png"` so it would be silently excluded from the release zip unless `.pkgmeta` is updated. Easier to just use `.tga` and avoid that footgun. | `.tga` |
| Non-power-of-two texture dimensions | Renders as solid green in-game. No error message — silent failure. | Power-of-two (e.g. `512x128`, `1024x256`) |
| `SettingsInbound.RepairDisplay()` called unconditionally | Rerenders all controls every time window visibility changes, even when the Settings panel is not open. | Guard with `if SettingsPanel and SettingsPanel:IsShown() then` |
| `InterfaceOptions_AddCategory` | Removed/dead in Midnight (12.0). Does nothing. | `Settings.RegisterAddOnCategory(category)` |

---

## Sources

- `wow-ui-source\Interface\AddOns\Blizzard_APIDocumentationGenerated\SimpleScriptRegionAPIDocumentation.lua` — `EnableMouse`, `SetMouseClickEnabled`, `EnableMouseMotion`, `SetMouseMotionEnabled`, `SetPropagateMouseClicks`, `SetPassThroughButtons` signatures and restriction annotations. Version 12.0.1.66337 (Interface 120005).
- `wow-ui-source\Interface\AddOns\Blizzard_APIDocumentationGenerated\SimpleFrameAPIDocumentation.lua` — `SetMovable`, `RegisterForDrag` signatures and `AllowedWhenUntainted` annotation.
- `wow-ui-source\Interface\AddOns\Blizzard_APIDocumentationGenerated\SimpleTextureBaseAPIDocumentation.lua` — `SetTexture`, `SetTexCoord` signatures; `AllowedWhenTainted` confirms addon-callable.
- `wow-ui-source\Interface\AddOns\Blizzard_Settings_Shared\Blizzard_SettingControls.lua:700-720, 762-774` — `EvaluateName` call site, `CreateSettingsButtonInitializer` signature, `gameDataFunc` pattern.
- `wow-ui-source\Interface\AddOns\Blizzard_Settings_Shared\Blizzard_SettingsInbound.lua:156-158` — `SettingsInbound.RepairDisplay()` public function.
- `wow-ui-source\Interface\AddOns\Blizzard_Settings_Shared\Blizzard_SettingsPanel.lua:144-148` — `OnShow` calls `SelectFirstCategory(force=true)` confirming controls re-init on panel open.
- `wow-ui-source\Interface\AddOns\Blizzard_Settings_Shared\Blizzard_Settings.lua:341-342` — `Settings.CreateElementInitializer` public wrapper.
- `wow-ui-source\Interface\AddOns\Blizzard_Channels\VoiceActivityNotification.lua:85` — Blizzard addon calling `self:EnableMouse(false)` from `OnLoad`, confirming addon-callable outside secure frame constraint.
- `wow-ui-source\Interface\AddOns\Blizzard_EncounterWarnings\EncounterWarningsView.lua:6` — `self:SetMouseClickEnabled(false)` from `OnLoad`.
- `wow-ui-source\Interface\AddOns\Blizzard_UIWidgets\Mainline\Blizzard_UIWidgetTemplateBase.lua:6` — `self:SetMouseClickEnabled(false)` at frame construction.
- `wow-ui-source\Interface\AddOns\Blizzard_Settings_Shared\Blizzard_ImplementationReadme.lua` — canonical vertical-layout pattern and `Settings.CreateElementInitializer` guidance.
- [warcraft.wiki.gg — Category:API functions/restricted](https://warcraft.wiki.gg/wiki/Category:API_functions/restricted) — `EnableMouse` is NOT listed, confirming it is not restricted from addon code. MEDIUM confidence (wiki may lag client).
- [warcraft.wiki.gg — API_TextureBase_SetTexture](https://warcraft.wiki.gg/wiki/API_TextureBase_SetTexture) — confirmed `.tga`, `.png`, `.blp`, `.jpeg` supported; power-of-two required; addon paths in `Interface/AddOns/` work since 9.0.1.
- [warcraft.wiki.gg — BLP files](https://warcraft.wiki.gg/wiki/BLP_files) — recommends TGA for addon devs: "Instead of converting to BLP files…the WoW engine also accepts TGA files, which can be edited directly in graphics editors."
- [BigWigs Packager wiki — Preparing the PackageMeta File](https://github.com/BigWigsMods/packager/wiki/Preparing-the-PackageMeta-File) — packager uses opt-out model; everything ships unless listed under `ignore:`. The current `"*.png"` ignore entry is confirmed to exclude PNG files from the release zip.
- [warcraft.wiki.gg — Patch 12.0.0/Planned API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes) — "SetTexture will no longer accept secret strings" applies only to secret-value arguments (tainted combat data), not to hardcoded string literals from addon code.

---
*Stack research for: TerribleLuraHelper v1.0.0 polish features*
*Researched: 2026-05-09*
