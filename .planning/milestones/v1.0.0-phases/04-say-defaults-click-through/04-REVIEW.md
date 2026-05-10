---
phase: 04-say-defaults-click-through
reviewed: 2026-05-09T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - Window.lua
  - Core.lua
  - Config.lua
findings:
  critical: 0
  warning: 1
  info: 1
  total: 2
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-05-09
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three files reviewed covering the complete Phase 4 surface: click-through (`win:EnableMouse(not locked)` in `applyLockState`), SAY-centric first-run defaults in Core.lua, and the SAFE-06 fix in Config.lua. Hard constraints from CLAUDE.md are all satisfied — no `SendChatMessage`, no `msg` indexing, no `COMBAT_LOG_EVENT_UNFILTERED`, `applySoftHideState` correctly uses `SetAlpha(0)` exclusively. The SAFE-06 grep returns zero matches in `*.lua` files. The `win:EnableMouse(not locked)` placement is correct, and the intentional design decisions (D-01 through D-12) are all honored.

One warning and one info item were found, both in `Config.lua`. Neither is a correctness bug at runtime for the typical user path, but the warning will surface as a user-visible defect the first time any user clicks "Restore Defaults" in the Settings panel.

## Warnings

### WR-01: `RegisterAddOnSetting` default for `TLH_MACRO_CHANNEL` still hardcodes `"RAID"` — should be `"SAY"` after Phase 4

**File:** `Config.lua:234`

**Issue:** `Settings.RegisterAddOnSetting` accepts a `defaultValue` argument as its last positional parameter. This value is what the Settings framework restores when the user clicks the "Restore Defaults" button in Options > AddOns > TerribleLuraHelper. Phase 4 changed the canonical first-run default for `macroChannel` from `"RAID"` to `"SAY"` (Core.lua line 65 and line 103). The `RegisterAddOnSetting` call on Config.lua line 227-235 still passes `"RAID"` as the default, creating a divergence: fresh installs will have `db.macroChannel = "SAY"` (correct), but if the user ever clicks "Restore Defaults" the Settings framework will write `"RAID"` back to `db.macroChannel` and trigger `ns:OnMacroChannelChanged("RAID")`, which will rebuild all five `TLH_*` macros with `/raid` bodies — the opposite of the Phase 4 intent.

This is not triggered by normal usage (no one clicks Restore Defaults casually), but it is a user-facing defect that produces silent, incorrect macro bodies without any warning.

**Fix:**
```lua
local setting = Settings.RegisterAddOnSetting(
    category,
    "TLH_MACRO_CHANNEL",
    "macroChannel",
    db,
    Settings.VarType.String,
    "Macro target",
    "SAY"   -- was "RAID"; changed to match Phase 4 default (SCAF-14)
)
```

## Info

### IN-01: Dropdown tooltip says "/raid is the default" — stale after Phase 4 changed default to `/s`

**File:** `Config.lua:251`

**Issue:** The `Settings.CreateDropdown` tooltip string reads: _"The chat channel each TLH_* macro sends raid markers to. /raid is the default and works during raid encounters..."_ After Phase 4, the first-run default is `macroChannel = "SAY"` (`/s`). The phrase "/raid is the default" is now factually incorrect for new installs. The rest of the sentence ("works during raid encounters") is still true and useful as descriptive copy for the `/raid` option — the problem is specifically the words "is the default".

**Fix:**
```lua
"The chat channel each TLH_* macro sends raid markers to. /s works anywhere and is the default; /raid works during raid encounters; /rw requires raid leader/assist; /i sends to instance/dungeon chat."
```

---

_Reviewed: 2026-05-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
