# Phase 8: Zone-Aware Auto Show/Hide - Pattern Map

**Mapped:** 2026-05-16
**Files analyzed:** 1 modified (`Core.lua`), 0 created
**Analogs found:** 6 / 6 (every new addition has a same-file or sibling-file analog)

---

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `Core.lua` (additive — new top-level block) | event dispatcher / namespace function | event-driven (zone events → world-state query → branch → call existing primitives) | `Macros.lua:86-100` (`regenFrame` permanent listener) + `Core.lua:23-27` (`eventFrame` registration shape) | exact (same pattern, same file family) |

**Scope summary:** Phase 8 is the smallest phase in the milestone — one additive block in `Core.lua`:
1. File-scope constant `LURA_RAID_INSTANCE_ID` (numeric literal, placeholder per RESEARCH two-track approach).
2. Optional file-scope debug flag `DEBUG_ZONE_INFO = false`.
3. New permanent `zoneFrame` (CreateFrame + 2x RegisterEvent + SetScript).
4. New exported handler `function ns:OnZoneChanged()`.

Zero new files. Zero modifications to `Window.lua`, `Macros.lua`, `Config.lua`, or `TerribleLuraHelper.toc`. The handler calls `ns:ShowWindow()` / `ns:HideWindow()` (Window.lua:441-458) as terminal actions without modifying them.

---

## Pattern Assignments

### `Core.lua` — additive top-level block (event listener + handler)

**Analog 1: Permanent event-listener frame** (`Macros.lua:86-100` — `regenFrame`)

This is the closest structural analog. `regenFrame` is a permanent listener (registered once at file scope, never unregisters its registration — only the per-event subscription cycles). The new `zoneFrame` follows the same shape: top-level `local zoneFrame = CreateFrame("Frame")` at file scope, `RegisterEvent` calls, `SetScript("OnEvent", ...)` with a small dispatcher.

```lua
-- Macros.lua:86-100 (verbatim, for shape reference)
-- Single shared retry frame. Reused by every code path that needs a
-- "deferred until combat ends" hook (initial load + every dropdown change).
-- Calling armRegenRetry repeatedly is idempotent — RegisterEvent on the
-- same event is a no-op when already registered. The handler always
-- unregisters after firing so the frame stays cold between deferrals.
local regenFrame = CreateFrame("Frame")
regenFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if registrationDeferred then
            ns:RegisterMacros()
        end
    end
end)
```

**What to copy from this analog:**
- File-scope `local frameName = CreateFrame("Frame")` declaration (no parent, no template).
- Comment block immediately above the frame explaining purpose + lifecycle.
- `SetScript("OnEvent", function(self, event, ...) ... end)` inline closure pattern.
- The closure captures `ns` from the upvalue chain (file-scope `local _, ns = ...`).

**What differs for `zoneFrame`:**
- `zoneFrame` registers TWO events (`PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`) instead of one.
- `zoneFrame` NEVER unregisters (vs. `regenFrame` which unregisters after fire — but only because regen retry is one-shot per deferral; the *frame* itself persists). Phase 8's zone listener is fully permanent.
- The OnEvent body does NOT branch on `event` (per RESEARCH D-07: handler is idempotent, runs the same body for both events).

---

**Analog 2: Event registration sequence** (`Core.lua:23-27` — `eventFrame`)

Same file. Established pattern at the top of `Core.lua`. The shape `CreateFrame → RegisterEvent → SetScript` is verbatim what `zoneFrame` follows.

```lua
-- Core.lua:23-27 (verbatim, for shape reference)
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        ...
```

**What to copy:**
- Two adjacent `:RegisterEvent("EVENT_NAME")` calls before `SetScript` — this matches the planned two-event registration for `zoneFrame`.
- The inline `SetScript("OnEvent", function(self, event, ...) ... end)` shape with three positional captures.
- File-scope placement (NOT inside a function).

**What differs:**
- `eventFrame` is one-shot per event (unregisters after handling). `zoneFrame` is permanent — no `self:UnregisterEvent(...)` call.
- `eventFrame` branches on `event == "..."`. `zoneFrame` does NOT (single code path).

---

**Analog 3: `ns:On*Changed()` exported handler** (`Macros.lua:140-150` — `OnMacroChannelChanged`; `Macros.lua:157-171` — `OnVerboseMarkersChanged`)

The verb-prefix `ns:On<Subject>Changed()` is established convention across the codebase. Three existing instances (`OnAutoHideChanged`, `OnMacroChannelChanged`, `OnVerboseMarkersChanged`). `ns:OnZoneChanged()` follows the same convention.

```lua
-- Macros.lua:140-150 (verbatim, for shape reference — closest in structure)
-- Phase 3 / CFG-11. The dropdown's SetValueChangedCallback fires this after
-- the framework has already written db.macroChannel = value. We just re-run
-- RegisterMacros, which re-reads db.macroChannel via the CHANNEL_PREFIX
-- lookup. Combat-lockdown deferral routes through the shared regen frame.
function ns:OnMacroChannelChanged(value)
    local prefix = CHANNEL_PREFIX[value] or "/raid"
    if InCombatLockdown() then
        ns:RegisterMacros() -- sets registrationDeferred=true via the early-return
        armRegenRetry()
        print("|cffaa44ffTLH|r: Macro target → " .. prefix .. ". Macros will update when you leave combat.")
    else
        ns:RegisterMacros()
        print("|cffaa44ffTLH|r: Macro target → " .. prefix .. ". Macros updated.")
    end
end
```

**What to copy from this analog:**
- `function ns:OnXChanged(...)` declaration (exported via the `ns` namespace table).
- Multi-line docstring comment block immediately above the function, citing Phase + REQ-ID.
- Query world state → branch → dispatch-to-primitive structure (the analog: `InCombatLockdown()` → branch → call `ns:RegisterMacros()`; the Phase 8 mirror: `IsInInstance()` + `GetInstanceInfo()` → branch → call `ns:ShowWindow()` / `ns:HideWindow()`).

**What differs for `OnZoneChanged`:**
- Takes NO arguments (zone handler queries world state directly; nothing is passed from `SetScript("OnEvent", ...)`).
- Does NOT print on every fire (CONTEXT D-10 — auto-fires are silent). The `|cffaa44ffTLH|r:` prefix appears ONLY if the optional `DEBUG_ZONE_INFO` block is enabled and uses a `TLH-DEBUG` variant prefix (RESEARCH §Q6).
- Does NOT touch any `db.*` directly — `ns:ShowWindow()` / `ns:HideWindow()` write `db.window.visible` (Window.lua:450, 456).

---

**Analog 4: File-scope numeric constants for stable Blizzard IDs** (`Macros.lua:17-28` — `MACROS` table with FileDataID literals)

```lua
-- Macros.lua:17-28 (verbatim, for shape reference)
-- Phase 7 / MACR-06, MACR-07. The four marker rows have BOTH payloadVerbose
-- and payloadRT; RegisterMacros picks one via db.verboseMarkers. TLH_T uses
-- a single `payload` field — its rune is the literal letter T (the 5th
-- L'ura rune), not a marker icon, so no verbose variant exists. The
-- single-vs-dual-field shape per row self-documents this irregularity.
local MACROS = {
    { name = "TLH_Diamond", payloadVerbose = "{diamond}", payloadRT = "{rt3}", icon = 137003 },
    { name = "TLH_Triangle", payloadVerbose = "{triangle}", payloadRT = "{rt4}", icon = 137004 },
    { name = "TLH_Circle", payloadVerbose = "{circle}", payloadRT = "{rt2}", icon = 137002 },
    { name = "TLH_Cross", payloadVerbose = "{cross}", payloadRT = "{rt7}", icon = 137007 },
    { name = "TLH_T", payload = "T", icon = 137001 },
}
```

**What to copy:**
- Numeric Blizzard-stable IDs as bare integer literals (`137001`, `137002`, etc. — `LURA_RAID_INSTANCE_ID` follows the same shape: bare integer, no string-quoted, no expression).
- File-scope `local` declaration (top of file, near other module-level constants).
- All-caps name for the constant (matches `LISTEN_DEFAULTS`, `CHANNEL_PREFIX`, `MACROS`, `CHAT_EVENTS` precedent across all three Lua files).
- Multi-line comment block above the constant citing REQ-ID + rationale.

**Phase 8 specifics (per RESEARCH §Q1 two-track):**
- Initial value is a sentinel placeholder: `local LURA_RAID_INSTANCE_ID = 0`. Zero will never match a real raid instanceID (which are always positive — Wowpedia samples: 2657, 2549, 2569). The sentinel makes the TODO visible to code reviewers and makes the placeholder safe-by-default (no zone matches → window never auto-shows → no regression of `/lura show`).
- A TODO comment must call out the placeholder status and reference the UAT capture step.

---

**Analog 5: Optional debug-print flag (no exact in-codebase analog — standard Lua idiom)**

No existing TerribleLuraHelper file uses a `DEBUG = false` gate. This pattern is new infrastructure introduced specifically by the RESEARCH two-track approach. The closest precedent is `Macros.lua:42` (`local macrosPrintedThisSession = false`) — a file-scope `local` boolean flag — and the chat-print color prefix convention from existing prints.

```lua
-- Macros.lua:42 (verbatim, for the file-scope boolean flag shape)
-- Once-per-session flag for the "drag macros to your action bar" hint.
local macrosPrintedThisSession = false
```

```lua
-- Existing chat-print color-prefix convention (used in Core.lua:126, 186, 195
-- and Macros.lua:74, 145, 148, 161, 169 — gold ID, gold command, colored hint)
print("|cffaa44ffTLH|r: ...")
print("|cffaa44ffTerribleLuraHelper|r loaded.")
```

**What to copy when adding the debug block:**
- File-scope `local DEBUG_ZONE_INFO = false` declaration with one-line comment explaining purpose and lifecycle (flip true for UAT capture, flip false before release tag).
- All debug prints use the established color prefix, but with a **`TLH-DEBUG`** variant (per RESEARCH §Q6 sample) so debug output is visually distinct from real user-facing prints:
  ```lua
  print(string.format("|cffaa44ffTLH-DEBUG|r PEW: init=%s reload=%s inst=%s map=%s type=%s",
      tostring(isInitialLogin), tostring(isReloadingUi),
      tostring(instanceID), tostring(mapID), instanceType))
  ```
- Single-line `if DEBUG_ZONE_INFO then print(...) end` gate inside the OnEvent body (zero overhead when flag is false).

**Phase 8 specifics:**
- Per CONTEXT D-11, the debug block is OPTIONAL — planner's discretion. RESEARCH §Q1 recommends YES for the v1.1.0 dev cycle (captures live instanceID in one UAT pass instead of requiring a separate `/dump` step). Final call lives in the plan.
- If included, the block MUST default to `DEBUG_ZONE_INFO = false` in the committed code.

---

**Analog 6: Handler body skeleton — query → check → dispatch** (refined from CONTEXT D-08 by RESEARCH §Q3)

The architectural pivot in RESEARCH §Q3 replaces `C_Map.GetBestMapForUnit("player")` (uiMapID) with `GetInstanceInfo()` (instanceID) + `IsInInstance()` short-circuit. The closest in-codebase analog for the "query world state → branch → dispatch to primitive" structure is `OnMacroChannelChanged` (Analog 3) — but the *query* shape is novel because Phase 8 is the first handler to read instance/zone info.

```lua
-- RESEARCH §Q3 / D-08 refined handler body (verbatim from RESEARCH.md:137-153)
function ns:OnZoneChanged()
    -- IsInInstance is the fast-path negative check — avoids unpacking
    -- GetInstanceInfo() for the common case (player in outdoor world).
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "raid" then
        ns:HideWindow()
        return
    end
    local instanceID = select(8, GetInstanceInfo())
    if instanceID == LURA_RAID_INSTANCE_ID then
        ns:ShowWindow()
    else
        ns:HideWindow()
    end
end
```

**What this preserves from in-codebase analogs:**
- Top-of-function world-state read via Blizzard untainted getters (same shape as `Macros.lua:51` `if InCombatLockdown() then ... end`).
- Early-return on the negative case (mirrors `Macros.lua:52-54` early-return on combat-blocked).
- Terminal dispatch to existing `ns:` exported primitives (mirrors `OnMacroChannelChanged` calling `ns:RegisterMacros()`).
- No `db.*` writes inside the handler — all `db` mutation happens inside the called primitives (`ns:ShowWindow()` writes `db.window.visible = true`, `ns:HideWindow()` writes `false`).

**What is novel:**
- First handler in the addon to call `IsInInstance()` and `GetInstanceInfo()`. These are documented safe (RESEARCH §Q7: no combat lockdown, no taint, plain untainted getters). No existing pattern to mirror, but no risk either.
- First handler to use `select(8, GetInstanceInfo())` multi-return pattern. Standard Lua idiom.

---

**Terminal call sites — NOT modified** (`Window.lua:441-458`)

The handler's only outputs are calls to these existing functions. Phase 8 does NOT modify them. Listed here so the executor can read (read-only) to confirm what each does:

```lua
-- Window.lua:441-458 (verbatim, for read-only reference — DO NOT MODIFY)
function ns:ShowWindow()
    applySavedPosition()
    win:Show()
    -- Phase 3 / D-20: explicit show always reveals — visibility is a UX
    -- confirmation that the addon is engaged. The next 20s self-clear may
    -- re-enter soft-hide via ClearAll → applySoftHideState() if autoHide=on.
    softHidden = false
    win:SetAlpha(ns.db.window.alpha or 1.00)
    -- Persist visibility so /reload restores the same state.
    ns.db.window.visible = true
    ns:NotifyWindowVisibilityChanged()
end

function ns:HideWindow()
    win:Hide()
    ns.db.window.visible = false
    ns:NotifyWindowVisibilityChanged()
end
```

**Why this matters for Phase 8:**
- `win:Show()` triggers `OnShow` (registers chat events — AMEND-01 invariant). Phase 8 routes through this — does NOT use `SetAlpha(0)` for the zone-leave case (SAFE-07).
- `win:Hide()` triggers `OnHide` (unregisters chat events + wipes sequence — AMEND-01 invariant).
- `ns:NotifyWindowVisibilityChanged()` is called automatically at the end of both — Phase 6 dynamic config-panel label refresh fires for free on every zone transition. No additional wiring needed in Phase 8.
- `db.window.visible` is written by Show/Hide directly. Phase 8's handler does NOT touch `db.window.visible`. Effectively `db.window.visible` becomes a transient cache of last-applied state inside the raid (CONTEXT D-13).

---

## Shared Patterns

### Pattern A: File-scope event-listener frame
**Sources:**
- `Core.lua:23-27` (`eventFrame`, one-shot ADDON_LOADED/PLAYER_LOGIN)
- `Macros.lua:92-100` (`regenFrame`, permanent listener; per-fire unregister)
- `Window.lua` (`combatFrame`, Phase 5 — permanent listener for PLAYER_REGEN_*; not re-quoted here)

**Apply to:** The new `zoneFrame` declaration in Phase 8.

**Canonical shape:**
```lua
local frameName = CreateFrame("Frame")
frameName:RegisterEvent("EVENT_NAME_1")
frameName:RegisterEvent("EVENT_NAME_2")  -- optional, multiple registrations allowed
frameName:SetScript("OnEvent", function(self, event, ...)
    -- handler body
end)
```

**Phase 8 instantiation:** `zoneFrame` registers `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA`; OnEvent body does NOT branch on `event` (single code path per CONTEXT D-07); permanent (no unregister); calls `ns:OnZoneChanged()`.

---

### Pattern B: Verb-prefix `ns:On*Changed()` exported handler
**Sources:**
- `Macros.lua:140-150` (`ns:OnMacroChannelChanged(value)`)
- `Macros.lua:157-171` (`ns:OnVerboseMarkersChanged(value)`)
- `Config.lua` (`ns:OnAutoHideChanged(value)` — Phase 4; not re-quoted here, follows same convention)

**Apply to:** `ns:OnZoneChanged()` in Phase 8.

**Canonical shape:**
```lua
-- Phase X / REQ-ID-NN. <One-paragraph rationale citing the triggering event
-- and what the handler does in response.>
function ns:OnXChanged(value)
    -- query world state
    -- branch
    -- dispatch to existing primitive
end
```

**Phase 8 instantiation:** Takes no arguments (no value passed from `SetScript("OnEvent", ...)`); queries world state via `IsInInstance()` + `GetInstanceInfo()`; dispatches to `ns:ShowWindow()` or `ns:HideWindow()`.

---

### Pattern C: File-scope numeric constants for stable Blizzard IDs
**Sources:**
- `Macros.lua:22-28` (`MACROS` table — icon FileDataIDs 137001..137007)
- `Core.lua:14-21` (`LISTEN_DEFAULTS` table — string keys, boolean values; precedent for top-of-file constant declarations)

**Apply to:** `LURA_RAID_INSTANCE_ID` constant in Phase 8.

**Canonical shape:**
```lua
-- <Multi-line comment block citing REQ-ID + rationale + lifecycle.>
local CONSTANT_NAME = <bare numeric literal>
```

**Phase 8 instantiation:** `local LURA_RAID_INSTANCE_ID = 0` (sentinel placeholder per RESEARCH §Q1 two-track); comment block must call out TODO status + reference UAT capture step.

---

### Pattern D: Chat-print color prefix (`|cffaa44ffTLH|r:`)
**Sources:**
- `Core.lua:126` (`print("|cffaa44ffTerribleLuraHelper|r loaded.")`)
- `Core.lua:186` (`print("|cffaa44ffTLH|r: settings not yet ready, ...")`)
- `Core.lua:195` (`print("|cffaa44ffTLH|r: unrecognized command. ...")`)
- `Macros.lua:74-80` (`print(string.format("|cffaa44ffTLH|r macros: %d created, %d updated. ...", ...))`)
- `Macros.lua:145, 148, 161, 169` (multiple `print("|cffaa44ffTLH|r: ...")`)

**Apply to:** ONLY the optional `DEBUG_ZONE_INFO` block in Phase 8 — and with a `TLH-DEBUG` variant prefix per RESEARCH §Q6.

**Phase 8 silence rule (CONTEXT D-10):** Zone-driven auto show/hide does NOT print on every fire. Auto-fires are silent by design. The chat-print prefix is mentioned here only because IF the debug block is included, it MUST use the established color convention (variant: `|cffaa44ffTLH-DEBUG|r`) to stay visually consistent with the rest of the addon.

---

### Pattern E: Permanent vs. one-shot listener
**Permanent listener (never unregisters):** `combatFrame` (Window.lua, Phase 5).
**One-shot listener (unregisters self after firing):** `eventFrame` (Core.lua:37, 128 — unregisters PLAYER_LOGIN and ADDON_LOADED after handling).
**Hybrid (frame is permanent; subscription cycles):** `regenFrame` (Macros.lua:95 — unregisters PLAYER_REGEN_ENABLED after each fire, re-registers via `armRegenRetry` on next combat deferral).

**Apply to:** Phase 8's `zoneFrame` is a **permanent listener** — closest analog is `combatFrame`. Subscription to both `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA` is set once at file scope and never cycled.

---

### Pattern F: Hard-constraint invariants (regression guard — applies to ALL phases)
**Sources:** `CLAUDE.md` §"Hard Constraints"; `.planning/PROJECT.md` Key Decisions; `08-CONTEXT.md` D-16.

**Apply to:** Phase 8 MUST NOT introduce:
- Any call to `SendChatMessage` (or other chat-emitting APIs).
- Any indexing of the `msg` argument from `CHAT_MSG_*` events (`:gsub`, `:match`, `#msg`, `msg[...]`, `..`, etc.).
- Any registration of `COMBAT_LOG_EVENT_UNFILTERED`.
- Any `SetAlpha(0)` substitution for the zone-leave case (SAFE-07 requires full `Hide()`).
- Any change to the AMEND-01 chat-event registration invariant (OnShow registers, OnHide unregisters — Phase 8 routes through `ns:Show/HideWindow()` which already preserves this).

**Regression diff guard (CONTEXT D-16):** `git diff -- '*.lua' | grep -E '^\+.*(SendChatMessage|:gsub|:match|#msg|msg\[)'` MUST return zero lines for the Phase 8 commit(s).

---

## No Analog Found

| Item | Reason | Mitigation |
|------|--------|------------|
| `IsInInstance()` + `select(8, GetInstanceInfo())` query pattern | First handler in the codebase to read instance/zone info from Blizzard APIs. No prior usage. | RESEARCH §Q3 + §Q7 confirm APIs are documented safe (untainted, no combat lockdown, plain getters). Pattern verified against Blizzard's own `Blizzard_WorldMap/MapTexturePreloader.lua` (full-file example in RESEARCH §Q5). |
| `DEBUG_ZONE_INFO = false` toggle pattern | No existing TerribleLuraHelper file uses a debug-flag gate. The closest precedent is `Macros.lua:42` (`macrosPrintedThisSession`) — a file-scope boolean flag used for a different purpose (once-per-session print gate). | Standard Lua idiom; planner adds at their discretion (CONTEXT D-11, RESEARCH §Q1 recommends YES). Block uses established `|cffaa44ff...|r` color convention with `TLH-DEBUG` variant prefix per RESEARCH §Q6. |

---

## Insertion Site

Per CONTEXT integration-points note: insert the new block in `Core.lua` **after** the existing `eventFrame` `SetScript` block (closes at line 130) and **before** the `function ns:PrintHelp()` declaration (line 138), OR at the very end of the file after the SlashCmdList assignments (line 207). Planner picks based on readability — recommend after the `eventFrame` block so all event-driven dispatchers are visually grouped at the top of the file.

Suggested ordering inside the new block:
1. File-scope debug flag (if planner opts in): `local DEBUG_ZONE_INFO = false`
2. File-scope constant: `local LURA_RAID_INSTANCE_ID = 0` (with TODO comment)
3. `function ns:OnZoneChanged() ... end`
4. `local zoneFrame = CreateFrame("Frame")` + 2x RegisterEvent + SetScript

This ordering follows the precedent in `Macros.lua` (constants → functions → frame setup) and ensures the OnEvent closure can reference `ns:OnZoneChanged` (lookup happens at call time via the `ns` table, so forward-reference would also work, but defining the function first is cleaner).

---

## Metadata

**Analog search scope:** `Core.lua`, `Macros.lua`, `Window.lua` (full project — only 4 Lua files; trivial to enumerate exhaustively).
**Files scanned:** 4 (`Core.lua`, `Macros.lua`, `Window.lua`, `Config.lua` — the addon's complete Lua surface).
**Pattern extraction date:** 2026-05-16

---

## PATTERN MAPPING COMPLETE
