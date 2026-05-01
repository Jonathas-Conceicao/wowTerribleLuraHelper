---
gsd_state_version: 1.0
milestone: v0.1.0
milestone_name: milestone
status: milestone_complete
stopped_at: Completed 03-01-PLAN.md Tasks 1–5; Task 6 (in-game smoke verify) PENDING
last_updated: "2026-05-01T12:00:00.000Z"
last_activity: 2026-05-01
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 7
  completed_plans: 6
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-30)

**Core value:** The five runes that L'ura shows must arrive — in the right order — on every raid member's screen, during the boss-fight chat-messaging-lockdown that blocks normal addon chat output.
**Current focus:** Phase 3 — Config Panel & Integration (code complete; awaiting in-game smoke verification)

## Current Position

Phase: 3
Plan: Not started
Next: Run install.bat + 15-step in-game smoke pass (see 03-01-SUMMARY.md), then squash-merge milestone/0.1.0 → main and tag v0.1.0
Last activity: 2026-05-01

Progress: [██████████] 100% of defined plans (6/7); Phase 3 plan 1/1 implemented, awaiting human-verify checkpoint

## Performance Metrics

**Velocity:**

- Total plans completed: 7
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3 | - | - |
| 2 | 3 | - | - |
| 3 | 1 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 01 P01 | 131 | 3 tasks | 5 files |
| Phase 01 P02 | 122 | 3 tasks | 5 files |
| Phase 01 P03 | 2 | 2 tasks | 4 files |
| Phase 02 P01 | 15 | 3 tasks | 2 files |
| Phase 02 P02 | 8 | 3 tasks | 1 file |
| Phase 02 P03 | 12 | 2 tasks | 1 file |
| Phase 03 P01 | TBD | 5 tasks (+1 human-verify) | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: 3 phases (coarse granularity) — scaffolding entangled with first runnable Core.lua, so Phase 1 owns both; POC port is one phase; config panel is its own phase because Settings API research already de-risked it.
- Roadmap: SAFE-01..04 cross-cutting requirements anchored in Phase 2 (where the chat-event handler, macro creation site, and gating logic first exist).
- Roadmap: WIN-08 (scale slider live-update) and CMD-05 (/lura config) live in Phase 3 because they require the config panel; default scale value is initialized in Phase 1's SavedVariables defaults.
- milestone/0.1.0 branch created from main at 55e2b03 and pushed to origin; all Phase 1 commits must land here
- CLAUDE.md verified against SCAF-11 full checklist (8/8 checks pass); no patches needed
- All five addon files (TOC + 4 Lua) committed as a single unit — the addon does not load with any missing
- D-06 honored: Phase 1 does NOT push a tag — release pipeline committed but first live run is v0.1.0 at milestone-merge time
- D-07: CHANGELOG-cutoff awk copied verbatim from TBT: awk '/^## /{if(found) exit; found=1} found' CHANGELOG.md > RELEASE_NOTES.md
- D-08 fixed: release.bat pushes CURRENT branch via git rev-parse --abbrev-ref HEAD (not hardcoded main) — works from milestone/* or main
- D-27: db.sequence removed from schema and backfill — in-memory only
- D-33/D-34: Macros.lua verbatim POC port with Lua-local printed-once flag
- D-35..37: db.window.alpha=1.00 added to Core.lua defaults and backfill
- D-14..D-22: Window.lua chrome (BasicFrameTemplateWithInset, lock button left of CloseButton, drag-position 5-tuple persistence)
- D-25/D-27: window hidden by default, no auto-show on chat; sequence is Lua local (in-memory only)
- D-28/D-29: 20s INACTIVITY_TIMEOUT named constant
- D-30..D-32: chat pipeline taint-safe — C_ChatInfo only, channel filter via event:sub(10), combat+enabled gating
- D-23..D-26: slash dispatcher — /lura show→Enable; /lura hide→Disable (wipe+hide+unregister); bare /lura toggles db.enabled; /tlh full alias via separate SLASH_TLH1 namespace
- T-SLASH-PARSER mitigation: parser uses :lower():match against closed-set literals; no loadstring/setfenv anywhere in repo
- Phase 3 D-01..D-05: modern Settings API (Settings.RegisterAddOnCategory + RegisterAddOnSetting post-11.0.2 signature); EventUtil.ContinueOnAddOnLoaded gate; cache numeric category ID for /lura config
- Phase 3 D-10/D-33: channel DB keys are INSTANCE_CHAT / INSTANCE_CHAT_LEADER (matching Window.lua chat handler event:sub(10) keys); SETTINGS_API.md research example was wrong on this point
- Phase 3 D-18..D-22: soft-hide model (alpha=0, NOT win:Hide()) so chat events stay registered while window is auto-hidden; FillSlot/ClearAll/ShowWindow drive applySoftHideState
- Phase 3 D-25..D-28: 8-command slash surface (added /lura lock + /lura unlock as escape hatches); ns.SLASH_HELP shared between Config.lua panel section and Core.lua ns:PrintHelp for single source of truth
- Phase 3 D-35..D-40: db.macroChannel string field (RAID/RAID_WARNING/SAY); CHANNEL_PREFIX lookup builds macro body at registration time; sections re-organized to Chat channels / Window / Macros / Slash commands (Lock button moved up into Window)

### Pending Todos

- **Phase 3 / Plan 03-01 / Task 6 (human-verify checkpoint)**: 15-step in-game smoke pass against the installed addon. See `.planning/phases/03-config-panel-integration/03-01-SUMMARY.md` for the checklist. Resume signal: user types "approved".

### Blockers/Concerns

None yet — all 5 implementation tasks committed clean (stylua + SAFE-01/SAFE-02 grep + 0 InterfaceOptions_AddCategory). The only gate is the human in-game smoke pass.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-05-01T12:00:00.000Z
Stopped at: Completed 03-01-PLAN.md Tasks 1–5 (5 commits on milestone/0.1.0); Task 6 (human-verify in-game smoke) PENDING
Resume file: .planning/phases/03-config-panel-integration/03-01-SUMMARY.md

**Planned Phase:** 3 (Config Panel & Integration) — 1 plan — 2026-05-01
**Completed Phase:** 2 (POC Port) — all 3 plans done — 2026-05-01
**Next Phase:** 3 (Config Panel & Integration) — code complete; awaiting in-game smoke approval; then squash-merge to main + tag v0.1.0
