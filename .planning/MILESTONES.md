# Milestones: TerribleLuraHelper

Shipped milestone history. Each entry links to its archived ROADMAP and REQUIREMENTS snapshots under `.planning/milestones/`.

---

## v1.0.0 — Polish & Defaults

**Shipped:** 2026-05-10
**Phases:** 4 → 5 → 6 (3 phases, 1 plan each)
**Commits since v0.1.0:** 44 squashed → single commit on `main`
**Branch:** `milestone/1.0.0` → squash-merged to `main`
**Archive:**
- [Roadmap](milestones/v1.0.0-ROADMAP.md)
- [Requirements](milestones/v1.0.0-REQUIREMENTS.md)
- Phases: `milestones/v1.0.0-phases/`

### Delivered

A more polished, less intrusive helper. SAY-centric defaults match how most pugs and casual groups actually use the addon, the helper window finally gets out of your way when locked, and the config panel grew a built-in rune-symbol cheat sheet so new spotters don't need an external reference.

### Key accomplishments

- **Click-through when locked** — the helper window no longer eats mouse clicks once locked; clicks pass through to action bars or anything else beneath it (WIN-11, WIN-12)
- **SAY-centric defaults for new installs** — `listenChannels.SAY=true` (other 5 off) and `macroChannel="SAY"` on fresh DBs; upgrade-safe backfill preserves existing user choices via `if X == nil then` idiom (SAFE-06 — zero `db.X = db.X or DEFAULT` instances repo-wide) (SCAF-13, SCAF-14, SCAF-15)
- **Auto-hide reframed to in-combat-only** — out of combat the empty window stays visible (toggle is self-evident); in combat hides when empty; combat-state transitions re-evaluate immediately via permanent `PLAYER_REGEN_*` listener; soft-hide invariant preserved (`SetAlpha(0)`, NEVER `win:Hide()`) (WIN-13, WIN-14, WIN-15, CFG-14, SAFE-05)
- **Cheat-sheet image at the top of the config panel** — rune-to-marker reference card (`reference.tga`, 319×143) ships via BigWigs Packager pipeline and renders first in the panel (CFG-12, SCAF-16, SCAF-17)
- **Live Show/Hide and Lock/Unlock button labels** — config-panel button labels flip immediately when toggled from anywhere (slash command, on-window button, panel itself) without losing scroll position; implementation via `hooksecurefunc(SettingsButtonControlMixin, "Init", ...)` capturing rendered frame refs (CFG-13)

### Requirements: 15/15 complete

All v1.0.0 requirements shipped. See [milestones/v1.0.0-REQUIREMENTS.md](milestones/v1.0.0-REQUIREMENTS.md) for full traceability.

### Stats

| Metric | Value |
|---|---|
| Commits squashed | 44 |
| Files changed | 69 |
| LOC delta | +7,188 / −288 |
| New repo files | `reference.tga`, `templates.xml`, `assets/reference.png` (repo-only source) |
| Timeline | 2026-04-30 → 2026-05-10 (10 days) |

---

## v0.1.0 — Initial Release

**Shipped:** 2026-05-01
**Phases:** 1 → 2 → 3 (3 phases, 7 plans)
**Branch:** `milestone/0.1.0` → squash-merged to `main`
**Archive:** Phase artifacts at `.planning/archive/v0.1.0/`

### Delivered

A helper for the Midnight Falls L'ura encounter — one spotter calls the rune sequence and everyone with the addon sees it on a dedicated window, surviving the boss-fight chat-messaging-lockdown that blocks normal addon chat output.

### Key accomplishments

- **Helper window** — smile-arc display with five rune slots that fill as the spotter presses the macros; auto-clears between casts (WIN-01..06, WIN-09)
- **Five macros** auto-created on login (`TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T`) with combat-lockdown deferral via `PLAYER_REGEN_ENABLED` (MACR-01..05)
- **Config panel** under Options > AddOns via the modern Settings.* API: chat channel toggles, window scale + alpha sliders, auto-hide toggle, macro target channel dropdown, action buttons (CFG-01..11, WIN-08, WIN-10)
- **Taint-safe chat pipeline** — `C_ChatInfo.ReplaceIconAndGroupExpressions` opaque passthrough; zero indexing/matching/concat of `msg`; visibility-gated chat-event registration (AMEND-01) (SAFE-01..04)
- Slash commands `/lura` + `/tlh` alias; `/lura hide` disables processing entirely (CMD-01..03, CMD-06, CMD-07)

### Requirements: 47/47 complete

See git history at commit `b601cb7` for the v0.1.0 REQUIREMENTS.md snapshot.
