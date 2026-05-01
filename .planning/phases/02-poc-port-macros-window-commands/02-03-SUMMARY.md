---
phase: 02-poc-port-macros-window-commands
plan: "03"
subsystem: slash-commands-state-machine
tags: [slash-commands, state-machine, dispatcher, taint-safe, phase-2-close]
dependency_graph:
  requires:
    - 02-01-SUMMARY.md
    - 02-02-SUMMARY.md
  provides:
    - "ns:Enable"
    - "ns:Disable"
    - "ns:PrintHelp"
    - "ns:HandleSlashCommand"
    - "SLASH_LURA1 = /lura"
    - "SLASH_TLH1 = /tlh"
    - "SlashCmdList[LURA] / SlashCmdList[TLH]"
  affects:
    - "Phase 3 / CFG-* (will replace the /lura config stub with Settings.OpenToCategory(category:GetID()))"
    - "Phase 3 / CFG-09 (slash command help block in panel mirrors ns:PrintHelp output)"
tech_stack:
  added: []
  patterns:
    - dual-name-slash-registration
    - whitespace-tolerant-arg-parser
    - closed-set-literal-dispatch
    - idempotent-state-edges
    - color-coded-chat-help
key_files:
  created: []
  modified:
    - Core.lua
decisions:
  - "D-23 (mid-combat enable): ns:Enable defers mid-combat registration to ns:ShowWindow which calls ns:RegisterChatEvents() if InCombatLockdown() and ns.db.enabled — symmetric handoff, no duplicate logic in Core.lua."
  - "D-24 (hide wipes): ns:Disable runs UnregisterChatEvents → WipeSequence → HideWindow in that order; flag flip happens first so the next PLAYER_REGEN_DISABLED can't re-register."
  - "D-25 (bare toggle): /lura with no arg is a pure on/off toggle on db.enabled — no 3-state cycle, no IsWindowShown check (the flag is the source of truth)."
  - "D-26 (alias): /tlh is a separate slash-name namespace (SLASH_TLH1) routing to the same ns:HandleSlashCommand — full alias, not a SLASH_LURA2 variant."
  - "T-SLASH-PARSER mitigation: parser uses ONLY (rawArg or ''):lower():match('^%s*(%S*)') against a closed set of literals (show/hide/help/config/''); no loadstring, no setfenv, no _G[arg]."
metrics:
  duration_min: 12
  completed: "2026-04-30"
  tasks: 2
  files_modified: 1
---

# Phase 2 Plan 3: Slash Commands & State Machine Summary

Final piece of the Phase 2 POC port — the user-facing command surface that drives the show/hide/wipe state machine per D-23..D-26. Closes Phase 2 with /lura-only visibility (WIN-04) and the new "/lura hide = disable processing entirely" semantics that the POC never had.

## What Was Built

Four new `ns.*` exports on Core.lua plus two slash-name registrations (LURA, TLH), all routing through a single dispatcher. Total addition: 70 lines, single file (Core.lua).

### New `ns.*` surface (Core.lua)

| Export | Calls | Role |
|--------|-------|------|
| `ns:Enable()` | `ns:ShowWindow()` (which itself registers chat events mid-combat per D-23) | Sets `db.enabled = true`, shows window. |
| `ns:Disable()` | `ns:UnregisterChatEvents()`, `ns:WipeSequence()`, `ns:HideWindow()` | Sets `db.enabled = false`, full wipe per D-24. |
| `ns:PrintHelp()` | `print` ×6 with WoW color codes | Emits the 6-line slash command help block. |
| `ns:HandleSlashCommand(rawArg)` | `ns:Enable` / `ns:Disable` / `ns:PrintHelp` / stub print / toggle | Parses `rawArg` and dispatches to the appropriate state-machine function. |

### Slash registration

```lua
SLASH_LURA1 = "/lura"
SLASH_TLH1  = "/tlh"
SlashCmdList["LURA"] = function(arg) ns:HandleSlashCommand(arg) end
SlashCmdList["TLH"]  = function(arg) ns:HandleSlashCommand(arg) end
```

Two separate slash-name namespaces (LURA, TLH) routing to the same handler. Matches TBT's `SLASH_TERRIBLEBUFFTRACKER1/2` pattern (TBT/Core.lua:114-115) inverted — TBT uses one name with two slash strings; we use two names with one slash string each. Both patterns are equivalent for the user; the two-name form makes `/tlh` fully independent and self-documenting.

## Slash Command Surface (5 subcommands + 1 alias)

| Input | Handler | Effect | db.enabled before → after | Window | Chat events |
|-------|---------|--------|---------------------------|--------|-------------|
| `/lura show` | `ns:Enable()` | Enable + show | `*` → `true` | shown | registered if combat (D-23); auto on next PLAYER_REGEN_DISABLED otherwise |
| `/lura hide` | `ns:Disable()` | Disable + wipe | `*` → `false` | hidden | unregistered + sequence wiped (D-24) |
| `/lura help` | `ns:PrintHelp()` | Help text | unchanged | unchanged | unchanged |
| `/lura config` | `print("Config panel lands in Phase 3.")` | Stub print | unchanged | unchanged | unchanged |
| `/lura` (bare) | toggle on `db.enabled` (D-25) | Pure on/off | flipped | shown if enabled | registered if combat+enabled |
| Unrecognized | `print` warning + suggest help | No state change | unchanged | unchanged | unchanged |
| `/tlh ...` | full alias, identical dispatch (D-26) | Same as `/lura ...` | — | — | — |

Parser:
```lua
local cmd = (rawArg or ""):lower():match("^%s*(%S*)") or ""
```
Whitespace-tolerant, case-insensitive, `nil`-safe — closed-set literal compare against `"show"`, `"hide"`, `"help"`, `"config"`, `""`.

## Help Block Output (CMD-07 / UI-SPEC §5.4)

Six chat lines, color-coded:

```
|cffaa44ffTerribleLuraHelper|r commands:
  |cffffd700/lura show|r       Enable + show window
  |cffffd700/lura hide|r       Disable + hide window
  |cffffd700/lura config|r     Open Options > AddOns > TLH (Phase 3)
  |cffffd700/lura help|r       Show this help
  |cffffd700/lura|r            Toggle enabled/disabled
|cffffd700/tlh|r is an alias for |cffffd700/lura|r with the same subcommands.
```

Hard-coded literals only — no variable interpolation, no DB values, no user input concatenation (T-PRINT-FORMAT). `print` is Blizzard's chat-frame `AddMessage` shim, NOT `SendChatMessage` (SAFE-01 unaffected).

## State Edge Verification (D-23..D-26)

### `ns:Enable` flow (the show path)
```
ns.db.enabled := true
ns:ShowWindow()
  └─ applySavedPosition() (first show only)
  └─ win:Show()
  └─ if ns.db.enabled and InCombatLockdown() then ns:RegisterChatEvents() (D-23)
```
Mid-combat handoff lives entirely inside `ns:ShowWindow` (Window.lua:320-322); Core.lua doesn't duplicate the combat check.

### `ns:Disable` flow (the hide path; D-24)
```
ns.db.enabled := false                    -- flag first so PLAYER_REGEN_DISABLED skips re-register
ns:UnregisterChatEvents()                 -- idempotent (Blizzard returns silently for unregistered events)
ns:WipeSequence()                         -- wipe sequence + clear slot text + cancel timer (calls ManualClear)
ns:HideWindow()                           -- win:Hide() only
```
Order matters — flag flip first, registration teardown second. Even if a chat event fires between the unregister call and combat-frame's PLAYER_REGEN_ENABLED handler, it'd be filtered by `db.enabled == false` (which the combat frame in Window.lua reads) — flag-and-register stay in sync (T-FLAG-DESYNC mitigation).

### Bare `/lura` toggle (D-25)
```
if ns.db.enabled then ns:Disable() else ns:Enable() end
```
Pure on/off based on the flag. No `IsWindowShown()` consultation — the flag is the source of truth, the window is a consequence.

## 02-02 ns.* Surface Consumed

Verified each call site against the 02-02 export list:

| 02-02 export | Used by |
|--------------|---------|
| `ns:ShowWindow` | `ns:Enable` (Core.lua:97) |
| `ns:HideWindow` | `ns:Disable` (Core.lua:105) |
| `ns:WipeSequence` | `ns:Disable` (Core.lua:104) |
| `ns:RegisterChatEvents` | (indirectly via `ns:ShowWindow`'s mid-combat branch — Window.lua owns the wiring; Core.lua does not call it directly) |
| `ns:UnregisterChatEvents` | `ns:Disable` (Core.lua:103) |
| `ns:IsWindowShown` | (NOT used — bare-toggle uses `db.enabled` per D-25; export remains available for Phase 3 if needed) |
| `ns:ToggleLocked` | (NOT used — button-driven only in Phase 2; available for the Phase 3 panel "Lock/Unlock window" button per CFG-07) |
| `ns:InitWindow` | Core.lua's ADDON_LOADED dispatcher (already wired in Phase 1, line 78) |

`ns:IsWindowShown` and `ns:ToggleLocked` are intentionally unused by Core.lua — they're exported for Phase 3's config panel, not the slash dispatcher.

## Phase 1 Anchors Untouched

Verified intact:
- ADDON_LOADED handler (lines 12-88)
- Grouped DB schema with backfill loop (lines 19-71)
- Dispatcher calls: `ns:InitMacros()`, `ns:InitWindow()`, `ns:InitConfig()` (lines 74-82)
- Load banner: `print("|cffaa44ffTerribleLuraHelper|r loaded.")` (line 84)
- 02-01 schema amendments: `alpha = 1.00` default + backfill (lines 35, 69-71)
- Channel list: `INSTANCE_CHAT_LEADER = true` (line 28)

## Threat Model Compliance

All five threats from `<threat_model>` upheld:

| Threat | Disposition | Verification |
|--------|-------------|--------------|
| T-SLASH-PARSER | mitigate | Parser uses only `:lower():match("^%s*(%S*)")`. Closed-set literal compare. `! grep -qE "loadstring\|setfenv\|loadfile" Core.lua` ✓ |
| T-MSG-OPAQUE | n/a here | Core.lua has zero `CHAT_MSG_*` handlers; chat pipeline is exclusively in Window.lua. `! grep -qE "CHAT_MSG_" Core.lua` ✓ |
| T-COMBAT-LOCKDOWN | accept | Enable/Disable are pure Lua state changes + Show/Hide; none restricted by Blizzard combat lockdown. |
| T-DISABLE-IDEMPOTENCY | accept | All three Disable sub-calls are idempotent — repeated `/lura hide` produces no errors. |
| T-FLAG-DESYNC | mitigate | Flag flip before unregister; combat frame reads flag at PLAYER_REGEN_DISABLED — stay in sync. |
| T-PRINT-FORMAT | accept | Help block is hard-coded literals only. No user input concatenation. |

## Acceptance Criteria — All Pass

Plan-defined grep suite (39 checks): all PASS.

Prompt's 8 acceptance criteria:

1. **stylua clean**: `stylua --check Core.lua Macros.lua Window.lua Config.lua` → exit 0 ✓
2. **No SendChatMessage repo-wide**: `grep -rE 'SendChatMessage' *.lua` → 0 matches ✓
3. **No msg ops in Core.lua**: `grep -nE 'msg:(gsub|match|find|len|sub|rep)|#msg|msg \.\.|\.\. msg' Core.lua` → 0 matches ✓ (slash arg is `rawArg`/`arg`, never named `msg`)
4. **SLASH_LURA1 + SLASH_TLH1 present**: `grep -nE '^SLASH_LURA1|^SLASH_TLH1' Core.lua` → 2 matches ✓
5. **SlashCmdList LURA + TLH**: `grep -nE 'SlashCmdList\["LURA"\]|SlashCmdList\["TLH"\]' Core.lua` → 2 matches ✓
6. **ns:InitWindow wired**: `grep -n 'ns:InitWindow' Core.lua` → 2 matches (header comment + dispatcher call at line 78) ✓
7. **Config.lua unchanged**: still the Phase 1 stub with `function ns:InitConfig() end` ✓
8. **Commit at HEAD on milestone branch**: `git log --oneline milestone/0.1.0 ^main` shows `8b44b6c feat(02): slash commands + state machine ...` at HEAD ✓

## Phase 2 Close Summary

Phase 2 closes with **3 `feat(02)` commits** on `milestone/0.1.0`:

```
8b44b6c feat(02): slash commands + state machine (CMD-01..03, CMD-06, CMD-07)
e01a50b feat(02): helper window — smile-arc + lock + chat pipe + 20s clear (WIN-01..06, WIN-09, SAFE-01..04)
018db02 feat(02): macros + schema cleanup (MACR-01..05, SAFE-03)
```

**21 Phase-2 REQ IDs covered:**

| Plan | REQ IDs |
|------|---------|
| 02-01 | MACR-01, MACR-02, MACR-03, MACR-04, MACR-05, SAFE-03 (6) |
| 02-02 | WIN-01, WIN-02, WIN-03, WIN-04, WIN-05, WIN-06, WIN-09, SAFE-01, SAFE-02, SAFE-04 (10) |
| 02-03 | CMD-01, CMD-02, CMD-03, CMD-06, CMD-07 (5) |

Sum: 21. Match. (MACR-04 — config-panel "Recreate Macros" button — Phase 3 owns the button UI; Phase 2 ships the re-runnable entry point `ns:RegisterMacros` per 02-01.)

**WIN-08, WIN-10, CMD-05, and all CFG-* IDs remain Phase 3 territory.**

## Hard Taint Constraints — Repo-Wide Clean

Per CLAUDE.md, all four hard constraints upheld across `Core.lua`, `Macros.lua`, `Window.lua`, `Config.lua`:

| Constraint | Verification |
|-----------|--------------|
| No `SendChatMessage` | `! grep -rE "SendChatMessage" *.lua` ✓ |
| No Lua string ops on `msg` | `! grep -rnE "msg:(gsub|match|find|len|sub|format|rep)" *.lua` ✓ |
| No `ChatFrame_ReplaceIconAndGroupExpressions` (older alias) | `! grep -rE "ChatFrame_ReplaceIconAndGroupExpressions" *.lua` ✓ |
| No `loadstring` / `setfenv` (T-SLASH-PARSER mitigation) | `! grep -rE "loadstring\|setfenv" *.lua` ✓ |
| `COMBAT_LOG_EVENT_UNFILTERED` never used | `! grep -rE "COMBAT_LOG_EVENT_UNFILTERED" *.lua` ✓ (also verified) |

## Recommended User Smoke Test

After Phase 2 close (no /reload between addon files needed; install.bat copies all four Lua files):

1. Run `./scripts/install.bat` then `/reload` in WoW.
2. `/lura help` — expect 6 colored lines listing all subcommands.
3. `/lura show` (out of combat) — expect window appears at default anchor (CENTER UIParent CENTER 200 80).
4. Drag window to a new position (lock button must be unlocked); `/lura hide`; `/reload`; `/lura show` — expect window appears at the new persisted position.
5. Click the padlock button — expect texture swaps Locked ↔ Unlocked; drag enable/disable follows.
6. In raid combat with `TLH_*` macros bound to action bars: press `TLH_Diamond` — expect slot 1 fills with a diamond raid-marker icon.
7. Press all 5 macros in sequence, then a 6th — expect slot 1 refills (wrap-around clear behavior).
8. Wait 20s after last fill — expect display self-clears.
9. Mid-combat `/lura hide` — expect window hides immediately, sequence wiped, subsequent macro presses ignored.
10. Mid-combat `/lura show` — expect window reappears, next macro press fills slot 1 (D-23).
11. Bare `/lura` — toggles current state (verify by watching window visibility flip).
12. `/tlh help`, `/tlh show`, `/tlh hide`, `/tlh` — verify alias parity with `/lura`.

## Self-Check: PASSED

- File created: `.planning/phases/02-poc-port-macros-window-commands/02-03-SUMMARY.md` ✓
- Commit `8b44b6c` exists in `git log milestone/0.1.0 --oneline` ✓
- Core.lua exports verified by grep: `ns:Enable`, `ns:Disable`, `ns:PrintHelp`, `ns:HandleSlashCommand`, `SLASH_LURA1`, `SLASH_TLH1`, `SlashCmdList["LURA"]`, `SlashCmdList["TLH"]` all present ✓
- Phase 2 commit count: 3 feat(02) commits on milestone/0.1.0 ✓
- Repo-wide taint grep clean ✓
