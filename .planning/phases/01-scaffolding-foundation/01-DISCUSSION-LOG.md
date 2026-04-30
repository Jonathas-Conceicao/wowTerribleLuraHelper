# Phase 1: Scaffolding & Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-30
**Phase:** 01-scaffolding-foundation
**Areas discussed:** Module decomposition, SavedVariables schema, First-tag release strategy, Curse/Wago project IDs + license + docs scope

---

## Selection: Which areas to discuss?

| Option | Description | Selected |
|--------|-------------|----------|
| Module decomposition | Single Core.lua to start (split later) vs. Core/Macros/Window/Config split now — affects how Phase 2 & 3 stub their entry points | ✓ |
| SavedVariables schema shape | Flat keys (db.scale, db.channels.RAID) vs. grouped (db.window.scale, db.listenChannels.RAID) — locks read/write paths for Phase 2 & 3 | ✓ |
| First-tag release strategy | Push v0.0.1 during Phase 1 to live-test the GHA pipeline, OR just verify YAML syntax and tag v0.1.0 at milestone end | ✓ |
| Curse/Wago project IDs + license + readme scope | TOC packager IDs (leave blank or register now), LICENSE choice (WTFPL like TBT?), CHANGELOG/README initial content | ✓ |

**User's choice:** All four.

---

## Module Decomposition

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-split into 4 files | Core.lua / Macros.lua / Window.lua / Config.lua — stubs in Phase 1, filled in Phase 2/3. Matches TBT's per-module style. | ✓ |
| Start single-file, split later | Everything in Core.lua at first. Easier to ship Phase 1 quickly. Phase 2 split decision deferred. | |
| Mirror POC layout exactly | Single Core.lua matching the POC's structure (top-down: macros, window, chat, slash). | |
| You decide | Claude picks based on what makes Phase 2/3 cleanest | |

**User's choice:** Pre-split into 4 files.
**Notes:** Locked-in. Phase 1 stubs out four files with namespace boilerplate and `ns.Init<Macros|Window|Config>` placeholders called from Core.lua's ADDON_LOADED handler.

---

## SavedVariables Schema

| Option | Description | Selected |
|--------|-------------|----------|
| Grouped by area | db.listenChannels.{...}, db.window.{...}, db.enabled, db.sequence. Easier to extend; matches TBT's containerSettings pattern. | ✓ |
| Flat keys | db.channelSAY, db.channelRAID, ..., db.scale, db.locked, db.autoHide, db.enabled. Simpler to read; easier to bind to RegisterAddOnSetting. | |
| Hybrid | db.channels = table, scale/locked/autoHide/enabled flat. Pragmatic split. | |

**User's choice:** Grouped by area, **and** save the position so it's persistent across reloads and relogs.
**Notes:** The position-persistence requirement was added during this discussion — added as **WIN-09** in REQUIREMENTS.md and incorporated into the SCAF-03 schema (`db.window.position = nil` default; written on drag-end via `frame:GetPoint()`, applied via `SetPoint(unpack(...))` on first show). Schema also uses literal channel keys (`SAY` / `RAID` / `RAID_LEADER` / `RAID_WARNING` / `INSTANCE_CHAT` / `INSTANCE_CHAT_LEADER`) so the chat-event handler can do `db.listenChannels[event:sub(10)]` directly.

---

## First-Tag Release Strategy

### Question 1: Tag during Phase 1?

| Option | Description | Selected |
|--------|-------------|----------|
| Tag v0.0.1 from milestone branch | Live-tests the BigWigs Packager pipeline early. | |
| Skip tag, verify YAML only | Phase 1 ships without a release. Pipeline first exercised at v0.1.0 milestone-merge. | ✓ |
| Tag v0.0.1 from main after squash-merge | Squash Phase 1 to main first, then tag from main. | |

**User's choice:** Skip tag, verify YAML only — but **also implement the CHANGELOG cutoff logic in the release workflow**.
**Notes:** Phase 1 commits the GHA workflow (including the awk that extracts the latest CHANGELOG section into RELEASE_NOTES.md) but does not push a tag. First real tag is v0.1.0 at milestone merge.

### Question 2: release.bat branch policy?

| Option | Description | Selected |
|--------|-------------|----------|
| Any branch | release.bat tags wherever HEAD is. | ✓ |
| Main only | release.bat checks current branch == main and aborts otherwise. | |
| Configurable, default main | Add a flag like `--allow-non-main` for explicit override. | |

**User's choice:** Any branch.
**Notes:** TBT's release.bat hardcodes `git push origin main "%TAG%"` — that needs to be parameterized to the current branch (e.g., via `git rev-parse --abbrev-ref HEAD`). Captured as D-08 in CONTEXT.md.

---

## Curse/Wago, License, Docs

### Question 1: TOC packager IDs

| Option | Description | Selected |
|--------|-------------|----------|
| Omit both fields | Leave them out until you register the project. | |
| Include with placeholder values | Empty fields, documents intent. | |
| Register and fill in now | Register on CurseForge + Wago, fill in real IDs. | ✓ |

**User's choice:** CurseForge ID **1529832**, Wago ID **XKqArdKy** — already registered, fill in immediately.

### Question 2: License

| Option | Description | Selected |
|--------|-------------|----------|
| WTFPL (matches TBT) | Same as TerribleBuffTracker. Maximally permissive. | ✓ |
| MIT | Permissive but more standard. | |
| Apache-2.0 | Permissive with explicit patent grant. | |
| GPL-3.0 | Copyleft. | |

**User's choice:** WTFPL (matches TBT). Copyright 2026 Jonathas-Conceicao.

### Question 3: README/CHANGELOG scope at Phase 1 close

| Option | Description | Selected |
|--------|-------------|----------|
| README stub + CHANGELOG bootstrap | README: 1-paragraph + install + slash commands. CHANGELOG: header + format note. | ✓ |
| Full README, empty CHANGELOG | README documents all v1 features upfront. CHANGELOG empty. | |
| Both stubs (minimum viable) | Just headers. | |

**User's choice:** README stub + CHANGELOG bootstrap.
**Notes:** CHANGELOG must use `## v<version> — <title>` heading format so the awk-cutoff in release.yml works.

---

## Claude's Discretion

- File header / module-doc comments tone and length in stub Lua files.
- Exact wording of the "loaded" banner Core.lua prints.
- Banner color (TBT cyan vs. POC purple — Claude picks).
- README install section exact phrasing.
- Whether to add a `.editorconfig` (skip for now).

## Deferred Ideas

- Addon `.blp` icon (OOS in PROJECT.md).
- Custom `stylua.toml` (defaults are fine).
- CurseForge/Wago API tokens in GHA (commented out, wire up when publishing).
