# Phase 6: Dynamic Label + Symbol Reference Image - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 06-dynamic-label-symbol-reference-image
**Areas discussed:** Image-frame architecture, Image sizing strategy, UI-SPEC requirement

---

## Gray-Area Selection (multiSelect)

| Option | Description | Selected |
|--------|-------------|----------|
| Image-frame architecture | XML template file vs inline Lua frame for the reference texture | ✓ |
| Image sizing strategy | Stretch to panel width vs intermediate fixed size vs native | ✓ |
| UI-SPEC requirement | /gsd-ui-phase 6 first vs plan directly with --skip-ui | ✓ |

**Outcome:** All three areas selected for discussion.

---

## Image-frame architecture

| Option | Description | Selected |
|--------|-------------|----------|
| XML template file (Recommended — canonical) | New `templates.xml` at repo root with `<Frame name="TLHSymbolReferenceTemplate" virtual="true">` containing child `<Texture>`. Register in `.toc` after Lua files. Reference from Lua via `Settings.CreateElementInitializer(template_name, data)`. Matches STACK.md verified pattern + Blizzard conventions. | ✓ |
| Inline Lua frame, no XML | Define frame programmatically in Config.lua via CreateFrame + child texture. Saves an XML file; less idiomatic; risk of built-in templates not accommodating static-texture mounting cleanly. | |

**User's choice:** XML template file
**Notes:** Captured as D-01 / D-02 in CONTEXT.md. New `templates.xml` at repo root, added to `.toc` after Lua files. Frame definition: minimal Frame + child Texture layered "ARTWORK". Init callback (Mixin or initializer data-handler) calls `texture:SetTexture(self.data.texturePath)` once per panel-open. Texture file is small (182KB) — Blizzard caches on first load, no per-open async re-fetch.

---

## Image sizing strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Stretch to full panel width, preserve aspect (Recommended) | Frame width = panel content width; height = width * (143/319). Image fills horizontally with preserved aspect. Some upscaling softness possible. | |
| Centered at intermediate fixed size (e.g. 480x215) | Frame at 480x215, centered. More controlled; doesn't fill panel width — leaves margins. | |
| Native size (319x143) | Frame sized exactly to texture. Smallest visual presence; no upscaling artifacts. Consistent with the user's "simple/literal/no-upscaling" preference. | ✓ |

**User's choice:** Native size (319x143)
**Notes:** Captured as D-04 / D-05 / D-06 in CONTEXT.md. Frame dimensions exactly 319×143 — preserves texture crispness; no `SetTexCoord` letterboxing needed (default `SetTexCoord(0, 1, 0, 1)` shows full texture). Frame anchor strategy is Claude's Discretion (recommendation: TOP-anchor with small inset, horizontally CENTERED). Smaller visual footprint leaves more panel space for actual controls.

---

## UI-SPEC requirement

| Option | Description | Selected |
|--------|-------------|----------|
| Plan directly with --skip-ui (Recommended) | Match Phase 4/5 pattern. Phase 6's UI surface is small (one new visible element + button-label refresh mechanism). CONTEXT.md decisions are sufficient scaffolding for the planner. UI-SPEC adds friction without much benefit at this scope. | ✓ |
| Run /gsd-ui-phase 6 first | Generate formal UI-SPEC.md for Phase 6. More disciplined; useful if the visual design needs further refinement. Adds one workflow step before /gsd-plan-phase 6. | |

**User's choice:** Plan directly with --skip-ui
**Notes:** Captured as D-07 in CONTEXT.md. Phase 6 plan invocation: `/gsd-plan-phase 6 --skip-research --skip-ui` (matches Phase 4/5 pattern). All design decisions captured in 06-CONTEXT.md are concrete enough for the planner to specify the implementation precisely.

---

## Claude's Discretion

Areas left for Claude to decide during planning/implementation:
- Exact XML template structure (Frame + Texture + optional Mixin OnLoad). Recommendation: keep minimal — one Frame, one Texture child layered "ARTWORK", no backdrop/border.
- Frame anchor strategy. Recommendation: TOP of panel content area + horizontal CENTER, with small inset (8-12px).
- Whether the reference image gets a tooltip on hover. Recommendation: no tooltip (static informational; tooltip clutters).
- Whether to wrap the image in `CreateSettingsListSectionHeaderInitializer` (like other sections) or leave bare. Recommendation: bare — header above image-only "section" is redundant.
- Exact notify-hook function name. Recommendation: `ns:NotifyWindowVisibilityChanged` — descriptive, matches existing `ns:OnAutoHideChanged` callback naming.
- Whether to extract `SettingsInbound.RepairDisplay` early-exit guard into a helper. Recommendation: no — 3-line body, inlining keeps call-site obvious.

## Deferred Ideas

(All captured in CONTEXT.md `<deferred>` section; mirrored here for audit trail.)
- POT-padded fallback TGA pre-prepared defensively — only generate if non-POT fails in-game
- Tooltip on the reference image — recommendation: no
- Animation/fade-in on image appearance — out of scope
- Responsive image sizing on different panel widths — out of scope
- Multiple language variants of cheat-sheet — out of scope
- Notify-hook on additional Window.lua sites (applySoftHideState etc.) — explicitly OOS per engineering-truth model (D-12)
- RepairDisplay debouncing — out of scope; 3 call sites + direct user actions don't need debouncing
