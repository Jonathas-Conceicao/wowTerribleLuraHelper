# Phase 7: Verbose-Marker Toggle - Pattern Map

**Mapped:** 2026-05-15
**Files analyzed:** 3 modified (no new files)
**Analogs found:** 5 / 5 (every change has a same-file analog in v1.0.0 code)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `Macros.lua` (table modification) | config-data | transform | `Macros.lua:17-23` (existing `MACROS` table) | exact (modify-in-place) |
| `Macros.lua` (payload selection in `RegisterMacros`) | utility | transform | `Macros.lua:55-66` (existing `RegisterMacros` for-loop) | exact (one-line conditional inside existing loop) |
| `Macros.lua` (new `ns:OnVerboseMarkersChanged`) | event-callback | request-response | `Macros.lua:134-144` (`ns:OnMacroChannelChanged`) | exact (mirror structure verbatim) |
| `Config.lua` (new "Use verbose markers" checkbox) | config-ui | request-response | `Config.lua:161-180` (Auto-hide checkbox) — Boolean shape; also `Config.lua:317-329` (macro-channel dropdown) — callback shape | exact (Boolean checkbox is structurally closest) |
| `Core.lua` (default `verboseMarkers = true`) | config-data | request-response | `Core.lua:65` (`macroChannel = "SAY",` inline default) | exact (one-line addition to literal table) |
| `Core.lua` (backfill `db.verboseMarkers`) | config-data | request-response | `Core.lua:101-103` (`if db.macroChannel == nil then db.macroChannel = "SAY" end`) | exact (verbatim idiom, different key/default) |

## Pattern Assignments

### Modification 1 — `Macros.lua:17-23` — Dual-field `MACROS` table

**Analog (verbatim, current code):**
```lua
-- Macros.lua:17-23
local MACROS = {
    { name = "TLH_Diamond", payload = "{rt3}", icon = 137003 },
    { name = "TLH_Triangle", payload = "{rt4}", icon = 137004 },
    { name = "TLH_Circle", payload = "{rt2}", icon = 137002 },
    { name = "TLH_Cross", payload = "{rt7}", icon = 137007 },
    { name = "TLH_T", payload = "T", icon = 137001 },
}
```

**Target shape (per CONTEXT D-01):**
```lua
local MACROS = {
    { name = "TLH_Diamond",  payloadVerbose = "{diamond}",  payloadRT = "{rt3}", icon = 137003 },
    { name = "TLH_Triangle", payloadVerbose = "{triangle}", payloadRT = "{rt4}", icon = 137004 },
    { name = "TLH_Circle",   payloadVerbose = "{circle}",   payloadRT = "{rt2}", icon = 137002 },
    { name = "TLH_Cross",    payloadVerbose = "{cross}",    payloadRT = "{rt7}", icon = 137007 },
    { name = "TLH_T",        payload = "T",                                       icon = 137001 },
}
```

**Patterns to preserve:**
- Indentation: tabs (current file is stylua-formatted with tabs).
- Field-order convention: `name` first, payload field(s) middle, `icon` last.
- `TLH_T`'s single `payload` field stays as-is (no verbose variant — encodes the L'ura-encounter-specific irregularity self-documenting).
- A comment above the table explaining the dual-shape is recommended but not load-bearing (CONTEXT specifics §3).

---

### Modification 2 — `Macros.lua:55-66` — Payload selection conditional

**Analog (verbatim, current code):**
```lua
-- Macros.lua:55-66 (inside RegisterMacros)
for _, m in ipairs(MACROS) do
    local body = prefix .. " " .. m.payload
    local idx = GetMacroIndexByName(m.name)
    if idx == 0 then
        if CreateMacro(m.name, m.icon, body, false) then
            created = created + 1
        end
    else
        EditMacro(idx, m.name, m.icon, body)
        updated = updated + 1
    end
end
```

**Target change (per CONTEXT D-02):** Replace the `local body = prefix .. " " .. m.payload` line with the inline-conditional pair:
```lua
local payload = m.payload or (ns.db.verboseMarkers and m.payloadVerbose or m.payloadRT)
local body = prefix .. " " .. payload
```

**Patterns to preserve:**
- The for-loop body around it (lines 57-65) is UNCHANGED.
- Tab indentation is one level deeper than the `for` line.
- Direct read of `ns.db.verboseMarkers` (no helper); matches CHANNEL_PREFIX pattern at line 53 (`CHANNEL_PREFIX[ns.db.macroChannel]` — also a direct read).
- Lua `or` semantics: `m.payload` for `TLH_T` short-circuits to `"T"`; the four marker rows have `m.payload == nil` and fall through to the verbose/RT choice.
- This is a READ expression — no `= db.` assignment — so the SAFE-06 grep gate (`git grep "= db\." | grep " or "`) does NOT match.

---

### Modification 3 — `Macros.lua` (append after line 144) — New `ns:OnVerboseMarkersChanged`

**Analog (verbatim, current code at Macros.lua:130-144):**
```lua
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

**Target shape (per CONTEXT D-09 + D-10):**
```lua
-- Phase 7 / CFG-16. The checkbox's SetValueChangedCallback fires this after
-- the framework has already written db.verboseMarkers = value. We just re-run
-- RegisterMacros, which re-reads db.verboseMarkers via the payload-selection
-- conditional. Combat-lockdown deferral routes through the shared regen frame.
function ns:OnVerboseMarkersChanged(value)
    if InCombatLockdown() then
        ns:RegisterMacros() -- sets registrationDeferred=true via the early-return
        armRegenRetry()
        print(
            string.format(
                "|cffaa44ffTLH|r: Verbose markers %s. Macros will update when you leave combat.",
                value and "on" or "off"
            )
        )
    else
        ns:RegisterMacros()
        print(
            string.format(
                "|cffaa44ffTLH|r: Verbose markers %s. Macros updated.",
                value and "on" or "off"
            )
        )
    end
end
```

**Patterns to preserve (load-bearing):**
- Function naming: `ns:On*Changed(value)` — established by `OnAutoHideChanged` and `OnMacroChannelChanged`.
- Combat branch order: in-combat first (sets `registrationDeferred`, arms retry), else branch second.
- `ns:RegisterMacros()` call appears in BOTH branches — the in-combat call deliberately runs to take the early-return at `Macros.lua:46-49` that sets `registrationDeferred = true` (do NOT skip it).
- `armRegenRetry()` reused unchanged from line 96-98 — no new combat-deferral machinery.
- `|cffaa44ffTLH|r:` chat-print color prefix (canonical across all three files).
- No arrow (`→`) in the print — CONTEXT D-10 explicitly notes the dropdown uses one because it shows a target value (`→ /s`); the boolean toggle's "on/off" doesn't need an arrow.
- `value and "on" or "off"` ternary inline at both call sites — CONTEXT specifics §"Claude's Discretion" recommends NO helper extraction.

**Patterns to deliberately diverge from:**
- The dropdown's analog reads `CHANNEL_PREFIX[value]` to display the target. The checkbox doesn't need this — `value` itself (bool) is consumed directly via `value and "on" or "off"`.

---

### Modification 4 — `Config.lua` (insert between line 344 and line 345) — "Use verbose markers" checkbox

**Primary analog — `Config.lua:161-180` (Auto-hide checkbox, structurally closest as Boolean checkbox):**
```lua
-- (2c) Auto-hide checkbox — UI-SPEC §3.4
do
    local setting = Settings.RegisterAddOnSetting(
        category,
        "TLH_AUTO_HIDE",
        "autoHide",
        db.window,
        Settings.VarType.Boolean,
        "Auto-hide",
        false
    )
    setting:SetValueChangedCallback(function(_, value)
        ns:OnAutoHideChanged(value)
    end)
    Settings.CreateCheckbox(
        category,
        setting,
        "When on, the helper window stays visible while you're out of combat so you remember the toggle is on. In combat, it hides while the rune sequence is empty and reappears automatically when the next marker arrives."
    )
end
```

**Secondary analog — `Config.lua:316-344` (macro-channel dropdown, structurally closest as sibling Macros-section control):**
```lua
-- (3a) Macro target dropdown — UI-SPEC §4.5.2
do
    local setting = Settings.RegisterAddOnSetting(
        category,
        "TLH_MACRO_CHANNEL",
        "macroChannel",
        db,
        Settings.VarType.String,
        "Macro target",
        "SAY"
    )
    setting:SetValueChangedCallback(function(_, value)
        ns:OnMacroChannelChanged(value)
    end)
    -- ... GenerateMacroChannelOptions + Settings.CreateDropdown ...
end
```

**Target shape (per CONTEXT D-04 + D-08, combining both analogs):**
```lua
-- (3aa) Verbose-marker toggle. Inserted between (3a) channel dropdown and
-- (3b) Recreate button — same Macros section, same Settings.* API, but
-- Boolean+Checkbox instead of String+Dropdown.
do
    local setting = Settings.RegisterAddOnSetting(
        category,
        "TLH_VERBOSE_MARKERS",
        "verboseMarkers",
        db,
        Settings.VarType.Boolean,
        "Use verbose markers",
        true
    )
    setting:SetValueChangedCallback(function(_, value)
        ns:OnVerboseMarkersChanged(value)
    end)
    Settings.CreateCheckbox(
        category,
        setting,
        "When on, macros emit {diamond} / {triangle} / {circle} / {cross} — these render correctly in more chat addons than the older {rt3} / {rt4} / {rt2} / {rt7} codes. Turn off only if your chat addon doesn't expand the verbose names. The 5th macro (TLH_T) sends the letter T either way."
    )
end
```

**Patterns to preserve (load-bearing):**
- `do ... end` block wrapping the entire control init — established by every (2X) and (3X) control in Config.lua.
- Section-comment label `-- (3aa) ...` — the numeric+letter scheme matches the existing `(3a)/(3b)/(3c)` scheme. Insertion is between `(3a)` (line 316) and `(3b)` (line 346).
- `db` (not `db.window`) — CONTEXT D-07 specifies `db.verboseMarkers` is top-level on `db`, NOT nested under `db.window` like Auto-hide's `db.window.autoHide`. The dropdown analog at line 322 uses `db` (top-level) — that's the correct parent for the verbose toggle.
- Variable name: `TLH_VERBOSE_MARKERS` (uppercase + `TLH_` prefix per established `TLH_AUTO_HIDE`, `TLH_MACRO_CHANNEL` convention).
- DB field name: `verboseMarkers` (camelCase per established `autoHide`, `macroChannel`).
- Default: `true` (matches SCAF-18 and CONTEXT D-12; framework's `SecureSetVariableTblDefaultValue` will idempotently backfill this in addition to Core.lua's nil-check — confirmed safe in RESEARCH Q3).
- `setting:SetValueChangedCallback(function(_, value) ns:OnVerboseMarkersChanged(value) end)` — IDENTICAL shape to the dropdown's line 327-329. Framework auto-writes `db.verboseMarkers` BEFORE this callback fires (Phase 3 invariant T-03-02) — the callback only calls into Macros.lua to apply the new value; do NOT manually write `db.verboseMarkers` here.
- Tooltip passed as the third positional arg to `Settings.CreateCheckbox` — single inline string, no explicit line-wrap, no helper extraction (Auto-hide's tooltip at line 178 is also a single inline string; RESEARCH note A confirms framework wraps).
- No sentinel-flag hook needed — checkbox auto-syncs via `OnSettingValueChanged` (RESEARCH Q4 verified in wow-ui-source). Do NOT add `_tlhVerboseCheckbox` flag or `ns:RefreshVerboseMarkersCheckbox()` function.

**Insertion site (exact):** between line 344 (closing `end` of the `(3a)` dropdown block) and line 346 (the `-- (3b) Recreate / update macros button — UI-SPEC §4.2 / §4.5.3.` comment).

---

### Modification 5 — `Core.lua:47-67` — Fresh-install default

**Analog (verbatim, current code):**
```lua
-- Core.lua:47-67
if not TerribleLuraHelperDB then
    TerribleLuraHelperDB = {
        listenChannels = {
            SAY = true,
            -- ...
        },
        window = {
            scale = 1.00,
            locked = false,
            autoHide = false,
            position = nil,
            alpha = 1.00,
            visible = false,
        },
        macroChannel = "SAY",
    }
end
```

**Target change (per CONTEXT D-12):** Add one line `verboseMarkers = true,` immediately after the `macroChannel = "SAY",` line (current line 65). New structure:
```lua
macroChannel = "SAY",
verboseMarkers = true,
```

**Patterns to preserve:**
- Tab indentation, one level deeper than `TerribleLuraHelperDB = {`.
- Trailing comma on the new line (matches every other entry in the table).
- Top-level placement on `TerribleLuraHelperDB` (not nested under `window` or any other sub-table — CONTEXT D-07 specifies no `db.macros` namespace).
- Camel-case key naming (`verboseMarkers`) — matches `macroChannel`, `autoHide` convention.

---

### Modification 6 — `Core.lua:101-103` — Nil-check backfill

**Analog (verbatim, current code):**
```lua
-- Core.lua:101-103
if db.macroChannel == nil then
    db.macroChannel = "SAY"
end
```

**Target shape (per CONTEXT D-13):** Add an identically-shaped block immediately after the `macroChannel` backfill:
```lua
if db.macroChannel == nil then
    db.macroChannel = "SAY"
end
if db.verboseMarkers == nil then
    db.verboseMarkers = true
end
```

**Patterns to preserve (load-bearing — SAFE-06 invariant):**
- Idiom is `if X == nil then X = default end` — NEVER `X = X or default` (would clobber explicit `false`; PITFALLS DB-1). This is enforced by the D-16 #5 grep gate `git grep "= db\." -- '*.lua' | grep " or "` which MUST remain zero-match after this phase.
- Three-line block (if / assignment / end), no inlined one-liner — matches every other backfill in the `Core.lua:70-103` block.
- Tab indentation at function-body level.
- Variable name match: `db.verboseMarkers` (the same SavedVar field the Config.lua control binds to).
- Default value match: `true` — same value as the fresh-install default at modification 5, same value as the Settings.RegisterAddOnSetting default at modification 4. Triple-defense, all idempotent (RESEARCH Q3 confirms framework's `SecureSetVariableTblDefaultValue` uses the identical idiom).

**Insertion site (exact):** after current line 103 (closing `end` of the `macroChannel` backfill), before current line 105 (the dispatch-to-per-module-init comment).

---

## Shared Patterns

### Print-feedback color prefix
**Source:** `|cffaa44ffTLH|r:` literal across `Macros.lua:70, 139, 142`, `Config.lua:353, 358, 377, 382, 384`, `Core.lua:122, 135, 141, 147, 182, 191`.
**Apply to:** All four new chat-print strings in `ns:OnVerboseMarkersChanged` (modification 3).
```lua
print("|cffaa44ffTLH|r: ...")
```

### `do ... end` block per control in `RegisterMacroSection`
**Source:** `Config.lua:317-344` (`(3a)` dropdown), `Config.lua:349-368` (`(3b)` Recreate), `Config.lua:374-395` (`(3c)` Delete), and `Config.lua:162-180`/`186-210`/`216-245` for the section-2 controls.
**Apply to:** The new `(3aa)` checkbox block in modification 4. Wrap the entire setting+callback+createCheckbox triplet in `do ... end`.

### `-- (NX) <label>` section-comment marker
**Source:** Section-2 controls labeled `(2a)`, `(2b)`, `(2c)`, `(2d)`, `(2e)`; Section-3 controls labeled `(3a)`, `(3b)`, `(3c)`.
**Apply to:** New checkbox in modification 4 uses `-- (3aa) Verbose-marker toggle. ...` — the two-letter `3aa` suffix encodes "inserted between (3a) and (3b)" without disturbing the existing (3b)/(3c) labels (which would otherwise need renumbering).

### `Settings.RegisterAddOnSetting` + `SetValueChangedCallback` + `Settings.CreateXxx`
**Source:** Used by every settings-bound control in `Config.lua` (auto-hide checkbox lines 162-180; macro-channel dropdown lines 318-343).
**Apply to:** New checkbox in modification 4. Framework writes `db[key]` automatically before callback fires (Phase 3 / T-03-02 invariant — NEVER write the DB manually from the callback).

### `if X == nil then X = default end` backfill (SAFE-06)
**Source:** Every backfill in `Core.lua:70-103` (`listenChannels` keys, `window.scale`, `window.locked`, `window.autoHide`, `window.alpha`, `window.visible`, `macroChannel`).
**Apply to:** New `verboseMarkers` backfill in modification 6.
**Enforced by:** D-16 #5 UAT grep gate.

### `registrationDeferred` flag + `armRegenRetry()` for combat-deferred work
**Source:** `Macros.lua:40, 46-49, 86-98`. Combat-blocked work sets the flag, calls `armRegenRetry()`, returns. On `PLAYER_REGEN_ENABLED`, the shared `regenFrame` consumes the flag and re-runs `RegisterMacros`.
**Apply to:** New `ns:OnVerboseMarkersChanged` in modification 3 — reuse the existing machinery unchanged; no new flag, no new frame, no new event registration.
**Idempotency guarantee:** `RegisterEvent` on an already-registered event is a no-op; the handler unregisters on fire. Rapid-toggle is safe (RESEARCH Q5 walks through the scenario).

### `ns:On*Changed(value)` function naming for Settings change callbacks
**Source:** `ns:OnAutoHideChanged` (Window.lua), `ns:OnMacroChannelChanged` (Macros.lua:134).
**Apply to:** New `ns:OnVerboseMarkersChanged` in modification 3. Lives in `Macros.lua` (it's a macro-state function; CONTEXT specifics §"Claude's Discretion" confirms — parallel to `OnMacroChannelChanged`).

### `TLH_*` uppercase setting name for `Settings.RegisterAddOnSetting`
**Source:** `TLH_AUTO_HIDE` (Config.lua:165), `TLH_MACRO_CHANNEL` (Config.lua:320), plus all section-2 settings.
**Apply to:** New setting `TLH_VERBOSE_MARKERS` in modification 4.

---

## No Analog Found

None. All six modifications have at least one same-file analog. Phase 7 is a pure pattern-mirroring phase — no new techniques, no new APIs, no new architectural surface.

---

## Metadata

**Analog search scope:** `Macros.lua`, `Config.lua`, `Core.lua` (the three files Phase 7 modifies).
**Files scanned:** 3.
**Pattern extraction date:** 2026-05-15.
**Confidence:** HIGH — every analog is in the same file as the modification, with line-numbered citations.

## PATTERN MAPPING COMPLETE
