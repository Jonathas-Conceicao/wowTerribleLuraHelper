# Requirements: TerribleLuraHelper

**Defined:** 2026-04-30
**Core Value:** The five runes that L'ura shows must arrive — in the right order — on every raid member's screen, during the boss-fight chat-messaging-lockdown that blocks normal addon chat output.

## v1 Requirements

### Project Scaffolding

- [x] **SCAF-01
**: `.toc` declares `Interface 120005`, `TerribleLuraHelperDB` SavedVariables, BigWigs packager hooks (`@project-version@`, optional `X-Curse-Project-ID` / `X-Wago-ID`), and lists every Lua file in load order
- [x] **SCAF-02
**: Namespace pattern `local addonName, ns = ...` is shared across all Lua files (matches TerribleBuffTracker)
- [x] **SCAF-03
**: SavedVariables key `TerribleLuraHelperDB` is initialized on `ADDON_LOADED` with the grouped default schema: `enabled=false`, `listenChannels.{SAY,RAID,RAID_LEADER,RAID_WARNING,INSTANCE_CHAT,INSTANCE_CHAT_LEADER}=true`, `window={scale=1.00, locked=true, autoHide=false, position=nil}`, `sequence={}`. Backfills new keys on existing DBs (matches TBT pattern). **Phase 2 amends:** drops `sequence` (in-memory only per D-27), adds `window.alpha=1.00` (per WIN-10).
- [x] **SCAF-04
**: `.pkgmeta` configures BigWigs Packager with `package-as: TerribleLuraHelper`, manual changelog from `RELEASE_NOTES.md`, and ignore list (gitignore, pkgmeta, CHANGELOG, CLAUDE, README, LICENSE, scripts, png, RELEASE_NOTES)
- [x] **SCAF-05
**: `.gitignore` excludes `*.zip`, `.claude/`, and emacs swap files (mirrors TBT)
- [x] **SCAF-06
**: `.luarc.json` configures Lua 5.1 runtime and `vscode-wow-api` workspace library
- [x] **SCAF-07
**: `scripts/install.bat` copies all addon files to `_retail_/Interface/AddOns/TerribleLuraHelper`
- [x] **SCAF-08
**: `scripts/release.bat <version>` tags `v<version>` and pushes; GitHub Actions handles packaging
- [x] **SCAF-09
**: `.github/workflows/release.yml` runs BigWigs Packager on tag push and extracts the current `## ` section from `CHANGELOG.md` into `RELEASE_NOTES.md`
- [x] **SCAF-10
**: `CHANGELOG.md`, `README.md`, `LICENSE` exist at repo root
- [x] **SCAF-11
**: `CLAUDE.md` documents the project, hard constraints (chat-lockdown / no-msg-processing / no-SendChatMessage), workflow rules (`milestone/<version>` branch, squash-merge, run `stylua`), and architecture file map
- [x] **SCAF-12
**: All work for the v1 milestone happens on a `milestone/0.1.0` branch and is squash-merged to `main`

### Macros

- [x] **MACR-01
**: Five named player macros (`TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T`) are created on first load, each with body `/raid {rt#}` and a Blizzard built-in raid-marker FileDataID icon (Diamond=137003, Triangle=137004, Circle=137002, Cross=137007, T=137001)
- [x] **MACR-02
**: Existing macros with the TLH names are updated in place (idempotent body+icon refresh) on every login — never duplicated
- [x] **MACR-03
**: If `InCombatLockdown()` is true on load, macro registration is deferred to `PLAYER_REGEN_ENABLED`
- [x] **MACR-04
**: A "Recreate Macros" button in the config panel re-runs registration on demand (with the same combat-lockdown deferral behavior)
- [x] **MACR-05
**: First successful registration of the session prints a one-time chat hint reminding the user to drag the macros from `/macro` onto their action bar

### Helper Window

- [x] **WIN-01**: Window contains five positional rune slots arranged in a smile-arc, with a `BOSS` label centered and a `TANK` label opposite slot 3 (mirrors POC)
- [x] **WIN-02**: Slots fill in the order chat messages arrive (1 → 5); a 6th message clears all slots and begins refilling at slot 1
- [x] **WIN-03**: Each slot renders the raid marker as a `FontString` whose text is set directly from `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` — no addon-side string operations on `msg`
- [x] **WIN-04**: Window is hidden by default on every login/reload (no remembered visibility state, no auto-show on chat); only `/lura show` (or `/lura` toggling from hidden) reveals it
- [x] **WIN-05**: Window has a visible lock/unlock button on its frame; when unlocked the window is draggable, when locked drag is disabled
- [x] **WIN-06**: Slot display self-clears 20 seconds after the most recent chat message (timer hardcoded for v1; amended from 15s during Phase 2 discuss)
- [ ] ~~**WIN-07**: Sequence persists across `/reload`~~ — DROPPED in Phase 2 discuss. Sequence is in-memory only (Lua local in Window.lua, not in `TerribleLuraHelperDB`). Cleared on `/lura hide`, on 20s inactivity timer, and on `/reload`. See OOS table for rationale.
- [x] **WIN-08**: Window scale honors the configured scale value (range 0.50–2.00, default 1.00) and updates live when the slider changes
- [x] **WIN-09**: Window position persists across `/reload` and full game-session restarts — written to `db.window.position` on drag-end and re-applied on first show; defaults to `CENTER UIParent CENTER 200 80` when no saved position exists
- [x] **WIN-10**: Window alpha honors `db.window.alpha` (range 0.20–1.00, default 1.00) — applied via `frame:SetAlpha(db.window.alpha)`; updates live when the config slider changes (slider lives in Phase 3 / CFG-10; Phase 2 reads the default at frame creation)

### Behavior States (Slash Commands)

- [x] **CMD-01**: `/lura show` flips addon state to **enabled** — registers chat events for combat (via `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`), shows window (subject to `auto-hide-when-empty`); if combat is already active, registers events immediately (mid-combat enable per D-23)
- [x] **CMD-02**: `/lura hide` flips addon state to **disabled** — unregisters / ignores chat events even during combat, hides window, **wipes the in-memory sequence** (per D-24/D-27)
- [x] **CMD-03**: `/lura` (no arg) toggles between enabled and disabled (pure toggle, no clever 3-state)
- [ ] ~~**CMD-04**: `/lura clear`~~ — DROPPED in Phase 2 discuss. `/lura hide` does a clean wipe + disable; the 20s inactivity timer auto-clears.
- [x] **CMD-05**: `/lura config` opens the addon's panel under Options > AddOns directly (via `Settings.OpenToCategory(category:GetID())`) — Phase 3 owns; Phase 2 stub prints "Config panel lands in Phase 3."
- [x] **CMD-06**: `/tlh` is a full alias for `/lura` (same arg parsing, same dispatch)
- [x] **CMD-07**: `/lura help` (and `/tlh help`) prints the slash command list to chat with brief per-command descriptions (added in Phase 2 discuss)

### Config Panel (Options > AddOns > TerribleLuraHelper)

- [x] **CFG-01**: Panel registered via `Settings.RegisterVerticalLayoutCategory` + `Settings.RegisterAddOnCategory` (NOT the deprecated `InterfaceOptions_AddCategory`); registration is gated on `EventUtil.ContinueOnAddOnLoaded`
- [x] **CFG-02**: Six checkboxes for per-channel listen toggles (SAY / RAID / RAID_LEADER / RAID_WARNING / INSTANCE / INSTANCE_LEADER), each bound to `TerribleLuraHelperDB` via `Settings.RegisterAddOnSetting`
- [x] **CFG-03**: Channel filter is applied at chat-event-handling time — events from disabled channels are ignored entirely (no slot fill, no sequence update); the registration set still includes all channels (filtering is by-flag, not by-registration)
- [x] **CFG-04**: Slider for window scale (range 0.50–2.00, default 1.00, step 0.05); change callback updates the live window scale and persists to SavedVariables
- [x] **CFG-05**: Checkbox "Auto-hide when empty" — when on AND addon is enabled, window hides while sequence is empty (including after the 15s self-clear) and reappears when slot 1 fills; when off, window stays visible the whole time the addon is enabled
- [x] **CFG-06**: Button "Recreate Macros" — calls macro-registration entry point (with combat-lockdown deferral)
- [x] **CFG-07**: Button "Unlock helper window" — toggles drag-lock state from the panel; the button label reflects current state (Lock/Unlock)
- [x] **CFG-08**: Read-only command-examples section listing `/lura show`, `/lura hide`, `/lura config`, `/lura help`, `/tlh` (rendered via repeated `CreateSettingsListSectionHeaderInitializer` per the research; updated to drop `/lura clear` and add `/lura help`)
- [x] **CFG-09**: All settings persist across `/reload` and across game sessions
- [x] **CFG-10**: Slider for window alpha (range 0.20–1.00, default 1.00, step 0.05); change callback updates `db.window.alpha` and calls `frame:SetAlpha` live (mirrors the scale slider pattern in CFG-04)
- [x] **CFG-11**: Dropdown for macro target channel — values `RAID` (default) / `RAID_WARNING` / `SAY`. On change, calls `ns:RegisterMacros()` to rebuild the five `TLH_*` macros with the new channel (combat-lockdown deferral via `PLAYER_REGEN_ENABLED` retry). Stored at `db.macroChannel`. Macro body is built from a `{ RAID = "/raid", RAID_WARNING = "/rw", SAY = "/s" } [db.macroChannel]` lookup at registration time.

### Combat & Taint Safety (cross-cutting)

- [x] **SAFE-01**: No call site in the addon ever invokes `SendChatMessage` (or any chat-emitting API), including from OnClick / OnMouseDown / OnUpdate — verified by grep at PR time
- [x] **SAFE-02**: No call site in the addon ever indexes, length-checks, gsubs, matches, concatenates, or pattern-tests the `msg` argument from `CHAT_MSG_*` events — verified by grep at PR time
- [x] **SAFE-03
**: Macro creation/edit (`CreateMacro` / `EditMacro`) is always guarded by `InCombatLockdown()` and deferred to `PLAYER_REGEN_ENABLED` when blocked
- [x] **SAFE-04**: Chat events are registered only while addon state is enabled AND combat is active (mirrors POC's NSRT-style gating)

## v2 Requirements

(None tracked for v2 yet — re-evaluate after v1 ships.)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Configurable inactivity timeout | User declined the option in scoping; 20s hardcoded is fine for v1 (bumped from 15s during Phase 2 discuss) |
| Sequence persistence across `/reload` | Originally WIN-07. Dropped in Phase 2 discuss — in-memory-only state is simpler, avoids disk writes for transient combat data, and the 20s self-clear handles the use case automatically. `db.sequence` field also removed from Phase 1's Core.lua schema. |
| `/lura clear` standalone command | Originally CMD-04. Dropped in Phase 2 discuss — `/lura hide` does a clean wipe + disable, and the 20s timer auto-clears. Simpler command surface. |
| Marker-set remapping (rune→raid-marker mapping) | Fixed mapping in POC; not configurable in v1 |
| Reading or processing chat msg text in any way | Hard taint constraint — not a deferral; addon would break in boss fights |
| Sending chat messages from addon code (incl. OnClick) | Hard taint constraint — same reason; macros are the only viable channel |
| Auto-binding macros to action bar slots | Blizzard requires user to drag from `/macro` themselves |
| Standalone fallback for non-Midnight clients | Interface 120005 only — matches TerribleBuffTracker target |
| Auto-show window on first chat message | POC does this; user explicitly chose `/lura`-only visibility |
| Custom addon icon (.blp) | Defer for v1 to keep scope tight; revisit after first release |
| `COMBAT_LOG_EVENT_UNFILTERED` use | Disabled in Midnight (carry-over constraint from TBT) |
| Auto-show on combat start | Not requested; would conflict with explicit `/lura hide` user intent |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCAF-01 | Phase 1 | Complete |
| SCAF-02 | Phase 1 | Complete |
| SCAF-03 | Phase 1 | Complete |
| SCAF-04 | Phase 1 | Complete |
| SCAF-05 | Phase 1 | Complete |
| SCAF-06 | Phase 1 | Complete |
| SCAF-07 | Phase 1 | Complete |
| SCAF-08 | Phase 1 | Complete |
| SCAF-09 | Phase 1 | Complete |
| SCAF-10 | Phase 1 | Complete |
| SCAF-11 | Phase 1 | Complete |
| SCAF-12 | Phase 1 | Complete |
| MACR-01 | Phase 2 | Complete |
| MACR-02 | Phase 2 | Complete |
| MACR-03 | Phase 2 | Complete |
| MACR-04 | Phase 2 | Complete |
| MACR-05 | Phase 2 | Complete |
| WIN-01 | Phase 2 | Complete |
| WIN-02 | Phase 2 | Complete |
| WIN-03 | Phase 2 | Complete |
| WIN-04 | Phase 2 | Complete |
| WIN-05 | Phase 2 | Complete |
| WIN-06 | Phase 2 | Complete |
| ~~WIN-07~~ | — | Dropped (in-memory only) |
| WIN-08 | Phase 3 | Complete |
| WIN-09 | Phase 2 | Complete |
| WIN-10 | Phase 3 | Complete |
| CMD-01 | Phase 2 | Complete |
| CMD-02 | Phase 2 | Complete |
| CMD-03 | Phase 2 | Complete |
| ~~CMD-04~~ | — | Dropped (folded into /lura hide) |
| CMD-05 | Phase 3 | Complete |
| CMD-06 | Phase 2 | Complete |
| CMD-07 | Phase 2 | Complete |
| CFG-01 | Phase 3 | Complete |
| CFG-02 | Phase 3 | Complete |
| CFG-03 | Phase 3 | Complete |
| CFG-04 | Phase 3 | Complete |
| CFG-05 | Phase 3 | Complete |
| CFG-06 | Phase 3 | Complete |
| CFG-07 | Phase 3 | Complete |
| CFG-08 | Phase 3 | Complete |
| CFG-09 | Phase 3 | Complete |
| CFG-10 | Phase 3 | Complete |
| CFG-11 | Phase 3 | Complete |
| SAFE-01 | Phase 2 | Complete |
| SAFE-02 | Phase 2 | Complete |
| SAFE-03 | Phase 2 | Complete |
| SAFE-04 | Phase 2 | Complete |

**Coverage:**
- v1 requirements: 47 total active (48 issued; WIN-07 + CMD-04 dropped, CMD-07 + WIN-10 + CFG-10 + CFG-11 added — net 47)
- Mapped to phases: 46 (Phase 1: 12, Phase 2: 21, Phase 3: 13)
- Unmapped: 0

**Phase distribution:**
- Phase 1 (Scaffolding & Foundation): SCAF-01..12 (12 requirements) — COMPLETE
- Phase 2 (POC Port): MACR-01..05, WIN-01..06, WIN-09, CMD-01..03, CMD-06..07, SAFE-01..04 (21 requirements)
- Phase 3 (Config Panel & Integration): CFG-01..10, CMD-05, WIN-08, WIN-10 (13 requirements)

---
*Requirements defined: 2026-04-30*
*Last updated: 2026-04-30 after Phase 2 close — all 21 Phase-2 REQ IDs complete (MACR-01..05, WIN-01..06, WIN-09, CMD-01..03, CMD-06..07, SAFE-01..04)*
