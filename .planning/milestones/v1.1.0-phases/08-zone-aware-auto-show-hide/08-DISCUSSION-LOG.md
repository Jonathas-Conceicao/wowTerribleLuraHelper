# Phase 8: Zone-Aware Auto Show/Hide - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-16
**Phase:** 08-zone-aware-auto-show-hide
**Areas discussed:** M of Q mapping scope (user-selected; the other two areas were delegated to Claude's Discretion)

---

## Gray Area Selection

The orchestrator surfaced 3 gray areas at the start of discussion:

| Option | Description | Selected |
|--------|-------------|----------|
| Handler location + frame | Where the zone-change handler lives (Core.lua / Window.lua / new Zone.lua) and frame strategy | (delegated to Claude's Discretion) |
| Print feedback policy | Silent vs chat print on zone auto-fires | (delegated to Claude's Discretion) |
| M of Q mapping scope | Single mapID vs set; instance-vs-outdoor; difficulty handling | ✓ User-discussed |
| All three | Discuss all three in order | |

**User's choice:** "M of Q mapping scope"
**Notes:** User wanted to confirm scope explicitly; delegated the other two areas to Claude's recommendations. Same delegation pattern as Phase 7.

---

## M of Q Mapping Scope (user-locked)

**Sub-question presented:**
> Where does the L'ura encounter live, and what should 'in zone' mean for auto show/hide?

| Option | Description | Selected |
|--------|-------------|----------|
| M of Q outdoor only | L'ura is a world boss in the outdoor M of Q zone; single mapID; window hides on entering any instance from M of Q | |
| M of Q + adjacent instance(s) | L'ura is inside an instance accessed from M of Q; in-zone set includes M of Q outdoor + the instance(s) | |
| Other / let research figure it out | Have research confirm L'ura's actual location and pick scope based on that | |

**User's choice (verbatim):** "L'ura is in the raid instance m of q, not on open world, not on other zones like magister's terrace. the raid self has 4 difficulties, lfr, normal, heroic and mythic; the addon should auto-toggle for any of them. research should show of they have different IDs or not, and what they are"

**Captured decisions (CONTEXT D-01 / D-02 / D-03 / D-04):**
- L'ura is inside the **March of Quel'danas raid instance** (NOT the outdoor zone, NOT Magister's Terrace).
- Auto-toggle must work across **all 4 difficulties** (LFR / Normal / Heroic / Mythic).
- Research surface: confirm whether the 4 difficulties share a single mapID (typical) or have distinct IDs (atypical).
- The mapID(s) are encoded as hardcoded numeric literal(s) in the addon source — no zone-name strings.
- If research can't pin them down from documented sources, the planner adds a "verify-via-`/dump`-in-game" task to the plan.

**Alternatives explicitly rejected:**
- Outdoor M of Q zone (if any exists in Midnight) — the user said "not on open world".
- Magister's Terrace and other adjacent instances — the user said "not on other zones".
- Multi-difficulty differentiation — the user said "auto-toggle for any of them".

---

## Handler Location + Frame (Claude's Discretion)

**Decision (CONTEXT D-05 / D-06 / D-09):**
- New permanent `zoneFrame` in `Core.lua` (file-scope `CreateFrame("Frame")`).
- Registers `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA` once at load, never unregisters.
- Handler `ns:OnZoneChanged()` lives in Core.lua alongside the existing `eventFrame` and `ns:PrintHelp` / `ns:HandleSlashCommand` functions.

**Alternatives rejected:**
- Handler in Window.lua — would couple Window.lua to event-dispatching, which is Core.lua's responsibility.
- New Zone.lua file — overkill for a single handler in a 4-file project.
- Reusing the existing `eventFrame` — that frame is a one-shot for ADDON_LOADED/PLAYER_LOGIN that unregisters after firing; permanent listener needs its own frame.

---

## Print Feedback Policy (Claude's Discretion)

**Decision (CONTEXT D-10 / D-11):**
- **Silent** — no chat output on zone-driven auto show/hide.
- No debug print at addon-load time showing the detected mapID (optional Claude's-discretion-for-planner: gated behind a `local DEBUG = false` constant).

**Alternatives rejected:**
- Chat print on every zone change (e.g. `TLH: Entered March of Quel'danas — showing window`) — would be spammy across taxi flights and frequent zone boundaries; adds no information beyond the visible window state change.
- Permanent debug print of detected mapID at addon-load — clutters chat for the normal user; only useful during initial mapID verification.

---

## Other Claude's Discretion (CONTEXT.md detailed)

- D-07: Re-evaluate on every event fire (no state tracking) — Show/Hide are no-ops on already-shown/hidden frames.
- D-08: Mapping check skeleton with `C_Map.GetBestMapForUnit("player")` (subject to research confirmation).
- D-12..D-16: Interaction with existing paths (ADDON_LOADED's RestoreWindowVisibility, `db.window.visible`, Phase 5 soft-hide, Phase 6 dynamic-label refresh, hard taint constraints) — no new logic needed; existing wiring composes correctly.
- D-17: UAT checkpoints (will be batched with Phase 7's UAT per user preference).

## Deferred Ideas

- Auto-show for outdoor M of Q zone (if separate from raid in Midnight) — not relevant; L'ura is in the raid.
- Auto-show for Magister's Terrace / Sunwell Plateau / other Midnight raids — explicit user OOS.
- Configurable in-zone mapID set — out of scope; hardcoded for v1.1.0.
- Print feedback on zone auto-fires — rejected as spammy.
- Kill-switch toggle for the auto-feature — out of scope per REQUIREMENTS.
- Saved manual hide/show state across `/reload` — user picked auto-show on every fire (WIN-17).
