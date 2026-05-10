---
phase: 02-poc-port-macros-window-commands
verified: 2026-04-30T00:00:00Z
human_verified: 2026-05-01T00:00:00Z
status: PASS
score: 5/5 success-criteria verified (programmatic); 21/21 requirements code-delivered; 10/10 runtime smoke tests confirmed by user 2026-05-01
overrides_applied: 0
re_verification: null
post_execution_amendments:
  - id: AMEND-01
    description: "Combat-only chat-event registration replaced with visibility-gated registration. OnShow registers CHAT_MSG_*, OnHide unregisters and wipes the in-memory sequence. Affects D-23, D-24, D-32, SAFE-04 truth tables."
    reason: "User asked to drop combat gating ('plain and simple — window open it runs, not open it doesn't') after smoke testing showed combat-only chat events made testing and casual use too friction-heavy."
    code_locations: "Window.lua OnShow/OnHide handlers; Core.lua slash dispatcher toggles on win:IsShown()."
    constraint_impact: "Hard taint constraints (no SendChatMessage, no msg string ops) unchanged. Combat lockdown still respected for macro creation (MACR-03)."
  - id: AMEND-02
    description: "db.enabled field removed from schema. Window visibility (win:IsShown()) is the single source of truth for on/off state."
    reason: "Schema simplification follow-on from AMEND-01 — db.enabled became a redundant mirror of visibility."
    code_locations: "Core.lua defaults table + backfill loop; ns:HandleSlashCommand toggle branch."
    constraint_impact: "None — existing DBs keep their stale enabled key harmlessly."
  - id: AMEND-03
    description: "Macro registration moved from ADDON_LOADED to PLAYER_LOGIN."
    reason: "CreateMacro/EditMacro silently fail at ADDON_LOADED — the macro subsystem isn't fully initialized until PLAYER_LOGIN. POC ran from a script context that already fired post-login, so the timing wasn't visible there."
    code_locations: "Core.lua eventFrame handler — PLAYER_LOGIN branch unregisters itself after firing."
    constraint_impact: "MACR-01..05 still satisfied; combat-deferral path (MACR-03) unchanged."
  - id: AMEND-04
    description: "Visual chrome rebuilt: BasicFrameTemplateWithInset → BasicFrameTemplate → plain BackdropTemplate (no template chrome at all). No title bar, no close button. Backdrop is solid midnight-navy (0.05, 0.07, 0.18) with no edgeFile."
    reason: "User iterated toward minimal chrome that blends into a borderless UI setup. Close button became redundant once /lura toggles visibility."
    code_locations: "Window.lua CreateWindow."
    constraint_impact: "UI-SPEC visual contract supersedes the original Inset-template description; functional contract (smile-arc, slot order, BOSS/TANK labels) unchanged."
  - id: AMEND-05
    description: "Lock button: textured padlock at top-right → text 'Lock' at bottom-right; hidden entirely when locked."
    reason: "Cleaner look once the window is positioned and locked. To unlock, the user uses the config panel toggle (Phase 3) or /run TerribleLuraHelperDB.window.locked = false; ReloadUI()."
    code_locations: "Window.lua lockBtn + applyLockState."
    constraint_impact: "WIN-05 (lock toggle) still satisfied; WIN-08 (config-panel unlock) becomes the only Phase-3 unlock affordance."
  - id: AMEND-06
    description: "Window default-locked → default-unlocked. Existing DBs keep their saved value."
    reason: "Fresh installs should let users position the window without first hunting for the lock button."
    code_locations: "Core.lua defaults table + backfill loop."
    constraint_impact: "None."
  - id: AMEND-07
    description: "Slot palette retheme: muted-purple borders (0.3, 0.2, 0.5) + bright violet fill (0.85, 0.4, 1.0) → warm parchment-grey idle (0.65, 0.62, 0.55) + bright cream-gold filled (1.0, 0.92, 0.7). Slot bg lifted to (0.10, 0.10, 0.13) so empty slots stay visible against navy bg."
    reason: "Match the L'ura encounter's golden-rune / void-light aesthetic."
    code_locations: "Window.lua CreateWindow slot creation + FillSlot/ClearAll."
    constraint_impact: "None."
  - id: AMEND-08
    description: "Window dimensions trimmed 380x320 → 380x235; bossView TOP -38 → -10. Slot positions spread outward (110/80/0 → 140/90/0) so adjacent 64px slots no longer overlap."
    reason: "User requested less empty space + more slot separation after first in-game smoke test."
    code_locations: "Window.lua W/H + SLOT_POS constants."
    constraint_impact: "None — smile-arc shape preserved."
human_verification_results:
  - test: "Slot fill via /s {rt#} (1..5 in arrival order)"
    result: PASS
  - test: "6th press wraps to slot 1"
    result: PASS
  - test: "20s inactivity self-clear"
    result: PASS
  - test: "/lura hide wipes slots and hides window"
    result: PASS
  - test: "/lura no-arg toggle"
    result: PASS
  - test: "Drag + /reload position persistence"
    result: PASS
  - test: "Lock click + /reload — locked state persists, no Lock button visible"
    result: PASS
  - test: "Sequence is in-memory only (filled slots clear on /reload)"
    result: PASS
  - test: "Macro idempotence on /reload (no duplicates)"
    result: PASS
  - test: "Macro recreation after manual delete + /reload"
    result: PASS
human_verification:
  - test: "Install + /reload, then /lura help"
    expected: "6 colored chat lines: header in purple, 5 commands in gold, /tlh alias note. Format matches UI-SPEC §5.4 exactly."
    why_human: "Color-code rendering and chat-frame output is visible only in-game."
  - test: "/lura show out of combat (fresh install)"
    expected: "Window appears at default anchor (CENTER UIParent CENTER 200 80) with smile-arc layout: BOSS center, TANK above slot 3, slots numbered 1-5, padlock + close buttons in title bar."
    why_human: "Window appearance, anchor location, and chrome rendering are visible only in-game."
  - test: "Drag window to a new position (after clicking padlock to unlock); /lura hide; /reload; /lura show"
    expected: "Window appears at the new dragged position (db.window.position persists across /reload)."
    why_human: "Drag interaction, position persistence round-trip, and visual relocation require a real client."
  - test: "Click padlock button while window is shown"
    expected: "Texture swaps between Locked-Up/Unlocked-Up; drag enable/disable follows the swap."
    why_human: "Texture path resolution on Midnight 12.0 client is not verifiable from source. UI-SPEC §3.1 mentions a possible atlas fallback if classic paths return blank."
  - test: "Mid-combat raid encounter: press TLH_Diamond, then TLH_Triangle, ..., TLH_T (5 macros)"
    expected: "Slots 1..5 fill in arrival order with raid-marker icons rendered via C_ChatInfo.ReplaceIconAndGroupExpressions."
    why_human: "Behavior depends on macro keys being bound to the action bar AND the player being in real combat (PLAYER_REGEN_DISABLED fired) AND chat events arriving from the player's own /raid call. Cannot be simulated."
  - test: "After 5 slots filled, press a 6th macro"
    expected: "All slots clear instantly, then slot 1 fills with the 6th press's marker."
    why_human: "Wrap-around behavior is visible only at runtime."
  - test: "Wait 20 seconds after the most recent fill (no further chat events)"
    expected: "All slots self-clear (text empty, borders return to unfilled color)."
    why_human: "C_Timer.NewTimer firing requires the WoW client; cannot be simulated."
  - test: "Mid-combat /lura hide"
    expected: "Window hides; sequence wipes; subsequent TLH_* macro presses are ignored (no slot fill, no sequence growth) until /lura show."
    why_human: "Confirms event unregister semantics under combat lockdown — runtime-only behavior."
  - test: "Mid-combat /lura show (after a /lura hide)"
    expected: "Window reappears; next macro press fills slot 1 (D-23 mid-combat re-register works)."
    why_human: "Verifies the InCombatLockdown() branch in ns:ShowWindow re-registers events correctly mid-fight."
  - test: "First-login mid-combat (rare)"
    expected: "Macros do not appear immediately; on PLAYER_REGEN_ENABLED (combat ends), 5 TLH_* macros materialize in /macro with raid-marker icons (no duplicates)."
    why_human: "Requires triggering ADDON_LOADED while InCombatLockdown() is true — only achievable via real combat at login."
  - test: "Subsequent logins: open /macro"
    expected: "TLH_Diamond, TLH_Triangle, TLH_Circle, TLH_Cross, TLH_T present exactly once each (no duplicates after multiple logins)."
    why_human: "Idempotence of CreateMacro vs EditMacro lookup is logic-correct in source; visual confirmation requires the macro UI."
  - test: "/tlh, /tlh show, /tlh hide, /tlh help, /tlh config"
    expected: "Behavior is identical to the corresponding /lura commands (full alias)."
    why_human: "Slash command dispatch is wired identically in source; runtime parity confirmation lives in the chat frame."
---

# Phase 2: POC Port (Macros, Window, Commands) Verification Report

**Phase Goal:** Every behavior proven in `WeakerScripts/Samples/LuraPatternHelper.lua` runs inside the standalone addon, plus the new `/lura hide` = "disable processing entirely" semantics that the POC doesn't have. The five rune slots fill in arrival order during boss combat without violating any taint constraint.

**Verified:** 2026-04-30
**Status:** human_needed (programmatic verification PASSED for all 5 success criteria + 21 requirements; runtime smoke testing required)
**Re-verification:** No — initial verification

## Goal Achievement

### Success Criteria (from ROADMAP.md)

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| 1 | First-login macro creation: 5 TLH_* macros with raid-marker icons; mid-combat defers to PLAYER_REGEN_ENABLED; subsequent logins update in place | PASS (code) / NEEDS HUMAN (runtime) | `Macros.lua:15-21` defines all 5 macros with FileDataIDs 137001/137002/137003/137004/137007. `Macros.lua:33-36` guards on `InCombatLockdown()` and sets `registrationDeferred=true`. `Macros.lua:69-78` arms a `PLAYER_REGEN_ENABLED` retry frame. `Macros.lua:39-47` uses `GetMacroIndexByName` lookup before `CreateMacro` (idx==0) or `EditMacro` (idx>0) — idempotent in-place update. |
| 2 | Slot-fill behavior: After /lura show during raid combat, 5 macros fill slots 1..5 via C_ChatInfo.ReplaceIconAndGroupExpressions; 6th press wraps to slot 1; **20s of silence self-clears**; **sequence is in-memory only** | PASS (code) / NEEDS HUMAN (runtime) | `Window.lua:43` `local sequence = {}` (in-memory upvalue, NOT in DB). `Window.lua:265` `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)`. `Window.lua:271-273` `if #sequence >= 5 then ClearAll() end` (wrap-around). `Window.lua:15` `local INACTIVITY_TIMEOUT = 20`. `Window.lua:234` `C_Timer.NewTimer(INACTIVITY_TIMEOUT, ...)`. No `db.sequence` reference anywhere in repo (verified by grep). |
| 3 | Slash commands: /lura show, /lura hide, /lura (toggle), /lura help, /tlh alias all behave as specified. **/lura hide mid-combat causes next chat marker to be ignored**. **/lura hide also wipes in-memory sequence** | PASS (code) / NEEDS HUMAN (runtime) | `Core.lua:128-148` `ns:HandleSlashCommand` parses 5 cases (show/hide/help/config/empty/unknown). `Core.lua:101-106` `ns:Disable` sets `db.enabled=false`, calls `UnregisterChatEvents`, `WipeSequence`, `HideWindow` — flag flip BEFORE unregister so combat-frame won't re-register. `Core.lua:151-158` registers `SLASH_LURA1`/`SLASH_TLH1` with both SlashCmdList entries routing to the same handler (full alias). `Core.lua:108-116` `ns:PrintHelp` emits 6-line color-coded block. |
| 4 | Window default-hidden + lock: Hidden by default on every login/reload; never auto-shows on chat; draggable only when unlocked via on-window lock button; only opens via /lura or /lura show | PASS (code) / NEEDS HUMAN (runtime) | `Window.lua:62` `win:Hide()` at frame creation (WIN-04). `Window.lua:277` comment + absence of `win:Show()` inside chat handler block (verified by reading lines 256-278 — handler ends with `ScheduleClear()` then `end)`). `Window.lua:84-90` lock button created and bound to `ns:ToggleLocked`. `Window.lua:179-192` `applyLockState` toggles `SetMovable` and `RegisterForDrag` based on `db.window.locked`. `Window.lua:317` `win:Show()` is reached ONLY via `ns:ShowWindow` (called by `ns:Enable`, called by `/lura show` or `/lura` toggle). |
| 5 | Taint safety: zero SendChatMessage; zero index/length/gsub/match/concat/pattern-test of msg; chat events registered only while addon enabled AND combat active; CreateMacro/EditMacro guarded by InCombatLockdown with PLAYER_REGEN_ENABLED retry | PASS | All five hard taint constraints hold. See "Anti-Patterns Found" section — all greps clean. `Window.lua:297-310` combat-state hooks: `PLAYER_REGEN_DISABLED` registers events ONLY if `ns.db.enabled` is true; `PLAYER_REGEN_ENABLED` always unregisters. `Window.lua:315-323` `ns:ShowWindow` covers the mid-combat `/lura show` case via the `if ns.db.enabled and InCombatLockdown() then ns:RegisterChatEvents() end` clause. `Macros.lua:33-36` + `69-78` covers SAFE-03. |

**Score:** 5/5 success criteria programmatically verified (runtime smoke testing required for visual/timing behavior — see human_verification frontmatter).

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Core.lua` | Schema cleanup (drop db.sequence, add db.window.alpha) + slash dispatcher | VERIFIED | 158 lines. `alpha = 1.00` at line 35. Backfill at lines 69-71. No `db.sequence` reference. SLASH_LURA1/SLASH_TLH1/SlashCmdList at lines 151-158. ns:Enable/Disable/PrintHelp/HandleSlashCommand at lines 95-148. |
| `Macros.lua` | 5-macro registration with combat-lockdown deferral and idempotent CreateMacro/EditMacro | VERIFIED | 89 lines. MACROS table lines 15-21 with all 5 names + 5 correct FileDataIDs (137003/137004/137002/137007/137001). `InCombatLockdown()` guard line 33. PLAYER_REGEN_ENABLED retry frame lines 69-78. Printed-once flag `macrosPrintedThisSession` is a Lua local (line 24), not in DB. Three exports: `RegisterMacros`, `InitMacros`, `OnRegenEnabled`. |
| `Window.lua` | Full helper-window implementation: BasicFrameTemplateWithInset, smile-arc, lock button, drag-position persistence, taint-safe chat pipeline, 20s self-clear | VERIFIED | 347 lines. `BasicFrameTemplateWithInset` line 58. SLOT_POS verbatim from POC lines 23-29. Lock button anchored `TOPRIGHT, win.CloseButton, TOPLEFT, 2, 0` (line 86). `INACTIVITY_TIMEOUT = 20` line 15. `local sequence = {}` (in-memory) line 43. `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` line 265. `db.listenChannels[event:sub(10)]` filter line 260. Combat gating frame lines 297-310. Eight `ns.*` exports (lines 194, 280, 286, 315, 325, 332, 336, 343). |
| `Config.lua` | Phase 1 stub, untouched in Phase 2 | VERIFIED | 12 lines. `function ns:InitConfig()` is empty stub at line 10. No Phase 2 changes. |
| `TerribleLuraHelper.toc` | Lists Core.lua, Macros.lua, Window.lua, Config.lua in load order | VERIFIED | Lines 12-15 list all four files in correct dependency order. |

## Key Link Verification (Wiring)

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| Core.lua ADDON_LOADED dispatcher | ns:InitMacros / ns:InitWindow / ns:InitConfig | Direct calls | WIRED | `Core.lua:74-82` calls all three init functions in order. |
| Core.lua slash registration | ns:HandleSlashCommand | `SlashCmdList[name] = function(arg) ns:HandleSlashCommand(arg) end` | WIRED | `Core.lua:153,156` — both SlashCmdList entries route to the same handler. |
| ns:HandleSlashCommand "show" | ns:Enable | dispatch on parsed `cmd` | WIRED | `Core.lua:130-131`. |
| ns:HandleSlashCommand "hide" | ns:Disable | dispatch on parsed `cmd` | WIRED | `Core.lua:132-133`. |
| ns:HandleSlashCommand "help" | ns:PrintHelp | dispatch on parsed `cmd` | WIRED | `Core.lua:134-135`. |
| ns:HandleSlashCommand "config" | print stub | dispatch on parsed `cmd` | WIRED | `Core.lua:136-137`. |
| ns:HandleSlashCommand bare | toggle | `if ns.db.enabled then Disable else Enable` | WIRED | `Core.lua:138-144`. |
| ns:Enable | ns:ShowWindow | direct call after `db.enabled = true` | WIRED | `Core.lua:96-97`. |
| ns:Disable | ns:UnregisterChatEvents + ns:WipeSequence + ns:HideWindow | three direct calls in order, after `db.enabled = false` | WIRED | `Core.lua:102-105`. Order is correct (flag flip first). |
| ns:ShowWindow | ns:RegisterChatEvents (mid-combat case) | `if ns.db.enabled and InCombatLockdown() then` | WIRED | `Window.lua:316-322`. |
| Window.lua chatFrame OnEvent | ns.db.listenChannels | `event:sub(10)` lookup | WIRED | `Window.lua:260` — operates on EVENT, not MSG (SAFE-02 explicitly safe). |
| Window.lua chatFrame OnEvent | C_ChatInfo.ReplaceIconAndGroupExpressions | opaque msg pass-through | WIRED | `Window.lua:265` — exact signature `(msg, nil, false)`. |
| Window.lua chatFrame OnEvent | FillSlot | `FillSlot(#sequence, processed)` after wrap-around check | WIRED | `Window.lua:271-275`. |
| Window.lua combatFrame OnEvent | ns:RegisterChatEvents (gated by db.enabled) | `if ns.db.enabled then` on PLAYER_REGEN_DISABLED | WIRED | `Window.lua:301-305`. |
| Window.lua combatFrame OnEvent | ns:UnregisterChatEvents | always on PLAYER_REGEN_ENABLED | WIRED | `Window.lua:306-309`. |
| Window.lua OnDragStop | ns.db.window.position | persistPosition writes 5-tuple | WIRED | `Window.lua:147-149`, `202-211`. |
| Window.lua first show | saved position OR default | `_G[pos[2]] or UIParent` fallback | WIRED | `Window.lua:213-225`. |
| Window.lua lockBtn OnClick | ns:ToggleLocked | direct call | WIRED | `Window.lua:88-90`. |
| Macros.lua ns:InitMacros | ns:RegisterMacros + PLAYER_REGEN_ENABLED retry | call + retry frame on combat-block | WIRED | `Macros.lua:66-80`. |

All key links verified.

## Data-Flow Trace (Level 4)

The Phase 2 phase produces a renderable smile-arc display whose data is the in-memory `sequence` table. The data path:

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `Window.lua` slot FontStrings | `sequence[i]` (post-processed `\|T...\|t` string) | Blizzard's CHAT_MSG_* event → `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` | YES (provided real raid combat is occurring and macros are bound to action bars) | FLOWING — but flow is gated on real game state and macro key presses, which can only be confirmed at runtime |
| `Window.lua` lock button textures | None (configuration only — `db.window.locked`) | User click | YES | FLOWING |
| `Window.lua` window scale/alpha | `ns.db.window.scale` / `ns.db.window.alpha` | SavedVariables (default 1.00 each) | YES | FLOWING — values applied at frame creation per D-36 |

No HOLLOW or DISCONNECTED artifacts. The chat handler does not have a fallback static-data path; it only renders what the live `C_ChatInfo` helper returns.

## Behavioral Spot-Checks

This phase produces WoW addon Lua code that depends on the in-game runtime (CHAT_MSG_* events from Blizzard, PLAYER_REGEN_* from combat lockdown, action-bar macro key presses). No runnable entry points exist outside the WoW client.

**Step 7b: SKIPPED (no runnable entry points outside WoW)** — see human_verification for the full smoke-test list.

The closest programmatic substitute (stylua syntax-parse) was run:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 4 Lua files parse cleanly | `stylua --check Core.lua Macros.lua Window.lua Config.lua` | exit 0 | PASS |

## Requirements Coverage

All 21 Phase 2 requirements verified at the source level:

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| MACR-01 | 02-01 | 5 named TLH_* player macros with raid-marker FileDataIDs | SATISFIED | `Macros.lua:15-21` MACROS table with all 5 names + 5 correct icons. |
| MACR-02 | 02-01 | Existing macros updated in place (idempotent on every login) | SATISFIED | `Macros.lua:39-47` GetMacroIndexByName returns 0 → CreateMacro; non-zero → EditMacro. Verified by code reading; runtime confirmation deferred to smoke test. |
| MACR-03 | 02-01 | InCombatLockdown defers macro registration to PLAYER_REGEN_ENABLED | SATISFIED | `Macros.lua:33-36` early return + `registrationDeferred=true`; `Macros.lua:69-78` PLAYER_REGEN_ENABLED retry frame. |
| MACR-04 | 02-01 | "Recreate Macros" button re-runs registration on demand | SATISFIED (entry point) | `Macros.lua:32` `function ns:RegisterMacros()` is the re-runnable entry point. The Phase 3 button (CFG-06) will call this; Phase 2 ships the entry point. |
| MACR-05 | 02-01 | First successful registration prints "drag to action bar" hint once per session | SATISFIED | `Macros.lua:24,49-58` `macrosPrintedThisSession` Lua local + conditional print. |
| WIN-01 | 02-02 | Smile-arc with 5 slots, BOSS center, TANK opposite slot 3 | SATISFIED | `Window.lua:23-29` SLOT_POS verbatim. `Window.lua:100-108` BOSS at center +0,+8; TANK at +0,+60 (above boss, opposite slot 3). |
| WIN-02 | 02-02 | Slots fill 1→5; 6th message clears all and refills slot 1 | SATISFIED | `Window.lua:271-275` `if #sequence >= 5 then ClearAll() end; sequence[#sequence+1] = processed; FillSlot(#sequence, processed)`. |
| WIN-03 | 02-02 | FontString text set from `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` | SATISFIED | `Window.lua:265` exact API call; `Window.lua:163-166` FillSlot calls `slot.fs:SetText(msg)` directly with the processed result. Zero string ops on msg verified by repo-wide grep. |
| WIN-04 | 02-02 | Window hidden by default on every login/reload; only /lura reveals it | SATISFIED | `Window.lua:62` `win:Hide()` at creation. Chat handler does NOT call `win:Show()` (verified — comment line 277 + reading). `win:Show()` is called only at line 317 inside `ns:ShowWindow`. |
| WIN-05 | 02-02 | Visible lock/unlock button on frame; toggles drag enable | SATISFIED | `Window.lua:84-90` lock button created. `Window.lua:179-192` applyLockState toggles `SetMovable` + `RegisterForDrag`. |
| WIN-06 | 02-02 | Slot display self-clears 20s after most recent chat message | SATISFIED | `Window.lua:15` `INACTIVITY_TIMEOUT = 20`. `Window.lua:230-238` ScheduleClear cancels in-flight + new C_Timer.NewTimer(20, ClearAll). Each chat event (line 276) calls ScheduleClear. |
| WIN-09 | 02-02 | Window position persists across /reload via db.window.position | SATISFIED | `Window.lua:202-211` persistPosition writes 5-tuple on OnDragStop. `Window.lua:213-225` applySavedPosition reads + applies via `_G[name] or UIParent` fallback. Default `CENTER UIParent CENTER 200 80` matches POC. |
| CMD-01 | 02-03 | /lura show flips enabled, registers events for combat, shows window; mid-combat case handled | SATISFIED | `Core.lua:95-99` ns:Enable. `Window.lua:316-322` mid-combat re-register inside ns:ShowWindow per D-23. |
| CMD-02 | 02-03 | /lura hide flips enabled=false, unregisters/ignores chat events, hides window, wipes in-memory sequence | SATISFIED | `Core.lua:101-106` ns:Disable runs the four operations in correct order (flag first, then unregister, wipe, hide). |
| CMD-03 | 02-03 | /lura (no arg) toggles between enabled and disabled | SATISFIED | `Core.lua:138-144` bare-`""` branch in HandleSlashCommand: `if ns.db.enabled then Disable else Enable end`. |
| CMD-06 | 02-03 | /tlh is a full alias for /lura | SATISFIED | `Core.lua:151-158` SLASH_LURA1 + SLASH_TLH1 + both SlashCmdList entries route to the same `ns:HandleSlashCommand`. |
| CMD-07 | 02-03 | /lura help prints color-coded slash command list | SATISFIED | `Core.lua:108-116` ns:PrintHelp emits 6 lines with `\|cffaa44ff` (purple) + `\|cffffd700` (gold) color codes per UI-SPEC §5.4. |
| SAFE-01 | 02-02 | Zero SendChatMessage call sites | SATISFIED | Repo-wide grep: 0 matches for `SendChatMessage` across all .lua files. |
| SAFE-02 | 02-02 | Zero call sites that index/length/gsub/match/concat/pattern-test the msg arg | SATISFIED | Repo-wide grep: 0 matches for `msg:(gsub\|match\|find\|len\|sub\|format\|rep\|byte\|upper\|lower)`, 0 for `#msg`, 0 for `msg[`, 0 for `string.{gsub,match,...}(msg`. The only msg use is the opaque pass to `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` at Window.lua:265. |
| SAFE-03 | 02-01 | CreateMacro/EditMacro guarded by InCombatLockdown with PLAYER_REGEN_ENABLED retry | SATISFIED | `Macros.lua:33-36` guard. `Macros.lua:69-78` retry frame. |
| SAFE-04 | 02-02 | Chat events registered only while addon enabled AND combat active | SATISFIED | `Window.lua:297-310` combatFrame: PLAYER_REGEN_DISABLED registers ONLY if `ns.db.enabled` true; PLAYER_REGEN_ENABLED always unregisters. `Window.lua:316-322` covers mid-combat /lura show case. |

**Coverage:** 21/21 Phase 2 requirements satisfied at the source level. Items requiring runtime confirmation (idempotence on subsequent logins, real CHAT_MSG_* arrival, timer firing, drag persistence round-trip) are listed in human_verification.

No orphaned requirements detected. Each declared requirement maps to verified code.

## Anti-Patterns Found

Repo-wide scan across `Core.lua`, `Macros.lua`, `Window.lua`, `Config.lua`:

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| Config.lua | 10-12 | Empty function body `function ns:InitConfig() end` | Info | Phase 1 stub explicitly preserved for Phase 3 to fill (per CONTEXT.md "Out of scope (Phase 3): Settings panel registration..."). NOT a Phase 2 gap — Phase 2 deliberately does not modify Config.lua. |
| Core.lua | 137 | `print("Config panel lands in Phase 3.")` | Info | Phase 2 stub for `/lura config` per D-CMD-05 (CMD-05 owned by Phase 3). Documented as expected behavior in plan 02-03. NOT a gap. |

Hard taint constraints — all CLEAN:

| Constraint | Grep Pattern | Result |
|-----------|--------------|--------|
| No SendChatMessage | `SendChatMessage` | 0 matches |
| No msg string ops | `msg:(gsub\|match\|find\|len\|sub\|format\|rep\|byte\|upper\|lower)` | 0 matches |
| No msg index | `msg\[` | 0 matches |
| No msg length | `#msg\b` | 0 matches |
| No string.* on msg | `string\.(gsub\|match\|find\|len\|sub\|format\|rep)\(msg` | 0 matches |
| No older alias | `ChatFrame_ReplaceIconAndGroupExpressions` | 0 matches |
| No combat-log event | `COMBAT_LOG_EVENT_UNFILTERED` | 0 matches |
| No eval | `loadstring\|setfenv\|loadfile` | 0 matches |

No blocker, warning, or critical anti-patterns found.

## Commit Verification

Phase 2 commits on `milestone/0.1.0`:

| Commit | Subject | Files |
|--------|---------|-------|
| `018db02` | feat(02): macros + schema cleanup (MACR-01..05, SAFE-03) | Core.lua, Macros.lua |
| `e01a50b` | feat(02): helper window — smile-arc + lock + chat pipe + 20s clear (WIN-01..06, WIN-09, SAFE-01..04) | Window.lua |
| `8b44b6c` | feat(02): slash commands + state machine (CMD-01..03, CMD-06, CMD-07) | Core.lua |

Phase 2 commit count: 3 `feat(02)` commits as required by the plan close criteria.
Branch: `milestone/0.1.0` (verified — current HEAD on this branch).
`main` untouched per the milestone-branch + squash-merge workflow rule.

## Phase Goal Alignment

The phase goal states: "Every behavior proven in WeakerScripts/Samples/LuraPatternHelper.lua runs inside the standalone addon, plus the new /lura hide = 'disable processing entirely' semantics that the POC doesn't have. The five rune slots fill in arrival order during boss combat without violating any taint constraint."

Source-level analysis:
- POC line 42-78 (macros) → ported verbatim with combat-lockdown deferral added (Macros.lua).
- POC lines 90-194 (window chrome + smile-arc + slot helpers) → ported verbatim except for D-17 (purple BackdropTemplate → BasicFrameTemplateWithInset) and D-19 (template default title color).
- POC lines 196-220 (timer) → ported with 15s → 20s amendment per D-28.
- POC lines 240-271 (chat pipeline) → ported with 3 deviations: D-30 (drop ChatFrame_ alias), D-25 (no auto-show), D-31 (channel filter).
- POC lines 280-293 (slash dispatcher) → ported with new state-machine semantics: /lura hide is now an `ns:Disable` (wipe + hide + unregister) instead of POC's hide-only.
- New /lura hide = "disable processing entirely" → implemented via `ns:Disable` (Core.lua:101-106).

All five hard taint constraints upheld (verified by repo-wide grep, all clean).

## Gaps Summary

**No source-level gaps.** All 5 success criteria, all 21 requirements, and all hard taint constraints are delivered in code.

The status is **human_needed** because the Phase 2 deliverable is a WoW addon — the goal includes runtime behavior (visible window, raid-combat key presses fill slots, 20s timer fires, drag persists across /reload) that is fundamentally only verifiable inside a running WoW client. The source-level evidence is consistent with goal achievement, but final goal confirmation requires the user smoke test enumerated in `human_verification` (see frontmatter — 12 items).

After the user runs the smoke test and confirms the 12 human verification items, this phase moves to PASS.

---

## Phase Verdict: PASS (source-level) / PENDING HUMAN VERIFICATION (runtime)

- All Phase 2 success criteria are deliverable based on the code in `Core.lua`, `Macros.lua`, `Window.lua`.
- All 21 Phase 2 requirements (MACR-01..05, WIN-01..06, WIN-09, CMD-01..03, CMD-06, CMD-07, SAFE-01..04) are satisfied at source level.
- All five hard taint constraints from CLAUDE.md are upheld (verified by repo-wide grep).
- All key wiring links are correct: `Core.lua` slash dispatcher → `ns:Enable`/`Disable` → `ns:ShowWindow`/`HideWindow`/`WipeSequence`/`UnregisterChatEvents` (defined in `Window.lua`); `Window.lua` chat pipeline → `C_ChatInfo.ReplaceIconAndGroupExpressions` → `FontString:SetText`; `Macros.lua` deferral → `PLAYER_REGEN_ENABLED` retry frame.
- Three Phase 2 commits exist on `milestone/0.1.0`; `main` is untouched.

The remaining work to fully close Phase 2 is a 12-item runtime smoke test inside WoW, listed in the `human_verification` frontmatter.

---

_Verified: 2026-04-30_
_Verifier: Claude (gsd-verifier)_
