# TerribleLuraHelper

## What This Is

A standalone World of Warcraft Midnight addon that helps a raid coordinate during the Midnight Falls boss fight against L'ura. L'ura displays five runes that the raid must read in order to position correctly; this addon lets one spotter press five pre-bound macros (created by the addon) and surfaces the result, in human-readable form, both in raid chat and in a dedicated helper window every player can see.

## Core Value

The five runes that L'ura shows must arrive — in the right order — on every raid member's screen, during the boss-fight chat-messaging-lockdown that blocks normal addon chat output.

## Current Milestone: v1.0.0 Polish & Defaults

**Goal:** Tighten the core UX before going wide — make the helper window unobtrusive in raid (click-through when locked), surface a built-in symbol reference for new users, swap defaults to the channel most pugs/casual groups actually use (SAY), and prevent the most common foot-gun (auto-hide left on outside combat).

**Target features:**

- **Click-through when locked** — coupled to lock state. Locked = fully pass-through (no clicks, no drag, lock/close buttons inert). Unlocked = today's click-and-drag behavior. Unlock paths when locked: `/lura unlock` and the config-panel button.
- **Symbol reference image on top of the config panel** — wide cheat-sheet (Diamond / Triangle / Circle / Cross / T → rune mapping) anchored at the top of Options > AddOns > TerribleLuraHelper. Hard gate: the real image asset must be supplied before the milestone closes.
- **Dynamic Show/Hide window button label** — the existing config-panel button label flips live from any state-change source (slash command, on-window close, auto-hide cycle, `/lura` toggle) while the panel is open. Replaces today's `EvaluateName`-init-only refresh.
- **New first-run defaults** — `listenChannels.SAY = true` and all other channels default-off; `macroChannel = "SAY"` (macros target `/s` by default). Backfill must NOT clobber existing user choices on upgrade — defaults apply only to fresh DBs and freshly-introduced keys.
- **Auto-hide-when-empty → "Auto hide when empty in combat"** — reframed semantics: out of combat, window stays visible when empty (so the toggle being on is visible to the user as a reminder); in combat, hides when empty as before. Hooks `PLAYER_REGEN_ENABLED` / `PLAYER_REGEN_DISABLED`. UI label and tooltip updated.

## Requirements

### Validated

- ✓ **Project scaffolding (Phase 1)** — `.toc` (Interface 120005, X-Curse-Project-ID 1529832, X-Wago-ID XKqArdKy), `.pkgmeta`, `.gitignore`, `.luarc.json`, `LICENSE` (WTFPL v2), `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `scripts/install.bat`, `scripts/release.bat` (current-branch push fix), `.github/workflows/release.yml` (CHANGELOG-cutoff awk), four-file Lua skeleton (`Core.lua` + `Macros.lua` + `Window.lua` + `Config.lua` stubs), namespace pattern `local addonName, ns = ...`, grouped `TerribleLuraHelperDB` schema with backfill, milestone/0.1.0 branch open. **In-game smoke test passed 2026-04-30** — addon loads with banner, no Lua errors, addon listed.
- ✓ **POC port (Phase 2)** — Five `TLH_*` player macros (Diamond/Triangle/Circle/Cross/T) with `InCombatLockdown()` deferral and `PLAYER_REGEN_ENABLED` retry; `BasicFrameTemplateWithInset` smile-arc helper window with five slots, lock button, drag-position persistence; taint-safe chat pipeline via `C_ChatInfo.ReplaceIconAndGroupExpressions` (zero indexing/matching/concat of `msg`); 20s self-clear; visibility-gated chat-event registration (AMEND-01); `/lura show|hide|toggle|help|config` and `/tlh` alias dispatcher. **Shipped 2026-05-01.**
- ✓ **Config panel & integration (Phase 3)** — Modern Settings-API panel under Options > AddOns wires channel toggles, scale slider (0.50–2.00), alpha slider (0.20–1.00), auto-hide-when-empty toggle, lock/unlock button, "Recreate Macros" button, macro-target-channel dropdown (RAID / RAID_WARNING / SAY), and slash-commands help block. Soft-hide model (alpha=0, not `Hide()`) keeps chat events registered while auto-hiding. `/lura config` opens directly to category. v0.1.0 released to CurseForge / Wago / GitHub. **Shipped 2026-05-01.**
- ✓ **SAY defaults + click-through (Phase 4)** — Fresh installs default `listenChannels.SAY=true` (other 5 channels off) and `macroChannel="SAY"` (was `"RAID"`); upgrade-safe backfill respects existing user choices via `if X == nil then` idiom (verified by repo-wide `git grep "= db\." -- '*.lua' | grep " or "` returning zero matches — SAFE-06 gate). Locked window is fully click-through (`win:EnableMouse(not locked)` in `applyLockState`); unlocked window restores click + drag. Pre-existing `Config.lua:70` SAFE-06 violation fixed in-flight. Code-review caught two missed pieces of D-11 (RegisterAddOnSetting default arg + dropdown tooltip still RAID-centric) — both fixed before phase close. Reqs satisfied: SCAF-13, SCAF-14, SCAF-15, SAFE-06, WIN-11, WIN-12. **Phase 4 complete 2026-05-09.**
- ✓ **Auto-hide combat reframe (Phase 5)** — Auto-hide-when-empty became in-combat-only. Out of combat with empty sequence: window stays visible (so the toggle being on is self-evident — a "this addon is on but nothing to show yet" reminder). In combat with empty sequence: soft-hides via `SetAlpha(0)` (NEVER `win:Hide()` — AMEND-01 invariant preserved; chat events stay registered through soft-hide cycles). Implementation: cached `local inCombat` flag in Window.lua, seeded via `InCombatLockdown()` at frame creation (handles `/reload` mid-combat), updated by permanent `combatFrame` listening to both `PLAYER_REGEN_*` edges. Toggle label shortened post-UAT from "Auto-hide when empty in combat" → "Auto-hide" (tooltip carries the full semantic detail). Reqs satisfied: WIN-13, WIN-14, WIN-15, CFG-14, SAFE-05. **Phase 5 complete 2026-05-10.**
- ✓ **Dynamic label + symbol reference image (Phase 6)** — Wide rune-symbol cheat-sheet image (`reference.tga`, 319×143) anchors at the top of the config panel as the first visual element. Show/Hide window button label updates live from any state-change source (slash commands, on-window close, panel button click, `/lura` toggle) without rebuilding the panel — scroll position preserved. Engineering-truth invariant: soft-hide cycles (Phase 5's combat path) do NOT flip the label because soft-hide doesn't change `IsShown()`. Implementation evolved across three iterative bug-fix rounds during UAT (AMEND-06-01/02/03 — see Phase 6 SUMMARY.md): texture file path inlined in XML, notify-hook switched from `RepairDisplay` → `DisplayCategory` → cached-frame `SetText` via `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)`, Texture explicit `Size + CENTER anchor` instead of `setAllPoints`. Reqs satisfied: CFG-12, CFG-13, SCAF-16, SCAF-17. **Phase 6 complete 2026-05-10.**

**v1.0.0 milestone complete (2026-05-10) — 15/15 requirements shipped across Phases 4, 5, 6.** Next: squash-merge `milestone/1.0.0` → `main` and tag `v1.0.0`.

### Active

v1.0.0 milestone complete (2026-05-10) — all 15 requirements validated. See Validated section above. No active requirements; next milestone TBD.

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
- **Configurable click-through (decoupled from lock state)** — v1.0.0 ties click-through directly to the lock state for a clean single-axis mental model. A separate "click-through" toggle independent of locking is not in v1.0.0; could be added later if real users ask for the decoupling.
- **Partial click-through (e.g. lock button stays clickable)** — explicitly considered and rejected during v1.0.0 questioning. Locked = fully pass-through. Users unlock via `/lura unlock` or the config panel button.
- **Placeholder image for the config-panel cheat sheet** — v1.0.0 ships the real image or doesn't ship the cheat-sheet UI at all. No placeholder ship.
- **Combat-state-aware behavior beyond the auto-hide reframe** — v1.0.0 only uses `PLAYER_REGEN_ENABLED` / `PLAYER_REGEN_DISABLED` for the auto-hide-when-empty-in-combat reframe. No combat-aware scale, alpha, or other window-property changes.

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
| v1.0.0: click-through coupled to lock state (no decoupled toggle) | Single-axis mental model is easier to teach and matches the natural intuition: "I locked it; therefore I can't accidentally click it." Partial click-through (lock button stays clickable) was explicitly considered and rejected to avoid edge cases with combat input. | ✓ Shipped Phase 4 |
| v1.0.0: cheat-sheet image is a hard milestone gate (no placeholder ship) | The image is the user-facing reason new users will understand the addon at a glance; shipping a placeholder defeats the purpose and risks the placeholder becoming permanent. | ✓ Shipped Phase 6 (real `reference.tga` delivered 2026-05-09) |
| v1.0.0: defaults shift from RAID-centric to SAY-centric (listen + macro target) | First-month real-raid usage shows pugs and casual groups use `/s` more than `/raid` for L'ura, and SAY is universally readable inside instances. RAID-* channels remain user-toggleable. | ✓ Shipped Phase 4 |
| v1.0.0: auto-hide reframed as "auto hide when empty *in combat*" (not all-time) | Out of combat the empty window stays visible so the toggle being on is self-evident — players can't accidentally leave it on and forget. In combat the original hide-when-empty UX is preserved. | ✓ Shipped Phase 5 |
| v1.0.0: Phase 5 toggle label shortened to "Auto-hide" post-UAT (AMEND-05-01) | Original locked label "Auto-hide when empty in combat" was too long for the toggle row in practice; tooltip carries the semantic detail anyway. | ✓ Shipped Phase 5 |
| v1.0.0: Phase 6 cheat-sheet image uses inline `<Texture file=...>` (not data-table indirection) | `Settings.CreateElementInitializer`'s data is held on the initializer object, NOT on the rendered frame; `<OnLoad>` runs at template instantiation before `Init(initializer)` is called → `self.data` is nil at OnLoad time. Inline file path bypasses the data-flow entirely (texture path is a hardcoded literal anyway). | ✓ Shipped Phase 6 (AMEND-06-01) |
| v1.0.0: Phase 6 button label refresh uses cached-frame `SetText` via `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` (not `RepairDisplay` or `DisplayCategory`) | `SettingsInbound.RepairDisplay` only adds/removes initializers — does NOT re-Init existing controls (per Blizzard_SettingsList.lua:98). `SettingsPanel:DisplayCategory` works but resets scroll. Capturing the rendered frame ref via the hook and calling `frame.Button:SetText(frame:EvaluateName())` directly is the only path that updates the label AND preserves scroll. | ✓ Shipped Phase 6 (AMEND-06-02) |
| v1.0.0: Phase 6 cheat-sheet image uses explicit Texture `<Size>` + CENTER anchor (not `setAllPoints`) | Settings vertical-layout overrides the parent Frame's width to fill the panel content area (~640px); `setAllPoints` would stretch the 319×143 image. Explicit Size keeps it at native dimensions centered. | ✓ Shipped Phase 6 (AMEND-06-03) |

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
*Last updated: 2026-05-10 — v1.0.0 milestone complete. Phases 4, 5, 6 all shipped; 15/15 requirements validated. Next: squash-merge `milestone/1.0.0` → `main` and tag `v1.0.0`.*
