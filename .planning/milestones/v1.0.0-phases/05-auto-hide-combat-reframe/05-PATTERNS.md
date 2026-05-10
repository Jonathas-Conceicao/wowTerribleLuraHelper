# Phase 5: Auto-Hide Combat Reframe - Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 2 (both modified, none created)
**Analogs found:** 6 / 6

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `Window.lua` (Lua-locals block) | state | event-driven | `TerribleBuffTracker/Display.lua` line 12 | exact |
| `Window.lua` (combatFrame) | event listener | event-driven | `TerribleBuffTracker/Display.lua` lines 348-354 | exact |
| `Window.lua` (inCombat seed) | init | request-response | `Macros.lua` lines 46-49 | role-match |
| `Window.lua` (applySoftHideState condition) | logic | event-driven | `Window.lua` lines 230-238 (self, extended) | self-extension |
| `Window.lua` (SAFE-05 block-comment) | comment | — | `Core.lua` lines 9-13 (SAFE-06 comment) | style-match |
| `Config.lua` (auto-hide label + tooltip) | config | request-response | `Config.lua` lines 144-162 (self, modified) | self-modification |

## Pattern Assignments

### `Window.lua` — Lua-local flag declaration (for `inCombat`)

**Analog:** `TerribleBuffTracker/Display.lua` line 12 AND `Window.lua` lines 46-52

The new `inCombat` flag joins the existing in-memory state block. Pattern: declared at module top, no initializer args, mutated by event handlers, read by visibility logic.

**Existing Lua-locals block** (`Window.lua` lines 46-52):
```lua
local sequence = {}
local clearTimer
local positionApplied = false -- saved position is applied on first show only
-- Phase 3 / D-18..D-22: soft-hide state. true while autoHide=on AND #sequence==0.
-- Window stays visible (no Hide()) but with alpha=0; chat events stay registered
-- so the next slot fill can reveal it via applySoftHideState().
local softHidden = false
```

**Sibling-addon exact match** (`TerribleBuffTracker/Display.lua` line 12):
```lua
local inCombat = false
```

**Placement instruction:** Add `local inCombat = false` immediately after `local softHidden = false` (line 52). Optionally add a one-line comment explaining it is seeded at frame creation time — see D-02 pattern below.

---

### `Window.lua` — `combatFrame` creation + permanent event registration

**Analog:** `TerribleBuffTracker/Display.lua` lines 347-354

This is the exact pattern Phase 5 requires: `InCombatLockdown()` seed, `CreateFrame`, register BOTH regen events, handler updates the cached flag and calls the re-evaluation function. The only difference: Phase 5 calls `applySoftHideState()` where TerribleBuffTracker calls `ns:UpdateDisplay()`.

**Sibling-addon pattern** (`TerribleBuffTracker/Display.lua` lines 347-354):
```lua
-- Combat tracking for visibility setting
inCombat = InCombatLockdown()
local combatFrame = CreateFrame("Frame", nil, UIParent)
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(_, event)
    inCombat = (event == "PLAYER_REGEN_DISABLED")
    ns:UpdateDisplay()
end)
```

**Phase 5 adaptation** — replace `ns:UpdateDisplay()` with individual set + call, to be explicit about which edge sets which value (matches D-03 wording):
```lua
-- Permanent combat listener — seeds inCombat at creation and tracks both
-- edges for the addon's lifetime. NOT a fire-once retry (unlike Macros.lua's
-- regenFrame which unregisters after firing). Never unregistered.
inCombat = InCombatLockdown()
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    else
        inCombat = false
    end
    applySoftHideState()
end)
```

**Placement instruction:** Inside `CreateWindow()`, immediately after `applyLockState()` at line 174 (last line of the function body). The combatFrame is permanent; it does not belong inside OnShow/OnHide.

**NEAR-MISS — do NOT copy** (`Macros.lua` lines 86-94):
```lua
local regenFrame = CreateFrame("Frame")
regenFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")   -- ← fire-once unregister
        if registrationDeferred then
            ns:RegisterMacros()
        end
    end
end)
```
This unregisters after firing — the opposite of what Phase 5 needs. The two frames are architecturally independent and must remain so.

---

### `Window.lua` — `inCombat = InCombatLockdown()` initial seed

**Analog:** `Macros.lua` lines 46-49 (same API call, different purpose)

**Macros.lua guard pattern** (lines 46-49 — role-match, NOT copied directly):
```lua
if InCombatLockdown() then
    registrationDeferred = true
    return false
end
```

**Phase 5 usage** is a seed, not a guard. The seed is embedded in the `combatFrame` block above (line `inCombat = InCombatLockdown()` immediately before `CreateFrame`). This handles `/reload` mid-combat where `PLAYER_REGEN_DISABLED` never fires because the player was already in combat at load time.

---

### `Window.lua` — `applySoftHideState` condition extension

**Analog:** `Window.lua` lines 230-238 (self-extension — single line change)

**Existing implementation** (`Window.lua` lines 229-238):
```lua
applySoftHideState = function()
    if ns.db.window.autoHide and #sequence == 0 then
        softHidden = true
        win:SetAlpha(0)
    else
        softHidden = false
        win:SetAlpha(ns.db.window.alpha or 1.00)
    end
end
```

**Phase 5 change:** One token added to the condition. Everything else is identical — else-branch unchanged, `SetAlpha(0)` unchanged, `softHidden` flag unchanged:
```lua
if ns.db.window.autoHide and #sequence == 0 and inCombat then
```

The SAFE-05 block-comment (see next section) goes immediately above the `applySoftHideState = function()` line.

---

### `Window.lua` — SAFE-05 block-comment style

**Analog:** `Core.lua` lines 9-13 (SAFE-06 comment — same style and purpose)

**SAFE-06 comment in Core.lua** (lines 9-13):
```lua
-- Per-channel defaults for fresh-install AND backfill (SCAF-13, SCAF-15, SAFE-06).
-- SAY=true is the v1.0.0 default; all other channels off until user opts in.
-- SAFE-06: backfill MUST use `if db.X == nil then db.X = DEFAULT end` — never
-- the `or` shorthand, which silently clobbers intentional `false` values.
-- See .planning/research/PITFALLS.md DB-1 for the full rationale.
```

**Phase 5 SAFE-05 comment** — same block-comment style, placed immediately above `applySoftHideState = function()`. Must convey three facts (D-09): (1) soft-hide uses `SetAlpha(0)` only, (2) NEVER `win:Hide()` — that fires OnHide which unregisters chat events, (3) origin reference. Draft wording:
```lua
-- SAFE-05: soft-hide MUST use SetAlpha(0) exclusively — NEVER win:Hide().
-- win:Hide() fires OnHide which calls ns:UnregisterChatEvents(), breaking the
-- AMEND-01 invariant: chat events must stay registered while the window is
-- shown (even at alpha=0) so the next slot fill can reveal it.
-- Origin: .planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-VERIFICATION.md (AMEND-01)
```

---

### `Config.lua` — auto-hide checkbox label + tooltip

**Analog:** `Config.lua` lines 144-162 (self-modification — two string values change)

**Existing auto-hide checkbox registration** (`Config.lua` lines 143-162):
```lua
-- (2c) Auto-hide checkbox — UI-SPEC §3.4
do
    local setting = Settings.RegisterAddOnSetting(
        category,
        "TLH_AUTO_HIDE",
        "autoHide",
        db.window,
        Settings.VarType.Boolean,
        "Auto-hide when empty",          -- ← label: 6th argument; CHANGE THIS
        false
    )
    setting:SetValueChangedCallback(function(_, value)
        ns:OnAutoHideChanged(value)
    end)
    Settings.CreateCheckbox(
        category,
        setting,
        "When enabled, the helper window stays visible but invisible while no runes are showing. The next message reveals it."
        -- ↑ tooltip: 3rd argument to CreateCheckbox; CHANGE THIS
    )
end
```

**Phase 5 changes (CFG-14, D-06, D-07):**

Label (6th arg to `Settings.RegisterAddOnSetting`) — exact text locked by D-06:
```lua
"Auto-hide when empty in combat"
```

Tooltip (3rd arg to `Settings.CreateCheckbox`) — Claude's discretion per D-07; must preserve three semantic facts: out-of-combat = visible reminder, in-combat = hidden when empty, reappears on next marker:
```lua
"When on, the helper window stays visible while you're out of combat so you remember the toggle is on. In combat, it hides while the rune sequence is empty and reappears automatically when the next marker arrives."
```

---

## Shared Patterns

### Soft-hide invariant (AMEND-01 / SAFE-05)
**Source:** `Window.lua` lines 229-238 (`applySoftHideState`) + `Window.lua` lines 376-379 (`ns:ShowWindow`)
**Apply to:** Phase 5's `combatFrame` OnEvent handler — must call `applySoftHideState()`, never `win:Hide()` directly.

```lua
-- From ns:ShowWindow (lines 376-379) — correct pattern for exiting soft-hide:
softHidden = false
win:SetAlpha(ns.db.window.alpha or 1.00)
```

### chatFrame vs combatFrame architecture
**Source:** `Window.lua` lines 331-365
`chatFrame` is permanent but its events are registered/unregistered by `OnShow`/`OnHide`. `combatFrame` (Phase 5) is permanent AND its events stay registered for the addon's entire lifetime — no on/off switch. These two frames coexist independently.

**chatFrame creation pattern** (`Window.lua` lines 331-333):
```lua
local chatFrame = CreateFrame("Frame")
chatFrame:SetScript("OnEvent", function(self, event, msg)
    -- handler body
end)
```

Phase 5's `combatFrame` uses the same `CreateFrame("Frame")` shape (no name, no parent — matches chatFrame, which also omits UIParent).

---

## No Analog Found

None. All patterns have direct analogs in the codebase.

---

## Metadata

**Analog search scope:** `Window.lua`, `Macros.lua`, `Config.lua`, `Core.lua`, `TerribleBuffTracker/Display.lua`
**Files read:** 5
**Pattern extraction date:** 2026-05-09
