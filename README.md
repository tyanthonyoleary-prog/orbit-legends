# Orbit Legends

An open-world multiplayer space game for Roblox: explore, mine asteroids, upgrade your ship, fight other pilots, and progress toward capital-class vessels.

This repository contains the complete **MVP** — every system listed below is implemented in Luau with a modular, server-authoritative architecture. The entire world (station, starfield, asteroid fields, ships) is generated procedurally at runtime, so **no uploaded assets are required** to play it.

## What's in the MVP

| Feature | Status |
|---|---|
| Central space station with safe zone | ✅ Built at world origin, 3,000-stud no-PvP radius |
| Three starter ships (Scout / Fighter / Heavy Hauler) | ✅ Plus 5 unlockable ships purchasable with credits |
| Arcade flight controls (third-person chase cam) | ✅ Client-owned physics for zero-lag handling |
| Asteroid mining (Iron, Copper, Titanium, Crystal, Dark Matter) | ✅ Auto-mines when stopped near a rock; asteroids shrink and respawn |
| Secured resource system | ✅ 50% of mined cargo can never be lost on death |
| Resource selling + credit economy | ✅ Sell at the station |
| 5-category upgrade system (Engine, Shields, Mining, Cargo, Weapons) | ✅ 10 levels each, exponential costs, resource gates at Lv. 4/7/10 |
| Server-authoritative PvP combat | ✅ Hitscan lasers, shields-then-hull, energy management, kill bounties + loot |
| Floating ship gamertags | ✅ Name, class, shield/hull/cargo bars |
| Pilot HUD | ✅ Shield, hull, energy, cargo, speed, credits, mining indicator, notifications |
| DataStore persistence | ✅ Credits, ships, upgrades, secured cargo, stats; autosave + save-on-leave |

## Getting it into Roblox Studio

### Option A — Rojo (recommended)

1. Install [Rojo](https://rojo.space) (`aftman add rojo-rbx/rojo` or the VS Code extension).
2. From this folder run:
   ```
   rojo build -o OrbitLegends.rbxlx
   ```
   and open the file in Studio — or run `rojo serve` and connect the Rojo plugin for live sync.

### Option B — Manual copy

Recreate this layout in Studio (each `.lua` file becomes a script of the matching type):

```
ReplicatedStorage
└── Shared (Folder)
    ├── GameConfig   (ModuleScript)
    ├── Remotes      (ModuleScript)
    └── ShipStats    (ModuleScript)
ServerScriptService
└── OrbitLegends (Script, source = src/server/init.server.lua)
    ├── DataSystem, ZoneSystem, WorldGen, ShipBuilder, ShipSystem,
    ├── ResourceSystem, MiningSystem, CombatSystem,
    └── EconomySystem, UpgradeSystem   (all ModuleScripts, children of the Script)
StarterPlayer
└── StarterPlayerScripts
    └── OrbitLegendsClient (LocalScript, source = src/client/init.client.lua)
        ├── ClientState, FlightController, CombatClient,
        └── HUD, Nameplates, StationUI   (all ModuleScripts, children of the LocalScript)
```

### Enable saving

DataStores need: **Game Settings → Security → Enable Studio Access to API Services** (the place must be published). Without it the game runs fine in a no-save mode and warns in the output.

## How to play

1. Spawn on the station platform — the hangar opens automatically for new pilots.
2. Pick a ship and hit **LAUNCH**; you're auto-seated and flying.
3. Fly out to an asteroid belt, stop next to a rock — mining starts automatically. Half of everything you mine is **secured** (kept even if you're destroyed).
4. Fly back inside the glowing safe-zone sphere, open the **Station** panel, **SELL ALL**, and buy upgrades or new ships.
5. Venture into the outer belts for Titanium, Crystal, and Dark Matter — but PvP is live out there.

### Controls

| Input | Action |
|---|---|
| Mouse | Steer (locked to screen center while flying) |
| W / S | Throttle forward / reverse |
| Space / Left Ctrl | Vertical strafe up / down |
| Left Mouse (hold) | Fire weapons |
| Jump | Exit the pilot seat |
| H | Hangar panel (near station) |
| T | Trade & upgrades panel (near station) |

## Architecture notes

- **Server-authoritative everything that matters.** Clients send only *intent* (aim point, "sell", "buy X"). The server validates fire rate, energy, range, zone rules, prices, ownership, and cooldowns. Damage, cargo, and credits never exist on the client.
- **Client-owned flight physics.** The server grants network ownership of the ship to its pilot, so flying feels instant; positions are sanity-bounded by Roblox physics, and all combat math runs server-side from server-known positions.
- **Attributes over remotes.** Ship state (shield, hull, energy, cargo fill, stats) is mirrored as model attributes, which replicate automatically — HUD and nameplates read them with zero custom networking. Beam visuals use a single `UnreliableRemoteEvent`.
- **One config file.** Every number — ship stats, weapon types, resource values, field layouts, upgrade curves, safe-zone radius, secured percentage — lives in `src/shared/GameConfig.lua`. Balance the whole game without touching system code.
- **Expandable by design.** New ships = a config entry + a builder spec. New weapons = a config entry. New asteroid fields/zones = config entries. New systems plug into the same `init()` pattern.

## Post-MVP roadmap (in priority order)

1. **Home-world bases** — personal planet per player: storage, hangar, refinery, research lab, defense turrets (new `BaseSystem` server module + a planet generator in `WorldGen`).
2. **Advanced weapons live** — Plasma Cannon, Railgun, Burst Laser, Missile Launcher are already defined in config and wired into combat; add a weapon shop/loadout UI to let players switch.
3. **Missions** — fetch/escort/bounty contracts issued at the station for credit income variety.
4. **Guilds/factions** — shared banks, territory control over the deep fields.
5. **Mobile/gamepad input** — flight is keyboard+mouse only right now.
6. **Polish** — space skybox asset, sounds, better asteroid meshes, engine particle tuning.

## Monetization plan (no pay-to-win)

Cosmetics only, sold for Robux via standard `MarketplaceService` developer products / game passes:
- Ship skins (recolor the `SPECS` palettes in `ShipBuilder`)
- Engine trail colors/styles
- Cosmetic weapon beam colors
- Hangar/base decorations (post-base-update)

Convenience (e.g., +1 ship loadout slot) is acceptable; never sell damage, shields, or mining rate.
