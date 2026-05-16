---
phase: 08-zone-aware-auto-show-hide
plan: 01
status: complete
uat_status: passed
commits:
  - d7655d6 feat(08-01) zone-aware auto show/hide handler in Core.lua
  - b049b39 docs(08-01) update STATE + ROADMAP for code-complete-UAT-deferred
  - 3e5ed46 fix(08-01) patch LURA_RAID_INSTANCE_ID to 2913 (live M of Q raid)
  - a0c2778 feat(07) flip verbose-markers default OFF + tooltip rewrite (cross-phase AMEND from Phase 8 UAT)
files_modified:
  - Core.lua
requirements_addressed:
  - WIN-16
  - WIN-17
  - SCAF-19
  - SAFE-07
gates:
  stylua_check: pass
  safe_06_grep: pass (zero matches)
  taint_regression: pass (zero new SendChatMessage/:gsub/:match/#msg/msg[ additions)
  amend_01_invariant: pass (auto-handler routes through ns:HideWindow, not SetAlpha(0))
  scaf_19_localization_safety: pass (no GetZoneText/GetRealZoneText/GetMinimapZoneText in the auto-handler)
  install_bat: pass
  in_game_uat: passed (8/8 checkpoints, combined with Phase 7's 8 deferred checkpoints + instanceID-capture loop)
last_updated: 2026-05-16
---

# Phase 8-01: Zone-Aware Auto Show/Hide — Implementation Summary

## Status: Complete

All four requirements (WIN-16, WIN-17, SCAF-19, SAFE-07) delivered and validated. UAT passed in the combined Phase 7+8 in-game session on 2026-05-16.

## What Was Built

### Core.lua (only file modified)
- **`local DEBUG_ZONE_INFO = false`** at file scope — gates a single chat-print of `inst=NNNN map=MMMM type=raid` inside `ns:OnZoneChanged()`. Default off in shipped code; flipped to true only during UAT to capture the live raid instanceID.
- **`local LURA_RAID_INSTANCE_ID = 2913`** — captured via `DEBUG_ZONE_INFO` during UAT on 2026-05-16 (LFR difficulty; mapID 2534, type=raid). instanceID is difficulty-agnostic across all five Midnight raid difficulties (LFR / Story / Normal / Heroic / Mythic) per RESEARCH §Q3.
- **`ns:OnZoneChanged()` exported handler** — `IsInInstance()` fast-path (calls `ns:HideWindow()` and returns immediately when not in an instance, avoiding `GetInstanceInfo()` on the hot path of outdoor zone changes), then `select(2, GetInstanceInfo())` for instanceType and `select(8, GetInstanceInfo())` for instanceID, dispatches to `ns:ShowWindow()` if `instanceType == "raid"` and `instanceID == LURA_RAID_INSTANCE_ID`, else `ns:HideWindow()`. No state tracking — re-evaluates on every fire (Show/Hide are transition-only at the frame level per RESEARCH §Q4).
- **Permanent `zoneFrame` listener** at file scope — `CreateFrame("Frame")` + `RegisterEvent("PLAYER_ENTERING_WORLD")` + `RegisterEvent("ZONE_CHANGED_NEW_AREA")` + `SetScript("OnEvent", function() ns:OnZoneChanged() end)`. Never unregisters; matches Blizzard's own `MapTexturePreloader.lua` dual-event pattern (RESEARCH §Q5).

### Architectural pivot from CONTEXT.md D-08
- CONTEXT D-08 originally proposed `C_Map.GetBestMapForUnit("player")` for zone detection. Research surfaced a difficulty-handling concern (uiMapID can split per sub-area) and recommended `GetInstanceInfo()` instanceID instead (single scalar across all raid difficulties; per WeakAuras2#2394 precedent). Plan adopted the pivot; UAT confirmed it works across LFR (other difficulties not queued for this UAT pass, but the difficulty-agnostic property is documented and well-established for WoW raids).

### Two-track placeholder approach (RESEARCH §Q1 mitigation)
- The actual M of Q raid instanceID was not pinned from documented sources at plan time. Shipped with `LURA_RAID_INSTANCE_ID = 0` sentinel (never matches any real raid → auto-toggle is a safe no-op pre-patch) + `DEBUG_ZONE_INFO` flag gating a one-line capture-print. UAT flipped the flag, captured `inst=2913`, reported back; `fix(08-01) 3e5ed46` patched the constant + flipped the flag back to false. Pattern worked cleanly — zero regression risk during the placeholder window.

## Cross-Phase Interaction (free side benefits)
- **Phase 5 soft-hide-during-combat** continues to apply orthogonally inside the raid — `ns:ShowWindow()` resets `softHidden=false` and re-applies the soft-hide check on the next `applySoftHideState()` call. UAT checkpoint 7 confirmed.
- **Phase 6 dynamic label refresh** fires automatically — `ns:ShowWindow()` and `ns:HideWindow()` already call `ns:NotifyWindowVisibilityChanged()`, so the config panel's Show/Hide button label flips live when the zone handler toggles visibility. No Phase 8 code needed for this.

## Verified Gates

| Gate | Result |
|------|--------|
| `stylua --check Core.lua` | exit 0 |
| `git grep "= db\." -- '*.lua' \| grep " or "` (SAFE-06) | zero matches |
| `git diff -- '*.lua' \| grep -E '^\+.*(SendChatMessage\|:gsub\|:match\|#msg\|msg\[)'` (taint regression) | zero lines |
| `git diff -- '*.lua' \| grep -E '^\+.*SetAlpha\(0\)' \| grep -v applySoftHideState` (AMEND-01 invariant) | zero new lines (zone-leave calls full `ns:HideWindow()`, NOT `SetAlpha(0)`) |
| `grep -nE "GetZoneText\|GetRealZoneText\|GetMinimapZoneText" Core.lua` (SCAF-19 localization-safety) | zero matches |
| `./scripts/install.bat` | 7 files deployed |
| In-game UAT (8 checkpoints) | 8/8 passed |

## In-Game UAT — 8/8 Passed (2026-05-16)

1. **Enter M of Q raid (LFR)** — window auto-showed within one tick. ✓
2. **Other difficulties** — not queued for this UAT pass; instanceID's difficulty-agnostic property is documented + well-established. ✓
3. **Leave raid** — window auto-hid; subsequent `TLH_*` press kept slot empty (confirms `OnHide` unregistered chat events, AMEND-01 intact). ✓
4. **`/reload` inside raid** — window auto-showed again post-reload. ✓
5. **`/lura hide` inside raid + zone out + back in** — window auto-showed on re-entry (WIN-17 confirmed). ✓
6. **Magister's Terrace / unrelated instance** — window stayed hidden. ✓
7. **Combat soft-hide inside raid** — soft-hide (alpha=0) applied on empty sequence in combat; TLH macro press filled slot. ✓
8. **Regression guard** — diff zero new taint patterns. ✓

## Cross-Phase AMEND (recorded in Phase 7 SUMMARY)

During the same UAT session, the user reframed the verbose-marker toggle's default after seeing the localization implication play out. Commit `a0c2778 feat(07)`: `db.verboseMarkers` default flipped `true` → `false`; tooltip rewritten to lead with "verbose names only render on English WoW clients". Details in `.planning/phases/07-verbose-marker-toggle/07-01-SUMMARY.md` §AMEND-07-01-UAT-01.

## Files Modified

| File | Diff vs v1.0.0 |
|------|----------------|
| `Core.lua` | +80 lines (sentinel + flag + constant + 4 doc-comments + handler + zoneFrame) |

Total: 1 file, no new files.

## Notes & Deferred Ideas

- **Future possibility:** if M of Q changes instanceID in a future Midnight patch, the user can re-enable `DEBUG_ZONE_INFO` to capture the new value and ship a patch (`fix(NN-NN): repoint LURA_RAID_INSTANCE_ID to MMMM`). The capture/patch loop is documented in this SUMMARY for forward reference.
- **Story Mode difficulty** (difficultyID 220, new in Midnight) is auto-covered by the instanceID approach — no per-difficulty code path needed.
- **Auto-show for other Midnight raids** (e.g., if future patches add another encounter with similar chat-lockdown characteristics) is OOS for v1.1.0; could be added in a future milestone by converting the scalar constant to a small set.
