# Changelog

<!-- Release entries use the format `## v<version> — <title>` (H2, em-dash separator). -->
<!-- The GitHub Actions workflow's awk cutoff extracts only the first `## ` section into RELEASE_NOTES.md, so keep this format consistent. -->

## v0.1.0 — Initial Release

A helper for the Midnight Falls **L'ura** encounter — one spotter calls the rune sequence and everyone with the addon sees it on a dedicated window, surviving the boss-fight chat lockdown.

- **Helper window** — smile-arc display with five rune slots that fill as the spotter presses the macros; auto-clears between casts
- **Five macros** auto-created on login (`TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T`) — drag to your action bar or assign keybinds
- **Config panel** under Options > AddOns: chat channels, window scale & opacity, auto-hide, macro target channel (`/raid` / `/rw` / `/i` / `/s`), and quick action buttons (Show/Hide, Lock/Unlock, Recreate, Delete)
- **Non-addon players still benefit** — the markers land in raid chat, so they can read the sequence even without installing
- Type `/lura help` for the slash command list

**Heroic** difficulty supported. Normal (3 marks) and Mythic (rotation may vary) aren't wired up yet — leave a comment if you want them.
