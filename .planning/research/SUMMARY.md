# Project Research Summary

**Project:** TerribleLuraHelper v1.0.0 — Polish & Defaults
**Domain:** WoW Midnight (Interface 120005) raid-coordination HUD addon
**Researched:** 2026-05-09
**Confidence:** HIGH (all API claims verified against wow-ui-source@12.0.1.66337)

---

## Executive Summary

TerribleLuraHelper v1.0.0 is a polish milestone on top of the fully-shipped v0.1.0 foundation. All five features are additive changes to the existing four-file addon (Core.lua, Macros.lua, Window.lua, Config.lua) with no new files strictly required except an optional XML template for the cheat-sheet image widget and the image asset itself. The research confirms that every feature is implementable with Blizzard built-in APIs and zero new library dependencies. The biggest risk is not technical complexity (four of five features are LOW or LOW-MODERATE complexity) but two asset/packaging hard gates: the cheat-sheet texture must be delivered in TGA format (not PNG, because `.pkgmeta` ignores `*.png`) and the image asset must be present before the milestone closes.

The one feature requiring meaningful design care is Feature 3 (dynamic Show/Hide button label). Three researchers each surfaced a different mechanism — see the Reconciliation section for the definitive pick. The remaining four features have clear, one-way implementations verified against source. The build order from ARCHITECTURE.md is Feature 4 then 1 then 5 then 3 then 2, and it must be followed to avoid rework: Features 4 and 1 are standalone, Feature 5 adds the combat-state infrastructure that Feature 3 notify-hook call sites in Window.lua will reference, and Feature 2 has an external asset dependency that may block it until last.

The hard constraint from v0.1.0 that auto-hide logic must use soft-hide (`SetAlpha(0)`) rather than hard-hide (`win:Hide()`) remains load-bearing in v1.0.0. Hard-hiding the window during combat unregisters CHAT_MSG_* listeners (AMEND-01 invariant) and causes the window to miss the exact macro presses it was built to display. Every new code path that touches window visibility must use the alpha path, never `Hide()`.

---

## Reconciliation: Dynamic Show/Hide Button Label (Feature 3)

Three researchers surfaced three different mechanisms. **The winning approach is STACK.md's `SettingsInbound.RepairDisplay()` pattern**, combined with the single-subscriber notification slot from ARCHITECTURE.md for call-site discipline.

### Chosen approach

Window.lua exposes `ns.onWindowVisibilityChanged = nil` (single-subscriber slot). Every visibility-changing code path calls a module-local `notifyVisibilityChanged()` that invokes the subscriber if present. Config.lua assigns the subscriber:

```lua
ns.onWindowVisibilityChanged = function()
    if SettingsPanel and SettingsPanel:IsShown() then
        SettingsInbound.RepairDisplay()
    end
end
```

`SettingsInbound.RepairDisplay()` is a public function verified at `Blizzard_SettingsInbound.lua:156-158`. It re-initializes all controls in the currently displayed category, re-calling `SettingsButtonControlMixin:Init`, which re-calls `EvaluateName`, which calls the `buttonText` function. The label is re-evaluated from the authoritative source with no stale widget-reference risk. The `SettingsPanel:IsShown()` guard makes the call a no-op when the panel is not open.

**Why FEATURES.md's gameDataFunc/gameDataEvent approach was rejected:**

`gameDataFunc`/`gameDataEvent` wires via `EventRegistry:RegisterFrameEventAndCallbackWithHandle`. This adds indirection (custom event name, EventRegistry dispatch) for no benefit over a direct `RepairDisplay()` call, and introduces a subscription lifecycle concern: PITFALLS.md DL-1 identifies that subscriptions registered in `Init` without unsubscription in `Release` accumulate stale closures on panel re-open. `RepairDisplay()` sidesteps this entirely — nothing to subscribe, nothing to unsubscribe.

**Why ARCHITECTURE.md's hooksecurefunc + sentinel approach was rejected:**

`hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` with a sentinel marker hooks a Blizzard internal mixin. If Blizzard renames or restructures `SettingsButtonControlMixin` in a future patch, the hook silently stops firing. `RepairDisplay()` is a documented public function that is more stable against Blizzard internal refactoring. The sentinel-matching logic is also fragile against pool-recycle edge cases where the frame data table is reused.

**What to retain from ARCHITECTURE.md:** The `ns.onWindowVisibilityChanged` single-subscriber slot pattern and the enumerated call-site discipline (`ns:ShowWindow`, `ns:HideWindow`, `ns:RestoreWindowVisibility`, combatFrame `PLAYER_REGEN_ENABLED` handler) are used verbatim. The subscriber calls `RepairDisplay()` rather than `SetText` directly.

**Contingency (if RepairDisplay causes visible panel flicker in-game):** Fall back to direct button-reference via `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` with a `data.tlhIsShowHideBtn = true` sentinel, store `self.Button` in a module-local, and call `SetText(evaluateLabel())` from the subscriber. This avoids RepairDisplay's full-panel reinit at the cost of the hooksecurefunc coupling.

---

## Reconciliation: Texture Format

All researchers converge: **use TGA**.

- STACK.md: TGA recommended; notes `.pkgmeta` ignores `*.png`
- PITFALLS.md TX-1: confirms `*.png` is in the current `.pkgmeta` ignore list — PNG is silently absent from release ZIPs
- ARCHITECTURE.md and FEATURES.md: format-agnostic

**Decision:** Deliver the cheat-sheet asset as `.tga`. No `.pkgmeta` change required. If the artist delivers PNG, convert to TGA before committing.

`SetTexture` path: string form without extension — `"Interface\\AddOns\\TerribleLuraHelper\\Textures\\CheatSheet"`. Power-of-two dimensions required (e.g., 512x128); non-power-of-two renders as solid green with no error message.

---

## Key Findings

### Recommended Stack

Zero new dependencies. All five features use Blizzard built-in APIs on Interface 120005.

**Core APIs by feature:**

- **CLICK-THRU:** `Frame:EnableMouse(bool)` — disables both click and motion events. Must be called on the parent `win` AND explicitly on each child slot frame (`EnableMouse` does not cascade to children).
- **TEXTURE:** `Texture:SetTexture(path)` + `Settings.CreateElementInitializer("TemplateName", data)` + new XML frame template. TGA format, power-of-two dimensions required.
- **DYNLABEL:** `SettingsInbound.RepairDisplay()` guarded by `SettingsPanel:IsShown()`. Called from `ns.onWindowVisibilityChanged` subscriber set in Config.lua.
- **DEFAULTS:** Existing nil-check backfill pattern in Core.lua. Change fresh-DB defaults block; update `RegisterAddOnSetting` `defaultValue` arguments in Config.lua.
- **COMBAT-HIDE:** `PLAYER_REGEN_ENABLED` / `PLAYER_REGEN_DISABLED` on a new `combatFrame` in Window.lua. One-line addition (`and InCombatLockdown()`) to `applySoftHideState`. Seed `inCombat = false` at init.

Interface version confirmed: wow-ui-source 12.0.1.66337; `.toc` `Interface: 120005` is correct; no version bump needed.

### Expected Features

**Must have (table stakes for v1.0.0):**

- **Click-through when locked** — every locked HUD addon disables mouse. The v0.1.0 gap in `applyLockState` (no `EnableMouse` call) is a confirmed defect.
- **Dynamic Show/Hide button label** — a button reflecting mutable state must show current state. v0.1.0 `EvaluateName`-only refresh is a known gap per PROJECT.md.
- **SAY-centric defaults** — wrong defaults cause "addon doesn't work" reports. Existing users must not be affected (nil-check backfill only touches nil keys).
- **Auto-hide combat reframe** — always-hide creates a foot-gun where users think the addon is off. Combat-scoped reframe makes the toggle self-evident out of combat.

**Should have (differentiator for v1.0.0):**

- **Cheat-sheet image in config panel** — first-time users see rune-to-symbol reference immediately. Blocked by asset delivery; hard gate per PROJECT.md.

**Explicitly out of scope — do not re-recommend:**

These were declined during v0.1.0 or v1.0.0 scoping. Any agent recommendation to add these must be flagged and discarded:

- Partial click-through (lock button stays clickable while locked)
- Separate click-through toggle decoupled from lock state
- Placeholder cheat-sheet image
- Combat-aware scale/alpha beyond the auto-hide reframe
- Clobbering existing user channel choices on upgrade
- Configurable inactivity timeout, sequence persistence across reload, `/lura clear` command (all deferred during v0.1.0)

### Architecture Approach

The four-file flat architecture (Core.lua, Macros.lua, Window.lua, Config.lua) is unchanged. All five features integrate at clearly-identified extension points. The only new file is the optional XML template for Feature 2. Config.lua only calls `ns:*` exports and never writes DB directly.

**Feature integration points:**

| Feature | Files touched | Extension point |
|---------|--------------|-----------------|
| 4 — SAY defaults | Core.lua, Config.lua | Fresh-DB block + backfill loop + `defaultValue` args |
| 1 — Click-through | Window.lua | `applyLockState()` + child-frame loop + `InCombatLockdown` guard |
| 5 — Combat-hide | Window.lua, Config.lua | `applySoftHideState()` + new `combatFrame` + label/tooltip strings |
| 3 — Dynamic label | Window.lua, Config.lua | `ns.onWindowVisibilityChanged` slot + call sites + subscriber |
| 2 — Texture | Config.lua, XML, textures/ | `RegisterSymbolReference(layout)` first in layout registration |

**Key architectural patterns:**

- `applyLockState` as single applier: one change covers all four callers.
- `ns.onWindowVisibilityChanged` single-subscriber slot: no event system overhead; Config.lua is the only consumer.
- Dedicated `combatFrame` for `PLAYER_REGEN_*` listening: self-contained in Window.lua; does not pollute Core.lua's lifecycle frame or Macros.lua's one-shot regenFrame.

### Critical Pitfalls

1. **CT-1: EnableMouse does not cascade to child frames.** Call `EnableMouse(false/true)` on `win` AND loop over `slotFrames[1..5]` in `applyLockState`. Blizzard's DamageMeter (`DamageMeterSessionWindow.lua:830-836`) does this explicitly.

2. **CT-3: EnableMouse may fire a protected-function error during combat.** `EnableMouse` is `IsProtectedFunction = true`. Guard `applyLockState` with `if InCombatLockdown() then return end`; re-arm on `PLAYER_REGEN_ENABLED` (Macros.lua ArmRegenRetry pattern is directly reusable).

3. **TX-1: `.pkgmeta` excludes `*.png` — cheat-sheet silently absent from release ZIPs.** Use TGA. Verify by unzipping a test release artifact before milestone close.

4. **AH-2: Auto-hide MUST use soft-hide (`SetAlpha(0)`), never `win:Hide()`.** Hard-hiding unregisters `CHAT_MSG_*` events (AMEND-01). If hard-hidden in combat, the next `TLH_*` macro press is silently missed.

5. **DB-1: `db.X = db.X or DEFAULT` clobbers explicit `false` values.** `false or DEFAULT` evaluates to `DEFAULT` in Lua. Always use: `if db.X == nil then db.X = DEFAULT end`.

6. **DL-3: Missing visibility-change call sites make button label drift.** Wire notify to ALL paths: `ns:ShowWindow()`, `ns:HideWindow()`, `ns:RestoreWindowVisibility()`, and the combatFrame `PLAYER_REGEN_ENABLED` handler (which restores alpha after combat-exit soft-hide).

---

## Open UX Decisions Requiring User Confirmation

Three decisions embed user-visible behavior choices that need explicit confirmation before Feature 3 and Feature 5 implementation finalizes:

1. **Soft-hidden window label (LO-05 wart):** When `autoHide=on` and the window is at alpha=0, `win:IsShown()` returns `true`. The button says "Hide window" even though the window is invisible. Research recommendation: accept this. "Hide window" is correct because `/lura hide` stops processing and the frame IS technically shown. Do not change `IsWindowShown` semantics mid-milestone; document as v1.1 backlog.

2. **Corpse-run behavior:** `PLAYER_REGEN_ENABLED` fires when the player is dead and combat ends. The window will become visible (if `autoHide=on`, sequence empty) during a corpse run. Research recommendation: correct UX — the fight is over. Confirm with user.

3. **Auto-hide ON + out of combat + between M+ pulls:** Window stays visible between every trash pull (`autoHide=on`, out of combat). Research recommendation: intentional per PROJECT.md. Tooltip must clearly explain in-combat-only semantics.

---

## Implications for Roadmap

### Phase 1: SAY Defaults + Click-Through

**Rationale:** Both features are standalone with no cross-feature dependencies. Validates the QA loop (install.bat + in-game test) before more complex features.

**Delivers:** Correct first-run experience (SAY-only defaults); fully inert locked window (click-through).

**Implements:** Feature 4 (Core.lua defaults + backfill + Config.lua `defaultValue` args) + Feature 1 (`applyLockState` + child-frame loop + `InCombatLockdown` guard + `PLAYER_REGEN_ENABLED` retry).

**Avoids:** DB-1, DB-2, CT-1, CT-3.

**Research flag:** Standard patterns. No `/gsd-research-phase` needed.

### Phase 2: Auto-Hide Combat Reframe

**Rationale:** Must precede Feature 3 so the `combatFrame` handler exists when the notify call site is added in a single pass.

**Delivers:** Auto-hide toggle that is self-evident out of combat; correct login behavior; M+ flicker documented as expected.

**Implements:** Feature 5 — new `combatFrame` in Window.lua, `InCombatLockdown()` guard in `applySoftHideState`, Config.lua label/tooltip strings.

**Avoids:** AH-1 (REGEN_ENABLED at login), AH-2 (hard-hide breaks AMEND-01), AH-4 (drag mid-combat soft-hide).

**Research flag:** Standard patterns. No `/gsd-research-phase` needed.

### Phase 3: Dynamic Show/Hide Button Label

**Rationale:** Depends on Phase 2 being done first (combatFrame call sites exist). Most architecturally complex feature; implement after simpler features are verified.

**Delivers:** Config-panel button that accurately reflects window state at all times while the panel is open.

**Implements:** Feature 3 — `ns.onWindowVisibilityChanged` slot in Window.lua; call sites at all four visibility-changing functions; Config.lua subscriber using `SettingsInbound.RepairDisplay()` guarded by `SettingsPanel:IsShown()`.

**Avoids:** DL-1 (notify hook lifecycle leak), DL-2 (taint from chat-event call chain), DL-3 (missing call sites).

**Research flag:** `SettingsInbound.RepairDisplay()` is verified public but not previously used in this addon. In-game QA must confirm: label updates correctly, no panel flicker, no cross-category side effects. Contingency (direct `SetText` via `hooksecurefunc` sentinel) documented in the Reconciliation section above.

### Phase 4: Symbol Reference Image

**Rationale:** Completely independent; listed last because the TGA asset is an external hard dependency. If the asset is not ready, this phase is skipped — no placeholder ship per PROJECT.md.

**Delivers:** Cheat-sheet image at top of config panel for new users.

**Implements:** Feature 2 — `RegisterSymbolReference(layout)` first in layout registration; XML frame template `TLHSymbolReferenceTemplate`; `Textures/CheatSheet.tga`; `.toc` updated to load XML before Config.lua.

**Avoids:** TX-1 (TGA ships automatically, no `.pkgmeta` change), TX-2 (string path only, no FileDataID), TX-3 (`SetTexture` in XML `OnLoad`, not deferred to `Init` callback).

**Hard gate:** Unzip a test release artifact to confirm `Textures/CheatSheet.tga` is present. `install.bat` bypasses BigWigs Packager and is insufficient verification.

**Research flag:** No `/gsd-research-phase` needed. In-game QA must confirm power-of-two dimensions render correctly.

### Phase Ordering Rationale

- Features 4 and 1 first: standalone, no cross-feature dependencies, validate QA loop early.
- Feature 5 before Feature 3: Feature 5 creates the `combatFrame` handler that Feature 3 must add a notify call inside — single pass, no rework.
- Feature 2 last: external asset dependency may block independently; isolating it last prevents blocking the other four features.
- No phase requires `/gsd-research-phase`: all APIs verified against wow-ui-source@12.0.1; Phase 3 has a documented contingency.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs verified against wow-ui-source@12.0.1.66337 and confirmed against Blizzard's own addon patterns in the same source tree |
| Features | HIGH | Verified against shipped v0.1.0 codebase; gaps confirmed from source, not inferred |
| Architecture | HIGH | Integration points from direct source reading of shipped files; build order verified against dependency map |
| Pitfalls | HIGH | All critical pitfalls verified against source (EnableMouse cascade: DamageMeterSessionWindow.lua; pkgmeta: .pkgmeta reviewed 2026-05-09; AMEND-01: 02-VERIFICATION.md) |

**Overall confidence: HIGH**

### Gaps to Address During Implementation

- **CT-3 (EnableMouse during combat lockdown):** STACK.md asserts non-secure frames are likely exempt; PITFALLS.md says guard anyway. Resolution: implement `InCombatLockdown` guard in Phase 1. Macros.lua `ArmRegenRetry` pattern is directly reusable.
- **Phase 3 RepairDisplay in-game behavior:** Public API verified; panel behavior (flicker, cross-category effects) not yet smoke-tested. Resolution: Phase 3 QA gate; contingency (direct `SetText` via `hooksecurefunc`) documented.
- **TGA asset:** Not yet delivered. Resolution: external dependency; Feature 2 cannot close without it.
- **UX decisions #1-3:** Need user confirmation before Feature 3 and Feature 5 finalize behavior. Recommendations documented above.

---

## Sources

### Primary (HIGH confidence — verified against wow-ui-source@12.0.1.66337)

- `Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua` — `EnableMouse`, `SetMouseClickEnabled`, `SetMovable`, `RegisterForDrag` signatures and restriction annotations
- `Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua` — `SetTexture`, `SetTexCoord`; `AllowedWhenTainted` annotation
- `Blizzard_Settings_Shared/Blizzard_SettingControls.lua:700-720, 762-774` — `EvaluateName` (called once at Init), `CreateSettingsButtonInitializer` signature, `gameDataFunc` pattern
- `Blizzard_Settings_Shared/Blizzard_SettingsInbound.lua:156-158` — `SettingsInbound.RepairDisplay()` public function
- `Blizzard_Settings_Shared/Blizzard_Settings.lua:341` — `Settings.CreateElementInitializer` public wrapper
- `Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua` — vertical layout pattern and element initializer guidance
- `Blizzard_DamageMeter/DamageMeterSessionWindow.lua:821-836` — `EnableMouse` is per-frame (not inherited); canonical child-frame iteration pattern
- `TerribleLuraHelper/Window.lua` (v0.1.0 shipped) — `applyLockState`, `applySoftHideState`, AMEND-01 invariant confirmed
- `TerribleLuraHelper/Core.lua` (v0.1.0 shipped) — nil-check backfill pattern confirmed correct
- `TerribleLuraHelper/Config.lua` (v0.1.0 shipped) — button initializer, EvaluateName-only refresh gap confirmed
- `TerribleLuraHelper/.pkgmeta` — `*.png` in ignore list confirmed present (reviewed 2026-05-09)
- `.planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-VERIFICATION.md` — AMEND-01 documented
- `.planning/research/SETTINGS_API.md` — verified Settings API patterns

### Secondary (MEDIUM confidence)

- [warcraft.wiki.gg/Category:API_functions/restricted](https://warcraft.wiki.gg/wiki/Category:API_functions/restricted) — `EnableMouse` not listed as restricted; wiki may lag client
- [warcraft.wiki.gg/API_TextureBase_SetTexture](https://warcraft.wiki.gg/wiki/API_TextureBase_SetTexture) — TGA/PNG/BLP supported; power-of-two required
- [BigWigs Packager wiki](https://github.com/BigWigsMods/packager/wiki/Preparing-the-PackageMeta-File) — opt-out model; `*.png` exclude confirmed

### Tertiary (LOW confidence — needs in-game validation)

- `SettingsInbound.RepairDisplay()` panel behavior when called on an already-open panel — public API confirmed; in-game flicker and cross-category effects not yet smoke-tested

---
*Research completed: 2026-05-09*
*Ready for roadmap: yes*
