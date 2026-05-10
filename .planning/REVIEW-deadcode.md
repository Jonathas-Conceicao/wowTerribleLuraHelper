---
phase: post-milestone-polish
reviewed: 2026-05-09T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Core.lua
  - Macros.lua
  - Window.lua
  - Config.lua
findings:
  dead_code: 2
  unused: 3
  stale_comment: 0
  total: 5
status: cleanup_available
---

# Post-Milestone Polish: Dead Code / Unused Variables Review

**Reviewed:** 2026-05-09
**Depth:** standard (focused: dead code, unused variables, cleanup only)
**Files Reviewed:** 4
**Status:** cleanup_available — 5 low-severity findings; no bugs, no behavioral issues

## Summary

All four files are structurally sound. The three categories of findings are:

1. **`addonName` unused in two files** — declared in the `local addonName, ns = ...` vararg unpack but never referenced in Window.lua or Macros.lua.
2. **`category` parameter unused in two Config.lua helpers** — `RegisterReferenceImage` and `RegisterCommandHelp` both accept `(category, layout)` but only use `layout`.
3. **`ns:RegisterChatEvents` / `ns:UnregisterChatEvents` exported unnecessarily** — both are only ever called from within Window.lua's own OnShow/OnHide scripts; exporting them to `ns` exposes surface area with no consumer.

Zero stale comments found. All forward declarations in Window.lua are fully assigned and used. All other locals (`softHidden`, `clearTimer`, `positionApplied`, `inCombat`, `sequence`, `macrosPrintedThisSession`, `registrationDeferred`) are live. All constants (`MACROS`, `CHANNEL_PREFIX`, `LISTEN_DEFAULTS`, `SLOT_POS`, `CHAT_EVENTS`, `CHANNELS`, `SLASH_HELP`, `INACTIVITY_TIMEOUT`, `W`, `H`, `SLOT_SIZE`, `ICON_SIZE`) are referenced. `texturePath` in `RegisterReferenceImage` is intentionally preserved per AMEND-06-01 and not flagged.

---

## Findings

### DC-01: `addonName` unused in Window.lua

**File:** `Window.lua:1`
**Issue:** `local addonName, ns = ...` — `addonName` is unpacked but never referenced anywhere in the file. The file doesn't need the addon name (no `EventUtil.ContinueOnAddOnLoaded` call, no `ADDON_LOADED` guard).
**Recommendation:** Replace the first line with `local _, ns = ...` to make the intent explicit.

```lua
-- Before
local addonName, ns = ...

-- After
local _, ns = ...
```

---

### DC-02: `addonName` unused in Macros.lua

**File:** `Macros.lua:1`
**Issue:** Same as DC-01. `addonName` is unpacked but never used. Macros.lua has no event registration that requires the addon name.
**Recommendation:** Replace with `local _, ns = ...`.

```lua
-- Before
local addonName, ns = ...

-- After
local _, ns = ...
```

---

### DC-03: `category` parameter unused in `RegisterReferenceImage`

**File:** `Config.lua:77`
**Issue:** `local function RegisterReferenceImage(category, layout)` — `category` is accepted but the function body only calls `layout:AddInitializer(...)`. `Settings.CreateElementInitializer` does not take a category argument.
**Recommendation:** Drop `category` from the signature (and update the call site at line 427 accordingly) or rename to `_` if keeping the signature consistent with the other helpers is preferred for readability.

```lua
-- Option A: drop the parameter
local function RegisterReferenceImage(layout)
    ...
end
-- call site:
RegisterReferenceImage(layout)

-- Option B: mark it unused (keeps call-site symmetry)
local function RegisterReferenceImage(_, layout)
    ...
end
```

---

### DC-04: `category` parameter unused in `RegisterCommandHelp`

**File:** `Config.lua:402`
**Issue:** `local function RegisterCommandHelp(category, layout)` — `category` is accepted but the function body only calls `layout:AddInitializer(...)`. Same pattern as DC-03.
**Recommendation:** Same options as DC-03 — drop or mark with `_`.

```lua
-- Option A: drop the parameter
local function RegisterCommandHelp(layout)
    ...
end
-- call site:
RegisterCommandHelp(layout)

-- Option B: mark it unused
local function RegisterCommandHelp(_, layout)
    ...
end
```

---

### DC-05: `ns:RegisterChatEvents` and `ns:UnregisterChatEvents` exported unnecessarily

**File:** `Window.lua:420`, `Window.lua:426`
**Issue:** Both functions are defined as `function ns:RegisterChatEvents()` / `function ns:UnregisterChatEvents()` (exported to the shared namespace), but they are only ever called from within Window.lua itself — from the `win:SetScript("OnShow", ...)` and `win:SetScript("OnHide", ...)` closures at lines 170 and 173. No other file calls them. Exporting them to `ns` adds public surface area with no consumer and could mislead a future maintainer into thinking they're safe to call from outside (they're not — they bypass the OnShow/OnHide gating contract).
**Recommendation:** Convert both to local functions.

```lua
-- Before
function ns:RegisterChatEvents()
    for _, ev in ipairs(CHAT_EVENTS) do
        chatFrame:RegisterEvent(ev)
    end
end

function ns:UnregisterChatEvents()
    for _, ev in ipairs(CHAT_EVENTS) do
        chatFrame:UnregisterEvent(ev)
    end
end

-- After
local function RegisterChatEvents()
    for _, ev in ipairs(CHAT_EVENTS) do
        chatFrame:RegisterEvent(ev)
    end
end

local function UnregisterChatEvents()
    for _, ev in ipairs(CHAT_EVENTS) do
        chatFrame:UnregisterEvent(ev)
    end
end
```

Update the OnShow/OnHide call sites at lines 170 and 173 to drop the `ns:` prefix.

Note: also add `RegisterChatEvents` and `UnregisterChatEvents` to the forward-declaration line 60 (or move the function definitions above the `CreateWindow` function that references them, since they don't depend on `win` or `slotFrames`).

---

## Not Flagged (Confirmed Live or Intentional)

- `addonName` in **Core.lua** — used at line 43 (`if name ~= addonName`) and in **Config.lua** — used at line 418 (`EventUtil.ContinueOnAddOnLoaded(addonName, ...)`). Both are active.
- `self` in `chatFrame:SetScript("OnEvent", function(self, event, msg)` — not used in the body, but `_` would require changing to `function(_, event, msg)`. This is idiomatic WoW Lua boilerplate and very low priority; not flagged as it doesn't affect correctness.
- Forward declarations `win`, `slotFrames`, `lockBtn`, `FillSlot`, `ClearAll`, `ScheduleClear`, `ManualClear`, `applyLockState`, `applySavedPosition`, `persistPosition`, `applySoftHideState` — all assigned and used.
- `texturePath` in `RegisterReferenceImage`'s `data` table — intentionally kept per AMEND-06-01.
- `ns.SLASH_HELP` — consumed by `Core.lua:PrintHelp`; cross-file shared table, not dead.

---

_Reviewed: 2026-05-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard (dead-code focused)_
