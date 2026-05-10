# Phase 4: SAY Defaults + Click-Through - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 04-say-defaults-click-through
**Areas discussed:** Click-through implementation scope, /lura lock during combat, Upgrade notification (v0.1.0 → v1.0.0)

---

## Gray-Area Selection (multiSelect)

| Option | Description | Selected |
|--------|-------------|----------|
| Click-through implementation scope | Minimal (single `win:EnableMouse(not locked)` line) vs defensive (iterate slot frames + lockBtn). Both yield identical UX today; difference is future-regression risk vs code minimalism. | ✓ |
| `/lura lock` during combat | Call EnableMouse immediately (trust STACK.md) vs add a defer-on-combat retry path mirroring MACR-03. | ✓ |
| Upgrade notification (v0.1.0 → v1.0.0) | Silent vs one-time chat print vs `db.schemaVersion` field. | ✓ |

**Outcome:** All three areas selected for discussion.

---

## Click-through implementation scope

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — just `win:EnableMouse(not locked)` (Recommended) | Single-line change in `applyLockState()`. Slot frames already default to mouse-disabled (verified in current Window.lua). Nothing else needs touching. Smallest diff, easiest to review. | ✓ |
| Defensive — iterate slot frames + lockBtn explicitly | Loop over `slotFrames[1..5]` calling `EnableMouse(false/true)` to match `win`. Future-proofs against someone adding `EnableMouse(true)` to a slot in a later phase. Slightly more code; identical user-facing behavior today. | |

**User's choice:** Minimal — just `win:EnableMouse(not locked)`
**Notes:** Recommended path; matches user's consistent simplicity preference. Captured as D-01 / D-02 / D-03 in CONTEXT.md. If a later phase introduces `EnableMouse(true)` on a child frame, that phase will own the matching lock-state coupling for its own frame.

---

## `/lura lock` during combat

| Option | Description | Selected |
|--------|-------------|----------|
| Call immediately — trust STACK.md (Recommended) | Just call `win:EnableMouse(false)` directly. STACK.md verified `TerribleLuraHelperWindow` is plain `CreateFrame("Frame", ...)` (not protected), and `EnableMouse` on non-protected frames is combat-safe. Zero deferral logic. | ✓ |
| Defer + retry — mirror MACR-03 pattern | If `InCombatLockdown()`, cache the pending lock change and retry on `PLAYER_REGEN_ENABLED`. Adds shared deferral state. PITFALLS.md was conservative on this (CT-3) but STACK.md's verification carries authority. | |

**User's choice:** Call immediately — trust STACK.md
**Notes:** Captured as D-04 / D-05 / D-06 in CONTEXT.md. Phase 4 UAT must include `/lura lock` during a live combat encounter to confirm zero `ADDON_ACTION_BLOCKED` errors. If a problem surfaces in practice, deferral can be added as a v1.0.1 patch.

---

## Upgrade notification (v0.1.0 → v1.0.0)

| Option | Description | Selected |
|--------|-------------|----------|
| Silent (Recommended) | No chat print, no schema field. Existing users keep their previous settings and discover the new defaults only if they /reset or check the config panel. Matches the addon's existing low-noise style. | ✓ |
| One-time print on first reload | Track via `db.notifiedV1` boolean. Brief message about defaults shifting and existing settings being preserved. | |
| Introduce `db.schemaVersion` field | Add `schemaVersion = 2`; print on bump. Reusable for future migrations. Slightly more scaffolding now. | |

**User's choice:** Silent
**Notes:** Captured as D-07 / D-08 in CONTEXT.md. No `db.schemaVersion` introduced in v1.0.0 — YAGNI; reconsider if a future migration needs it.

---

## Claude's Discretion

Areas left for Claude to decide during planning/implementation:
- Exact code-comment wording for the SAFE-06 reminder near the backfill block
- Whether to factor the new `LISTEN_DEFAULTS` table into a top-of-file local or inline within the backfill loop
- Whether the upgrade-test step adds an automated grep + manual UAT, or just one or the other
- Code-style choice for the click-through line (`win:EnableMouse(not locked)` ternary-ish vs explicit if/else mirroring the existing `applyLockState` shape)

## Deferred Ideas

(All captured in CONTEXT.md `<deferred>` section; mirrored here for audit trail.)
- Schema-versioning scaffold — defer to v1.1.0+ if/when needed
- Defensive `EnableMouse` iteration over slot frames — defer until a future phase adds `EnableMouse(true)` on a child
- One-time chat print on upgrade — defer; reconsider if user feedback shows missed-default-shift
- CI / pre-commit grep for SAFE-06 — defer; manual PR-review grep is sufficient at current scale
