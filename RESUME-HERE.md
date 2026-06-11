# Orbit Legends — resume here

This is the **canonical project folder** (moved out of OneDrive on 2026-06-10 to fix the
read-only file lock). Work here from now on, not the old OneDrive copy.

## To continue working

- **Test the game now:** double-click `build-and-open.cmd` — it rebuilds the place file
  from `src\` and opens it in Roblox Studio. Then press the Play button (or F5).
- **Edit the game:** all code is in `src\` (one config file, `src\shared\GameConfig.lua`,
  holds every tunable number). Edit, then rebuild with `build-and-open.cmd`.
- **Work with Claude here:** open this folder (`C:\dev\orbit-legends`) in VS Code or a
  terminal and run `claude`. The `.mcp.json` here auto-connects Claude to a running
  Studio instance for live edits.

## Status as of last session (2026-06-10)

- Full MVP built and tested live in Studio: world gen, 3 starter + 5 unlockable ships,
  flight, auto-mining with secured-cargo split, sell/upgrade economy, server-side PvP,
  HUD, nameplates, DataStore saves.
- Two bugs found and fixed during testing: HUD stat panel now renders; station panel
  now refreshes cargo on open.
- Not yet done (post-MVP roadmap in README.md): home-world bases, weapon-swap shop,
  missions, guilds.

## Backups

- `C:\Users\tyant\OneDrive\Apps\ROBLOX\orbit-legends` — old copy, safe to delete once
  you've confirmed this folder works.
- `C:\Users\tyant\claude-tradingview-mcp-trading\orbit-legends` — the original copy.
- Cloud: a private "Orbit LEgends" experience exists on your Roblox account (not yet
  published with this code).
