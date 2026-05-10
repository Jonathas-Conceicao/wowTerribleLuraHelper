# Phase 1: Scaffolding & Foundation - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning

<domain>
## Phase Boundary

A loadable, no-op TerribleLuraHelper addon ships from a repo whose layout, packaging pipeline, and conventions mirror TerribleBuffTracker, with the `milestone/0.1.0` branch open. Runtime behavior (macros, window, chat handling) is **not** in this phase — Phase 1 produces empty/stub modules that Phase 2 and 3 fill.

In scope: `.toc`, `.pkgmeta`, `.gitignore`, `.luarc.json`, `LICENSE`, `README.md`, `CHANGELOG.md`, `CLAUDE.md` (already exists, may need touch-up), `scripts/install.bat`, `scripts/release.bat`, `.github/workflows/release.yml`, four stub Lua files, SavedVariables defaults, milestone branch creation.

Out of scope (Phase 2/3): macro registration, helper window, chat-event handling, slash command logic, Settings panel registration.

</domain>

<decisions>
## Implementation Decisions

### Module Decomposition

- **D-01:** Pre-split source into 4 Lua files at Phase 1 — `Core.lua`, `Macros.lua`, `Window.lua`, `Config.lua`. Phase 1 lands them as stubs (each with the namespace boilerplate `local addonName, ns = ...`) and an `ns.Init<Macros|Window|Config>` placeholder function called from `Core.lua` on `ADDON_LOADED`. Phase 2 fills `Macros.lua` and `Window.lua`; Phase 3 fills `Config.lua`. **Why:** matches TBT's per-module style, gives Phase 2/3 clear file boundaries before code lands, avoids a "split" sub-task later.
- **D-02:** `.toc` lists files in load order: `Core.lua, Macros.lua, Window.lua, Config.lua`. Core.lua first so it sets up the namespace for the others.

### SavedVariables Schema

- **D-03:** `TerribleLuraHelperDB` is grouped by area, not flat. Schema initialized in `Core.lua` on `ADDON_LOADED` (with a backfill loop for new keys, matching TBT's pattern):

  ```lua
  TerribleLuraHelperDB = {
    enabled = false,
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
      locked = true,
      autoHide = false,
      position = nil,  -- { point, relativeTo, relativePoint, x, y } — written on drag-end, read on first show
    },
    sequence = {},  -- post-processed |T...|t strings, persisted across /reload (opaque)
  }
  ```

- **D-04:** Window position **persists across `/reload` and full game-session restarts** (NEW requirement on top of REQUIREMENTS.md as written — added as WIN-09). `db.window.position` is written by an `OnDragStop` script (after `StopMovingOrSizing`) using `frame:GetPoint()`, and re-applied on first show via `SetPoint(unpack(db.window.position))` if the table is non-nil. If nil, default anchor `CENTER UIParent CENTER 200 80` is used (matches POC).

- **D-05:** Use the literal channel-flag names `INSTANCE_CHAT` / `INSTANCE_CHAT_LEADER` in the DB (matching the WoW event suffixes `CHAT_MSG_INSTANCE_CHAT` / `CHAT_MSG_INSTANCE_CHAT_LEADER`). Lets the chat-event handler check `db.listenChannels[event:sub(10)]` (where `event` is e.g. `"CHAT_MSG_RAID_LEADER"`) without a translation table — the `SAY` / `RAID` / `RAID_LEADER` / `RAID_WARNING` keys also match this scheme.

### First-Tag Release Strategy

- **D-06:** Phase 1 does **not** push a release tag. The `release.yml` workflow file is committed and verified syntactically; the first real tag is `v0.1.0` at milestone-merge time. **Why:** avoids wasting a v0.0.x slot when there's no release-worthy content to ship. The pipeline's first live exercise is the milestone tag.

- **D-07:** `release.yml` includes the CHANGELOG cutoff awk that extracts only the first `## ` section into `RELEASE_NOTES.md` before BigWigs Packager runs (copied verbatim from TBT's workflow file). **Why:** the awk-cutoff is the only mechanism translating `CHANGELOG.md` into per-release notes; without it, every release would be the full changelog.

- **D-08:** `scripts/release.bat <version>` works from any branch — no main-only check. **Why:** lets the user release from a milestone branch if needed; the user accepts the small risk of an accidental tag on dirty WIP. Script body matches TBT's: tag `v<version>`, push `origin <current-branch> <tag>`. Note the current TBT script hardcodes `main` in the push — this needs to be parameterized to the current branch (e.g., `git rev-parse --abbrev-ref HEAD`).

### Curse/Wago Project IDs, License, Docs

- **D-09:** `.toc` includes the registered packager IDs from day one: `## X-Curse-Project-ID: 1529832` and `## X-Wago-ID: XKqArdKy`. **Why:** project is already registered on CurseForge and Wago; no reason to defer.

- **D-10:** LICENSE: WTFPL v2 (Copyright 2026 Jonathas-Conceicao). Verbatim copy of TBT's LICENSE text, only the year-and-author line carries.

- **D-11:** `README.md` at Phase 1 close: 1-paragraph description (lifted from PROJECT.md "What This Is"), an "Install" section pointing at the release-ZIP path (or "Install via CurseForge / Wago / GitHub Releases once published"), and a "Slash Commands" section listing the v1 commands. No screenshots, no contributor guide.

- **D-12:** `CHANGELOG.md` at Phase 1 close: `# Changelog` heading and a one-line comment noting that entries follow the v0.X.X format with `## v<version> — <title>` headings (so the awk cutoff in the GHA workflow has a stable anchor). No version entries until v0.1.0 milestone-close. **This format is what the awk cutoff depends on** — keep it consistent.

### Stylua

- **D-13:** No `.stylua.toml` in repo (matches TBT — defaults are fine). The `stylua` workflow rule in CLAUDE.md is sufficient.

### Claude's Discretion

- File header / module-doc comments at the top of each stub Lua file: planner picks tone/length. POC's module header is a good model but not required to copy.
- README install section copy: planner can phrase install steps. Just keep it short.
- Whether to add a `.editorconfig` or any other repo-root config beyond the listed ones — defer to planner.
- Banner color and exact load-message string in Core.lua's print (TBT uses `|cff00ccff` cyan; TLH could use a different color — Claude picks).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — "What This Is", Core Value, full v1 requirements list, Out of Scope, Constraints, Key Decisions
- `.planning/REQUIREMENTS.md` — 44+1 v1 REQ-IDs (SCAF-01..12 own this phase; the new WIN-09 below adds position persistence to Phase 2's scope)
- `.planning/ROADMAP.md` — phase definitions and success criteria; Phase 1 success criterion #4 is **superseded by D-06** (no v0.0.1 tag)
- `CLAUDE.md` — workflow rules (`milestone/<version>`, squash-merge, stylua), hard taint constraints

### Functional spec (POC)
- `C:\Users\jonat\Repositories\WeakerScripts\Samples\LuraPatternHelper.lua` — the working POC, all 297 lines. Phase 1 doesn't port it but planner should skim the module-header docstring for context on what the file structure has to support.

### Sibling addon (scaffolding source-of-truth)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\TerribleBuffTracker.toc` — .toc shape to mirror (Interface 120005, packager hooks, file load list)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\.pkgmeta` — package-as / manual-changelog / ignore-list pattern
- `C:\Users\jonat\Repositories\TerribleBuffTracker\.gitignore` — `*.zip`, `.claude/`, emacs swap files
- `C:\Users\jonat\Repositories\TerribleBuffTracker\.luarc.json` — Lua 5.1 + `vscode-wow-api` workspace library
- `C:\Users\jonat\Repositories\TerribleBuffTracker\LICENSE` — WTFPL v2 text to copy (only update copyright year)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\Core.lua` — namespace + `ADDON_LOADED` SavedVariables init + backfill loop pattern; also slash command registration (TBT uses `/tbt`, TLH uses `/lura` + `/tlh`)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\.github\workflows\release.yml` — full GHA workflow including the CHANGELOG-cutoff awk to copy
- `C:\Users\jonat\Repositories\TerribleBuffTracker\scripts\install.bat` — install pattern (copy each file individually, NOT `xcopy *.lua` — easier to grep for missing files)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\scripts\release.bat` — release pattern (must be modified for D-08: push current branch instead of hardcoded `main`)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\CLAUDE.md` — reference format for own CLAUDE.md (already largely mirrored)
- `C:\Users\jonat\Repositories\TerribleBuffTracker\CHANGELOG.md` — reference format for entries (`## v0.1.0 — Title`); Phase 1's CHANGELOG.md only needs the header

### Settings API research (consumed in Phase 3, not Phase 1, but listed for traceability)
- `.planning/research/SETTINGS_API.md` — verified `Settings.*` API patterns for Phase 3

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **WTFPL LICENSE text** — verbatim copy from `TerribleBuffTracker/LICENSE`, change copyright year/name only.
- **`.pkgmeta` template** — copy from TBT, change `package-as: TerribleBuffTracker` → `TerribleLuraHelper`.
- **GHA `release.yml`** — copy from TBT verbatim; the CHANGELOG-cutoff awk in step 2 is exactly what we need.
- **install.bat structure** — copy from TBT, replace addon name and the per-file copy list.
- **release.bat structure** — copy from TBT, replace addon name AND **fix the hardcoded `main` in `git push origin main "%TAG%"`** to push the current branch (D-08).
- **Core.lua SavedVariables init pattern** — copy the `if not TerribleBuffTrackerDB then ... end` + backfill loop from TBT's Core.lua (lines 14-83), adapt for the grouped TLH schema in D-03.

### Established Patterns
- **Namespace:** `local addonName, ns = ...` — first line of every Lua file. Module init functions hang off `ns.` (e.g. `ns:InitMacros()`, `ns:InitWindow()`, `ns:InitConfig()`).
- **Backfill loop on ADDON_LOADED:** add new keys defensively to existing DBs so users who upgrade don't lose state. Pattern: `if cs.newField == nil then cs.newField = default end`.
- **Per-file load order in .toc:** `Core.lua` first (namespace + DB + dispatcher), then leaf modules.
- **One-time chat print on load:** TBT prints `|cff00ccff TerribleBuffTracker|r loaded.` — TLH should follow with its own color/text.

### Integration Points
- `.toc` declares load order — file additions go here.
- `Core.lua`'s `OnEvent` ADDON_LOADED handler is the integration point for new sub-modules — call `ns:InitMacros()` etc. from there.
- The four stub Lua files have `ns.InitMacros = function() end` style — Phase 2/3 expand the function bodies.

</code_context>

<specifics>
## Specific Ideas

- **Window position field** is a behavioral tightening, not scope creep — the user explicitly asked for it. New requirement WIN-09: "Window position persists across /reload and full game-session restarts; on first show after a fresh install, the default anchor matches the POC (`CENTER UIParent CENTER 200 80`)."
- **CurseForge ID 1529832** and **Wago ID XKqArdKy** are already registered — fill in immediately.
- **Banner color preference:** none specified — Claude picks. (POC uses `|cffaa44ff` purple/violet, fitting given the Midnight setting; would mirror well.)
- **`release.bat` push behavior** must use the current branch, not `main` — TBT's hardcoded `main` is a bug/limitation we don't want to inherit.
- **CHANGELOG bootstrap format:** must use `## v<version> — <title>` so the awk cutoff (`/^## /{if(found) exit; found=1} found`) works. Don't use H3 or any other heading style for releases.

</specifics>

<deferred>
## Deferred Ideas

- **Addon `.blp` icon** — explicitly OOS in PROJECT.md; revisit after first release.
- **`.editorconfig`** — Claude's discretion in this phase; may add later.
- **`stylua.toml`** — TBT doesn't have one; defaults work.
- **CurseForge/Wago API tokens in GHA** — TBT's workflow has them commented out (`# CF_API_KEY: ...`); same approach for TLH. User can wire up later when ready to publish to CF/Wago.
- **Addon-managed action-bar binding** — explicitly OOS (Blizzard restriction).
- **Auto-show window on combat start** — explicitly OOS.

</deferred>

---

*Phase: 01-scaffolding-foundation*
*Context gathered: 2026-04-30*
