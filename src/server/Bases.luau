--!strict
-- Steal a Snack v2 — Bases: base claiming, slot geometry, snack placement,
-- AND the realistic base environment (fresh build for the v2 environment pass).
--
-- *** API CONTRACT — UNCHANGED ***
-- The 11 placement functions below are byte-for-byte the v2 behaviour from
-- API.md / src/server/Bases.luau. Nothing about claiming, slots or records
-- changed: same slot grid (3 cols x 2 rows, offsets (-6|0|6, 0, -3.5|+3.5)),
-- same 8 bases at Config.BASE_CENTERS, same SlotRecord shape.
--   claim(player) -> number            base index 1..8, or 0 when full
--   drop(player) -> ()                 release the player's base
--   indexOf(player) -> number          0 when the player has no base
--   platformCenter(i) -> Vector3       world centre of base i (top y = 1)
--   slotWorldPos(i, slot) -> Vector3   ground point of a slot on base i
--   firstEmpty(i) -> number?           first free slot, nil when full
--   place(i, slot, record) -> ()       record a snack on a slot
--   remove(i, slot) -> SlotRecord?     take a snack off a slot (no destroy)
--   peek(i, slot) -> SlotRecord?       read one slot without removing it
--   list(i) -> {SlotRecord}            every snack on base i
--   clearAll(i) -> ()                  empty a base (destroys the models)
--   count(i) -> number                 snacks currently on base i
--
-- *** NEW, ADDITIVE ONLY ***
--   buildBase(index, parent) -> Model  build ONE base's realistic dressing
--   build(parent) -> Folder            build all 8 bases + plaza dressing
-- `build` is never called by the existing server init; the parent wires it
-- in (once, at boot). It is idempotent: re-running it destroys the previous
-- "BasesEnv" folder first. No game logic lives here — only geometry.
--
-- ENVIRONMENT DESIGN (roblox-realism skill; Genshin town-square reference):
-- Value + roughness first, colour second, texture third. Every surface uses
-- a library material — no default grey, no SmoothPlastic-everywhere.
--   Base floor   WoodPlanks, warm 120-160, ±3-6% value jitter per board
--   Foundation   Cobblestone plinth (stone base the planks sit on)
--   Back wall    Plaster, warm neutral 170-210, never pure white (cap 235)
--   Pilasters    Cobblestone; trim / plate carry the base's own colour
--   Flags/banner Fabric in the base colour + cream
--   Stall        Wood counter (top one tone lighter than the frame),
--                Fabric red/white striped awning, framed Glass window +
--                Glass jars, Cardboard boxes, Foil snack bundles
--   Lamp         warm 2700 K Neon bulb (255,167,87) + PointLight, range 14
--   Wear         geometry strips (dirt at floor line, scuffs on the front
--                edge, streaks under the stall window) — geometry, not
--                decals, because this project has no licensed grime texture
--                asset; a fake rbxassetid would render as a broken image.
--   Kerbs/seams  Concrete kerb ring where grass meets stone; Cobblestone
--                path panels (jittered stone tones) from each base to the
--                belt; gold Neon wedge chevrons point toward the belt.
--   Greenery     layered trees (trunk + 3 canopy volumes, varied greens),
--                bushes, flower beds with pink/yellow/purple accents.
--   Water        granite fountain (north gap) + pebble-rim pond (south gap).
-- Layout is UNTOUCHED: bases stay at Config.BASE_CENTERS, platform
-- footprint stays 20 x 14 with its top at y = 1, the belt is not moved.
-- The stall sits just BEHIND each base's back wall (outside the platform)
-- so it can never clip a snack standing on a slot (snacks are up to 6
-- studs wide). Slots, clicks and steal reach are unaffected.
--
-- BACKGROUND + LIGHTS (Lyso order 2026-11-18: background must be nice WITH
-- LIGHTS, bases must be COOL, not standard):
--   Plaza lamps  6 tall lamp posts framing the belt (3 per side) with a
--                warm Neon bulb + PointLight each (range 18, shadowless).
--   String lights 4 catenary spans between the lamp posts, warm/gold +
--                pink/cyan Neon bulbs with a thin wire, sagging mid-span.
--   Neon identity every base glows in its accent colour: a Neon crown
--                strip on the back wall, Neon caps on the pilasters, a
--                Neon front-edge strip, and a glowing entrance arch
--                (posts + Neon top bar + orbs) framing the front.
--   Floor runner an accent-colour carpet with gold Neon edges down the
--                middle of each platform (flat, 0.06 proud — slots sit
--                on it, geometry unchanged).
--   Ground life  flower beds along the belt, boulder clusters on the
--                outer grass, cobble paths belt -> fountain and belt ->
--                pond, and 4 more layered trees at the far corners
--                (the plain ball-on-stick trees were removed from
--                default.project.json).
-- Light budget: 6 plaza + 8 stall + 1 fountain + 1 tower beacon = 16
-- PointLights total, all shadowless. Neon/string bulbs are emissive
-- only (no light cost).
--
-- BELT — UNMISSABLE (Lyso live-test 2026-11-18: he could not find the
-- belt in a top-down view). The belt itself is a dark strip in
-- default.project.json, so the dressing makes it shout: a cream centre
-- lane down the middle (walkers pop against it), gold Neon strips on
-- both side faces, a big "SNACK BELT" sign gate at each end, gold Neon
-- chevrons on the grass pointing at it from both sides, and cobble
-- promenade strips flanking it. The lane top (2.06) sits 0.06 into the
-- walkers' discs — invisible, and BELT_TOP_Y / walker motion unchanged.
--
-- BASE SHAPE + ROOF (Lyso live-test 2026-11-18: "bentuknya masih aneh"
-- and "ga ada atapnya ini basenya"). Trim is decoration, not shape, so
-- the shape itself changed: a stepped gable peak on the back wall, two
-- splayed wing walls framing the entrance (outside the platform, so no
-- slot ever clips them), and a ROOF — an open pergola over the back
-- third (Wood side beams + 3 accent slats with gaps, front beam + Neon
-- edge, front posts) PLUS a sloped canopy over the market stall behind
-- the wall. The pergola's slats are spaced so the back-row slots sit in
-- the GAPS (back row z = -3.5 rel. centre falls between slats at -4.1
-- and -2.5), the front two-thirds of the platform stay fully open, and
-- from the belt side the camera looks UNDER the roof — snacks on the
-- slots stay visible from every angle. Footprint, slot positions/counts,
-- lock behaviour and map positions are unchanged.
--
-- CARNIVAL (Lyso order 2026-11-18: a tower + a ferris wheel, full of
-- colourful lights). Both stand in the BACKGROUND, outside the play
-- area, as landmarks: the ferris wheel at (-92, 15) west (ring + spokes
-- + 8 cabins + A-frame legs, rainbow Neon, facing the plaza) and the
-- tower at (95, -25) east (3 tiers, Neon trim rings, glowing beacon +
-- 1 PointLight, flag on top). They never touch the belt, bases, spawns
-- or the camera's view of the snacks. The wheel is STATIC (no rotation
-- script — a runtime script would need init wiring and could break the
-- headless test harness; Neon carries the carnival read).
--
-- DARK GREEN CUBE (Lyso live-test 2026-11-18: "apa itu bentuk mentah").
-- No source builds a dark-green Block: every foliage volume in this
-- file is a Ball, and the only flat green volumes in the whole place are
-- the Ground slab and the SpawnLocation pad (default.project.json). What
-- read as a raw block was the bare central grass between the base rows.
-- That whole band is now dressed (promenade + chevrons + belt bushes +
-- flower beds) so no raw green flat remains near the belt.
--
-- SlotRecord = { snackKey: string, variant: string, rate: number,
--                mult: number, model: Model }

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Bases = {}

export type SlotRecord = {
	snackKey: string,
	variant: string,
	rate: number,
	mult: number,
	model: Model,
}

local claims: { [Player]: number } = {}
local taken: { [number]: boolean } = {}
local slots: { [number]: { [number]: SlotRecord } } = {}

-- Slot grid offsets relative to the platform centre (3 cols x 2 rows).
local SLOT_OFFSETS = {
	Vector3.new(-6, 0, -3.5),
	Vector3.new(0, 0, -3.5),
	Vector3.new(6, 0, -3.5),
	Vector3.new(-6, 0, 3.5),
	Vector3.new(0, 0, 3.5),
	Vector3.new(6, 0, 3.5),
}

function Bases.claim(player: Player): number
	local existing = claims[player]
	if existing then
		return existing
	end
	for i = 1, Config.MAX_BASES do
		if not taken[i] then
			taken[i] = true
			claims[player] = i
			slots[i] = {}
			return i
		end
	end
	return 0
end

function Bases.drop(player: Player): ()
	local index = claims[player]
	if index then
		Bases.clearAll(index)
		taken[index] = nil
		slots[index] = nil
		claims[player] = nil
	end
end

function Bases.indexOf(player: Player): number
	return claims[player] or 0
end

function Bases.platformCenter(index: number): Vector3
	return Config.BASE_CENTERS[index]
end

function Bases.slotWorldPos(index: number, slot: number): Vector3
	return Config.BASE_CENTERS[index] + SLOT_OFFSETS[slot]
end

function Bases.firstEmpty(index: number): number?
	local held = slots[index]
	if not held then
		return nil
	end
	for slot = 1, Config.MAX_SLOTS_PER_BASE do
		if held[slot] == nil then
			return slot
		end
	end
	return nil
end

function Bases.place(index: number, slot: number, record: SlotRecord): ()
	slots[index][slot] = record
end

function Bases.remove(index: number, slot: number): SlotRecord?
	local held = slots[index]
	if not held then
		return nil
	end
	local record = held[slot]
	held[slot] = nil
	return record
end

-- Read one slot without removing it (used by saves + the HUD sync).
function Bases.peek(index: number, slot: number): SlotRecord?
	local held = slots[index]
	if not held then
		return nil
	end
	return held[slot]
end

function Bases.list(index: number): { SlotRecord }
	local out = {}
	local held = slots[index]
	if held then
		for _, record in pairs(held) do
			table.insert(out, record)
		end
	end
	return out
end

function Bases.count(index: number): number
	return #Bases.list(index)
end

function Bases.clearAll(index: number): ()
	local held = slots[index]
	if held then
		for _, record in pairs(held) do
			if record.model then
				record.model:Destroy()
			end
		end
		slots[index] = {}
	end
end

-- ======================================================================
-- ENVIRONMENT BUILD (additive; no placement logic above is touched)
-- ======================================================================

-- Base accent colours — carried over from the v2 place file's eight base
-- colours (0-1 floats converted to 0-255). The accent lives ONLY on trim,
-- number plate text, flags and banner — never on the whole floor.
local BASE_ACCENTS = {
	{ 217, 89, 89 }, -- 1 red
	{ 89, 153, 217 }, -- 2 blue
	{ 89, 204, 115 }, -- 3 green
	{ 217, 179, 77 }, -- 4 gold
	{ 179, 115, 217 }, -- 5 purple
	{ 217, 140, 77 }, -- 6 orange
	{ 77, 191, 191 }, -- 7 teal
	{ 230, 115, 153 }, -- 8 pink
} :: { { number } }

local WOOD_FLOOR = { 150, 118, 82 } -- warm WoodPlanks base tone
local PLASTER_WALL = { 198, 190, 172 } -- warm neutral, cap 235
local CREAM = { 232, 224, 205 } -- number plates, awning white stripes
local AWNING_RED = { 200, 60, 55 }
local STONE = { 140, 135, 128 } -- Cobblestone plinth / pilasters
local KERB = { 150, 148, 140 } -- Concrete kerb ring
local COBBLE = { 138, 132, 120 } -- path panels
local LAMP_WARM = { 255, 167, 87 } -- 2700 K stall lamp
local GOLD = { 255, 180, 40 } -- belt direction chevrons (Neon)
local DARK_TEXT = { 60, 55, 45 } -- plate text, lifted well above black
local FLOWER_COLORS = {
	{ 235, 120, 170 }, -- pink
	{ 240, 200, 60 }, -- yellow
	{ 170, 120, 220 }, -- purple
	{ 235, 228, 215 }, -- white (capped)
	{ 220, 80, 70 }, -- red
} :: { { number } }
local CANOPY_GREENS = {
	{ 96, 145, 72 },
	{ 72, 126, 58 },
	{ 112, 158, 86 },
	{ 84, 138, 66 },
} :: { { number } }

-- Deterministic ±pct value jitter from (seedA, seedB): same build every
-- run, neighbouring panels never identical. No math.random in the build.
local function jitter(seedA: number, seedB: number, pct: number): number
	local h = math.sin(seedA * 12.9898 + seedB * 78.233) * 43758.5453
	local frac = h - math.floor(h)
	return 1 - pct + frac * (2 * pct)
end

local function jitteredRGB(base: { number }, seedA: number, seedB: number, pct: number): Color3
	local f = jitter(seedA, seedB, pct)
	local r = math.clamp(math.floor(base[1] * f + 0.5), 30, 235)
	local g = math.clamp(math.floor(base[2] * f + 0.5), 30, 235)
	local b = math.clamp(math.floor(base[3] * f + 0.5), 30, 235)
	return Color3.fromRGB(r, g, b)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(
		math.clamp(c[1], 30, 235),
		math.clamp(c[2], 30, 235),
		math.clamp(c[3], 30, 235)
	)
end

local function part(
	parent: Instance,
	name: string,
	material: Enum.Material,
	color: Color3,
	size: Vector3,
	pos: Vector3,
	shape: Enum.PartType?,
	transparency: number?,
	castShadow: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Material = material
	p.Color = color
	p.Size = size
	p.Position = pos
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	if transparency then
		p.Transparency = transparency
	end
	-- Dressing never casts shadows by default: the sun + the big masses
	-- (floor, walls, canopy) shape the shadows; small parts would only
	-- cost shadow-map work on mobile.
	p.CastShadow = castShadow or false
	p.Parent = parent
	return p
end

-- North bases (z = -22) face the belt toward +Z; south bases toward -Z.
local function towardBelt(index: number): number
	return if Config.BASE_CENTERS[index].Z < 0 then 1 else -1
end

-- The face of the back wall that looks at the belt: +Z side is Back,
-- -Z side is Front (Roblox Front = -Z).
local function wallFace(index: number): Enum.NormalId
	return if towardBelt(index) == 1 then Enum.NormalId.Back else Enum.NormalId.Front
end

-- ------------------------------------------------------------------
-- One base's dressing. Floor top stays exactly y = 1 (platformCenter);
-- footprint stays 20 x 14. `model` is parented by the caller.
-- ------------------------------------------------------------------
local function buildFloor(model: Model, index: number, cx: number, cz: number): ()
	local accent = BASE_ACCENTS[index]
	-- Stone plinth the planks sit on: visible 0.7-stud stone band around
	-- the platform edge (Genshin stone-base read). Top at y = 0.7.
	part(model, "Plinth", Enum.Material.Cobblestone, jitteredRGB(STONE, index, 1, 0.04),
		Vector3.new(20, 0.7, 14), Vector3.new(cx, 0.35, cz), nil, nil, true)
	-- 7 WoodPlanks boards side by side along X; each board jittered
	-- ±5% in value so no two neighbours read as a copy-paste. Board tops
	-- sit exactly at y = 1 (centre 0.85, thickness 0.3).
	local boardW = 20 / 7
	for b = 1, 7 do
		local bx = cx - 10 + boardW * (b - 0.5)
		part(model, "FloorBoard" .. b, Enum.Material.WoodPlanks,
			jitteredRGB(WOOD_FLOOR, index * 7 + b, 3, 0.05),
			Vector3.new(boardW - 0.06, 0.3, 14), Vector3.new(bx, 0.85, cz), nil, nil, true)
	end
	-- Concrete kerb ring where grass meets stone (the seam strip).
	local kerbC = jitteredRGB(KERB, index, 9, 0.03)
	part(model, "KerbFront", Enum.Material.Concrete, kerbC,
		Vector3.new(21, 0.35, 0.9), Vector3.new(cx, 0.175, cz + towardBelt(index) * 7.4))
	part(model, "KerbBack", Enum.Material.Concrete, kerbC,
		Vector3.new(21, 0.35, 0.9), Vector3.new(cx, 0.175, cz - towardBelt(index) * 7.4))
	part(model, "KerbLeft", Enum.Material.Concrete, kerbC,
		Vector3.new(0.9, 0.35, 14), Vector3.new(cx - 10.4, 0.175, cz))
	part(model, "KerbRight", Enum.Material.Concrete, kerbC,
		Vector3.new(0.9, 0.35, 14), Vector3.new(cx + 10.4, 0.175, cz))
	-- Accent runner rug down the middle of the platform: a carpet
	-- leading from the entrance to the back wall, in the base colour.
	-- Flat (0.06 proud) — the middle slot column sits on it, and a
	-- 0.06 sink is invisible, so slot geometry is unchanged.
	part(model, "Runner", Enum.Material.Fabric, rgb(accent),
		Vector3.new(3, 0.06, 13), Vector3.new(cx, 1.03, cz), nil, 0.15)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "RunnerEdge" .. side, Enum.Material.Neon, rgb(GOLD),
			Vector3.new(0.18, 0.06, 13), Vector3.new(cx + side * 1.6, 1.03, cz))
	end
end

local function buildWall(model: Model, index: number, cx: number, cz: number): ()
	local t = towardBelt(index)
	local accent = BASE_ACCENTS[index]
	local wallZ = cz - t * 6.6
	-- Plaster back wall (warm neutral, matte) + Cobblestone pilasters.
	part(model, "BackWall", Enum.Material.Plaster, jitteredRGB(PLASTER_WALL, index, 5, 0.04),
		Vector3.new(20, 5, 0.8), Vector3.new(cx, 3.5, wallZ), nil, nil, true)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Pilaster" .. side, Enum.Material.Cobblestone,
			jitteredRGB(STONE, index, 10 + side, 0.04),
			Vector3.new(1.2, 5.6, 1.2), Vector3.new(cx + side * 9.4, 3.8, wallZ), nil, nil, true)
	end
	-- Number plate: cream Plaster slab on the wall's belt-facing side,
	-- "BASE N" in dark text (SurfaceGui so the text stays crisp).
	local plate = part(model, "NumberPlate", Enum.Material.Plaster, rgb(CREAM),
		Vector3.new(3.4, 1.6, 0.2), Vector3.new(cx, 4.6, wallZ + t * 0.5))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlateGui"
	gui.Face = wallFace(index)
	gui.AlwaysOnTop = false
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Name = "PlateText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BASE " .. tostring(index)
	label.TextColor3 = rgb(DARK_TEXT)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	-- Fabric banner in the base colour with a cream emblem stripe,
	-- hanging on the wall's belt-facing side.
	local banner = part(model, "Banner", Enum.Material.Fabric, rgb(accent),
		Vector3.new(2.2, 3.2, 0.15), Vector3.new(cx + 5.5, 3.1, wallZ + t * 0.55))
	part(model, "BannerStripe", Enum.Material.Fabric, rgb(CREAM),
		Vector3.new(0.5, 3.2, 0.16), Vector3.new(cx + 5.5, 3.1, wallZ + t * 0.55))
	banner.CastShadow = false
	-- Two Fabric flags on Wood poles at the wall-top corners.
	for _, side in ipairs({ -1, 1 }) do
		local px = cx + side * 8
		part(model, "FlagPole" .. side, Enum.Material.Wood, rgb({ 110, 78, 48 }),
			Vector3.new(0.25, 3, 0.25), Vector3.new(px, 7.4, wallZ))
		part(model, "Flag" .. side, Enum.Material.Fabric, rgb(accent),
			Vector3.new(1.7, 1.0, 0.1), Vector3.new(px + side * 0.95, 8.4, wallZ))
	end
	-- Neon crown strip along the top of the back wall, in the base
	-- colour: the wall glows in the base's identity from across the
	-- plaza (emissive only, no light cost).
	part(model, "WallCrown", Enum.Material.Neon, rgb(accent),
		Vector3.new(20, 0.35, 0.9), Vector3.new(cx, 6.15, wallZ))
	-- Glowing Neon caps on the pilasters.
	for _, side in ipairs({ -1, 1 }) do
		part(model, "PilasterCap" .. side, Enum.Material.Neon, rgb(accent),
			Vector3.new(1.5, 0.35, 1.5), Vector3.new(cx + side * 9.4, 6.75, wallZ))
	end
	-- Stepped gable peak on the wall top: 3 stacked accent blocks, each
	-- narrower, so the wall's silhouette is a peaked shop-front, not a
	-- flat rectangle. Sits on the wall top (y 6.0); the middle step is
	-- clear of the pergola's back beam (there is none — the side beams
	-- rest on the pilaster caps) and the slats (first slat z -5.7).
	part(model, "GableStep1", Enum.Material.SmoothPlastic, rgb(accent),
		Vector3.new(8, 0.8, 0.9), Vector3.new(cx, 6.4, wallZ), nil, nil, true)
	part(model, "GableStep2", Enum.Material.SmoothPlastic, rgb(accent),
		Vector3.new(5, 0.8, 0.9), Vector3.new(cx, 7.2, wallZ), nil, nil, true)
	part(model, "GableStep3", Enum.Material.SmoothPlastic, rgb(accent),
		Vector3.new(2.5, 0.8, 0.9), Vector3.new(cx, 8.0, wallZ), nil, nil, true)
	-- Dirt at the floor line: thin dark translucent strip along the wall
	-- base (geometry wear — see header note on decals).
	part(model, "DirtFloorLine", Enum.Material.SmoothPlastic, Color3.fromRGB(60, 50, 40),
		Vector3.new(20, 0.06, 0.7), Vector3.new(cx, 1.03, wallZ + t * 0.6), nil, 0.65)
end

local function buildFront(model: Model, index: number, cx: number, cz: number): ()
	local t = towardBelt(index)
	local accent = BASE_ACCENTS[index]
	-- Front trim in the base's own colour: the colour carrier.
	part(model, "FrontTrim", Enum.Material.SmoothPlastic, rgb(accent),
		Vector3.new(20, 0.5, 0.6), Vector3.new(cx, 1.15, cz + t * 6.8), nil, nil, true)
	-- Neon front-edge strip: the platform's front edge glows in the
	-- base colour, visible from the belt at any distance.
	part(model, "FrontGlow", Enum.Material.Neon, rgb(accent),
		Vector3.new(20, 0.18, 0.25), Vector3.new(cx, 1.32, cz + t * 6.95))
	-- Glowing entrance arch framing the front: two accent posts + a Neon
	-- top bar + glowing orbs. Posts sit at the front corners (x ±8.5),
	-- clear of the slot columns (x -6/0/6); the bar sits above every
	-- snack's face (y 5.7) and reads as a gateway, not a cage.
	for _, side in ipairs({ -1, 1 }) do
		part(model, "ArchPost" .. side, Enum.Material.SmoothPlastic, rgb(accent),
			Vector3.new(0.6, 4.6, 0.6), Vector3.new(cx + side * 8.5, 3.3, cz + t * 6.9), nil, nil, true)
		part(model, "ArchOrb" .. side, Enum.Material.Neon, rgb(accent),
			Vector3.new(0.7, 0.7, 0.7), Vector3.new(cx + side * 8.5, 6.0, cz + t * 6.9),
			Enum.PartType.Ball)
	end
	part(model, "ArchBar", Enum.Material.Neon, rgb(accent),
		Vector3.new(17.6, 0.4, 0.4), Vector3.new(cx, 5.7, cz + t * 6.9))
	-- Gold Neon wedge chevrons on the path pointing toward the belt.
	-- Neon ONLY here (and the lamp bulb): these are the emitting markers.
	for _, ox in ipairs({ -5, 0, 5 }) do
		local ch = part(model, "BeltChevron" .. ox, Enum.Material.Neon, rgb(GOLD),
			Vector3.new(1.4, 0.2, 1.0), Vector3.new(cx + ox, 1.08, cz + t * 8.6),
			Enum.PartType.Wedge)
		-- Wedge slope faces +Z by default; flip for south bases so the
		-- point aims at the belt either way.
		ch.CFrame = CFrame.new(cx + ox, 1.08, cz + t * 8.6)
			* CFrame.Angles(0, if t == 1 then 0 else math.pi, 0)
	end
	-- Scuff strip on the front edge (wear where feet + snacks cross).
	part(model, "ScuffFront", Enum.Material.SmoothPlastic, Color3.fromRGB(70, 60, 50),
		Vector3.new(20, 0.05, 0.5), Vector3.new(cx, 1.02, cz + t * 6.4), nil, 0.7)
	-- Splayed wing walls framing the entrance: two Plaster walls angled
	-- 45 deg out from the front corners, like a shop's open doorway.
	-- They stand OUTSIDE the 20 x 14 platform (x ±10.8, z +8.2 toward
	-- the belt), on the grass, so they can never clip a snack on a slot
	-- (slots end at x ±6 + snack half-width, z ±3.5 + snack half-depth).
	-- The rotation sign mirrors per side and per base row (t).
	for _, side in ipairs({ -1, 1 }) do
		local wing = part(model, "WingWall" .. side, Enum.Material.Plaster,
			jitteredRGB(PLASTER_WALL, index, 20 + side, 0.04),
			Vector3.new(3.2, 2.6, 0.5),
			Vector3.new(cx + side * 10.8, 1.3, cz + t * 8.2), nil, nil, true)
		wing.CFrame = CFrame.new(cx + side * 10.8, 1.3, cz + t * 8.2)
			* CFrame.Angles(0, side * t * math.pi / 4, 0)
		local cap = part(model, "WingCap" .. side, Enum.Material.Neon, rgb(accent),
			Vector3.new(3.2, 0.2, 0.6),
			Vector3.new(cx + side * 10.8, 2.7, cz + t * 8.2))
		cap.CFrame = CFrame.new(cx + side * 10.8, 2.7, cz + t * 8.2)
			* CFrame.Angles(0, side * t * math.pi / 4, 0)
	end
	-- Cobblestone path, base front edge -> belt rail (4 jittered panels).
	local pathLen = 11
	for p = 1, 4 do
		local pz = cz + t * (7.6 + pathLen * (p - 0.5) / 4)
		part(model, "PathPanel" .. p, Enum.Material.Cobblestone,
			jitteredRGB(COBBLE, index * 4 + p, 7, 0.05),
			Vector3.new(6, 0.12, pathLen / 4 - 0.06), Vector3.new(cx, 0.06, pz))
	end
end

-- The base's ROOF (Lyso: "ga ada atapnya ini basenya"): an open pergola
-- over the BACK third of the platform. Wood side beams rest on the
-- pilaster caps, a front beam + Neon edge closes the front, and 3 accent
-- slats cross it with open gaps between them. The front two-thirds of
-- the platform stay fully open, and the back-row slots (z -3.5 rel.
-- centre) sit in the GAP between slats 2 and 3, so snacks on the slots
-- stay visible through the roof from above and fully visible from the
-- belt side (the camera looks under the slats). Front posts stand at
-- x ±9.6 — clear of the widest snack on the corner slots (x max 9).
local function buildRoof(model: Model, index: number, cx: number, cz: number): ()
	local t = towardBelt(index)
	local accent = BASE_ACCENTS[index]
	-- Side beams along Z, resting on the pilaster caps (cap top 6.925).
	for _, side in ipairs({ -1, 1 }) do
		part(model, "RoofBeam" .. side, Enum.Material.Wood, rgb({ 110, 78, 48 }),
			Vector3.new(0.5, 0.5, 5.5), Vector3.new(cx + side * 9.2, 7.2, cz - t * 4.0), nil, nil, true)
		-- Front post: floor (y 1) up to the front beam.
		part(model, "RoofPost" .. side, Enum.Material.Wood, rgb({ 110, 78, 48 }),
			Vector3.new(0.5, 6.2, 0.5), Vector3.new(cx + side * 9.6, 4.1, cz - t * 1.4), nil, nil, true)
	end
	-- Front beam across the full width + Neon edge on top of it.
	part(model, "RoofBeamFront", Enum.Material.Wood, rgb({ 110, 78, 48 }),
		Vector3.new(19, 0.5, 0.5), Vector3.new(cx, 7.2, cz - t * 1.4), nil, nil, true)
	part(model, "RoofNeonFront", Enum.Material.Neon, rgb(accent),
		Vector3.new(19, 0.15, 0.25), Vector3.new(cx, 7.5, cz - t * 1.4))
	-- 3 accent slats across the width. Gaps: slat 1 spans -6.05..-5.15,
	-- slat 2 -4.45..-3.55, slat 3 -2.85..-1.95 (rel. centre, x t).
	-- Back-row slots at -3.5 sit in the 0.7 gap between slats 2 and 3.
	for i, sz in ipairs({ -5.6, -4.0, -2.4 }) do
		part(model, "RoofSlat" .. i, Enum.Material.Fabric, rgb(accent),
			Vector3.new(19, 0.25, 0.9), Vector3.new(cx, 7.45, cz + t * sz))
	end
end

local function buildGreenery(model: Model, index: number, cx: number, cz: number): ()
	local t = towardBelt(index)
	-- Flower bed along the back-wall base: Pebble soil + 5 flowers.
	part(model, "FlowerBed", Enum.Material.Pebble, rgb({ 90, 65, 45 }),
		Vector3.new(8, 0.35, 1.2), Vector3.new(cx - 4, 1.15, cz - t * 5.6))
	for f = 1, 5 do
		local fx = cx - 7 + (f - 1) * 1.5 + (jitter(index, f, 0.1) - 1) * 0.4
		part(model, "FlowerStem" .. f, Enum.Material.SmoothPlastic, rgb({ 70, 110, 55 }),
			Vector3.new(0.12, 0.7, 0.12), Vector3.new(fx, 1.65, cz - t * 5.6))
		part(model, "Flower" .. f, Enum.Material.SmoothPlastic,
			rgb(FLOWER_COLORS[((index + f - 1) % #FLOWER_COLORS) + 1]),
			Vector3.new(0.35, 0.35, 0.35), Vector3.new(fx, 2.05, cz - t * 5.6),
			Enum.PartType.Ball)
	end
	-- Two layered bushes at the front corners (2 canopy volumes each).
	for _, side in ipairs({ -1, 1 }) do
		local bx = cx + side * 8.5
		local bz = cz + t * 5.5
		part(model, "BushA" .. side, Enum.Material.SmoothPlastic,
			jitteredRGB(CANOPY_GREENS[((index + side) % 4) + 1], index, side, 0.05),
			Vector3.new(1.8, 1.4, 1.8), Vector3.new(bx, 1.7, bz), Enum.PartType.Ball, nil, true)
		part(model, "BushB" .. side, Enum.Material.SmoothPlastic,
			jitteredRGB(CANOPY_GREENS[((index + side + 1) % 4) + 1], index, side + 3, 0.05),
			Vector3.new(1.2, 1.0, 1.2), Vector3.new(bx + side * 0.7, 1.5, bz + 0.4),
			Enum.PartType.Ball)
	end
end

-- The base's market stall, tucked just BEHIND the back wall (outside the
-- 20 x 14 platform) so it can never clip a snack on a slot. It faces the
-- base: awning toward the platform. Side alternates per base for variety.
local function buildStall(model: Model, index: number, cx: number, cz: number): ()
	local t = towardBelt(index)
	local side = if index % 2 == 0 then 1 else -1
	local sx = cx + side * 8
	local sz = cz - t * 10.2 -- stall centre, ~2.5 studs behind the wall
	-- Counter frame (Wood, dark) + top one tone lighter (skill rule).
	part(model, "StallCounter", Enum.Material.Wood, rgb({ 120, 85, 55 }),
		Vector3.new(3.6, 1.0, 1.6), Vector3.new(sx, 0.5, sz), nil, nil, true)
	part(model, "StallCounterTop", Enum.Material.Wood, rgb({ 165, 125, 80 }),
		Vector3.new(3.9, 0.25, 1.9), Vector3.new(sx, 1.1, sz), nil, nil, true)
	-- Back board with a FRAMED glass display window (glass never frameless).
	part(model, "StallBack", Enum.Material.Wood, rgb({ 105, 74, 48 }),
		Vector3.new(3.6, 2.2, 0.2), Vector3.new(sx, 1.6, sz - t * 0.9))
	local frameC = rgb({ 80, 56, 36 })
	part(model, "WindowFrameTop", Enum.Material.Wood, frameC,
		Vector3.new(1.9, 0.15, 0.12), Vector3.new(sx, 2.55, sz - t * 0.78))
	part(model, "WindowFrameBottom", Enum.Material.Wood, frameC,
		Vector3.new(1.9, 0.15, 0.12), Vector3.new(sx, 1.45, sz - t * 0.78))
	part(model, "WindowFrameLeft", Enum.Material.Wood, frameC,
		Vector3.new(0.15, 1.25, 0.12), Vector3.new(sx - 0.9, 2.0, sz - t * 0.78))
	part(model, "WindowFrameRight", Enum.Material.Wood, frameC,
		Vector3.new(0.15, 1.25, 0.12), Vector3.new(sx + 0.9, 2.0, sz - t * 0.78))
	part(model, "StallWindow", Enum.Material.Glass, rgb({ 170, 200, 215 }),
		Vector3.new(1.6, 1.0, 0.08), Vector3.new(sx, 2.0, sz - t * 0.78), nil, 0.4)
	-- Rain streaks under the window: thin dark translucent strips.
	for _, ox in ipairs({ -0.5, 0.4 }) do
		part(model, "WindowStreak" .. ox, Enum.Material.SmoothPlastic,
			Color3.fromRGB(70, 62, 52), Vector3.new(0.12, 0.9, 0.05),
			Vector3.new(sx + ox, 1.0, sz - t * 0.76), nil, 0.7)
	end
	-- Awning: 4 Fabric stripes, red/white, tilted ~20 deg toward the base.
	for a = 1, 4 do
		local stripe = part(model, "AwningStripe" .. a, Enum.Material.Fabric,
			rgb(if a % 2 == 1 then AWNING_RED else CREAM),
			Vector3.new(1.0, 0.12, 2.4),
			Vector3.new(sx - 2 + a - 0.5, 3.35, sz + t * 0.3))
		stripe.CFrame = CFrame.new(sx - 2 + a - 0.5, 3.35, sz + t * 0.3)
			* CFrame.Angles(t * -0.35, 0, 0)
	end
	-- Awning posts (tall — they reach just under the stall canopy above).
	for _, px in ipairs({ -1.8, 1.8 }) do
		part(model, "AwningPost" .. px, Enum.Material.Wood, rgb({ 110, 78, 48 }),
			Vector3.new(0.3, 3.8, 0.3), Vector3.new(sx + px, 1.9, sz + t * 1.3), nil, nil, true)
	end
	-- Stall canopy (atap): a solid sloped Wood slab over the whole stall,
	-- high at the back board, low over the counter, carried by the tall
	-- awning posts in front and the back board behind. The stall reads as
	-- a roofed kiosk from the plaza, and the lamp still glows under it.
	local canopy = part(model, "StallCanopy", Enum.Material.Wood, rgb({ 140, 100, 62 }),
		Vector3.new(5.0, 0.25, 4.2), Vector3.new(sx, 4.5, sz - t * 0.2), nil, nil, true)
	canopy.CFrame = CFrame.new(sx, 4.5, sz - t * 0.2) * CFrame.Angles(t * 0.4, 0, 0)
	-- Warm Neon trim along the canopy's low front edge (same tilt).
	local trim = part(model, "StallCanopyTrim", Enum.Material.Neon, rgb(LAMP_WARM),
		Vector3.new(5.0, 0.15, 0.2), Vector3.new(sx, 3.78, sz + t * 1.7))
	trim.CFrame = CFrame.new(sx, 3.78, sz + t * 1.7) * CFrame.Angles(t * 0.4, 0, 0)
	-- Rear posts carry the canopy's high back edge down to the ground.
	for _, px in ipairs({ -1.8, 1.8 }) do
		part(model, "CanopyPost" .. px, Enum.Material.Wood, rgb({ 110, 78, 48 }),
			Vector3.new(0.3, 5.3, 0.3), Vector3.new(sx + px, 2.65, sz - t * 2.0), nil, nil, true)
	end
	-- Glass jars on the counter (tinted, Transparency 0.35) + goods.
	local jarTints = { { 220, 170, 80 }, { 200, 90, 90 }, { 150, 190, 120 } }
	for j = 1, 3 do
		part(model, "Jar" .. j, Enum.Material.Glass, rgb(jarTints[j]),
			Vector3.new(0.5, 0.7, 0.5), Vector3.new(sx - 1.2 + (j - 1) * 0.9, 1.55, sz - 0.4),
			Enum.PartType.Cylinder, 0.35)
	end
	part(model, "GoodsBox1", Enum.Material.Cardboard, rgb({ 165, 135, 95 }),
		Vector3.new(0.8, 0.6, 0.8), Vector3.new(sx + 1.2, 1.5, sz + 0.4))
	part(model, "GoodsFoil1", Enum.Material.Foil, rgb({ 235, 200, 60 }),
		Vector3.new(0.5, 0.35, 0.7), Vector3.new(sx - 1.2, 1.4, sz + 0.45))
	part(model, "GoodsFoil2", Enum.Material.Foil, rgb({ 220, 90, 110 }),
		Vector3.new(0.5, 0.35, 0.7), Vector3.new(sx - 0.5, 1.4, sz + 0.45))
	-- Counter stain near the front edge (wear where hands + spills land).
	part(model, "CounterStain", Enum.Material.SmoothPlastic, Color3.fromRGB(60, 45, 30),
		Vector3.new(0.7, 0.03, 0.5), Vector3.new(sx + 0.6, 1.24, sz + 0.7), nil, 0.6)
	-- THE stall lamp: warm 2700 K Neon bulb + PointLight, range 14.
	-- Shadows = false (sun is the only shadow caster; see notes).
	local poleX = sx - side * 2.4
	part(model, "LampPole", Enum.Material.Metal, rgb({ 55, 55, 60 }),
		Vector3.new(0.25, 3.4, 0.25), Vector3.new(poleX, 1.7, sz + t * 1.3), nil, nil, true)
	part(model, "LampArm", Enum.Material.Metal, rgb({ 55, 55, 60 }),
		Vector3.new(1.0, 0.2, 0.2), Vector3.new(poleX + side * 0.45, 3.3, sz + t * 1.3))
	local bulb = part(model, "LampBulb", Enum.Material.Neon, rgb(LAMP_WARM),
		Vector3.new(0.5, 0.5, 0.5), Vector3.new(poleX + side * 0.9, 3.1, sz + t * 1.3),
		Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Name = "LampLight"
	light.Color = rgb(LAMP_WARM)
	light.Brightness = 1.2
	light.Range = 14
	light.Shadows = false
	light.Parent = bulb
	-- Wall sconce over the stall back board: Neon glow, no light cost.
	part(model, "SconceBulb", Enum.Material.Neon, rgb(LAMP_WARM),
		Vector3.new(0.35, 0.35, 0.35), Vector3.new(sx, 3.0, sz - t * 0.75),
		Enum.PartType.Ball)
end

-- Layered tree: Wood trunk (2 segments, slight lean) + 3 canopy volumes
-- in varied greens. Canopy casts shadows; trunk does too.
local function buildTree(parent: Instance, index: number, x: number, z: number): ()
	local trunkC = jitteredRGB({ 110, 78, 48 }, index, 21, 0.05)
	part(parent, "TreeTrunk" .. index, Enum.Material.Wood, trunkC,
		Vector3.new(1.2, 5, 1.2), Vector3.new(x, 2.5, z), nil, nil, true)
	part(parent, "TreeBranch" .. index, Enum.Material.Wood, trunkC,
		Vector3.new(0.7, 2.4, 0.7), Vector3.new(x + 0.9, 5.2, z + 0.3), nil, nil, true)
	local canopySizes = { 5.2, 4.0, 3.2 }
	local canopyPos = {
		Vector3.new(x, 7.6, z),
		Vector3.new(x + 1.6, 6.4, z + 0.8),
		Vector3.new(x - 1.5, 6.8, z - 0.9),
	}
	for ci = 1, 3 do
		local s = canopySizes[ci]
		part(parent, "TreeCanopy" .. index .. "_" .. ci, Enum.Material.SmoothPlastic,
			jitteredRGB(CANOPY_GREENS[((index + ci) % 4) + 1], index, ci * 13, 0.05),
			Vector3.new(s, s * 0.85, s), canopyPos[ci], Enum.PartType.Ball, nil, true)
	end
	part(parent, "TreeBush" .. index, Enum.Material.SmoothPlastic,
		jitteredRGB(CANOPY_GREENS[((index + 2) % 4) + 1], index, 31, 0.05),
		Vector3.new(1.6, 1.2, 1.6), Vector3.new(x + 1.2, 0.6, z + 1.0), Enum.PartType.Ball)
end

-- Granite fountain in the north gap (between bases 1-2, x = -36, z = -22).
local function buildFountain(parent: Instance): ()
	local fx, fz = -36, -22
	local basin = part(parent, "FountainBasin", Enum.Material.Granite, rgb({ 150, 148, 142 }),
		Vector3.new(1, 8, 8), Vector3.new(fx, 0.5, fz), Enum.PartType.Cylinder, nil, true)
	basin.CFrame = CFrame.new(fx, 0.5, fz) * CFrame.Angles(0, 0, math.pi / 2)
	local water = part(parent, "FountainWater", Enum.Material.Glass, rgb({ 120, 180, 220 }),
		Vector3.new(0.5, 7, 7), Vector3.new(fx, 0.65, fz), Enum.PartType.Cylinder, 0.35)
	water.CFrame = CFrame.new(fx, 0.65, fz) * CFrame.Angles(0, 0, math.pi / 2)
	local column = part(parent, "FountainColumn", Enum.Material.Slate, rgb({ 135, 132, 128 }),
		Vector3.new(1, 1.4, 1.4), Vector3.new(fx, 1.4, fz), Enum.PartType.Cylinder, nil, true)
	column.CFrame = CFrame.new(fx, 1.4, fz) * CFrame.Angles(0, 0, math.pi / 2)
	local top = part(parent, "FountainTopWater", Enum.Material.Glass, rgb({ 140, 195, 230 }),
		Vector3.new(0.25, 2.2, 2.2), Vector3.new(fx, 2.2, fz), Enum.PartType.Cylinder, 0.3)
	top.CFrame = CFrame.new(fx, 2.2, fz) * CFrame.Angles(0, 0, math.pi / 2)
	-- Cool dim sparkle light over the water (shadowless, range 10).
	local glow = part(parent, "FountainGlow", Enum.Material.Neon, rgb({ 150, 200, 235 }),
		Vector3.new(0.4, 0.4, 0.4), Vector3.new(fx, 2.6, fz), Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Name = "FountainLight"
	light.Color = Color3.fromRGB(180, 210, 255)
	light.Brightness = 0.4
	light.Range = 10
	light.Shadows = false
	light.Parent = glow
	for i = 1, 4 do
		local a = (i - 1) * math.pi / 2 + 0.4
		part(parent, "FountainBush" .. i, Enum.Material.SmoothPlastic,
			jitteredRGB(CANOPY_GREENS[(i % 4) + 1], 50, i, 0.05),
			Vector3.new(1.4, 1.1, 1.4),
			Vector3.new(fx + math.cos(a) * 5.2, 0.55, fz + math.sin(a) * 5.2),
			Enum.PartType.Ball)
	end
end

-- Pebble-rim pond in the south gap (between bases 7-8, x = 36, z = 22).
local function buildPond(parent: Instance): ()
	local px, pz = 36, 22
	local water = part(parent, "PondWater", Enum.Material.Glass, rgb({ 110, 175, 165 }),
		Vector3.new(0.4, 9, 9), Vector3.new(px, 0.2, pz), Enum.PartType.Cylinder, 0.4)
	water.CFrame = CFrame.new(px, 0.2, pz) * CFrame.Angles(0, 0, math.pi / 2)
	for i = 1, 8 do
		local a = (i - 1) * math.pi / 4
		part(parent, "PondStone" .. i, Enum.Material.Pebble,
			jitteredRGB({ 130, 125, 118 }, 60, i, 0.05),
			Vector3.new(1.1, 1.1, 1.1),
			Vector3.new(px + math.cos(a) * 4.6, 0.45, pz + math.sin(a) * 4.6),
			Enum.PartType.Ball)
	end
	for i = 1, 3 do
		local a = i * 2.1
		local pad = part(parent, "LilyPad" .. i, Enum.Material.SmoothPlastic,
			rgb({ 80, 140, 70 }), Vector3.new(0.12, 1.3, 1.3),
			Vector3.new(px + math.cos(a) * 2.2, 0.42, pz + math.sin(a) * 2.2),
			Enum.PartType.Cylinder)
		pad.CFrame = CFrame.new(px + math.cos(a) * 2.2, 0.42, pz + math.sin(a) * 2.2)
			* CFrame.Angles(0, 0, math.pi / 2)
		part(parent, "LilyFlower" .. i, Enum.Material.SmoothPlastic,
			rgb(FLOWER_COLORS[i]), Vector3.new(0.3, 0.3, 0.3),
			Vector3.new(px + math.cos(a) * 2.2, 0.6, pz + math.sin(a) * 2.2),
			Enum.PartType.Ball)
	end
end

-- ------------------------------------------------------------------
-- PLAZA LIGHTS + GROUND LIFE (background polish, Lyso order 2026-11-18)
-- ------------------------------------------------------------------

local STRING_COLORS = {
	{ 255, 200, 100 }, -- warm gold
	{ 255, 150, 180 }, -- soft pink
	{ 140, 220, 255 }, -- soft cyan
	{ 255, 240, 200 }, -- warm white
} :: { { number } }

-- Carnival rainbow (ferris wheel + tower trim): bright Neon colours.
local RAINBOW = {
	{ 255, 80, 80 }, -- red
	{ 255, 200, 60 }, -- gold
	{ 90, 220, 110 }, -- green
	{ 90, 200, 255 }, -- cyan
	{ 180, 120, 255 }, -- purple
	{ 255, 130, 190 }, -- pink
} :: { { number } }

-- 6 plaza lamp posts framing the belt, 3 per side. The ±56 posts stand
-- at the edge of the outer base paths (lamps lining the paths); the 0
-- posts stand in the centre gaps. All clear of the belt, slots and spawn.
local LAMP_POSTS = {
	{ -56, -8 }, { 0, -8 }, { 56, -8 },
	{ -56, 8 }, { 0, 8 }, { 56, 8 },
} :: { { number } }

-- One tall plaza lamp post: stone base + dark pole + hanging warm
-- lantern (Neon bulb + PointLight, range 18, shadowless).
local function buildLampPost(parent: Instance, n: number, x: number, z: number): ()
	local dir = if z < 0 then 1 else -1 -- arm reaches toward the belt
	part(parent, "PlazaLampBase" .. n, Enum.Material.Cobblestone, rgb(STONE),
		Vector3.new(1.2, 0.6, 1.2), Vector3.new(x, 0.3, z), nil, nil, true)
	part(parent, "PlazaLampPole" .. n, Enum.Material.Metal, rgb({ 55, 55, 60 }),
		Vector3.new(0.35, 7, 0.35), Vector3.new(x, 3.5, z), nil, nil, true)
	part(parent, "PlazaLampArm" .. n, Enum.Material.Metal, rgb({ 55, 55, 60 }),
		Vector3.new(0.25, 0.25, 1.4), Vector3.new(x, 6.8, z + dir * 0.6))
	part(parent, "PlazaLampRod" .. n, Enum.Material.Metal, rgb({ 55, 55, 60 }),
		Vector3.new(0.12, 0.5, 0.12), Vector3.new(x, 6.6, z + dir * 1.2))
	local bulb = part(parent, "PlazaLampBulb" .. n, Enum.Material.Neon, rgb(LAMP_WARM),
		Vector3.new(0.7, 0.7, 0.7), Vector3.new(x, 6.2, z + dir * 1.2), Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Name = "PlazaLampLight" .. n
	light.Color = rgb(LAMP_WARM)
	light.Brightness = 1.5
	light.Range = 18
	light.Shadows = false
	light.Parent = bulb
	part(parent, "PlazaLampCap" .. n, Enum.Material.Metal, rgb({ 55, 55, 60 }),
		Vector3.new(0.9, 0.25, 0.9), Vector3.new(x, 7.1, z))
end

-- String-light catenary between two lamp posts on the same side.
-- Bulbs every 7 studs, sagging 1.3 at mid-span; thin wire segments
-- join them. Bulbs are Neon (emissive only, no light cost).
local function buildStringSpan(parent: Instance, span: number, x1: number, x2: number, z: number): ()
	local baseY = 7.0
	local half = (x2 - x1) / 2
	local mid = (x1 + x2) / 2
	local function sagY(x: number): number
		local u = (x - mid) / half
		return baseY - 1.3 * (1 - u * u)
	end
	-- Points: post top, 7 bulbs, post top.
	local pts = {}
	table.insert(pts, Vector3.new(x1, baseY, z))
	for b = 1, 7 do
		local bx = x1 + 7 * b
		table.insert(pts, Vector3.new(bx, sagY(bx), z))
	end
	table.insert(pts, Vector3.new(x2, baseY, z))
	-- Bulbs (skip the two post endpoints).
	for b = 2, 8 do
		local p = pts[b]
		part(parent, "StringBulb" .. span .. "_" .. (b - 1), Enum.Material.Neon,
			rgb(STRING_COLORS[((b - 2) % #STRING_COLORS) + 1]),
			Vector3.new(0.35, 0.35, 0.35), p, Enum.PartType.Ball)
	end
	-- Wire segments between consecutive points.
	for s = 1, #pts - 1 do
		local a = pts[s]
		local b = pts[s + 1]
		local dx = b.X - a.X
		local dy = b.Y - a.Y
		local len = math.sqrt(dx * dx + dy * dy)
		local wire = part(parent, "StringWire" .. span .. "_" .. s, Enum.Material.SmoothPlastic,
			Color3.fromRGB(40, 38, 36), Vector3.new(len + 0.1, 0.06, 0.06),
			Vector3.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, z))
		wire.CFrame = CFrame.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, z)
			* CFrame.Angles(0, 0, math.atan2(dy, dx))
	end
end

-- Flower beds along the belt, in the gaps between bases (clear of the
-- belt rails and the base fronts).
local function buildBeltFlowers(parent: Instance): ()
	local spots = { { -36, -5.5 }, { 36, -5.5 }, { -36, 5.5 }, { 36, 5.5 } }
	for i, spot in ipairs(spots) do
		local bx, bz = spot[1], spot[2]
		part(parent, "BeltFlowerBed" .. i, Enum.Material.Pebble, rgb({ 90, 65, 45 }),
			Vector3.new(4, 0.35, 1.2), Vector3.new(bx, 0.175, bz))
		for f = 1, 3 do
			local fx = bx - 1.2 + (f - 1) * 1.2
			part(parent, "BeltFlowerStem" .. i .. "_" .. f, Enum.Material.SmoothPlastic,
				rgb({ 70, 110, 55 }), Vector3.new(0.12, 0.6, 0.12), Vector3.new(fx, 0.65, bz))
			part(parent, "BeltFlower" .. i .. "_" .. f, Enum.Material.SmoothPlastic,
				rgb(FLOWER_COLORS[((i + f - 1) % #FLOWER_COLORS) + 1]),
				Vector3.new(0.35, 0.35, 0.35), Vector3.new(fx, 1.0, bz), Enum.PartType.Ball)
		end
	end
end

-- Boulder clusters on the outer grass, away from play.
local function buildRocks(parent: Instance): ()
	local clusters = { { -95, 0 }, { 95, 0 }, { 0, -62 } }
	for i, c in ipairs(clusters) do
		local sizes = { 2.2, 1.5, 1.1 }
		for j, s in ipairs(sizes) do
			part(parent, "Rock" .. i .. "_" .. j, Enum.Material.Slate,
				jitteredRGB({ 130, 128, 122 }, i * 10 + j, 5, 0.05),
				Vector3.new(s, s * 0.8, s),
				Vector3.new(c[1] + (j - 2) * 1.6, s * 0.4, c[2] + (j % 2) * 1.2),
				Enum.PartType.Ball, nil, true)
		end
	end
end

-- Cobble paths from the belt to the fountain (north gap) and the pond
-- (south gap), so the water features connect to the play area.
local function buildFeaturePaths(parent: Instance): ()
	for p = 1, 4 do
		part(parent, "FountainPath" .. p, Enum.Material.Cobblestone,
			jitteredRGB(COBBLE, 70 + p, 7, 0.05),
			Vector3.new(4, 0.12, 3), Vector3.new(-36, 0.06, -5 - (p - 1) * 3.2))
		part(parent, "PondPath" .. p, Enum.Material.Cobblestone,
			jitteredRGB(COBBLE, 80 + p, 7, 0.05),
			Vector3.new(4, 0.12, 3), Vector3.new(36, 0.06, 5 + (p - 1) * 3.2))
	end
end

-- ------------------------------------------------------------------
-- BELT — UNMISSABLE (Lyso live-test 2026-11-18)
-- ------------------------------------------------------------------
local function buildBelt(parent: Instance): ()
	-- Cream centre lane down the middle of the dark belt (top y 2.0):
	-- the walking snacks pop against it. Gold Neon strips on both
	-- SIDE faces of the belt (not the top, so they never fight the
	-- walkers' discs): visible from the side and from above.
	part(parent, "BeltLane", Enum.Material.SmoothPlastic, rgb(CREAM),
		Vector3.new(128, 0.06, 1.6), Vector3.new(0, 2.03, 0))
	for _, side in ipairs({ -1, 1 }) do
		part(parent, "BeltEdge" .. (if side == 1 then "South" else "North"), Enum.Material.Neon, rgb(GOLD),
			Vector3.new(128, 0.5, 0.12), Vector3.new(0, 1.75, side * 3.06))
	end
	-- Big "SNACK BELT" sign gates at both ends of the belt, facing the
	-- plaza (west sign faces +X, east sign faces -X). Walkers never
	-- reach x ±66.5 (they turn at ±64), so the board never clips one.
	for _, s in ipairs({ -1, 1 }) do
		local x = s * 66.5
		for i, pz in ipairs({ -3.2, 3.2 }) do
			part(parent, "BeltSignPost" .. s .. "_" .. i, Enum.Material.Wood, rgb({ 110, 78, 48 }),
				Vector3.new(0.4, 3.2, 0.4), Vector3.new(x, 1.6, pz), nil, nil, true)
		end
		local board = part(parent, "BeltSign" .. (if s == -1 then "West" else "East"),
			Enum.Material.SmoothPlastic, rgb({ 35, 32, 40 }),
			Vector3.new(0.3, 2.6, 7), Vector3.new(x, 4.5, 0), nil, nil, true)
		part(parent, "BeltSignTrimTop" .. s, Enum.Material.Neon, rgb(GOLD),
			Vector3.new(0.35, 0.25, 7.3), Vector3.new(x, 5.9, 0))
		part(parent, "BeltSignTrimBottom" .. s, Enum.Material.Neon, rgb(GOLD),
			Vector3.new(0.35, 0.25, 7.3), Vector3.new(x, 3.1, 0))
		local gui = Instance.new("SurfaceGui")
		gui.Name = "BeltSignGui"
		gui.Face = if s == -1 then Enum.NormalId.Right else Enum.NormalId.Left
		gui.AlwaysOnTop = false
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "BeltSignText"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "SNACK BELT"
		label.TextColor3 = rgb(GOLD)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
	end
	-- Gold Neon chevrons on the grass pointing at the belt, both sides.
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 5 do
			local ax = -48 + (i - 1) * 24
			local ch = part(parent, "BeltArrow" .. (if side == -1 then "N" else "S") .. i,
				Enum.Material.Neon, rgb(GOLD),
				Vector3.new(2, 0.2, 2), Vector3.new(ax, 0.1, side * 10), Enum.PartType.Wedge)
			ch.CFrame = CFrame.new(ax, 0.1, side * 10)
				* CFrame.Angles(0, if side == -1 then 0 else math.pi, 0)
		end
	end
	-- Cobble promenade strips flanking the belt: the bare grass band
	-- between the belt and the base rows becomes a walkway (this is the
	-- band that read as a raw green block in Lyso's screenshot).
	for _, side in ipairs({ -1, 1 }) do
		for p = 1, 8 do
			local px = -56 + (p - 1) * 16
			part(parent, "PromenadePanel" .. (if side == -1 then "N" else "S") .. p,
				Enum.Material.Cobblestone, jitteredRGB(COBBLE, 90 + p, side, 0.05),
				Vector3.new(16, 0.1, 2.6), Vector3.new(px, 0.05, side * 4.9))
		end
	end
	-- Shaped round bushes just beyond the promenade (Balls, never Blocks).
	local bushSpots = { { -12, -7.5 }, { 12, -7.5 }, { -12, 7.5 }, { 12, 7.5 } }
	for i, spot in ipairs(bushSpots) do
		part(parent, "BeltBushA" .. i, Enum.Material.SmoothPlastic,
			jitteredRGB(CANOPY_GREENS[(i % 4) + 1], 100, i, 0.05),
			Vector3.new(1.7, 1.3, 1.7), Vector3.new(spot[1], 0.65, spot[2]), Enum.PartType.Ball, nil, true)
		part(parent, "BeltBushB" .. i, Enum.Material.SmoothPlastic,
			jitteredRGB(CANOPY_GREENS[((i + 1) % 4) + 1], 100, i + 5, 0.05),
			Vector3.new(1.1, 0.9, 1.1), Vector3.new(spot[1] + 0.8, 0.45, spot[2] + 0.5), Enum.PartType.Ball)
	end
end

-- ------------------------------------------------------------------
-- CARNIVAL — tower + ferris wheel (Lyso order 2026-11-18)
-- ------------------------------------------------------------------

-- Ferris wheel at (-92, 15), west end, facing the plaza (its circle
-- lies in the Y-Z plane, so the plaza sees it face-on). Ring + spokes
-- + 8 cabins + A-frame legs, rainbow Neon. STATIC by design: no
-- rotation script (that would need init wiring and could break the
-- headless harness); the Neon carries the carnival read.
local function buildFerrisWheel(parent: Instance): ()
	local hx, hy, hz = -92, 17, 15
	local R = 12.5
	part(parent, "FerrisPlatform", Enum.Material.Cobblestone, rgb(STONE),
		Vector3.new(8, 0.5, 16), Vector3.new(hx, 0.25, hz), nil, nil, true)
	-- A-frame legs: base (hx, 0, hz + s*7.5) to hub; Y-long box rotated
	-- about X by -s*0.419 rad (atan(7.5/17)).
	for _, s in ipairs({ -1, 1 }) do
		local leg = part(parent, "FerrisLeg" .. s, Enum.Material.Metal, rgb({ 70, 70, 78 }),
			Vector3.new(0.9, 18.6, 0.9), Vector3.new(hx, 8.5, hz + s * 3.75), nil, nil, true)
		leg.CFrame = CFrame.new(hx, 8.5, hz + s * 3.75) * CFrame.Angles(-s * 0.419, 0, 0)
	end
	part(parent, "FerrisCrossbar", Enum.Material.Metal, rgb({ 70, 70, 78 }),
		Vector3.new(0.7, 0.7, 15), Vector3.new(hx, 8.5, hz))
	-- Hub: cylinder along X (Roblox cylinders are X-axis by default, so
	-- no rotation) + Neon orb at the centre.
	part(parent, "FerrisHub", Enum.Material.Metal, rgb({ 55, 55, 60 }),
		Vector3.new(1.2, 2.4, 2.4), Vector3.new(hx, hy, hz), Enum.PartType.Cylinder, nil, true)
	part(parent, "FerrisHubOrb", Enum.Material.Neon, rgb(RAINBOW[2]),
		Vector3.new(1.2, 1.2, 1.2), Vector3.new(hx, hy, hz), Enum.PartType.Ball)
	-- Rim: 12 Neon segments (dodecagon) + 12 bulbs at the vertices.
	for i = 1, 12 do
		local a = (i - 0.5) * math.pi / 6 -- segment centre angle from +Y
		local seg = part(parent, "FerrisRim" .. i, Enum.Material.Neon,
			rgb(RAINBOW[((i - 1) % #RAINBOW) + 1]),
			Vector3.new(0.5, 6.6, 0.5),
			Vector3.new(hx, hy + math.cos(a) * R, hz + math.sin(a) * R))
		seg.CFrame = CFrame.new(hx, hy + math.cos(a) * R, hz + math.sin(a) * R)
			* CFrame.Angles(a + math.pi / 2, 0, 0)
		local v = (i - 1) * math.pi / 6
		part(parent, "FerrisBulb" .. i, Enum.Material.Neon,
			rgb(RAINBOW[((i + 2) % #RAINBOW) + 1]),
			Vector3.new(0.55, 0.55, 0.55),
			Vector3.new(hx, hy + math.cos(v) * R, hz + math.sin(v) * R), Enum.PartType.Ball)
	end
	-- Spokes: 8 radial bars from hub to rim.
	for i = 1, 8 do
		local a = (i - 1) * math.pi / 4
		local spoke = part(parent, "FerrisSpoke" .. i, Enum.Material.Metal, rgb({ 90, 90, 100 }),
			Vector3.new(0.35, R, 0.35),
			Vector3.new(hx, hy + math.cos(a) * (R / 2), hz + math.sin(a) * (R / 2)))
		spoke.CFrame = CFrame.new(hx, hy + math.cos(a) * (R / 2), hz + math.sin(a) * (R / 2))
			* CFrame.Angles(a, 0, 0)
	end
	-- Cabins: 8 colourful cars on the rim + a Neon bulb each.
	local cabinColors = {
		{ 255, 90, 90 }, { 255, 200, 60 }, { 90, 220, 110 }, { 90, 200, 255 },
		{ 180, 120, 255 }, { 255, 130, 190 }, { 255, 150, 60 }, { 120, 255, 200 },
	} :: { { number } }
	for i = 1, 8 do
		local a = (i - 1) * math.pi / 4 + math.pi / 8
		local cy = hy + math.cos(a) * 11
		local cz = hz + math.sin(a) * 11
		part(parent, "FerrisCabin" .. i, Enum.Material.SmoothPlastic, rgb(cabinColors[i]),
			Vector3.new(2.4, 2.2, 2.2), Vector3.new(hx, cy, cz), nil, nil, true)
		part(parent, "FerrisCabinBulb" .. i, Enum.Material.Neon, rgb(RAINBOW[((i - 1) % #RAINBOW) + 1]),
			Vector3.new(0.4, 0.4, 0.4), Vector3.new(hx, cy + 1.3, cz), Enum.PartType.Ball)
	end
	-- Pennant flags on the platform corners.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local px = hx + sx * 3.5
			local pz = hz + sz * 7
			part(parent, "FerrisPennantPole" .. sx .. "_" .. sz, Enum.Material.Wood, rgb({ 110, 78, 48 }),
				Vector3.new(0.2, 3.5, 0.2), Vector3.new(px, 1.75, pz))
			part(parent, "FerrisPennant" .. sx .. "_" .. sz, Enum.Material.Fabric,
				rgb(RAINBOW[((sx + sz + 4) % #RAINBOW) + 1]),
				Vector3.new(1.3, 0.8, 0.08), Vector3.new(px + sx * 0.7, 3.1, pz))
		end
	end
end

-- Carnival tower at (95, -25), east end: 3 shrinking tiers, Neon trim
-- rings, glowing beacon (+ the carnival's only real PointLight) and a
-- flag on top. Windows + door face the plaza (west).
local function buildTower(parent: Instance): ()
	local tx, tz = 95, -25
	part(parent, "TowerPlatform", Enum.Material.Cobblestone, rgb(STONE),
		Vector3.new(10, 0.6, 10), Vector3.new(tx, 0.3, tz), nil, nil, true)
	local tierWidths = { 7, 5.5, 4 }
	local tierHeights = { 9, 8, 7 }
	local tierColors = {
		{ 198, 190, 172 },
		{ 210, 202, 184 },
		{ 222, 214, 196 },
	} :: { { number } }
	local y = 0.6
	for i = 1, 3 do
		local w = tierWidths[i]
		local h = tierHeights[i]
		local c = tierColors[i]
		part(parent, "TowerTier" .. i, Enum.Material.Plaster, rgb(c),
			Vector3.new(w, h, w), Vector3.new(tx, y + h / 2, tz), nil, nil, true)
		y += h
		part(parent, "TowerTrim" .. i, Enum.Material.Neon, rgb(RAINBOW[((i + 2) % #RAINBOW) + 1]),
			Vector3.new(w + 0.4, 0.4, w + 0.4), Vector3.new(tx, y, tz))
	end
	for _, wy in ipairs({ 3.5, 6, 8.5 }) do
		part(parent, "TowerWindow" .. wy, Enum.Material.Neon, rgb(LAMP_WARM),
			Vector3.new(0.15, 1.2, 0.9), Vector3.new(tx - 3.55, wy, tz))
	end
	part(parent, "TowerDoor", Enum.Material.SmoothPlastic, rgb({ 60, 45, 35 }),
		Vector3.new(0.2, 3, 1.8), Vector3.new(tx - 3.55, 2.1, tz))
	-- Beacon: glowing orb + the carnival's only real PointLight.
	local beacon = part(parent, "TowerBeacon", Enum.Material.Neon, rgb({ 140, 220, 255 }),
		Vector3.new(1.6, 1.6, 1.6), Vector3.new(tx, y + 0.8, tz), Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Name = "TowerBeaconLight"
	light.Color = Color3.fromRGB(140, 220, 255)
	light.Brightness = 1.0
	light.Range = 24
	light.Shadows = false
	light.Parent = beacon
	-- Flag on top, on its own pole beside the beacon.
	part(parent, "TowerFlagPole", Enum.Material.Wood, rgb({ 110, 78, 48 }),
		Vector3.new(0.25, 3, 0.25), Vector3.new(tx + 1.2, y + 1.5, tz))
	part(parent, "TowerFlag", Enum.Material.Fabric, rgb(RAINBOW[2]),
		Vector3.new(2.0, 1.2, 0.1), Vector3.new(tx + 2.3, y + 2.4, tz))
end

-- ------------------------------------------------------------------
-- Public build entry points (additive API).
-- ------------------------------------------------------------------
function Bases.buildBase(index: number, parent: Instance?): Model
	assert(index >= 1 and index <= Config.MAX_BASES, "Bases.buildBase: index 1..8")
	local center = Config.BASE_CENTERS[index]
	local model = Instance.new("Model")
	model.Name = "Base" .. index .. "Env"
	buildFloor(model, index, center.X, center.Z)
	buildWall(model, index, center.X, center.Z)
	buildFront(model, index, center.X, center.Z)
	buildRoof(model, index, center.X, center.Z)
	buildGreenery(model, index, center.X, center.Z)
	buildStall(model, index, center.X, center.Z)
	model.Parent = parent or game:GetService("Workspace")
	return model
end

function Bases.build(parent: Instance?): Folder
	local workspace = parent or game:GetService("Workspace")
	local old = workspace:FindFirstChild("BasesEnv")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BasesEnv"
	for i = 1, Config.MAX_BASES do
		Bases.buildBase(i, folder)
	end
	-- Plaza dressing: layered trees on the outer strips + water features.
	local treeSpots = {
		{ -72, -38 }, { -36, -38 }, { 36, -38 }, { 72, -38 },
		{ -72, 38 }, { -36, 38 }, { 36, 38 }, { 72, 38 },
		{ -85, -45 }, { 85, -45 }, { -85, 45 }, { 85, 45 },
	}
	for i, spot in ipairs(treeSpots) do
		buildTree(folder, i, spot[1], spot[2])
	end
	buildFountain(folder)
	buildPond(folder)
	-- Background lights: 6 plaza lamp posts + 4 string-light spans.
	for n, post in ipairs(LAMP_POSTS) do
		buildLampPost(folder, n, post[1], post[2])
	end
	buildStringSpan(folder, 1, -56, 0, -8)
	buildStringSpan(folder, 2, 0, 56, -8)
	buildStringSpan(folder, 3, -56, 0, 8)
	buildStringSpan(folder, 4, 0, 56, 8)
	-- Ground life: belt flower beds, boulders, feature paths.
	buildBeltFlowers(folder)
	buildRocks(folder)
	buildFeaturePaths(folder)
	-- Belt dressing (unmissable) + carnival landmarks (background).
	buildBelt(folder)
	buildFerrisWheel(folder)
	buildTower(folder)
	folder.Parent = workspace
	return folder
end

return Bases
