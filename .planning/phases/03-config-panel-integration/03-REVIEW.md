---
phase: 03-config-panel-integration
reviewed: 2026-05-01T06:36:50Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Config.lua
  - Window.lua
  - Macros.lua
  - Core.lua
findings:
  critical: 0
  high: 1
  medium: 5
  low: 5
  info: 3
  total: 14
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-05-01T06:36:50Z
**Depth:** standard
**Files Reviewed:** 4 (Config.lua, Window.lua, Macros.lua, Core.lua)
**Diff range:** `c672fc2..HEAD` (`120ff77`, `56cd7db`, `378912e`, `840492a`, `9c02931`, `bb78bca`, `487dc1a`)
**Status:** issues_found (1 High, 5 Medium, 5 Low, 3 Info; 0 Critical)

## Summary

Phase 3 lands a clean, spec-faithful Settings panel and integration layer. **All hard taint constraints from CLAUDE.md are honored** — verified via grep: zero `SendChatMessage`, zero `COMBAT_LOG_EVENT_UNFILTERED`, zero `InterfaceOptions_AddCategory`, zero `ChatFrame_ReplaceIconAndGroupExpressions`, and zero string operations on `msg` (no `msg:`, no `#msg`, no `msg ..`, no `.. msg`). `CreateMacro`/`EditMacro` are properly guarded by `InCombatLockdown()` with `PLAYER_REGEN_ENABLED` retry. The Settings API usage matches the post-11.0.2 signatures verified against `wow-ui-source@12.0.1`.

The panel correctly defers all `Settings.*` calls inside `EventUtil.ContinueOnAddOnLoaded`, caches the numeric category ID for `/lura config`, binds settings via `RegisterAddOnSetting` (auto-write-through), and uses the dynamic-text `buttonText` function pattern for the Lock/Unlock label. Soft-hide state machine integrates correctly with the existing OnShow/OnHide visibility-gated chat events from Phase 2 AMEND-01.

The one high-severity finding is a frame-leak in `ns:OnMacroChannelChanged` that occurs when the user changes the macro target dropdown more than once during combat. Medium findings cover code duplication in retry-frame logic, an undocumented 4th macro-channel option (`INSTANCE_CHAT`) that extends beyond CONTEXT.md D-35's three-channel list, and a missing post-combat success print on the deferred dropdown-change path. No bugs in the chat-msg pipeline; the soft-hide state machine, position persistence, and slash dispatcher are all correct.

## High

### HI-01: Frame leak in `OnMacroChannelChanged` when dropdown changes multiple times during combat

**File:** `Macros.lua:117-137`
**Issue:** Each call to `ns:OnMacroChannelChanged` during combat creates a new retry `Frame` registered for `PLAYER_REGEN_ENABLED`. If the user changes the dropdown N times during combat, N frames are created. When combat ends, the **first** frame's handler runs `RegisterMacros()`, which clears `registrationDeferred = false` (Macros.lua:78) and unregisters that one frame. The **subsequent** frames' handlers then evaluate `if event == "PLAYER_REGEN_ENABLED" and registrationDeferred then` — `registrationDeferred` is now `false`, so the entire block is skipped, including the `self:UnregisterEvent(...)` call. Those frames stay registered for `PLAYER_REGEN_ENABLED` indefinitely and will fire on every future combat-end with no useful work and no cleanup. They also retain references that prevent garbage collection.

The same retry-frame pattern in `ns:InitMacros` (Macros.lua:88-98) is safe because it is only ever armed once per session (during the initial post-login registration attempt).

**Reproduction:** During combat, change the macro-target dropdown three times (e.g. RAID → RAID_WARNING → INSTANCE_CHAT → SAY). Three frames are created. After combat ends, two are leaked.

**Fix:** Either (a) reuse a single module-level retry frame, or (b) move the unregister out of the inner conditional so any fire of `PLAYER_REGEN_ENABLED` cleans the frame up. Preferred — extract a shared helper and store the frame as a Lua module local:

```lua
-- At module scope:
local retryFrame

local function ArmRegenRetry()
    if retryFrame then return end -- already armed; reuse
    retryFrame = CreateFrame("Frame")
    retryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    retryFrame:SetScript("OnEvent", function(self, event)
        if event ~= "PLAYER_REGEN_ENABLED" then return end
        if registrationDeferred then
            ns:RegisterMacros()
        end
        -- Always unregister + clear handle on combat-end fire,
        -- regardless of whether retry succeeded. Re-arm next time
        -- combat blocks a registration attempt.
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self:SetScript("OnEvent", nil)
        retryFrame = nil
    end)
end

-- In ns:InitMacros and ns:OnMacroChannelChanged combat branches:
if not ns:RegisterMacros() then
    ArmRegenRetry()
end
```

This collapses both call sites onto the same single-frame retry path and eliminates the leak.

## Medium

### ME-01: Macro channel dropdown adds 4th option (`INSTANCE_CHAT`) not present in CONTEXT.md D-35 / UI-SPEC §4.5.2

**File:** `Config.lua:212`, `Macros.lua:33`
**Issue:** CONTEXT.md D-35 explicitly states `Allowed values: "RAID", "RAID_WARNING", "SAY"`. UI-SPEC §4.5.2 lists the same three options in its `container:Add` block. The code adds a fourth value `INSTANCE_CHAT` → `/i` (introduced in commit `bb78bca`). The tooltip at Config.lua:220 also documents `/i` ("/i sends to instance/dungeon chat"). This is a deviation from the planning artifacts.

This is not a runtime bug — `CHANNEL_PREFIX["INSTANCE_CHAT"] = "/i"` is symmetric in Macros.lua:33, and the chat channel `/i` is a real Blizzard slash command — but the planning docs are out of sync.

**Fix:** If the addition is intentional (it appears so given the commit message "add /i to macro target"), update CONTEXT.md D-35 and UI-SPEC §4.5.2 to list four allowed values, OR add a Phase 3 amendment in the verification frontmatter (mirroring Phase 2's AMEND-01..08 convention). No code change needed.

### ME-02: Combat-deferred macro-channel change has no post-combat success print

**File:** `Macros.lua:117-137`
**Issue:** When the user changes the dropdown during combat, the in-combat branch (line 132) prints "Macro target → /<channel>. Macros will update when you leave combat." Out of combat, line 135 prints "Macros target → /<channel>. Macros updated." But after combat ends and the retry frame fires `RegisterMacros`, no second confirmation is printed. The user receives no feedback that the deferred update actually completed.

UI-SPEC §4.5.2 specifies both the in-combat copy and the out-of-combat copy but doesn't lock the post-combat-completion case explicitly. Still, principle of least surprise — a deferred operation should confirm completion.

**Fix:** Inside the retry-frame's OnEvent (after the `ns:RegisterMacros()` call succeeds), print a post-combat confirmation: `print("|cffaa44ffTLH|r: Macros updated (combat ended).")`. If you adopt the HI-01 fix above, the shared helper is the right place to wire this.

### ME-03: Code duplication of retry-frame pattern

**File:** `Macros.lua:88-98` and `Macros.lua:122-131`
**Issue:** The same `CreateFrame("Frame") + RegisterEvent("PLAYER_REGEN_ENABLED") + OnEvent` pattern is duplicated nearly verbatim in `ns:InitMacros` and `ns:OnMacroChannelChanged`. The two copies are functionally identical except for the call origin. This is the same code path the HI-01 fix collapses; calling it out separately because it stands on its own as a readability/maintenance issue.

**Fix:** Extract `ArmRegenRetry()` as proposed in HI-01. Both call sites then just call `ArmRegenRetry()` after a deferred `RegisterMacros` attempt.

### ME-04: `applySoftHideState` runs after window is hidden via OnHide → ManualClear → ClearAll path

**File:** `Window.lua:202-204`, `Window.lua:172-175`
**Issue:** `OnHide` calls `ManualClear()` → `ClearAll()` → `applySoftHideState()`. If `db.window.autoHide == true`, this sets `softHidden = true` and calls `win:SetAlpha(0)` on the now-hidden frame. The state is harmless on a hidden frame, but `softHidden` is left as `true` until the next `ns:ShowWindow` resets it (line 381) or `applySoftHideState` is called again. If anything reads `softHidden` between Hide and Show, it would observe a misleading "soft-hidden" state on a frame that is actually fully hidden.

In practice the only reader is `ns:SetWindowAlpha` (line 256), and that path requires `win` to be visible (the user is dragging the slider with the panel open — not the same time as the window being hidden). So this is theoretical, not a live bug. Worth tightening the invariant.

**Fix:** Either (a) gate `applySoftHideState` to no-op when `not win:IsShown()`, or (b) explicitly reset `softHidden = false` at the top of `OnHide` so the state matches the visibility:

```lua
applySoftHideState = function()
    if not win:IsShown() then
        softHidden = false
        return
    end
    if ns.db.window.autoHide and #sequence == 0 then
        softHidden = true
        win:SetAlpha(0)
    else
        softHidden = false
        win:SetAlpha(ns.db.window.alpha or 1.00)
    end
end
```

### ME-05: `ns.SLASH_HELP` cross-file dependency is implicit

**File:** `Core.lua:120-135`, `Config.lua:53-63`
**Issue:** `ns.SLASH_HELP` is set at top-level chunk load time in Config.lua (line 63). `Core.lua:PrintHelp` reads it. Today this works because the `.toc` lists `Config.lua` after `Core.lua`, so when the user types `/lura help` (well after both files have loaded), the table exists. The defensive fallback at Core.lua:130-134 covers the never-fires case.

Risk: if someone reorders `.toc` (Config.lua before Core.lua) the load-time `ns.SLASH_HELP = SLASH_HELP` still fires before any user can type a slash command, so the runtime is fine — but the implicit cross-file ordering dependency is brittle and not asserted anywhere. The "single source of truth" goal of D-28 is achieved at the cost of a subtle file-load-order coupling.

**Fix:** Either (a) move `SLASH_HELP` definition into Core.lua (its more natural owner — Core.lua is the slash dispatcher) and have Config.lua read `ns.SLASH_HELP` for its panel section, OR (b) add a comment in `.toc` documenting the load order requirement, OR (c) do nothing and accept the brittleness (acceptable for a 4-file addon, but worth the note).

## Low

### LO-01: Recreate-macros button prints two lines on first session use

**File:** `Config.lua:228-237`, `Macros.lua:68-77`
**Issue:** First click on "Recreate" out-of-combat in a fresh session triggers `ns:RegisterMacros()` which prints the once-per-session hint ("TLH macros: N created, N updated. Open /macro and drag them..."), and THEN line 236 prints "TLH: Macros recreated." — two prints back-to-back. UI-SPEC §4.2 explicitly notes this is acceptable: "The print lives in `Config.lua`'s OnClick (not in `Macros.lua`), so the once-per-session flag is untouched." Documenting only — not a bug, but the user gets a slightly noisy first-click experience.

**Fix:** None required (per spec). If desired in v1.1: have `RegisterMacros` return the `(created, updated)` counts so OnClick can print a single combined line.

### LO-02: `MinimalSliderWithSteppersMixin.Label.Right` and `FormatPercentage` are unguarded globals

**File:** `Config.lua:113`, `Config.lua:132`
**Issue:** These two Blizzard-provided globals are referenced without existence checks. If a future Midnight client patch renames or removes either, the panel registration crashes during `ns:InitConfig` (inside `ContinueOnAddOnLoaded`), which fires synchronously inside `ADDON_LOADED`. The error would be visible but the panel would fail to register and `/lura config` would print "settings not yet ready, try again in a moment."

This is the standard idiomatic Blizzard pattern; both helpers are stable across 11.x and 12.0. Not worth defensive-coding for v1, but flag for awareness.

**Fix:** None required. If a future client breaks one of these, wrap in a `pcall` or fallback to a literal `"%d%%"` formatter.

### LO-03: `Settings.OpenToCategory` return value is ignored

**File:** `Core.lua:164`
**Issue:** No error handling if the category ID is stale or the secure backing call fails. Per `wow-ui-source@12.0.1` (`Blizzard_Settings.lua:143-145`), the call routes to `C_SettingsUtil.OpenSettingsPanel` which silently no-ops on invalid IDs. User would see no feedback.

**Fix:** None required. The defensive `if ns.settingsCategoryID then` guard at line 163 covers the only realistic failure mode (registration not yet complete). Stale IDs cannot occur in v1 because the category is registered exactly once per session.

### LO-04: `ns:RestoreWindowVisibility` and `ns:ShowWindow` duplicate position+show logic

**File:** `Window.lua:375-385`, `Window.lua:395-402`
**Issue:** Both functions call `applySavedPosition()` then `win:Show()`. They differ only in: `ShowWindow` forces `softHidden=false` and `win:SetAlpha(db.window.alpha)`, sets `db.window.visible=true`; `RestoreWindowVisibility` calls `applySoftHideState()` instead and skips the `db.window.visible` write (because it's already `true`).

Modest duplication; both functions are short and self-documenting. Could consolidate into a single function with a `respectSoftHide` boolean, but the current shape reads cleanly.

**Fix:** None required. Note for future v1.1 cleanup if this file grows.

### LO-05: `/lura` toggle uses `ns:IsWindowShown` which returns `win:IsShown()` truthy even while soft-hidden

**File:** `Core.lua:171-175`, `Window.lua:408-410`
**Issue:** `IsWindowShown` returns `win:IsShown()`. While soft-hidden, `win:IsShown()` returns `true` (alpha=0 only, frame is still shown — verified per UI-SPEC §3.5). So `/lura` no-arg toggle while the window is soft-hidden treats it as "shown" and the toggle calls `HideWindow`. This actually matches user intent — the user thought the window was hidden (alpha=0), they typed `/lura` to "show", but the addon thinks it's shown and hides. Then `/lura` again to "show" actually shows.

This is a UX wart but not a functional bug. Soft-hide is opt-in via auto-hide checkbox; users who enable it accept the alpha=0 model.

**Fix:** None required for v1. If reported as confusing in v1.1, change `IsWindowShown` to `return win and win:IsShown() and not softHidden` so the no-arg toggle treats soft-hide as "hidden" for toggling purposes. Defer.

## Info

### IN-01: Panel button label staleness on click is documented expected behavior

**File:** `Config.lua:166-185`
**Issue:** As noted in UI-SPEC §4.3 (verified against `Blizzard_SettingControls.lua:702-720`), the dynamic `buttonText` function is evaluated only on `Init`, not on `db.window.locked` change. Clicking the panel's Lock/Unlock button toggles the lock state but the button label does NOT update on the open instance — it shows the OLD label until the panel is closed and reopened.

Documented in the spec; mitigated by the `/lura lock` and `/lura unlock` slash commands as escape hatches. Calling out so reviewers don't flag it.

**Fix:** None required for v1. v1.1 mitigation: have OnClick call `Settings.OpenToCategory(ns.settingsCategoryID)` after `ToggleLocked()` to force a re-Init and refresh the label.

### IN-02: `softHidden` Lua local is never persisted across `/reload`

**File:** `Window.lua:52`
**Issue:** `softHidden` resets to `false` every reload. On reload, `RestoreWindowVisibility` runs `win:Show()` (which does NOT immediately apply alpha=0 even if autoHide is on and sequence is empty) THEN `applySoftHideState()` which does the right thing. Between the two there's a single-frame window where the frame is shown at the previous alpha. Imperceptible (sub-frame) but worth noting.

Sequence is also in-memory only (D-27), so `#sequence == 0` is always true on reload. If `autoHide=true`, soft-hide always re-engages on reload via `applySoftHideState()`. Correct.

**Fix:** None required. If the single-frame flash is ever observed: set `win:SetAlpha(0)` before `win:Show()` in `RestoreWindowVisibility` when `autoHide=on`.

### IN-03: `Window.lua:299` `_G[pos[2]]` lookup falls back to `UIParent`

**File:** `Window.lua:299`
**Issue:** Saved position's `relativeTo` global name is looked up via `_G`. If the name is invalid or the global was removed (e.g., user disabled an addon whose frame was the parent), it falls back to `UIParent`. This is correct defensive behavior. Calling out for traceability — no action needed.

**Fix:** None required.

---

## Constraint Verification

All hard constraints from `CLAUDE.md` verified clean across the four files:

| Constraint | Result |
|------------|--------|
| Zero `SendChatMessage` calls | PASS — grep returned no matches |
| Zero string operations on `msg` from `CHAT_MSG_*` (`msg:`, `#msg`, `msg ..`, `.. msg`) | PASS — grep returned no matches; `msg` flows opaque through `C_ChatInfo.ReplaceIconAndGroupExpressions` to `FontString:SetText` only (Window.lua:343-353) |
| No `COMBAT_LOG_EVENT_UNFILTERED` | PASS — grep returned no matches |
| No `ChatFrame_ReplaceIconAndGroupExpressions` (deprecated; modern `C_ChatInfo` only) | PASS — grep returned no matches |
| `CreateMacro` / `EditMacro` guarded by `InCombatLockdown()` | PASS — `Macros.lua:47-50` and `Macros.lua:60-64` (call sites are inside `RegisterMacros` which short-circuits on combat); `Config.lua:229-234` recreate-button OnClick re-checks before calling |
| No `InterfaceOptions_AddCategory` (deprecated; modern Settings API only) | PASS — grep returned no matches; `Settings.RegisterAddOnCategory` used instead |
| `Settings.RegisterAddOnSetting` post-11.0.2 signature `(categoryTbl, variable, variableKey, variableTbl, variableType, name, defaultValue)` | PASS — all 5 call sites verified (Config.lua:73-81, 100-108, 119-127, 143-151, 196-204) |
| `Settings.OpenToCategory` receives numeric ID, never name | PASS — `Core.lua:164` passes `ns.settingsCategoryID` which is `category:GetID()` (Config.lua:276) |
| `EventUtil.ContinueOnAddOnLoaded` deferral | PASS — Config.lua:269 wraps all `Settings.*` calls |
| Channel DB keys match `db.listenChannels` schema (`INSTANCE_CHAT`, NOT `INSTANCE`) | PASS — Config.lua:39, 41 use `INSTANCE_CHAT` / `INSTANCE_CHAT_LEADER`; aligns with `event:sub(10)` filter at Window.lua:338 |
| All globals namespaced on `ns` or file-local | PASS — all `function ns:Foo()` exports use `ns:`; `local addonName, ns = ...` shared across all 4 files; no stray globals introduced |

## Spec Traceability

13 Phase 3 REQ-IDs verified delivered in code:

| REQ | Status | File:line |
|-----|--------|-----------|
| CFG-01 (modern Settings API + EventUtil deferral) | Delivered | Config.lua:269, 275, 283 |
| CFG-02 (6 channel checkboxes via `RegisterAddOnSetting`) | Delivered | Config.lua:30-45, 68-88 |
| CFG-03 (channel filter at handle time) | Delivered (Phase 2 path) | Window.lua:338-340 |
| CFG-04 (scale slider 0.50–2.00, default 1.00, step 0.05) | Delivered | Config.lua:99-115 |
| CFG-05 (auto-hide checkbox; soft-hide model) | Delivered | Config.lua:142-160; Window.lua:233-241 |
| CFG-06 (Recreate Macros button with combat deferral) | Delivered | Config.lua:226-246 |
| CFG-07 (Lock/Unlock button with state-dependent label) | Delivered | Config.lua:166-185 |
| CFG-08 (8 slash help entries via repeated section headers) | Delivered | Config.lua:53-63, 253-258 |
| CFG-09 (settings persist across reload) | Delivered | `RegisterAddOnSetting` auto-write-through |
| CFG-10 (alpha slider 0.20–1.00, default 1.00, step 0.05; live update) | Delivered | Config.lua:117-139 |
| CFG-11 (macro-channel dropdown + re-registration) | Delivered with deviation | Config.lua:191-222; Macros.lua:30-35, 117-137 — see ME-01 (4th option not in spec) |
| CMD-05 (`/lura config` opens panel via numeric ID) | Delivered | Core.lua:161-169 |
| WIN-08 (scale slider live-updates window) | Delivered | Window.lua:247-251 |
| WIN-10 (alpha slider live-updates window with soft-hide gate) | Delivered | Window.lua:253-259 (D-21 honored) |

## Unrequested Strengths

- Comprehensive inline documentation referencing CONTEXT.md decision IDs (D-01..D-40) and UI-SPEC sections — makes future audits cheap.
- Defensive fallback in `Macros.lua:54` (`CHANNEL_PREFIX[ns.db.macroChannel] or "/raid"`) handles corrupted SavedVariables gracefully.
- Window.lua's forward-declaration block (lines 55-57) cleanly resolves the OnShow/OnHide callback ↔ helper-function ordering without resorting to heavy upvalue manipulation.
- `Core.lua:78-80` correctly NOT backfilling `db.window.position` (the `nil` sentinel is meaningful to `applySavedPosition`).
- `applySoftHideState` is the single funnel for soft-hide entry/exit decisions — reachable from 5 call sites, all consistent.

---

_Reviewed: 2026-05-01T06:36:50Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
