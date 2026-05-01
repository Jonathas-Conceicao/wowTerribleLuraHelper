# Roadmap: TerribleLuraHelper

## Overview

TerribleLuraHelper ports a working WeakerScripts POC (`LuraPatternHelper.lua`, 297 lines) into a standalone WoW Midnight addon and adds a config panel under Options > AddOns. The journey is short and goal-shaped: stand up the project skeleton (mirroring TerribleBuffTracker's release pipeline) so the addon loads, then lift the POC's chat-pipe + smile-arc UI + macros into the addon while adding the new `/lura hide` = "disable processing" semantics, and finally wrap it all in a Settings-API-driven config panel that wires the channel filters, scale slider, auto-hide toggle, and action buttons through to the runtime. All milestone work lives on a `milestone/0.1.0` branch and is squash-merged to `main`.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Scaffolding & Foundation** - Repo skeleton, `.toc`, packager pipeline, namespace, SavedVariables init; addon loads as a no-op and prints its load banner
- [x] **Phase 2: POC Port (Macros, Window, Commands)** - Lift POC behavior into the addon; macros, smile-arc helper window, slash commands, chat-event piggyback, `/lura show/hide` enable/disable semantics, all taint-safety constraints upheld
- [~] **Phase 3: Config Panel & Integration** - Settings API panel under Options > AddOns wires channel filters, scale slider, auto-hide toggle, and the two action buttons through to the runtime; `/lura config` opens the panel directly. *Plan 03-01 Tasks 1–5 implemented; Task 6 in-game smoke verification PENDING.*

## Phase Details

### Phase 1: Scaffolding & Foundation
**Goal**: A loadable, no-op TerribleLuraHelper addon ships from a repo whose layout, packaging pipeline, and conventions mirror TerribleBuffTracker, and whose first milestone branch is open.
**Depends on**: Nothing (first phase)
**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05, SCAF-06, SCAF-07, SCAF-08, SCAF-09, SCAF-10, SCAF-11, SCAF-12
**Success Criteria** (what must be TRUE):
  1. After running `./scripts/install.bat` and `/reload` in WoW, the addon loads and prints a colored `TerribleLuraHelper loaded.` banner in chat — no errors, no missing-file warnings, no unrecognized-addon entry.
  2. The repo's working state lives on a `milestone/0.1.0` branch (created from `main` and pushed); `main` is untouched until squash-merge.
  3. After a `/reload` round-trip, `TerribleLuraHelperDB` exists in `WTF/Account/.../SavedVariables/TerribleLuraHelperDB.lua` populated with the v1 default keys per CONTEXT.md D-03 grouped schema (`enabled = false`; `listenChannels` table with all six channels = `true`; `window = { scale = 1.00, locked = true, autoHide = false, position = nil }`; `sequence = {}`).
  4. **Per CONTEXT.md D-06, Phase 1 does NOT push a v0.0.1 tag.** Instead: `release.yml` is committed with the CHANGELOG-cutoff awk present, and `scripts/release.bat <version>` works from any branch (D-08 — parameterized push to current branch, not hardcoded `main`). The pipeline's first live exercise is the v0.1.0 milestone-merge tag.
  5. `CLAUDE.md` exists at the repo root and documents: the chat-lockdown / no-msg-processing / no-`SendChatMessage` hard constraints, the `milestone/<version>` + squash-merge workflow rule, the `stylua` formatting rule, the architecture file map, and the wow-ui-source style reference path.

**Plans:** 3/3 plans complete
- [x] 01-01-PLAN.md — Open milestone/0.1.0 branch + repo skeleton (.gitignore, .luarc.json, LICENSE, README, CHANGELOG, verify CLAUDE.md)
- [x] 01-02-PLAN.md — Addon scaffolding (.toc, Core.lua with grouped DB schema, stub Macros/Window/Config modules)
- [x] 01-03-PLAN.md — Release pipeline (.pkgmeta, GHA workflow with CHANGELOG cutoff, install.bat, release.bat with current-branch fix)

### Phase 2: POC Port (Macros, Window, Commands)
**Goal**: Every behavior proven in `WeakerScripts/Samples/LuraPatternHelper.lua` runs inside the standalone addon, plus the new `/lura hide` = "disable processing entirely" semantics that the POC doesn't have. The five rune slots fill in arrival order during boss combat without violating any taint constraint.
**Depends on**: Phase 1
**Requirements**: MACR-01, MACR-02, MACR-03, MACR-04, MACR-05, WIN-01, WIN-02, WIN-03, WIN-04, WIN-05, WIN-06, WIN-09, CMD-01, CMD-02, CMD-03, CMD-06, CMD-07, SAFE-01, SAFE-02, SAFE-03, SAFE-04
*(Phase 2 discuss amendments: WIN-07 dropped — sequence is in-memory only; CMD-04 dropped — folded into `/lura hide`; CMD-07 added — `/lura help`. Window alpha plumbing is part of WIN frame setup; the alpha slider lives in Phase 3 / WIN-10 / CFG-10.)*
**Success Criteria** (what must be TRUE):
  1. On first login (out of combat), opening `/macro` shows five player macros named `TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T` with raid-marker icons; logging in mid-combat creates them on the next `PLAYER_REGEN_ENABLED`; subsequent logins update them in place (no duplicates).
  2. After `/lura show` during a raid combat encounter, pressing the five dragged-to-action-bar macros in order fills slots 1 through 5 of the smile-arc display with the corresponding raid-marker icons (rendered via `C_ChatInfo.ReplaceIconAndGroupExpressions`); a 6th press clears all and refills at slot 1; **20 seconds of silence self-clears the display** (amended from 15s during Phase 2 discuss); **sequence is in-memory only — `/reload` clears it**.
  3. `/lura show`, `/lura hide`, `/lura` (toggle), `/lura help`, and the `/tlh` alias all behave as specified — and crucially, `/lura hide` while in combat causes the next chat marker received to be ignored (no slot fill, no sequence growth) until the user issues `/lura show` again. **`/lura hide` also wipes the in-memory sequence.**
  4. The window is hidden by default on every login and `/reload` (no auto-show on chat, no remembered visibility), is draggable only when unlocked via the on-window lock button, and never opens except in response to `/lura` or `/lura show`.
  5. A repo-wide grep at PR time finds zero call sites of `SendChatMessage`, and zero call sites that index/length-check/`gsub`/`match`/concatenate/pattern-test the `msg` argument from any `CHAT_MSG_*` event handler; chat events are registered only while the helper window is visible (post-execution amendment AMEND-01: visibility-gated replaced the original combat-gated model; see `02-VERIFICATION.md` frontmatter); `CreateMacro`/`EditMacro` calls are guarded by `InCombatLockdown()` with a `PLAYER_REGEN_ENABLED` retry path.

**Plans:** 3/3 plans complete
- [x] 02-01-PLAN.md — Schema cleanup + Macros (Core.lua schema amendment for D-27/D-35..37; Macros.lua verbatim port of POC 42-78 with combat-lockdown deferral) — MACR-01..05, SAFE-03
- [x] 02-02-PLAN.md — Helper Window (Window.lua: BasicFrameTemplateWithInset frame, smile-arc 5 slots, lock button, drag-position persistence, taint-safe chat pipeline with channel filter, 20s self-clear) — WIN-01..06, WIN-09, SAFE-01, SAFE-02, SAFE-04
- [x] 02-03-PLAN.md — Slash commands & state machine (Core.lua: SLASH_LURA + SLASH_TLH + dispatcher routing show/hide/help/config/toggle to ns:Enable/Disable per D-23..D-26) — CMD-01..03, CMD-06, CMD-07
**UI hint**: yes

### Phase 3: Config Panel & Integration
**Goal**: A `Settings.RegisterAddOnCategory`-registered panel under Options > AddOns surfaces every v1 configuration knob (six channel toggles, scale slider, auto-hide toggle, two action buttons, command-examples block), and every change in the panel takes immediate effect on the live addon and persists across `/reload`.
**Depends on**: Phase 2
**Requirements**: CFG-01, CFG-02, CFG-03, CFG-04, CFG-05, CFG-06, CFG-07, CFG-08, CFG-09, CFG-10, CFG-11, CMD-05, WIN-08, WIN-10
*(Added during Phase 2 UI-SPEC review: CFG-10 alpha slider + WIN-10 window alpha live update.)*
*(Added during Phase 3 UI-SPEC review: CFG-11 macro target channel dropdown.)*
**Success Criteria** (what must be TRUE):
  1. Pressing Esc and navigating to Options > AddOns shows a `TerribleLuraHelper` entry; opening it reveals — in vertical layout — a "Chat channels" section with six checkboxes (SAY / RAID / RAID_LEADER / RAID_WARNING / INSTANCE / INSTANCE_LEADER), a "Window" section with a 0.50–2.00 scale slider and an "Auto-hide when empty" checkbox, an "Actions" section with "Recreate Macros" and "Lock/Unlock window" buttons, and a "Slash commands" help block listing `/lura`, `/lura show`, `/lura hide`, `/lura clear`, `/lura config`, and `/tlh`.
  2. `/lura config` (and `/tlh config`) opens the panel directly to the TerribleLuraHelper category via `Settings.OpenToCategory(category:GetID())`.
  3. Toggling a channel checkbox while in raid combat causes that channel's incoming marker messages to be ignored at the chat-event handler (no slot fill, no sequence update) without unregistering the underlying chat event; toggling it back resumes filling.
  4. Dragging the scale slider live-updates the helper window's scale without closing the panel; clicking "Recreate Macros" re-runs macro registration (with the same combat-lockdown deferral and informational print as Phase 2's path); clicking the lock button toggles drag-lock and updates the button label on next panel show; "Auto-hide when empty" causes the window to hide while the sequence is empty (including post-15s-clear) and reappear when slot 1 next fills.
  5. All settings (six channel flags, scale, auto-hide, lock state) survive `/reload` and full game-session restarts via `TerribleLuraHelperDB`, with values written through automatically by the `Settings.RegisterAddOnSetting` framework — no addon-side direct writes to the DB from the panel callbacks.

**Plans:** 1/1 plans complete
- [~] 03-01-PLAN.md — Single-plan delivery (per CONTEXT.md D-31): Core.lua schema (db.macroChannel default + backfill) + slash dispatcher (lock/unlock/config) + ns:PrintHelp rewrite; Window.lua soft-hide state machine + 5 new exports (SetWindowScale/SetWindowAlpha/OnAutoHideChanged/LockWindow/UnlockWindow); Macros.lua dynamic body construction via CHANNEL_PREFIX[db.macroChannel] + ns:OnMacroChannelChanged; Config.lua full Settings-API panel (4 sections: Chat channels, Window, Macros, Slash commands) with EventUtil deferral. Covers all 14 Phase 3 requirement IDs (CFG-01..11, CMD-05, WIN-08, WIN-10). **Code complete; in-game smoke pass (Task 6) is the gate before phase close.**
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaffolding & Foundation | 3/3 | Complete    | 2026-04-30 |
| 2. POC Port (Macros, Window, Commands) | 3/3 | Complete    | 2026-05-01 |
| 3. Config Panel & Integration | 1/1 | Complete    | 2026-05-01 |
