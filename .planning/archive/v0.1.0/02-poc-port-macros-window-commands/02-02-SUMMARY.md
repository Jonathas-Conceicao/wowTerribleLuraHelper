---
phase: 02-poc-port-macros-window-commands
plan: "02"
subsystem: helper-window
tags: [window, chat-pipeline, taint-safe, smile-arc, drag-persist]
dependency_graph:
  requires: [02-01-SUMMARY.md]
  provides:
    - "ns:InitWindow"
    - "ns:ShowWindow"
    - "ns:HideWindow"
    - "ns:WipeSequence"
    - "ns:RegisterChatEvents"
    - "ns:UnregisterChatEvents"
    - "ns:ToggleLocked"
    - "ns:IsWindowShown"
    - "TerribleLuraHelperWindow (global frame name)"
  affects: [02-03-PLAN.md (slash dispatcher binds to all 8 ns.* exports)]
tech_stack:
  added: []
  patterns:
    - blizzard-template-inheritance
    - opaque-msg-pass-through
    - combat-gated-event-registration
    - in-memory-state-via-lua-upvalue
    - drag-position-persistence
    - c-timer-ticker-with-cancel
key_files:
  created: []
  modified:
    - Window.lua
decisions:
  - "D-14: lock button immediately LEFT of CloseButton (TOPRIGHT, win.CloseButton, TOPLEFT, +2, 0)"
  - "D-15: db.window.locked default true; padlock click toggles + rebinds drag handlers"
  - "D-16: Blizzard built-in lock textures (Interface\\Buttons\\LockButton-{Locked,Unlocked}-{Up,Down})"
  - "D-17: BasicFrameTemplateWithInset replaces POC's BackdropTemplate; POC purple SetBackdrop*Color dropped"
  - "D-18: smile-arc geometry verbatim from POC (SLOT_POS, SLOT_SIZE=64, ICON_SIZE=56, BOSS/TANK labels)"
  - "D-19: template default title color kept; only TitleText:SetText called"
  - "D-20: OnDragStop captures point/relativeTo/relativePoint/x/y, stores relativeTo as STRING name"
  - "D-21: first-show applies db.window.position via _G[name] or UIParent fallback; default CENTER UIParent CENTER 200 80"
  - "D-22: SetClampedToScreen(true) handles off-screen guard automatically"
  - "D-23: mid-combat /lura show registers chat events immediately (PLAYER_REGEN_DISABLED already passed)"
  - "D-25: no auto-show on chat (WIN-04); chat handler never calls win:Show()"
  - "D-27: sequence is a Lua local upvalue, NOT in TerribleLuraHelperDB"
  - "D-28: INACTIVITY_TIMEOUT bumped from POC's 15s → 20s"
  - "D-29: timer literal lives as named constant for v2 promotion"
  - "D-30: only C_ChatInfo.ReplaceIconAndGroupExpressions — POC's ChatFrame_ alias fallback dropped"
  - "D-31: channel filter via db.listenChannels[event:sub(10)] (event op, NOT msg op — SAFE-02 still respected)"
  - "D-32: combat+enabled truth table; PLAYER_REGEN_DISABLED registers iff db.enabled, PLAYER_REGEN_ENABLED always unregisters"
  - "D-36: db.window.alpha read once at frame creation (live-update slider is Phase 3)"
  - "SAFE-01: zero SendChatMessage call sites (verified repo-wide)"
  - "SAFE-02: zero msg-string-ops in chat handler (msg flows opaquely through Blizzard-secure helper)"
  - "SAFE-04: chat events registered only when (db.enabled AND combat-active)"
metrics:
  duration_minutes: 8
  completed_date: "2026-04-30"
  tasks_completed: 3
  files_modified: 1
---

# Phase 2 Plan 02: Helper Window Summary

**One-liner:** Full smile-arc helper window — BasicFrameTemplateWithInset chrome, 5-slot arc verbatim from POC, lock button left of CloseButton, drag-with-persistence, 20s self-clear, taint-safe chat pipeline with channel filter, combat-gated event registration, 8 `ns.*` exports for the 02-03 slash dispatcher.

## What Was Built

### Window.lua — full implementation (was a 10-line stub)

A single 348-line module that ports POC lines 90–271 with explicit deviations and 3 module-level structural additions (combat gating frame, channel filter, position persistence helpers).

#### Frame chrome (D-17, D-19)

`CreateFrame("Frame", "TerribleLuraHelperWindow", UIParent, "BasicFrameTemplateWithInset")` — 380×320, mouse-enabled, clamped to screen, hidden by default. Template provides title bar + close button + rock/marble backdrop; POC's purple `SetBackdrop*Color` calls and `SetFrameStrata("HIGH")` dropped per D-17 / UI-SPEC §4. Title text set via `win.TitleText:SetText("Terrible L'ura Helper")` with no color override (D-19). Close-button OnClick rebound to `win:Hide()` only.

#### Smile-arc layout (D-18)

`SLOT_POS` table (5 entries: `{110,32}, {80,-28}, {0,-60}, {-80,-28}, {-110,32}`) ports verbatim from POC lines 125–131. `SLOT_SIZE = 64`, `ICON_SIZE = 56`, BOSS at 18pt OUTLINE, TANK at 14pt OUTLINE, slot index labels at GameFontNormalSmall. Slot backdrops use `BackdropTemplate` with `WHITE8x8` fill+border, unfilled tint `(0.05, 0.05, 0.1, 0.7)` / border `(0.3, 0.2, 0.5, 0.7)`, filled accent `(0.85, 0.4, 1.0, 0.9)` — every color tuple verbatim from POC.

#### Lock button (D-14, D-15, D-16, UI-SPEC §3.1)

20×20 button anchored `TOPRIGHT, win.CloseButton, TOPLEFT, +2, 0`. Highlight texture `Interface\Buttons\UI-Common-MouseHilight` (ADD blend). Normal/Pushed textures swap via `applyLockState()` between `LockButton-Locked-{Up,Down}` and `LockButton-Unlocked-{Up,Down}`. Click → `ns:ToggleLocked()` flips `db.window.locked` and re-applies state.

#### Drag + position persistence (D-20, D-21, D-22, WIN-09)

OnDragStart guards on `IsMovable()`; OnDragStop calls `StopMovingOrSizing` then `persistPosition()`. Persisted as 5-tuple `{point, relativeToName, relativePoint, x, y}` where `relativeToName` is a **string** (`relativeTo:GetName()` or `"UIParent"`) — never a frame ref. `applySavedPosition()` runs once on first show via `positionApplied` latch; if `db.window.position` exists, applies via `_G[pos[2]] or UIParent` fallback; else defaults to `CENTER UIParent CENTER 200 80`.

#### 20s inactivity self-clear (D-28, D-29, UI-SPEC §3.4)

`local INACTIVITY_TIMEOUT = 20` near top of file. `ScheduleClear()` cancels any in-flight timer and starts a fresh `C_Timer.NewTimer(INACTIVITY_TIMEOUT, ...)` whose callback runs `ClearAll()` and nils the handle. `ManualClear()` cancels + clears synchronously (called by `ns:WipeSequence`).

#### Chat pipeline (D-30, D-31, SAFE-01, SAFE-02)

Dedicated `chatFrame` (separate frame, not the combatFrame). Handler signature `(self, event, msg)`:
1. Channel filter: `if not ns.db.listenChannels[event:sub(10)] then return end` — `event:sub(10)` strips `CHAT_MSG_` (9 chars). String op on EVENT, not on MSG (D-31 / SAFE-02 explicit safe).
2. Opaque pass-through: `local processed = C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` — no fallback alias (D-30 drops POC's `ChatFrame_ReplaceIconAndGroupExpressions`).
3. 6th-press wraparound: `if #sequence >= 5 then ClearAll() end`; then `sequence[#sequence + 1] = processed; FillSlot(#sequence, processed); ScheduleClear()`.
4. **No** `win:Show()` call (D-25 / WIN-04 — visibility is /lura-only).

#### Combat-gated event registration (D-23, D-32, SAFE-04)

`combatFrame` self-arms at file load (registers `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED`). Handler:
- `PLAYER_REGEN_DISABLED` → `if ns.db.enabled then ns:RegisterChatEvents() end`
- `PLAYER_REGEN_ENABLED` → `ns:UnregisterChatEvents()` (always; idempotent)

`ns:ShowWindow()` covers the D-23 mid-combat case: if `ns.db.enabled and InCombatLockdown()`, registers immediately so `/lura show` mid-fight catches subsequent markers.

### Eight `ns.*` exports (the surface 02-03 binds to)

| Export | Precondition | Behavior |
|--------|-------------|----------|
| `ns:InitWindow()` | Called by Core.lua's ADDON_LOADED dispatcher (already wired in Phase 1) | Builds the frame; combatFrame is already self-armed at load. |
| `ns:ShowWindow()` | `InitWindow` ran (frame exists) | Applies saved position on first call (latched), runs `win:Show()`, registers chat events if mid-combat-and-enabled (D-23). |
| `ns:HideWindow()` | `InitWindow` ran | Runs `win:Hide()` only — does NOT wipe sequence (per D-24 separation; `/lura hide` calls `WipeSequence` separately). |
| `ns:WipeSequence()` | `InitWindow` ran | Cancels timer + clears slot displays + wipes sequence table. |
| `ns:RegisterChatEvents()` | `InitWindow` ran (chatFrame exists) | Registers all 6 CHAT_MSG_* events on chatFrame. |
| `ns:UnregisterChatEvents()` | `InitWindow` ran | Unregisters all 6 CHAT_MSG_* events on chatFrame. |
| `ns:ToggleLocked()` | `InitWindow` ran (lockBtn exists) | Flips `db.window.locked`, swaps textures, rebinds drag via `applyLockState`. |
| `ns:IsWindowShown()` | Safe to call any time | Returns `win and win:IsShown() or false`. |

## Commits

| Task | Commit | Files | Description |
|------|--------|-------|-------------|
| 1 + 2 + 3 | `e01a50b` | Window.lua | feat(02): helper window — smile-arc + lock + chat pipe + 20s clear (WIN-01..06, WIN-09, SAFE-01..04) |

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| 1. Stylua | `stylua --check Window.lua` | PASS |
| 2. No SendChatMessage | `! grep -rE 'SendChatMessage' *.lua` | PASS (zero matches repo-wide) |
| 3. No msg string ops | `! grep -rnE 'msg:(gsub\|match\|find\|len\|sub\|format\|rep)' *.lua` | PASS (zero matches repo-wide) |
| 4. No auto-show on chat | `! grep -q 'if not win:IsShown' Window.lua` | PASS |
| 5. No POC ChatFrame_ alias | `! grep -q 'ChatFrame_ReplaceIconAndGroupExpressions' Window.lua` | PASS |
| 6. Modern API present | `grep -q 'C_ChatInfo.ReplaceIconAndGroupExpressions' Window.lua` | PASS (3 hits: 2 in comments, 1 in code) |
| 7. BasicFrameTemplateWithInset | `grep -q 'BasicFrameTemplateWithInset' Window.lua` | PASS (2 hits: comment + CreateFrame) |
| 8. Config.lua untouched | `git diff Config.lua` | PASS (empty diff; only Window.lua changed) |

### Granular acceptance-criteria checks (27 total — all PASS)

Smile-arc geometry: SLOT_SIZE=64, slot1 `{ 110, 32 }`, slot5 `{ -110, 32 }`, FRIZQT font.
Slot colors: unfilled fill `(0.05, 0.05, 0.1, 0.7)`, unfilled border `(0.3, 0.2, 0.5, 0.7)`, filled accent `(0.85, 0.4, 1.0, 0.9)`.
Lock button: `SetPoint("TOPRIGHT", win.CloseButton, "TOPLEFT", 2, 0)`, 20×20, `LockButton-Locked-Up`, `LockButton-Unlocked-Up`, `UI-Common-MouseHilight`.
Position persistence: `OnDragStart`, `OnDragStop`, `ns.db.window.position`, `_G[*] or UIParent`, default `CENTER UIParent CENTER 200 80`, `SetClampedToScreen(true)`.
Alpha + scale: `win:SetAlpha(ns.db.window.alpha)`, `win:SetScale(ns.db.window.scale)`.
Chat pipeline: exact signature `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)`, channel filter `ns.db.listenChannels[event:sub(10)]`.
Timing: `INACTIVITY_TIMEOUT = 20`, `C_Timer.NewTimer(INACTIVITY_TIMEOUT, ...)`.
Combat gating: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `InCombatLockdown()`.
Wraparound: `#sequence >= 5`.
All 6 chat events present: SAY, RAID, RAID_LEADER, RAID_WARNING, INSTANCE_CHAT, INSTANCE_CHAT_LEADER.
All 8 `ns.*` exports defined.
In-memory only: `local sequence = {}` present, `ns.db.sequence`/`TerribleLuraHelperDB.sequence` absent.
Negatives: no `SetFrameStrata`, no POC purple `SetBackdropColor(0.04`, no `SetBackdropBorderColor(0.5, 0.0, 0.9`, no `win:SetTextColor(0.85, 0.4, 1.0)`.

## Deviations from Plan

None — plan executed exactly as written. Tasks 1 and 2 were combined into a single Write operation (the plan organized them as separate Edit sequences for clarity, but a fresh-file Write is equivalent and easier to verify in one pass). Stylua reformatted the SLOT_POS literals' inner whitespace from `{   80, -28 }` to `{ 80, -28 }` (single space), which is cosmetic — coordinate values are byte-for-byte identical and the verification grep `\{ 110, 32 \}` matches the post-stylua format.

## POC Line Ranges Ported

- POC 90–110 → CreateWindow chrome (with D-17 swap to BasicFrameTemplateWithInset, dropped SetBackdrop*Color/SetFrameStrata)
- POC 112–119 → template's TitleText + CloseButton (no manual create; OnClick rebound)
- POC 121–178 → bossView + BOSS/TANK labels + 5-slot loop (verbatim including SLOT_POS, font calls, slot backdrop spec, slot index labels)
- POC 180–194 → FillSlot + ClearAll (verbatim — `wipe(sequence)` + per-slot SetText/SetBackdropBorderColor)
- POC 196–220 → ScheduleClear + ManualClear (verbatim except `15` → `INACTIVITY_TIMEOUT = 20` per D-28)
- POC 240–271 → CHAT_EVENTS table + chat handler (with 3 deviations: dropped POC-line-250 fallback alias per D-30, dropped POC-line-270 auto-show per D-25, added channel filter per D-31)

## POC Patterns Deliberately NOT Ported (with decision IDs)

- POC purple BackdropTemplate + `SetBackdropColor(0.04, 0.0, 0.13, 0.9)` + `SetBackdropBorderColor(0.5, 0.0, 0.9, 1.0)` → DROPPED per D-17 (BasicFrameTemplateWithInset supplies its own background)
- POC `title:SetTextColor(0.85, 0.4, 1.0)` → DROPPED per D-19 (template default title color)
- POC `win:SetFrameStrata("HIGH")` → DROPPED per UI-SPEC §4 (template's MEDIUM is correct)
- POC `if not win:IsShown() then win:Show() end` on chat reception → DROPPED per WIN-04 / D-25
- POC `ChatFrame_ReplaceIconAndGroupExpressions` fallback alias → DROPPED per D-30
- POC 15s `C_Timer.NewTimer` literal → CHANGED to `INACTIVITY_TIMEOUT = 20` per D-28/D-29
- POC `scriptFrame._luraSeq` cross-reload sequence persistence → REMOVED per D-27 / WIN-07-dropped (sequence is a Lua local now)
- POC direct `RegisterEvent` on parent script frame → REPLACED with dedicated `chatFrame` + combat gating per SAFE-04 / D-32

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced beyond what the plan's `<threat_model>` already declared. The four threats in the plan's STRIDE register are all mitigated or accepted as documented:

- T-MSG-OPAQUE (mitigate): repo-wide grep for `msg:(gsub|match|find|len|sub)` returns empty. The chat handler line that touches `msg` is exactly: `local processed = C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` — opaque pass-through to a Blizzard-secure helper.
- T-CHAT-FALLBACK (mitigate): `ChatFrame_ReplaceIconAndGroupExpressions` absent from Window.lua and from the entire repo.
- T-COMBAT-LOCKDOWN (accept): Window.lua never calls protected APIs; combat gating here is purely behavioral.
- T-CHANNEL-EVENT-SUBSTRING (accept): `event:sub(10)` operates on the Blizzard-supplied event name (a finite known-good set), not on `msg`. Missing key in `db.listenChannels` returns nil → falsy → event dropped (safe default).
- T-POSITION-FALLBACK (mitigate): SavedVariables tampering is out of standard threat model; `or UIParent` fallback prevents nil-global crash; SetPoint with non-frame errors gracefully.

## Handoff to 02-03

`Window.lua` exports the full 8-method `ns.*` surface that the slash-command dispatcher needs. Plan 02-03 should bind:

- `/lura show` → `ns.db.enabled = true; ns:ShowWindow()` (then if NOT in combat, do nothing extra — `PLAYER_REGEN_DISABLED` will register events at next combat-start; if in combat, `ns:ShowWindow` already registered them via D-23)
- `/lura hide` → `ns.db.enabled = false; ns:UnregisterChatEvents(); ns:WipeSequence(); ns:HideWindow()`
- `/lura` (toggle) → use `ns.db.enabled` to dispatch to one of the above
- `/lura config` → stub print "Config panel lands in Phase 3."
- `/lura help` → print colored slash-command list per UI-SPEC §5.4
- `/tlh` → alias

The combatFrame in Window.lua is self-arming and will not need any wiring from 02-03.

## Self-Check: PASSED

- `C:\Users\jonat\Repositories\TerribleLuraHelper\Window.lua` — exists (348 lines), contains `BasicFrameTemplateWithInset`, all 8 `ns.*` exports, and the exact `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` signature.
- Commit `e01a50b` exists on `milestone/0.1.0` with message starting `feat(02): helper window`.
- `Core.lua`, `Macros.lua`, `Config.lua` unmodified vs. previous commit (verified via `git diff --name-only HEAD~1 HEAD` showing only `Window.lua`).
- `stylua --check Window.lua` exits 0.
- Repo-wide grep for `SendChatMessage` and `msg:(gsub|match|find|len|sub|format|rep)` returns empty.
