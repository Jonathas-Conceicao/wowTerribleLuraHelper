# Pitfalls Research

**Domain:** WoW Midnight addon — v1.0.0 polish features (click-through, cheat-sheet texture, dynamic label, defaults change, auto-hide-in-combat reframe)
**Researched:** 2026-05-09
**Confidence:** HIGH — all pitfalls verified against wow-ui-source@12.0.1, live Core.lua/Window.lua/Config.lua code, and prior phase review logs (02-REVIEW.md, 03-REVIEW.md)

---

## Critical Pitfalls

### Pitfall CT-1: EnableMouse(false) on the parent frame does NOT cascade to children

**What goes wrong:**
When `win:EnableMouse(false)` is called to make the locked window click-through, the five slot frames (`slotFrames[1..5]`), `bossView`, and any other child frames that have `EnableMouse(true)` retain their own mouse-enabled state. Mouse events on those children are still captured by the child frames, blocking clicks to the world beneath — the window is not fully click-through. For TLH specifically: `bossView` is a plain frame with no mouse flag, but the five slot frames are also plain frames that inherit no explicit EnableMouse call. If any future code adds `EnableMouse(true)` to slots (e.g., for tooltips), the parent call will not automatically undo it.

**Why it happens:**
`EnableMouse` is per-frame, not inherited. This is confirmed by Blizzard's own DamageMeter addon which explicitly iterates all child frames when toggling its "non-interactive" mode:
```lua
-- DamageMeterSessionWindow.lua:830-836
local enabled = not nonInteractive;
self:EnableMouse(enabled);
self:GetSessionDropdown():EnableMouse(enabled);
self:GetResizeButton():EnableMouse(enabled);
self:ForEachEntryFrame(function(frame) frame:EnableMouse(enabled); end);
```
Developers assume inheritance because many UI properties do cascade; mouse input does not.

**How to avoid:**
In `applyLockState`, call `EnableMouse(false)` on `win` AND explicitly on every child frame that has or might have mouse interaction: the five slot frames, `bossView`. Since `lockBtn` is already hidden when locked (`lockBtn:Hide()`), it naturally absorbs no clicks — but hide it first, then disable mouse on `win`. Pattern:
```lua
applyLockState = function()
    local locked = ns.db.window.locked
    if locked then
        win:SetMovable(false)
        win:RegisterForDrag()
        win:EnableMouse(false)
        -- Children must be disabled explicitly — does NOT cascade.
        for i = 1, 5 do slotFrames[i]:EnableMouse(false) end
        lockBtn:Hide()
    else
        win:EnableMouse(true)
        for i = 1, 5 do slotFrames[i]:EnableMouse(false) end -- slots have no mouse use either way
        win:SetMovable(true)
        win:RegisterForDrag("LeftButton")
        lockBtn:Show()
    end
end
```
Note: if slots never have `EnableMouse(true)` set, this is defensive-only, but cheap. If future code adds slot tooltips with `OnEnter`/`OnLeave`, the guard becomes load-bearing.

**Warning signs:**
- In QA: click locked window area near slot positions — if the cursor changes shape or a right-click context menu appears, children are still capturing mouse.
- In code: any `slotFrames[i]:EnableMouse(true)` or `slot:SetScript("OnEnter", ...)` call without a paired `applyLockState` update.

**Phase to address:**
Click-through implementation phase (Phase 1 of v1.0.0). Architectural decision — the loop over children must be built into `applyLockState` at the same moment `win:EnableMouse` is added.

---

### Pitfall CT-2: RegisterForDrag() clear does not stop an in-progress drag

**What goes wrong:**
If the user starts dragging the window (mousedown) and then the lock state changes mid-drag (e.g., from a macro or slash command that somehow fires during the drag), `RegisterForDrag()` removes the binding, but `win:StartMoving()` has already been called. The frame continues moving until `win:StopMovingOrSizing()` is called or mouseup fires. `OnDragStop` calls `StopMovingOrSizing()` on mouseup — if `RegisterForDrag()` was cleared, the `OnDragStart` guard (`if self:IsMovable()`) prevents a second start, but the current drag completes. The position saved by `persistPosition()` in `OnDragStop` will then reflect the unlocked drag that completed while locking was triggered.

**Why it happens:**
`RegisterForDrag()` controls which button press initiates a drag, not the currently-running drag. Clearing it mid-drag is too late.

**How to avoid:**
In `applyLockState`, if locking while `win:IsMouseButtonDown("LeftButton")` is true, call `win:StopMovingOrSizing()` immediately before clearing `RegisterForDrag`. This is a narrow edge case but cheap to guard:
```lua
if locked then
    if win:IsMouseButtonDown("LeftButton") then
        win:StopMovingOrSizing()
    end
    win:SetMovable(false)
    win:RegisterForDrag()
    win:EnableMouse(false)
    lockBtn:Hide()
end
```

**Warning signs:**
- QA: start dragging the window, immediately type `/lura lock` (requires two hands or a keyboard macro), observe if the window jumps to an unexpected position after mouseup.
- Code: `applyLockState` that clears `RegisterForDrag` but does not call `StopMovingOrSizing` first.

**Phase to address:**
Click-through implementation phase. Marginal edge case but the fix is one line.

---

### Pitfall CT-3: EnableMouse(false) on a PROTECTED function is restricted during combat

**What goes wrong:**
`EnableMouse` is marked `IsProtectedFunction = true` in `SimpleScriptRegionAPIDocumentation.lua`. Protected functions on secure frames cannot be called from addon code during combat lockdown. If `applyLockState` is called while `InCombatLockdown()` is true (e.g., from `/lura unlock` mid-fight), the `EnableMouse` call will either silently fail or throw a Lua error, leaving the frame in an inconsistent mouse state.

**Why it happens:**
Addon code calling protected frame functions during combat is disallowed on `SECURE` frame types. Plain `CreateFrame("Frame", ...)` without a secure template is generally NOT a secure frame, so the restriction may not apply — but this is client-version-specific behavior. The Blizzard API docs flag `EnableMouse` as `IsProtectedFunction = true`, which indicates the function has restrictions in some contexts.

**How to avoid:**
In `applyLockState`, add an `InCombatLockdown()` guard. If in combat, defer the `EnableMouse` call to `PLAYER_REGEN_ENABLED` (similar to the macro-registration deferral pattern already in `Macros.lua`). Since the spec says unlock paths during combat are `/lura unlock` and the config-panel button, both of which can be issued in combat, this guard is likely needed:
```lua
applyLockState = function()
    if InCombatLockdown() then
        -- Re-arm on combat exit; lock state is already written to db.
        -- Window remains in current mouse state until combat ends.
        return
    end
    -- ... rest of applyLockState
end
```
Register a single `PLAYER_REGEN_ENABLED` listener that calls `applyLockState()` when it fires, and arm it if `applyLockState` is called while in combat. Mirror the `ArmRegenRetry` pattern from `Macros.lua`.

**Warning signs:**
- Lua error in combat on `/lura lock` or `/lura unlock`: "attempt to call protected function during combat lockdown"
- QA: run `/lura lock` during a boss fight dummy encounter and check for errors in chat.

**Phase to address:**
Click-through implementation phase. Must be verified during in-combat QA.

---

### Pitfall TX-1: .pkgmeta excludes "*.png" — cheat-sheet image will not ship

**What goes wrong:**
The current `.pkgmeta` has `"*.png"` in the `ignore:` list. Any PNG file committed to the repo will be stripped by BigWigs Packager before the CurseForge/Wago/GitHub release ZIP is built. The cheat-sheet image at `Textures/CheatSheet.png` (or whatever path is chosen) will be present locally after `install.bat` but absent from released packages. Users downloading from CurseForge will get a broken or invisible cheat-sheet panel with no error.

**Why it happens:**
The sibling addon `TerribleBuffTracker` also has `"*.png"` in its `.pkgmeta`. The exclusion was originally added to avoid shipping developer screenshots or design mockups. The pattern is too broad — it removes all PNG files, including intentional addon assets.

**How to avoid:**
Either:
1. Change `"*.png"` to a more specific ignore pattern that targets only documentation-adjacent PNGs: `docs/*.png`, `screenshots/*.png`, etc.
2. Use a TGA format instead — `"*.tga"` is NOT in the ignore list; BigWigs Packager passes TGA files through. WoW's `SetTexture` API accepts TGA files natively. This is the recommended approach because it avoids changing the ignore pattern while also using a format guaranteed to survive packaging.
3. If PNG is kept, replace `"*.png"` in `.pkgmeta` with named ignores: `- README.png\n  - showcase/*.png` (etc.).

The correct fix before shipping: remove `"*.png"` from `.pkgmeta` ignore list and add specific ignores for any documentary PNGs. Verify the release ZIP contains the texture file before tagging.

**Warning signs:**
- In `.pkgmeta`: `"*.png"` in `ignore:` list (currently present — confirmed in review).
- After `release.bat`: unzip the release artifact and confirm the texture file is present.
- Code that does `SetTexture("Interface\\AddOns\\TerribleLuraHelper\\Textures\\CheatSheet")` and shows nothing in-game after install from CurseForge (but works locally).

**Phase to address:**
Asset pipeline phase — must be resolved before any texture `SetTexture` call is written. If the image asset does not survive packaging, the milestone gate ("no placeholder ship") cannot be met.

---

### Pitfall TX-2: SetTexture path vs FileDataID — wrong choice breaks addon-shipped assets

**What goes wrong:**
Using a numeric FileDataID (e.g., `tex:SetTexture(123456)`) for a custom addon-shipped image fails silently — FileDataIDs are assigned by Blizzard to assets in the game client's CASC archive, not to addon files. The correct API for addon-shipped files is the string path form: `tex:SetTexture("Interface\\AddOns\\TerribleLuraHelper\\Textures\\CheatSheet")`. Using a FileDataID that happens to be valid for a different Blizzard image (to use as a placeholder) works in development but is not your asset.

**Why it happens:**
Developers see FileDataID usage in the POC (`Macros.lua:12-21` uses `137001..137008` for raid markers) and apply the same pattern to custom assets.

**How to avoid:**
For addon-shipped image files: always use the string path form without extension. WoW resolves `"Interface\\AddOns\\TerribleLuraHelper\\Textures\\CheatSheet"` to the TGA/BLP file at that path automatically. Do NOT include the `.tga` extension in the path string — Blizzard's loader strips it. Do NOT use FileDataIDs for custom files. Pattern:
```lua
local tex = panel:CreateTexture(nil, "ARTWORK")
tex:SetTexture("Interface\\AddOns\\TerribleLuraHelper\\Textures\\CheatSheet")
tex:SetAllPoints(panel)  -- or size explicitly
```

**Warning signs:**
- `SetTexture(number)` call where the number is not a known Blizzard built-in.
- Texture appears correctly in development but the wrong image shows for users (because their CASC FileDataID mapping may differ on different client patches).

**Phase to address:**
Asset pipeline phase, same as TX-1. Decided before writing any SetTexture call.

---

### Pitfall TX-3: Texture not loading because the panel initializer runs only on panel open — but texture creation must happen at Init time, not at panel-open time

**What goes wrong:**
The Settings panel uses a pool/recycler model (`SettingsListElementMixin:Init` / `Release`). If the cheat-sheet texture frame is created inside the initializer's `Init` callback (which fires on panel open), and the texture is loaded from disk the first time the panel opens, there can be a single-frame flash or blank space before the texture is fully loaded. More critically: if the panel is closed and reopened, the frame may be `Release()`-d and a new frame created — creating a new Texture object each time. If the texture file is large enough to not be cached, the flash recurs.

**Why it happens:**
Addon developers create textures inside `Init` callbacks because that's where the frame reference is available. For standard elements this is fine; for large images it causes visual glitches.

**How to avoid:**
Create the texture frame and call `SetTexture` once, outside any `Init` callback — at addon initialization time (in `ns:InitConfig` or inside the `EventUtil.ContinueOnAddOnLoaded` closure). Anchor it to a frame that exists throughout the addon's lifetime. For a panel header image in the Settings panel, the preferred approach is to use a custom `CreateElementInitializer` that embeds the texture in a fixed-size frame which the panel's layout system sizes and positions. The texture object and its `SetTexture` call happen once; the layout system positions the pre-loaded frame each panel open.

**Warning signs:**
- `SetTexture` called inside an `Init` method of a settings element.
- Texture flickers for ~1 frame on panel open (especially on slower HDDs or first-open).

**Phase to address:**
Texture-in-panel implementation phase. Architectural decision about where texture creation lives.

---

### Pitfall DL-1: Dynamic label uses a notify hook subscribed in panel Init without unsubscribing on Release — memory leak on panel re-open

**What goes wrong:**
The planned approach for the dynamic Show/Hide button label is a notify hook: Window.lua calls `ns.onWindowShownChanged()` from every visibility-change path, and Config.lua subscribes a closure that calls `button:SetText(...)`. If that subscription is done inside the `Init` callback of the `SettingButtonControlMixin` and the reference is stored in a module-level `ns.onWindowShownChanged` table, closing and reopening the panel causes `Init` to run again without `Release` having removed the prior subscription. After N panel opens, there are N closures holding references to potentially-stale `button` references (from prior pooled frames).

**Why it happens:**
The `SettingButtonControlMixin` lifecycle (`Init` / `Release` / `cbrHandles:Unregister`) manages Blizzard-API subscriptions automatically. But a custom notify hook stored on `ns` (outside `cbrHandles`) is invisible to the framework's cleanup pass.

**How to avoid:**
Two safe patterns:
1. **Single-slot ns hook** — Store exactly one function reference in `ns.onWindowShownChanged`. `Init` overwrites it; `Release` sets it to nil. Since only one button element exists, there is never more than one valid subscriber. In Release: `ns.onWindowShownChanged = nil`. In Init: `ns.onWindowShownChanged = function() button:SetText(...) end`. The risk: if `Release` is not called before a new `Init` (pool lifecycle edge), the old reference is orphaned — mitigated by the single-slot overwrite.
2. **EventRegistry approach** — Raise a custom `EventRegistry` event from the visibility-change paths. Inside `Init`, use `self.cbrHandles:AddHandle(EventRegistry:RegisterCallbackWithHandle("TLH_WINDOW_SHOWN_CHANGED", OnEvent, self))`. The framework's `cbrHandles:Unregister()` in `Release` auto-cleans the subscription. This is the cleanest approach and matches how Blizzard itself handles this pattern (see `SettingsButtonControlMixin.Init:713-717`).

**Warning signs:**
- `ns.onWindowShownChanged` assigned in `Init` with no corresponding nil-assignment in a `Release` function for the same element.
- Memory growth on repeated panel open/close (hard to measure in WoW, but stale closure references accumulate).
- Button text update fires for a button that no longer exists on screen (stale reference).

**Phase to address:**
Dynamic label implementation phase. Must decide between single-slot and EventRegistry approach before writing the first line. Single-slot is simpler for v1.0.0 given only one subscriber ever exists; EventRegistry is more correct if label-update consumers multiply.

---

### Pitfall DL-2: Notify hook called from inside a chat-event handler — taint risk

**What goes wrong:**
`FillSlot` and `ClearAll` (called from the chat-event handler) modify `#sequence`. If the auto-hide-in-combat reframe causes the window to hide/show during `FillSlot`, and `ShowWindow`/`HideWindow` call the notify hook, and the notify hook calls `button:SetText(...)` on a Settings panel button — that is addon Lua touching UI elements from a chat-event context with a potentially tainted `msg` derivation chain. Specifically: the `msg`-derived `processed` string flows into `FillSlot`, which triggers `applySoftHideState`, which may trigger a show/hide, which fires the notify hook. The notify hook itself does not touch `msg`, but the call chain from the `chatFrame:SetScript("OnEvent", ...)` handler is the concern.

In practice, `processed` is the output of `C_ChatInfo.ReplaceIconAndGroupExpressions` which is a Blizzard-secure helper — so the taint fence is at that call. But if the notify hook calls anything that Blizzard considers taint-sensitive (e.g., opening or modifying the Settings panel), it could propagate taint unexpectedly.

**Why it happens:**
Notify hooks seem like simple callbacks. Developers don't trace the call graph back through the chat-event handler to evaluate taint exposure.

**How to avoid:**
The notify hook must only call `button:SetText(string)` — a pure UI write with no taint implications. Do NOT: call `Settings.OpenToCategory`, trigger panel re-initialization, or access Blizzard unit/UI globals. The taint fence at `C_ChatInfo.ReplaceIconAndGroupExpressions` protects the `processed` value, and `FontString:SetText` is the endpoint for the taint-safe pipeline. A `Button:SetText` call on a Settings panel button follows the same safe pattern and is fine. The risk arises only if the notify hook reaches beyond a simple text update.

**Warning signs:**
- Notify hook does anything more than `button:SetText(...)` or `button:SetEnabled(bool)`.
- Lua error during boss fight: "Call to protected function" or "Script protected" referencing the notify path.
- `/lura` or chat events triggering taint errors on any game action (attack, spell, ability) that follows the sequence fill.

**Phase to address:**
Dynamic label implementation phase. The notify hook's scope must be defined as "text update only" in code comments before implementation.

---

### Pitfall DL-3: Forgetting one of the six visibility-change paths — button label drifts

**What goes wrong:**
The Show/Hide button label must stay in sync across all paths that change window visibility. The current codebase has these paths:
1. `/lura show` → `ns:ShowWindow()`
2. `/lura hide` → `ns:HideWindow()`
3. `/lura` (no arg, toggle) → `ns:ShowWindow()` or `ns:HideWindow()`
4. Config-panel Show/Hide button `OnClick` → `ns:ShowWindow()` or `ns:HideWindow()`
5. 20s inactivity timer → `ClearAll()` → `applySoftHideState()` — if autoHide changes alpha, does the label reflect "hidden"? (Soft-hide is alpha=0, `win:IsShown()` returns `true` — the label would say "Hide window" even though the window is invisible. This is the existing LO-05 discrepancy from Phase 3.)
6. Auto-hide-in-combat (new): `PLAYER_REGEN_DISABLED` (enter combat, sequence empty) → potentially hides. `PLAYER_REGEN_ENABLED` (leave combat) → potentially shows or stays hidden.

If the notify hook is only wired from `ns:ShowWindow()` and `ns:HideWindow()`, path 6 will silently diverge.

**Why it happens:**
Developers wire the hook to the explicit show/hide functions and forget the new combat-state paths which may bypass those functions entirely (going directly through `applySoftHideState` or a new `win:Hide()` call in the combat handler).

**How to avoid:**
Canonicalize: every window state change must go through `ns:ShowWindow()`, `ns:HideWindow()`, or at minimum call the notify hook. For the auto-hide-in-combat path: if `PLAYER_REGEN_ENABLED`/`PLAYER_REGEN_DISABLED` drives a `win:SetAlpha(0)` (soft-hide), the notify hook should fire only if the window truly changes from shown to hidden or vice versa — not on every soft-hide alpha change, since soft-hide does not change `win:IsShown()`. For the label: if `IsWindowShown()` returns `win:IsShown()`, soft-hide always reads as "shown." This is the existing LO-05 wart and v1.0.0 should not change the `IsWindowShown` semantics mid-milestone.

**Warning signs:**
- Button label says "Show window" when the window is visible (or vice versa) after a combat-exit auto-hide cycle.
- Any new code path that calls `win:Hide()` or `win:Show()` directly, bypassing `ns:ShowWindow()`/`ns:HideWindow()`.

**Phase to address:**
Dynamic label implementation phase. Build the hook into `ns:ShowWindow()` and `ns:HideWindow()` — not into `win:Show()` and `win:Hide()` directly — to match where the bookkeeping already lives.

---

### Pitfall DB-1: Backfill using "db.X = db.X or DEFAULT" clobbers explicit false/empty-string values

**What goes wrong:**
The v0.1.0 `listenChannels` backfill already uses the correct `if db.X == nil then` pattern (Core.lua:62). But if any new v1.0.0 backfill for the defaults change uses the Lua idiom `db.X = db.X or DEFAULT`, it will clobber:
- `db.window.locked = false` → `false or DEFAULT` evaluates to `DEFAULT` (since `false` is falsy in Lua).
- `db.listenChannels.SAY = false` → `false or true` evaluates to `true`, silently re-enabling SAY for a user who explicitly turned it off.
- `db.macroChannel = ""` (corrupted) → `"" or "SAY"` evaluates to `"SAY"` — this one is arguably correct, but the inconsistency is the danger.

**Why it happens:**
`x = x or default` is idiomatic Lua for "initialize if nil," but it is wrong for boolean keys where `false` is a valid explicit choice. This is a classic Lua footgun.

**How to avoid:**
Always use `if db.X == nil then db.X = DEFAULT end` for backfill. Every new key added to the DB schema in v1.0.0 must follow this pattern. The existing backfill code (Core.lua:62-89) already does this correctly — new keys must follow the same template. Never use `or` shorthand in backfill code.

**Warning signs:**
- Any backfill line that reads `db.X = db.X or VALUE`.
- After upgrade QA: existing user had `listenChannels.RAID = false`, after reload RAID is re-enabled.
- After upgrade QA: existing user had `window.locked = false` (intentionally unlocked), after reload window is locked.

**Phase to address:**
Defaults change phase. Code review gate: grep `\.lua` files for `db\.[a-z]* = db\.[a-z]* or` and flag every match.

---

### Pitfall DB-2: Changing defaults in the fresh-DB block silently resets existing users' channel choices

**What goes wrong:**
The v0.1.0 defaults block (Core.lua:34-52) initializes `TerribleLuraHelperDB` if it is nil. For the v1.0.0 defaults change (SAY-only instead of all-channels-on), the defaults block must change. BUT: the backfill loop that runs for existing users (Core.lua:61-65) currently backfills all missing channels to `true`. If v1.0.0 changes only the fresh-DB defaults (SAY=true, others=false) but keeps the backfill loop at `db.listenChannels[ch] = true` for nil entries, then:
- Existing users (already have all channels set) → unchanged (correct).
- New users → get SAY=true, others=false from the defaults block (correct).
- BUT: a user who clears their SavedVariables and reloads gets the new defaults (correct).

The dangerous case: a user who was on v0.1.0 and had RAID=true, who then deletes only `db.listenChannels.SAY` from their SavedVariables (edge case), would get SAY=true from backfill — which matches the old default. This is actually fine. The real danger is the opposite: if the defaults block is changed to SAY-only but the backfill loop is ALSO changed to default false for RAID, existing users who had RAID enabled would have it turned off on the next `/reload`. This is a destructive upgrade.

**How to avoid:**
For v1.0.0 defaults change: change ONLY the fresh-DB defaults block (the `if not TerribleLuraHelperDB then` block). Do NOT change the backfill loop. Existing users' channel settings are already written in their SavedVariables; the backfill only fires for keys that are `nil` (absent from SavedVariables), not for keys set to `false` or `true`. The correct v1.0.0 backfill behavior for `macroChannel`: `if db.macroChannel == nil then db.macroChannel = "SAY" end` — this only applies to fresh installs where `macroChannel` was never set. Users who already have `macroChannel = "RAID"` keep their choice.

**Warning signs:**
- Backfill loop changed to use a new default value (e.g., `db.listenChannels[ch] = false` for non-SAY channels).
- QA upgrade path: create a fresh `TerribleLuraHelperDB` with all channels true, simulate v0.1.0→v1.0.0 upgrade by adding the new backfill logic, verify no channels change.

**Phase to address:**
Defaults change phase. The fresh-DB block and the backfill loop are the two code points to touch; they must be touched independently and deliberately.

---

### Pitfall AH-1: PLAYER_REGEN_ENABLED may fire on initial login — auto-hide-in-combat window-show may trigger at startup

**What goes wrong:**
`PLAYER_REGEN_ENABLED` fires when the player leaves combat. In normal play this is the standard "combat ended" signal. However, `PLAYER_REGEN_ENABLED` can also fire on initial login if the player logs in while not in combat — the game emits it during the world-entry sequence to signal that the regen system is "enabled" from a cold start. If the auto-hide-in-combat feature registers a `PLAYER_REGEN_ENABLED` listener and that listener calls `win:Show()` or `applySoftHideState()`, it may fire at startup when:
- The window is hidden (db.window.visible = false, the default).
- The sequence is empty.
- autoHide is true.

Result: the handler fires, sees "we are out of combat and autoHide is true and window was visible," and may call `win:Show()` on a window that should be hidden at startup.

**Why it happens:**
`PLAYER_REGEN_ENABLED` semantics include "regen is now active" not just "combat just ended." The distinction matters at login. Many addon developers assume REGEN events only fire at combat transitions.

**How to avoid:**
Guard the `PLAYER_REGEN_ENABLED` handler for the auto-hide feature with a check that the window is actually shown before acting: `if not win:IsShown() then return end`. Additionally, only take action if there was a prior `PLAYER_REGEN_DISABLED` in the same session (track `inCombat = false` as a module-local, set it to `true` on `PLAYER_REGEN_DISABLED`, set it to `false` on `PLAYER_REGEN_ENABLED`; only apply auto-hide logic in `PLAYER_REGEN_ENABLED` if `inCombat` was `true`).

**Warning signs:**
- On `/reload` with window hidden and autoHide=true: window appears briefly or shows immediately at startup.
- `PLAYER_REGEN_ENABLED` handler that does not check prior `PLAYER_REGEN_DISABLED` in the same session.

**Phase to address:**
Auto-hide-in-combat reframe phase. The `inCombat` tracking local must be initialized false and only set true on `PLAYER_REGEN_DISABLED`.

---

### Pitfall AH-2: Auto-hide-in-combat toggled while in combat — should it apply immediately or at next combat boundary?

**What goes wrong:**
The user opens the Settings panel during combat (Settings panel is accessible during combat), toggles "Auto hide when empty in combat" from off to on. The toggle's `SetValueChangedCallback` fires `ns:OnAutoHideChanged(true)`. Currently `ns:OnAutoHideChanged` calls `applySoftHideState()`, which checks `autoHide AND #sequence == 0` and may soft-hide the window immediately via `win:SetAlpha(0)`. Soft-hide during combat is fine (it's just alpha change on a non-secure frame). However, if the new behavior is "hide while in combat when empty," and the window is shown and empty (waiting for rune macros), immediately hiding it mid-combat is correct behavior. The pitfall is the reverse: turning the toggle OFF mid-combat should re-show a soft-hidden window immediately. If `ns:OnAutoHideChanged(false)` calls `applySoftHideState()`, the current logic exits soft-hide and restores alpha — this is correct. No additional combat guard needed.

BUT: if the new auto-hide-in-combat reframe involves `PLAYER_REGEN_DISABLED` calling `win:Hide()` (actual Hide, not soft-hide), then toggling autoHide off mid-combat while the window is `Hide()`-n requires calling `win:Show()` immediately in `OnAutoHideChanged`. If the window is hard-hidden and autoHide is turned off in combat, the change-callback must call `win:Show()` for users to see the window. This depends on implementation choice: soft-hide (alpha) vs hard-hide (Hide/Show).

**How to avoid:**
Decide once whether the auto-hide-in-combat reframe uses soft-hide (alpha=0, same as current) or hard-hide (Hide/Show). Given the existing soft-hide model is load-bearing for chat-event registration (AMEND-01: OnHide unregisters chat events), hard-hide in combat is problematic — if the window is hard-hidden, chat events unregister, and the next macro press (the very event we're waiting for) is not received. Therefore: **the auto-hide-in-combat reframe MUST use the existing soft-hide model** (alpha=0) rather than hard-hide. Changing to hard-hide breaks AMEND-01.

**Warning signs:**
- Auto-hide-in-combat implementation calls `win:Hide()` directly instead of `win:SetAlpha(0)`.
- After combat with auto-hide-in-combat on: pressing a TLH macro produces a chat message but the window does not appear (because chat events were unregistered by the Hide call).

**Phase to address:**
Auto-hide-in-combat reframe phase. Architectural gate: decide soft-hide vs hard-hide FIRST. The correct answer given AMEND-01 is soft-hide.

---

### Pitfall AH-3: M+ trash-chain combat flicker causes rapid show/hide cycles on the soft-hidden window

**What goes wrong:**
In Mythic+ dungeons, trash packs cause rapid `PLAYER_REGEN_DISABLED` → `PLAYER_REGEN_ENABLED` → `PLAYER_REGEN_DISABLED` cycles between pulls (sometimes under 5 seconds between packs). If the auto-hide-in-combat reframe triggers `applySoftHideState()` on each combat transition with the window empty, the alpha flips 0→1→0→1 repeatedly. This is visible as a flicker if the alpha transitions are instantaneous. Additionally, the inactivity timer (`ClearAll` after 20s) may fire mid-combat, causing a `ClearAll` → `applySoftHideState` → alpha=0 mid-combat; then `PLAYER_REGEN_ENABLED` fires (trash pack dead) → alpha=1; then immediately `PLAYER_REGEN_DISABLED` (next pack) → alpha=0 again.

For users who do not want to see the window between trash pulls (autoHide=true), this is correct. For users who use TLH for raid encounters only, M+ usage is not the target scenario.

**How to avoid:**
No code change required — the flicker is correct behavior for the feature. The risk is user perception: the window visibly flashes between pulls. Document in the UI tooltip that "auto hide in combat" means the window will appear briefly between trash pulls in dungeons if there was a sequence displayed. Optionally add a minimum-visible-time delay (debounce on the alpha-restore path), but this is probably YAGNI for v1.0.0.

**Warning signs:**
- QA in a Mythic+ dungeon: pull a pack, let them die, immediately pull another — observe if the window flickers.
- This is expected behavior not a bug, but worth noting in QA notes.

**Phase to address:**
Auto-hide-in-combat reframe phase. Document in tooltip, no code change. Flag as known behavior.

---

### Pitfall AH-4: PLAYER_REGEN_DISABLED fires while window is being dragged (unlocked) — window should not abruptly auto-hide

**What goes wrong:**
The user is repositioning the window (drag in progress) and combat starts (`PLAYER_REGEN_DISABLED` fires). If the auto-hide-in-combat handler immediately applies `win:SetAlpha(0)` (soft-hide), the frame being dragged becomes invisible mid-drag. The user has no visual feedback that the drag is still in progress. When they release the mouse, `OnDragStop` fires and `persistPosition()` saves the position — but the window is invisible. This is surprising behavior.

**How to avoid:**
In the `PLAYER_REGEN_DISABLED` handler for auto-hide-in-combat, guard: `if win:IsMouseButtonDown("LeftButton") then return end` — if a drag is in progress, do not apply soft-hide. The drag will complete on mouseup, `OnDragStop` saves the position, and the next `applySoftHideState` evaluation (e.g., on the next `FillSlot` or manual call) will apply the combat-hide. Alternatively, accept the behavior (the window going invisible mid-drag is rare and not dangerous), but the former is a better UX.

**Warning signs:**
- QA: start dragging the window, have a friend /duel you or pull a mob to enter combat mid-drag — window disappears while still being positioned.

**Phase to address:**
Auto-hide-in-combat reframe phase. One-line guard in the REGEN_DISABLED handler.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Single-slot notify hook (`ns.onWindowShownChanged = fn`) | Simple, no framework wiring | If a second subscriber ever needed, pattern breaks | v1.0.0 only — one subscriber exists |
| Soft-hide via alpha instead of tracking in-combat state separately | Reuses existing applySoftHideState | Cannot distinguish "soft-hidden because in-combat" vs "soft-hidden because empty out of combat" without an additional flag | Acceptable if behavior is identical; fragile if they need to diverge |
| Hardcoded texture path string | Simple | Case-sensitivity bug on Linux/macOS game clients (Windows is case-insensitive) | Acceptable for Windows-only WoW (WoW is Windows/Mac; Midnight is Windows only for this user) |
| Omitting `InCombatLockdown()` guard on `applyLockState` | Simpler code | Potential protected-function error during combat on non-plain frames | Never acceptable — must guard |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|-----------------|
| BigWigs Packager + PNG textures | Add PNG to repo, assume it ships | Remove `"*.png"` from `.pkgmeta` ignore, or use TGA format which is not in the ignore list |
| BigWigs Packager + TGA textures | Incorrect extension in `.pkgmeta` | TGA not in ignore list — ships by default. Verify with test release ZIP |
| Settings API `buttonText` function | Assume function is called on every click | Function is called only in `SettingsButtonControlMixin:Init`, which fires on panel open. Live updates require custom notify approach |
| Settings panel custom frame (texture) | Create Frame inside `Init` callback | Create once at addon init; the panel's initializer positions a pre-existing frame |
| `db.X = db.X or DEFAULT` backfill | Works for string/number keys | Fails silently for boolean-false keys (Lua: `false or default` → `default`) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Notify hook called on every `applySoftHideState` evaluation | If autoHide=on, `applySoftHideState` fires on every chat message (via FillSlot → applySoftHideState). If the hook does heavy work, this fires up to 5 times per combat per L'ura encounter. | Restrict hook to actual state changes only: fire only when `win:IsShown()` changes, not on every alpha-update | If notify hook includes any work beyond `Button:SetText` |
| RegisterForDrag called on every `applyLockState` call | Minor — `RegisterForDrag` is a cheap call | No change needed | Never a performance issue for this frame count |
| PLAYER_REGEN events driving per-frame decisions | PLAYER_REGEN fires at most once per combat segment — not per-frame | Safe as-is | N/A |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Click-through with no visual indicator | User doesn't know window is locked and why clicks pass through. They try to interact with the window, nothing responds, they think the addon is broken. | Ensure `lockBtn` is hidden (already done) and consider a subtle "LOCKED" text or frame tint when in locked state — but v1.0.0 spec says clean look when locked, so no indicator is correct per spec. Document in `/lura help` that "Locked = click-through." |
| Auto-hide-in-combat: window invisible while waiting for macros to be pressed | User enters combat, window is empty and invisible (autoHide=on). They have no confirmation the addon is "ready." They may think the addon is disabled. | This is by design for users who want minimal screen real estate. Tooltip must clearly explain the semantics. |
| Dynamic label stale on soft-hide | Button says "Hide window" when window is alpha=0 (soft-hidden). LO-05 from Phase 3 review — not fixed in v1.0.0. | Known wart; acceptable. Document in v1.1 backlog. |
| Defaults change: SAY-only on fresh install, existing users see no change | User who installed v0.1.0 had all channels on; their friends install fresh and get only SAY. Same toggle, different behavior — confusing if they compare notes. | Correct behavior per spec. Only communication gap — document in CHANGELOG. |

## "Looks Done But Isn't" Checklist

- [ ] **Click-through:** `EnableMouse(false)` called on parent `win` AND confirmed no child frames have independent `EnableMouse(true)` — verify with mouse-click QA on each slot position.
- [ ] **Click-through:** `applyLockState` has `InCombatLockdown()` guard with PLAYER_REGEN_ENABLED retry armed.
- [ ] **Texture in panel:** Release ZIP (from `release.bat` or a test tag) unzipped and the texture file is present inside the addon folder.
- [ ] **Texture in panel:** `SetTexture` path string verified in-game (not just `install.bat` — also from a release ZIP install).
- [ ] **Dynamic label:** Notify hook has corresponding cleanup (either single-slot overwrite pattern or `cbrHandles` integration). Verify by: open panel, press Show/Hide button, close panel, re-open panel — confirm label matches current state.
- [ ] **Dynamic label:** All six visibility-change paths tested: `/lura`, `/lura show`, `/lura hide`, `/lura lock`/`unlock` (does NOT change window visibility — label unchanged), panel button, 20s inactivity clear (does NOT change IsShown — label unchanged unless new combat-path changes it).
- [ ] **Defaults change:** Upgrade path tested: create `TerribleLuraHelperDB` with all channels=true and macroChannel="RAID", run new backfill code, verify no existing values changed.
- [ ] **Defaults change:** Fresh install tested: delete `TerribleLuraHelperDB`, reload, verify SAY=true, all other channels=false, macroChannel="SAY".
- [ ] **Auto-hide-in-combat:** Verified that `PLAYER_REGEN_DISABLED` does NOT trigger soft-hide while window is visible and non-empty (sequence has items).
- [ ] **Auto-hide-in-combat:** Verified that auto-hide uses soft-hide (alpha=0), NOT hard-hide (`win:Hide()`). Chat events remain registered throughout.
- [ ] **Hard constraints:** grep across all new code: zero `SendChatMessage`, zero string ops on `msg`, zero `COMBAT_LOG_EVENT_UNFILTERED`, zero `win:Hide()` from any new combat-state path (only `win:SetAlpha`).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| TX-1: PNG excluded from package | MEDIUM | Update `.pkgmeta`, re-tag release, CurseForge/Wago update usually propagates within 1 hour |
| CT-1: Child frames still clickable | LOW | Add `EnableMouse(false)` loop to `applyLockState`, re-release |
| DB-2: Existing users' channels reset | HIGH | Cannot restore SavedVariables retroactively. Only mitigation: print a warning on upgrade "Your channel settings were reset — please re-enable your preferred channels in /lura config." Requires a schema version bump to detect upgrade. |
| AH-2: Hard-hide used instead of soft-hide | MEDIUM | Replace `win:Hide()` calls in combat handler with `win:SetAlpha(0)` / `softHidden = true`, re-release. User symptom: macros pressed in combat but window doesn't appear. Easy to reproduce and diagnose. |
| DL-1: Notify hook leak | LOW | Replace with single-slot overwrite or EventRegistry pattern; no user-visible symptom (memory leak only, slow accumulation) |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| CT-1: EnableMouse not cascading | Click-through implementation | QA: click each slot position while locked; confirm world click-through |
| CT-2: In-progress drag not stopped on lock | Click-through implementation | QA: drag + `/lura lock` simultaneously |
| CT-3: Protected function during combat | Click-through implementation | QA: `/lura lock` during live combat |
| TX-1: PNG excluded from package | Asset pipeline (before any texture code) | Unzip release artifact and verify file presence |
| TX-2: FileDataID vs path string | Asset pipeline | In-game: texture renders correctly on a CurseForge-installed copy |
| TX-3: Texture created in Init callback | Asset pipeline / texture-in-panel implementation | Rapid panel open/close: no flicker |
| DL-1: Notify hook leak | Dynamic label implementation | Open+close panel 10x; no orphaned callbacks |
| DL-2: Notify hook taint risk | Dynamic label implementation | Boss-fight smoke test: no taint errors after sequence fill |
| DL-3: Missing visibility-change path | Dynamic label implementation | Verify all 6 paths update label |
| DB-1: `or` backfill clobbers false | Defaults change | Code review grep; upgrade QA |
| DB-2: Backfill loop changed destructively | Defaults change | Upgrade QA with existing DB fixture |
| AH-1: PLAYER_REGEN_ENABLED on login | Auto-hide-in-combat implementation | `/reload` with window hidden + autoHide=on: window stays hidden |
| AH-2: Hard-hide breaks chat events | Auto-hide-in-combat implementation | Press macro in combat with autoHide=on: window appears |
| AH-3: M+ flicker | Auto-hide-in-combat implementation | M+ dungeon QA: expected behavior, not a bug |
| AH-4: Drag mid-combat soft-hide | Auto-hide-in-combat implementation | Drag + enter combat simultaneously |

## Sources

- `wow-ui-source@12.0.1` — `Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua` lines 821-836 (EnableMouse cascade behavior, confirmed per-frame not inherited)
- `wow-ui-source@12.0.1` — `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua` lines 72-81 (`EnableMouse` is `IsProtectedFunction = true`)
- `wow-ui-source@12.0.1` — `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua` lines 702-720 (`EvaluateName` called only in `Init`; `cbrHandles:Unregister` in `Release` for lifecycle cleanup)
- `TerribleLuraHelper/.pkgmeta` — `"*.png"` in ignore list confirmed (current file, reviewed 2026-05-09)
- `TerribleLuraHelper/Window.lua` — `applySoftHideState`, `OnShow`/`OnHide` event gating (AMEND-01 constraint, confirmed load-bearing)
- `TerribleLuraHelper/Core.lua` — backfill pattern using `== nil` check (lines 62-89, confirmed correct)
- `02-REVIEW.md` — WR-01 (nil-guard for ns.db in combat frame handlers), Phase 2 constraint checklist
- `03-REVIEW.md` — IN-01 (EvaluateName Init-only refresh), LO-05 (soft-hide IsWindowShown wart), ME-04 (applySoftHideState on hidden frame), HI-01 (frame leak in retry pattern)

---
*Pitfalls research for: TerribleLuraHelper v1.0.0 polish features*
*Researched: 2026-05-09*
