---
phase: 07-verbose-marker-toggle
plan: 01
status: complete
uat_status: passed
uat_completed: 2026-05-16 (combined Phase 7+8 session)
commits:
  - aeca02b feat(07-01) dual-field MACROS + payload-selection + OnVerboseMarkersChanged
  - e9840a3 feat(07-01) db.verboseMarkers fresh-install default + SAFE-06 backfill
  - 570fefe feat(07-01) (3aa) Use-verbose-markers checkbox in Config Macros section
  - b1fd8a2 chore(07-01) stylua format pass after Task 1 edits
  - "[AMEND-07-01-UAT-01] feat(07) verbose default OFF + revised tooltip (post-UAT 2026-05-16)"
files_modified:
  - Macros.lua
  - Core.lua
  - Config.lua
requirements_addressed:
  - MACR-06
  - MACR-07
  - CFG-15
  - CFG-16
  - SCAF-18
gates:
  stylua_check: pass
  safe_06_grep: pass (zero matches)
  taint_regression: pass (zero new SendChatMessage/:gsub/:match/#msg/msg[ additions)
  install_bat: pass (7 files deployed to WoW retail addons folder)
  in_game_uat: passed (8/8 checkpoints in combined Phase 7+8 session 2026-05-16)
last_updated: 2026-05-16
---

# Phase 7-01: Verbose-Marker Toggle — Implementation Summary

## Status: Complete

All four autonomous tasks (1-4) shipped, gated, and validated. Task 5's 8-checkpoint UAT passed during the combined Phase 7+8 in-game session on 2026-05-16 (deferred from initial implementation per the v1.0.0 Phase 5+6 combined-UAT pattern). A late-UAT semantic refinement (AMEND-07-01-UAT-01 below) flipped the default and rewrote the tooltip; the post-flip behavior was re-tested in the same session and passed.

## What Was Built

### Macros.lua
- **Dual-field `MACROS` table** — four marker rows gained `payloadVerbose` + `payloadRT` fields (`{diamond}`+`{rt3}`, `{triangle}`+`{rt4}`, `{circle}`+`{rt2}`, `{cross}`+`{rt7}`). `TLH_T` row unchanged (single `payload = "T"` field).
- **Payload-selection conditional** in `RegisterMacros` for-loop: `local payload = m.payload or (ns.db.verboseMarkers and m.payloadVerbose or m.payloadRT)`. `m.payload` short-circuits for `TLH_T`; falls through to `db.verboseMarkers` for the four marker macros. Read expression — does NOT match the SAFE-06 grep gate.
- **New exported function `ns:OnVerboseMarkersChanged(value)`** mirroring `OnMacroChannelChanged`: combat-branch defers via existing `regenFrame`, out-of-combat rebuilds immediately. Print copy:
  - Immediate: `TLH: Verbose markers on/off. Macros updated.`
  - Deferred: `TLH: Verbose markers on/off. Macros will update when you leave combat.`

### Core.lua
- **Fresh-install default** `verboseMarkers = true` added to the inline `TerribleLuraHelperDB` table after `macroChannel = "SAY"`.
- **SAFE-06 nil-check backfill** appended to the backfill block: `if db.verboseMarkers == nil then db.verboseMarkers = true end`. Explicit `false` values are preserved.

### Config.lua
- **New `(3aa)` checkbox** in `RegisterMacroSection` between `(3a)` macro-target dropdown and `(3b)` Recreate button.
- Setting: `Settings.RegisterAddOnSetting(category, "TLH_VERBOSE_MARKERS", "verboseMarkers", db, Settings.VarType.Boolean, "Use verbose markers", true)`.
- Callback: `setting:SetValueChangedCallback(function(_, value) ns:OnVerboseMarkersChanged(value) end)` — framework auto-writes `db.verboseMarkers` before the callback fires.
- Tooltip (locale-aware refinement of CONTEXT D-06 per RESEARCH Q7): `"When on, macros emit {diamond} / {triangle} / {circle} / {cross} — these render correctly in most modern chat addons. Turn off if you play on a non-English client or your chat addon doesn't expand the verbose names. The 5th macro (TLH_T) sends the letter T either way."`
- **No sentinel-flag hook** for the checkbox — `SettingsCheckboxControlMixin:OnSettingValueChanged` auto-syncs the rendered control. Phase 6 sentinel-hook code (lines 248-308) unchanged.

## Verified Gates (Pre-UAT)

| Gate | Result |
|------|--------|
| `stylua --check Macros.lua Core.lua Config.lua` | exit 0 |
| `git grep "= db\." -- '*.lua' \| grep " or "` (SAFE-06) | zero matches |
| `git diff -- '*.lua' \| grep -E '^\+.*(SendChatMessage\|:gsub\|:match\|#msg\|msg\[)'` (taint regression) | zero lines |
| `./scripts/install.bat` | 7 files deployed to WoW retail addons folder |
| Phase 6 sentinel-hook code in Config.lua (lines 248-308 pre-edit) | unchanged |

## UAT — Deferred (8 checkpoints to run after Phase 8 code lands)

The full 8-checkpoint UAT from `07-CONTEXT.md` §D-16 and `07-01-PLAN.md` Task 5 will run in a combined session covering Phase 7 and Phase 8 after Phase 8 ships. Preserved here for that run:

1. **Fresh install** — `/run TerribleLuraHelperDB = nil` + `/reload`; verify five macro bodies (`/s {diamond}`, `/s {triangle}`, `/s {circle}`, `/s {cross}`, `/s T`) and "Use verbose markers" checkbox checked between the channel dropdown and the Recreate button in the Macros section.
2. **Toggle OFF (out of combat)** — uncheck the box; chat prints `TLH: Verbose markers off. Macros updated.`; `/macro` shows rt# bodies.
3. **Toggle ON (out of combat)** — re-check; chat prints `TLH: Verbose markers on. Macros updated.`; verbose bodies back.
4. **Toggle in combat** — engage dummy; toggle the checkbox; chat prints `TLH: Verbose markers <on|off>. Macros will update when you leave combat.`; bodies stay until `PLAYER_REGEN_ENABLED` fires.
5. **Upgrade-safe backfill** — `/run TerribleLuraHelperDB.verboseMarkers = nil` + `/reload`; checkbox is checked (default ON applied via backfill).
6. **End-to-end verbose ON** — press `TLH_Diamond` on action bar; `/s` shows the diamond marker icon.
7. **End-to-end verbose OFF** — toggle off; press `TLH_Diamond`; `/s` shows the same diamond icon (rendered from `{rt3}` this time); helper window renders the rune in both forms.
8. **Regression guard** — already verified at commit time; no in-game step needed.

## AMEND-07-01-UAT-01: Verbose default flipped ON → OFF (2026-05-16)

During the combined Phase 7+8 UAT, after Block A passed cleanly, the user revised the toggle's framing: since `{diamond}`/`{triangle}`/`{circle}`/`{cross}` only render on English WoW clients (`ICON_TAG_LIST` keys go through locale-loaded global strings, per RESEARCH Q7), any raid group with even one non-English-client player would see broken markers if verbose is on. `{rt#}` codes are universal across all client locales.

**Change:** `db.verboseMarkers` default flipped `true` → `false` in both the fresh-install defaults table (`Core.lua:66`) and the SAFE-06 nil-check backfill (`Core.lua:106`). Settings.RegisterAddOnSetting's default arg flipped to `false` (`Config.lua:364`). Tooltip rewritten to lead with the localization warning:

> "Switches the four marker macros from {rt2} / {rt3} / {rt4} / {rt7} to {circle} / {diamond} / {triangle} / {cross}. WARNING: verbose names only render on English WoW clients — if anyone in your raid runs a non-English client, leave this OFF. The default {rt#} markers are universal across all locales. The 5th macro (TLH_T) sends the letter T either way."

**Semantic shift:** the toggle was originally framed as "verbose ON = the modern good behavior; OFF = fallback for broken setups". Post-UAT it's reframed as "OFF (universal `{rt#}`) = safe default for any group; ON (verbose) = opt-in for English-only groups". The chat-print messages on toggle change (`TLH: Verbose markers on. Macros updated.` etc.) work in either direction unchanged.

**Gates re-run after the flip:** stylua --check OK, SAFE-06 zero matches, taint regression zero matches, install.bat re-deployed.

## Notes & Deferred Ideas

- **Localization caveat surfaced by research (now the primary framing):** `{diamond}` only renders on English-locale WoW clients (`ICON_TAG_LIST` keys go through locale-loaded global strings). `{rt#}` is universal. Tooltip leads with this; toggle defaults OFF so the universal behavior is the out-of-box experience.
- **No `/lura verbose on|off` slash command** in v1.1.0 — CFG-15 specifies a config-panel checkbox only. Deferred for a future milestone if user feedback requests it.
- **No auto-detect of chat-addon verbose-token support** — fragile and overengineered; the toggle is the user-controlled fallback.

## Files Modified

| File | Lines (final) | Diff (vs base 25899ea) |
|------|---------------|------------------------|
| `Macros.lua` | ~155 | +32/-6 |
| `Core.lua` | ~209 | +4 |
| `Config.lua` | ~466 | +30 |

Total: +66/-6 across 3 files, 0 new files.
