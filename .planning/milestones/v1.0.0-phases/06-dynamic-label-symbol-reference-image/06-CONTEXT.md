# Phase 6: Dynamic Label + Symbol Reference Image - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

The Show/Hide window button label in the config panel updates live from any state-change source (slash commands, on-window close, panel button click, `/tlh` alias) while the panel is open — replaces the existing `EvaluateName`-init-only behavior. A wide rune-symbol cheat-sheet image (`reference.tga`, 319×143, on disk) anchors at the top of the config panel, above the "Chat channels" section header, as the first visual element a user sees when opening Options > AddOns > TerribleLuraHelper.

This phase covers 4 requirements:
- **CFG-13** — Dynamic Show/Hide button label refresh via Window.lua notify hook → `SettingsInbound.RepairDisplay()` round-trip
- **CFG-12** — Reference image as first element of config panel
- **SCAF-16** — TGA asset on disk (already complete from milestone questioning — `reference.tga` at addon root, 319×143 RGBA)
- **SCAF-17** — In-game render verification (non-POT first; repad to POT only if rendering breaks)

What this phase explicitly does NOT touch:
- Click-through / `EnableMouse` (Phase 4 — shipped)
- Auto-hide-in-combat / `combatFrame` / `applySoftHideState` (Phase 5 — code committed, UAT pending but invariants stable)
- Macro code (Macros.lua untouched)
- Chat-pipeline / `msg`-handling (permanent OOS — taint constraints)

</domain>

<decisions>
## Implementation Decisions

### Image-frame architecture (CFG-12, SCAF-16)
- **D-01:** XML template file. Add a new `templates.xml` (or similarly-named, per planner choice) at the repo root containing `<Frame name="TLHSymbolReferenceTemplate" virtual="true">` with a child `<Texture>` layer (parent layer "ARTWORK" or similar; no border). Register in `.toc` AFTER the Lua files (load order: Core.lua, Macros.lua, Window.lua, Config.lua, then templates.xml — XML loaded after Lua so the template is available for Settings.CreateElementInitializer calls in Config.lua's runtime path).
- **D-02:** Use `Settings.CreateElementInitializer("TLHSymbolReferenceTemplate", { texturePath = "Interface\\AddOns\\TerribleLuraHelper\\reference.tga" })`. Init callback (defined either as a Mixin in XML or as the initializer's data-handler in Lua) calls `texture:SetTexture(self.data.texturePath)` once when the initializer fires. Per PITFALLS.md TX-3, texture frame creation should NOT happen inside Init's per-panel-open callback for large/uncached textures; the XML template's frame is created once at load, the Init callback only assigns the texture path — which is acceptable because the texture file is small (182KB) and Blizzard caches it on first load.
- **D-03:** Image placement = first in vertical-layout `AddInitializer` sequence — BEFORE the "Chat channels" `CreateSettingsListSectionHeaderInitializer` call. Insertion order = display order. No section header above the image; the image stands alone as the visual anchor for the panel.

### Image sizing (CFG-12)
- **D-04:** Native size — frame dimensions exactly 319×143. No stretching, no upscaling. Rationale: preserves texture crispness; the image was designed at this resolution; smaller visual footprint leaves more panel space for actual controls.
- **D-05:** Frame anchor = **Claude's Discretion**. Recommendation: anchor the frame's TOP point to the panel's content-area TOP with a small inset (e.g., 8-12px), and CENTER horizontally. The exact anchor strategy is a small UI choice the planner picks during XML template design.
- **D-06:** No `SetTexCoord` letterboxing at the native-size code path. `SetTexCoord(0, 1, 0, 1)` (default) shows the full texture. The 319×143 frame matches the 319×143 texture exactly — no aspect distortion possible.

### Non-POT verification + fallback (SCAF-17)
- **D-07:** Try non-POT (319×143) FIRST per the user's earlier choice during milestone questioning. Phase 6 ships with native-size loading.
- **D-08:** If in-game UAT reveals the solid-green silent-failure mode (per PITFALLS.md TX-3 — non-POT can render as solid green on some video paths despite warcraft.wiki.gg's claims about modern WoW POT-tolerance), fall back: repad the TGA externally to 512×256 (next POT up), use `SetTexCoord(0, 319/512, 0, 143/256)` for letterboxing in the Init callback. Frame dimensions stay 319×143; only the texture-coordinate clip changes. Treat this fallback as a v1.0.0 patch (a 1-2 line code edit + asset-replacement) rather than blocking Phase 6 close.
- **D-09:** Verify-by-build: after `./scripts/install.bat` runs, unzip a freshly-built release artifact (or run BigWigs Packager locally) and confirm `reference.tga` is present in the zip — TGA is NOT in `.pkgmeta`'s ignore list, ships automatically. PNG (`assets/reference.png` source) is excluded.

### Notify-hook architecture (CFG-13)
- **D-10:** Export `ns:NotifyWindowVisibilityChanged()` from Window.lua. Body:
  ```lua
  function ns:NotifyWindowVisibilityChanged()
      if SettingsPanel and SettingsPanel:IsShown() then
          SettingsInbound.RepairDisplay()
      end
  end
  ```
  The early-exit guard (`SettingsPanel:IsShown()`) ensures zero work when the panel isn't open — the notify hook is a no-op for the 99.9% case where the user is in combat or otherwise not looking at the config panel.
- **D-11:** Call sites — every place in `Window.lua` that changes `win:IsShown()`:
  1. `ns:ShowWindow()` (line ~371) — call notify after `win:Show()` and the alpha set
  2. `ns:HideWindow()` (line ~383) — call notify after `win:Hide()`
  3. `ns:RestoreWindowVisibility()` (line ~391) — call notify after `applySoftHideState()` (RestoreWindowVisibility is a special-case Show that respects soft-hide)
- **D-12:** Do NOT call notify from `applySoftHideState()` (Phase 5's combat-state path). Soft-hide changes `alpha`, NOT `IsShown()`. The label uses `ns:IsWindowShown()` → `win:IsShown()` which returns true regardless of soft-hide. Per the v1.0.0 engineering-truth model: soft-hidden = "visible" → button reads "Hide window" — correct without any label refresh on soft-hide transitions. Adding notify to applySoftHideState would re-run RepairDisplay needlessly on every combat-state transition with no UX benefit.
- **D-13:** Show/Hide button initializer at `Config.lua:188-216` stays structurally unchanged (uses `CreateSettingsButtonInitializer` with `buttonText` closure). The closure already calls `ns:IsWindowShown()` correctly — Phase 6's contribution is making the framework re-evaluate the closure on demand via `RepairDisplay()`, not changing what the closure does.

### Cross-feature interactions
- **D-14:** Phase 5's `combatFrame` (committed in `86a4218`) does NOT need notification calls added. Soft-hide state transitions in Phase 5 don't trigger label updates per D-12. Phase 5 and Phase 6 are independent at the implementation level despite sharing the auto-hide subject domain.
- **D-15:** Order-independence at addon load: Core.lua's ADDON_LOADED handler calls `ns:InitWindow()` then `ns:InitConfig()` then `ns:RestoreWindowVisibility()`. The notify hook is defined in Window.lua at module load (top-level function definition) — available before InitConfig runs. RestoreWindowVisibility's notify call fires correctly because the panel isn't open at addon-load time, so the early-exit guard short-circuits.

### Verification approach (UAT)
- **D-16:** Phase 6 UAT checkpoints — planner finalizes; recommended:
  1. **Image renders** — Open `/lura config`, confirm reference image displays at the top of the panel, above "Chat channels" section header. Image is NOT solid green (validates SCAF-17 non-POT viability).
  2. **Image dimensions** — Image displays at 319×143 native size; aspect ratio preserved; no distortion.
  3. **Live label refresh — slash command** — Open `/lura config`, panel visible. From in-game (different WoW window or via Esc-to-game), type `/lura show` (window visible → button reads "Hide window"). Type `/lura hide` (window hidden → button reads "Show window"). Each label flip happens immediately, without closing+reopening the panel.
  4. **Live label refresh — panel button** — Click the Show/Hide window button itself in the panel. Label flips immediately to reflect the new state (the button's own click is a state-change source).
  5. **Live label refresh — `/lura` toggle** — `/lura` (no arg) while panel open → label flips to match new state.
  6. **Soft-hide does NOT flip label** — engage combat with autoHide=on and empty sequence (Phase 5 soft-hide path). Window soft-hides (alpha=0). Confirm: button label STAYS as "Hide window" (engineering-truth model — `IsShown()` is still true through soft-hide). When combat ends and window restores, label still says "Hide window". Validates D-12.
  7. **Release-zip ships TGA** — After `./scripts/release.bat <test-version>` (or a local BigWigs Packager run), unzip the release artifact, confirm `reference.tga` is present at the addon root inside the zip. Confirm `assets/reference.png` is NOT in the zip (excluded by `*.png` ignore rule).

### Claude's Discretion
- Exact XML template structure (Frame + Texture + optional Mixin OnLoad). Recommendation: keep it minimal — one Frame, one Texture child layered "ARTWORK", no backdrop or border.
- Frame anchor strategy (recommend: TOP of panel content area + horizontal CENTER).
- Whether the reference image gets a tooltip on hover. Recommendation: no tooltip (static informational image; tooltip would feel cluttered).
- Whether to wrap the image in a `CreateSettingsListSectionHeaderInitializer` (like the other sections) or leave it bare. Recommendation: bare — adding a header above an image-only "section" is redundant.
- Exact notify-hook function name (`NotifyWindowVisibilityChanged` vs `OnVisibilityChanged` vs `RefreshConfigPanel`). Recommendation: `NotifyWindowVisibilityChanged` — descriptive, matches the existing `ns:OnAutoHideChanged` callback naming style (verb-prefix indicating a notification, not a query).
- Whether to extract the SettingsInbound.RepairDisplay early-exit guard into a helper. Recommendation: no — the body is 3 lines, inlining keeps the call-site obvious.

</decisions>

<specifics>
## Specific Ideas

- The user's preferred style is **simple/native/no-special-cases**. Native-size image is consistent with this — no upscaling, no stretching, image renders exactly as designed. Phase 6 should resist over-engineering (no animation, no fade-in, no responsive resizing).
- The reference image is the **user-discovery** centerpiece for new users — it's what makes a fresh install make sense to a new spotter at a glance. Treat the image's correct rendering (Checkpoint 1) as the highest-value UAT item.
- The dynamic label is small UX polish but **noticeable** — every state change in the addon while the panel is open will reflect the live state. Without it, the panel feels stale; with it, the panel feels like a real control surface.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.0.0 milestone scope
- `.planning/PROJECT.md` — Current Milestone section + Key Decisions table (especially v1.0.0 entries on cheat-sheet image and engineering-truth label model)
- `.planning/REQUIREMENTS.md` §"v1.0.0 Requirements (active — Polish & Defaults)" — full text of CFG-12, CFG-13, SCAF-16, SCAF-17
- `.planning/ROADMAP.md` §"Phase 6: Dynamic Label + Symbol Reference Image" — goal + 5 success criteria

### Research outputs (all v1.0.0)
- `.planning/research/SUMMARY.md` §"Reconciliation — Feature 3 dynamic label" — STACK.md's `SettingsInbound.RepairDisplay()` recommendation wins over FEATURES' EventRegistry approach and ARCHITECTURE's `hooksecurefunc` approach. Rationale: simplicity + robustness against future Blizzard internal changes.
- `.planning/research/STACK.md` §"DYNAMIC LABEL" — `SettingsInbound.RepairDisplay()` API verification (location: `Blizzard_SettingsInbound.lua:156`); panel re-init triggered correctly when called while `SettingsPanel:IsShown()` is true.
- `.planning/research/STACK.md` §"TEXTURE" — TGA format choice rationale, `SetTexture` path-string usage (NOT FileDataID for addon-shipped files), `.pkgmeta` `*.png` ignore rule, `Settings.CreateElementInitializer` template-name argument.
- `.planning/research/PITFALLS.md` TX-1, TX-2, TX-3 — texture pipeline pitfalls (PNG packaging exclusion already addressed; FileDataID-vs-path; async load flicker on first panel-open). DL-1, DL-2, DL-3 — dynamic-label pitfalls (subscribe/unsubscribe lifecycle, taint risks of calling notify from chat handlers, missing call sites).
- `.planning/research/ARCHITECTURE.md` §"Feature 3" + §"Feature 2" — integration map, build-order rationale (Phase 6 depends on Phase 5's combatFrame existing — already committed; Phase 6 adds notify hook + image element).

### Existing code patterns
- `Config.lua` lines 188-216 — current Show/Hide button initializer using `CreateSettingsButtonInitializer` + `buttonText` closure. Phase 6 keeps this initializer unchanged structurally; only the framework's re-init triggering changes (via `RepairDisplay`).
- `Window.lua` lines 371, 383, 391 — three exported visibility-changing functions (`ns:ShowWindow`, `ns:HideWindow`, `ns:RestoreWindowVisibility`). Phase 6 adds a notify call to each of these (3 small additions).
- `Window.lua` `applySoftHideState` (line ~229) — explicitly NOT a notify call site per D-12.
- `Config.lua` `RegisterChannelToggles` / `RegisterWindowControls` / `RegisterMacroSection` / etc. — the existing layout-registration pattern. Phase 6 adds `layout:AddInitializer(reference_image_initializer)` BEFORE the "Chat channels" section header registration in the appropriate parent-of-`InitConfig` site.

### Hard constraints (carry-over)
- `CLAUDE.md` §"Hard Constraints" — never call SendChatMessage, never index msg, no COMBAT_LOG_EVENT_UNFILTERED. Phase 6 doesn't touch chat code; constraints are absolute.
- `CLAUDE.md` Architecture section — `.toc` lists every Lua file in load order. Phase 6 adds `templates.xml` AFTER the Lua files (load order convention).
- `.planning/archive/v0.1.0/03-config-panel-integration/03-CONTEXT.md` — Phase 3 Settings-API panel decisions. Phase 6 extends this panel; doesn't reinvent.

### Phase 5 carry-forward
- `.planning/phases/05-auto-hide-combat-reframe/05-CONTEXT.md` D-12 — engineering-truth model: soft-hidden = visible label-wise. Phase 6's D-12 enforces this in code by NOT firing notify from applySoftHideState.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Config.lua` `CreateSettingsButtonInitializer` pattern at lines 169-186 (Lock button) and 188-216 (Show/Hide button) — same shape Phase 6 keeps for Show/Hide; same `buttonText` closure pattern.
- `Window.lua` `ns:IsWindowShown()` at line ~400 — already returns `win and win:IsShown() or false`. Soft-hidden window returns `true` (because `IsShown()` is true at alpha=0). Engineering-truth model is automatic from this single function — no Phase 6 changes needed here.
- `Window.lua` exported functions at lines 243-271 — `SetWindowScale`, `SetWindowAlpha`, `OnAutoHideChanged`, `LockWindow`, `UnlockWindow`. Phase 6 adds `NotifyWindowVisibilityChanged` to this export set.
- `.toc` 4-line Lua block (lines 12-15) — Phase 6 adds `templates.xml` as line 16.

### Established Patterns
- **Settings.CreateElementInitializer with template name + data table:** Used implicitly by Blizzard's built-in initializers (`CreateSettingsListSectionHeaderInitializer`, `CreateSettingsButtonInitializer`). Phase 6 introduces the first explicit `Settings.CreateElementInitializer(template_name, data)` call in this addon — for the reference image.
- **`layout:AddInitializer` insertion-order = display-order in vertical layout:** Existing pattern. Phase 6 inserts the reference image FIRST (before the "Chat channels" `CreateSettingsListSectionHeaderInitializer`).
- **Section organization in InitConfig:** Existing four functions — `RegisterChannelToggles`, `RegisterWindowControls`, `RegisterMacroSection`, `RegisterSlashHelp`. Phase 6 adds a new top-level `layout:AddInitializer(reference_image_initializer)` call in `ns:InitConfig` BEFORE the four `Register*` calls — OR adds a new `RegisterReferenceImage(category, layout)` function for symmetry. Recommendation: dedicated function for symmetry — matches the existing pattern.

### Integration Points
- **`Config.lua:InitConfig`** (function defining the panel layout sequence) — Phase 6 adds a `RegisterReferenceImage(category, layout)` call as the FIRST `layout:AddInitializer`-bearing function call.
- **`Config.lua:RegisterReferenceImage`** (new function) — calls `layout:AddInitializer(Settings.CreateElementInitializer("TLHSymbolReferenceTemplate", { texturePath = "Interface\\AddOns\\TerribleLuraHelper\\reference.tga" }))`.
- **`templates.xml`** (new file at repo root) — defines the `<Frame name="TLHSymbolReferenceTemplate" virtual="true">` template with child Texture layer. Loaded after Lua per `.toc` ordering.
- **`Window.lua:ns:NotifyWindowVisibilityChanged`** (new exported function) — 3-line body with early-exit guard. Called from ShowWindow / HideWindow / RestoreWindowVisibility.
- **`Window.lua:ns:ShowWindow`, `ns:HideWindow`, `ns:RestoreWindowVisibility`** — each gains one line: `ns:NotifyWindowVisibilityChanged()` after the visibility change completes.
- **`.toc`** — gain one line: `templates.xml` after `Config.lua`.

### Existing Test Surface
- No automated test harness for WoW addons. All testing is in-game smoke pass (CLAUDE.md).
- Phase 6 UAT extends established checkpoint pattern with 7 explicit checkpoints covering image rendering + 4 dynamic-label paths + soft-hide non-flip + release-zip inclusion.
- `stylua` runs after every modified Lua file (CLAUDE.md gate). XML files are not stylua-formatted (different language); manual format check.

</code_context>

<deferred>
## Deferred Ideas

- **POT-padded fallback TGA pre-prepared as a defensive measure** — D-08 deferred. Only generate if SCAF-17 in-game verification reveals the solid-green failure mode. Producing it preemptively wastes effort if non-POT works (which warcraft.wiki.gg suggests it does for modern WoW).
- **Tooltip on the reference image** — Claude's Discretion list; recommended NO tooltip (static informational; tooltip would feel cluttered).
- **Animation/fade-in on image first appearance** — out of scope for v1.0.0. The image either renders or it doesn't; no transition.
- **Responsive image sizing on different panel widths** — out of scope. Native 319×143 fixed.
- **Multiple language variants of the cheat-sheet** — out of scope; single image for v1.0.0.
- **Adding notify-hook calls to additional Window.lua call sites** (e.g., applySoftHideState, FillSlot, ClearAll) — explicitly OOS per D-12. Engineering-truth model means these aren't visibility changes.
- **Caching mechanism for `RepairDisplay()` to debounce repeated calls** — out of scope. Three call sites firing on direct user actions; no debouncing needed.

</deferred>

---

*Phase: 06-dynamic-label-symbol-reference-image*
*Context gathered: 2026-05-09*
