---
phase: 06-dynamic-label-symbol-reference-image
reviewed: 2026-05-09T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Window.lua
  - Config.lua
  - templates.xml
  - TerribleLuraHelper.toc
  - scripts/install.bat
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 5+6: Code Review Report

**Reviewed:** 2026-05-09
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

This is a combined review of Phase 5 (auto-hide combat reframe) and Phase 6 (dynamic Show/Hide label + symbol reference image). All five hard constraints from CLAUDE.md are verified clean: zero `SendChatMessage` calls, zero `COMBAT_LOG_EVENT_UNFILTERED` registrations, zero Lua string operations on the `msg` argument, zero SAFE-06 `db.X = db.X or DEFAULT` patterns in any `.lua` file, and the AMEND-01 invariant (`applySoftHideState` uses `SetAlpha(0)` exclusively, never `win:Hide()`) is intact.

Phase 5's `combatFrame` is correct: seeded with `InCombatLockdown()` at frame-creation time to handle `/reload` mid-combat, permanently registered on both regen edges, flips `inCombat` and re-evaluates `applySoftHideState` on each edge. D-12 is verified: `applySoftHideState` does NOT call `ns:NotifyWindowVisibilityChanged`.

Phase 6's `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` at file scope is sound: `SettingsButtonControlMixin` is defined in `Blizzard_SettingControls.lua` (loaded via `Blizzard_Settings_Shared`, a Blizzard built-in that always loads before any third-party addon), so the global exists when Config.lua executes. The sentinel `data._tlhShowHideButton` correctly distinguishes the Show/Hide button initializer from every other `CreateSettingsButtonInitializer` in the panel. The ScrollBox frame-pool lifecycle is correctly handled: the hook fires on Init (the moment a pooled frame is bound to an initializer), the `IsVisible()` guard in `RefreshShowHideButton` prevents a stale cache entry from writing to an off-screen recycled frame. `scripts/install.bat` and `TerribleLuraHelper.toc` are in sync.

One warning and two info items follow.

## Warnings

### WR-01: `hooksecurefunc` on a Blizzard mixin method taints the hooked function's execution context

**File:** `Config.lua:256`
**Issue:** `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` replaces the function value stored in the mixin table with a secure wrapper that calls the original and then calls the addon-provided hook. The hook body itself is addon (tainted) Lua code. In WoW's taint model, `hooksecurefunc` is specifically designed to allow this pattern safely — the hook runs AFTER the original returns and does NOT propagate taint back into the protected original. However, the addon hook touches `cachedShowHideFrame` (an upvalue), which means any subsequent call to `ns:RefreshShowHideButton` that reads `cachedShowHideFrame` is addon-controlled and safe. The concern is narrower: `SettingsButtonControlMixin:Init` itself is called from the ScrollBox factory path inside `securecallfunction` (verified in `Blizzard_SettingsList.lua` line 51-53). The `securecallfunction` wrapper executes its inner function in a protected context. A tainted post-hook added via `hooksecurefunc` on the mixin will still execute after that protected call returns — this is the documented and intended behavior. **In practice this is safe**, but it is a WoW-specific pattern that deserves a documented rationale in the code, because it will trigger "why are we hooking a Blizzard method at file scope?" questions from any future reviewer.

**Fix:** Add a comment directly above the `hooksecurefunc` call explaining why file-scope (not deferred) placement is correct and that `hooksecurefunc` is the taint-safe mechanism for this pattern:

```lua
-- hooksecurefunc is the correct tool here: it appends an addon-controlled
-- post-hook without replacing the original protected function, so taint
-- never flows back into SettingsButtonControlMixin:Init's execution context.
-- File-scope placement is intentional — SettingsButtonControlMixin is defined
-- in Blizzard_SettingControls.lua (part of Blizzard_Settings_Shared, a Blizzard
-- built-in), which is fully loaded before any third-party addon TOC file executes,
-- so the global exists when this line runs. Deferring to ADDON_LOADED is not
-- required and would create a window where the hook is not yet installed.
hooksecurefunc(SettingsButtonControlMixin, "Init", function(frame, initializer)
```

## Info

### IN-01: `cachedShowHideFrame` is never cleared on panel close — stale frame reference after pool recycle

**File:** `Config.lua:255-267`
**Issue:** `cachedShowHideFrame` is set in the hook whenever the Show/Hide button's frame is initialized from the pool. It is never set back to `nil`. When the user closes the Settings panel (or navigates to a different category), the ScrollBox releases all rendered frames back to the pool via `SettingsButtonControlMixin:Release`. At that moment `cachedShowHideFrame` still points to the released frame. `SettingsListElementMixin:Release` sets `self.data = nil` on the released frame. The `IsVisible()` guard in `RefreshShowHideButton` (line 264) prevents a write to a hidden/recycled frame, so no incorrect text mutation occurs. But the dangling pointer is unnecessary state and could confuse a future reader who expects `cachedShowHideFrame` to always be a "live" frame.

This is a latent clarity issue, not a runtime bug: the `IsVisible()` guard provides the actual safety guarantee.

**Fix:** Either (a) document the lifecycle explicitly in the comment above `cachedShowHideFrame`, noting that `IsVisible()` is the runtime guard and the stale reference is intentional, or (b) hook `SettingsButtonControlMixin:Release` to clear the cache when our frame is released:

```lua
-- Option (a): clarify in comment (minimal change)
-- cachedShowHideFrame may be stale (frame returned to pool after panel close).
-- IsVisible() is the runtime guard; callers must check it before SetText.
local cachedShowHideFrame

-- Option (b): clear on release
hooksecurefunc(SettingsButtonControlMixin, "Release", function(frame)
    if frame == cachedShowHideFrame then
        cachedShowHideFrame = nil
    end
end)
```

Option (a) is lower risk because option (b) adds a second `hooksecurefunc` and the current guard already works correctly.

### IN-02: `local combatFrame` shadows the broader "never unregisters" intent documented in the comment

**File:** `Window.lua:191`
**Issue:** `combatFrame` is declared as a `local` inside `CreateWindow()`. The comment on lines 182-188 correctly documents that this frame "never unregisters, unlike Macros.lua's regenFrame." That is true — the frame's event registrations are permanent because the frame is never garbage-collected (WoW frames are C-level objects not subject to Lua GC once registered). However, the `local` scoping means the Lua variable `combatFrame` itself goes out of scope when `CreateWindow` returns, leaving no Lua-side handle. This is intentional (the frame is not needed after creation) but is worth a brief in-line note to prevent a future "bug: we lost the reference" investigation.

**Fix:** Add a one-line comment on the declaration:

```lua
-- local because no Lua-side handle is needed after registration;
-- the C-level frame persists and its event registrations are permanent.
local combatFrame = CreateFrame("Frame")
```

---

## Hard Constraint Verification

| Constraint | Result |
|---|---|
| No `SendChatMessage` in any `.lua` | PASS — grep returns zero matches |
| No `COMBAT_LOG_EVENT_UNFILTERED` in any `.lua` | PASS — grep returns zero matches |
| No Lua string ops on `msg` argument | PASS — only `C_ChatInfo.ReplaceIconAndGroupExpressions` pipeline used |
| AMEND-01: `applySoftHideState` uses `SetAlpha` only, never `win:Hide()` | PASS — verified lines 258-266; `win:Hide()` appears only at line 73 (init) and line 438 (`ns:HideWindow`) |
| D-12: `applySoftHideState` does NOT call `NotifyWindowVisibilityChanged` | PASS — function body lines 258-266 contains no notify call |
| SAFE-06: no `db.X = db.X or DEFAULT` pattern | PASS — all backfills use `if db.X == nil then db.X = DEFAULT end` (Core.lua) |
| `templates.xml` in TOC after Config.lua | PASS — TOC line 16 |
| `templates.xml` and `reference.tga` in install.bat | PASS — install.bat lines 13-14 |

---

_Reviewed: 2026-05-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
