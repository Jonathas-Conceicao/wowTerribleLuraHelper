# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0.0 — Polish & Defaults

**Shipped:** 2026-05-10
**Phases:** 3 (4, 5, 6) | **Plans:** 3 | **Sessions:** ~5

### What Was Built

- **Click-through when locked** — `EnableMouse(not locked)` cascade across window + 5 slot frames (the cascade is not automatic; this was a Phase 4 PITFALLS catch).
- **SAY-centric defaults + safe upgrade backfill** — `LISTEN_DEFAULTS` constant table, `if X == nil then` idiom enforced via repo-wide grep gate (SAFE-06).
- **Auto-hide reframed to in-combat-only** — `local inCombat` flag in `Window.lua` seeded from `InCombatLockdown()` at frame creation, refreshed by permanent `combatFrame` listening to both `PLAYER_REGEN_*` edges. `applySoftHideState` extended with `and inCombat` condition. AMEND-01 invariant (alpha=0, never `win:Hide()`) preserved end-to-end.
- **Cheat-sheet image asset pipeline** — `reference.tga` ships via existing BigWigs Packager (`.pkgmeta` defaults already correct for `*.tga`); `templates.xml` virtual frame with inline `file=` path.
- **Live Show/Hide + Lock/Unlock button labels with scroll preservation** — `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` captures rendered frame refs via sentinel `data._tlhShowHideButton` / `_tlhLockButton` flags; `frame.Button:SetText(frame:EvaluateName())` direct call refreshes the label without rebuilding the panel (which would reset scroll).

### What Worked

- **Combined Phase 5 + Phase 6 UAT** — user deferred Phase 5 in-game testing and validated both phases at once in one in-game session. Saved a context-clearing cycle and surfaced cross-phase interactions (soft-hide + dynamic label) earlier.
- **Single-plan phases** — Phase 4/5/6 each landed on a single `01-PLAN.md`. Right grain for small UX-polish work; the plan-checker step was still useful as a sanity gate.
- **Repo-wide grep gates** — SAFE-06 (`db.X = db.X or DEFAULT`) was caught in code review by a literal grep enforced at PR time. The plan-checker also caught a stale comment in `Core.lua` matching the anti-pattern (false positive that taught a teaching-comment lesson: don't quote the bad pattern verbatim in code).
- **Pre-commit + post-commit performance/cleanup passes** — caught 5 dead-code items in a single retroactive review (`addonName` unused × 2, `category` unused × 2, `ns:RegisterChatEvents` over-exposed). Net wins, zero behavior change.
- **`hooksecurefunc` + sentinel data flag pattern** — the right Blizzard-Settings-API hook for "I need a ref to the rendered frame after the panel layouts." Reusable.

### What Was Inefficient

- **Phase 6 took 3 UAT iteration rounds** — three separate bug fixes (AMEND-06-01/02/03) for what should have been one. Root cause: phase researcher offered three conflicting recommendations for "dynamic label refresh" (`RepairDisplay`, `gameDataFunc`, `hooksecurefunc`). Synthesizer picked `RepairDisplay`, which silently doesn't re-Init existing controls. Lesson: when researcher returns 3 conflicting options, surface ALL of them in CONTEXT for the user to choose, don't auto-pick one.
- **Texture sizing bug** — `setAllPoints` stretched the 319×143 image to ~640px because the Settings vertical-layout overrides parent frame width. Should have been caught at plan time; the wow-ui-source has examples of explicit Size + CENTER anchor for narrow images in vertical layouts.
- **`install.bat` missed new files** — `templates.xml` and `reference.tga` weren't added to `scripts/install.bat` in the original Phase 6 plan; executor caught it before UAT but the plan should have included it as a Task 3 line item.
- **Branch state confusion at session start** — gitStatus snapshot showed stale `milestone/0.1.0` branch even though v0.1.0 was already merged. Cost a corrective round-trip. Probably fixable by always querying `git status` fresh at session start instead of trusting the harness snapshot.

### Patterns Established

- **Engineering-truth model for state-dependent UI labels** — "soft-hide (alpha=0) counts as IsShown()=true counts as 'visible' for label purposes." User-confirmed during Phase 6 questioning. Saves a class of bug where the displayed state diverges from the engineering state.
- **Sentinel `initializer.data._tlhXxxButton` flag for hooksecurefunc capture** — clean way to filter the `SettingsButtonControlMixin:Init` hook to only our buttons. Reusable for any future panel button that needs live refresh.
- **Combined UAT for adjacent phases** — when phases share a runtime surface (Phase 5 modifies Window.lua state, Phase 6 reads it), batching UAT into one in-game session is more efficient and finds cross-phase bugs.
- **Defensive `.pkgmeta` `assets` entry** — even though `*.png` ignore already excludes today's only repo-only source, listing `assets` future-proofs against new dev-only files in that folder showing up empty in the release zip.

### Key Lessons

1. **When the researcher offers 3 conflicting approaches, don't let the synthesizer auto-pick** — surface all options in CONTEXT for the user to choose, especially for unfamiliar Blizzard-API territory. Phase 6 burned 3 UAT rounds on this.
2. **Texture sizing in Settings vertical layout always needs explicit Size + CENTER anchor** — `setAllPoints` stretches because the parent frame is forced to panel width.
3. **`hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` is the documented Blizzard hook** for capturing rendered Settings panel button frame refs. `RepairDisplay` does NOT re-Init existing controls (only adds/removes initializers from the data provider). `DisplayCategory` works but resets scroll. The hook + cached-frame `SetText(EvaluateName())` is the only path that updates the label AND preserves scroll.
4. **Plan needs to enumerate ALL file additions** including build/install scripts (`install.bat`). Easy to miss when the new asset is "just a texture."
5. **Per-AMEND log entries pay off at milestone-close** — being able to read AMEND-05-01 and AMEND-06-01/02/03 in sequence reconstructed the UAT iteration cleanly for the CHANGELOG and PROJECT.md updates. Worth the inline cost.

### Cost Observations

- Model mix: ~95% Opus 4.7 (1M context), ~5% Sonnet 4.6 (subagent verification passes)
- Sessions: ~5 (new-milestone, plan-Phase-4, plan-Phase-5+6, execute-Phase-4+5+6, complete-milestone)
- Notable: the combined Phase 5+6 plan+execute session stayed warm in cache by chaining work — would have been more expensive with `/clear` between every phase.

---

## Milestone: v1.1.0 — QoL Update

**Shipped:** 2026-05-16
**Phases:** 2 (Phase 7, Phase 8) | **Plans:** 2 | **Sessions:** ~3

### What Was Built

- **Verbose-marker toggle (Phase 7)** — dual-field `MACROS` table + payload-selection conditional in `RegisterMacros`; new `ns:OnVerboseMarkersChanged` callback mirroring `OnMacroChannelChanged`; (3aa) "Use verbose markers" checkbox in the Macros config section; SAFE-06 nil-check backfill in `Core.lua`. Default flipped from initial `true` → `false` during UAT (AMEND-07-01-UAT-01) after localization implication played out — verbose tokens only render on English clients, so universal `{rt#}` becomes the safe default.
- **Zone-aware auto show/hide (Phase 8)** — permanent `zoneFrame` listener on `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA` (Blizzard's `MapTexturePreloader.lua` dual-event pattern); `ns:OnZoneChanged()` handler routing through existing `ns:ShowWindow()` / `ns:HideWindow()`; `LURA_RAID_INSTANCE_ID = 2913` captured live via gated `DEBUG_ZONE_INFO` flag during UAT (two-track placeholder pattern); difficulty-agnostic single scalar covers all 5 Midnight raid difficulties.

### What Worked

- **Two-track placeholder pattern for unknown-at-plan-time constants** — Phase 8 shipped with sentinel `0` + gated debug-print block. UAT captured the live `inst=2913` and a follow-up `fix(08-01)` patched the constant + flipped the debug flag off. Zero regression risk during the placeholder window. Worth keeping in the playbook for any "we don't know this value until we run it" situation (e.g. new raid mapIDs in future expansions, new icon FileDataIDs, etc.).
- **Combined cross-phase UAT (Block A + B + C in one session)** — Phase 7 shipped code-complete-UAT-deferred; UAT ran as a single 16-checkpoint in-game session at end of milestone. This matches v1.0.0's Phase 5+6 pattern and is now a re-validated, second-occurrence project preference (saved as a memory feedback artifact). Saved at least one context-clearing cycle between phases.
- **Research-driven architectural pivot** — Phase 8 RESEARCH §Q3 pivoted from CONTEXT D-08's `C_Map.GetBestMapForUnit` proposal to `GetInstanceInfo()` instanceID. Eliminated a potential per-difficulty lookup table; turned a "set" into a scalar. Showed the value of having the researcher revisit foundational architecture decisions even when CONTEXT has a recommendation.
- **Late-UAT semantic refinement (AMEND-07-01-UAT-01)** — user spotted the localization implication of "verbose ON by default" during real-feel testing and flipped the default. The CONTEXT/RESEARCH framing had treated localization as a tooltip clarification; UAT promoted it to a default-flip. Lesson: research-surfaced caveats deserve a re-read at UAT, not just at plan time.
- **First-iteration plan-checker passes** for both phases — Phase 7 + Phase 8 both passed verification on first try, no revision loop. Strong CONTEXT.md + RESEARCH.md + PATTERNS.md combination paid off.
- **Repo-wide grep gates as commit-time invariants** — SAFE-06 grep + taint-regression diff scan + AMEND-01 SetAlpha(0) grep + SCAF-19 localization-safety grep all caught nothing this milestone (good — they're working as intended). The discipline of checking them per commit is what keeps them effective.

### What Was Inefficient

- **Late-UAT default flip required updating multiple docs** — AMEND-07-01-UAT-01 touched Core.lua + Config.lua + PROJECT.md + REQUIREMENTS.md + ROADMAP.md + SUMMARY.md. About 25 minutes of careful doc-updating to keep historical records consistent. Hard to prevent (you can't predict which UAT findings become reframes), but worth noting that semantic reframes during UAT carry a doc-update tail.
- **autocrlf line-ending warnings cluttered every git status** — the `M Core.lua` / `M Config.lua` after stylua-LF-normalization vs Git-autocrlf-CRLF appeared all session, with zero content delta. Not a real issue but cosmetic noise. Could be settled by setting `.gitattributes` for LF-only on `.lua` files (worth a follow-up cleanup in a future minor milestone).
- **Two encoding glitches in ROADMAP.md** — mojibake characters (`Ã¢â‚¬â€` instead of em-dashes) survived through several edits because they were committed by Windows tooling at some point in v1.0.0 and propagated. Edit attempts on lines containing mojibake fell back to `sed` (which is byte-level tolerant). Not a milestone blocker but adds friction.

### Patterns Established

- **Two-track placeholder pattern** (sentinel constant + gated debug-print + UAT-driven capture + follow-up patch commit) — formally documented in v1.1.0-ROADMAP.md and PROJECT.md Key Decisions. First use was Phase 8's `LURA_RAID_INSTANCE_ID`. Pattern is now in the playbook.
- **Semver discipline: minor for features, patch for hotfixes** — formalized as a Key Decision (PROJECT.md) after the in-flight v1.0.1 → v1.1.0 rename when the user pointed out that two new features can't be a patch bump.
- **Cross-phase UAT batching** — second occurrence (v1.0.0 Phase 5+6, v1.1.0 Phase 7+8). Now a stable project preference and a saved memory feedback artifact.
- **Locale-safety as a first-class concern** — verbose-token localization gotcha + SCAF-19's no-zone-name-string-matching rule both make "this addon must work for non-English players" a recurring constraint. Worth pre-checking in every CONTEXT for any new feature that touches user-visible strings or zone/instance state.

### Key Lessons

1. **Research-surfaced caveats deserve a re-read at UAT, not just at plan time.** The localization implication of verbose tokens was correctly surfaced by RESEARCH §Q7 and flowed into the tooltip wording. But the default-flip didn't surface until the user saw the actual UAT behavior. Lesson: when research highlights a "this only works under condition X" caveat, the planner should ask: "Is X always true for our users?" If not, the default behavior may need to flip too.
2. **Two-track placeholder is the right answer when the planner can't know a value.** Better than blocking the plan on research, better than guessing wrong. Sentinel + gated debug + UAT capture + patch commit is a four-step recipe that worked cleanly and would scale to other "we'll find out at runtime" constants (new raid mapIDs, new icon FileDataIDs, future Blizzard ID changes).
3. **`GetInstanceInfo()` instanceID beats `C_Map.GetBestMapForUnit` uiMapID for difficulty-agnostic raid detection.** Documented in Key Decisions for any future zone-aware features. Concrete because we proved it: single scalar `2913` covers all 5 Midnight raid difficulties.
4. **Combined cross-phase UAT is now a default expectation, not an exception.** Saves context cycles, surfaces cross-phase interactions earlier (didn't materialize as a problem this milestone, but the pattern is preserved). Memory feedback artifact captures this for future milestones.
5. **The post-commit cleanup pass discipline (per CLAUDE.md) caught zero issues this milestone** but the discipline itself stays valuable — it keeps each commit small and clean. Zero is the right number for this kind of check most of the time.

### Cost Observations

- Model mix: ~95% Opus 4.7 (1M context), ~5% Sonnet 4.6 (subagent verification passes — pattern-mapper, plan-checker)
- Sessions: ~3 (new-milestone → plan+execute Phase 7 → plan+execute+UAT Phase 8 + close)
- Notable: the combined Phase 7+8 UAT session avoided 1-2 context resets vs running per-phase UAT. The late-UAT verbose-default flip added ~25 minutes of doc-update work that wouldn't have been needed if the flip had happened at plan time.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v0.1.0 | ~10 | 3 | Initial scaffolding, POC port, config panel — establishing patterns from scratch |
| v1.0.0 | ~5 | 3 | Iteration on shipped foundation; combined-phase UAT; smaller plans per phase |
| v1.1.0 | ~3 | 2 | Two-track placeholder pattern; research-driven architectural pivot; cross-phase UAT batching as default; semver policy formalized |

### Cumulative Quality

| Milestone | Lua LOC | Files | Notable |
|-----------|---------|-------|---------|
| v0.1.0 | ~1,100 | 4 .lua | First ship; visibility-gated chat events (AMEND-01) load-bearing invariant established |
| v1.0.0 | ~1,400 | 4 .lua + 1 .xml | +inCombat coupling, +sentinel-flag hook pattern; AMEND-01 still load-bearing |
| v1.1.0 | ~1,550 | 4 .lua + 1 .xml | +zoneFrame permanent listener, +dual-field MACROS pattern, +two-track placeholder constant; AMEND-01 still load-bearing |

### Top Lessons (Verified Across Milestones)

1. **Hard taint constraints must be re-checked at every code-path edit** — three milestones in, the CLAUDE.md grep gates have caught zero violations because the discipline is in place. The cost of running them is trivial; the cost of missing a `msg` indexing addition would be the addon silently breaking in boss combat.
2. **In-game smoke test is the only real test** — there's no test harness for WoW addons. Always run `scripts/install.bat` and `/reload` before declaring a phase verified; user UAT is non-negotiable for any UX change.
3. **Per-phase SUMMARY.md frontmatter pays for itself at milestone-close** — being able to grep for AMEND-* entries and reconstruct the iteration log is essential for the CHANGELOG and PROJECT.md evolution.
4. **Cross-phase UAT batching is a stable preference** — v1.0.0 + v1.1.0 both validated; saved memory feedback. When a milestone has multiple small phases that don't depend on each other for code, batch UAT at milestone end.
5. **Research-surfaced caveats deserve a UAT-time re-read** — v1.1.0's late default flip demonstrated this. Lesson is portable to any future milestone with research that includes "this only works under condition X" findings.
