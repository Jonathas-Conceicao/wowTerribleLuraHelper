# Phase 2: POC Port (Macros, Window, Commands) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-30
**Phase:** 02-poc-port-macros-window-commands
**Areas discussed:** Lock button position + styling, Window backdrop / template, State edge cases (mid-combat enable, sequence on hide, bare `/lura` toggle), Slash command surface revision (drop /lura clear, add /lura help), Inactivity timeout amendment

---

## Selection: Which gray areas to discuss?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-hide hook pre-wiring | Phase 2 reads db.window.autoHide so Phase 3 just adds the UI checkbox — OR — Phase 2 ignores it, Phase 3 does both UI + behavior wholesale | |
| Lock button: position + styling | Where does the on-window lock/unlock toggle live? POC has none — placement and look | ✓ |
| State edge cases | Mid-combat /lura show, /lura hide preserve sequence?, /lura no-arg toggle mid-fight | ✓ |
| Window backdrop / template | POC uses BackdropTemplate with purple border — keep verbatim, modernize to Blizzard template, restyle | ✓ |

**User's choice:** Lock button, Window backdrop, State edge cases. Auto-hide pre-wiring deferred to Phase 3 wholesale.

---

## Lock Button Position + Styling

| Option | Description | Selected |
|--------|-------------|----------|
| Top-right icon, next to close | Small padlock icon button to the immediate left of the close-X button. Open-padlock when unlocked, closed-padlock when locked. | ✓ |
| Title-bar text toggle | Click the title text itself to toggle. | |
| Bottom-right corner button | Padlock at bottom-right, away from close button. | |
| Right-click window for menu | Right-click background opens a tiny menu with Lock/Unlock + Reset Position. | |

**User's choice:** Top-right icon, next to close.

---

## Window Backdrop / Template

| Option | Description | Selected |
|--------|-------------|----------|
| Keep POC verbatim | BackdropTemplate, dark-purple bg, bright-purple border — Midnight theme, proven in-game | |
| Restyle to neutral / less saturated | Same template, calmer purple | |
| Modern Blizzard template | Drop BackdropTemplate, use ButtonFrameTemplate / BasicFrameTemplateWithInset / similar | ✓ |

**User's choice:** Modern Blizzard template (planner picks the specific one — `BasicFrameTemplateWithInset` recommended in CONTEXT.md D-17).

**Notes:** The specific template choice (BasicFrameTemplate vs BasicFrameTemplateWithInset vs PortraitFrameTemplate vs ButtonFrameTemplate) is delegated to the planner with a note to verify by reading wow-ui-source.

---

## State Edge Cases

### Question 1: Mid-combat /lura show

| Option | Description | Selected |
|--------|-------------|----------|
| Register events immediately | If combat is active when /lura show fires, register CHAT_MSG_* right then. | ✓ |
| Wait for next combat cycle | Mark enabled but don't register until next PLAYER_REGEN_DISABLED. | |
| Register + show + reset to empty | Register immediately, show window, but wipe any prior sequence. | |

**User's choice:** Register events immediately.

### Question 2: /lura hide sequence preservation

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve sequence in DB | Window hides, events ignored, db.sequence intact across /reload. | |
| Wipe sequence on hide | Window hides AND db.sequence wiped. | (closest match) |
| Preserve in-memory, wipe on /reload | Sequence stays in memory until /reload, then gone. | |

**User's choice (extended):** "Data already auto cleans 15s after no new input (we can update this to 20 seconds to be safer btw), we don't have to worry about preserving anything. /lura hide clears everything, and nothing has to persist on reload either. Save only to memory and avoiding disk writes is even better."

**Notes:** This produces TWO scope changes recorded in CONTEXT.md as D-27/D-28 and amended in REQUIREMENTS.md:
- **WIN-06 timeout: 15s → 20s** (per "we can update this to 20 seconds")
- **WIN-07 dropped entirely** — sequence is in-memory only, not in `TerribleLuraHelperDB`. Cleared on /lura hide, on 20s inactivity, and on /reload. Requires Phase 2 to also remove `db.sequence = {}` from Phase 1's Core.lua schema as a first task.

### Question 3: Bare /lura behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Pure toggle | enabled → disable, disabled → enable | ✓ |
| Smart toggle: also clear if showing | 3-state cycle | |
| Show help if no args | Bare /lura prints help; explicit show/hide required | |

**User's choice:** Pure toggle.

---

## Slash Command Surface Revision (added at the "Done?" gate)

User said: "For /lura commands, we should have show, hide, config, help. Where config opens the addon config window on tlh page, and help shows the cli options; we also should have /tlh alongside /lura with the same subcommands"

This implied dropping `/lura clear` and adding `/lura help`. Confirmed via follow-up:

### Question: Keep or drop /lura clear?

| Option | Description | Selected |
|--------|-------------|----------|
| Drop /lura clear | Removed entirely. /lura hide does the wipe; 20s timer auto-clears. | ✓ |
| Keep /lura clear | Useful between pulls when you want to reset slots without disabling. | |

**User's choice:** Drop.

**Final command set captured in CONTEXT.md D-23..D-26 + CMD-07 added to REQUIREMENTS.md:**
- `/lura show` (enable + show)
- `/lura hide` (disable + wipe + hide)
- `/lura config` (Phase 3 opens Options > AddOns > TLH)
- `/lura help` (NEW — prints command list)
- `/lura` (pure toggle)
- `/tlh` (alias with same subcommands)

**Dropped:** `/lura clear` (was CMD-04).

---

## Claude's Discretion (planner picks)

- Exact Blizzard frame template (BasicFrameTemplateWithInset recommended; planner verifies via wow-ui-source).
- Padlock button textures (Blizzard built-in lock/unlock atlas paths).
- Slash command help text formatting and color codes.
- Module-internal organization of Window.lua.
- Whether to expose `INACTIVITY_TIMEOUT` and other named constants at module top.
- Title-bar color (template default is fine).

## Deferred Ideas (parked, not in scope)

- Configurable inactivity timeout (still OOS; D-28 only changes the literal).
- Sequence persistence across /reload (dropped per D-27).
- /lura clear standalone command (dropped per Slash command revision).
- Off-screen window position guard (SetClampedToScreen handles it).
- Auto-hide-when-empty hook pre-wiring (Phase 3 wholesale).
- Custom addon icon (.blp) — still OOS in PROJECT.md.
