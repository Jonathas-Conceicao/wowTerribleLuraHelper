# TerribleLuraHelper

## What This Is

A standalone World of Warcraft Midnight addon that helps a raid coordinate during the Midnight Falls boss fight against L'ura. L'ura displays five runes that the raid must read in order to position correctly; this addon lets one spotter press five pre-bound macros (created by the addon) and surfaces the result, in human-readable form, both in raid chat and in a dedicated helper window every player can see.

## Core Value

The five runes that L'ura shows must arrive — in the right order — on every raid member's screen, during the boss-fight chat-messaging-lockdown that blocks normal addon chat output.

## Requirements

### Validated

- ✓ **Project scaffolding (Phase 1)** — `.toc` (Interface 120005, X-Curse-Project-ID 1529832, X-Wago-ID XKqArdKy), `.pkgmeta`, `.gitignore`, `.luarc.json`, `LICENSE` (WTFPL v2), `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `scripts/install.bat`, `scripts/release.bat` (current-branch push fix), `.github/workflows/release.yml` (CHANGELOG-cutoff awk), four-file Lua skeleton (`Core.lua` + `Macros.lua` + `Window.lua` + `Config.lua` stubs), namespace pattern `local addonName, ns = ...`, grouped `TerribleLuraHelperDB` schema with backfill, milestone/0.1.0 branch open. **In-game smoke test passed 2026-04-30** — addon loads with banner, no Lua errors, addon listed.

### Active

#### Macros & messaging
- [ ] Addon creates 5 named player macros on load (`TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T`), each sending an inline `{rt#}` raid-marker code to `/raid` so the message survives boss-fight chat lockdown
- [ ] Macros use Blizzard built-in raid-marker FileDataIDs (no addon dependency)
- [ ] Macros are recreated/updated idempotently on every login; if creation is blocked by combat, retry on `PLAYER_REGEN_ENABLED`
- [ ] Manual "Recreate Macros" button in the config panel for users who deleted them

#### Helper window
- [ ] Five positional slots arranged in a smile-arc around a `BOSS` label, with a `TANK` label opposite slot 3 — slots fill 1→5 in arrival order; a 6th message clears all and restarts at slot 1
- [ ] Window is movable when unlocked; lock/unlock button on the window itself
- [ ] Window shows scaled rendering of the raid markers received from chat (rendered via Blizzard's secure chat pipeline — no string processing in addon)
- [ ] Self-clears after 20 seconds of no new message (timer hardcoded for v1; bumped from 15s during Phase 2 discuss)
- [ ] Sequence is in-memory only (cleared on `/lura hide`, on 20s inactivity, and on `/reload` — no SavedVariables persistence)
- [ ] Window is hidden by default and across reloads — never auto-shows; only opens via `/lura` or `/lura show`

#### Behavior states (slash commands)
- [ ] `/lura show` — enable processing: register chat events during combat, fill slots as messages arrive, show window. Mid-combat enable registers events immediately (per D-23 in Phase 2 CONTEXT).
- [ ] `/lura hide` — disable processing AND wipe in-memory sequence: ignore chat events even during combat, hide window, clear slots
- [ ] `/lura` (no arg) — pure toggle between enabled/disabled states
- [ ] `/lura config` — open Options > AddOns > TerribleLuraHelper page (Phase 3)
- [ ] `/lura help` — print slash command list to chat
- [ ] `/tlh` — alias for `/lura` with same subcommands

#### Config panel (Options > AddOns > TerribleLuraHelper)
- [ ] Per-channel listen toggles: SAY, RAID, RAID_LEADER, RAID_WARNING, INSTANCE, INSTANCE_LEADER
- [ ] Window scale slider: range 0.50–2.00, default 1.00
- [ ] Window alpha slider: range 0.20–1.00, default 1.00 (transparency)
- [ ] Auto-hide-when-empty toggle — when on and the addon is enabled, window hides while sequence is empty (including after the 15s self-clear) and reappears when slot 1 fills; when off, window stays visible the whole time the addon is enabled
- [ ] "Unlock helper window" button — toggles drag-lock state from the config panel (mirror of the lock button on the window)
- [ ] "Recreate Macros" button
- [ ] Read-only command-examples text block listing `/lura show`, `/lura hide`, `/lura clear`, `/tlh`

### Out of Scope

- **Configurable inactivity timeout** — explicitly considered; user picked the channel filters / utilities / scale instead. Stays hardcoded at 20s for v1 (bumped from 15s during Phase 2 discuss).
- **Sequence persistence across `/reload`** — was originally WIN-07; dropped during Phase 2 discuss in favor of in-memory-only state. Avoids SavedVariables churn for transient combat data; the 20s self-clear handles the use case naturally.
- **`/lura clear` standalone command** — was originally CMD-04; dropped during Phase 2 discuss. `/lura hide` does a clean wipe + disable; the 20s timer auto-clears between pulls.
- **Marker-set remapping (which raid marker each rune produces)** — POC ships with a fixed mapping (Diamond/Triangle/Circle/Cross/T → rt3/rt4/rt2/rt7/rt1); not configurable in v1.
- **Reading or processing chat message text in any way** — Blizzard chat lockdown taints any addon code that indexes, matches, gsubs, concatenates, or measures the `msg` argument. Hard constraint, not a deferral.
- **Sending chat messages from addon code (including OnClick handlers)** — boss-fight chat lockdown blocks tainted strings. Reason we use user-bound macros instead.
- **Addon-managed action-bar binding for the macros** — Blizzard requires the user to drag macros from `/macro` onto an action bar themselves. Addon prints a hint after creation.
- **Standalone fallback for non-Midnight clients** — Interface 120005 (Midnight) only, matching TerribleBuffTracker.
- **Auto-show on first chat message** — the POC does this; explicitly removed for v1 because the user wants `/lura` (and only `/lura`) to govern visibility.
- **Custom addon icon (`.blp`)** — TBT has one; deferred for v1 to keep scope tight. May add later.

## Context

**Functional spec is the POC.** A working prototype lives at `C:\Users\jonat\Repositories\WeakerScripts\Samples\LuraPatternHelper.lua` — it runs as a WeakerScripts sample (loaded by an external addon's script frame). It already implements every behavior except the config panel and the `/lura hide`-disables-processing semantics. Porting it to a standalone addon plus building the config UI is the bulk of the v1 work.

**Reference addon for scaffolding:** `C:\Users\jonat\Repositories\TerribleBuffTracker` — same author, same target client (Midnight 120005), same BigWigs-packaged release flow. Reuse: `.toc` shape, `.pkgmeta`, `.gitignore`, `.luarc.json`, install/release scripts, GHA workflow, namespace pattern, SavedVariables init pattern, CDM-tab settings UI conventions.

**Why piggybacking on Blizzard's secure chat pipeline matters.** During the L'ura encounter (and most boss fights since the chat-messaging-lockdown change), addon-tainted strings can't be sent over chat or rendered through normal channels. The POC sidesteps this by:
1. User-bound macros (player-bound macros aren't tainted) send raw `{rt#}` codes to `/raid`.
2. The addon registers the chat events and receives `msg`, but never inspects it — it only passes `msg` opaquely to `C_ChatInfo.ReplaceIconAndGroupExpressions` (a Blizzard-secure helper) and from there straight into `FontString:SetText`.

This is load-bearing. Any new code path that touches `msg` with `:gsub`, `:match`, `#`, `..`, or string indexing will silently break the addon during boss fights.

**Author context:** Same author and machine as TerribleBuffTracker. Conventions, scripts, and CI patterns from that repo are intentional and should be carried forward.

**Prior exploration:** No `.planning/spikes/` or `.planning/sketches/` artifacts in this repo. The POC plays the role of "validated spike."

## Constraints

- **Tech stack**: Lua 5.1 (WoW API), no external libraries beyond Blizzard built-ins. — Matches TBT and the POC; keeps packaging simple.
- **Tech stack**: Project must run on WoW Midnight (Interface 120005+); no support for older clients. — Same target as TBT.
- **Compatibility**: Must function correctly during the boss-fight chat-messaging-lockdown that blocks tainted addon strings. — This is the entire reason the addon exists.
- **Compatibility**: No use of `COMBAT_LOG_EVENT_UNFILTERED`. — Disabled in Midnight (carry-over from TBT's CLAUDE.md).
- **Code purity**: Addon code must never read, index, length-check, gsub, match, or concatenate the `msg` argument from any `CHAT_MSG_*` event. — Tainting via these operations is what breaks chat output during lockdown.
- **Code purity**: Addon code must never call `SendChatMessage` (or any chat-emitting API), including from OnClick handlers. — Tainted strings are blocked in boss fights; user-bound macros are the only viable channel.
- **Combat lockdown**: Macro creation/edit cannot happen during combat (`InCombatLockdown()` true). — Blizzard restriction; retry on `PLAYER_REGEN_ENABLED`.
- **Workflow**: All milestone work happens on a `milestone/<version>` branch; squash-merged to `main` to keep history clean (`CLAUDE.md` directive). — User explicitly requested; Claude/GSD generates many small commits and `main` should stay readable.
- **Workflow**: Run `stylua` on Lua files after finishing a task (carry-over from TBT). — Consistent formatting.
- **Style reference**: Blizzard UI source at `C:\Users\jonat\Repositories\wow-ui-source` (from TBT's CLAUDE.md). — Consult for visual/layout work to match Blizzard conventions.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use the POC at `LuraPatternHelper.lua` as the functional spec | POC already solves the chat-lockdown problem and has battle-tested comments explaining the constraints; rewriting from scratch risks losing that hard-won knowledge | — Pending |
| Mirror TerribleBuffTracker's project scaffolding (`.toc`, `.pkgmeta`, scripts, GHA, namespace) | Same author, same target client, same release flow — convergence reduces maintenance | — Pending |
| `/lura show` and `/lura hide` gate *processing*, not just *visibility* | User wants explicit on/off control even during combat (e.g. testing other addons in combat without TLH grabbing chat); also avoids any cycles when not needed | — Pending |
| Window hidden by default on every login/reload | User explicitly chose this over POC's auto-show-on-first-msg behavior — keeps screen uncluttered for non-L'ura content | — Pending |
| Inactivity timeout stays hardcoded at 15s | User declined the configurable-timeout option; YAGNI for v1 | — Pending |
| Add `auto-hide-when-empty` toggle | Bridges the gap between "always visible while enabled" (some users want this for confidence) and "only show when something to display" (others want minimal screen real estate) | — Pending |
| Slash commands: `/lura` (primary) + `/tlh` (alias) | `/lura` is the natural name and matches the POC; `/tlh` matches the addon initials and TBT's pattern (`/tbt`) | — Pending |
| Branch convention: `milestone/<version>` for milestone work, squash-merged to main | User wants `main` history readable; GSD generates many granular commits | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-30 after Phase 1 completion (Scaffolding & Foundation)*
