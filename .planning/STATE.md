---
gsd_state_version: 1.0
milestone: v1.1.0
milestone_name: QoL Update
status: milestone_shipped
stopped_at: v1.1.0 squash-merged and tagged
last_updated: "2026-05-16T00:00:00.000Z"
last_activity: 2026-05-16 -- v1.1.0 milestone complete (squash-merge to main + tag v1.1.0). Both phases delivered; 9/9 reqs validated; combined Phase 7+8 UAT 16/16 passed.
progress:
  total_phases: 8
  completed_phases: 8
  total_plans: 12
  completed_plans: 12
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-16)

**Core value:** The five runes that L'ura shows must arrive — in the right order — on every raid member's screen, during the boss-fight chat-messaging-lockdown that blocks normal addon chat output.
**Current focus:** v1.1.0 shipped — next milestone TBD via `/gsd-new-milestone`

## Current Position

Phase: — (between milestones)
Plan: —
Status: v1.1.0 shipped 2026-05-16
Last activity: 2026-05-16 — milestone squash-merge + tag

Progress: [##########] 100% — 8/8 phases complete across v0.1.0 + v1.0.0 + v1.1.0

## Shipped Milestones

| Version | Title | Phases | Shipped |
|---------|-------|--------|---------|
| v0.1.0 | Initial Release | 1–3 | 2026-05-01 |
| v1.0.0 | Polish & Defaults | 4–6 | 2026-05-10 |
| v1.1.0 | QoL Update | 7–8 | 2026-05-16 |

See [.planning/MILESTONES.md](MILESTONES.md) for full milestone history and [.planning/RETROSPECTIVE.md](RETROSPECTIVE.md) for cross-milestone lessons.

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. v0.1.0 + v1.0.0 + v1.1.0 decisions all marked ✓ Shipped.

Carry-over invariants for any future milestone:

- **AMEND-01: visibility-gated chat-event registration.** `OnShow` registers `CHAT_MSG_*`, `OnHide` unregisters and wipes the sequence. Soft-hide (alpha=0) MUST NOT call `win:Hide()` — would unregister events and break the next marker in combat. Zone-change auto-show/hide routes through the same `Show()` / `Hide()` paths as `/lura show` / `/lura hide` to keep this invariant intact (verified by Phase 8).
- **SAFE-06 grep gate.** Repo-wide `git grep "= db\." -- '*.lua' | grep " or "` must return zero matches. All backfill paths use `if db.X == nil then`.
- **SCAF-19 localization-safety.** Zone/instance detection uses numeric IDs (mapID, instanceID), never locale-dependent strings. No `GetZoneText` / `GetRealZoneText` / `GetMinimapZoneText` in any auto-handler.
- **No `SendChatMessage`, ever.** Boss-fight chat lockdown blocks tainted strings. User-bound macros are the only viable channel.
- **Never touch `msg` from `CHAT_MSG_*` events.** No index, no length, no gsub, no match, no concat, no pattern test. Only `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` → `FontString:SetText`.
- **`COMBAT_LOG_EVENT_UNFILTERED` is disabled in Midnight.** Do not use.
- **Macro creation/edit is blocked during combat.** Guard with `InCombatLockdown()`, defer to `PLAYER_REGEN_ENABLED`.
- **Verbose tokens (`{diamond}` etc.) only render on English WoW clients.** `{rt#}` is universal across all locales. Any future user-visible chat-formatting feature must respect this.

### Open Blockers

None.

### Deferred Items

None at v1.1.0 close.

## Next Step

Run `/gsd-new-milestone` to start the next milestone (questioning → research → requirements → roadmap).

Recommended `/clear` before starting fresh — current session has accumulated v1.1.0 close-out context that won't be relevant to the next milestone's discovery work.
