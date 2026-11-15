# Ember Drift — Salvage Run

[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![rank](https://make.fun/badge/roblox-game-01/Riaking89/roblox-game-ria/rank.svg)](https://make.fun/bounty/roblox-game-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![reward](https://make.fun/badge/roblox-game-01/Riaking89/roblox-game-ria/reward.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)

My entry for the [roblox-game-01](https://make.fun/bounty/roblox-game-01) bounty on [make.fun](https://make.fun/bounty/roblox-game-01): **Ember Drift — Salvage Run**, a 2D arcade salvage game built from scratch in Luau — original code, art and names throughout.

## The game

Pilot a salvage skiff through a dusk-space drift field. Grab the golden ember orbs for points, chain them without a hit to raise your combo up to x5, and dodge the asteroids — three hits end the run. Clear 12 embers to reach the next sector; clear all three sectors (Drift Field, Meteor Belt, Ember Storm) to win the run, then keep flying in endless mode and chase a bigger score.

- **A complete game:** start screen with instructions, HUD (score, combo, lives, sector progress), sector banners, victory and game-over screens, Play Again and endless mode.
- **Real client/server split:** the client renders and reports what it sees; the server owns the score, lives, sector and streak, rate-limits reports and only pays fixed values, so a tampered client cannot mint points.
- **Depth:** three sectors with rising spawn rates and fall speeds, rare gold cores worth 25, a combo multiplier, invulnerability window and screen shake after a hit.
- **Feel:** pickup sparkles, floating score text, damage flash, screen shake, sector banners, blinking invulnerability.

## Controls

WASD or arrow keys to fly. Mouse to click PLAY / PLAY AGAIN / KEEP FLYING.

## Layout

- `src/shared/Config.luau` — palette, tuning, sector table (the numbers both sides agree on)
- `src/shared/Util.luau` — clamp, AABB overlap, lerp, score formatting
- `src/server/GameServer.server.luau` — authoritative score/lives/sector, validation, state broadcast
- `src/client/GameClient.client.luau` — interface, input, spawn loop, collisions, feedback
- `default.project.json` — Rojo project; `rojo build` writes `game.rbxl`
- `main.ts` — copies the game to `/output` and writes `dossier.json` with the vendored make.fun library

## Build it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## Publish status

⚠️ **Not yet published.** This entry needs a Roblox account that is at least 2 days old and past Roblox's age check to publish the experience as Public, plus Roblox Studio (Windows/macOS) to run the game and take its screenshots. See `roblox-game-ria-notes/BUILD.md` for the exact remaining steps. `PLAY.json` still holds placeholder zeros until the experience is published.

Rebuilt after the competition opened (19:00 WIB, 15 Nov 2026), so this repo and its build session fall inside the competition window.
