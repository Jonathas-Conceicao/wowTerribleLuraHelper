---
phase: 01-scaffolding-foundation
verified: 2026-04-30T21:00:00Z
status: passed
score: 12/12 must-haves verified (all automated checks pass; in-game smoke test confirmed by user 2026-04-30)
overrides_applied: 0
human_verification:
  - test: "Run `./scripts/install.bat` from repo root, then `/reload` in WoW (retail, Interface 120005 / Midnight). Open the chat log."
    expected: "Load banner appears, no Lua errors, addon listed."
    result: passed
    confirmed_by: user
    confirmed_at: 2026-04-30T20:25:00Z
    notes: "Banner observed: `TerribleLuraHelper loaded.` (Core.lua:84 — short form, no '/lura usage' suffix; user confirmed they prefer this). No Lua errors. Addon listed. `/lura` undefined as expected (Phase 2 deliverable). SavedVariables write not inspected, treated as assumed-fine."
---

# Phase 1: Scaffolding & Foundation — Verification Report

**Phase Goal:** A loadable, no-op TerribleLuraHelper addon ships from a repo whose layout, packaging pipeline, and conventions mirror TerribleBuffTracker, and whose first milestone branch is open.
**Verified:** 2026-04-30T21:00:00Z
**Status:** passed (after user-confirmed in-game smoke test on 2026-04-30)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | After `./scripts/install.bat` + `/reload`, addon loads with colored banner and no errors | ? HUMAN | In-game test required — filesystem and code verified; WoW client needed for runtime confirmation |
| SC-2 | Repo working state lives on `milestone/0.1.0` branch (created from main and pushed); main untouched | ✓ VERIFIED | `git rev-parse --abbrev-ref HEAD` = `milestone/0.1.0`; 9 commits ahead of main; origin confirms branch at `54d83a67b3ebfd369383133e8ea94db3f576e313`; main HEAD = `55e2b038` (unchanged) |
| SC-3 | After `/reload`, `TerribleLuraHelperDB` exists in SavedVariables with exact D-03 grouped schema | ? HUMAN | Schema init code in Core.lua fully verified (all 12 D-03 fields present and correct); actual WTF file write requires WoW client |
| SC-4 | `release.yml` committed with CHANGELOG-cutoff awk; `release.bat` pushes CURRENT branch not hardcoded main; no Phase 1 tag pushed | ✓ VERIFIED | awk pattern `awk '/^## /{if(found) exit; found=1} found' CHANGELOG.md` present in release.yml line 27; `git rev-parse --abbrev-ref HEAD` captured in release.bat line 17; `git push origin main` absent from release.bat; zero git tags |
| SC-5 | `CLAUDE.md` exists and documents chat-lockdown/no-msg/no-SendChatMessage, milestone/squash-merge workflow, stylua, architecture file map, wow-ui-source path | ✓ VERIFIED | All 8 SCAF-11 greps pass: SendChatMessage, msg constraint phrasing, chat lockdown, milestone/, squash-merge, stylua, Core.lua, wow-ui-source |

**Score:** 3/3 fully automated truths VERIFIED; 2/5 truths require human confirmation (in-game test)

---

## Required Artifacts

| Artifact | SCAF | Status | Details |
|----------|------|--------|---------|
| `TerribleLuraHelper.toc` | 01 | ✓ VERIFIED | 15 lines; Interface 120005; Title, Author, Version @project-version@, URL, Category, X-Curse-Project-ID 1529832, X-Wago-ID XKqArdKy, SavedVariables TerribleLuraHelperDB; 4 Lua files in D-02 order; no IconTexture |
| `Core.lua` | 02, 03 | ✓ VERIFIED | 88 lines; line 1 = `local addonName, ns = ...`; DB init guard present; full D-03 schema (enabled=false, 6 channels, scale=1.00, locked=true, autoHide=false, position=nil, sequence={}); backfill loop; dispatchers; colored load banner; no SendChatMessage; no CHAT_MSG_ |
| `Macros.lua` | 02 | ✓ VERIFIED | 10 lines; line 1 = `local addonName, ns = ...`; `function ns:InitMacros()` defined with empty stub body |
| `Window.lua` | 02 | ✓ VERIFIED | 10 lines; line 1 = `local addonName, ns = ...`; `function ns:InitWindow()` defined with empty stub body |
| `Config.lua` | 02 | ✓ VERIFIED | 12 lines; line 1 = `local addonName, ns = ...`; `function ns:InitConfig()` defined with empty stub body |
| `.pkgmeta` | 04 | ✓ VERIFIED | 19 lines; `package-as: TerribleLuraHelper`; `manual-changelog: filename: RELEASE_NOTES.md`; ignore list includes .gitignore, .pkgmeta, CHANGELOG.md, CLAUDE.md, README.md, LICENSE, scripts, "*.png", RELEASE_NOTES.md |
| `.gitignore` | 05 | ✓ VERIFIED | Exact patterns: `*.zip`, `.claude/`, `.\#*`, `\#*`, `*.~*` (emacs swap) |
| `.luarc.json` | 06 | ✓ VERIFIED | `"Lua.runtime.version": "Lua 5.1"`; `"Lua.workspace.library": ["C:/Users/jonat/Repositories/vscode-wow-api"]`; 7 diagnostics.globals |
| `scripts/install.bat` | 07 | ✓ VERIFIED | 14 lines; DEST = `%PROGRAMFILES(x86)%\World of Warcraft\_retail_\Interface\AddOns\TerribleLuraHelper`; explicit `copy /Y` for all 5 files (TOC + 4 Lua); no xcopy; no .blp |
| `scripts/release.bat` | 08 | ✓ VERIFIED | 35 lines; `setlocal enabledelayedexpansion`; captures HEAD via `git rev-parse --abbrev-ref HEAD`; uses `!BRANCH!`; annotated tag via `git tag -a`; no hardcoded `main`; exits 1 on missing arg |
| `.github/workflows/release.yml` | 09 | ✓ VERIFIED | 29 lines; triggers on `tags: "**"`; `permissions: contents: write`; `actions/checkout@v4` with `fetch-depth: 0`; exact D-07 awk pattern; `BigWigsMods/packager@v2` |
| `CHANGELOG.md` | 10 | ✓ VERIFIED | First line = `# Changelog`; no `## ` headings yet (0 matched); format comment present |
| `README.md` | 10 | ✓ VERIFIED | 20 lines; contains addon description, Install section, Slash Commands (/lura, /lura show, /lura hide, /lura clear, /lura config, /tlh), License section |
| `LICENSE` | 10 | ✓ VERIFIED | WTFPL v2; first line = `            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE` (12 leading spaces); copyright = `Copyright (C) 2026 Jonathas-Conceicao` |
| `CLAUDE.md` | 11 | ✓ VERIFIED | 80 lines; all 8 SCAF-11 content greps pass |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `milestone/0.1.0` branch | origin remote | `git push -u origin milestone/0.1.0` | ✓ WIRED | `git ls-remote` confirms `refs/heads/milestone/0.1.0` at `54d83a67...` on origin |
| `TerribleLuraHelper.toc` | Core.lua, Macros.lua, Window.lua, Config.lua | Load-order list | ✓ WIRED | awk order check: `Core.lua Macros.lua Window.lua Config.lua` (exact D-02 order) |
| `Core.lua ADDON_LOADED` | `TerribleLuraHelperDB` | `if not TerribleLuraHelperDB then ... end` + backfill | ✓ WIRED | Init guard on line 19; backfill lines 42–71; `ns.db = TerribleLuraHelperDB` on line 39 |
| `Core.lua ADDON_LOADED` | `ns:InitMacros / ns:InitWindow / ns:InitConfig` | Guarded dispatcher calls | ✓ WIRED | Lines 74–82 dispatch to all three; all three stubs define the receiving functions |
| `.github/workflows/release.yml awk step` | `CHANGELOG.md` `## ` headings | `awk '/^## /{if(found) exit; found=1} found' CHANGELOG.md > RELEASE_NOTES.md` | ✓ WIRED | Exact awk pattern present in release.yml; CHANGELOG.md uses `# Changelog` H1 + `## v<version>` H2 format per D-12 |
| `scripts/install.bat` | Plan 02 addon files | `copy /Y` for each of 5 files | ✓ WIRED | All 5 explicit copy lines present; destination path matches `TerribleLuraHelper` subfolder |
| `scripts/release.bat` | `git push origin <current-branch> <tag>` | `git rev-parse --abbrev-ref HEAD` → `!BRANCH!` | ✓ WIRED | Line 17 captures branch; line 29 uses `!BRANCH!` in push; no hardcoded `main` |

---

## Decision Compliance

| Decision | Check | Result |
|----------|-------|--------|
| D-02: TOC load order Core first | `awk ... \| tr '\n' ' '` = `Core.lua Macros.lua Window.lua Config.lua ` | PASS |
| D-03: Exact grouped schema | All 12 schema fields verified by grep | PASS |
| D-04: `db.window.position` NOT backfilled | Only comment on line 66; no assignment expression | PASS |
| D-06: No Phase 1 tag | `git tag` returns empty | PASS |
| D-07: Exact awk pattern | Pattern matches verbatim in release.yml line 27 | PASS |
| D-08: release.bat pushes current branch | `rev-parse --abbrev-ref HEAD` present; no `push origin main` | PASS |
| D-09: Curse ID 1529832, Wago ID XKqArdKy | Both exact literal values in TOC | PASS |

---

## Hard Constraint Compliance

| Constraint | Grep | Result |
|-----------|------|--------|
| No `SendChatMessage` in any `.lua` file | `grep -r "SendChatMessage" *.lua` | PASS (exit 1 = no matches) |
| No `COMBAT_LOG_EVENT_UNFILTERED` in any `.lua` file | `grep -r "COMBAT_LOG_EVENT_UNFILTERED" *.lua` | PASS (exit 1 = no matches) |
| No `msg` argument manipulation in any `.lua` file | `grep -rE "\bmsg\b.*(:|gsub|match|find|len|#)" *.lua` | PASS (exit 1 = no matches) |

Note: Window.lua's comment references `C_ChatInfo.ReplaceIconAndGroupExpressions(msg, nil, false)` as documentation of the Phase 2 intent — this is a comment, not code, and the grep for Lua-expression `msg` manipulation correctly produces zero code matches.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|------------|------------|-------------|--------|---------|
| SCAF-01 | 01-02 | TOC declares Interface 120005, SavedVariables, packager hooks, file load list | ✓ SATISFIED | TOC verified field-by-field |
| SCAF-02 | 01-02 | Namespace pattern `local addonName, ns = ...` in all Lua files | ✓ SATISFIED | All 4 Lua files — line 1 confirmed |
| SCAF-03 | 01-02 | SavedVariables initialized with grouped D-03 schema + backfill | ✓ SATISFIED | Core.lua lines 19–71 verified |
| SCAF-04 | 01-03 | `.pkgmeta` with package-as, RELEASE_NOTES.md, ignore list | ✓ SATISFIED | All pkgmeta fields verified |
| SCAF-05 | 01-01 | `.gitignore` excludes *.zip, .claude/, emacs swap | ✓ SATISFIED | All exact patterns confirmed |
| SCAF-06 | 01-01 | `.luarc.json` configures Lua 5.1 + vscode-wow-api | ✓ SATISFIED | Both keys confirmed |
| SCAF-07 | 01-03 | `scripts/install.bat` copies all addon files to WoW retail AddOns | ✓ SATISFIED | 5 per-file copy /Y lines confirmed |
| SCAF-08 | 01-03 | `scripts/release.bat` tags and pushes (current-branch aware) | ✓ SATISFIED | D-08 fix confirmed; no hardcoded main |
| SCAF-09 | 01-03 | `.github/workflows/release.yml` runs BigWigs Packager with CHANGELOG awk | ✓ SATISFIED | All structural elements confirmed |
| SCAF-10 | 01-01 | CHANGELOG.md, README.md, LICENSE exist at repo root | ✓ SATISFIED | All three files present with correct content |
| SCAF-11 | 01-01 | CLAUDE.md documents constraints, workflow, stylua, file map, style ref | ✓ SATISFIED | All 8 content greps pass on 80-line file |
| SCAF-12 | 01-01 | Work on `milestone/0.1.0` branch; main untouched | ✓ SATISFIED | 9 commits on milestone branch; main HEAD = 55e2b038 |

**All 12 Phase 1 SCAF-* requirements satisfied by automated checks.**

No orphaned Phase 1 requirements detected — REQUIREMENTS.md maps exactly SCAF-01..12 to Phase 1 and all are claimed by the three plans.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Macros.lua` | 8–10 | `function ns:InitMacros()` empty body | ℹ️ Info (intentional stub) | Intentional Phase 1 stub; Phase 2 fills the body. Does not prevent phase goal ("no-op addon"). |
| `Window.lua` | 8–10 | `function ns:InitWindow()` empty body | ℹ️ Info (intentional stub) | Intentional Phase 1 stub; Phase 2 fills the body. |
| `Config.lua` | 10–12 | `function ns:InitConfig()` empty body | ℹ️ Info (intentional stub) | Intentional Phase 1 stub; Phase 3 fills the body. |

**No blocker or warning anti-patterns.** The three empty Init function bodies are Phase 1's stated deliverable per D-01 — the phase goal explicitly describes these as stubs to be filled by Phase 2/3. The pattern does NOT constitute a hidden implementation gap because the addon is intended to be a no-op.

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — addon requires the WoW Lua VM; no runnable entry point exists outside the WoW client. Lua files parse correctly (confirmed by code review; stylua confirmed exit 0 in Summary reports), but behavior can only be confirmed inside WoW. Deferred to human verification item below.

---

## Code Review Cross-Reference

REVIEW.md status: `clean` — critical: 0, warning: 0, info: 5. Five informational notes (IN-01 through IN-05) are non-blocking:
- IN-01: Sub-table backfill truthy vs. type-safe check (cosmetic, not a correctness bug in Phase 1)
- IN-02: Init dispatcher nil guards are unreachable under normal load (defensible pattern)
- IN-03: Double-backslash in SOURCE path construction (cosmetic; Windows collapses it)
- IN-04: Detached-HEAD edge case in release.bat (hardening suggestion, not a bug)
- IN-05: Empty RELEASE_NOTES.md until v0.1.0 CHANGELOG entry added (by design per D-06)

---

## Human Verification Required

### 1. In-Game Smoke Test (mandatory before phase close)

**Test:** On a machine with WoW Midnight (Interface 120005) installed, run `./scripts/install.bat` from the repo root. Launch or switch to WoW. Type `/reload` (or log in to a character). Open the General or default chat tab.

**Expected:**
- The colored banner `TerribleLuraHelper loaded.` (purple/violet, hex `aa44ff`) appears in the chat frame — no Lua errors, no "addon not found" or "missing file" warnings.
- In the AddOns list (character select or `/framexml show` equivalent), `TerribleLuraHelper` appears as a recognized addon with no missing-file warnings for Core.lua, Macros.lua, Window.lua, or Config.lua.
- After a second `/reload`, the file `WTF/Account/<account>/<realm>/<character>/SavedVariables/TerribleLuraHelperDB.lua` exists and contains a Lua table with: `enabled = false`, a `listenChannels` subtable with all six channel keys set to `true`, a `window` subtable with `scale = 1.0`, `locked = true`, `autoHide = false`, and `position = nil` (or absent), and an empty `sequence` table.

**Why human:** The WoW Lua VM executes the `.toc` load path, fires `ADDON_LOADED`, and performs the SavedVariables round-trip — none of these can be simulated by a static code analysis tool. This is the ONLY human verification item for Phase 1.

---

## Gaps Summary

No gaps found. All 12 SCAF-* requirements are fully satisfied by filesystem, git state, and grep evidence. The sole remaining item is the in-game smoke test, which is an inherent constraint of WoW addon development (no offline test harness) rather than an implementation gap.

---

_Verified: 2026-04-30T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
