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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v0.1.0 | ~10 | 3 | Initial scaffolding, POC port, config panel — establishing patterns from scratch |
| v1.0.0 | ~5 | 3 | Iteration on shipped foundation; combined-phase UAT; smaller plans per phase |

### Cumulative Quality

| Milestone | Lua LOC | Files | Notable |
|-----------|---------|-------|---------|
| v0.1.0 | ~1,100 | 4 .lua | First ship; visibility-gated chat events (AMEND-01) load-bearing invariant established |
| v1.0.0 | ~1,400 | 4 .lua + 1 .xml | +inCombat coupling, +sentinel-flag hook pattern; AMEND-01 still load-bearing |

### Top Lessons (Verified Across Milestones)

1. **Hard taint constraints must be re-checked at every code-path edit** — both milestones had moments where a new feature could have touched `msg` or called `SendChatMessage`; the CLAUDE.md grep gates caught them at PR time.
2. **In-game smoke test is the only real test** — there's no test harness for WoW addons. Always run `scripts/install.bat` and `/reload` before declaring a phase verified; user UAT is non-negotiable for any UX change.
3. **Per-phase SUMMARY.md frontmatter pays for itself at milestone-close** — being able to grep for AMEND-* entries and reconstruct the iteration log is essential for the CHANGELOG and PROJECT.md evolution.
