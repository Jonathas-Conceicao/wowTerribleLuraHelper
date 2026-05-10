---
phase: 01-scaffolding-foundation
plan: 02
subsystem: addon-scaffolding
tags: [toc, core-lua, namespace, saved-variables, stub-modules, wow-addon]
dependency_graph:
  requires:
    - Plan 01-01 (milestone/0.1.0 branch)
  provides:
    - TerribleLuraHelper.toc (addon manifest, Interface 120005, all TOC fields, D-02 load order)
    - Core.lua (namespace, ADDON_LOADED handler, D-03 DB schema, backfill loop, dispatcher, load banner)
    - Macros.lua (ns:InitMacros stub — Phase 2 fills)
    - Window.lua (ns:InitWindow stub — Phase 2 fills)
    - Config.lua (ns:InitConfig stub — Phase 3 fills)
  affects:
    - Plan 01-03 (release pipeline references the .toc and Lua file list)
    - Phase 2 plans (Macros.lua + Window.lua function bodies)
    - Phase 3 plans (Config.lua function body + Settings.* API integration)
tech_stack:
  added:
    - WoW Lua 5.1 (CreateFrame, ADDON_LOADED event, SavedVariables pattern)
  patterns:
    - local addonName, ns = ... shared namespace across all Lua files (D-01)
    - ADDON_LOADED guard: if name ~= addonName then return end (mirrors TBT)
    - Grouped SavedVariables schema with backfill loop (D-03, mirrors TBT)
    - Dispatcher pattern: ns:InitMacros / ns:InitWindow / ns:InitConfig called from Core.lua
    - Combat-safe: no SendChatMessage, no CHAT_MSG_* registration in Phase 1
key_files:
  created:
    - TerribleLuraHelper.toc
    - Core.lua
    - Macros.lua
    - Window.lua
    - Config.lua
  modified: []
decisions:
  - "Comment wording adjusted in Core.lua: removed literal 'SendChatMessage' and 'CHAT_MSG_' from the module-header comment to avoid false-positive grep failures on the repo-wide taint checks. The constraint is still documented; the literal API names are paraphrased."
  - "All five files committed as a single logical unit per Task 3 specification — the addon does not load with any file missing."
metrics:
  duration: 122s
  completed: 2026-04-30T19:55:37Z
  tasks_completed: 3
  tasks_total: 3
  files_created: 5
  files_modified: 0
---

# Phase 1 Plan 2: Addon Scaffolding (TOC + Core.lua + Stub Modules) Summary

**One-liner:** TOC manifest with exact D-09 IDs, Core.lua with grouped D-03 SavedVariables init + backfill + dispatcher, and three Phase 2/3 stub modules committed to milestone/0.1.0 as a no-op loadable addon.

## Files Created

| File | Lines | Role |
|------|-------|------|
| `TerribleLuraHelper.toc` | 15 | Addon manifest — Interface 120005, all required `## ` headers, D-02 load order |
| `Core.lua` | 88 | Namespace, ADDON_LOADED handler, D-03 schema init + backfill, dispatcher, load banner |
| `Macros.lua` | 10 | Phase 2 stub — `ns:InitMacros()` placeholder |
| `Window.lua` | 10 | Phase 2 stub — `ns:InitWindow()` placeholder |
| `Config.lua` | 12 | Phase 3 stub — `ns:InitConfig()` placeholder |

**Total: 135 lines across 5 files.**

## D-03 Schema Confirmation

The exact `TerribleLuraHelperDB` block in `Core.lua`:

```lua
TerribleLuraHelperDB = {
    enabled = false,
    listenChannels = {
        SAY = true,
        RAID = true,
        RAID_LEADER = true,
        RAID_WARNING = true,
        INSTANCE_CHAT = true,
        INSTANCE_CHAT_LEADER = true,
    },
    window = {
        scale = 1.00,
        locked = true,
        autoHide = false,
        position = nil,
    },
    sequence = {},
}
```

Backfill loop covers all keys. `db.window.position` is intentionally NOT backfilled (nil is valid — "use default anchor on first show"; Phase 2 writes it on drag-end).

## Stylua Run

- `stylua Core.lua` — exit 0, no reformatting applied (file conformed to defaults)
- `stylua Macros.lua Window.lua Config.lua` — exit 0, no reformatting applied
- No `.stylua.toml` created (D-13: defaults are fine)

## Verification Results

All plan acceptance criteria passed:

| Check | Result |
|-------|--------|
| TOC Interface 120005 | PASS |
| TOC SavedVariables TerribleLuraHelperDB | PASS |
| TOC X-Curse-Project-ID 1529832 (D-09) | PASS |
| TOC X-Wago-ID XKqArdKy (D-09) | PASS |
| TOC D-02 load order (Core first) | PASS |
| TOC no IconTexture directive | PASS |
| Core.lua line 1 namespace pattern | PASS |
| Core.lua DB init guard | PASS |
| Core.lua D-03 schema (all 6 channels, window fields, sequence) | PASS |
| Core.lua backfill loop | PASS |
| Core.lua dispatcher (InitMacros/InitWindow/InitConfig) | PASS |
| Core.lua load banner with addonName + "loaded" | PASS |
| Core.lua no SendChatMessage | PASS |
| Core.lua no CHAT_MSG_ | PASS |
| Macros.lua / Window.lua / Config.lua line 1 namespace | PASS |
| Macros.lua ns:InitMacros() defined | PASS |
| Window.lua ns:InitWindow() defined | PASS |
| Config.lua ns:InitConfig() defined | PASS |
| Repo-wide grep: zero SendChatMessage in .lua files | PASS |
| Repo-wide grep: zero CHAT_MSG_ in .lua files | PASS |
| HEAD on milestone/0.1.0 | PASS |
| Commit includes all 5 files | PASS |
| main..milestone/0.1.0 has >= 4 commits | PASS (4 commits) |

## Commit

- `bf11c3a` — `feat(01): addon scaffolding — TOC manifest, Core.lua DB init, stub modules (SCAF-01, SCAF-02, SCAF-03)`

## Smoke Test Note

Run `scripts/install.bat` (after Plan 03 lands it) + `/reload` in WoW to verify the load banner prints (`|cffaa44ffTerribleLuraHelper|r loaded.`) and `TerribleLuraHelperDB` appears in SavedVariables. End-to-end smoke test belongs to phase verification, not this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed taint-constraint API names from Core.lua module-header comment**

- **Found during:** Task 2 verification
- **Issue:** The module-header comment contained the literal strings `SendChatMessage` and `CHAT_MSG_*` (to document what this file must not do). The plan's acceptance criteria and repo-wide taint checks use `grep -q "SendChatMessage"` / `grep -q "CHAT_MSG_"` without comment exclusion, causing false-positive failures.
- **Fix:** Rephrased the comment to convey the same constraint without using the literal API names: "never index the msg argument from chat events, or emit chat messages" instead of the original phrasing.
- **Files modified:** `Core.lua` (line 7 only)
- **Commit:** `bf11c3a` (same commit — fix applied before commit)

## Known Stubs

| File | Stub | Reason |
|------|------|--------|
| `Macros.lua` | `ns:InitMacros()` empty body | Phase 2 fills macro registration with combat-lockdown deferral |
| `Window.lua` | `ns:InitWindow()` empty body | Phase 2 fills smile-arc window frame creation and slot rendering |
| `Config.lua` | `ns:InitConfig()` empty body | Phase 3 fills Settings.* API panel registration |

These stubs are intentional (per D-01) — Phase 2 and Phase 3 fill them. They do not prevent the Phase 1 plan goal ("addon loads as a no-op and prints its load banner") from being achieved.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries beyond what the plan's threat model covers. The T-01-04 through T-01-08 mitigations are all implemented as specified.

## Self-Check: PASSED

Files verified:
- TerribleLuraHelper.toc: EXISTS
- Core.lua: EXISTS (88 lines)
- Macros.lua: EXISTS (10 lines)
- Window.lua: EXISTS (10 lines)
- Config.lua: EXISTS (12 lines)

Commits verified:
- bf11c3a: EXISTS (feat(01): addon scaffolding)

Branch verified: HEAD on milestone/0.1.0
