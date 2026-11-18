# Steal a Snack v2 — Assessment

**Date:** 2026-11-18 ~19:45 WIB
**Competition:** make.fun roblox-brainrot-01 ($1,000, top 50), deadline Fri 20 Nov 2026 21:30 WIB
**Repo:** https://github.com/agungvg/steal-a-snack-v2 — remote HEAD `4bf91a14d1b80ac286a7e40e55b8817aa51dd97d` (30 files, tree verified identical)
**Build:** `game.rbxl` **52,141 B**, sha256 `bc0b52f093616a7f967216338fef727b9520851eddc86835717a4ee41ea8cc78`
**Tests:** `tests/run.sh` → **RESULT: passed=279 failed=0** (re-run by the coordinator after integration)
**Rojo:** clean build, zero errors.

## Zero-reuse compliance (Lyso's hard rule)

The Polish 2 build (`~/workspace/makefun/steal-a-snack/`) was **never opened** by any of the three build agents — no file, script, function, model, part, structure or layout was read, copied or adapted. Every line in this project was written fresh in this session. The scaffold agent designed its own module APIs (positional `buildSnack(def, variantName, groundPos, headingRad, parent)` + separate `attachClick` — no options table). A grep for v1 references in the new workdir is clean. The first scaffold attempt (a copy of Polish 2) was discarded and deleted before this build started.

Same CONCEPT only: Steal a Brainrot-style snack game — 9 original snack characters with the same names/rarities/prices, same play code (`makefun-parcel-ranch-highland`), same core loop (buy/sell/steal, lock, rebirth, waves, weather, saves).

## What changed vs Polish 2

### Characters (realistic builder, replaced the placeholder factory)
- **Heads:** oval sculpted balls (never boxes), tilted 0.05 rad, with a jaw/chin step — the side view has real relief.
- **Faces:** eye line at half head height; eyes ~0.25 of face width, one eye-width apart; per-eye stack of white + dark outline + tall-oval iris (per-snack colour) + pupil + glint + upper lid covering the iris top; tapered asymmetric brows (left a touch higher); modelled nose (bridge + tip); blush cheek steps; thin smile / Taco smirk / Dumpling open mouth + tongue.
- **Limbs/hands:** tapered two-segment arms with an elbow bend and a left-shoulder drop; hands are palm + 3 fingers + thumb (no mitten blobs); legs + dark leather shoes.
- **Per-character sculpted props:** Fry sticks + ketchup drips + cardboard box; Ned noodle-nest cap + chilli + steam; Dumpling pleats + gold earrings + pink tutu (arms raised, dance pose); Taco shell dome + sauce drips + lime + sour cream; Lasagna pleated chef hat + olive + cheese drips; Queso gold crown + red cape + gold necklace + ruby earrings; Kebab flatbread wrap + grill marks + smoke + metal skewer; Burger bun dome + sesame + pickle + onion + mustard drip; Ramen nori + chashu + crossed chopsticks + steam + chilli-oil swirl.
- **Materials:** Fabric for bread/dough/cloth, Metal for crowns/gold, SmoothPlastic only for glossy food, Leather shoes, Neon only on the disc + chest gem. 3-step colour ramps (hi/mid/lo). Rarity colour ONLY on the disc + chest gem, never the body.
- **Part counts:** 50–53 per snack (budget ≤ 60). Part budget is higher than Polish 2's placeholder (10) because the detail is real geometry, not flat parts.

### Environment (realistic rebuild, same layout)
- **Bases:** same 8 platforms at the same centres, same 3×2 slot grid — but now jittered WoodPlanks floors (±5% value), Cobblestone plinths, Plaster back walls (cap 235, never pure white), Fabric banners/flags in the base accent, market stalls behind the back wall (lighter wood counters, red/white striped Fabric awnings, framed Glass windows + tinted jars, goods), warm 2700 K stall lamps, concrete kerb rings, cobblestone paths to the belt, gold neon chevrons, geometry wear strips (floor-line dirt, scuffs, streaks — no decals, the project has no licensed grime asset).
- **Plaza:** 8 layered trees (trunk + 3 canopy volumes, varied greens), flower beds, bushes, granite fountain (north gap), pebble-rim pond with lily pads (south gap). ~656 parts total.
- **Lighting:** brighter + warmer + HD-clear — Brightness 2.6 (was 2.0), ClockTime 13.5, warm Ambient, real cool-sky OutdoorAmbient, FogColor set (was default black), FogEnd 1200, Bloom threshold 0.95 (only true emitters glow), ColorCorrection saturation 0.05 + warm tint, SunRays 0.12. Technology stays Future.
- **Weather:** all 5 weathers retuned with the same property names (Sunny 2.6/13.5, Rain 1.6/12.5, Storm 1.1/17.5 blue hour, Fog 1.35/10.5, Snow 2.0/12). Sunny stays the default.
- **Light budget:** 8 stall lamps + 1 fountain light, all `Shadows = false` — 0 shadowed local lights; the sun is the only shadow caster.

### Systems (fresh scaffold, all new code)
- 14 server modules (State, Economy, Bases, CharacterFactory, Spawner, Steal, Rebirth, Wave, Weather, Leaderboard, Effects, RateLimit, Saves, init) + client HUD (cash/income/owned/weather/wave banner/lock + rebirth buttons/leaderboard, all from server payloads) + headless test harness (mock + assembler + run_tests).
- Buys/sells/steals run through server-side ClickDetectors with full server re-validation (cash, slots, lock, cooldown, distance). Owned snacks carry `OwnerId`/`Slot` attributes, so one click handler works even after a steal moves the snack.
- Remotes: GameSync (1s), WaveAlert, LockBase, RequestRebirth. Saves are versioned (DataStore `StealASnackV2`, v1), all calls pcall-wrapped.

## Integration notes (coordinator)
- `Bases.build()` is wired once at boot in `init.server.luau` (parents its folder to Workspace). The old Base1–8 SmoothPlastic slabs were removed from `default.project.json` to avoid double geometry.
- The 9 weather assertions in `tests/run_tests.luau` were updated to the new retuned values (Sunny 2.6, Storm 1.1/260/17.5, Fog 160, Rain 500, Snow 12) — the values are the design, so the tests now assert the design. No other test was changed.
- The CharacterFactory's `addPart` sets `Position` explicitly as well as `CFrame` (the headless mock's CFrame doesn't drive Position), and materials go through a `mat()` fallback (the mock's `Enum.Material` only ships a subset). Both are mock-only adaptations; in real Roblox the values resolve normally.

## Preview (for screenshots)
- `preview/preview-characters.html` + `preview/three.min.js` (Three.js r128, MIT) — written fresh for v2, mirrors the v2 CharacterFactory's parametric system (same offsets/colours/props) + the v2 environment layout.
- Views (same page, `?view=` param):
  - `?view=group` (default) — all 9 characters on the belt, warm sunny light.
  - `?view=closeup` — Baron Burger face close-up (head + shoulders).
  - `?view=hero` — wide market shot (belt + bases + trees + stalls + pond).
  - `?view=burger` — Baron Burger medium shot.
- The page is syntax-checked (node --check) and smoke-tested headlessly in Node with a THREE stub (all 4 views run clean, no runtime errors; group builds 595 meshes + 9 labels, closeup 191 meshes + 1 label). `preserveDrawingBuffer: true` is set so the browser's save-to-PDF captures the WebGL canvas.
- **NOT visually verified:** there is no Chromium on this VM, so no screenshot was taken. The parent must screenshot the page (GitHub Pages or the raw file) and judge the look before Lyso publishes.

## Caveats / not done
- **No Studio playtest.** The loop is verified headless (279 checks) + Rojo builds clean, but a real 2-player Studio pass (buy → earn → steal → lock → rebirth → save) is still needed before submission.
- **No submission.** Lyso publishes in Studio himself (Polish 2 stays the publish-tonight safety net; v2 replaces it only if clearly better). After he publishes and sends place_id + universe_id, the parent does Recording 3 + PLAY.json + submit before 20 Nov 21:30 WIB.
- **No Roblox-side visual check.** The preview is a Three.js reconstruction, not the game itself. The real in-game look (lighting, materials, scale at belt distance) can only be judged in Studio.
