# Requirements: TerribleLuraHelper

**Defined:** 2026-04-30
**Core Value:** The five runes that L'ura shows must arrive — in the right order — on every raid member's screen, during the boss-fight chat-messaging-lockdown that blocks normal addon chat output.

## v1 Requirements

### Project Scaffolding

- [ ] **SCAF-01**: `.toc` declares `Interface 120005`, `TerribleLuraHelperDB` SavedVariables, BigWigs packager hooks (`@project-version@`, optional `X-Curse-Project-ID` / `X-Wago-ID`), and lists every Lua file in load order
- [ ] **SCAF-02**: Namespace pattern `local addonName, ns = ...` is shared across all Lua files (matches TerribleBuffTracker)
- [ ] **SCAF-03**: SavedVariables key `TerribleLuraHelperDB` is initialized on `ADDON_LOADED` with the grouped default schema: `enabled=false`, `listenChannels.{SAY,RAID,RAID_LEADER,RAID_WARNING,INSTANCE_CHAT,INSTANCE_CHAT_LEADER}=true`, `window={scale=1.00, locked=true, autoHide=false, position=nil}`, `sequence={}`. Backfills new keys on existing DBs (matches TBT pattern).
- [ ] **SCAF-04**: `.pkgmeta` configures BigWigs Packager with `package-as: TerribleLuraHelper`, manual changelog from `RELEASE_NOTES.md`, and ignore list (gitignore, pkgmeta, CHANGELOG, CLAUDE, README, LICENSE, scripts, png, RELEASE_NOTES)
- [ ] **SCAF-05**: `.gitignore` excludes `*.zip`, `.claude/`, and emacs swap files (mirrors TBT)
- [ ] **SCAF-06**: `.luarc.json` configures Lua 5.1 runtime and `vscode-wow-api` workspace library
- [ ] **SCAF-07**: `scripts/install.bat` copies all addon files to `_retail_/Interface/AddOns/TerribleLuraHelper`
- [ ] **SCAF-08**: `scripts/release.bat <version>` tags `v<version>` and pushes; GitHub Actions handles packaging
- [ ] **SCAF-09**: `.github/workflows/release.yml` runs BigWigs Packager on tag push and extracts the current `## ` section from `CHANGELOG.md` into `RELEASE_NOTES.md`
- [ ] **SCAF-10**: `CHANGELOG.md`, `README.md`, `LICENSE` exist at repo root
- [ ] **SCAF-11**: `CLAUDE.md` documents the project, hard constraints (chat-lockdown / no-msg-processing / no-SendChatMessage), workflow rules (`milestone/<version>` branch, squash-merge, run `stylua`), and architecture file map
- [ ] **SCAF-12**: All work for the v1 milestone happens on a `milestone/0.1.0` branch and is squash-merged to `main`

### Macros

- [ ] **MACR-01**: Five named player macros (`TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T`) are created on first load, each with body `/raid {rt#}` and a Blizzard built-in raid-marker FileDataID icon (Diamond=137003, Triangle=137004, Circle=137002, Cross=137007, T=137001)
- [ ] **MACR-02**: Existing macros with the TLH names are updated in place (idempotent body+icon refresh) on every login — never duplicated
- [ ] **MACR-03**: If `InCombatLockdown()` is true on load, macro registration is deferred to `PLAYER_REGEN_ENABLED`
- [ ] **MACR-04**: A "Recreate Macros" button in the config panel re-runs registration on demand (with the same combat-lockdown deferral behavior)
- [ ] **MACR-05**: First successful registration of the session prints a one-time chat hint reminding the user to drag the macros from `/macro` onto their action bar

### Helper Window

- [ ] **WIN-01**: Window contains five positional rune slots arranged in a smile-arc, with a `BOSS` label centered and a `TANK` label opposite slot 3 (mirrors POC)
- [ ] **WIN-02**: Slots fill in the order chat messages arrive (1 → 5); a 6th message clears all slots and begins refilling at slot 1
- [ ] **WIN-03**: Each slot renders the raid marker as a `FontString` whose text is set directly from `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` — no addon-side string operations on `msg`
- [ ] **WIN-04**: Window is hidden by default on every login/reload (no remembered visibility state, no auto-show on chat); only `/lura show` (or `/lura` toggling from hidden) reveals it
- [ ] **WIN-05**: Window has a visible lock/unlock button on its frame; when unlocked the window is draggable, when locked drag is disabled
- [ ] **WIN-06**: Slot display self-clears 15 seconds after the most recent chat message (timer hardcoded for v1)
- [ ] **WIN-07**: Sequence persists across `/reload` so the display is restored on the next load (the addon must store the post-processed strings opaquely — never indexed by Lua)
- [ ] **WIN-08**: Window scale honors the configured scale value (range 0.50–2.00, default 1.00) and updates live when the slider changes
- [ ] **WIN-09**: Window position persists across `/reload` and full game-session restarts — written to `db.window.position` on drag-end and re-applied on first show; defaults to `CENTER UIParent CENTER 200 80` when no saved position exists

### Behavior States (Slash Commands)

- [ ] **CMD-01**: `/lura show` flips addon state to **enabled** — registers chat events for combat (via `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`), shows window (subject to `auto-hide-when-empty`)
- [ ] **CMD-02**: `/lura hide` flips addon state to **disabled** — unregisters / ignores chat events even during combat, hides window, leaves stored sequence intact
- [ ] **CMD-03**: `/lura` (no arg) toggles between enabled and disabled
- [ ] **CMD-04**: `/lura clear` clears the slot display immediately (does not change enabled/disabled state)
- [ ] **CMD-05**: `/lura config` opens the addon's panel under Options > AddOns directly (via `Settings.OpenToCategory(category:GetID())`)
- [ ] **CMD-06**: `/tlh` is a full alias for `/lura` (same arg parsing, same dispatch)

### Config Panel (Options > AddOns > TerribleLuraHelper)

- [ ] **CFG-01**: Panel registered via `Settings.RegisterVerticalLayoutCategory` + `Settings.RegisterAddOnCategory` (NOT the deprecated `InterfaceOptions_AddCategory`); registration is gated on `EventUtil.ContinueOnAddOnLoaded`
- [ ] **CFG-02**: Six checkboxes for per-channel listen toggles (SAY / RAID / RAID_LEADER / RAID_WARNING / INSTANCE / INSTANCE_LEADER), each bound to `TerribleLuraHelperDB` via `Settings.RegisterAddOnSetting`
- [ ] **CFG-03**: Channel filter is applied at chat-event-handling time — events from disabled channels are ignored entirely (no slot fill, no sequence update); the registration set still includes all channels (filtering is by-flag, not by-registration)
- [ ] **CFG-04**: Slider for window scale (range 0.50–2.00, default 1.00, step 0.05); change callback updates the live window scale and persists to SavedVariables
- [ ] **CFG-05**: Checkbox "Auto-hide when empty" — when on AND addon is enabled, window hides while sequence is empty (including after the 15s self-clear) and reappears when slot 1 fills; when off, window stays visible the whole time the addon is enabled
- [ ] **CFG-06**: Button "Recreate Macros" — calls macro-registration entry point (with combat-lockdown deferral)
- [ ] **CFG-07**: Button "Unlock helper window" — toggles drag-lock state from the panel; the button label reflects current state (Lock/Unlock)
- [ ] **CFG-08**: Read-only command-examples section listing `/lura show`, `/lura hide`, `/lura clear`, `/lura config`, `/tlh` (rendered via repeated `CreateSettingsListSectionHeaderInitializer` per the research)
- [ ] **CFG-09**: All settings persist across `/reload` and across game sessions

### Combat & Taint Safety (cross-cutting)

- [ ] **SAFE-01**: No call site in the addon ever invokes `SendChatMessage` (or any chat-emitting API), including from OnClick / OnMouseDown / OnUpdate — verified by grep at PR time
- [ ] **SAFE-02**: No call site in the addon ever indexes, length-checks, gsubs, matches, concatenates, or pattern-tests the `msg` argument from `CHAT_MSG_*` events — verified by grep at PR time
- [ ] **SAFE-03**: Macro creation/edit (`CreateMacro` / `EditMacro`) is always guarded by `InCombatLockdown()` and deferred to `PLAYER_REGEN_ENABLED` when blocked
- [ ] **SAFE-04**: Chat events are registered only while addon state is enabled AND combat is active (mirrors POC's NSRT-style gating)

## v2 Requirements

(None tracked for v2 yet — re-evaluate after v1 ships.)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Configurable inactivity timeout | User declined the option in scoping; 15s hardcoded is fine for v1 |
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
| SCAF-01 | Phase 1 | Pending |
| SCAF-02 | Phase 1 | Pending |
| SCAF-03 | Phase 1 | Pending |
| SCAF-04 | Phase 1 | Pending |
| SCAF-05 | Phase 1 | Pending |
| SCAF-06 | Phase 1 | Pending |
| SCAF-07 | Phase 1 | Pending |
| SCAF-08 | Phase 1 | Pending |
| SCAF-09 | Phase 1 | Pending |
| SCAF-10 | Phase 1 | Pending |
| SCAF-11 | Phase 1 | Pending |
| SCAF-12 | Phase 1 | Pending |
| MACR-01 | Phase 2 | Pending |
| MACR-02 | Phase 2 | Pending |
| MACR-03 | Phase 2 | Pending |
| MACR-04 | Phase 2 | Pending |
| MACR-05 | Phase 2 | Pending |
| WIN-01 | Phase 2 | Pending |
| WIN-02 | Phase 2 | Pending |
| WIN-03 | Phase 2 | Pending |
| WIN-04 | Phase 2 | Pending |
| WIN-05 | Phase 2 | Pending |
| WIN-06 | Phase 2 | Pending |
| WIN-07 | Phase 2 | Pending |
| WIN-08 | Phase 3 | Pending |
| WIN-09 | Phase 2 | Pending |
| CMD-01 | Phase 2 | Pending |
| CMD-02 | Phase 2 | Pending |
| CMD-03 | Phase 2 | Pending |
| CMD-04 | Phase 2 | Pending |
| CMD-05 | Phase 3 | Pending |
| CMD-06 | Phase 2 | Pending |
| CFG-01 | Phase 3 | Pending |
| CFG-02 | Phase 3 | Pending |
| CFG-03 | Phase 3 | Pending |
| CFG-04 | Phase 3 | Pending |
| CFG-05 | Phase 3 | Pending |
| CFG-06 | Phase 3 | Pending |
| CFG-07 | Phase 3 | Pending |
| CFG-08 | Phase 3 | Pending |
| CFG-09 | Phase 3 | Pending |
| SAFE-01 | Phase 2 | Pending |
| SAFE-02 | Phase 2 | Pending |
| SAFE-03 | Phase 2 | Pending |
| SAFE-04 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 45 total
- Mapped to phases: 45 (Phase 1: 12, Phase 2: 22, Phase 3: 11)
- Unmapped: 0

**Phase distribution:**
- Phase 1 (Scaffolding & Foundation): SCAF-01..12 (12 requirements)
- Phase 2 (POC Port): MACR-01..05, WIN-01..07, WIN-09, CMD-01..04, CMD-06, SAFE-01..04 (22 requirements)
- Phase 3 (Config Panel & Integration): CFG-01..09, CMD-05, WIN-08 (11 requirements)

---
*Requirements defined: 2026-04-30*
*Last updated: 2026-04-30 after Phase 1 discuss (added WIN-09 window-position persistence; refined SCAF-03 schema)*
