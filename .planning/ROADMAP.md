# Roadmap: TerribleLuraHelper

## Overview

TerribleLuraHelper is a standalone WoW Midnight addon that helps a raid coordinate during the Midnight Falls L'ura encounter. The addon survives the boss-fight chat-messaging-lockdown by combining user-bound macros (untainted) with a taint-safe chat-event pipeline that pipes raid-marker tokens straight from `C_ChatInfo.ReplaceIconAndGroupExpressions` into a `FontString:SetText` on a dedicated helper window — every raid member with the addon sees the rune sequence in real time, regardless of chat lockdown.

## Milestones

- ✅ **v0.1.0 Initial Release** — Phases 1–3 (shipped 2026-05-01)
- ✅ **v1.0.0 Polish & Defaults** — Phases 4–6 (shipped 2026-05-10)
- 📋 **v1.1+ TBD** — next milestone via `/gsd-new-milestone`

## Phases

<details>
<summary>✅ v0.1.0 Initial Release (Phases 1–3) — SHIPPED 2026-05-01</summary>

- [x] **Phase 1: Scaffolding & Foundation** (3/3 plans) — Repo skeleton, `.toc`, packager pipeline, namespace, SavedVariables init; addon loads as no-op with banner. Completed 2026-04-30.
- [x] **Phase 2: POC Port (Macros, Window, Commands)** (3/3 plans) — Lifted POC behavior into the addon; macros, smile-arc helper window, slash commands, taint-safe chat-event piggyback, `/lura show/hide` enable/disable semantics, AMEND-01 visibility-gated chat-event registration. Completed 2026-05-01.
- [x] **Phase 3: Config Panel & Integration** (1/1 plan) — Settings API panel under Options > AddOns wiring channel filters, scale + alpha sliders, auto-hide toggle, action buttons, macro-target dropdown, slash-commands help block; `/lura config` opens panel directly. Completed 2026-05-01.

Full detail: [`.planning/archive/v0.1.0/`](archive/v0.1.0/) (per-phase artifacts)

</details>

<details>
<summary>✅ v1.0.0 Polish & Defaults (Phases 4–6) — SHIPPED 2026-05-10</summary>

- [x] **Phase 4: SAY Defaults + Click-Through** (1/1 plan) — Fresh installs default SAY-only listen + `macroChannel="SAY"`; upgrade-safe backfill (SAFE-06 zero-match gate); locked window is fully click-through (`EnableMouse(not locked)` cascade across window + slot frames). Completed 2026-05-09.
- [x] **Phase 5: Auto-Hide Combat Reframe** (1/1 plan) — Auto-hide toggle becomes in-combat-only; out-of-combat empty window stays visible (toggle self-evident); permanent `PLAYER_REGEN_*` listener re-evaluates soft-hide on every combat-state edge; `inCombat` flag seeded via `InCombatLockdown()` at frame creation; AMEND-01 invariant (alpha=0, never `win:Hide()`) preserved. Completed 2026-05-10.
- [x] **Phase 6: Dynamic Label + Symbol Reference Image** (1/1 plan) — Cheat-sheet image (`reference.tga`, 319×143) at top of config panel as first visual element; Show/Hide + Lock/Unlock button labels refresh live via `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` with sentinel data flags; scroll position preserved across label refresh. Completed 2026-05-10.

Full detail:
- [`.planning/milestones/v1.0.0-ROADMAP.md`](milestones/v1.0.0-ROADMAP.md) — full per-phase ROADMAP snapshot
- [`.planning/milestones/v1.0.0-REQUIREMENTS.md`](milestones/v1.0.0-REQUIREMENTS.md) — 15/15 requirements complete
- [`.planning/milestones/v1.0.0-phases/`](milestones/v1.0.0-phases/) — per-phase CONTEXT/PLAN/SUMMARY/VERIFICATION

</details>

### 📋 v1.1+ TBD

Next milestone scope TBD. Run `/gsd-new-milestone` to define.

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Scaffolding & Foundation | v0.1.0 | 3/3 | Complete | 2026-04-30 |
| 2. POC Port (Macros, Window, Commands) | v0.1.0 | 3/3 | Complete | 2026-05-01 |
| 3. Config Panel & Integration | v0.1.0 | 1/1 | Complete | 2026-05-01 |
| 4. SAY Defaults + Click-Through | v1.0.0 | 1/1 | Complete | 2026-05-09 |
| 5. Auto-Hide Combat Reframe | v1.0.0 | 1/1 | Complete | 2026-05-10 |
| 6. Dynamic Label + Symbol Reference Image | v1.0.0 | 1/1 | Complete | 2026-05-10 |
