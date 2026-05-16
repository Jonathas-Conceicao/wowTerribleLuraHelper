# Phase 7: Verbose-Marker Toggle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 07-verbose-marker-toggle
**Areas discussed:** Toggle placement & copy, Print-feedback wording, Payload table shape

---

## Gray Area Selection

The orchestrator surfaced 3 gray areas at the start of discussion:

| Option | Description | Selected |
|--------|-------------|----------|
| Toggle placement & copy | Where in the Macros section the "Use verbose markers" checkbox lives + the exact label + tooltip wording | (delegated) |
| Print-feedback wording | Exact text the addon prints when the toggle changes; analog is `OnMacroChannelChanged`'s `TLH: Macro target → /s. Macros updated.` (+ deferred-during-combat variant) | (delegated) |
| Payload table shape | How the `MACROS` table in `Macros.lua` represents the dual-payload (verbose vs rt#) state | (delegated) |
| All three | Discuss all three in order | |

**User's choice:** "None of these, I think you can handle these items as you see fit"
**Notes:** User explicitly delegated all three areas. All decisions captured in CONTEXT.md as Claude's-Discretion with concrete recommendations and reasoning so the planner can act without re-asking.

---

## Toggle placement & copy (Claude's Discretion)

**Decision (CONTEXT D-04 / D-05 / D-06 / D-07 / D-08):**
- Position: Inside `RegisterMacroSection` (`Config.lua:313-396`), between section (3a) macro-target dropdown and (3b) Recreate button.
- Label: "Use verbose markers".
- Tooltip: "When on, macros emit `{diamond}` / `{triangle}` / `{circle}` / `{cross}` — these render correctly in more chat addons than the older `{rt3}` / `{rt4}` / `{rt2}` / `{rt7}` codes. Turn off only if your chat addon doesn't expand the verbose names. The 5th macro (TLH_T) sends the letter T either way."
- Variable: `TLH_VERBOSE_MARKERS` (uppercase-prefix convention); SavedVar field `verboseMarkers` (top-level, not nested).
- Registration follows the existing Auto-hide checkbox shape from `Config.lua:161-180`.

**Alternatives rejected:**
- Position above the Macros section header — breaks the existing top-down "header → controls" structure.
- Position below Delete button — separates it from the related macro controls.
- "Verbose markers" (no verb prefix) — breaks the panel's verb-prefix convention.
- "Use legacy rt# codes" (toggle named for fallback, default OFF) — makes the modern default feel obscure; framing toggle for default-ON state reads better.
- Nested `db.macros.verboseMarkers` — introduces a new namespace for a single boolean; over-engineered.

---

## Print-feedback wording (Claude's Discretion)

**Decision (CONTEXT D-10):**
- ON, immediate: `TLH: Verbose markers on. Macros updated.`
- OFF, immediate: `TLH: Verbose markers off. Macros updated.`
- ON, deferred (in combat): `TLH: Verbose markers on. Macros will update when you leave combat.`
- OFF, deferred (in combat): `TLH: Verbose markers off. Macros will update when you leave combat.`
- All use the existing `|cffaa44ffTLH|r:` color prefix.
- No arrow (`→`) — the macro-channel dropdown uses one because it shows a target value; a boolean on/off doesn't need one.

**Alternatives rejected:**
- `TLH: Verbose markers → on. ...` — arrow implies "changed to", redundant for boolean.
- `TLH: Now using verbose markers. ...` — verbose, drops the parallel "Macros updated." suffix.
- Single-line concatenation without the "Macros updated." suffix — matches the macro-channel-dropdown analog less closely.

---

## Payload table shape (Claude's Discretion)

**Decision (CONTEXT D-01 / D-02 / D-03):**
- Dual fields per row in the existing `MACROS` table — `payloadVerbose` + `payloadRT` on the four marker macros; `TLH_T` keeps single `payload`.
- Payload selection in `RegisterMacros` uses an inline conditional: `local payload = m.payload or (ns.db.verboseMarkers and m.payloadVerbose or m.payloadRT)`.
- `m.payload` short-circuits for `TLH_T`; falls through to the boolean-driven choice for the four marker macros.

**Alternatives rejected:**
- Single nested `payload = { verbose = ..., rt = ... }` table per row — unnecessary nesting.
- Two parallel lookup tables (`PAYLOADS_VERBOSE`, `PAYLOADS_RT`) keyed by macro name — splits payload data from the rest of the row; error-prone when adding a macro.
- Builder function per row — over-engineered for a binary string choice.

---

## Claude's Discretion

All three discussed gray areas were delegated by the user. See CONTEXT.md §"Implementation Decisions" for the locked recommendations and §"Claude's Discretion" for the remaining flexibility the planner can resolve.

## Deferred Ideas

- `/lura verbose on|off` slash command — natural CLI mirror of the panel toggle, but CFG-15 only specifies a config-panel checkbox. Deferred to a future milestone if requested.
- Auto-detect chat-addon verbose-token support — fragile + over-engineered.
- Per-macro verbose override — explicitly OOS per requirements.
- Migrating macro names (`TLH_Diamond` → ...) — would force re-drag to action bars.
- One-time "we changed your macros" post-upgrade notice — would feel intrusive.
