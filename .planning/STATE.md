---
gsd_state_version: 1.0
milestone: v1.0.0
milestone_name: Polish & Defaults
status: milestone_shipped
stopped_at: v1.0.0 squash-merged and tagged
last_updated: "2026-05-10T23:30:00.000Z"
last_activity: 2026-05-10 -- v1.0.0 milestone complete (squash-merge + tag)
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 10
  completed_plans: 10
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-10)

**Core value:** The five runes that L'ura shows must arrive — in the right order — on every raid member's screen, during the boss-fight chat-messaging-lockdown that blocks normal addon chat output.
**Current focus:** v1.0.0 shipped — next milestone TBD via `/gsd-new-milestone`

## Current Position

Phase: — (between milestones)
Plan: —
Status: v1.0.0 shipped 2026-05-10
Last activity: 2026-05-10 — milestone squash-merge + tag

Progress: [##########] 100% — 6/6 phases complete across v0.1.0 + v1.0.0

## Shipped Milestones

| Version | Title | Phases | Shipped |
|---------|-------|--------|---------|
| v0.1.0 | Initial Release | 1–3 | 2026-05-01 |
| v1.0.0 | Polish & Defaults | 4–6 | 2026-05-10 |

See [.planning/MILESTONES.md](MILESTONES.md) for full milestone history and [.planning/RETROSPECTIVE.md](RETROSPECTIVE.md) for cross-milestone lessons.

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. v1.0.0 decisions all marked ✓ Shipped.

Carry-over invariants for any future milestone:

- **AMEND-01: visibility-gated chat-event registration.** `OnShow` registers `CHAT_MSG_*`, `OnHide` unregisters and wipes the sequence. Soft-hide (alpha=0) MUST NOT call `win:Hide()` — would unregister events and break the next marker in combat.
- **SAFE-06 grep gate.** Repo-wide `git grep "= db\." -- '*.lua' | grep " or "` must return zero matches. All backfill paths use `if db.X == nil then`.
- **No `SendChatMessage`, ever.** Boss-fight chat lockdown blocks tainted strings. User-bound macros are the only viable channel.
- **Never touch `msg` from `CHAT_MSG_*` events.** No index, no length, no gsub, no match, no concat, no pattern test. Only `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` → `FontString:SetText`.
- **`COMBAT_LOG_EVENT_UNFILTERED` is disabled in Midnight.** Do not use.
- **Macro creation/edit is blocked during combat.** Guard with `InCombatLockdown()`, defer to `PLAYER_REGEN_ENABLED`.

### Open Blockers

None.

### Deferred Items

None at v1.0.0 close.

## Next Step

Run `/gsd-new-milestone` to start the next milestone (questioning → research → requirements → roadmap).

Recommended `/clear` before starting fresh — current session has accumulated v1.0.0 close-out context that won't be relevant to the next milestone's discovery work.
