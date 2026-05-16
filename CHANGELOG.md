# Changelog

<!-- Release entries use the format `## v<version> — <title>` (H2, em-dash separator). -->
<!-- The GitHub Actions workflow's awk cutoff extracts only the first `## ` section into RELEASE_NOTES.md, so keep this format consistent. -->

## v1.1.0 — QoL Update

- **Auto show/hide for the March of Quel'danas raid** — entering the
  raid auto-opens the helper window; leaving the raid auto-closes it.
- **Verbose-marker toggle** — new "Use verbose markers" checkbox in
  Options > AddOns > TerribleLuraHelper. **Off by default** — the
  standard `{rt2}` / `{rt3}` / `{rt4}` / `{rt7}` markers are universal
  across every WoW client locale. Turn it on for `{circle}` /
  `{diamond}` / `{triangle}` / `{cross}` only if every player in your
  raid runs the English client and someone can't see rt markers due to
  other chat addons being incomplete; verbose token names don't expand
  on non-English clients.

## v1.0.0 — Polish + Some small improvements

- **Click-through when locked** — the helper window no longer eats
  mouse clicks once locked; clicks pass through to action bars or
  anything else beneath it
- **Channel set to SAY as defaults for new installs** — macros target
  `/s` and only the SAY channel is listened to by default; existing
  users keep their previous choices on upgrade
- **Cheat-sheet image at the top of the config panel** — rune-symbol
  reference card shows new users which marker each macro produces
- **Auto-hide refined to in-combat-only** — out of combat the window
  stays visible even when empty (so you can see the toggle is on); in
  combat it hides when empty and reappears on the next marker
- **Improved Lock/Unlock button labels** — config panel button labels
  flip immediately when you toggle them

## v0.1.0 — Initial Release

A helper for the Midnight Falls **L'ura** encounter — one spotter calls the rune sequence and everyone with the addon sees it on a dedicated window, surviving the boss-fight chat lockdown.

- **Helper window** — smile-arc display with five rune slots that fill as the spotter presses the macros; auto-clears between casts
- **Five macros** auto-created on login (`TLH_Diamond`, `TLH_Triangle`, `TLH_Circle`, `TLH_Cross`, `TLH_T`) — drag to your action bar or assign keybinds
- **Config panel** under Options > AddOns: chat channels, window scale & opacity, auto-hide, macro target channel (`/raid` / `/rw` / `/i` / `/s`), and quick action buttons (Show/Hide, Lock/Unlock, Recreate, Delete)
- **Non-addon players still benefit** — the markers land in raid chat, so they can read the sequence even without installing
- Type `/lura help` for the slash command list

**Heroic** difficulty supported. Normal (3 marks) and Mythic (rotation may vary) aren't wired up yet — leave a comment if you want them.
