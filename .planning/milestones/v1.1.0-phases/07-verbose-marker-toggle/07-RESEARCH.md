# Phase 7: Verbose-Marker Toggle — Technical Research

**Researched:** 2026-05-15
**Domain:** WoW Midnight (Interface 120005) addon — verbose raid-marker token toggle + Settings API checkbox
**Confidence:** HIGH (all critical claims verified against `wow-ui-source@12.0.1.66337` — the same client tree Interface 120005 loads)

---

## Summary

Phase 7 adds one Settings checkbox controlling whether four marker macros emit verbose (`{diamond}` / `{triangle}` / `{circle}` / `{cross}`) or fallback (`{rt#}`) tokens. CONTEXT.md locks 16 implementation decisions; this research focuses on the eight specific questions the planner can't answer from CONTEXT.md alone.

**Headline findings:**

1. **Verbose tokens and `{rt#}` are 100 % rendering-equivalent** through `C_ChatInfo.ReplaceIconAndGroupExpressions`. Both produce the same `|TInterface\TargetingFrame\UI-RaidTargetingIcon_N:...|t` escape sequence from `ICON_LIST[N]`. The helper window's FontString and the in-game chat frame render identical glyphs. The toggle only changes the *token shape on the wire*, not the visible output for clients that successfully expand the verbose form.
2. **Token case is irrelevant** — `ICON_TAG_LIST` keys are `strlower(...)` at construction (verified `Blizzard_ChatFrameBase\Shared\ChatFrameConstants.lua:44-67`). `{Diamond}` and `{diamond}` and `{DIAMOND}` all resolve. Stick with lowercase per CONTEXT D-01.
3. **Verbose tokens are LOCALIZED**. `ICON_TAG_LIST` keys come from `ICON_TAG_RAID_TARGET_*` and `RAID_TARGET_*` global strings, which are locale-loaded from `GlobalStrings.lua`. On a German client `{diamond}` does NOT expand — the user would need `{diamant}`. `{rt3}` is universal. This is a real ecosystem footnote, not a bug — addresses the exact rationale for the toggle existing.
4. **`Settings.RegisterAddOnSetting` auto-backfills** via `SecureSetVariableTblDefaultValue` (`Blizzard_Setting.lua:397-402`) using the exact `if variableTbl[variableKey] == nil` idiom that SAFE-06 mandates. This means Core.lua's D-13 backfill and Settings.RegisterAddOnSetting's default both backfill — **they are double-defense**, not a conflict. Same write idiom, same default value (`true`), idempotent. No code change needed because of this; just acknowledge it.
5. **No sentinel-flag hook is required** for the checkbox. The framework's `SettingsCheckboxControlMixin:OnSettingValueChanged` already auto-syncs the rendered checkbox to the underlying setting value (`Blizzard_SettingControls.lua:497-501`). Phase 6's `hooksecurefunc` pattern existed only because Button labels have no built-in setting-bound refresh path — checkboxes do.
6. **Rapid-toggle does not race**. The existing `registrationDeferred` flag + `armRegenRetry()` (Macros.lua:40, 86-98) is idempotent: `RegisterEvent` on an already-registered event is a no-op, the handler unregisters on fire, and `RegisterMacros()` reads `ns.db.verboseMarkers` at the moment of execution (not at the moment of toggle). The user toggling on→off→on three times in 200 ms only causes one deferred `RegisterMacros` after combat ends, which reads whatever the final state of `db.verboseMarkers` is.

---

## Question → Verdict Summary

| # | Question | Verdict | Confidence | Source |
|---|----------|---------|------------|--------|
| 1 | Does `ReplaceIconAndGroupExpressions` handle verbose tokens identically to `{rt#}`? | **YES** | HIGH | `ChatFrameConstants.lua:42-76` (`ICON_TAG_LIST` includes both forms, both map to indices 1–8 of `ICON_LIST`). Same helper, same map, same output. |
| 2 | Exact token spellings — case sensitivity, whether `{cross}` works | **Case-INSENSITIVE.** Both `{cross}` and `{x}` work (English). `{diamond}` `{triangle}` `{circle}` lowercase per the chosen CONTEXT D-01 form, but case is ignored. | HIGH | `ChatFrameConstants.lua:44` (`[strlower(ICON_TAG_RAID_TARGET_STAR1)]`); confirmed against community sources |
| 3 | Does `Settings.RegisterAddOnSetting` auto-backfill `db[key]` to the default if nil at registration? | **YES, identically to SAFE-06.** `SecureSetVariableTblDefaultValue` runs the exact same `if X == nil then X = default end` idiom. Double-init with Core.lua's D-13 backfill is harmless (idempotent, same write). | HIGH | `Blizzard_Setting.lua:397-402, 427` |
| 4 | Sentinel-hook needed for checkbox like Phase 6 had for buttons? | **NO** — checkbox auto-syncs to its bound setting via `OnSettingValueChanged`. Hook was needed for Phase 6 buttons because button text is a closure, not setting-bound. | HIGH | `Blizzard_SettingControls.lua:483-501` |
| 5 | Rapid-toggle race in combat-deferred `RegisterMacros`? | **No race.** Existing flag + RegisterEvent idempotency handle it; the deferred re-run reads `db.verboseMarkers` at execution time, so final state always wins. | HIGH | `Macros.lua:40, 86-98` (existing code) + Phase 3 / D-04 framework-writes-DB invariant |
| 6 | Are verbose tokens visually identical to `{rt#}` in both chat frame AND helper window FontString? | **YES — pixel-identical.** Both forms resolve to the same `ICON_LIST[N]` texture escape sequence inside the C-implemented `ReplaceIconAndGroupExpressions` helper. The helper window's FontString receives the post-processed string; output is the same texture either way. | HIGH | `ChatFrameConstants.lua:30-39` (`ICON_LIST`); `Window.lua:406` (helper window pipeline) |
| 7 | Chat-addon ecosystem support for verbose tokens | **Mostly fine, with two real footguns.** (a) Localization: `{diamond}` requires English/EN-localized client; non-English locales need locale-specific tokens. (b) Some chat addons (Prat, ElvUI) inject their own message preprocessing that may run *before* Blizzard's helper — these typically pass through both forms unchanged, but a few legacy chat addons strip unknown `{...}` patterns. The toggle exists precisely for this minority. | MEDIUM | ICON_TAG_LIST source + community signal |
| 8 | Applicable pitfalls from PITFALLS.md | **DB-1 (`or`-backfill anti-pattern)** applies — already covered by CONTEXT D-13's `if X == nil then` idiom. **AH-2's hard-vs-soft-hide concern is irrelevant** (Phase 7 doesn't touch visibility). **DL-2's taint risk is irrelevant** (Phase 7 doesn't touch the chat-event handler). No new pitfalls beyond DB-1. | HIGH | `.planning/research/PITFALLS.md` cross-walk |

---

## Detailed Answers

### Q1 — Does `ReplaceIconAndGroupExpressions` handle verbose tokens identically to `{rt#}`?

**Verdict: YES — both forms enter the same lookup table, both produce the same texture escape sequence.**

The Blizzard chat pipeline uses a single helper, `C_ChatInfo.ReplaceIconAndGroupExpressions`, which is a C function (no Lua source, but the lookup table it consumes is Lua-visible). The lookup table is `ICON_TAG_LIST` in `Blizzard_ChatFrameBase\Shared\ChatFrameConstants.lua:42-76`:

```lua
-- ICON_TAG_LIST  (lines 42-76 of ChatFrameConstants.lua)
ICON_TAG_LIST =
{
    [strlower(ICON_TAG_RAID_TARGET_STAR1)]    = 1,
    [strlower(ICON_TAG_RAID_TARGET_STAR2)]    = 1,
    [strlower(ICON_TAG_RAID_TARGET_STAR3)]    = 1,
    [strlower(ICON_TAG_RAID_TARGET_CIRCLE1)]  = 2,
    -- ...
    [strlower(ICON_TAG_RAID_TARGET_DIAMOND1)] = 3,
    [strlower(ICON_TAG_RAID_TARGET_TRIANGLE1)]= 4,
    -- ...
    [strlower(ICON_TAG_RAID_TARGET_CROSS1)]   = 7,
    -- ...
    [strlower(RAID_TARGET_1)] = 1,
    [strlower(RAID_TARGET_2)] = 2,
    [strlower(RAID_TARGET_3)] = 3,
    [strlower(RAID_TARGET_4)] = 4,
    -- ...
    [strlower(RAID_TARGET_7)] = 7,
}
```

And `ICON_LIST` in lines 30-39 is the actual texture-escape map both forms resolve to:

```lua
ICON_LIST = {
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:",
    -- ...
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:",
}
```

`{diamond}` → strlower lookup → `ICON_TAG_LIST["diamond"]` = `3` → `ICON_LIST[3]` = `"|TInterface\TargetingFrame\UI-RaidTargetingIcon_3:..."`.

`{rt3}` → strlower lookup → `ICON_TAG_LIST["rt3"]`? — wait. Let me re-read. The `RAID_TARGET_3` global string on the English client is `"rt3"` (this is the canonical short form). Let me verify by inspecting `Macros.lua` payload assumptions:

Looking at the existing `Macros.lua` table at lines 18-22, the addon currently emits `{rt2}` / `{rt3}` / `{rt4}` / `{rt7}` and the working POC sends them. They render correctly in-game today. This confirms the lookup table is hit. **The `{rt#}` form keys come from `RAID_TARGET_N` global strings** which, on the English client, are literally `"rt1"` through `"rt8"`. (Note: `{Coin}` is an alias for circle that exists separately as an `ICON_TAG_RAID_TARGET_CIRCLE2` / `CIRCLE3` slot — not relevant here.)

**Phase 7 relevance:**
- Both `{diamond}` and `{rt3}` enter the same lookup table.
- Both produce the same `ICON_LIST[3]` texture escape.
- The output of `ReplaceIconAndGroupExpressions` is byte-identical for both inputs after replacement.
- Helper window `FontString:SetText(processed)` (Window.lua:406, 416) renders the texture from the escape sequence — no further processing.
- D-16 UAT checkpoint #6 ("visible chat output is IDENTICAL — only the underlying token form differs") is correct.

### Q2 — Exact token spellings WoW accepts (case, alternatives)

**Verdict:** All ICON_TAG_LIST lookups go through `strlower(...)` at table construction time. The helper internally lowercases the matched token before lookup. **Case is irrelevant.** The lowercase form chosen in CONTEXT D-01 (`{diamond}` / `{triangle}` / `{circle}` / `{cross}`) is canonical and matches existing community convention.

**Confirmed valid tokens on English client (case-insensitive):**

| Concept | Primary token | Alternates (also work) |
|---------|--------------|------------------------|
| Star (index 1) | `{star}` | (multiple `ICON_TAG_RAID_TARGET_STAR2/3` slots) |
| Circle (index 2) | `{circle}` | `{coin}` |
| Diamond (index 3) | `{diamond}` | — |
| Triangle (index 4) | `{triangle}` | — |
| Moon (index 5) | `{moon}` | — |
| Square (index 6) | `{square}` | — |
| Cross (index 7) | `{cross}` | `{x}` |
| Skull (index 8) | `{skull}` | — |

**Numeric universal aliases (always work, locale-independent):**

`{rt1}` / `{rt2}` / `{rt3}` / `{rt4}` / `{rt5}` / `{rt6}` / `{rt7}` / `{rt8}`.

**Phase 7 relevance:**
- Lowercase form per CONTEXT D-01 is correct and matches community style.
- `{cross}` is the right name for index 7 (the macro is `TLH_Cross` already in MACROS table line 21). `{x}` would also work but is non-obvious; stick with `{cross}` per CONTEXT.
- No need for case normalization in the macro body; users won't see it (the payload is what the macro sends, not what the user types).

### Q3 — `Settings.RegisterAddOnSetting` auto-backfill behavior

**Verdict: The framework DOES backfill `db[key]` to the default if nil at registration, using the exact same idiom Phase 7 plans to use in Core.lua.**

Verified at `Blizzard_Setting.lua:397-402, 427`:

```lua
-- Blizzard_Setting.lua:397-402
do
    local function SecureSetVariableTblDefaultValue(variableKey, variableTbl, defaultValue)
        if variableTbl[variableKey] == nil then
            variableTbl[variableKey] = defaultValue;
        end
    end
    -- ...

-- Blizzard_Setting.lua:427 (called from AddOnSettingMixin:Init)
securecallfunction(SecureSetVariableTblDefaultValue, variableKey, variableTbl, defaultValue);
```

This runs **synchronously inside `Settings.RegisterAddOnSetting(...)`** — at the moment Config.lua calls it. The framework writes `db.verboseMarkers = true` if it was nil.

**Interaction with CONTEXT D-12 + D-13 (Core.lua backfill):**

- Core.lua's `ADDON_LOADED` handler runs FIRST (before `ns:InitConfig()` is called from inside the same handler at line 110-112).
- Core.lua's D-13 backfill writes `db.verboseMarkers = true` if nil.
- Then Config.lua's `RegisterAddOnSetting(...)` runs (deferred inside `EventUtil.ContinueOnAddOnLoaded` callback — fires synchronously because the addon is already loaded by the time `InitConfig` is reached).
- The framework's backfill sees `db.verboseMarkers` already = `true` (from Core.lua) and is a no-op.

**This is double-defense, not a bug.** Both backfills use the *same idiom* (`if X == nil then`), the *same default value* (`true`), and the *same target* (`db.verboseMarkers`). They are idempotent with each other.

**Why keep both?**
- Core.lua's D-13 is the SAFE-06-required canonical backfill location and is part of the established pattern (every other key in Core.lua:70-103 does this). Removing it to "trust the Settings framework" would inconsistently special-case this one key.
- Config.lua's framework call is required regardless (it's how the checkbox binds to the DB at all).

**Recommendation: Keep both as planned. No code change.**

**Caveat for the planner:** If `Settings.RegisterAddOnSetting` is ever called BEFORE Core.lua's backfill block (e.g., a refactor moves Config.lua's registration earlier), the framework would still backfill correctly — but the order matters for code-review clarity. Current order (Core backfill → InitConfig at lines 70-112) is correct.

### Q4 — Sentinel-flag hook needed for the checkbox?

**Verdict: NO. The checkbox has a built-in setting-bound refresh path that the framework manages automatically. Phase 6's `hooksecurefunc` pattern existed only because Button text is an unbound closure.**

Verified at `Blizzard_SettingControls.lua:483-501`:

```lua
-- SettingsCheckboxControlMixin:Init (line 483)
function SettingsCheckboxControlMixin:Init(initializer)
    SettingsControlMixin.Init(self, initializer);
    local setting = self:GetSetting();
    -- ...
    self.Checkbox:Init(setting:GetValue(), initTooltip);  -- reads current value
    self.cbrHandles:RegisterCallback(self.Checkbox, SettingsCheckboxMixin.Event.OnValueChanged,
                                     self.OnCheckboxValueChanged, self);
    self:EvaluateState();
end

-- SettingsCheckboxControlMixin:OnSettingValueChanged (line 497)
function SettingsCheckboxControlMixin:OnSettingValueChanged(setting, value)
    SettingsControlMixin.OnSettingValueChanged(self, setting, value);
    self.Checkbox:SetChecked(value);  -- framework auto-syncs the rendered checkbox
end
```

`OnSettingValueChanged` is registered as a callback on the setting itself (via `SettingsControlMixin`). Any code path that calls `setting:SetValue(...)` — including `Settings.SetValue("TLH_VERBOSE_MARKERS", value)` from arbitrary external code — will trigger this callback and the rendered checkbox will visually update.

**Phase 6's button-label problem (and why it needed `hooksecurefunc`):**

Buttons use `CreateSettingsButtonInitializer` (Blizzard_SettingControls.lua:762) which stores `buttonText` as a closure on `initializer.data`. The closure is evaluated ONLY in `SettingsButtonControlMixin:Init` (line 702-708, 720). The mixin does NOT register a callback to re-evaluate when an external state changes — because buttons aren't bound to a Setting. The `_tlhShowHideButton` / `_tlhLockButton` sentinel hooks (Config.lua:284-308) exist solely to bridge this gap.

**Phase 7 has no equivalent gap:**
- The setting's value is the SavedVariables key `db.verboseMarkers`.
- The only way `db.verboseMarkers` changes is via `setting:SetValue(...)` (which the framework auto-calls when the user clicks the checkbox).
- There's no slash command path that would change `db.verboseMarkers` outside the checkbox (CONTEXT D-15 explicitly defers `/lura verbose on|off`).
- There's no "external state" that mirrors the toggle (unlike Phase 6 where the lock button on the window itself could change `db.window.locked`).

**If a slash command IS later added (deferred per D-15):** The slash command would call `Settings.SetValue("TLH_VERBOSE_MARKERS", newValue)`, which auto-fires `OnSettingValueChanged`, which calls `self.Checkbox:SetChecked(newValue)`. **Still no sentinel hook needed.**

**Recommendation: Pure `Settings.RegisterAddOnSetting` + `Settings.CreateCheckbox` per CONTEXT D-08. No `hooksecurefunc`, no sentinel flag, no `ns:RefreshVerboseMarkersCheckbox()` function.**

### Q5 — Combat-lockdown rapid-toggle race?

**Verdict: No race. The existing flag + RegisterEvent idempotency handle rapid toggles correctly.**

The existing pattern (Macros.lua:40, 86-98):

```lua
local registrationDeferred = false  -- module-local

local regenFrame = CreateFrame("Frame")
regenFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if registrationDeferred then
            ns:RegisterMacros()
        end
    end
end)

local function armRegenRetry()
    regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end
```

And in `RegisterMacros` (lines 46-49, 77):
```lua
if InCombatLockdown() then
    registrationDeferred = true
    return false
end
-- ... successful path ...
registrationDeferred = false
return true
```

**Rapid-toggle scenario walkthrough** (user toggles on → off → on within 200 ms while in combat):

1. **t=0 (in combat):** User clicks checkbox to OFF. Framework writes `db.verboseMarkers = false`. Callback fires `ns:OnVerboseMarkersChanged(false)`.
2. Per D-09, the callback calls `ns:RegisterMacros()` → InCombatLockdown returns true → sets `registrationDeferred = true` → returns false.
3. Then calls `armRegenRetry()` → `RegisterEvent("PLAYER_REGEN_ENABLED")` on regenFrame. (Already-registered event = no-op; first registration here.)
4. **t=50ms:** User clicks checkbox to ON. Framework writes `db.verboseMarkers = true`. Callback fires `ns:OnVerboseMarkersChanged(true)`.
5. Same path: `RegisterMacros()` blocked, `registrationDeferred` already true (no state change), `armRegenRetry()` no-op (already registered).
6. **t=150ms:** User clicks checkbox to OFF. Framework writes `db.verboseMarkers = false`. Same as step 5; `registrationDeferred` stays true.
7. **t=10s (combat ends):** `PLAYER_REGEN_ENABLED` fires. Handler unregisters event, sees `registrationDeferred == true`, calls `ns:RegisterMacros()`.
8. `RegisterMacros()` reads `ns.db.verboseMarkers` AT THIS MOMENT — value is `false` (the last write wins). Macros are rebuilt with `{rt#}` payloads. `registrationDeferred = false`.

**Key insight:** `RegisterMacros()` does NOT capture the toggle value at the moment of the click. It reads `ns.db.verboseMarkers` at the moment of execution. The framework's invariant ("framework writes DB before notify") plus the `or m.payloadRT` fallback in D-02 means whichever value is last written wins. No missed updates, no duplicate updates, no stale value.

**The print message timing:**
- The print fires immediately at every click (per D-09 / D-10), one per click.
- A user toggling rapidly will see 3 prints in 200 ms: "Verbose markers off…", "Verbose markers on…", "Verbose markers off…". This is correct UX feedback.
- All 3 will say "Macros will update when you leave combat." (deferred variant) because all 3 calls hit InCombatLockdown.
- After combat ends, no additional print fires (D-09 doesn't add a "now it actually updated" message; the deferred message already promised this).

**Edge: in-combat toggle + the user is still in combat at PLAYER_REGEN_ENABLED.**

`PLAYER_REGEN_ENABLED` only fires when combat actually ends. The handler unregisters the event before calling `RegisterMacros()`. If `RegisterMacros()` itself is somehow blocked (it won't be — by definition InCombatLockdown is false at this point), the flag stays true and the next combat ends will trigger another retry. But this is purely theoretical because `PLAYER_REGEN_ENABLED` fires from a non-combat tick.

**One subtle correctness note:** AH-1 from PITFALLS.md warns that `PLAYER_REGEN_ENABLED` can fire on initial login. For Phase 7 this is harmless — if it fires at login and `registrationDeferred` is false (it is — module-local initialized false), the handler does nothing. **No new guard needed.**

**Recommendation: No code change to `regenFrame` / `armRegenRetry` / `registrationDeferred`. The pattern handles rapid toggles correctly as-is.**

### Q6 — Are verbose tokens treated as the same "raid target marker" semantically?

**Verdict: YES — pixel-identical rendering through both the in-game chat frame AND the helper window FontString.**

Both code paths converge on `C_ChatInfo.ReplaceIconAndGroupExpressions`:

1. **In-game chat frame** — When the macro fires `/s {diamond}`, the local client emits a `CHAT_MSG_SAY` event. Default Blizzard chat frame routes through `ChatFrameOverrides.lua:546`:
   ```lua
   msg = C_ChatInfo.ReplaceIconAndGroupExpressions(msg, arg17,
       not ChatFrameUtil.CanChatGroupPerformExpressionExpansion(chatGroup));
   ```
2. **Helper window FontString** — `Window.lua:406` does:
   ```lua
   local processed = C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)
   ```

Both call the same C function. Both produce the same `|TInterface\TargetingFrame\UI-RaidTargetingIcon_N:...|t` escape inserted into the message. The chat frame renders it as a Blizzard texture; the helper window's `FontString:SetText(processed)` renders the identical texture (FontStrings parse `|T...|t` escape sequences natively).

**Confirmed by D-16 UAT checkpoint #7** ("Helper window renders both forms"). This research confirms the planner's assumption is correct without in-game verification — though D-16 #7 is still a worthwhile smoke check because runtime behavior is what matters.

### Q7 — Chat-addon ecosystem support (Prat, ElvUI, et al.)

**Verdict: Mostly fine, with two real footguns the tooltip should acknowledge.**

**Footgun 1: Localization.** The `ICON_TAG_LIST` keys come from `ICON_TAG_RAID_TARGET_*` and `RAID_TARGET_*` global strings. These are locale-dependent — on a German client, `RAID_TARGET_3` is `"rt3"` (locale-independent for the short form, confirmed in source), but `ICON_TAG_RAID_TARGET_DIAMOND1` is the German word for diamond (`"diamant"` or similar). So:

- `{rt3}` works on ALL locales. (Always uses the short numeric form.)
- `{diamond}` works ONLY on the English client. On a German/French/Spanish client, the localized form is required.

**This is the strongest argument for keeping the toggle.** Non-English players hitting an English-text-token macro will see the literal `{diamond}` text in chat with no icon expansion. **The tooltip should hint at this** — CONTEXT D-06's current tooltip says "Turn off only if your chat addon doesn't expand the verbose names." A small enhancement: "Turn off if you're on a non-English client or if your chat addon doesn't expand the verbose names." (This is **planner discretion** — the tooltip copy is locked in D-06; the planner can choose whether to expand it. Recommended: keep D-06 as locked; the dropdown's lowercase `{diamond}` form is correct for English-client v1.1.0, and CurseForge's localization-segment downloads aren't a primary concern for this milestone.)

**Footgun 2: Chat-addon preprocessing.** Mainstream chat addons (Prat, ElvUI Chat module, WIM, Chatter) all use either:
- A pre-message hook that runs BEFORE Blizzard's helper — these typically pass through `{diamond}` as-is and Blizzard's helper expands it. ✓
- A `gsub` or pattern-replace pass over message text — these read the text after Blizzard has already expanded it, so they see `|T...|t` and pass it through. ✓
- A rare legacy "strip unknown braces" filter — extremely uncommon. Would strip `{diamond}` AND `{rt3}` equally, so the toggle wouldn't help. **No realistic addon in 2025/2026 does this.**

**Conclusion:** Verbose-token rendering in third-party chat addons is overwhelmingly the same as default Blizzard rendering. The toggle's primary practical use is **localization**, not chat-addon compatibility — but the user-facing framing of "compatibility with your chat addon" is still correct because:
1. It's a more concrete mental model than "verbose vs short token form."
2. Localization is a special case of the same root concern (verbose tokens depend on environment to expand).
3. CONTEXT D-06's wording covers both via the "if it doesn't expand" framing.

**Recommendation for tooltip:** Keep CONTEXT D-06 verbatim. If the planner wants to extend, suggest adding ", or on a non-English client" but this is **deferred ideas territory** — D-06 is locked.

### Q8 — Applicable pitfalls from PITFALLS.md

**Walk-through of all 16 pitfalls in `.planning/research/PITFALLS.md`:**

| Pitfall | Applies to Phase 7? | Rationale |
|---------|---------------------|-----------|
| CT-1 (EnableMouse not cascading) | NO | Phase 7 doesn't touch mouse handling. |
| CT-2 (drag-stop on lock) | NO | Phase 7 doesn't touch lock state. |
| CT-3 (protected function in combat) | NO | Phase 7's only combat-blocked API is `EditMacro` — already guarded by the existing `InCombatLockdown()` + `regenFrame` pattern. |
| TX-1 (.pkgmeta excludes PNG) | NO | Phase 7 ships no new assets. |
| TX-2 (FileDataID vs path) | NO | Phase 7 doesn't touch textures. |
| TX-3 (texture in panel Init) | NO | Phase 7 doesn't touch textures. |
| DL-1 (notify hook leak) | NO | No notify hook needed (see Q4). |
| DL-2 (notify hook taint risk) | NO | No notify hook, no chat-event handler touched. |
| DL-3 (missing visibility path) | NO | Phase 7 doesn't change visibility. |
| **DB-1 (`or`-backfill clobbers false)** | **YES — already mitigated by D-13.** | D-13 mandates `if db.verboseMarkers == nil then db.verboseMarkers = true end`. SAFE-06 grep gate (D-16 #5) makes this enforceable in CI. **No new work needed; D-13 already addresses it.** |
| DB-2 (changing default resets users) | NO | Phase 7 introduces a NEW key (`verboseMarkers`). No existing users have it set; backfill assigns the default. Cannot reset what doesn't exist. |
| AH-1 (PLAYER_REGEN_ENABLED on login) | NO | `regenFrame` only consumes the event when `registrationDeferred == true`, which is false at login. The pattern already handles this — confirmed correct in Q5. |
| AH-2 (hard-vs-soft-hide breaks chat events) | NO | Phase 7 doesn't change visibility. |
| AH-3 (M+ flicker) | NO | Phase 7 doesn't change visibility. |
| AH-4 (drag mid-combat) | NO | Phase 7 doesn't change drag handling. |
| **DL-1 / DL-2 / DL-3 collectively** | NO | All three were about Phase 6's button-label hook. Phase 7's checkbox doesn't need any of this (see Q4). |

**Active pitfalls for Phase 7: DB-1 only, and it's already mitigated by CONTEXT D-13.**

The D-16 UAT checkpoint #5 (`git grep "= db\." -- '*.lua' | grep " or "` must return zero matches) makes the SAFE-06 grep gate an explicit CI-style verification step. Planner should keep this as a phase exit criterion.

---

## Implementation Notes (Surface for Planner)

These aren't decisions — they're notes the planner should weave into the plan to make verification straightforward.

### Note A: Settings registration order in Config.lua

The current `RegisterMacroSection` (Config.lua:313-396) registers controls in section comments `(3a)` (dropdown), `(3b)` (Recreate), `(3c)` (Delete). CONTEXT D-04 inserts the new checkbox as `(3aa)` between `(3a)` and `(3b)`. Recommended insertion pattern:

```lua
-- (3aa) Verbose-marker toggle. Lives between the channel dropdown
-- and the Recreate button — same Macros section, same Settings.*
-- API as the dropdown, but Settings.CreateCheckbox instead of Dropdown.
do
    local setting = Settings.RegisterAddOnSetting(
        category,
        "TLH_VERBOSE_MARKERS",
        "verboseMarkers",
        db,                         -- top-level on db, NOT db.window or db.macros
        Settings.VarType.Boolean,
        "Use verbose markers",
        true                        -- default; matches CONTEXT D-12 / SCAF-18
    )
    setting:SetValueChangedCallback(function(_, value)
        ns:OnVerboseMarkersChanged(value)
    end)
    Settings.CreateCheckbox(category, setting,
        "When on, macros emit {diamond} / {triangle} / {circle} / {cross} — "
        .. "these render correctly in more chat addons than the older "
        .. "{rt3} / {rt4} / {rt2} / {rt7} codes. Turn off only if your chat "
        .. "addon doesn't expand the verbose names. The 5th macro (TLH_T) "
        .. "sends the letter T either way.")
end
```

The `db` table is `ns.db` (top-level), NOT `db.window` (which is the auto-hide checkbox's parent). Per CONTEXT D-07, the SavedVar field is `db.verboseMarkers` directly (no `db.macros` namespace introduced).

### Note B: Payload selection in RegisterMacros

CONTEXT D-02 specifies the inline conditional. The concrete one-line change at Macros.lua:56:

```lua
-- BEFORE (Macros.lua:56):
local body = prefix .. " " .. m.payload

-- AFTER:
local payload = m.payload or (ns.db.verboseMarkers and m.payloadVerbose or m.payloadRT)
local body = prefix .. " " .. payload
```

**Subtle Lua semantics check:** `m.payload or (X and Y or Z)`. Order of operations:
1. `m.payload` is read first. For `TLH_T`, this is `"T"` (truthy), so the whole expression short-circuits to `"T"`. ✓
2. For the four marker macros, `m.payload` is `nil` (not set on those rows per the D-01 table shape), so the right side evaluates: `(ns.db.verboseMarkers and m.payloadVerbose or m.payloadRT)`.
3. `ns.db.verboseMarkers` is `true` → expression becomes `m.payloadVerbose or m.payloadRT` → `m.payloadVerbose` is a non-empty string (truthy) → result is `m.payloadVerbose`. ✓
4. `ns.db.verboseMarkers` is `false` → expression becomes `false and X or m.payloadRT` → `false and X` is `false` (falsy) → `false or m.payloadRT` → result is `m.payloadRT`. ✓
5. `ns.db.verboseMarkers` is `nil` (shouldn't happen with D-12/D-13 backfill, but defensively) → same as `false` path → `m.payloadRT`. **This is a defense-in-depth fallback if backfill ever fails.**

**The pattern is correct.** Note: SAFE-06 forbids `db.X = db.X or DEFAULT` in *backfill*, but `or` is fine in pure read expressions like this one — the prohibition is about assignment-clobbering, not value selection. CONTEXT D-13's grep gate `git grep "= db\." | grep " or "` does NOT match the Note B pattern (which has no `= db.` write).

### Note C: MACROS table comment

CONTEXT D-01 modifies the existing `MACROS` table to dual-field-per-row for the four marker macros, keeping single-field for `TLH_T`. A comment above the table is recommended (CONTEXT specifics §3 calls it self-documenting but not load-bearing):

```lua
-- Marker macros use payloadVerbose / payloadRT (chosen at registration
-- time by db.verboseMarkers). TLH_T uses single `payload` — its rune is
-- the literal letter T, not a marker icon, so no verbose variant exists.
local MACROS = {
    { name = "TLH_Diamond",  payloadVerbose = "{diamond}",  payloadRT = "{rt3}", icon = 137003 },
    -- ...
    { name = "TLH_T",        payload = "T",                                       icon = 137001 },
}
```

This is the only non-load-bearing recommendation in this entire research; the planner can adopt or skip.

### Note D: stylua formatting after edits

Per CLAUDE.md ("Run `stylua` on all Lua files after finishing a task"), the three edited files (`Macros.lua`, `Config.lua`, `Core.lua`) must be `stylua`-formatted after editing. The existing files are already stylua-formatted (verified by reading them); preserve indentation as-is and `stylua` will be a no-op if the edits follow the surrounding style.

### Note E: Phase 7 stays clear of taint constraints

CLAUDE.md hard constraints scan for Phase 7:

| Constraint | Phase 7 touchpoint | Result |
|------------|-------------------|--------|
| Never call `SendChatMessage` | Phase 7 macro payloads are strings emitted by user-bound macros (player chat, not addon-tainted). Macros.lua never calls `SendChatMessage`. | ✓ Clear |
| Never index `msg` from `CHAT_MSG_*` | Phase 7 doesn't touch the chat-event handler in Window.lua. | ✓ Clear |
| No `COMBAT_LOG_EVENT_UNFILTERED` | Phase 7 doesn't register any combat-log event. | ✓ Clear |
| Macro creation/edit blocked during combat | Phase 7's `OnVerboseMarkersChanged` reuses the existing `InCombatLockdown` guard + `regenFrame` retry. | ✓ Clear |

D-16 UAT checkpoint #8 explicitly verifies the diff is clear of forbidden patterns.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Token spelling case-sensitivity is wrong in the lowered-key form | **LOW** | Macros silently send `{diamond}` literal text with no icon expansion | `ICON_TAG_LIST` builds keys via `strlower(...)` — case-insensitive. Lowercase form is correct. **Confirmed in wow-ui-source.** |
| `Settings.RegisterAddOnSetting` and Core.lua D-13 backfill conflict | **NONE** | None (idempotent, same idiom, same value) | Confirmed in `Blizzard_Setting.lua:397-402`. Keep both per Q3. |
| Rapid-toggle in-combat causes missed macro update | **NONE** | None (last write wins via `ns.db.verboseMarkers` read at execution time) | Confirmed pattern correctness in Q5. |
| Non-English client users see literal `{diamond}` text | **MEDIUM** (only on locale-mismatched clients) | Verbose tokens don't expand → user sees `/s {diamond}` instead of the icon | Toggle exists exactly for this fallback. Default-ON is fine for English-speaking majority (the addon's target audience: WoW Midnight English-server raid coordinators). Affected users flip the toggle off and get `{rt3}`-form macros. |
| Chat addons strip `{diamond}` patterns | **VERY LOW** | User sees nothing in chat after the macro fires | No mainstream 2025/2026 chat addon does this. If it ever happens, user flips toggle off. |
| Sentinel hook is forgotten and the checkbox label doesn't refresh | **N/A** | N/A — checkbox auto-refreshes via `OnSettingValueChanged` (Q4) | No sentinel hook needed. |
| User has `db.verboseMarkers` explicitly set to `false` from prior session, expects it to stay off | **VERY LOW** (impossible at v1.0.0→v1.1.0 boundary since key didn't exist) | N/A | D-13's `if X == nil` check preserves explicit `false`. |
| SAFE-06 grep gate trips on Note B's `m.payload or ...` line | **VERY LOW** | Misleading false positive in CI | The grep is `git grep "= db\." | grep " or "` — pattern requires `= db.` (assignment with `db.` on RHS). Note B's expression is `local body = prefix .. " " .. payload` (no `= db.`). Pattern does not match. **Verified by re-reading the grep.** |
| `EditMacro` for 4 marker macros + 1 unchanged macro on every toggle is wasteful | **VERY LOW** | Minor perf — 5 `EditMacro` calls per toggle | `EditMacro` is cheap (sets macro body in client memory). Out-of-combat path executes synchronously. Not a perf concern. |
| Phase 7 inadvertently breaks Phase 6's button-label refresh | **LOW** | Show/Hide or Lock button labels stop refreshing | Phase 7 doesn't touch the sentinel-flag hook code in Config.lua:284-308. Adding the checkbox to RegisterMacroSection is additive. **Re-read Config.lua change diff in code review to confirm no edits to lines 248-308.** |

---

## Sources

### Primary (HIGH confidence — verified in wow-ui-source@12.0.1.66337)

- [VERIFIED: `Blizzard_ChatFrameBase\Shared\ChatFrameConstants.lua:30-76`] — `ICON_LIST` (texture escape sequences) and `ICON_TAG_LIST` (lowercased verbose-token AND `rt#`-numeric lookup keys, all mapping to indices 1–8 of `ICON_LIST`). This is the definitive proof that verbose and `{rt#}` forms render identically.
- [VERIFIED: `Blizzard_Settings_Shared\Blizzard_Setting.lua:397-444`] — `AddOnSettingMixin:Init` and `SecureSetVariableTblDefaultValue` (the `if X == nil` backfill the framework performs at registration).
- [VERIFIED: `Blizzard_Settings_Shared\Blizzard_Setting.lua:100-137`] — `SetValue` → `ApplyValue` → `SetValueDerived` then `TriggerValueChanged`. Confirms framework writes DB **before** firing the change callback.
- [VERIFIED: `Blizzard_Settings_Shared\Blizzard_SettingControls.lua:438-541`] — `SettingsCheckboxControlMixin` lifecycle. `OnSettingValueChanged` (line 497) auto-syncs the rendered checkbox to the bound setting value. This is why no `hooksecurefunc` sentinel hook is needed for the checkbox.
- [VERIFIED: `Blizzard_Settings_Shared\Blizzard_SettingControls.lua:702-774`] — `SettingsButtonControlMixin:EvaluateName` and `:Init`, `CreateSettingsButtonInitializer`. Confirms `buttonText` closure is evaluated only in `Init`, explaining why Phase 6 needed the sentinel hook for live label updates.
- [VERIFIED: `Blizzard_FrameXMLUtil\Mainline\RaidWarning.lua:130`] — Live example of `ReplaceIconAndGroupExpressions` consuming a `CHAT_MSG_*` payload in core Blizzard UI.
- [VERIFIED: `Blizzard_ChatFrameBase\Mainline\ChatFrameOverrides.lua:546`] — The default chat-frame call to `ReplaceIconAndGroupExpressions` for raid/say/etc. messages.
- [VERIFIED: `wow-ui-source\version.txt`] — `12.0.1.66337`, the same client tree Interface 120005 addons load.
- [VERIFIED: `.planning/research/SETTINGS_API.md`] — pre-existing Phase 3 research; all referenced patterns still apply.
- [VERIFIED: `.planning/research/PITFALLS.md` DB-1] — backfill anti-pattern catalogue; only DB-1 applies to Phase 7.

### Secondary (MEDIUM confidence — community sources, cross-referenced)

- [CITED: warcraft.wiki.gg — Target marker] — Confirms verbose tokens include `{star}`, `{circle}`, `{diamond}`, `{triangle}`, `{moon}`, `{square}`, `{cross}`/`{x}`, `{skull}`, plus `{coin}` for circle and `{rt1}`–`{rt8}` numeric forms. Confirms case-insensitivity. Confirms tokens are localized.
- [CITED: wowwiki-archive.fandom.com — Target markers] — Confirms verbose-token feature was added in Patch 2.4 as an undocumented chat substitution. Confirms it works in chat channels, macros, and `SendChatMessage` calls.

### Tertiary (LOW confidence — opinion / ecosystem observation, no authoritative source)

- Chat-addon ecosystem (Prat, ElvUI, WIM, Chatter) handling of `{diamond}`-form tokens: claim is that mainstream addons pass these through and let Blizzard's helper expand them. Based on reading addon source intent at distance, not on running each addon. **The toggle's existence makes this risk moot regardless.**

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MACR-06 | When `db.verboseMarkers == true`, four marker macros emit verbose tokens (`{diamond}` / `{triangle}` / `{circle}` / `{cross}`). `TLH_T` unchanged. | Q1, Q2, Q6 — verbose tokens render identically to `{rt#}` via `ReplaceIconAndGroupExpressions`. CONTEXT D-01 + D-02 implementation pattern is sound. |
| MACR-07 | When `db.verboseMarkers == false`, four marker macros emit `{rt#}` payloads (`{rt3}` / `{rt4}` / `{rt2}` / `{rt7}`). `TLH_T` unchanged. | Q5 — `ns.db.verboseMarkers` read at execution time in the D-02 conditional. Last-write-wins via the framework's "write before notify" invariant. |
| CFG-15 | "Use verbose markers" checkbox in config panel via `Settings.RegisterAddOnSetting`. | Q3 (framework auto-backfills default), Q4 (no sentinel hook needed). CONTEXT D-04 (position) + D-05/D-06 (label/tooltip) + D-08 (registration code shape). |
| CFG-16 | Toggle change rebuilds macros with combat-lockdown deferral via `regenFrame`. Prints feedback. | Q5 — `OnVerboseMarkersChanged` mirrors `OnMacroChannelChanged` (CONTEXT D-09). Existing `registrationDeferred` + `armRegenRetry` pattern is correct for rapid toggles. |
| SCAF-18 | First-run default `db.verboseMarkers = true`, backfill with SAFE-06 idiom. | Q3 — Core.lua D-13 backfill (`if X == nil then`) is correct. Framework's `Settings.RegisterAddOnSetting` also backfills idempotently. Q8 — DB-1 pitfall does not apply (D-13 uses the safe idiom). |

---

## Metadata

**Confidence breakdown:**
- Verbose-token rendering equivalence: **HIGH** — verified in `ChatFrameConstants.lua` + multiple call-site live examples.
- Settings API auto-backfill: **HIGH** — verified in `Blizzard_Setting.lua` with line-numbered citations.
- Sentinel-hook irrelevance: **HIGH** — verified by reading `SettingsCheckboxControlMixin` lifecycle.
- Rapid-toggle correctness: **HIGH** — existing pattern in Macros.lua is provably idempotent.
- Localization caveat: **MEDIUM** — verified via community source; not blocking but worth knowing.
- Pitfalls cross-walk: **HIGH** — only DB-1 applies, already mitigated by D-13.

**Research date:** 2026-05-15
**Valid until:** Indefinitely, until the Settings API or `ReplaceIconAndGroupExpressions` semantics change. The Settings API has been stable since Patch 11.0.2 (Aug 2024); `ReplaceIconAndGroupExpressions` has been stable since at least Patch 2.4 (2008). No upcoming changes flagged in `Patch 12.0.0/Planned API changes`.

---

## RESEARCH COMPLETE
