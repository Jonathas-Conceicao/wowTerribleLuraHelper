# Roadmap: TerribleLuraHelper

## Overview

TerribleLuraHelper ports a working WeakerScripts POC (`LuraPatternHelper.lua`, 297 lines) into a standalone WoW Midnight addon and adds a config panel under Options > AddOns. The journey is short and goal-shaped: stand up the project skeleton (mirroring TerribleBuffTracker's release pipeline) so the addon loads, then lift the POC's chat-pipe + smile-arc UI + macros into the addon while adding the new `/lura hide` = "disable processing" semantics, and finally wrap it all in a Settings-API-driven config panel that wires the channel filters, scale slider, auto-hide toggle, and action buttons through to the runtime. All milestone work lives on a `milestone/0.1.0` branch and is squash-merged to `main`.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Scaffolding & Foundation** - Repo skeleton, `.toc`, packager pipeline, namespace, SavedVariables init; addon loads as a no-op and prints its load banner
- [ ] **Phase 2: POC Port (Macros, Window, Commands)** - Lift POC behavior into the addon; macros, smile-arc helper window, slash commands, chat-event piggyback, `/lura show/hide` enable/disable semantics, all taint-safety constraints upheld
- [ ] **Phase 3: Config Panel & Integration** - Settings API panel under Options > AddOns wires channel filters, scale slider, auto-hide toggle, and the two action buttons through to the runtime; `/lura config` opens the panel directly

## Phase Details

### Phase 1: Scaffolding & Foundation
**Goal**: A loadable, no-op TerribleLuraHelper addon ships from a repo whose layout, packaging pipeline, and conventions mirror TerribleBuffTracker, and whose first milestone branch is open.
**Depends on**: Nothing (first phase)
**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05, SCAF-06, SCAF-07, SCAF-08, SCAF-09, SCAF-10, SCAF-11, SCAF-12
**Success Criteria** (what must be TRUE):
  1. After running `./scripts/install.bat` and `/reload` in WoW, the addon loads and prints a colored `TerribleLuraHelper loaded.` banner in chat — no errors, no missing-file warnings, no unrecognized-addon entry.
  2. The repo's working state lives on a `milestone/0.1.0` branch (created from `main` and pushed); `main` is untouched until squash-merge.
  3. After a `/reload` round-trip, `TerribleLuraHelperDB` exists in `WTF/Account/.../SavedVariables/TerribleLuraHelperDB.lua` populated with the v1 default keys (channels table with all six set to `true`, `scale = 1.00`, `autoHide = false`, `locked = true`, `enabled = false`).
  4. Pushing a tag of the form `v0.0.1` triggers the `release.yml` GitHub Actions workflow, which runs BigWigs Packager and produces a CurseForge/Wago/GitHub release ZIP whose root folder is named `TerribleLuraHelper`.
  5. `CLAUDE.md` exists at the repo root and documents: the chat-lockdown / no-msg-processing / no-`SendChatMessage` hard constraints, the `milestone/<version>` + squash-merge workflow rule, the `stylua` formatting rule, the architecture file map, and the wow-ui-source style reference path.
**Plans**: TBD

### Phase 2: POC Port (Macros, Window, Commands)
**Goal**: Every behavior proven in `WeakerScripts/Samples/LuraPatternHelper.lua` runs inside the standalone addon, plus the new `/lura hide` = "disable processing entirely" semantics that the POC doesn't have. The five rune slots fill in arrival order during boss combat without violating any taint constraint.
**Depends on**: Phase 1
**Requirements**: MACR-01, MACR-02, MACR-03, MACR-04, MACR-05, WIN-01, WIN-02, WIN-03, WIN-04, WIN-05, WIN-06, WIN-07, CMD-01, CMD-02, CMD-03, CMD-04, CMD-06, SAFE-01, SAFE-02, SAFE-03, SAFE-04
**Success Criteria** (what must be TRUE):
  1. On first login (out of combat), opening `/macro` shows five player macros named `TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T` with raid-marker icons; logging in mid-combat creates them on the next `PLAYER_REGEN_ENABLED`; subsequent logins update them in place (no duplicates).
  2. After `/lura show` during a raid combat encounter, pressing the five dragged-to-action-bar macros in order fills slots 1 through 5 of the smile-arc display with the corresponding raid-marker icons (rendered via `C_ChatInfo.ReplaceIconAndGroupExpressions`); a 6th press clears all and refills at slot 1; 15 seconds of silence self-clears the display; the sequence persists across `/reload`.
  3. `/lura show`, `/lura hide`, `/lura` (toggle), `/lura clear`, and the `/tlh` alias all behave as specified — and crucially, `/lura hide` while in combat causes the next chat marker received to be ignored (no slot fill, no sequence growth) until the user issues `/lura show` again.
  4. The window is hidden by default on every login and `/reload` (no auto-show on chat, no remembered visibility), is draggable only when unlocked via the on-window lock button, and never opens except in response to `/lura` or `/lura show`.
  5. A repo-wide grep at PR time finds zero call sites of `SendChatMessage`, and zero call sites that index/length-check/`gsub`/`match`/concatenate/pattern-test the `msg` argument from any `CHAT_MSG_*` event handler; chat events are registered only while the addon is enabled AND combat is active; `CreateMacro`/`EditMacro` calls are guarded by `InCombatLockdown()` with a `PLAYER_REGEN_ENABLED` retry path.
**Plans**: TBD
**UI hint**: yes

### Phase 3: Config Panel & Integration
**Goal**: A `Settings.RegisterAddOnCategory`-registered panel under Options > AddOns surfaces every v1 configuration knob (six channel toggles, scale slider, auto-hide toggle, two action buttons, command-examples block), and every change in the panel takes immediate effect on the live addon and persists across `/reload`.
**Depends on**: Phase 2
**Requirements**: CFG-01, CFG-02, CFG-03, CFG-04, CFG-05, CFG-06, CFG-07, CFG-08, CFG-09, CMD-05, WIN-08
**Success Criteria** (what must be TRUE):
  1. Pressing Esc and navigating to Options > AddOns shows a `TerribleLuraHelper` entry; opening it reveals — in vertical layout — a "Chat channels" section with six checkboxes (SAY / RAID / RAID_LEADER / RAID_WARNING / INSTANCE / INSTANCE_LEADER), a "Window" section with a 0.50–2.00 scale slider and an "Auto-hide when empty" checkbox, an "Actions" section with "Recreate Macros" and "Lock/Unlock window" buttons, and a "Slash commands" help block listing `/lura`, `/lura show`, `/lura hide`, `/lura clear`, `/lura config`, and `/tlh`.
  2. `/lura config` (and `/tlh config`) opens the panel directly to the TerribleLuraHelper category via `Settings.OpenToCategory(category:GetID())`.
  3. Toggling a channel checkbox while in raid combat causes that channel's incoming marker messages to be ignored at the chat-event handler (no slot fill, no sequence update) without unregistering the underlying chat event; toggling it back resumes filling.
  4. Dragging the scale slider live-updates the helper window's scale without closing the panel; clicking "Recreate Macros" re-runs macro registration (with the same combat-lockdown deferral and informational print as Phase 2's path); clicking the lock button toggles drag-lock and updates the button label on next panel show; "Auto-hide when empty" causes the window to hide while the sequence is empty (including post-15s-clear) and reappear when slot 1 next fills.
  5. All settings (six channel flags, scale, auto-hide, lock state) survive `/reload` and full game-session restarts via `TerribleLuraHelperDB`, with values written through automatically by the `Settings.RegisterAddOnSetting` framework — no addon-side direct writes to the DB from the panel callbacks.
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaffolding & Foundation | 0/TBD | Not started | - |
| 2. POC Port (Macros, Window, Commands) | 0/TBD | Not started | - |
| 3. Config Panel & Integration | 0/TBD | Not started | - |
