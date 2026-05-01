# TerribleLuraHelper

WoW Midnight (Interface 120005+) addon that helps a raid coordinate during the Midnight Falls boss fight against L'ura. One spotter presses pre-bound macros (created by the addon) and the result lands in raid chat *and* in a smile-arc helper window every player can see — surviving the boss-fight chat-messaging-lockdown that blocks normal addon chat output.

## Workflow (read first)

- **All milestone work happens on a dedicated `milestone/<version>` branch.** Never commit milestone work directly to `main`. Open the branch at the start of the milestone (`git checkout -b milestone/0.1.0` for v1) and stay on it until the milestone is complete.
- **Squash-merge to `main` at milestone completion** with a single clean commit message summarizing all changes. The reason: GSD/Claude generates many granular per-task commits. The milestone branch keeps that history intact for forensics; `main` stays human-readable.
- Run `stylua` on all Lua files after finishing a task.
- After every commit, do a quick performance/cleanup pass: hot-path allocations, redundant per-frame work, dirty-check opportunities, dead code.
- Deploy to WoW with `./scripts/install.bat` (Windows).
- Release with `./scripts/release.bat <version>` — tags `v<version>` and pushes; GitHub Actions handles BigWigs Packager and uploads.

## Hard Constraints

These are non-negotiable. Any code that violates them will silently break the addon during the boss fight that's the entire reason the addon exists.

- **`COMBAT_LOG_EVENT_UNFILTERED` is disabled in Midnight — do NOT use it.**
- **Never call `SendChatMessage` (or any chat-emitting API) anywhere in the addon, including from OnClick / OnMouseDown / OnUpdate handlers.** Boss-fight chat lockdown blocks tainted addon strings. The addon ships pre-bound *player* macros instead — those aren't tainted.
- **Never read, index, length-check, gsub, match, concatenate, or pattern-test the `msg` argument from any `CHAT_MSG_*` event.** The string is tainted; touching it via Lua taints downstream code paths. Pass `msg` *opaquely* through `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` (a Blizzard-secure helper) and from there straight into `FontString:SetText`. That's the only legal pipeline.
- **Macro creation/edit is blocked during combat.** Always guard `CreateMacro` / `EditMacro` with `InCombatLockdown()` and defer to `PLAYER_REGEN_ENABLED` when blocked.
- **Chat events are registered when the helper window is shown and unregistered when it is hidden.** Window visibility is the single on/off switch — `OnShow` registers the `CHAT_MSG_*` events, `OnHide` unregisters them and wipes the in-memory sequence. No combat gating; no `db.enabled` flag. (Reading own-state `db.*` and Lua locals during combat is fine — the "secret values" / lockdown concern is about reading Blizzard's UI/unit info during combat, not own state.)
- **Tracking buffs/auras is generally limited in Midnight; many values are "Secret Values".** Not directly relevant to TLH but inherited convention from sibling addons — guard such reads behind fail-safe calls.

## Architecture (planned)

- `Core.lua` — namespace, init, event routing, slash commands, ADDON_LOADED → DB defaults
- `Macros.lua` — TLH_* macro registration with combat-lockdown deferral
- `Window.lua` — smile-arc helper window, lock/unlock, slot rendering, sequence persistence, 15s self-clear
- `Config.lua` — Options > AddOns > TerribleLuraHelper panel via the modern `Settings.*` API (NOT `InterfaceOptions_AddCategory`)
- `TerribleLuraHelper.toc` — Interface 120005, SavedVariables, BigWigs packager hooks
- `.pkgmeta` — BigWigs Packager config (CurseForge / Wago / GitHub releases)
- `.github/workflows/release.yml` — BigWigs Packager action on tag push
- `scripts/install.bat` — copy to WoW retail addons folder
- `scripts/release.bat` — tag and push (CI handles packaging)

(File map subject to refinement during planning — keep this section updated as files are added.)

## Patterns

- Namespace: `local addonName, ns = ...` shared across all Lua files (matches TerribleBuffTracker)
- SavedVariables: `TerribleLuraHelperDB` (account-wide), initialized on `ADDON_LOADED` with backfill of new keys for existing DBs
- Settings panel: register with `EventUtil.ContinueOnAddOnLoaded`; bind controls via `Settings.RegisterAddOnSetting` (the API auto-writes back to SavedVariables — don't write the DB manually from change callbacks); panel lives under Options > AddOns via `Settings.RegisterAddOnCategory`. See `.planning/research/SETTINGS_API.md` for concrete code patterns and signatures verified against `wow-ui-source@12.0.1`.
- Sequence storage: store the *post-processed* `|T...|t` string opaquely (received from Blizzard's secure helper) — never index it from Lua. `wipe()` the table on clear; `#sequence` for length is fine (it doesn't index the strings, just counts table entries).
- Slash commands: `/lura` primary, `/tlh` alias. `/lura show`, `/lura hide`, `/lura clear`, `/lura config` are explicit; bare `/lura` toggles enabled/disabled state.

## Testing

- `/lura` toggles enabled/disabled state.
- `/lura show` enables processing and shows the window.
- `/lura hide` disables processing entirely.
- `/lura clear` clears slot display immediately.
- `/lura config` opens the addon's options panel.
- `/tlh` (and aliases) — same as `/lura`.

In-game smoke test (no test harness for WoW addons): install via `./scripts/install.bat`, `/reload`, run through the slash commands, then verify behavior during a real or training-dummy combat encounter where the five `TLH_*` macros are bound to action bars.

## Style Reference

- Blizzard UI source: `C:\Users\jonat\Repositories\wow-ui-source` (https://github.com/Gethe/wow-ui-source). Always consult before changing visual or layout code.
- Settings API canonical files (in wow-ui-source): `Interface\AddOns\Blizzard_Settings_Shared\Blizzard_Settings.lua`, `Blizzard_Setting.lua`, `Blizzard_SettingControls.lua`, `Blizzard_SettingsInbound.lua`.
- Sibling addon for scaffolding conventions: `C:\Users\jonat\Repositories\TerribleBuffTracker` (same author, same client target, same release flow).

## Functional Spec

The working POC at `C:\Users\jonat\Repositories\WeakerScripts\Samples\LuraPatternHelper.lua` is the functional spec for everything the addon must do at runtime. Read its module-header docstring before touching macro registration, the chat-event handler, the smile-arc layout, or the sequence-persistence path — the comments document why each piece is shaped the way it is. Behavior changes from the POC for v1:

1. `/lura hide` and `/lura show` now gate *processing*, not just visibility (POC processes whenever combat is active, regardless of window state).
2. Window is hidden by default on every login/reload (POC auto-shows on first chat message).
3. Settings panel did not exist in the POC; v1 adds it under Options > AddOns.

## GSD Workflow

Project planning artifacts live in `.planning/`. Key files for context:

- `.planning/PROJECT.md` — what we're building, core value, constraints, key decisions.
- `.planning/REQUIREMENTS.md` — 44 v1 requirements with REQ-IDs (SCAF / MACR / WIN / CMD / CFG / SAFE) and traceability to phases.
- `.planning/ROADMAP.md` — 3-phase roadmap.
- `.planning/research/SETTINGS_API.md` — verified Settings API patterns for the config panel.
- `.planning/STATE.md` — current project state.
