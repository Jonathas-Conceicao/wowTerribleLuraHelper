# Phase 4: SAY Defaults + Click-Through - Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 2 modified files (no new files)
**Analogs found:** 4 / 4 (all patterns drawn from the same two files being modified)

---

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `Window.lua` | utility | request-response | `Window.lua:applyLockState` (lines 205-216) | exact — same function |
| `Core.lua` | config/init | CRUD | `Core.lua` ADDON_LOADED block (lines 33-89) | exact — same block |

---

## Pattern Assignments

### `Window.lua` — `applyLockState()` (WIN-11 / WIN-12)

**Change:** Add one `win:EnableMouse(not locked)` call inside `applyLockState`.

**Existing function** (`Window.lua` lines 205-216):
```lua
applyLockState = function()
	local locked = ns.db.window.locked
	if locked then
		win:SetMovable(false)
		win:RegisterForDrag()
		lockBtn:Hide()
	else
		win:SetMovable(true)
		win:RegisterForDrag("LeftButton")
		lockBtn:Show()
	end
end
```

**Pattern to follow — symmetry inside the existing if/else:**
Each branch already sets three properties symmetrically (`SetMovable`, `RegisterForDrag`, `lockBtn:Show/Hide`). Add `win:EnableMouse(false)` at the end of the `if locked` branch and `win:EnableMouse(true)` at the end of the `else` branch — matching the existing 3-line-per-branch shape exactly. Alternatively (per Claude's Discretion in CONTEXT.md D-64), a single line **after** the if/else is cleaner:

```lua
-- Clean single-line form (preferred — avoids duplicating the call):
win:EnableMouse(not locked)
```

Place this line immediately after the closing `end` of the if/else, before the function's own `end`. No combat-lockdown deferral — `EnableMouse` is unrestricted on plain `Frame` objects (D-04/D-05).

**Callers — zero changes needed.** `applyLockState` is already called from all four entry points:
- `CreateWindow` (line 174)
- `ns:ToggleLocked` (line 220)
- `ns:LockWindow` (line 265)
- `ns:UnlockWindow` (line 270)

---

### `Core.lua` — Fresh-install defaults block (SCAF-13 / SCAF-14)

**Change:** Update the literal `TerribleLuraHelperDB = { ... }` table (lines 33-53) so `listenChannels` defaults SAY to `true` and all other channels to `false`; `macroChannel` defaults to `"SAY"`.

**Existing fresh-install block** (`Core.lua` lines 33-53):
```lua
if not TerribleLuraHelperDB then
	TerribleLuraHelperDB = {
		listenChannels = {
			SAY = true,
			RAID = true,
			RAID_LEADER = true,
			RAID_WARNING = true,
			INSTANCE_CHAT = true,
			INSTANCE_CHAT_LEADER = true,
		},
		window = {
			scale = 1.00,
			locked = false,
			autoHide = false,
			position = nil,
			alpha = 1.00,
			visible = false,
		},
		macroChannel = "RAID",
	}
end
```

**Target shape after Phase 4** — only the values in `listenChannels` and `macroChannel` change; the block structure and `window` sub-table are untouched:
```lua
if not TerribleLuraHelperDB then
	TerribleLuraHelperDB = {
		listenChannels = {
			SAY = true,
			RAID = false,
			RAID_LEADER = false,
			RAID_WARNING = false,
			INSTANCE_CHAT = false,
			INSTANCE_CHAT_LEADER = false,
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

---

### `Core.lua` — `LISTEN_DEFAULTS` table + backfill loop (SCAF-15 / SAFE-06 / D-10)

**Change:** Replace the per-channel backfill loop (lines 61-65) with a `LISTEN_DEFAULTS`-driven loop. Add the `LISTEN_DEFAULTS` constant table near the top of `Core.lua`.

**Analog — Lua-local constant table pattern** from `Macros.lua` lines 17-23 and 29-34:
```lua
-- Macros.lua lines 17-23 (MACROS table)
local MACROS = {
	{ name = "TLH_Diamond", payload = "{rt3}", icon = 137003 },
	...
}

-- Macros.lua lines 29-34 (CHANNEL_PREFIX table)
local CHANNEL_PREFIX = {
	RAID = "/raid",
	RAID_WARNING = "/rw",
	INSTANCE_CHAT = "/i",
	SAY = "/s",
}
```

**Analog — constant table pattern** from `Window.lua` lines 26-41:
```lua
local SLOT_POS = {
	[1] = { 140, 55 },
	...
}

local CHAT_EVENTS = {
	"CHAT_MSG_SAY",
	"CHAT_MSG_RAID",
	...
}
```

**Target shape for `LISTEN_DEFAULTS`** — place as a file-level local near the top of `Core.lua`, before the `eventFrame` declaration, following the same `local NAME = { ... }` convention:
```lua
-- Per-channel defaults for fresh-install AND backfill (SCAF-13, SCAF-15, SAFE-06).
-- SAY=true is the v1.0.0 default; all other channels off until user opts in.
-- IMPORTANT: backfill MUST use `if db.X == nil then` — never `db.X = db.X or X`.
-- The `or` idiom silently clobbers explicit `false` values. See SAFE-06.
local LISTEN_DEFAULTS = {
	SAY = true,
	RAID = false,
	RAID_LEADER = false,
	RAID_WARNING = false,
	INSTANCE_CHAT = false,
	INSTANCE_CHAT_LEADER = false,
}
```

**Existing backfill loop** (`Core.lua` lines 61-65):
```lua
for _, ch in ipairs({ "SAY", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" }) do
	if db.listenChannels[ch] == nil then
		db.listenChannels[ch] = true
	end
end
```

**Target shape after Phase 4** — iterate over `LISTEN_DEFAULTS` using `pairs` (key-value, not positional); preserves the `== nil` guard unchanged:
```lua
for ch, default in pairs(LISTEN_DEFAULTS) do
	if db.listenChannels[ch] == nil then
		db.listenChannels[ch] = default
	end
end
```

---

### `Core.lua` — `macroChannel` backfill (SCAF-14 / D-11)

**Change:** Line 88 literal changes from `"RAID"` to `"SAY"`. The `if == nil` guard is unchanged — existing users' `db.macroChannel = "RAID"` is already set, so the nil-check is a no-op for them.

**Existing backfill** (`Core.lua` lines 87-89):
```lua
if db.macroChannel == nil then
	db.macroChannel = "RAID"
end
```

**Target shape:**
```lua
if db.macroChannel == nil then
	db.macroChannel = "SAY"
end
```

---

## Shared Patterns

### Backfill idiom (SAFE-06)
**Source:** `Core.lua` lines 69-89 — every single key uses `if db.X == nil then db.X = DEFAULT end`.
**Apply to:** Every default written in Phase 4.
**Anti-pattern to NEVER use:** `db.X = db.X or DEFAULT` — this silently clobbers `false` boolean values, turning an intentional "disabled" into the default. The `== nil` form is the only safe idiom for boolean-typed keys.

```lua
-- CORRECT (used throughout Core.lua):
if db.window.locked == nil then
	db.window.locked = false
end

-- WRONG — do not introduce this form anywhere:
-- db.window.locked = db.window.locked or false  -- clobbers explicit false
```

### Lua-local constant table at top of file
**Source:** `Macros.lua` lines 17-34; `Window.lua` lines 18-41.
**Apply to:** New `LISTEN_DEFAULTS` table in `Core.lua`.
**Convention:** `local NAME = { ... }` declared before any `CreateFrame` or function body. No global leakage. Keys match the exact string keys used in `db.listenChannels` and `CHAT_EVENTS`.

### Combat-lockdown deferral — NOT used in Phase 4
**Source:** `Macros.lua` lines 86-98 (`regenFrame` + `armRegenRetry`).
**Applicability:** `EnableMouse` does not require deferral on plain (non-protected) `Frame` objects. Do NOT add `InCombatLockdown()` guards or `armRegenRetry` calls to `applyLockState`. Reference this pattern for awareness only; it is deliberately excluded per D-04/D-05.

---

## No Analog Found

None. All Phase 4 changes extend existing patterns already present in the codebase. The planner should reference the excerpts above directly.

---

## Metadata

**Analog search scope:** `Core.lua`, `Window.lua`, `Macros.lua` (the entire addon source)
**Files read:** 3
**Pattern extraction date:** 2026-05-09
