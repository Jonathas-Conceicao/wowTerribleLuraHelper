# Phase 8: Zone-Aware Auto Show/Hide — Technical Research

**Researched:** 2026-05-16
**Domain:** WoW Midnight (Interface 120005+) — `C_Map` / `GetInstanceInfo` / zone event handling
**Confidence:** HIGH on API + event semantics; **MEDIUM/LOW** on the specific M of Q raid instanceID (no public datamine source surfaced; verified two candidates worth probing in-game).

---

## User Constraints (from CONTEXT.md)

### Locked Decisions
The 17 implementation decisions in `08-CONTEXT.md` are locked. This research does NOT re-open any of them. The only research-driven amendments below are:
- **Amendment to D-02 (number of difficulties):** Midnight raids ship with **5** difficulty modes, not 4 (LFR + **Story** + Normal + Heroic + Mythic). Story Mode is new this expansion and is the first solo-raid difficulty. Planner should treat Story Mode as a 5th "in-zone" difficulty unless the user explicitly excludes solo content (open question Q1 below).
- **Amendment to D-08 (mapID-lookup API):** Recommended primary API changes from `C_Map.GetBestMapForUnit("player")` to **`GetInstanceInfo()` → select(8) instanceID** — see Q3 for the architectural reasoning. Two-track fallback identified below if the planner prefers to stay on `C_Map`.

### Claude's Discretion
The Claude's-Discretion items in CONTEXT.md remain open; this research surfaces evidence the planner can use to settle them:
- API choice (research recommends `GetInstanceInfo` + `select(8)` over `C_Map.GetBestMapForUnit`).
- Constant shape (`scalar` is sufficient; instanceID is shared across all 5 difficulties — see Q3).
- Optional debug print at addon-load — recommendation: **YES**, gated behind a local `DEBUG = false` constant, because the actual instanceID will be captured during UAT and we'd rather print it once than ask the user to `/dump`. See Q1 (M of Q raid instanceID) — the live value cannot be pinned down from documentation alone.

### Deferred Ideas (OUT OF SCOPE)
All items in CONTEXT.md `<deferred>` remain out of scope: outdoor-zone auto-show, adjacent-instance auto-show, configurable in-zone set, print feedback on zone-auto fires, kill-switch toggle, manual-state persistence, per-character verbose-marker preference. This research does not propose adding any of them.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WIN-16 | Register `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA`; query mapID; route via existing Show/Hide. | Q2 confirms both events are required (Q5 firing order); Q3 picks the correct API (`GetInstanceInfo` recommended over `C_Map.GetBestMapForUnit`); Q4 confirms re-fires are free. |
| WIN-17 | Manual `/lura show|hide` re-evaluated on next zone event; `/reload` inside raid auto-shows. | Q5: PLAYER_ENTERING_WORLD fires reliably on `/reload`. Q4: Show on already-shown is a no-op so the re-evaluation is idempotent. |
| SCAF-19 | Hardcoded numeric constant(s); localization-safe; no zone-name strings. | Q1: actual ID couldn't be pinned from docs — recommend two-track approach (placeholder constant + one-time debug print). Q3: a single scalar is correct (instanceID is shared across all 5 difficulties). |
| SAFE-07 | Routes through `Show()` / `Hide()` (not `SetAlpha(0)`); AMEND-01 chat-event registration invariant preserved. | Q9 (PITFALLS audit): no AMEND-01-breaking patterns are introduced. Q10 (Blizzard's reference pattern) uses the same architecture. |

---

## Summary Table

| # | Question | Verdict | Confidence | Primary Source |
|---|----------|---------|------------|----------------|
| 1 | **M of Q raid mapID(s) — exact value(s)?** | **Unknown from docs.** Two candidate numbers exist: `2424` is the *outdoor* Isle of Quel'Danas mapID (NOT what we want); `16342` appears as a "zone identifier" external-link on warcraft.wiki.gg's M-of-Q page but its type is unverified. **Recommend two-track plan: ship with a TODO placeholder + a one-time addon-load debug print that captures the live instanceID, then patch in v1.1.0-rc.** | **LOW** (no documented value) | warcraft.wiki.gg M of Q wiki page (external link `wowdb.com/zones/16342`); Wowhead `/way #2424` coordinates |
| 2 | Canonical mapID-lookup API for Midnight | **`GetInstanceInfo()` → `select(8)` for instanceID** is the recommended primary API for THIS use case. `C_Map.GetBestMapForUnit("player")` is the correct API for "where on the map am I" semantics but is NOT what we want — see Q3. | HIGH | `wow-ui-source` `InstanceDocumentation.lua` + `MapDocumentation.lua` |
| 3 | `GetInstanceInfo` instanceID vs `C_Map` uiMapID — which is right? | **instanceID via `GetInstanceInfo()`.** It is shared across all 5 raid difficulties (LFR/Story/Normal/Heroic/Mythic) — difficulty is a separate axis (return position 3, `difficultyID`). uiMapID via `C_Map.GetBestMapForUnit` can split per-sub-area (e.g. Sunwell historically has uiMapIDs 335 AND 336) which would force a set-check. instanceID is one scalar per raid. | HIGH | `wow-ui-source`+ WeakAuras issue #2394 evidence; Wowpedia API_GetInstanceInfo |
| 4 | `OnShow` / `OnHide` re-fire semantics | **Transition-only.** Calling `:Show()` on already-shown frame is a no-op; `:Hide()` on already-hidden is a no-op. Validates D-07 ("re-evaluate on every event fire" is free). | HIGH | WoWInterface forum + warcraft.wiki.gg `Widget_script_handlers` |
| 5 | PLAYER_ENTERING_WORLD vs ZONE_CHANGED_NEW_AREA firing order | **Both are needed.** PLAYER_ENTERING_WORLD fires on initial login, `/reload`, and every map-instance transition (loading screen). ZONE_CHANGED_NEW_AREA fires on later in-session zone transitions (and inconsistently at session start). Belt-and-suspenders registration of both is the correct pattern — matches Blizzard's own `MapTexturePreloader.lua`. | HIGH | warcraft.wiki.gg `AddOn_loading_process`; `MapTexturePreloader.lua` (wow-ui-source) |
| 6 | PLAYER_ENTERING_WORLD args | `isInitialLogin` (true on character login), `isReloadingUi` (true on `/reload`). Both false when zoning between map instances mid-session. Phase 8 does not need to differentiate — D-07 re-evaluates on every fire — but planner should add `local isInitialLogin, isReloadingUi = ...` to the handler signature for clarity and any optional debug-print branching. | HIGH | warcraft.wiki.gg `PLAYER_ENTERING_WORLD`; `wow-ui-source` `Blizzard_CodeOfConduct.lua:1` |
| 7 | Zone-event safety during combat | **Safe.** PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA are not combat-locked. `GetInstanceInfo()` and `C_Map.GetBestMapForUnit("player")` are both untainted reads (`AllowedWhenUntainted` and unannotated respectively — both safe). `ns:ShowWindow()` / `ns:HideWindow()` already run via Settings panel button during combat without issue (no protected-frame calls). | HIGH | `wow-ui-source` `MapDocumentation.lua:51`, `InstanceDocumentation.lua:88-104`; CLAUDE.md MEMORY note (combat-taint scope) |
| 8 | Midnight-specific zone-event changes | **One material change:** raids in Midnight now have **5 difficulty modes** (added Story Mode at difficultyID 220). Affects D-02's mental model ("4 difficulties") but does NOT change the implementation if Phase 8 uses instanceID — Q3 — because instanceID is difficulty-agnostic. | HIGH | warcraft.wiki.gg `DifficultyID`; Wowhead Midnight raid news |
| 9 | Applicable PITFALLS | One existing pitfall partially applies: **AH-1** (PLAYER_REGEN_ENABLED fires on initial login). The Phase 8 analog: PLAYER_ENTERING_WORLD fires on initial login — but here the firing is *intentional and desired* (it's how we route the correct visibility at session start). No code change needed. **Three new pitfalls** identified: ZONE-1 (event re-fires from sub-zone transitions), ZONE-2 (instanceID returns 0 for non-instance), ZONE-3 (PLAYER_ENTERING_WORLD vs ADDON_LOADED interaction with `db.window.visible`). See §"New Pitfalls" below. | HIGH | PITFALLS.md AH-1; this research |
| 10 | Reference implementations in wow-ui-source | `Blizzard_WorldMap/MapTexturePreloader.lua` (full file, lines 1-26) — **exactly** the pattern Phase 8 needs: permanent frame, PLAYER_ENTERING_WORLD + zone event(s), idempotent on-every-fire handler, queries `C_Map.GetBestMapForUnit("player")`. Phase 8 swaps the API call but is otherwise structurally identical. Secondary: `Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:501-502` (ZONE_CHANGED_NEW_AREA + ZONE_CHANGED registered together). | HIGH | wow-ui-source@12.0.1 |

---

## Detailed Answers

### Q1: M of Q raid mapID(s) — the user-flagged priority

**Verdict:** **The exact raid-instance mapID/instanceID cannot be pinned from documented sources at research time.** Recommend a **two-track plan**.

**What the search found:**

- The raid is officially called **"March on Quel'Danas"** (preposition "on", not "of" — minor naming nit but no functional impact; the user's verbal shorthand "M of Q" is universally understood). [Icy Veins · Wowhead](https://www.wowhead.com/guide/midnight/raids/march-on-quel-danas-overview-location-rewards-bosses)
- It is a 2-boss raid (Belo'ren, Child of Al'ar → Midnight Falls). **L'ura is part of the final encounter ("Midnight Falls").** The user's CLAUDE.md confirms this is the entire reason the addon exists. [Wowhead L'ura NPC 240391](https://www.wowhead.com/npc=240391/lura/raid-finder-encounter-journal)
- The raid is located in the Isle of Quel'Danas zone. The Wowhead-format entrance coordinate is `/way #2424 52.61 85.75`. **The `2424` in that coordinate is the uiMapID for the *outdoor* Isle of Quel'Danas — NOT the raid-instance mapID.** Walking onto the raid teleporter does NOT change uiMapID to 2424 (you're still in the outdoor zone); only crossing the loading screen into the raid does, at which point uiMapID becomes the raid's own value.
- `warcraft.wiki.gg/wiki/March_on_Quel'Danas` has an external-link panel pointing to `wowdb.com/zones/16342`. The number `16342` is in the right magnitude for a zone/instance ID but **the wiki page does not specify whether it is a uiMapID, an instanceID, or a wowdb-internal area ID.** WebFetch on the wowdb URL returned HTTP 403. WebSearch did not corroborate `16342` as a uiMapID. **Confidence: LOW.**
- `wow-ui-source@12.0.1` (the local Blizzard UI source tree) does NOT reference "Quel'Danas", "L'ura", "Midnight Falls", or "March on" anywhere in the FrameXML — confirming the raid data lives in the client-only CASC archive and is not exposed in UI Lua. We cannot grep for it.

**Why this matters for the plan:** The user explicitly flagged this as the top research output. Honest reporting: I do not have a verified value to give the planner. Three options for the plan:

1. **Two-track recommended approach:** Ship the addon with a `TODO_LURA_INSTANCE_ID` placeholder (e.g., `local LURA_RAID_INSTANCE_ID = 0` — a value that will never match real raid IDs which are always positive) AND a one-time addon-load debug print (gated behind a local `DEBUG_ZONE_INFO = false` constant defaulting to true for the v1.1.0 dev cycle, flipped to false before release). The debug print outputs both `select(8, GetInstanceInfo())` and `C_Map.GetBestMapForUnit("player")` on every zone event so the user captures the live value in UAT, then we patch the constant before the v1.1.0 release tag.

2. **Capture-via-`/dump` task:** Per D-04, the plan adds a UAT task: "Run `/dump select(8, GetInstanceInfo())` immediately upon zoning into the raid (any difficulty). Report the number back to Claude before merging Phase 8." Then the constant gets patched in a follow-up commit before release.

3. **Speculative best-guess + UAT verification:** Use `16342` from the wiki external link as a starting point and verify at UAT. **Not recommended** — wiki external-link numbers are often wowdb's own internal IDs, not Blizzard uiMapIDs. High risk of needing to patch.

**Recommended:** Option 1 (two-track placeholder + debug print) is the lowest-risk path. It makes the addon SAFE to ship even with the wrong constant (no zone matches → window never auto-shows → no regression of existing `/lura show` behavior); and the debug print self-documents the correct value for the patch commit. The placeholder constant can use a sentinel that obviously means "not set" (e.g., `-1` or `0`) so a code reviewer immediately sees the TODO.

**Note on whether the raid has a single ID or multiple:** Per Q3, the answer is **single scalar** — instanceID is shared across all difficulties. The user's "research should show if the 4 difficulties have different IDs" question is correctly answered "all share one instanceID" — provided we use instanceID, not uiMapID.

---

### Q2: Canonical mapID-lookup API for Midnight

**Verdict (final architectural recommendation):** **`local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()`** is the primary API call for Phase 8. Use this. NOT `C_Map.GetBestMapForUnit("player")`.

**Why:** See Q3 for the reasoning. But for completeness, both APIs are verified available and untainted in Midnight 12.0.1:

| API | Returns | `SecretArguments` | Restricted? | Verified file:line |
|-----|---------|-------------------|-------------|---------------------|
| `C_Map.GetBestMapForUnit("player")` | `number?` (uiMapID, nilable) | `AllowedWhenUntainted` | No | `wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua:49-63` |
| `C_Map.GetMapInfo(mapID)` | `UiMapDetails` struct (name, mapType, parentMapID, ...) | `AllowedWhenUntainted` | No | `MapDocumentation.lua:311-326` |
| `GetInstanceInfo()` | 10 values (name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, **instanceID**, instanceGroupSize, lfgDungeonID) | (no args) | No | `InstanceDocumentation.lua:87-104` |
| `IsInInstance()` | `bool, instanceType` | (no args) | No | `InstanceDocumentation.lua:153-162` |
| `GetCurrentMapAreaID()` | n/a — **deprecated/removed** | n/a | n/a | Not present in wow-ui-source@12.0.1 |
| `WorldMapFrame:GetMapID()` | mapID of the currently *displayed* map (not the player's location) | UI-bound | n/a | `Blizzard_WorldMap.lua` (UI state, wrong semantics for Phase 8) |

`GetCurrentMapAreaID` is genuinely gone in Midnight — do not use. `WorldMapFrame:GetMapID()` reflects what's drawn on the world map, which can be different from where the player is (user pans the map). Wrong semantics for Phase 8.

**Code example (verified pattern):**
```lua
-- From wow-ui-source/Interface/AddOns/Blizzard_WorldMap/MapTexturePreloader.lua:5-12
local function PreloadPlayersMap()
    local mapID = C_Map.GetBestMapForUnit("player");
    if mapID and not preloadingRequests[mapID] then
        C_Map.RequestPreloadMap(mapID);
        preloadingRequests[mapID] = true;
    end
end
```

If for any reason the planner preferred uiMapID over instanceID (e.g., they want to also auto-show in the *outdoor* Isle of Quel'Danas — explicitly OOS per CONTEXT D-01, so not applicable), `C_Map.GetBestMapForUnit("player")` is the right call. **For Phase 8 as scoped, use instanceID.**

---

### Q3: `GetInstanceInfo` instanceID vs `C_Map` uiMapID — which is right?

**Verdict:** **Use `GetInstanceInfo()` and read `select(8, …)` — the instanceID.** Architecturally cleaner; difficulty-stable; one scalar value matches all 5 difficulties.

**Why instanceID is the right axis for THIS use case:**

| Property | uiMapID (`C_Map.GetBestMapForUnit`) | instanceID (`GetInstanceInfo`) |
|----------|-------------------------------------|---------------------------------|
| Stable across difficulties? | **Usually yes, but not guaranteed.** Modern raids typically share uiMapID across difficulties (uiMapID describes a map, not an instance), but Blizzard has historically split raids into multiple uiMapIDs for sub-areas (e.g., Sunwell Plateau is uiMapID 335 AND 336 "Shrine of the Eclipse" per `wowpedia.fandom.com/wiki/UiMapID`). For Midnight raids the schema is unknown until shipped. | **Yes, definitively.** instanceID is the identifier of the instance (the "where am I locked to" concept). Difficulty is a separate axis (`select(3, GetInstanceInfo())` = difficultyID). All 5 difficulties of the same raid return the same instanceID. This is how Blizzard's lockout system works — see Wowpedia `InstanceID`. |
| Stable across sub-areas? | **Can split.** `C_Map.GetBestMapForUnit` returns "the lowest map the unit is on" — if a raid has internal sub-zones with their own uiMapIDs, this returns the sub-zone, not the raid. Forces a set-check. | **Yes.** instanceID is set when the player enters the instance and stays the same regardless of which sub-area they walk to. |
| Returns `nil` ever? | **Yes — `Nilable = true`** in `MapDocumentation.lua:61`. Can be `nil` briefly during/after loading screens. | `Nilable = false` for instanceID field (`InstanceDocumentation.lua:100`). When not in an instance, instanceID is still a number — it's just not a raid (instanceType == "none"). |
| Sentinel for "not in instance" | `nil` — fragile to check (need both nil and inequality) | instanceType == "none" or instanceID being the outdoor-world ID. Cleaner: also check `IsInInstance()` and short-circuit. |
| Constant shape in source | Set/table (set-check needed in case raid has sub-zones) | Single scalar (one number per raid) |
| Match locking the user wants | "When player is in the M of Q raid instance" | "When player is in the M of Q raid instance" |

The mapping is **near-identical for typical raids** but the architectural risk asymmetry favors instanceID:
- If we use uiMapID and the raid has sub-areas, the addon silently breaks in sub-zones (hides when it shouldn't). Hard to detect in QA unless the user happens to walk to that sub-zone.
- If we use instanceID, there is exactly one value to compare and the only risk is "did we get the right number" — which UAT catches immediately on the first zone-in.

**Recommended handler pattern:**

```lua
-- D-08 refined: use instanceID (return position 8 of GetInstanceInfo)
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

This is **more selective than uiMapID** (skips even checking the constant if we're not in a raid at all), **more reliable** (no nil-on-load-screen window), and **simpler** (one constant, no set table). The `IsInInstance()` short-circuit also means the handler does no further work in 99% of fires (taxis, outdoor zones, mounting up, etc.) — addresses the "PLAYER_ENTERING_WORLD fires on every loading screen" concern.

**Difficulty IDs the user should know about (verified):**

| difficultyID | Name | Raid? |
|--------------|------|-------|
| 14 | Normal | Raid |
| 15 | Heroic | Raid |
| 16 | Mythic | Raid |
| 17 | Raid Finder (LFR) | Raid |
| **220** | **Story** | **Raid (new in Midnight)** |

Phase 8 does NOT need to inspect difficultyID — instanceID alone gates the show/hide. But the planner should know that Midnight introduced a 5th raid difficulty (Story Mode). See Q8 + Open Question Q1 below.

**Sources for instanceID stability:**
- WeakAuras2 GitHub issue #2394 — the entire feature request only makes sense if instanceID is stable across difficulties and difficultyID is the separate axis. The Blizzard maintainer's response treats this as common knowledge.
- Wowpedia `InstanceID` page: examples of stable values (Nerub-ar Palace=2657, Amirdrassil=2549, Aberrus=2569) — three- and four-digit values, very different in magnitude from uiMapIDs.

---

### Q4: `OnShow` / `OnHide` re-fire semantics

**Verdict:** **Transition-only.** Calling `:Show()` on a frame that is already shown does NOT re-fire `OnShow`. Same for `:Hide()` on already-hidden. **D-07 ("re-evaluate on every event fire, no state tracking") is the correct call** — redundant zone-event fires are free at the frame level.

Source: WoWInterface forum + multiple wiki references. The Blizzard frame system tracks visibility internally; `OnShow`/`OnHide` are gated by the state transition, not the API call. This is well-established behavior consistent across all WoW expansions.

**Implication for AMEND-01 (chat-event registration):** Because `OnShow` doesn't re-fire on `:Show()`-while-shown, chat events do NOT get double-registered (which would also be a no-op per `RegisterEvent` documentation, but still — clean). And `OnHide` doesn't re-fire on `:Hide()`-while-hidden, so the sequence does NOT get re-wiped, and chat events do NOT get unregistered twice. The full AMEND-01 invariant is intact across redundant zone-event fires.

**Implication for `db.window.visible`:** `ns:ShowWindow()` writes `db.window.visible = true` and `ns:HideWindow()` writes `false` unconditionally. So calling Show twice in a row writes `true` twice (idempotent), but it does NOT trigger redundant `NotifyWindowVisibilityChanged()` calls — wait, actually it DOES (the notify is at the end of the function, not gated by IsShown). Minor:

**Sub-finding ZONE-3 (see New Pitfalls below):** Phase 6's `ns:NotifyWindowVisibilityChanged()` is called from inside `ns:ShowWindow()` / `ns:HideWindow()` *unconditionally* (Window.lua:451, 457). If the zone handler re-evaluates on every fire AND the visibility didn't change, NotifyWindowVisibilityChanged() still fires — meaning the Settings panel button label refresh runs even when the label hasn't changed. This is **not a bug** (the refresh is cheap and idempotent — it just calls `SettingsInbound.RepairDisplay()` only if the panel is shown), but worth flagging to the planner so they don't add a state-tracking guard expecting it to be missing.

---

### Q5: PLAYER_ENTERING_WORLD vs ZONE_CHANGED_NEW_AREA firing order

**Verdict:** Register **both**. Blizzard's own code uses this dual-registration pattern.

**Firing matrix (verified):**

| Scenario | PLAYER_ENTERING_WORLD | ZONE_CHANGED_NEW_AREA |
|----------|----------------------|------------------------|
| Initial character login | ✓ (with `isInitialLogin=true`) | Usually NOT at the exact load moment — fires later if the player walks to a new zone. Not reliable for "what zone am I in at login." |
| `/reload` | ✓ (with `isReloadingUi=true`) | Usually NOT (you're still in the same zone — no transition). |
| Cross continent (taxi to another zone) | ✓ (loading screen) | ✓ |
| Enter raid instance via portal | ✓ (loading screen) | ✓ |
| Leave raid instance back to outdoor | ✓ (loading screen) | ✓ |
| Walk across a zone border (no loading screen) | ✗ | ✓ |
| Walk into a sub-zone like a building (indoor) | ✗ | ✗ (ZONE_CHANGED_INDOORS fires instead — NOT registered by Phase 8) |

The two events together cover all the cases Phase 8 cares about:
- PLAYER_ENTERING_WORLD = catches the loading-screen cases (raid entry, raid exit, login, /reload).
- ZONE_CHANGED_NEW_AREA = catches walking across zone borders (e.g., Eversong Woods → Isle of Quel'Danas, in case the user is questing in the area without a loading screen).

**Firing order at session start (verified — warcraft.wiki.gg `AddOn_loading_process`):**
1. ADDON_LOADED (per addon)
2. PLAYER_LOGIN
3. PLAYER_ENTERING_WORLD

D-12's order-of-operations analysis (ADDON_LOADED → `RestoreWindowVisibility` then PLAYER_ENTERING_WORLD → `OnZoneChanged` has final say) holds verbatim. The brief-flicker case in D-12 is real but acceptable.

**Reference implementation (verbatim from Blizzard, `Blizzard_WorldMap/MapTexturePreloader.lua` lines 1-26 of wow-ui-source@12.0.1):**

```lua
local PreloaderDriver = CreateFrame("Frame");

local preloadingRequests = {};

local function PreloadPlayersMap()
    local mapID = C_Map.GetBestMapForUnit("player");
    if mapID and not preloadingRequests[mapID] then
        C_Map.RequestPreloadMap(mapID);
        preloadingRequests[mapID] = true;
    end
end

PreloaderDriver:SetScript("OnEvent", function(self, event, ...)
    if event == "ZONE_CHANGED" then
        PreloadPlayersMap();
    elseif event == "MAP_EXPLORATION_UPDATED" then
        PreloadPlayersMap();
    elseif event == "PLAYER_ENTERING_WORLD" then
        PreloadPlayersMap();
    end
end);

PreloaderDriver:RegisterEvent("ZONE_CHANGED");
PreloaderDriver:RegisterEvent("MAP_EXPLORATION_UPDATED");
PreloaderDriver:RegisterEvent("PLAYER_ENTERING_WORLD");
```

Note Blizzard uses `ZONE_CHANGED` (not `_NEW_AREA`) for map preloading — they want every sub-zone change to preload. Phase 8 wants `ZONE_CHANGED_NEW_AREA` (less spammy; fires only on meaningful zone changes; matches the "moved to a new zone" semantics our show/hide actually cares about). **D-09's choice of `ZONE_CHANGED_NEW_AREA` is correct.**

Secondary verification: `Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:501-502` registers both `ZONE_CHANGED_NEW_AREA` and `ZONE_CHANGED` for "World PvP stuff" — confirms `ZONE_CHANGED_NEW_AREA` is the standard "moved to a meaningful new area" event.

---

### Q6: PLAYER_ENTERING_WORLD argument behavior

**Verdict (verified `Blizzard_CodeOfConduct.lua:1` + warcraft.wiki.gg):**

```lua
zoneFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        -- isInitialLogin = true on character login
        -- isReloadingUi = true on /reload
        -- both false when zoning between map instances mid-session
    end
    ns:OnZoneChanged()
end)
```

Phase 8 does NOT need to differentiate these. D-07 re-evaluates on every fire and produces the right answer regardless of `isInitialLogin` / `isReloadingUi`. The only reason to capture these is for the **optional one-time debug print** at load time:

```lua
-- Optional, gated behind DEBUG_ZONE_INFO = false at the top of Core.lua.
-- Useful only during v1.1.0 dev cycle to capture the M of Q raid instanceID
-- in UAT; flipped off before release tag.
local DEBUG_ZONE_INFO = false  -- set true ONLY for in-game UAT capture
if DEBUG_ZONE_INFO then
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        local inInstance, instanceType = IsInInstance()
        local instanceID = inInstance and select(8, GetInstanceInfo()) or "(not in instance)"
        local mapID = C_Map.GetBestMapForUnit("player") or "(nil)"
        print(string.format("|cffaa44ffTLH-DEBUG|r PEW: init=%s reload=%s inst=%s map=%s type=%s",
            tostring(isInitialLogin), tostring(isReloadingUi), tostring(instanceID), tostring(mapID), instanceType))
    end
end
```

**Recommended:** Add this debug block to the implementation, defaulting `DEBUG_ZONE_INFO = false`. During UAT, the user (or Claude during dev) flips it to true, captures the M of Q instanceID, then flips it back to false before the release tag. This makes Q1's unknown-mapID problem self-correcting in one UAT pass instead of needing a `/dump` task.

---

### Q7: Zone-event safety during combat

**Verdict:** **Safe across the board.** No combat guards needed in `ns:OnZoneChanged()` or the new zone frame.

**Evidence:**

- PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA are not combat-locked events — they fire during combat without restriction (and in fact PLAYER_ENTERING_WORLD on a raid wipe + corpse run can fire from inside the encounter as you cross the instance threshold).
- `GetInstanceInfo()` takes no arguments and is unannotated in `wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua:87-104` — meaning no `SecretArguments`, no `IsProtectedFunction`. It is a plain getter. Safe during combat.
- `IsInInstance()` same — plain getter, `InstanceDocumentation.lua:153-162`.
- `C_Map.GetBestMapForUnit("player")` is `SecretArguments = "AllowedWhenUntainted"` — meaning the unitToken argument must not be a tainted value. The hardcoded literal `"player"` is never tainted. Safe during combat.
- `ns:ShowWindow()` / `ns:HideWindow()` operate on a plain `CreateFrame("Frame", ...)` (not a secure template), so the underlying `win:Show()` / `win:Hide()` are safe during combat. They are already called during combat from the existing slash-command handler and the Settings panel button without issue.

**MEMORY.md note (relevant):** "Combat-taint scope — Own SavedVariables/locals are safe to read during combat; 'secret values' only applies to Blizzard UI info reads." `GetInstanceInfo()` *is* a Blizzard info read, but it's an unannotated one (no SecretArguments) — fully addon-callable during combat. The "secret values" rule is specifically about Lua values that the engine has tainted (e.g., values read from secure templates inside protected handlers). A return value from `GetInstanceInfo()` in our context is not tainted because our zone frame has no secure-template ancestry.

---

### Q8: Midnight-Interface-120005-specific changes

**One material change:** Midnight introduced **Story Mode** as a 5th raid difficulty (`difficultyID = 220`). Wowhead news + Blizzard news article + Sportskeeda + Icy Veins all confirm. This is the first time WoW has had a solo-soloable raid difficulty.

**Why this matters for D-02:** The CONTEXT.md decision D-02 says "all 4 raid difficulties (LFR / Normal / Heroic / Mythic) MUST trigger the auto-show." Midnight has 5, not 4. Whether Story Mode should also trigger auto-show is **Open Question Q1** below — it's not literally what the user said, but the user's intent ("auto-show whenever the player is in the L'ura encounter regardless of difficulty") almost certainly extends to Story Mode (it IS the L'ura encounter, just solo). The planner should confirm before locking the implementation.

**Implementation impact:** **Zero, if Phase 8 uses `instanceID` per Q3.** instanceID is difficulty-agnostic — the same scalar matches all 5 difficulties. If Phase 8 had used `C_Map.GetBestMapForUnit` (uiMapID), there's a small risk that Story Mode has a different uiMapID (solo-instance phasing) requiring an additional entry in a set table. **Yet another reason to prefer instanceID over uiMapID.**

**Other Midnight-era changes investigated and found NOT to affect Phase 8:**
- `COMBAT_LOG_EVENT_UNFILTERED` is disabled in Midnight (CLAUDE.md hard constraint) — Phase 8 doesn't touch this event.
- Chat-message taint constraints — Phase 8 doesn't touch chat events.
- Aura "Secret Values" restrictions — Phase 8 doesn't read auras.
- Patch 12.0.0 `SetTexture` cannot accept secret strings — Phase 8 doesn't call SetTexture (the cheat-sheet texture from v1.0.0 was already addressed in Phase 4, see PITFALLS TX-1/TX-2).

---

### Q9: Existing PITFALLS.md applicability + new ZONE-* pitfalls

**Existing pitfalls reviewed against Phase 8 surface:**

| Existing Pitfall | Applies to Phase 8? | Why |
|------------------|---------------------|-----|
| CT-1, CT-2, CT-3 (click-through / EnableMouse / protected functions) | No | Phase 8 doesn't touch mouse handling or lock state |
| TX-1, TX-2, TX-3 (texture/pkgmeta) | No | Phase 8 ships no new textures |
| DL-1, DL-2, DL-3 (dynamic-label notify hook) | **Indirect — see ZONE-3 below** | Phase 8 calls `ns:ShowWindow()` / `ns:HideWindow()` which already call `ns:NotifyWindowVisibilityChanged()` (Window.lua:451, 457). Phase 8 does NOT add new notify-hook code — it just becomes another caller of existing infrastructure. DL-3's "missing visibility-change path" warning is the relevant lens: Phase 8 routes through Show/Hide so it's automatically covered. |
| DB-1, DB-2 (backfill clobbering) | No | Phase 8 adds no new DB keys |
| AH-1 (PLAYER_REGEN_ENABLED fires on login) | **Partially applicable — see new ZONE-3** | The Phase 8 analog is "PLAYER_ENTERING_WORLD fires on initial login." But for Phase 8 this firing is INTENDED and DESIRED — it's the mechanism by which the zone handler routes the correct visibility at session start. No code change needed. Mention in PITFALLS as ZONE-3 for clarity. |
| AH-2 (hard-hide breaks chat events / AMEND-01) | **Highly relevant — but already addressed by routing through `ns:HideWindow()`** | This pitfall says combat-driven hiding must use soft-hide, NOT `win:Hide()`, because hard-Hide unregisters chat events. **Phase 8's zone-leave case is different: hard-hide is CORRECT** because (a) when the player is outside the raid, the chat-event lockdown of L'ura doesn't apply, so unregistering chat events is fine and (b) AMEND-01's pairing requires `ns:HideWindow()` for the chat-event unregister side effect to fire on `OnHide`. SAFE-07 codifies this distinction. **The planner must NOT add a soft-hide variant for the out-of-zone case — it would defeat AMEND-01.** |
| AH-3 (M+ trash-chain flicker) | No | Phase 8 fires on zone events, not combat events; raid loading screens take >5 seconds and don't trash-chain |
| AH-4 (drag-in-progress mid-combat) | No | Phase 8 fires on zone events, not combat events; user can't be dragging the window during a loading screen |

**Three new pitfalls (ZONE-*) — recommend adding to PITFALLS.md alongside the v1.0.0 entries:**

---

#### Pitfall ZONE-1: ZONE_CHANGED_NEW_AREA fires on outdoor zone-border crossings — not just on instance entry

**What goes wrong:** The user expects Phase 8 to fire only on "entering / leaving the raid." But ZONE_CHANGED_NEW_AREA also fires when walking across any outdoor zone border (e.g., Eversong Woods → Ghostlands → Isle of Quel'Danas). Each crossing triggers `ns:OnZoneChanged()`. For 90% of these the handler short-circuits via `IsInInstance()` → `ns:HideWindow()` is called (a no-op if already hidden, per Q4).

**Why it happens:** ZONE_CHANGED_NEW_AREA is the "you crossed into a new zone" event — by design it fires on every outdoor zone border crossing, not just on loading screens. There is no narrower event for "you entered an instance."

**How to avoid:** No fix needed. The IsInInstance short-circuit handles it cheaply. But the planner should be aware: in casual outdoor play, `ns:OnZoneChanged()` fires several times per minute as the user moves around. The handler MUST be cheap (one `IsInInstance()` call in the negative path). Don't add any heavy work (no logging, no print, no Settings re-render) to the negative path.

**Warning signs:**
- Performance complaints from users in dense quest areas with frequent zone crossings.
- Any handler code that does more than `IsInInstance()` + early-return in the not-in-raid case.

**Phase to address:** Phase 8 implementation. Keep the handler skeleton at <10 lines; no debug spam in the negative path (the optional debug print should be gated behind `DEBUG_ZONE_INFO = false`).

---

#### Pitfall ZONE-2: GetInstanceInfo() returns non-nil instanceID even when outside any instance — don't compare-only

**What goes wrong:** Naive handler:
```lua
local instanceID = select(8, GetInstanceInfo())
if instanceID == LURA_RAID_INSTANCE_ID then
    ns:ShowWindow()
else
    ns:HideWindow()
end
```
This appears correct but masks an edge case: when the player is in the open world, `GetInstanceInfo()` still returns a valid instanceID (representing the world map / continent — not nil and not zero). The comparison naturally yields false for the open world, so the addon hides correctly. **However:** the `instanceType` for non-instances is `"none"` (or sometimes `"none"` / "world"); if Blizzard ever changes the instance numbering scheme to reuse a number that matches `LURA_RAID_INSTANCE_ID` (extremely unlikely), the addon would false-positive.

**Why it happens:** `GetInstanceInfo()` is engineered to always return values — it's a "tell me about my current world location" function, and the world counts as a kind of "instance" in Blizzard's internal model.

**How to avoid:** Add the `IsInInstance()` short-circuit per the Q3-recommended pattern:
```lua
local inInstance, instanceType = IsInInstance()
if not inInstance or instanceType ~= "raid" then
    ns:HideWindow()
    return
end
local instanceID = select(8, GetInstanceInfo())
-- ... compare
```
The `instanceType ~= "raid"` check is the belt-and-suspenders guard against accidental matches in dungeon/scenario/pvp instances.

**Warning signs:**
- Handler does `if select(8, GetInstanceInfo()) == CONST` without an IsInInstance / instanceType guard.

**Phase to address:** Phase 8 implementation. One-line guard at the top of `ns:OnZoneChanged()`.

---

#### Pitfall ZONE-3: PLAYER_ENTERING_WORLD interaction with ADDON_LOADED's `RestoreWindowVisibility` — brief flicker on login

**What goes wrong:** At login, the sequence is:
1. ADDON_LOADED → calls `RestoreWindowVisibility()` if `db.window.visible == true`. Window may briefly show.
2. ~10-100ms later: PLAYER_ENTERING_WORLD → calls `ns:OnZoneChanged()`. If the player is OUT of the raid, `ns:HideWindow()` is called. Window flickers visible → hidden.

D-12 explicitly accepts this as "acceptable brief flicker." But there's a subtler interaction: `db.window.visible` is written by both Show/Hide. So after the flicker:
- User logged out with `db.window.visible = true` (e.g., they `/lura show`-ed in town).
- Login → RestoreWindowVisibility shows the window. `db.window.visible` stays `true`.
- PLAYER_ENTERING_WORLD → ns:OnZoneChanged → outside raid → ns:HideWindow → `db.window.visible = false`.
- User logs out again from this session. Next login: `db.window.visible = false` → no restore → no flicker.

**So the flicker is a one-time event per "logout-while-visible-out-of-raid" scenario.** The system self-corrects. D-12 holds.

**Why it happens:** Two independent restoration paths (RestoreWindowVisibility at ADDON_LOADED, OnZoneChanged at PLAYER_ENTERING_WORLD) operate on the same state without coordination. They converge correctly within milliseconds, but produce a visible transition.

**How to avoid:** Three options, ranked by complexity:
1. **(Recommended) Accept the flicker.** It's brief, one-time per scenario, and self-corrects. D-12 already accepted this.
2. Skip `RestoreWindowVisibility()` at ADDON_LOADED if Phase 8 is enabled — let PLAYER_ENTERING_WORLD be the sole arbiter. **Rejected** per D-12 (no changes to ADDON_LOADED path).
3. Add a "first PEW only" flag and defer NotifyWindowVisibilityChanged until after the first PEW resolves. Overengineered; YAGNI.

**Warning signs:**
- User reports "the window flashes briefly on login then disappears" — confirm the scenario was logout-while-visible-out-of-raid; the flicker is expected.

**Phase to address:** Phase 8 implementation note + UAT checkpoint. No code change. Optional: mention in v1.1.0 RELEASE NOTES / CHANGELOG so users aren't surprised.

---

### Q10: Reference implementations in wow-ui-source

**Primary reference — copy this pattern almost verbatim:**

`Blizzard_WorldMap/MapTexturePreloader.lua` (full file, 26 lines) — quoted in full under Q5. Phase 8 needs this exact structure:
- Permanent `CreateFrame("Frame")` at file scope.
- `SetScript("OnEvent", function(self, event, ...) … end)` dispatching on event name.
- `RegisterEvent("PLAYER_ENTERING_WORLD")` + zone event(s) at file scope (top-level, runs at file-load time).
- Handler calls a single named function (in Phase 8: `ns:OnZoneChanged()`) that does the actual work — keeps the OnEvent shim minimal.

Differences for Phase 8:
- Use `ZONE_CHANGED_NEW_AREA` instead of `ZONE_CHANGED` (Phase 8 wants meaningful-zone-change semantics, not every sub-zone tick).
- Call `GetInstanceInfo()` instead of `C_Map.GetBestMapForUnit` (Q3).
- Call `ns:ShowWindow()` / `ns:HideWindow()` instead of `C_Map.RequestPreloadMap` (semantic: route through addon-internal visibility primitives).

**Secondary references:**

- `Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:501-502` — confirms dual registration `ZONE_CHANGED_NEW_AREA` + `ZONE_CHANGED` for "World PvP stuff." For Phase 8, single `ZONE_CHANGED_NEW_AREA` is sufficient (we don't care about sub-zone transitions inside the raid).
- `Blizzard_Minimap/Mainline/Minimap.lua:142-144` (registers PLAYER_ENTERING_WORLD); lines 360-362 register the three zone events together (`ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`). Phase 8 wants ONLY `ZONE_CHANGED_NEW_AREA` — registering the others would fire on every doorway transition, wasting cycles.
- `Blizzard_FrameXMLUtil/DifficultyUtil.lua:65, 70, 104` — Blizzard's own pattern for reading difficulty via `select(3, GetInstanceInfo())`. Confirms select() is the idiomatic destructuring approach.
- `Blizzard_Commentator/Blizzard_Commentator.lua:293` — `local mapID = select(8, GetInstanceInfo())` — verbatim the pattern Phase 8 uses.
- `Blizzard_CodeOfConduct/Blizzard_CodeOfConduct.lua:1` — canonical pattern for reading `isInitialLogin, _isUIReload = ...` from a PLAYER_ENTERING_WORLD handler.

**Negative reference (do NOT copy):**

- `Blizzard_Tutorials/Blizzard_Tutorials_Professions.lua` — registers ZONE_CHANGED_NEW_AREA but inside an Event-driven Mixin pattern with `EventRegistry:RegisterFrameEventAndCallback`. More machinery than Phase 8 needs.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Zone-event registration | Core.lua (file scope) | — | Mirrors existing `eventFrame` (Core.lua:23) and `regenFrame` (Macros.lua:92). Core.lua is the event dispatcher; new permanent frames live here. |
| `ns:OnZoneChanged()` handler | Core.lua | — | Verb-prefix convention matches `OnAutoHideChanged`, `OnMacroChannelChanged`, `OnVerboseMarkersChanged`. Core.lua owns event handlers. |
| Window visibility primitives | Window.lua | — | Phase 8 does NOT modify Window.lua. `ns:ShowWindow()` / `ns:HideWindow()` are reused as terminal actions. |
| `db.window.visible` write | Window.lua (existing `ns:ShowWindow` / `ns:HideWindow`) | — | Phase 8 doesn't write `db.window.visible` directly — only routes through Show/Hide which already do. |
| Hardcoded `LURA_RAID_INSTANCE_ID` constant | Core.lua (file scope, top, near `LISTEN_DEFAULTS`) | — | All `*_DEFAULTS` / numeric constants are file-scope in Core.lua. Establishes a pattern for "user-immutable lookup values." |
| AMEND-01 invariant (chat events register on Show, unregister on Hide) | Window.lua (`OnShow`/`OnHide` scripts) | Core.lua (calls Show/Hide correctly) | Phase 8 is the second consumer of this invariant (after slash commands). SAFE-07 codifies the requirement. |

---

## Standard Stack

### Core APIs (verified in wow-ui-source@12.0.1)

| API | Verified at | Signature | Use in Phase 8 |
|-----|-------------|-----------|-----------------|
| `CreateFrame("Frame")` | (universal) | Returns a Frame | Create `zoneFrame` |
| `Frame:RegisterEvent(event)` | (universal) | Subscribes to game event | Subscribe to `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA` |
| `Frame:SetScript("OnEvent", fn)` | (universal) | Sets event dispatch handler | Dispatch to `ns:OnZoneChanged()` |
| `GetInstanceInfo()` | `InstanceDocumentation.lua:87-104` | Returns 10 values; instanceID at position 8 | Primary "where am I" query |
| `IsInInstance()` | `InstanceDocumentation.lua:153-162` | Returns `(bool, instanceType)` | Fast-path negative check |
| `select(8, GetInstanceInfo())` | (idiomatic) | Extract instanceID | Blizzard pattern, verified in `Blizzard_Commentator.lua:293` |

### Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Track "did the zone change" | Module-local `lastZone` state with diff-check on every fire | Rely on `OnShow`/`OnHide` transition-only semantics (Q4); call Show/Hide unconditionally |
| Capture player's zone reliably | Parse `GetRealZoneText()` / `GetZoneText()` strings | `GetInstanceInfo()` + `select(8)` — numeric, localization-safe |
| Detect raid difficulty | Compare maxPlayers from `GetInstanceInfo()` | `select(3, GetInstanceInfo())` for `difficultyID` (but Phase 8 doesn't need this — instanceID is difficulty-agnostic) |
| "Am I currently in a raid?" | uiMapID set-membership check | `IsInInstance() + instanceType == "raid"` |

---

## Code Pattern (the planner can copy this almost verbatim)

```lua
-- Top of Core.lua, near LISTEN_DEFAULTS (around line 14-21):

-- The instanceID for the March on Quel'Danas raid. Shared across all 5
-- difficulties (LFR / Story / Normal / Heroic / Mythic) — difficulty is a
-- separate axis in GetInstanceInfo()'s return tuple, not encoded in instanceID.
--
-- TODO[v1.1.0-rc]: capture the real value during UAT and patch in place.
-- Until then, 0 is a sentinel that never matches a real instance.
-- See .planning/phases/08-zone-aware-auto-show-hide/08-RESEARCH.md §Q1.
local LURA_RAID_INSTANCE_ID = 0  -- PLACEHOLDER

-- Toggle to true ONLY during UAT to capture the live instanceID via chat print.
-- Must be false in any release build.
local DEBUG_ZONE_INFO = false


-- After the existing eventFrame block (around line 130, before ns:PrintHelp):

-- ============================================================
-- Zone-aware auto show/hide (Phase 8 / WIN-16, WIN-17, SCAF-19, SAFE-07).
-- Routes through the existing ns:ShowWindow() / ns:HideWindow() paths so
-- AMEND-01 (OnShow registers chat events, OnHide unregisters + wipes) holds.
-- See .planning/phases/08-zone-aware-auto-show-hide/08-RESEARCH.md.
-- ============================================================
function ns:OnZoneChanged(isInitialLogin, isReloadingUi)
    local inInstance, instanceType = IsInInstance()

    if DEBUG_ZONE_INFO then
        local instID = inInstance and select(8, GetInstanceInfo()) or "(none)"
        print(string.format("|cffaa44ffTLH-DEBUG|r zone: inst=%s type=%s init=%s reload=%s",
            tostring(instID), instanceType, tostring(isInitialLogin), tostring(isReloadingUi)))
    end

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

local zoneFrame = CreateFrame("Frame")
zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        ns:OnZoneChanged(isInitialLogin, isReloadingUi)
    else
        ns:OnZoneChanged()
    end
end)
```

**Total Core.lua addition:** ~30 lines including comments. Stylua-clean. No new files.

---

## Open Questions

### Q1: Should Story Mode (difficultyID 220) trigger auto-show?

**What we know:**
- Midnight introduces Story Mode (solo-soloable raid) as a 5th difficulty.
- The user's locked decision D-02 says "all 4 raid difficulties (LFR / Normal / Heroic / Mythic)" — written before Story Mode existed in our reference frame.
- The user's stated intent (CONTEXT.md `<specifics>`): "L'ura encounter is the entire reason this addon exists" and "high-value polish: it removes the cognitive overhead of remembering `/lura show` before every pull."
- Story Mode IS the L'ura encounter, just solo. The cognitive-overhead value applies equally.

**What's unclear:** Whether the user wants the addon visible during Story Mode. Two reasonable interpretations:
1. "All difficulties where the encounter exists" → YES, include Story Mode.
2. "Group-content difficulties only" → NO, Story Mode is solo and the user is alone.

**Recommendation:** **Include Story Mode (auto-show)**, because Phase 8 uses instanceID which is difficulty-agnostic — Story Mode just works without extra code. If the user later wants to exclude Story Mode, they can add a `select(3) == 220 then return` early-exit. **Action: planner should mention this in the plan summary so the user can flag if they want Story Mode excluded.** No code branch needed if instanceID-based handler is used.

### Q2: Should the addon proactively call `ns:OnZoneChanged()` at the end of ADDON_LOADED?

**What we know:**
- PLAYER_ENTERING_WORLD fires reliably ~10-100ms after ADDON_LOADED at session start (Q5).
- D-12 accepts the brief flicker between RestoreWindowVisibility and the first OnZoneChanged.
- An eager call at end-of-ADDON_LOADED would NOT eliminate the flicker (RestoreWindowVisibility runs first; the eager call would resolve the visibility a few ms earlier than PEW would, but still after RestoreWindowVisibility).

**What's unclear:** Whether the eager call is worth the complexity. It would slightly reduce the flicker window (~10-100ms shorter) but adds one more code path to debug. CONTEXT.md `<decisions>` `Claude's Discretion` mentioned this as "probably unnecessary."

**Recommendation:** **Do NOT call eagerly.** PEW is reliable; the flicker is acceptable. Keep the architecture simple: one event handler, one truth source. **Action: planner can confirm and lock this.**

### Q3: Should the optional debug-print block ship in the final code (gated `DEBUG_ZONE_INFO = false`) or be removed before release?

**What we know:** The block is ~5 lines of code, no runtime cost when DEBUG=false (one branch on a local boolean). It's the cheapest mechanism to capture the live instanceID during UAT.

**Tradeoff:**
- **Keep it (recommended):** Future-proofs the addon if M of Q instanceID ever changes (e.g., raid is re-released, content patch). User can flip the flag, reload, capture, report.
- **Remove it:** Cleaner code. But then we're back to a `/dump` task if anyone ever needs to re-capture.

**Recommendation:** **Keep it, default false.** 5 lines is nothing; the debug capability is meaningful insurance. **Action: planner confirms.**

---

## Validation Architecture

(Per `.planning/config.json` — research did not find a `workflow.nyquist_validation: false` setting, so this section is included.)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None (WoW addon — no automated test harness; CLAUDE.md §Testing) |
| Config file | n/a |
| Quick run command | `./scripts/install.bat` + `/reload` in-game |
| Full suite command | UAT checkpoints D-17 (8 checkpoints, combined with Phase 7 UAT) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| WIN-16 | Auto-show on raid entry, auto-hide on exit | manual-only (UAT D-17.1–6) | n/a — in-game smoke | n/a |
| WIN-17 | `/reload` inside raid auto-shows; manual hide re-evaluated on next zone event | manual-only (UAT D-17.4–5) | n/a — in-game smoke | n/a |
| SCAF-19 | Constant is numeric scalar; no zone-name strings in handler | static grep | `git diff -- '*.lua' | grep -iE '(GetZoneText|GetRealZoneText|GetMinimapZoneText)'` MUST return zero lines | n/a |
| SAFE-07 | Routes through Show/Hide; no SetAlpha(0) for zone-leave; AMEND-01 preserved | static grep + UAT D-17.3 | `git diff -- '*.lua' | grep -E '^\+.*win:SetAlpha\(0\)'` from the new zone-handler block MUST return zero lines | n/a |

### Sampling Rate
- **Per task commit:** stylua + `git diff` regression grep (CLAUDE.md hard-constraint patterns: SendChatMessage, :gsub on msg, etc.)
- **Per wave merge:** rebuild via install.bat + `/reload` + run `/lura help` to confirm no Lua errors at load
- **Phase gate:** Full UAT D-17 (8 checkpoints, batched with Phase 7 UAT)

### Wave 0 Gaps
- [ ] None — no test infrastructure needed beyond what already exists (manual UAT).

---

## Project Constraints (from CLAUDE.md)

Phase 8 must respect these existing constraints (all unaffected — Phase 8 does not touch any of these surfaces):

| Constraint | Phase 8 Status |
|------------|----------------|
| No `COMBAT_LOG_EVENT_UNFILTERED` | ✓ Not used |
| No `SendChatMessage` (or any chat-emit API) | ✓ Not used |
| No string ops on `msg` from `CHAT_MSG_*` | ✓ Phase 8 doesn't touch chat handlers |
| `CreateMacro`/`EditMacro` guarded by `InCombatLockdown()` | ✓ Phase 8 doesn't touch macros |
| Chat events registered on `OnShow`, unregistered on `OnHide` | ✓ Phase 8 routes through `ns:Show/HideWindow` which fire OnShow/OnHide |
| Stylua after all Lua changes | ✓ Plan should include stylua as final per-task step |
| Run install.bat for testing | ✓ MEMORY.md confirms this is mandatory pre-UAT step |
| Settings panel via modern `Settings.*` API | n/a (Phase 8 has no Settings UI) |

---

## Sources

### Primary (HIGH confidence — Blizzard official source)
- `wow-ui-source@12.0.1` (local repo at `C:\Users\jonat\Repositories\wow-ui-source`)
  - `Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua` — `GetBestMapForUnit`, `GetMapInfo`, restriction annotations
  - `Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua` — `GetInstanceInfo` full signature, `IsInInstance`, `GetDifficultyInfo`
  - `Interface/AddOns/Blizzard_APIDocumentationGenerated/MapConstantsDocumentation.lua` — UIMapType enum (Dungeon=4; no separate Raid type)
  - `Interface/AddOns/Blizzard_WorldMap/MapTexturePreloader.lua:1-26` — canonical zone-event listener pattern
  - `Interface/AddOns/Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:501-502` — dual zone-event registration
  - `Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua:142-144, 360-362` — zone event registration patterns
  - `Interface/AddOns/Blizzard_FrameXMLUtil/DifficultyUtil.lua:65, 70, 104` — `select(3, GetInstanceInfo())` for difficultyID
  - `Interface/AddOns/Blizzard_Commentator/Blizzard_Commentator.lua:293` — `local mapID = select(8, GetInstanceInfo())` verbatim pattern
  - `Interface/AddOns/Blizzard_CodeOfConduct/Blizzard_CodeOfConduct.lua:1-4` — `isInitialLogin, _isUIReload = ...` pattern for PEW handler
  - `version.txt` — 12.0.1.66337

### Secondary (HIGH confidence — official Blizzard or wiki cross-verified)
- [warcraft.wiki.gg/wiki/PLAYER_ENTERING_WORLD](https://warcraft.wiki.gg/wiki/PLAYER_ENTERING_WORLD) — event signature, arguments, firing conditions
- [warcraft.wiki.gg/wiki/ZONE_CHANGED_NEW_AREA](https://warcraft.wiki.gg/wiki/ZONE_CHANGED_NEW_AREA) — firing conditions, safe usage of `C_Map.GetBestMapForUnit` inside handler
- [warcraft.wiki.gg/wiki/AddOn_loading_process](https://warcraft.wiki.gg/wiki/AddOn_loading_process) — event firing order at session start
- [warcraft.wiki.gg/wiki/API_GetInstanceInfo](https://warcraft.wiki.gg/wiki/API_GetInstanceInfo) — return values for raids
- [warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit](https://warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit) — "lowest map" semantics
- [warcraft.wiki.gg/wiki/InstanceID](https://warcraft.wiki.gg/wiki/InstanceID) — example values (Nerub-ar Palace=2657 etc.); related API
- [warcraft.wiki.gg/wiki/UiMapID](https://warcraft.wiki.gg/wiki/UiMapID) — historical Sunwell Plateau split (335 + 336) confirming uiMapID can split per sub-area
- [warcraft.wiki.gg/wiki/DifficultyID](https://warcraft.wiki.gg/wiki/DifficultyID) — full difficulty ID list including Story Mode=220
- [warcraft.wiki.gg/wiki/Widget_script_handlers](https://warcraft.wiki.gg/wiki/Widget_script_handlers) — OnShow/OnHide transition-only semantics
- WeakAuras2 GitHub issue [#2394](https://github.com/WeakAuras/WeakAuras2/issues/2394) — addon-developer-confirmed difficultyID-vs-instanceID separation

### Tertiary (MEDIUM-LOW confidence — community sources, useful for triangulation)
- [Wowhead M of Q raid overview](https://www.wowhead.com/guide/midnight/raids/march-on-quel-danas-overview-location-rewards-bosses) — confirms raid name + outdoor mapID 2424
- [Wowhead L'ura NPC 240391](https://www.wowhead.com/npc=240391/lura/raid-finder-encounter-journal) — confirms L'ura is in Midnight Falls encounter
- [Wowhead news: March on Quel'Danas LFR + Story Mode now live](https://www.wowhead.com/news/march-on-queldanas-raid-finder-and-story-mode-now-live-381152)
- [Icy Veins Midnight Season 1 Raids](https://www.icy-veins.com/wow/midnight-season-1-raid-guide) — 2-boss raid, 4+1 difficulties confirmed
- [Blizzard news: WoW Weekly 12.0.5 Story Mode](https://news.blizzard.com/en-us/article/24272606/wow-weekly-12-0-5-content-update-midnight-raids-and-story-mode-and-more) — Story Mode introduction
- [warcraft.wiki.gg M of Q wiki page](https://warcraft.wiki.gg/wiki/March_on_Quel'Danas) — external-link to `wowdb.com/zones/16342` (number unverified)
- [Blizzard Watch Midnight Season 1 schedule](https://blizzardwatch.com/2026/03/17/midnight-season-1-release-schedule/) — release dates

### Unable to verify (LOW confidence — sources of "what we don't know")
- The actual numeric value of the M of Q raid instanceID — **not findable** via doc-only research; requires in-game `/dump` to capture. See Q1 + the recommended two-track plan.
- Whether `wowdb.com/zones/16342` is a uiMapID, instanceID, or wowdb-internal area ID — wowdb.com returned 403.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Wrong instanceID hardcoded → addon never auto-shows | HIGH (we ship with placeholder `0`) | LOW (regression-free: existing `/lura show` still works) | **Two-track plan:** ship placeholder, capture live ID during UAT, patch before release tag. Optional debug-print block self-documents. |
| Wrong API choice (uiMapID via `C_Map.GetBestMapForUnit`) → silently breaks in raid sub-areas | MEDIUM | MEDIUM (only manifests if raid has sub-zones with own uiMapIDs — Sunwell-style) | Use `GetInstanceInfo()` instanceID per Q3 — difficulty-agnostic AND sub-area-stable. |
| Story Mode (difficultyID 220) not anticipated → window doesn't auto-show in solo runs | LOW (instanceID is difficulty-agnostic; works automatically) | LOW (functionality, not regression) | Q3 architecture handles all difficulties uniformly. Q-Open-1 flags the design decision for planner confirmation. |
| Brief flicker on login when logged-out-visible-out-of-raid | MEDIUM (every time the scenario occurs) | LOW (one-time per login, <100ms, no user-visible impact other than the flicker itself) | Accept per D-12. Document in ZONE-3 pitfall and v1.1.0 CHANGELOG. |
| AMEND-01 invariant broken by zone handler using `SetAlpha(0)` instead of `Hide()` | LOW (the planner / Claude should know better; SAFE-07 codifies) | HIGH (chat events stay registered after raid exit → tainted chat messages from town leak into the sequence; user sees stale slot data on next raid pull) | SAFE-07 + static grep gate at UAT (the regression diff guard in D-16). |
| Performance: handler fires too often in outdoor play (ZONE-1) | MEDIUM | LOW (handler is O(1): one IsInInstance + early-return) | Keep handler ≤10 lines; no print/log/heavy work in the negative path. ZONE-1 pitfall codifies. |
| `GetInstanceInfo()` returns nil/zero during loading screen (call too early) | LOW (PEW fires *after* the loading screen completes — verified) | MEDIUM (nil compare → handler always hides → user briefly sees window disappear) | If the planner observes nil during UAT, add a defensive `if not instanceID then return end` early-exit. Not expected to be needed. |
| Phase 7 + Phase 8 interaction: combined UAT misses an edge case | LOW | LOW | UAT D-17 explicitly batches both phases' checkpoints. Phase 8 D-17 has 8 checkpoints + the existing Phase 7 set. |

---

## Assumptions Log

The table below lists every claim in this research that is `[ASSUMED]` rather than `[VERIFIED]` or `[CITED]`. The planner and discuss-phase use this to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The M of Q raid instanceID is a single number shared across all 5 difficulties. | Q3 | LOW — if instanceID does split per difficulty (extreme edge case never seen in modern WoW), the addon auto-shows for one difficulty only. UAT D-17.2 catches this on the second-difficulty checkpoint. Mitigation: convert `LURA_RAID_INSTANCE_ID` from scalar to a `{ [N]=true }` set lookup. One-line code change. |
| A2 | The user wants Story Mode (difficultyID 220) to also trigger auto-show. | Q1 (Open Questions) | LOW — if wrong, addon shows in a solo Story Mode run; user closes via `/lura hide` and the next zone event re-shows. Annoying but not broken. Q1 flags this for planner confirmation. |
| A3 | The M of Q raid is "instanceType = 'raid'" (not 'scenario' or any other custom type). | Q3 + Pitfall ZONE-2 | LOW — Wowhead consistently calls it a raid; the `IsInInstance() + instanceType == "raid"` guard is the right pattern by design. If Blizzard ever uses a non-"raid" instanceType for Story Mode specifically, the planner should relax the guard to `instanceType == "raid" or instanceType == "scenario"` — but that's a UAT-discoverable issue. |
| A4 | `db.window.visible` semantics in CONTEXT.md D-13 are correctly understood as "transient cache of last-applied state inside the raid." | (CONTEXT.md, not this research) | n/a — locked by user. |

---

## Metadata

**Confidence breakdown:**
- API + event signatures: **HIGH** — verified directly against wow-ui-source@12.0.1.
- Architectural recommendation (instanceID over uiMapID): **HIGH** — multiple corroborating sources + Blizzard's own internal pattern.
- M of Q raid instanceID specific value: **LOW** — not findable from documented sources; recommend two-track plan.
- Story Mode existence + difficultyID 220: **HIGH** — wiki + Blizzard news + multiple guides.
- OnShow/OnHide transition-only: **HIGH** — well-established WoW behavior, multiple sources.
- Firing order ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD: **HIGH** — official wiki confirmed.
- Combat-safety of zone events + GetInstanceInfo: **HIGH** — no SecretArguments annotations, no restricted-list membership, Blizzard's own code uses these patterns from non-secure handlers.

**Research date:** 2026-05-16
**Valid until:** 2026-06-15 (30 days for stable API surface; the M of Q instanceID specifically should be captured during the next UAT session and patched into the source before release — at that point the LOW-confidence item in Q1 resolves to HIGH).

---

*Phase: 08-zone-aware-auto-show-hide*
*Research conducted: 2026-05-16*
