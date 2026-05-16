# Phase 7: Verbose-Marker Toggle - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

A new `db.verboseMarkers` boolean (default `true`) controls whether the four marker macros emit verbose tokens or the original `{rt#}` payloads:

| Macro          | Verbose (default ON) | Fallback (OFF — `{rt#}`) |
|----------------|----------------------|--------------------------|
| `TLH_Diamond`  | `{diamond}`          | `{rt3}`                  |
| `TLH_Triangle` | `{triangle}`         | `{rt4}`                  |
| `TLH_Circle`   | `{circle}`           | `{rt2}`                  |
| `TLH_Cross`    | `{cross}`            | `{rt7}`                  |
| `TLH_T`        | literal `T`          | literal `T` (unchanged)  |

A new "Use verbose markers" checkbox in the config panel (Options > AddOns > TerribleLuraHelper) wraps the setting. Flipping it rebuilds the four marker macros in place via the existing `ns:RegisterMacros()` path, with combat-lockdown deferral via the existing `regenFrame` (Macros.lua:86-98) — same pattern as `OnMacroChannelChanged`.

Phase 7 covers 5 requirements:
- **MACR-06** — Verbose-token payloads when toggle is on
- **MACR-07** — `{rt#}` fallback payloads when toggle is off
- **CFG-15** — Checkbox in the config panel under Options > AddOns
- **CFG-16** — Toggle change rebuilds macros (with combat deferral) and prints feedback
- **SCAF-18** — First-run default `db.verboseMarkers = true` with SAFE-06-compliant nil-check backfill

What this phase explicitly does NOT touch:
- Zone-change event handling (Phase 8)
- `TLH_T` macro behavior (locked: still sends literal "T")
- Chat-event pipeline (`msg` handling — permanent OOS per CLAUDE.md taint constraints)
- Window.lua / Config.lua sections unrelated to the Macros section
- The Recreate / Delete macro buttons' user-facing behavior (they continue working; they already read current `db.*` state, so they pick up the new toggle automatically without any code change)

</domain>

<decisions>
## Implementation Decisions

### Macro payload table shape (MACR-06, MACR-07) — Claude's Discretion

- **D-01:** Modify the existing `MACROS` table in `Macros.lua:17-23` to dual-field-per-row. The four marker macros gain `payloadVerbose` + `payloadRT` fields; `TLH_T` keeps its single `payload` field (no verbose variant). Recommended shape:
  ```lua
  local MACROS = {
      { name = "TLH_Diamond",  payloadVerbose = "{diamond}",  payloadRT = "{rt3}", icon = 137003 },
      { name = "TLH_Triangle", payloadVerbose = "{triangle}", payloadRT = "{rt4}", icon = 137004 },
      { name = "TLH_Circle",   payloadVerbose = "{circle}",   payloadRT = "{rt2}", icon = 137002 },
      { name = "TLH_Cross",    payloadVerbose = "{cross}",    payloadRT = "{rt7}", icon = 137007 },
      { name = "TLH_T",        payload = "T",                                       icon = 137001 },
  }
  ```
  Rationale: minimal divergence from the existing structure — same per-row record, just with the payload split into two named alternatives for the four marker macros. `TLH_T`'s presence as the single-field outlier is self-documenting (a comment above the table can call out the irregularity).

- **D-02:** Payload selection in `RegisterMacros` uses an inline conditional that handles both shapes:
  ```lua
  local payload = m.payload or (ns.db.verboseMarkers and m.payloadVerbose or m.payloadRT)
  local body = prefix .. " " .. payload
  ```
  `m.payload` short-circuits for `TLH_T` (always literal "T"). For the four marker macros, the verbose-vs-rt# choice falls through to `db.verboseMarkers`. No new helper functions; one line of logic.

- **D-03:** Rejected alternatives (captured for traceability):
  - Single `payload` table with `{ verbose = ..., rt = ... }` — adds unnecessary nesting; doesn't simplify the conditional.
  - Two parallel lookup tables (`PAYLOADS_VERBOSE`, `PAYLOADS_RT`) keyed by macro name — splits payload data from the rest of the record; adding a new macro would require touching multiple tables; error-prone.
  - Builder function per macro — over-engineered for a binary string choice.

### Config panel placement & copy (CFG-15) — Claude's Discretion

- **D-04:** Toggle position: in the Macros section of the config panel, immediately AFTER the macro-target dropdown (3a) and BEFORE the Recreate button (3b). Specifically: inside `RegisterMacroSection` in `Config.lua:313`, add the new control as section (3aa) between the existing (3a) and (3b) blocks. Rationale: the toggle directly affects what the macros emit — same conceptual neighborhood as the channel dropdown. Grouping all macro-config controls together preserves the existing panel mental model.

- **D-05:** Toggle label: **"Use verbose markers"**.
  - Verb-prefix matches the existing panel convention ("Auto-hide", "Lock window", "Recreate", "Delete").
  - "Use" framing makes the default-ON state read as positive ("yes, use these"), not as a workaround.
  - "Verbose markers" is the term used in the user-facing milestone framing; consistent with the requirements doc.

- **D-06:** Toggle tooltip: **"When on, macros emit `{diamond}` / `{triangle}` / `{circle}` / `{cross}` — these render correctly in more chat addons than the older `{rt3}` / `{rt4}` / `{rt2}` / `{rt7}` codes. Turn off only if your chat addon doesn't expand the verbose names. The 5th macro (TLH_T) sends the letter T either way."`
  - States what changes (the four marker macros, with the actual tokens shown).
  - Names the WHY at one line (addon-compatibility) without lecturing.
  - Calls out the TLH_T exception so users aren't surprised when it doesn't flip.
  - Implicitly tells the user when to flip it off ("if your chat addon doesn't expand the verbose names").

- **D-07:** Variable name follows the Phase 3 convention (uppercase scope prefix + descriptive suffix): `TLH_VERBOSE_MARKERS`. SavedVar field: `verboseMarkers` (top-level on `db`, not nested under `db.macros` — there's no `db.macros` namespace today; introducing one for a single boolean would be over-engineering).

- **D-08:** Settings registration mirrors the existing macro-channel-dropdown pattern from `Config.lua:318-329`:
  ```lua
  local setting = Settings.RegisterAddOnSetting(
      category,
      "TLH_VERBOSE_MARKERS",
      "verboseMarkers",
      db,
      Settings.VarType.Boolean,
      "Use verbose markers",
      true   -- default; matches SCAF-18
  )
  setting:SetValueChangedCallback(function(_, value)
      ns:OnVerboseMarkersChanged(value)
  end)
  Settings.CreateCheckbox(category, setting, "<tooltip from D-06>")
  ```
  Framework auto-writes `db.verboseMarkers` on every change (Phase 3 / D-04 pattern). The callback only calls into Macros.lua to apply the new value — never writes `db.verboseMarkers` directly (threat T-03-02 / Phase 3).

### Toggle-change behavior (CFG-16) — Claude's Discretion

- **D-09:** New exported function in `Macros.lua`: `ns:OnVerboseMarkersChanged(value)`. Mirrors the structure of the existing `ns:OnMacroChannelChanged(value)` at `Macros.lua:134-144`. Body:
  ```lua
  function ns:OnVerboseMarkersChanged(value)
      if InCombatLockdown() then
          ns:RegisterMacros() -- sets registrationDeferred=true via the early-return
          armRegenRetry()
          print(string.format(
              "|cffaa44ffTLH|r: Verbose markers %s. Macros will update when you leave combat.",
              value and "on" or "off"
          ))
      else
          ns:RegisterMacros()
          print(string.format(
              "|cffaa44ffTLH|r: Verbose markers %s. Macros updated.",
              value and "on" or "off"
          ))
      end
  end
  ```
  Notes:
  - The `value` arg comes from the Settings framework's `SetValueChangedCallback` — by the time the callback fires, `db.verboseMarkers` is already written (framework writes before notify). So `ns:RegisterMacros()` reads the new value via `ns.db.verboseMarkers` inside the conditional from D-02; no need to pass `value` further.
  - The function name `OnVerboseMarkersChanged` mirrors `OnMacroChannelChanged` and `OnAutoHideChanged` (verb-prefix "On*Changed" — already established as the panel-callback convention).
  - `armRegenRetry()` is the existing helper at `Macros.lua:96-98`; reuse, don't re-implement.

- **D-10:** Print-feedback wording — confirmed copy:
  - ON, immediate (out of combat): `TLH: Verbose markers on. Macros updated.`
  - OFF, immediate (out of combat): `TLH: Verbose markers off. Macros updated.`
  - ON, deferred (in combat): `TLH: Verbose markers on. Macros will update when you leave combat.`
  - OFF, deferred (in combat): `TLH: Verbose markers off. Macros will update when you leave combat.`
  - All four use the existing `|cffaa44ffTLH|r:` color prefix (Macros.lua / Config.lua pattern).
  - No arrow (`→`) — the macro-channel dropdown uses one because it shows a target value (`→ /s`); the boolean toggle's "on/off" doesn't need an arrow.

- **D-11:** The drag-to-bar hint (`macrosPrintedThisSession` flag in `Macros.lua:37`) stays suppressed during toggle-driven rebuilds. The existing flag-gate in `RegisterMacros` (Macros.lua:67-76) already handles this: after the first session-load print, subsequent calls to `RegisterMacros` (channel change, toggle change, Recreate button) skip the hint. No additional code needed.

### Default + backfill (SCAF-18) — Claude's Discretion

- **D-12:** Fresh-install default: add `verboseMarkers = true` to the inline default block in `Core.lua:47-67`. Insert it after `macroChannel = "SAY"` at line 66. (The block is a single literal table; one-line addition.)

- **D-13:** Backfill: add `if db.verboseMarkers == nil then db.verboseMarkers = true end` to the backfill section in `Core.lua:70-103`. Insert it after the `macroChannel` backfill at line 101-103.
  - SAFE-06 idiom: nil-check, not `or DEFAULT`.
  - Existing v1.0.0 users upgrade to v1.1.0 with `db.verboseMarkers = nil` (key didn't exist) → backfill sets it to `true` → they get verbose tokens on first login post-upgrade.
  - Anyone who somehow has `db.verboseMarkers = false` (impossible at v1.0.0 → v1.1.0 boundary, but defensively safe) keeps that explicit choice.

- **D-14:** No data migration step required. The four marker macros' bodies update on next `RegisterMacros` call (which runs on `PLAYER_LOGIN` from `Core.lua:34-39`). On the very first v1.1.0 login post-upgrade, this happens automatically as part of normal addon load. Users see their macros' bodies change in `/macro` after the first login — no extra UI prompt needed; the milestone framing already explains the change.

### Slash command surface (not in scope)

- **D-15:** No new slash command. `/lura verbose on|off` was considered (would be the natural mirror of `/lura show|hide`) but is scope creep relative to the requirements as written — CFG-15 specifies a config-panel checkbox, not a slash command. Captured in Deferred Ideas for a future milestone if user feedback requests it.

### UAT checkpoints (planner finalizes)

- **D-16:** Recommended UAT pass after Phase 7 implementation:
  1. **Fresh install** — Delete `TerribleLuraHelperDB`, `/reload`. Open `/macro`. Confirm `TLH_Diamond` body `/s {diamond}`, `TLH_Triangle` `/s {triangle}`, `TLH_Circle` `/s {circle}`, `TLH_Cross` `/s {cross}`, `TLH_T` `/s T`. Open `/lura config`, confirm "Use verbose markers" checkbox is **checked** in the Macros section between the dropdown and the Recreate button.
  2. **Toggle off out of combat** — Uncheck "Use verbose markers". Confirm chat print: `TLH: Verbose markers off. Macros updated.` Open `/macro`, confirm `TLH_Diamond` body now `/s {rt3}`, `TLH_Triangle` `/s {rt4}`, `TLH_Circle` `/s {rt2}`, `TLH_Cross` `/s {rt7}`, `TLH_T` still `/s T`.
  3. **Toggle on out of combat** — Re-check the box. Confirm chat print: `TLH: Verbose markers on. Macros updated.` Open `/macro`, confirm verbose tokens are back.
  4. **Toggle during combat** — Engage a training dummy (or any combat). Toggle the checkbox. Confirm chat print: `TLH: Verbose markers on/off. Macros will update when you leave combat.` Open `/macro` (combat-allowed) — confirm bodies have NOT yet changed. Leave combat. Confirm bodies update on `PLAYER_REGEN_ENABLED`; no further print fires (existing `regenFrame` doesn't re-print; the deferral message already told the user what would happen).
  5. **Upgrade-safe backfill** — With a pre-modified `TerribleLuraHelperDB` that lacks `verboseMarkers`, `/reload`. Confirm checkbox is **checked** (default ON applied via backfill). Confirm `git grep "= db\." -- '*.lua' | grep " or "` returns ZERO matches (SAFE-06 grep gate intact).
  6. **End-to-end in-game** — Press `TLH_Diamond` macro from action bar with verbose ON: confirm chat in `/s` shows the diamond marker icon (rendered by Blizzard's chat pipeline from `{diamond}`). Press with verbose OFF after toggling: confirm chat in `/s` shows the SAME diamond marker icon (rendered from `{rt3}`). The visible chat output is IDENTICAL — only the underlying token form differs.
  7. **Helper window renders both forms** — With the TLH window shown, press each marker macro under verbose ON and verbose OFF. Confirm the rune slot in the helper window displays the icon correctly in both cases (validates that `C_ChatInfo.ReplaceIconAndGroupExpressions` handles `{diamond}` and `{rt3}` equivalently; this is documented Blizzard behavior but worth verifying).
  8. **Regression guard** — `git diff` for the phase contains zero `SendChatMessage`, no `:gsub`/`:match`/`#msg`/indexing of `msg` from `CHAT_MSG_*` events. Phase 7 stays clear of hard taint constraints.

### Claude's Discretion (the planner has flexibility here)

- Exact insertion point for the new checkbox initializer inside `RegisterMacroSection` — recommendation: a new `do ... end` block labeled `-- (3aa) Verbose markers checkbox` between the existing `-- (3a)` dropdown and `-- (3b)` Recreate button.
- Whether to extract `value and "on" or "off"` into a helper. Recommendation: no — used in exactly two places (immediate + deferred print) within a single function; inlining keeps the call sites readable.
- Whether the tooltip wraps lines explicitly or relies on the Settings framework's word wrap. Recommendation: rely on the framework (the existing tooltips in `Config.lua` are single-string-no-explicit-wrap).
- Whether `OnVerboseMarkersChanged` lives in `Macros.lua` or `Core.lua`. Recommendation: `Macros.lua` — it's a macro-state function; the parallel `OnMacroChannelChanged` already lives there.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.1.0 milestone scope
- `.planning/PROJECT.md` — Current Milestone section (v1.1.0 QoL Update) + Key Decisions table (carries forward the SAFE-06 / AMEND-01 invariants from v1.0.0).
- `.planning/REQUIREMENTS.md` §"Verbose-Marker Toggle" — full text of MACR-06, MACR-07, CFG-15, CFG-16, SCAF-18.
- `.planning/ROADMAP.md` §"Phase 7: Verbose-Marker Toggle" — goal + 5 success criteria.

### Existing code (the patterns Phase 7 mirrors)
- `Macros.lua` — full file is the reference. Key sites:
  - `Macros.lua:17-23` — existing `MACROS` table (D-01 modifies in place).
  - `Macros.lua:45-79` — `RegisterMacros` function (D-02 adds the payload-selection conditional).
  - `Macros.lua:86-98` — `regenFrame` + `armRegenRetry` (D-09 reuses unchanged).
  - `Macros.lua:131-144` — `OnMacroChannelChanged` (D-09 mirrors structurally for `OnVerboseMarkersChanged`).
- `Config.lua` — Macros section is the structural model:
  - `Config.lua:313-396` — `RegisterMacroSection` (D-04 inserts the new (3aa) block between (3a) and (3b)).
  - `Config.lua:318-329` — macro-channel dropdown registration pattern (D-08 mirrors the `Settings.RegisterAddOnSetting` + `SetValueChangedCallback` + `Settings.CreateCheckbox` shape; substituting Checkbox for Dropdown).
  - `Config.lua:161-180` — auto-hide checkbox (a closer template for the new control because it's also a `Settings.CreateCheckbox` with `Settings.VarType.Boolean`).
- `Core.lua` — backfill site:
  - `Core.lua:47-67` — inline defaults table (D-12 adds `verboseMarkers = true` here).
  - `Core.lua:70-103` — backfill block (D-13 adds the `if db.verboseMarkers == nil then` line here).
  - `Core.lua:34-39` — `PLAYER_LOGIN` → `ns:InitMacros` (the flow that picks up the new default on first post-upgrade login).

### v1.0.0 precedent — SAFE-06 idiom
- `.planning/milestones/v1.0.0-phases/04-say-defaults-click-through/04-CONTEXT.md` — Phase 4 established the `if X == nil then` backfill idiom. D-13's backfill line follows it verbatim.
- `.planning/research/PITFALLS.md` §"DB-1" — the `db.X = db.X or DEFAULT` anti-pattern rationale.

### Settings API patterns
- `.planning/research/SETTINGS_API.md` — Verified `Settings.*` API patterns from v0.1.0 research. Phase 7 uses the same building blocks as Phase 3's existing controls; no new API surface introduced.

### Hard constraints (permanent — carry-over)
- `CLAUDE.md` §"Hard Constraints" — never call `SendChatMessage`, never index `msg` from `CHAT_MSG_*` events, no `COMBAT_LOG_EVENT_UNFILTERED`. Phase 7 doesn't touch chat code paths, but the regression guard in D-16 #8 explicitly checks the diff.

### Phase boundary context
- `.planning/archive/v0.1.0/02-poc-port-macros-window-commands/02-CONTEXT.md` — Phase 2 established the `MACROS` table shape and `RegisterMacros` flow. Phase 7 modifies the table and the function but keeps the architecture.
- `.planning/archive/v0.1.0/03-config-panel-integration/03-CONTEXT.md` — Phase 3 established the Settings-API panel + `Settings.RegisterAddOnSetting` framework-writes-DB invariant. Phase 7 adds one control to the same panel using the same invariant.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Settings.RegisterAddOnSetting` + `Settings.CreateCheckbox`** — exact pattern used by `Config.lua:161-180` (Auto-hide checkbox). New "Use verbose markers" checkbox uses the same skeleton (different setting name, variable name, default, label, tooltip).
- **`ns:OnMacroChannelChanged` (Macros.lua:134-144)** — structural template for `ns:OnVerboseMarkersChanged`. Same combat-lockdown branch, same `armRegenRetry()` reuse, same print-feedback split between immediate and deferred variants.
- **`armRegenRetry` + `regenFrame` (Macros.lua:86-98)** — existing combat-deferral path. Phase 7 reuses unchanged.
- **`registrationDeferred` flag in `RegisterMacros` early-return (Macros.lua:46-49)** — already handles the "combat blocked → retry on PLAYER_REGEN_ENABLED" semantics. Phase 7 reuses unchanged.

### Established Patterns
- **`if X == nil then` backfill (SAFE-06)** — universal in `Core.lua:70-103`. Phase 7's backfill line follows verbatim.
- **Section ordering in `RegisterMacroSection`** — (3a) dropdown → (3b) Recreate → (3c) Delete. Phase 7 inserts (3aa) between (3a) and (3b). Section labels use `-- (3X)` comment markers throughout `Config.lua`.
- **Print-feedback color prefix** — `|cffaa44ffTLH|r:` is the canonical pattern across `Macros.lua`, `Config.lua`, `Core.lua`. Phase 7's new prints use the same.
- **`SetValueChangedCallback` calls an `ns:On*Changed(value)` export** — established in Phase 3 (auto-hide → `OnAutoHideChanged`; macro-channel → `OnMacroChannelChanged`). Phase 7's callback calls `ns:OnVerboseMarkersChanged(value)` per the convention.

### Integration Points
- **`Macros.lua:17-23`** — `MACROS` table (D-01 dual-field-per-row modification).
- **`Macros.lua:54-66`** — `RegisterMacros` for-loop (D-02 payload-selection conditional adds one line, modifies the `local body = ...` line).
- **`Macros.lua` (new exported function)** — `ns:OnVerboseMarkersChanged(value)` per D-09. Append near `OnMacroChannelChanged`.
- **`Config.lua:313-396`** — `RegisterMacroSection` (D-04 inserts the new (3aa) block).
- **`Core.lua:47-67`** — inline defaults (D-12 adds one line).
- **`Core.lua:70-103`** — backfill (D-13 adds one line).

### Existing Test Surface
- No automated test harness for WoW addons (CLAUDE.md). All testing is in-game smoke pass per UAT checkpoints (D-16).
- `stylua` runs after every modified Lua file (CLAUDE.md gate). Three files touched in Phase 7: `Macros.lua`, `Config.lua`, `Core.lua`.
- SAFE-06 grep gate: `git grep "= db\." -- '*.lua' | grep " or "` must remain zero-match. D-13's backfill line uses the nil-check idiom; D-16 #5 makes the grep an explicit UAT checkpoint.

</code_context>

<specifics>
## Specific Ideas

- **User's preferred style is "simple/native/no-special-cases".** Phase 7 has no UI novelty — it's one checkbox in an existing panel, one new SavedVar key with the same backfill pattern as the existing ones, one new exported function modeled exactly after the existing one. Resist scope creep (no slash command, no auto-detect, no per-macro override).
- **The toggle reframes for users who DON'T know they need it.** Default ON means the milestone improvement is invisible to users who already had things working — they get the better-rendering tokens automatically. The toggle exists as a safety valve for the minority on broken chat-addon stacks; the tooltip names that case explicitly so they know when to flip it.
- **Existing TLH_T outlier is intentional and self-documenting.** The 5th macro's literal-"T" payload is the encounter's actual rune, not a marker icon — that's why it doesn't get a verbose variant. The single `payload` field on its row in the `MACROS` table (vs `payloadVerbose` + `payloadRT` on the other four) physically encodes this irregularity. Adding a comment above the table is recommended but not load-bearing.

</specifics>

<deferred>
## Deferred Ideas

- **`/lura verbose on|off` slash command** — natural mirror of `/lura show|hide`, but adds a new slash-command surface. CFG-15 specifies a config-panel checkbox only. If user feedback after v1.1.0 ships requests a CLI path, add in a future milestone.
- **Auto-detect when verbose tokens fail in chat** — could compare the user's chat-addon stack against a known-good list, or watch for raid-marker rendering failures, but this is fragile and overengineered. The user can manually toggle off if they notice the issue.
- **Per-macro verbose override** — explicitly OOS per requirements; toggle is binary, affects all four marker macros uniformly. Marker-set remapping was already deferred in v0.1.0.
- **Migrating the macro NAME (`TLH_Diamond` → something else) to match verbose token convention** — would force users to drag new macros to action bars. Names are stable across v1.1.0; only payloads change.
- **Showing a one-time "we changed your macros" notice on first post-upgrade login** — D-14 explicitly rejects this. The milestone framing already communicates the change; an in-game popup would feel intrusive.

</deferred>

---

*Phase: 07-verbose-marker-toggle*
*Context gathered: 2026-05-15*
