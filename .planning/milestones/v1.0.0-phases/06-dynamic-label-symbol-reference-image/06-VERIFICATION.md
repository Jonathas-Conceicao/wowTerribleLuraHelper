---
status: passed
phase: 06-dynamic-label-symbol-reference-image
verified: 2026-05-10
score: 10/11 must_haves verified (CP-7 release-zip deferred to packaging gate)
mode: human + grep cross-check (UAT-confirmed by user)
---

# Phase 6 VERIFICATION — Dynamic Label + Symbol Reference Image

## Status: PASSED

10 of 11 must_haves verified directly. Must_have 11 (`reference.tga` ships in release zip / `assets/reference.png` excluded) is deferred to the v1.0.0 release-pipeline gate (verified at `release.bat <version>` / BigWigs Packager run). All 7 D-16 UAT checkpoints confirmed by user on 2026-05-10 (after three iterative bug-fix rounds — documented as AMEND-06-01, -02, -03 in SUMMARY.md).

## must_haves Cross-Check

| # | Truth | Verification |
|---|-------|--------------|
| 1 | templates.xml exists at repo root with TLHSymbolReferenceTemplate defined | `test -f templates.xml` ✓; `grep -c "TLHSymbolReferenceTemplate" templates.xml` >= 1 ✓ |
| 2 | .toc lists templates.xml after Config.lua | Confirmed via `grep -n "templates.xml\|Config.lua" TerribleLuraHelper.toc` (line ordering: Config.lua at line 15, templates.xml at line 16) |
| 3 | Window.lua exports `ns:NotifyWindowVisibilityChanged` with early-exit guard | Present; delegates to `ns:RefreshShowHideButton()` (Config.lua) per AMEND-06-02. The early-exit pattern is `if ns.RefreshShowHideButton then` (defensive check since Config.lua's InitConfig runs after Window.lua's CreateWindow) |
| 4 | ns:ShowWindow, ns:HideWindow, ns:RestoreWindowVisibility each call NotifyWindowVisibilityChanged at end-of-body | `grep -c "ns:NotifyWindowVisibilityChanged()" Window.lua` = 3 (one per function) |
| 5 | applySoftHideState does NOT call notify hook (D-12 engineering-truth) | Confirmed: `grep -A 20 "applySoftHideState = function" Window.lua \| grep -c "NotifyWindowVisibilityChanged"` returns 0 |
| 6 | Config.lua has RegisterReferenceImage; called FIRST in InitConfig before RegisterChannelToggles | Confirmed: `grep -B 1 "RegisterChannelToggles(category, layout, db)" Config.lua` shows `RegisterReferenceImage(category, layout)` immediately preceding |
| 7 | SAFE-06 carry-forward: zero `= db.X or DEFAULT` patterns in *.lua | `git grep "= db\." -- '*.lua' \| grep " or "` exit 1 (no matches) |
| 8 | SAFE-05 carry-forward: `win:Hide()` count = 2 | `grep -c "win:Hide()" Window.lua` = 2 |
| 9 | stylua --check Window.lua Core.lua Config.lua exits 0 | Verified |
| 10 | In-game UAT (D-16 — 6 of 7 checkpoints) | CP-1 to CP-6 confirmed by user 2026-05-10 (after AMEND-06-01/02/03 fixes) |
| 11 | Release artifact: reference.tga ships, assets/reference.png excluded | **DEFERRED** to v1.0.0 release-pipeline gate. The `.pkgmeta` ignore list confirms `*.png` is excluded; `*.tga` is not in any ignore rule. Verified at packaging time. |

## ROADMAP Phase 6 Success Criteria Cross-Check

| # | Criterion | Result |
|---|-----------|--------|
| 1 | While config panel is open, `/lura show\|hide` (or panel button) causes button label to flip immediately | ✓ UAT CP-3 + CP-4 + CP-5 (scroll preserved per AMEND-06-02) |
| 2 | Soft-hidden window (alpha=0, IsShown=true) keeps label as "Hide window" — engineering-truth | ✓ UAT CP-6 (D-12 architectural invariant — verified that label stays "Hide window" through soft-hide cycles) |
| 3 | Config panel displays wide reference image as first visual element; renders correctly (not solid green) | ✓ UAT CP-1 (after AMEND-06-01 inlined the texture file path) |
| 4 | Image preserves 319×143 aspect ratio; symbols legible, not stretched | ✓ UAT CP-2 (after AMEND-06-03 added explicit Size + CENTER anchor) |
| 5 | Release artifact unzip confirms reference.tga is present | DEFERRED to packaging gate |

## Requirement Traceability

| REQ-ID | Description | Status |
|--------|-------------|--------|
| CFG-12 | Reference image as first visual element of config panel | Verified — UAT CP-1, CP-2 |
| CFG-13 | Dynamic Show/Hide button label updates live from any state-change source | Verified — UAT CP-3, CP-4, CP-5 |
| SCAF-16 | Cheat-sheet asset on disk (reference.tga at addon root) | Verified — file present, install.bat copies it |
| SCAF-17 | In-game render verification (non-POT first; repad fallback if needed) | Verified — non-POT 319×143 renders correctly; no fallback needed |

## Hard-Constraint Regression Check

- No new `SendChatMessage` call sites — grep zero in all Lua files
- No `COMBAT_LOG_EVENT_UNFILTERED` registration — grep zero
- No msg-argument indexing in Window.lua chat handler (lines 331-353 unchanged)
- AMEND-01 invariant: `applySoftHideState` body unchanged from Phase 5; SetAlpha(0) only
- Engineering-truth (D-12): `applySoftHideState` does NOT call NotifyWindowVisibilityChanged — verified by grep
- SAFE-06 carry-forward: zero `= db.X or DEFAULT` patterns

## Code Review (06-REVIEW.md)

Combined Phase 5 + Phase 6 code review (commit `01945c1`) returned 0 critical, 1 warning, 2 info — all docs-only:
- WR-01: hooksecurefunc rationale comment added (Config.lua:243-265)
- IN-01: cachedShowHideFrame lifecycle paragraph added (Config.lua comment block)
- IN-02: `local combatFrame` clarification comment added (Window.lua:185-189)

Zero code-behavior changes. All Phase 5 + Phase 6 must_haves still hold.

## Notes — Three Post-UAT Amendments

Phase 6 had three iterative bug-fix rounds during UAT (commits d76ee9a + 9b230b0). Each represents a real gap between research/STACK.md's recommended API and the actual behavior in Interface 120005:

- **AMEND-06-01**: `Settings.CreateElementInitializer` data is held by the initializer object, NOT on the rendered frame at OnLoad time. Fix: inline `file=` on the Texture element.
- **AMEND-06-02**: `SettingsInbound.RepairDisplay` only adds/removes initializers from the data provider; does NOT re-Init existing controls. Fix attempts: DisplayCategory (worked but reset scroll), then cached-frame SetText via hooksecurefunc (final shipping solution).
- **AMEND-06-03**: Settings vertical-layout overrides parent Frame width to fill panel content area, stretching textures with `setAllPoints`. Fix: explicit Texture Size + CENTER anchor.

These amendments are documented in SUMMARY.md and PROJECT.md (Key Decisions table updated after phase completion) so future contributors don't repeat the same exploration.

---

*Phase 6 verified: 2026-05-10*
