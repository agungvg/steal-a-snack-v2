# Steal a Snack v2

A Steal-a-Brainrot-style snack game for Roblox, built from scratch with
Rojo + Luau. Snack characters walk along a central conveyor belt. Click a
walker to **buy** it, and it stands on your base earning cash every second.
Click a snack on another player's base to **steal** it — unless their base
is locked. Lock your base, rebirth for a permanent income multiplier, and
watch out for periodic snack waves and rotating weather.

## The loop

1. **Spawn** — snack walkers roll onto the belt every 7s (max 10), with
   rarity tiers (Common → Mythic) and mutations (Golden x2, Diamond x5,
   Rainbow x10).
2. **Buy** — click a walker. Costs its price, needs a free base slot (6).
3. **Earn** — owned snacks pay their rate every second, boosted by
   rebirths (x1.25 each) and doubled during waves.
4. **Steal / sell** — click a snack on someone else's base to steal it
   (5s cooldown, locked bases are safe, 40-stud reach). Click your own
   snack to sell it for half price.
5. **Progress** — lock your base (20s lock, 60s cooldown), rebirth
   ($25,000 × (rebirths + 1)) for a permanent multiplier, climb the
   richest-players leaderboard. Cash + rebirths + snacks save to DataStore.

## Layout

- `default.project.json` — Rojo DataModel project: Lighting (Future,
  Sky + Atmosphere + ColorCorrection + Bloom + SunRays), a 220×140 ground,
  a 128-stud belt (X −64…64, top Y=2), 8 coloured base platforms around
  it (4 north, 4 south), a spawn area, and 4 trees.
- `src/shared/Config.luau` — all game data + deterministic roll helpers.
- `src/server/` — one small module per system: `State`, `Economy`,
  `Bases`, `CharacterFactory` (placeholder builder), `Spawner`, `Steal`,
  `Rebirth`, `Wave`, `Weather`, `Leaderboard`, `Effects`, `RateLimit`,
  `Saves`, plus `init.server.luau` wiring it all together.
- `src/client/Hud.client.luau` — HUD built from code: cash, income,
  owned snacks, weather, wave banner, lock + rebirth buttons, leaderboard.
- `tests/` — headless test harness (mock Roblox API + checks).

## Build

```sh
# from this directory
bun main.ts            # build + test in one go
# or by hand:
~/workspace/tools/rojo/rojo build default.project.json -o game.rbxl
```

## Test

```sh
tests/run.sh           # headless Luau tests, no Studio needed
```

The harness assembles the mock API + the real `Config`,
`CharacterFactory` and `Weather` sources into one chunk and runs 279
checks: all 9 snacks (data, build, ground, facing, part budget), rarity
+ mutation roll boundaries, rebirth math, and weather lighting values.

## Remotes (ReplicatedStorage)

| Remote | Direction | Payload |
|---|---|---|
| `GameSync` | server → client | `{cash, owned, rate, rebirths, rebirthCost, weather, waveActive, waveIn, lockLeft, top}` every 1s |
| `WaveAlert` | server → client | `{kind="warn"\|"start"\|"end"\|"note", seconds?, text?}` |
| `LockBase` | client → server | no args (rate-limited) |
| `RequestRebirth` | client → server | no args (rate-limited) |

Buys, sells and steals use server-side ClickDetectors — no remote needed,
and the server re-validates everything (cash, slots, lock, cooldown,
distance).

## Notes

- `CharacterFactory` is a deliberately simple placeholder builder (ball
  body + face + limbs + rarity disc + label). Its API is frozen in
  `API.md`; a later pass replaces the internals with a realistic builder.
- Saves are versioned (`version = 1`) and every DataStore call is
  pcall-wrapped; a failed load starts a fresh session instead of wiping
  progress.
