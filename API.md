# Steal a Snack v2 — API

Module APIs for this build, written from scratch for v2. The next agent
replacing `CharacterFactory` or `Bases` must keep these signatures and
guarantees — every other system calls exactly what is documented here.

All server modules live in `src/server/` (ModuleScripts under
`ServerScriptService.Server`) and are required as
`require(script.Parent:WaitForChild("<Module>"))`. Shared data lives in
`src/shared/Config.luau` (`ReplicatedStorage.Shared.Config`).

---

## CharacterFactory (`src/server/CharacterFactory.luau`)

PLACEHOLDER builder — simple procedural snacks. A later pass replaces the
internals with a realistic builder; the signatures below are the contract.

### `buildSnack(def, variantName, groundPos, headingRad, parent) -> Model`

Builds one snack standing on the ground.

| Argument | Type | Meaning |
|---|---|---|
| `def` | `SnackDef` table | A `Config.SNACKS` entry: `{key, displayName, rarity, rate, price, color={r,g,b}, size}` |
| `variantName` | `string` | `"None"` \| `"Golden"` \| `"Diamond"` \| `"Rainbow"` — tints the body (Golden lightens, Diamond pale-blue + 0.25 transparency, Rainbow magenta) |
| `groundPos` | `Vector3` | Ground point under the snack's feet (its Y is the floor) |
| `headingRad` | `number` | Facing in radians: `0` = +Z, `math.pi/2` = +X. The face (eyes + mouth) sits on the +forward side |
| `parent` | `Instance` | Where the Model is parented |

Returns the `Model`. No click is wired here — see `attachClick`.

Guarantees:

- `Model.PrimaryPart` is an invisible (`Transparency = 1`), anchored
  `Root` part — a flat plate whose bottom sits exactly on `groundPos`.
- Every part is `Anchored = true`, `CanCollide = false`.
- No part dips below `groundPos.Y` (feet, disc and limbs all rest on it).
- A rarity-coloured flat `Disc` (Neon, 0.35 transparency) sits under the
  feet. Rarity tints: Common grey, Rare blue, Epic purple, Legendary
  orange, Mythic pink.
- A `BillboardGui` named `Caption` floats above with two `TextLabel`
  children: `NameLine` (display name) and `InfoLine`
  (`"$<price>  •  $<rate>/s"`).
- Attributes on the Model: `SnackKey` (string), `Variant` (string),
  `Rarity` (string).
- Part budget: 10 `BasePart`s per snack (Root, Body, EyeL, EyeR, Mouth,
  ArmL, ArmR, LegL, LegR, Disc) — well under the 60-part cap.

### `attachClick(model, reach, handler) -> ClickDetector`

Adds a `ClickDetector` to the model's `PrimaryPart` with
`MaxActivationDistance = reach`. `handler` is called as `handler(player)`
when a player clicks. Returns the detector. Asserts if the model has no
`PrimaryPart`.

### `setCaption(model, line1, line2) -> ()`

Rewrites the floating label: `NameLine.Text = line1`,
`InfoLine.Text = line2`. Silently does nothing if the `Caption` GUI is
missing.

### `countParts(model) -> number`

Counts `BasePart` descendants of the model (budget check).

---

## Bases (`src/server/Bases.luau`)

Owns base claiming, slot geometry and snack placement. Cash lives in
`State`; this module owns *where* snacks stand.

Slot grid: 3 columns × 2 rows on each platform, offsets
`(-6|0|6, 0, -3.5|+3.5)` from the platform centre. Slot numbers 1–6 run
back row left→right, then front row left→right.

### `claim(player) -> number`

Assigns the first free base (1–8) to `player`. Returns the index, or the
player's existing index if already claimed, or `0` when all 8 are taken.

### `drop(player) -> ()`

Empties the player's base (destroys its snack models) and releases the
base for reuse.

### `indexOf(player) -> number`

The player's base index, or `0` when they have none.

### `platformCenter(index) -> Vector3`

World centre of base `index` (top of the platform, y = 1). Comes from
`Config.BASE_CENTERS`.

### `slotWorldPos(index, slot) -> Vector3`

Ground point of slot `slot` (1–6) on base `index`.

### `firstEmpty(index) -> number?`

First free slot on the base, or `nil` when full (or the base is unknown).

### `place(index, slot, record) -> ()`

Records a snack on a slot. `record` is a `SlotRecord`:

```lua
{ snackKey: string, variant: string, rate: number, mult: number, model: Model }
```

The `model` inside the record is the snack's Model (used by `clearAll`
and by `Steal` to move it). `place` does not move or re-parent the model.

### `remove(index, slot) -> SlotRecord?`

Takes the snack off a slot and returns its record (or `nil` if empty).
Does **not** destroy the model — the caller owns it from here.

### `peek(index, slot) -> SlotRecord?`

Reads one slot without removing it.

### `list(index) -> {SlotRecord}`

Every snack record currently on the base (order unspecified).

### `count(index) -> number`

Snacks currently on the base.

### `clearAll(index) -> ()`

Destroys every snack model on the base and empties all its slots.

---

## Config (`src/shared/Config.luau`) — helpers

Pure data + deterministic rolls (no Roblox services; headless-testable).

- `lookupSnack(key) -> SnackDef?`
- `snacksOfRarity(rarity) -> {SnackDef}`
- `rarityColor(rarity) -> {r,g,b}`
- `variantFor(name) -> VariantDef` (unknown name → `"None"`)
- `pickRarity(roll) -> string` — `roll` in [0, 1); weights Common 46 /
  Rare 28 / Epic 15 / Legendary 8 / Mythic 3.
- `pickVariant(roll) -> VariantDef` — Rainbow 1% (x10), Diamond 5% (x5),
  Golden 15% (x2), else None (x1).
- `pickSnackOfRarity(rarity, roll) -> SnackDef`
- `rebirthPrice(rebirths) -> number` — `25000 * (rebirths + 1)`
- `incomeBoost(rebirths) -> number` — `1 + 0.25 * rebirths`
- Constants: `START_CASH` 100, `CASH_TICK` 1, `MAX_SLOTS_PER_BASE` 6,
  `MAX_BASES` 8, `LOCK_DURATION` 20, `LOCK_COOLDOWN` 60,
  `STEAL_COOLDOWN` 5, `WAVE_PERIOD` 90, `WAVE_WARN` 10,
  `WAVE_DURATION` 10, `WEATHER_MIN` 150, `WEATHER_MAX` 180,
  `WEATHER_FADE` 4, `CONVEYOR_SPEED` 6, belt X −64…64 at Z=0, top Y=2,
  `SPAWN_INTERVAL` 7, `MAX_WALKERS` 10, `ACTION_RANGE` 40,
  `SELL_REFUND` 0.5, `WAVE_INCOME_MULT` 2. `BASE_CENTERS`: 8 `Vector3`s
  (X −54/−18/18/54 × Z −22/22, y = 1).

## State (`src/server/State.luau`)

- `open(player) -> Session` — fresh session (`cash = START_CASH`,
  `rebirths = 0`, `lockUntil = 0`, `lockReadyAt = 0`, `lastStealAt = 0`,
  `baseIndex = 0`).
- `fetch(player) -> Session?`, `close(player)`, `all() -> {[Player]: Session}`
- `isLocked(session) -> boolean`, `lockSecondsLeft(session) -> number`
  (both read `os.time()` against `lockUntil`).

## Economy (`src/server/Economy.luau`)

Pure cash math over a `State.Session` and a list of
`{rate: number, mult: number}` owned snacks.

- `ratePerSecond(snacks, rebirths) -> number` — sum(rate × mult) ×
  `incomeBoost(rebirths)`.
- `tick(session, snacks, dt, waveActive) -> number` — adds income for
  `dt` seconds (×2 while a wave is active); returns cash earned.
- `canAfford(session, price) -> boolean`
- `charge(session, price) -> boolean` — deducts only when affordable.
- `grant(session, amount) -> ()`

## Spawner (`src/server/Spawner.luau`)

- `begin(walkersParent, onBuy) -> ()` — starts the spawn loop (every
  `SPAWN_INTERVAL`, halved while boosted) and the 0.1s movement loop.
  `onBuy(player, walker)` runs on walker click. Walkers spawn at
  `BELT_MIN_X`, walk +X at `CONVEYOR_SPEED`, despawn past `BELT_MAX_X`.
- `setBoost(on: boolean) -> ()` — wave mode.
- `count() -> number`, `removeWalker(walker) -> ()`
- `Walker = {model, snackKey, variant, def, mult, x}`

## Steal (`src/server/Steal.luau`)

- `attempt(thief, victim, slot, thiefPos) -> (boolean, string)` —
  validates (different players, victim not locked, thief off cooldown,
  within `ACTION_RANGE` of the victim's base, slot occupied, thief has a
  free slot), then moves the record + model to the thief's base, retags
  the model (`OwnerId`, `Slot` attributes) and restarts the thief's
  cooldown. On failure the snack stays put. Returns ok + a human message.

## Rebirth (`src/server/Rebirth.luau`)

- `attempt(player) -> (boolean, string)` — charges
  `rebirthPrice(rebirths)`, empties the player's base, resets cash to
  `START_CASH`, `rebirths += 1`.

## Wave (`src/server/Wave.luau`)

- `begin(onWarn, onStart, onEnd) -> ()` — loop: warn `WAVE_WARN` before
  each wave, run it for `WAVE_DURATION`, repeat every `WAVE_PERIOD`.
- `isActive() -> boolean`, `secondsToNext() -> number` (0 during a wave).

## Weather (`src/server/Weather.luau`)

- `settingsFor(name) -> WeatherSettings` — pure table
  (`brightness, clockTime, ambient, outdoorAmbient, fogEnd,
  atmosphereDensity, atmosphereOffset`); unknown name → Sunny.
- `applyTo(lighting, name) -> ()` — pushes one weather onto a `Lighting`
  instance (and its `Atmosphere` child when present).
- `current() -> string`
- `begin(lighting, onChange, minStretch?, maxStretch?, fadeSeconds?) -> ()`
  — rotates Sunny → Rain → Storm → Fog → Snow with a fade; defaults
  150s / 180s / 4s (init passes the `Config` values).

## Leaderboard (`src/server/Leaderboard.luau`)

- `ranked(rows) -> {Row}` — copy of `rows` sorted richest-first.
  `Row = {name, cash, rebirths}`.
- `top(rows, n) -> {Row}` — first `n` of the ranked list.

## Effects (`src/server/Effects.luau`)

- `pop(parent, pos, rgb) -> ()` — one-shot neon flash + particle burst,
  cleaned up by `Debris` after 1.2s.

## RateLimit (`src/server/RateLimit.luau`)

- `new(maxCalls, windowSeconds) -> Limiter`
- `limiter:allow(key: string) -> boolean` — per-key sliding window.

## Saves (`src/server/Saves.luau`)

Versioned DataStore (`StealASnackV2`, `version = 1`), all calls
pcall-wrapped.

- `pack(cash, rebirths, snackRows) -> table`
- `unpack(data) -> {cash, rebirths}?` — `nil` on bad version/shape.
- `load(player) -> table?`, `save(player, data) -> boolean`
- `SnackRow = {snackKey, variant, slot}`

## Remotes (ReplicatedStorage)

| Remote | Direction | Payload |
|---|---|---|
| `GameSync` | server → client | `{cash, owned, rate, rebirths, rebirthCost, weather, waveActive, waveIn, lockLeft, top={{name, cash}}}` every 1s |
| `WaveAlert` | server → client | `{kind="warn"\|"start"\|"end"\|"note", seconds?, text?}` |
| `LockBase` | client → server | no args, rate-limited (2 per 5s) |
| `RequestRebirth` | client → server | no args, rate-limited (2 per 5s) |

Buys, sells and steals use server-side `ClickDetector`s (see
`CharacterFactory.attachClick`); the server re-validates cash, slots,
locks, cooldowns and distance on every click. Owned snacks carry
`OwnerId` / `Slot` attributes on their Model so one click handler works
even after a steal moves the snack to a new base.
