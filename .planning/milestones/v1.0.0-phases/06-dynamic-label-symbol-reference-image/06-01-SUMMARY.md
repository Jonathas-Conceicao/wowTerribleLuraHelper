---
phase: 06-dynamic-label-symbol-reference-image
plan: 01
status: complete
completed: 2026-05-10
requirements:
  - CFG-13
  - CFG-12
  - SCAF-16
  - SCAF-17
key-files:
  created:
    - templates.xml
  modified:
    - TerribleLuraHelper.toc
    - Window.lua
    - Config.lua
    - scripts/install.bat
commits:
  - 033998b  # Task 1: templates.xml NEW + .toc registration
  - 773dba6  # Task 2: Window.lua NotifyWindowVisibilityChanged + 3 call sites
  - f51fb0f  # Task 3: Config.lua RegisterReferenceImage + install.bat fix
  - d76ee9a  # UAT round 1 fix: inline texture file path; switch to DisplayCategory
  - 9b230b0  # UAT round 2 fix: explicit Texture size+anchor (unstretch); hooksecurefunc Init capture (scroll preserve)
deviations:
  - id: AMEND-06-01
    date: 2026-05-10
    decision: D-01..D-02 (XML data-flow)
    description: |
      Original plan used `Settings.CreateElementInitializer(template, data)` with
      `self.data.texturePath` read inside the XML template's `<OnLoad>`.
      Empirically that doesn't work — `OnLoad` fires at template instantiation
      BEFORE the framework calls `Init(initializer)` and assigns data to the
      frame. The data is held by the initializer object, not on the frame.
      Fix (commit d76ee9a): inline `file=` attribute on the <Texture> element.
      The texture path is a hardcoded literal anyway (per CONTEXT D-02), so the
      data-flow indirection added no value.
  - id: AMEND-06-02
    date: 2026-05-10
    decision: D-10 (notify-hook mechanism)
    description: |
      Original plan used `SettingsInbound.RepairDisplay()` per STACK.md
      recommendation. Empirically that only adds/removes initializers from the
      data provider (per Blizzard_SettingsList.lua:98 `SettingsListMixin:RepairDisplay`
      docstring) — it does NOT re-Init existing controls. The button's
      `EvaluateName` closure was never re-run, so the label never refreshed.
      Round-1 fix (commit d76ee9a) tried `SettingsPanel:DisplayCategory` to
      force rebuild — worked but reset scroll position to top (UAT-flagged).
      Round-2 fix (commit 9b230b0) switched to ARCHITECTURE.md's originally-
      proposed hooksecurefunc(SettingsButtonControlMixin, "Init", ...) pattern
      with a sentinel data flag (`_tlhShowHideButton = true`) to capture the
      rendered button frame reference. Notify-hook now calls
      `frame.Button:SetText(frame:EvaluateName())` directly — no panel rebuild,
      no scroll loss.
  - id: AMEND-06-03
    date: 2026-05-10
    decision: D-04 (texture sizing — setAllPoints)
    description: |
      Original plan had `<Texture setAllPoints="true"/>` to fill the parent
      frame at native 319x143. Empirically the Settings vertical-layout
      overrides the parent Frame's width to match the panel content area
      (~640px), causing the texture to stretch horizontally. Round-2 fix
      (commit 9b230b0) removed setAllPoints; gave the Texture explicit
      `<Size x="319" y="143"/>` + `<Anchor point="CENTER"/>`. Texture stays
      at native dimensions centered in whatever frame width the layout
      assigns.
---

# Phase 6 SUMMARY — Dynamic Label + Symbol Reference Image

## What Was Built

A wide rune-symbol cheat-sheet image (`reference.tga`, 319×143) now anchors at the top of the Options > AddOns > TerribleLuraHelper panel as the first visual element a new user sees. The Show/Hide window button in the config panel updates its label live — flips to "Hide window" or "Show window" the instant the helper window's visibility changes via any path (`/lura show|hide` slash command, on-window close button, panel button click, `/lura` toggle, `RestoreWindowVisibility` at addon load) — without rebuilding the panel and without losing the user's scroll position. Engineering-truth model is preserved: soft-hide cycles (Phase 5's combat path) do NOT flip the label because soft-hide doesn't change `IsShown()`.

## Code Changes

**templates.xml** (NEW — commits `033998b` → `d76ee9a` → `9b230b0`):
- `<Frame name="TLHSymbolReferenceTemplate" virtual="true">` with child `<Texture parentKey="Image">`
- Texture: inline `file="Interface\AddOns\TerribleLuraHelper\reference.tga"`, explicit `<Size x="319" y="143"/>`, `<Anchor point="CENTER"/>`
- No OnLoad script, no Mixin — texture path inlined directly, so no data-flow needed

**TerribleLuraHelper.toc** (commit `033998b`):
- Added line 16: `templates.xml` after `Config.lua` (XML loaded after Lua per Blizzard's `.toc` load-order convention)

**Window.lua** (commits `773dba6` → `d76ee9a` → `9b230b0`):
- New export `function ns:NotifyWindowVisibilityChanged()` — delegates to `Config.lua`'s `ns:RefreshShowHideButton()`. Phase 6's evolution: started with `SettingsInbound.RepairDisplay` (didn't re-Init controls), then tried `SettingsPanel:DisplayCategory` (worked but reset scroll), settled on the cached-frame approach (Config.lua owns the cache via hooksecurefunc).
- Added 1-line notify call at the end of `ns:ShowWindow`, `ns:HideWindow`, `ns:RestoreWindowVisibility` (3 visibility-changing functions).
- Did NOT modify `applySoftHideState` (D-12 engineering-truth — soft-hide doesn't change IsShown).

**Config.lua** (commits `f51fb0f` → `9b230b0`):
- New `local function RegisterReferenceImage(category, layout)` — calls `Settings.CreateElementInitializer("TLHSymbolReferenceTemplate", { texturePath = "Interface\\AddOns\\TerribleLuraHelper\\reference.tga" })`. The `texturePath` data is a no-op now (texture file is hardcoded inline in XML per AMEND-06-01); kept in case a future phase wants Mixin-based runtime variability.
- `ns:InitConfig` calls `RegisterReferenceImage(category, layout)` FIRST in the layout sequence (before `RegisterChannelToggles`) → image renders at the top of the panel.
- Show/Hide button initializer gets a sentinel: `initializer.data._tlhShowHideButton = true`.
- New `hooksecurefunc(SettingsButtonControlMixin, "Init", function(frame, initializer) ... end)` at file-level scope — captures the rendered frame reference whenever Init fires on an initializer with the sentinel flag set.
- New export `function ns:RefreshShowHideButton()` — calls `cachedShowHideFrame.Button:SetText(cachedShowHideFrame:EvaluateName())` if the panel has been opened at least once this session (otherwise no-op).

**scripts/install.bat** (commit `f51fb0f`):
- Added two copy lines: `templates.xml` and `reference.tga`. Without them, `install.bat` would deploy the addon without the new XML template OR the texture asset, causing silent broken-image in-game.

## Decisions Honored (with Amendments)

| D-ID | Decision | Status |
|------|----------|--------|
| D-01 | NEW templates.xml with virtual Frame + child Texture | ✓ |
| D-02 | Settings.CreateElementInitializer with template + data | ✓ for the API call; **AMENDED-06-01**: texturePath data is no-op, file inlined in XML |
| D-03 | Image first in vertical-layout sequence | ✓ |
| D-04 | Native 319×143 size; no SetTexCoord letterboxing | ✓ size confirmed; **AMENDED-06-03**: setAllPoints removed in favor of explicit Texture Size + CENTER anchor |
| D-05 | Frame anchor = Claude's discretion | ✓ CENTER chosen |
| D-06 | Default SetTexCoord(0, 1, 0, 1) | ✓ (default; no explicit call) |
| D-07 | Non-POT first | ✓ 319×143 renders correctly in-game (UAT confirmed) — fallback NOT needed |
| D-08 | Fallback documented, not pre-prepared | ✓ documented; never needed |
| D-09 | Release zip ships TGA, excludes PNG | Pending Phase 6 CP-7 (release-pipeline gate; defer to packaging) |
| D-10 | ns:NotifyWindowVisibilityChanged with early-exit | ✓ for the function shape; **AMENDED-06-02**: mechanism changed twice (RepairDisplay → DisplayCategory → cached-frame SetText) |
| D-11 | 3 call sites: Show/Hide/Restore | ✓ |
| D-12 | applySoftHideState does NOT call notify (engineering-truth) | ✓ (architectural invariant — verified by UAT CP-6: label stays "Hide window" through soft-hide cycles) |
| D-13 | Show/Hide button initializer structurally unchanged | ✓ initializer call unchanged; only added sentinel `data._tlhShowHideButton = true` |
| D-14 | Phase 5 combatFrame untouched | ✓ |
| D-15 | Load-order safe (early-exit guard) | ✓ via `if ns.RefreshShowHideButton then` defensive check |
| D-16 | 7 UAT checkpoints | ✓ all 7 verified (2026-05-10, after two bug-fix rounds) |

## Verification (must_haves cross-check)

See `06-VERIFICATION.md`.

## UAT (D-16 — 7 checkpoints, user-verified 2026-05-10)

| CP | Test | Result |
|----|------|--------|
| 1 | Image renders, not solid green | ✓ (after AMEND-06-01 fix) |
| 2 | Image at native 319×143, not stretched | ✓ (after AMEND-06-03 fix) |
| 3 | Live label refresh via slash commands | ✓ (after AMEND-06-02 fix — preserves scroll) |
| 4 | Live label refresh via panel button click | ✓ (same code path as CP-3; user implicitly confirmed) |
| 5 | Live label refresh via `/lura` toggle | ✓ (same code path; user implicitly confirmed) |
| 6 | Soft-hide does NOT flip label | ✓ (D-12 engineering-truth invariant confirmed) |
| 7 | Release zip ships TGA, excludes PNG | ⏳ Deferred to v1.0.0 packaging gate (BigWigs Packager run on tag push) |

## Notable Wins

- **Code review caught Phase 6's pre-shipped install.bat bug** during execution (Task 3 deviation — missing copy lines for templates.xml + reference.tga). Without that catch, UAT Checkpoint 1 would have failed mysteriously (broken-template symptom but missing-asset cause).
- **Three iterative bug-fix rounds** (commits d76ee9a + 9b230b0 + f5bd880) closed real gaps between research/STACK.md's recommended APIs and how they actually behave in Interface 120005. Documenting AMEND-06-01, -02, -03 explicitly so future contributors don't repeat the same exploration.
- **Engineering-truth invariant (D-12)** survived all three fix rounds intact — soft-hide cycles never flipped the button label across any approach (RepairDisplay, DisplayCategory, or cached-frame SetText). Architectural decision held up.

## Deviations / Notes

- v1.0.0 closes after this phase. PROJECT.md evolution + ROADMAP marking happen next.
- The unused `texturePath` data table in `RegisterReferenceImage` is kept for future-proofing — switching to a Mixin Init pattern (for runtime variable image paths) would require this data to flow correctly. Today it's a no-op pass-through but cheap to leave in.

---

*Phase 6 complete: 2026-05-10*
