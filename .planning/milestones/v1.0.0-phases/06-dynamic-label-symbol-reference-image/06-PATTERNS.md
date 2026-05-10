# Phase 6: Dynamic Label + Symbol Reference Image - Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 4 (3 modified + 1 new)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `templates.xml` (NEW) | config / UI template | request-response | `Blizzard_SettingControls.xml` — `SettingsListSectionHeaderTemplate` | role-match |
| `TerribleLuraHelper.toc` | config | — | existing `.toc` lines 12-15 | exact |
| `Window.lua` (add export + 3 call sites) | utility / exported API | request-response | `Window.lua` `ns:OnAutoHideChanged` (line 286) | exact |
| `Config.lua` (add `RegisterReferenceImage` + call in `InitConfig`) | config / UI layout | request-response | `Config.lua` `RegisterChannelToggles` / `RegisterMacroSection` (lines 68, 222) | exact |

---

## Pattern Assignments

### `templates.xml` (NEW — virtual Frame template for reference image)

**Analog:** `wow-ui-source` `Blizzard_SettingControls.xml` — `SettingsListSectionHeaderTemplate` (line 13)

**XML namespace / root element pattern** (Blizzard_SettingControls.xml lines 1-2):
```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.blizzard.com/wow/ui/ ..\Blizzard_SharedXML\UI.xsd">
```

**Minimal virtual Frame + Layer pattern** (Blizzard_SettingControls.xml lines 13-35, condensed to the skeleton used):
```xml
<Frame name="SettingsListSectionHeaderTemplate" mixin="SettingsListSectionHeaderMixin" virtual="true">
    <Size y="45"/>
    <Layers>
        <Layer level="OVERLAY">
            <FontString parentKey="Title" inherits="GameFontHighlightLarge" .../>
        </Layer>
    </Layers>
    <Scripts>
        <OnLoad method="OnLoad"/>
    </Scripts>
</Frame>
```

**Adapted pattern for `TLHSymbolReferenceTemplate`** — replace the FontString child with a Texture child in layer "ARTWORK", add explicit `<Size>` matching the 319x143 native dimensions, add `<Scripts><OnLoad method="OnLoad"/></Scripts>` for the Mixin data-binding. No mixin attribute is required if the OnLoad is inlined as a `<OnLoad>` function block rather than a method reference; either form works. The executor chooses based on whether a Lua-side Mixin or an inline XML script is simpler:

- **Preferred (inline OnLoad, no external Mixin needed):**
```xml
<Frame name="TLHSymbolReferenceTemplate" virtual="true">
    <Size x="319" y="143"/>
    <Layers>
        <Layer level="ARTWORK">
            <Texture parentKey="Image" setAllPoints="true"/>
        </Layer>
    </Layers>
    <Scripts>
        <OnLoad>
            self.Image:SetTexture(self.data.texturePath)
        </OnLoad>
    </Scripts>
</Frame>
```

- **Alternative (Mixin method reference):** Add `mixin="TLHSymbolReferenceMixin"` to the Frame tag and define `TLHSymbolReferenceMixin = {}` + `function TLHSymbolReferenceMixin:OnLoad() self.Image:SetTexture(self.data.texturePath) end` in a Lua file. Adds complexity with no benefit for a 1-line body — avoid.

**Note on `self.data`:** `Settings.CreateElementInitializer(templateName, data)` stores `data` as `self.data` on the frame when the element is instantiated by the Settings list. This is the same mechanism used by `CreateSettingsListSectionHeaderInitializer` (Blizzard_SettingControls.lua line 101: `local data = {name = name, ...}; return Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", data)`) — the `SettingsListSectionHeaderMixin:OnLoad` reads `self.data.name`. The reference image template reads `self.data.texturePath` by the same convention.

**Anchoring guidance (Claude's Discretion):** The Settings list vertical-layout positions elements sequentially. For a virtual template that is the first element, the list's scroll box handles Y placement automatically. Within the frame, anchor the Texture's `setAllPoints="true"` to fill the parent frame — the frame's `<Size x="319" y="143"/>` controls the final dimensions.

---

### `TerribleLuraHelper.toc` (append `templates.xml`)

**Analog:** Existing `.toc` lines 12-15 (the Lua-file block).

**Current load order** (TerribleLuraHelper.toc lines 12-15):
```
Core.lua
Macros.lua
Window.lua
Config.lua
```

**Phase 6 addition — append as line 16:**
```
templates.xml
```

**Convention rationale:** Blizzard's `.toc` loader processes files in declaration order. XML files register virtual frame templates synchronously on load. `templates.xml` must appear AFTER `Config.lua` in the `.toc` because `Config.lua`'s runtime path (inside `EventUtil.ContinueOnAddOnLoaded`, deferred until ADDON_LOADED fires) calls `Settings.CreateElementInitializer("TLHSymbolReferenceTemplate", ...)` — by the time that deferred callback runs, all `.toc` files have already been loaded, so the template is available regardless of load order within the `.toc`. The convention of XML-after-Lua is the standard pattern used in Blizzard's own addon `.toc` files and avoids any future ordering ambiguity.

---

### `Window.lua` — new `ns:NotifyWindowVisibilityChanged` export

**Analog:** `Window.lua` `ns:OnAutoHideChanged` (lines 286-290) — closest shape: zero args, early-exit pattern implicit (checks state), calls into framework code.

**Analog excerpt** (Window.lua lines 286-290):
```lua
function ns:OnAutoHideChanged(value)
    -- The framework already wrote db.window.autoHide=value before this
    -- callback fires. We just re-evaluate state.
    applySoftHideState()
end
```

**Secondary analog — other small exports in the Phase 3 export block** (Window.lua lines 292-300):
```lua
function ns:LockWindow()
    ns.db.window.locked = true
    applyLockState()
end

function ns:UnlockWindow()
    ns.db.window.locked = false
    applyLockState()
end
```

**New function pattern — copy `ns:OnAutoHideChanged` shape, body from CONTEXT D-10:**
```lua
function ns:NotifyWindowVisibilityChanged()
    if SettingsPanel and SettingsPanel:IsShown() then
        SettingsInbound.RepairDisplay()
    end
end
```

**Placement:** Insert in the Phase 3 export block (after line 300, before line 302 `persistPosition`), alongside `LockWindow` / `UnlockWindow` / `OnAutoHideChanged`. This keeps all exported API surface grouped under the `-- Phase 3 exports` banner comment (Window.lua lines 268-271).

---

### `Window.lua` — one-line notify call added to ShowWindow, HideWindow, RestoreWindowVisibility

**Analog:** Existing body of each function being modified.

**`ns:ShowWindow` current body** (Window.lua lines 400-410):
```lua
function ns:ShowWindow()
    applySavedPosition()
    win:Show()
    softHidden = false
    win:SetAlpha(ns.db.window.alpha or 1.00)
    ns.db.window.visible = true
end
```

**`ns:HideWindow` current body** (Window.lua lines 412-415):
```lua
function ns:HideWindow()
    win:Hide()
    ns.db.window.visible = false
end
```

**`ns:RestoreWindowVisibility` current body** (Window.lua lines 420-427):
```lua
function ns:RestoreWindowVisibility()
    applySavedPosition()
    win:Show()
    applySoftHideState()
end
```

**Insertion rule (CONTEXT D-11):** Add `ns:NotifyWindowVisibilityChanged()` as the LAST line of each function, after all existing state mutations. Pattern:

```lua
function ns:ShowWindow()
    applySavedPosition()
    win:Show()
    softHidden = false
    win:SetAlpha(ns.db.window.alpha or 1.00)
    ns.db.window.visible = true
    ns:NotifyWindowVisibilityChanged()   -- NEW
end

function ns:HideWindow()
    win:Hide()
    ns.db.window.visible = false
    ns:NotifyWindowVisibilityChanged()   -- NEW
end

function ns:RestoreWindowVisibility()
    applySavedPosition()
    win:Show()
    applySoftHideState()
    ns:NotifyWindowVisibilityChanged()   -- NEW
end
```

**Explicit non-call-site (CONTEXT D-12):** `applySoftHideState` (Window.lua line 258) does NOT get a notify call. Soft-hide changes alpha only; `win:IsShown()` remains true; the engineering-truth label model is automatically correct without a notify call there.

---

### `Config.lua` — new `RegisterReferenceImage` function

**Analog:** `Config.lua` `RegisterChannelToggles` (lines 68-90) and `RegisterMacroSection` (line 222).

**`RegisterChannelToggles` signature + body shape** (Config.lua lines 68-70):
```lua
local function RegisterChannelToggles(category, layout, db)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Chat channels"))
    ...
end
```

**`RegisterMacroSection` signature** (Config.lua line 222):
```lua
local function RegisterMacroSection(category, layout, db)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Macros"))
    ...
end
```

**New function pattern — copy the `Register*` shape; takes `(category, layout)` only (no `db` — texture path is a hardcoded literal per CONTEXT D-02):**
```lua
local function RegisterReferenceImage(category, layout)
    local initializer = Settings.CreateElementInitializer(
        "TLHSymbolReferenceTemplate",
        { texturePath = "Interface\\AddOns\\TerribleLuraHelper\\reference.tga" }
    )
    layout:AddInitializer(initializer)
end
```

**Note on `category` parameter:** The function signature receives `category` for symmetry with the other `Register*` functions, even though this minimal body does not call `Settings.RegisterAddOnSetting` (which requires `category`). Consistent signature makes `ns:InitConfig`'s call-site uniform and avoids confusion if a future revision needs to attach search tags or a setting.

---

### `Config.lua` — `ns:InitConfig` call-site ordering

**Analog:** `ns:InitConfig` body (Config.lua lines 326-343).

**Current layout registration sequence** (Config.lua lines 336-339):
```lua
RegisterChannelToggles(category, layout, db)
RegisterWindowControls(category, layout, db)
RegisterMacroSection(category, layout, db)
RegisterCommandHelp(category, layout)
```

**Phase 6 insertion — `RegisterReferenceImage` becomes the FIRST call (CONTEXT D-03):**
```lua
RegisterReferenceImage(category, layout)        -- NEW: first = top of panel
RegisterChannelToggles(category, layout, db)
RegisterWindowControls(category, layout, db)
RegisterMacroSection(category, layout, db)
RegisterCommandHelp(category, layout)
```

**Rationale:** `layout:AddInitializer` insertion order equals display order in the vertical-layout Settings panel. First call = topmost element. No section header above the image — it stands alone as the visual anchor (CONTEXT D-03).

---

## Shared Patterns

### `Settings.CreateElementInitializer` call pattern
**Source:** `wow-ui-source` `Blizzard_SettingControls.lua` line 102 (`CreateSettingsListSectionHeaderInitializer`) and line 764 (`CreateSettingsButtonInitializer`)
**Apply to:** `RegisterReferenceImage` in `Config.lua`
```lua
-- Pattern: create a data table, pass template name + data to CreateElementInitializer,
-- receive an initializer object, then pass it to layout:AddInitializer.
local data = { name = name, tooltip = tooltip }
local initializer = Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", data)
layout:AddInitializer(initializer)
```

### `ns:` export function declaration style
**Source:** `Window.lua` lines 272-300 (the Phase 3 export block)
**Apply to:** `ns:NotifyWindowVisibilityChanged` in `Window.lua`
```lua
-- Pattern: function ns:Name() ... end  (no local, on the ns table, no upvalue capture)
function ns:SetWindowScale(value)
    if win then
        win:SetScale(value)
    end
end
```

### Early-exit guard pattern
**Source:** `Window.lua` `applySavedPosition` (lines 316-319) and the `ns:SetWindowAlpha` soft-hide guard (lines 280-283)
**Apply to:** `ns:NotifyWindowVisibilityChanged` body
```lua
-- Pattern: guard with nil-check + state-check before doing work
if win and not softHidden then
    win:SetAlpha(value)
end
-- Adapted for notify: guard with SettingsPanel existence + IsShown()
if SettingsPanel and SettingsPanel:IsShown() then
    SettingsInbound.RepairDisplay()
end
```

---

## No Analog Found

None. All four files have direct codebase or Blizzard-source analogs.

---

## Metadata

**Analog search scope:** `Window.lua`, `Config.lua`, `TerribleLuraHelper.toc`, `wow-ui-source/Interface/AddOns/Blizzard_Settings_Shared/`
**Files scanned:** 8 (4 project files + 4 Blizzard source files)
**Pattern extraction date:** 2026-05-09
