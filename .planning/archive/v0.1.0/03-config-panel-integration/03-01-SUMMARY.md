---
phase: 03-config-panel-integration
plan: 01
subsystem: config-panel
tags: [settings-api, soft-hide, dynamic-macros, slash-commands]
status: tasks-1-5-complete; task-6-human-verify-pending
requires:
  - Phase 1 scaffolding (Core/Window/Macros/Config skeleton)
  - Phase 2 POC port (chat handler, Window OnShow/OnHide, ns:RegisterMacros, slash dispatcher)
provides:
  - Options > AddOns > TerribleLuraHelper Settings panel (4 sections)
  - Soft-hide window state machine (alpha=0 instead of Hide())
  - Dynamic macro body construction from db.macroChannel
  - 8-command slash surface (added /lura lock, /lura unlock, /lura config)
  - ns.SLASH_HELP single-source-of-truth shared between panel and ns:PrintHelp
affects:
  - Core.lua (schema + slash dispatcher + PrintHelp)
  - Window.lua (soft-hide hooks + 5 new exports + ns.win alias)
  - Macros.lua (MACROS reshape, CHANNEL_PREFIX, ns:OnMacroChannelChanged)
  - Config.lua (full panel registration; was a 13-line stub)
tech-stack:
  added:
    - Settings.RegisterAddOnSetting (post-11.0.2 signature)
    - Settings.CreateDropdown / Settings.CreateControlTextContainer
    - CreateSettingsButtonInitializer / CreateSettingsListSectionHeaderInitializer
    - EventUtil.ContinueOnAddOnLoaded gate
  patterns:
    - Single-source-of-truth shared table (ns.SLASH_HELP) consumed by both
      Config.lua panel section and Core.lua ns:PrintHelp
    - Soft-hide via alpha=0 (chat events stay registered)
    - One-shot PLAYER_REGEN_ENABLED retry frame for macro-channel changes
key-files:
  created: []
  modified:
    - Core.lua (+36/-12)
    - Window.lua (+68/-1)
    - Macros.lua (+51/-7)
    - Config.lua (+279/-7)
decisions:
  - D-01..D-05 (modern Settings API, post-11.0.2 RegisterAddOnSetting signature, EventUtil deferral, numeric category ID)
  - D-10/D-33 (channel keys are INSTANCE_CHAT / INSTANCE_CHAT_LEADER — overrides SETTINGS_API.md research example)
  - D-18..D-22 (soft-hide via alpha=0 so chat events stay registered)
  - D-25..D-28 (8-command slash surface; ns.SLASH_HELP single-source-of-truth)
  - D-35..D-40 (db.macroChannel + CHANNEL_PREFIX dynamic body; section restructure to Chat channels/Window/Macros/Slash commands)
metrics:
  duration: TBD (sequential mode; clock not measured)
  completed_date: 2026-05-01
  tasks_completed: 5 of 6 (Task 6 human-verify pending)
  files_modified: 4
  commits: 5
---

# Phase 3 Plan 01: Settings-API Config Panel & Integration — Summary

**One-liner:** Full Settings-API config panel under Options > AddOns wires every v1 knob (6 channel toggles, scale slider, opacity slider, auto-hide, lock/unlock, recreate macros, macro-target dropdown, 8-command help) through to the live runtime via Window.lua / Macros.lua exports — no panel callback writes the DB directly.

## What Shipped

### Tasks 1–5 (code complete on milestone/0.1.0)

| # | Task                                                          | Commit    | Files Touched | Net LoC  |
| - | ------------------------------------------------------------- | --------- | ------------- | -------- |
| 1 | Add `db.macroChannel` schema default + backfill               | `120ff77` | Core.lua      | +4       |
| 2 | Soft-hide state machine + 5 new Window.lua exports + ns.win alias | `56cd7db` | Window.lua    | +68/-1   |
| 3 | Macro body built dynamically from `db.macroChannel`           | `378912e` | Macros.lua    | +51/-7   |
| 4 | Settings-API config panel (4 sections, ~280 LoC)              | `840492a` | Config.lua    | +279/-7  |
| 5 | Wire `/lura config|lock|unlock` + 8-command help block        | `9c02931` | Core.lua      | +32/-12  |

**Total:** 5 commits, 4 files, ~430 net LoC.

### Per-task acceptance gates (results)

#### Task 1 — Core.lua schema
- `grep -n 'macroChannel' Core.lua` → 3 matches (default-table line + backfill `if` + backfill assign — same pattern as `db.window.alpha`)
- `stylua --check Core.lua` → clean
- SAFE-01/SAFE-02 grep on Core.lua → 0 matches

#### Task 2 — Window.lua soft-hide + 5 exports
- `ns.win = win` → 1 match (line 69)
- `local softHidden` → 1 match (line 52)
- `applySoftHideState` → 7 occurrences (forward decl + helper definition + 4 call sites + 1 comment) — meets the plan's ≥6
- `ns:SetWindowScale` / `ns:SetWindowAlpha` / `ns:OnAutoHideChanged` / `ns:LockWindow` / `ns:UnlockWindow` → each 1 match
- SAFE-01/SAFE-02 grep on Window.lua → 0 matches
- `stylua --check Window.lua` → clean

#### Task 3 — Macros.lua dynamic body
- `CHANNEL_PREFIX` → 4 matches (definition + 2 reads + 1 comment) — meets ≥4
- `ns:OnMacroChannelChanged` → 1 match
- `m.body` → **0 matches** (body field gone from MACROS — confirms the reshape)
- `ns.db.macroChannel` → 1 match (the prefix lookup in `RegisterMacros`)
- Verbatim notice strings present:
  - `Macros will update when you leave combat` → 1 match (line 128)
  - `Macros updated.` → 1 match (line 132)
- SAFE-01/SAFE-02 grep on Macros.lua → 0 matches
- `stylua --check Macros.lua` → clean

#### Task 4 — Config.lua Settings panel
- `Settings.RegisterAddOnSetting` → 5 distinct call sites in source (channel loop body + scale + alpha + autoHide + macroChannel); resolves to **10 runtime invocations** (6 channel iterations + 4 individual sliders/checkbox/dropdown). Note: the plan's "exactly 10 grep matches" was a count of runtime calls — the loop-driven implementation produces 5 source occurrences, which is the correct DRY pattern.
- `Settings.CreateCheckbox` → 2 source sites (channel loop body + autoHide); 7 runtime invocations.
- `Settings.CreateSlider` → 2 (scale + alpha)
- `Settings.CreateDropdown` → 1 (macroChannel)
- `CreateSettingsButtonInitializer` → 2 (Lock/Unlock + Recreate / update macros)
- `CreateSettingsListSectionHeaderInitializer` → 5 source sites (4 section headers + 1 inside slash-help loop); 12 runtime invocations.
- `EventUtil.ContinueOnAddOnLoaded` → 1 call site (line 268; 2 additional mentions in comments)
- `Settings.RegisterAddOnCategory` → 1 match
- `ns.settingsCategoryID` → 2 matches (assign + read in Core.lua dispatcher)
- `InterfaceOptions_AddCategory` → **0 matches** (regression gate clean)
- Verbatim copy gates:
  - `Listen on /raid (leader)` → 1 match
  - `Recreate / update macros` → 2 matches (1 button text + 1 comment header — only the button-text occurrence is user-visible)
  - `Auto-hide when empty` → 1 match
  - `Macros recreated.` → 1 match
- `stylua --check Config.lua` → clean

#### Task 5 — Core.lua slash dispatcher + PrintHelp rewrite
- `ns.SLASH_HELP` → 4 matches (1 `if` check + 1 `for` loop + 2 comments)
- `Settings.OpenToCategory` → 1 invocation (line 152) + 1 comment mention
- `ns:LockWindow` → 1 match
- `ns:UnlockWindow` → 1 match
- `cmd == "lock"` / `cmd == "unlock"` / `cmd == "config"` → each 1 match
- `InterfaceOptions_AddCategory` in Core.lua → 0 matches
- `Config panel lands in Phase 3` → **0 matches** (Phase 2 stub print is gone)
- Hardcoded `"/lura ...` strings inside `ns:PrintHelp` body → 0 (only at line 170 `SLASH_LURA1 = "/lura"`, outside PrintHelp)
- SAFE-01/SAFE-02 grep on Core.lua → 0 matches
- `stylua --check Core.lua` → clean

### Plan-level (cross-file) gates

- `stylua --check Core.lua Window.lua Macros.lua Config.lua` → **all clean**
- Repo-wide hard-taint regression grep → **0 matches**
  ```
  grep -rnE 'SendChatMessage|msg:(gsub|match|find|len|sub|rep)|#msg|msg \.\.|\.\. msg|COMBAT_LOG_EVENT_UNFILTERED|ChatFrame_ReplaceIconAndGroupExpressions' --include='*.lua' .
  ```
- Repo-wide deprecated-API grep → **0 matches**
  ```
  grep -rn 'InterfaceOptions_AddCategory' --include='*.lua' .
  ```
- `EventUtil.ContinueOnAddOnLoaded` in Config.lua → 1 invocation ✓
- `Settings.OpenToCategory(ns.settingsCategoryID)` in Core.lua → numeric ID, never the name string ✓
- Single-source-of-truth slash help: `ns:PrintHelp` iterates `ns.SLASH_HELP` set by Config.lua — drift is impossible by construction ✓

## Deviations from Plan

**None.** Tasks 1–5 executed exactly as written.

Two minor expectation calibrations worth noting (no behavior change, just numbers):

1. **Task 4 grep counts:** the plan's "`Settings.RegisterAddOnSetting` exactly 10" expectation counted runtime invocations. The implementation uses a `for _, ch in ipairs(CHANNELS)` loop for the six channel toggles per CONTEXT.md D-29's "single-file, in-order" guidance, producing 5 source occurrences (channel loop + 4 explicit). At runtime exactly 10 invocations execute (6 + 4). DRY pattern is correct; the plan's wording was loose.

2. **Task 1 grep count:** the plan said "2 matches for `macroChannel`" but the `db.window.alpha` precedent (the explicit pattern to mirror) produces 3 lines (default + `if ... == nil` + assignment). Mine matches the precedent exactly: 3 lines. Plan miscounted; structure is correct.

Neither calibration changed implementation. No CLAUDE.md auto-fixes (Rules 1–3) needed; no architectural decisions (Rule 4) raised.

## Hard-Constraint Verification

| Constraint | Repo-wide grep | Result |
| ---------- | -------------- | ------ |
| `SendChatMessage` | `grep -rn 'SendChatMessage' --include='*.lua' .` | 0 matches |
| Lua string ops on `msg` | `grep -rnE 'msg:(gsub\|match\|find\|len\|sub\|rep)\|#msg\|msg \.\.\|\.\. msg' --include='*.lua' .` | 0 matches |
| `COMBAT_LOG_EVENT_UNFILTERED` | repo-wide | 0 matches |
| `ChatFrame_ReplaceIconAndGroupExpressions` (insecure helper) | repo-wide | 0 matches |
| `InterfaceOptions_AddCategory` (deprecated) | repo-wide | 0 matches |
| `EventUtil.ContinueOnAddOnLoaded` deferral | Config.lua | 1 invocation |

The only path that touches chat-event `msg` is Window.lua's chat handler at lines 296–318, untouched in Phase 3 — `msg` flows opaquely through `C_ChatInfo.ReplaceIconAndGroupExpressions` straight into `FontString:SetText`. CHANNEL_PREFIX strings (`/raid`, `/rw`, `/s`) and `{rt#}` are pure constant addon strings — never sent via `SendChatMessage`, only written to player macros via `CreateMacro` / `EditMacro`.

## Task 6 — Human-Verify Checkpoint (PENDING)

**TASK 6 PENDING — needs in-game smoke test by user.**

The plan's checkpoint requires 15 in-game smoke checks before phase close. The executor cannot automate WoW client behavior, so the human must run them and type "approved" to unblock phase close. Checklist (copy from 03-01-PLAN.md Task 6):

1. Install + reload — `./scripts/install.bat`, `/reload`. Expected: load banner, no Lua errors.
2. Schema persistence — `/run print(TerribleLuraHelperDB.macroChannel)` → `RAID`.
3. Slash help — `/lura help` → 8 commands matching UI-SPEC §5.2 exactly.
4. `/lura config` opens directly to Options > AddOns > TerribleLuraHelper.
5. Channel toggles — uncheck `/raid`, send a `{rt3}` to /raid, expect no slot fill; re-check, expect fill.
6. Scale slider — drag 1.00 → 0.50 → 1.00; window resizes live.
7. Alpha slider — drag 1.00 → 0.20 → 1.00; window fades live.
8. Auto-hide soft-hide — toggle on with empty slots → window goes invisible (alpha=0); next chat marker reveals; 20s self-clear re-soft-hides; toggle off → reveals immediately.
9. Recreate / update macros — out of combat: `Macros recreated.`; in combat: deferral notice; on combat exit, auto-update.
10. Macro target dropdown — switch to `/rw` → `Macro target → /rw. Macros updated.`; `/macro` confirms `TLH_Diamond` body is `/rw {rt3}`. Switch back to `/raid`. In-combat switch → `Macros will update when you leave combat.`
11. Lock/unlock — `/lura unlock`, drag, `/reload`, position persists. `/lura lock` hides on-window Lock button (Phase 2 AMEND-05). Panel button flips state (label is stale on open panel — documented per UI-SPEC §4.3).
12. Persistence — change every setting, `/reload`, all restored. `/quit` + login, all restored.
13. Hard-constraint regression — out-of-game grep: 0 matches both gates.
14. `stylua --check Core.lua Window.lua Macros.lua Config.lua` → no diff.
15. Performance/cleanup pass — no redundant per-frame work, no chat-handler hot-path allocations introduced, no Phase 1 stub remnants in Config.lua.

**Resume signal:** user types "approved" to unblock phase close. If anything fails, report step number + observed vs. expected; a follow-up task will be planned.

## Carry-Forward Items

**None expected.** This is the only Phase 3 plan. Phase close (after Task 6 approval) is owned by `/gsd-verify-phase` and `/gsd-close-milestone` — those will:

1. Squash-merge `milestone/0.1.0` → `main` per CLAUDE.md workflow rule.
2. Tag `v0.1.0` via `./scripts/release.bat 0.1.0`.
3. GitHub Actions builds the BigWigs Packager artifact and ships to CurseForge / Wago / GitHub releases.

## Self-Check: PASSED

Files created:
- FOUND: .planning/phases/03-config-panel-integration/03-01-SUMMARY.md (this file)

Commits exist (verified `git log --oneline -5`):
- FOUND: 120ff77 — feat(03-01): add db.macroChannel schema default + backfill
- FOUND: 56cd7db — feat(03-01): add soft-hide state machine + 5 Window.lua exports
- FOUND: 378912e — feat(03-01): macro body built dynamically from db.macroChannel
- FOUND: 840492a — feat(03-01): implement Settings-API config panel
- FOUND: 9c02931 — feat(03-01): wire /lura config|lock|unlock + 8-cmd help block

Files modified (verified `git log --stat`):
- FOUND: Core.lua, Window.lua, Macros.lua, Config.lua all present and stylua-clean

Hard-constraint regression gates:
- FOUND: 0 matches for SendChatMessage / msg-indexing / COMBAT_LOG_EVENT_UNFILTERED / ChatFrame_ReplaceIconAndGroupExpressions / InterfaceOptions_AddCategory across all .lua files in repo
