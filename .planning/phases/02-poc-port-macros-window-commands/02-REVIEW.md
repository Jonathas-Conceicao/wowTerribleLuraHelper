---
phase: 02-poc-port-macros-window-commands
reviewed: 2026-04-30T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Core.lua
  - Macros.lua
  - Window.lua
  - Config.lua
findings:
  critical: 0
  warning: 1
  info: 6
  total: 7
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-04-30
**Depth:** standard (per-file Lua-aware analysis with cross-file constraint checks)
**Files Reviewed:** 4 (`Core.lua`, `Macros.lua`, `Window.lua`, `Config.lua`)
**Status:** issues_found (1 Warning, 6 Info — no Critical, no High, no Medium)

## Summary

Phase 2 is a clean, faithful port of the POC. All five hard taint constraints from `CLAUDE.md` are honored:

- **Zero `SendChatMessage` calls** anywhere in the addon (verified with project-wide grep).
- **Zero string operations on the `msg` argument** from any `CHAT_MSG_*` handler. The single `event:sub(10)` call in `Window.lua:260` operates on the **event name**, not `msg`, and the inline comment correctly notes this distinction. `msg` is passed opaquely from `OnEvent` straight into `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` (the Blizzard-secure helper) and from there into `slot.fs:SetText(processed)`.
- **No `COMBAT_LOG_EVENT_UNFILTERED`** registration anywhere.
- **No `ChatFrame_ReplaceIconAndGroupExpressions`** (the deprecated/non-namespaced alias). The modern `C_ChatInfo.ReplaceIconAndGroupExpressions` is the only path used.
- **`CreateMacro` / `EditMacro` are guarded by `InCombatLockdown()`** at `Macros.lua:33`, with a `PLAYER_REGEN_ENABLED` retry frame armed at `Macros.lua:69-78`.

Schema cleanup per D-27 was completed correctly: `db.sequence = {}` was removed from both the initial defaults table and the backfill loop in `Core.lua` (compared against the Phase 1 baseline at commit `bf11c3a`). The new `db.window.alpha` field was added per D-35 with both a default value and a backfill check.

`Config.lua` is byte-identical to the Phase 1 stub (verified via `git diff main..HEAD -- Config.lua` against the Phase 1 commit) — Phase 2 correctly leaves Phase 3 territory untouched.

The single Warning concerns a defensive nil-guard in the combat-state event frame that fires at file-load time. The Info items are all stylistic / dead-code observations; none affect correctness or safety.

## Warnings

### WR-01: `combatFrame` OnEvent reads `ns.db` and `ns:RegisterChatEvents` with no nil-guard

**File:** `Window.lua:297-310`
**Issue:**
The `combatFrame` is created and registers `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` at module-load time (i.e., during the .lua file's chunk execution, before `ADDON_LOADED` fires). Its handler reads `ns.db.enabled` directly:

```lua
combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if ns.db.enabled then              -- ns.db is nil until ADDON_LOADED fires
            ns:RegisterChatEvents()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns:UnregisterChatEvents()           -- safe (just iterates), but symmetric concern
    end
end)
```

In normal play this is fine because `ADDON_LOADED` fires before the player enters the world and before any `PLAYER_REGEN_*` event can occur. However:

1. The contract is fragile — any future change to the Phase 1 dispatcher that defers `ns.db` assignment (e.g., behind `EventUtil.ContinueOnAddOnLoaded` for the Settings panel) would re-order the assignment relative to combat events.
2. If a future Blizzard build changes event-ordering semantics or a UI reload happens with the player already in combat, the guard fails closed (no chat events register) but only after a `nil`-index error in chat. Better to fail silently.

This is a Warning rather than Critical because the realistic crash path is narrow, but the cost of the fix is one line.

**Fix:**

```lua
combatFrame:SetScript("OnEvent", function(self, event)
    if not ns.db then return end          -- ADDON_LOADED hasn't run yet
    if event == "PLAYER_REGEN_DISABLED" then
        if ns.db.enabled then
            ns:RegisterChatEvents()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns:UnregisterChatEvents()
    end
end)
```

The same defensive guard could be added to the `chatFrame` OnEvent at `Window.lua:257`, but `chatFrame` only receives `CHAT_MSG_*` events and those events are only registered from `ns:RegisterChatEvents()`, which is itself called from paths that already require `ns.db` to exist. So `chatFrame` is safe by construction; only `combatFrame` needs the guard.

## Info

### IN-01: `ns:OnRegenEnabled()` is unreachable / dead public surface

**File:** `Macros.lua:85-89`
**Issue:**
`ns:OnRegenEnabled()` is defined but never called. The retry path in `Macros.lua:69-78` creates its own internal `PLAYER_REGEN_ENABLED` listener that calls `ns:RegisterMacros()` directly. The inline comment ("currently unused; provided for module-API surface symmetry") acknowledges this, but the function still adds five lines of always-dead surface.

If the symmetry justification is the genuine driver, leave it. Otherwise removing it cuts noise without losing any caller.

**Fix:**
Either delete the function or — if Phase 3's "Recreate Macros" button (MACR-04) plans to reach for it — document that intent in the doc-comment ("Phase 3 will call this from the Recreate-Macros button") so the next reader knows it's reserved, not abandoned.

### IN-02: `ns:IsWindowShown()` is unreferenced

**File:** `Window.lua:336-338`
**Issue:**
The accessor is exported on `ns` but no current call site reads it. Same flavor of dead public surface as IN-01. Phase 3's auto-hide UI (CFG-09) might be the intended consumer, but Phase 2 doesn't wire it anywhere and the doc-comment doesn't mark it reserved.

**Fix:**
Add a one-line comment "Reserved for Phase 3 auto-hide / config-panel reads" or remove until needed.

### IN-03: Default position is set in two places (CreateWindow + applySavedPosition fallback)

**File:** `Window.lua:65` and `Window.lua:223`
**Issue:**
`CreateWindow` calls `win:SetPoint("CENTER", UIParent, "CENTER", 200, 80)` at line 65, and `applySavedPosition` does the same when `db.window.position` is nil at line 223. The first SetPoint is a stopgap for the brief window between frame creation and the first `ShowWindow` call; once `applySavedPosition` runs (either with a saved point or the default fallback), `ClearAllPoints` discards whatever line 65 set. So line 65 is functionally a one-frame placeholder.

Not a bug — the frame is `:Hide()`-ed immediately after, so the placeholder is invisible. Mostly a clarity issue: the magic-number tuple `(200, 80)` lives in two places. If a v2 ever changes the default offset, both copies must be updated together.

**Fix:**
Promote the default position to a named local at module scope and reference it from both call sites:

```lua
local DEFAULT_POSITION = { "CENTER", "UIParent", "CENTER", 200, 80 }
-- and use it via win:SetPoint(unpack(DEFAULT_POSITION))
```

### IN-04: CloseButton `OnClick` bypasses `ns:HideWindow` / `ns:Disable`

**File:** `Window.lua:77-81`
**Issue:**
The template's `CloseButton` script is overridden to call `win:Hide()` directly. Per D-24 / UI-SPEC §3.5 this is intentional — closing the X does not wipe the sequence or flip `db.enabled`. The result is a state where `db.enabled == true` but the window is hidden; combat events still register and the sequence still updates in memory. `/lura show` brings the window back populated.

This matches the spec, but the asymmetry between "close-X" and "/lura hide" is non-obvious and there is no tooltip or visual cue distinguishing the two. Worth a one-line comment on the `OnClick` handler so the next reader doesn't "fix" it by routing through `ns:HideWindow` (which today does the same thing — but coupling them invites a future refactor that breaks the spec).

**Fix:**

```lua
win.CloseButton:SetScript("OnClick", function()
    -- D-24 / UI-SPEC §3.5: close-X hides only; does NOT disable processing
    -- or wipe the sequence. Use /lura hide for full disable.
    win:Hide()
end)
```

### IN-05: Slash command discards trailing arguments without warning

**File:** `Core.lua:129`
**Issue:**
`local cmd = (rawArg or ""):lower():match("^%s*(%S*)") or ""` extracts only the first whitespace-bounded token. Anything after is silently dropped. So `/lura show foo` runs the show path with no feedback that `foo` was unrecognized. Mirrors POC behavior, but the POC's surface was smaller. Now that we have `help` and may add more, a stricter parse helps users self-correct typos.

Low priority — current behavior matches POC and there are only four valid subcommands, so the failure mode is narrow.

**Fix:**
Optional. If desired, capture the rest of the line and warn on non-empty trailing content:

```lua
local cmd, rest = rawArg:lower():match("^%s*(%S*)%s*(.-)%s*$")
-- ... after dispatch, if rest ~= "" and cmd ~= "" then print extra-arg warning
```

### IN-06: `MACROS` constant in `Macros.lua` would benefit from a brief icon-FileDataID source comment

**File:** `Macros.lua:15-21`
**Issue:**
The five icon FileDataIDs (`137003`, `137004`, `137002`, `137007`, `137001`) are correct (verified against POC line 43-47), but a future maintainer hitting this table cold has no breadcrumb to the wow-ui-source / wago tools they were looked up in. The "T borrows {rt1}" comment is great; the icon IDs deserve a similar one-liner.

**Fix:**
Add one comment line above the table:

```lua
-- Icon FileDataIDs are Blizzard built-in raid markers (rt1..rt8 → 137001..137008).
-- See wow-ui-source/Interface/AddOns/Blizzard_TargetFrame for the canonical list.
local MACROS = { ... }
```

---

## Constraint Checklist (CLAUDE.md hard constraints)

| Constraint | Status | Evidence |
|------------|--------|----------|
| Zero `SendChatMessage` calls | PASS | `grep -r SendChatMessage *.lua` → 0 matches |
| Zero string ops on `msg` from `CHAT_MSG_*` | PASS | `Window.lua:265` passes `msg` opaquely; `event:sub(10)` operates on event name (commented at line 258-259) |
| No `COMBAT_LOG_EVENT_UNFILTERED` | PASS | `grep -r COMBAT_LOG_EVENT_UNFILTERED *.lua` → 0 matches |
| No deprecated `ChatFrame_ReplaceIconAndGroupExpressions` | PASS | Only `C_ChatInfo.ReplaceIconAndGroupExpressions` at `Window.lua:265` |
| `CreateMacro` / `EditMacro` guarded by `InCombatLockdown` + retry | PASS | `Macros.lua:33` early-return + `Macros.lua:69-78` `PLAYER_REGEN_ENABLED` retry frame |
| Chat events registered only while enabled AND in combat | PASS | `Window.lua:300-310` (combat gate) + `Window.lua:303` (`db.enabled` check) + D-23 mid-combat path at `Window.lua:320-322` |
| No `db.sequence` (per D-27) | PASS | Removed from defaults table and backfill loop in `Core.lua` (verified vs. Phase 1 baseline `bf11c3a`) |
| Sequence is in-memory only | PASS | `Window.lua:43` — `local sequence = {}` is a module-local Lua table, never written to `ns.db` |
| `db.window.alpha` default + backfill (D-35) | PASS | Defaults at `Core.lua:35`, backfill at `Core.lua:69-71`, applied at `Window.lua:69` |
| 20s inactivity timeout (D-28) | PASS | `Window.lua:15` — `INACTIVITY_TIMEOUT = 20` |

## POC Deviation Audit

| Deviation | Spec Source | Status in Phase 2 |
|-----------|-------------|-------------------|
| BackdropTemplate dropped → `BasicFrameTemplateWithInset` | D-17 | `Window.lua:58` |
| Hidden by default on every login/reload | D-25 / WIN-04 | `Window.lua:62` |
| Sequence in-memory only | D-27 | `Window.lua:43` (module-local, no DB write) |
| 15s → 20s timeout | D-28 | `Window.lua:15` |
| `/lura show/hide` gates processing (not just visibility) | D-23 / D-24 | `Core.lua:95-106`, `Window.lua:300-310` |
| `/lura clear` dropped | CMD-04 dropped | Confirmed not in dispatcher |
| `/lura help` added | CMD-07 | `Core.lua:108-116`, `Core.lua:134` |
| `/tlh` full alias | CMD-06 / D-26 | `Core.lua:152, 156-158` |
| Channel filter via `db.listenChannels[event:sub(10)]` | D-31 | `Window.lua:260` |
| Chat handler does NOT call `win:Show()` | D-25 / WIN-04 | `Window.lua:277` (commented out, intentionally absent) |
| Lock button left of CloseButton | D-14 | `Window.lua:84-90` |
| Window scale + alpha applied at creation | D-36 | `Window.lua:68-69` |

All documented Phase 2 deviations from the POC are present and correct.

## Out-of-Scope Confirmations

- `Config.lua` is byte-identical to the Phase 1 stub. Phase 3 territory untouched. PASS.
- No live scale-slider update logic in Phase 2 (Phase 3 / CFG-04). PASS.
- No live alpha-slider update logic in Phase 2 (Phase 3 / CFG-10). PASS.
- No auto-hide-when-empty hook (Phase 3 / CFG-09). PASS.
- No "Recreate Macros" button UI (Phase 3 / MACR-04). The `ns:RegisterMacros()` callable is exposed on `ns` so Phase 3 can wire it; this is correct prep, not premature implementation. PASS.

---

_Reviewed: 2026-04-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
