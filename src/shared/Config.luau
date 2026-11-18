--!strict
-- Steal a Snack v2 — shared game data.
-- Pure data + deterministic roll helpers. No Roblox services are touched here,
-- so this module loads in the headless test harness as well as in Roblox.
-- Colours are plain {r, g, b} 0-255 triples; callers convert to Color3.

local Config = {}

-- ------------------------------------------------------------------ tuning
Config.START_CASH = 100
Config.CASH_TICK = 1 -- seconds between income ticks
Config.MAX_SLOTS_PER_BASE = 6
Config.MAX_BASES = 8
Config.REBIRTH_BASE_COST = 25000
Config.REBIRTH_MULTIPLIER_STEP = 0.25
Config.LOCK_DURATION = 20 -- seconds a base stays locked
Config.LOCK_COOLDOWN = 60 -- seconds between locks
Config.STEAL_COOLDOWN = 5 -- seconds between steal attempts per player
Config.WAVE_PERIOD = 90 -- seconds between waves
Config.WAVE_WARN = 10 -- seconds of warning before a wave hits
Config.WAVE_DURATION = 10 -- seconds a wave lasts
Config.WEATHER_MIN = 150 -- shortest weather stretch (seconds)
Config.WEATHER_MAX = 180 -- longest weather stretch (seconds)
Config.WEATHER_FADE = 4 -- seconds a weather transition takes
Config.CONVEYOR_SPEED = 6 -- studs per second the walkers travel
Config.BELT_MIN_X = -64
Config.BELT_MAX_X = 64
Config.BELT_Z = 0
Config.BELT_TOP_Y = 2
Config.SPAWN_INTERVAL = 7 -- seconds between walker spawns
Config.MAX_WALKERS = 10
Config.ACTION_RANGE = 40 -- studs: click / steal reach
Config.SELL_REFUND = 0.5 -- selling a snack returns half its price
Config.WAVE_INCOME_MULT = 2 -- income multiplier while a wave is active
Config.SAVE_VERSION = 1

-- ------------------------------------------------------------------ snacks
-- The 9 snack characters. `color` is a 0-255 RGB triple, `size` is the
-- approximate body diameter in studs.
export type SnackDef = {
	key: string,
	displayName: string,
	rarity: string,
	rate: number, -- cash per second while owned
	price: number, -- cash to buy from the belt
	color: { number },
	size: number,
}

Config.SNACKS = {
	{ key = "soggy_fry", displayName = "Soggy Fry", rarity = "Common", rate = 1, price = 50, color = { 255, 196, 66 }, size = 3.3 },
	{ key = "noodle_ned", displayName = "Noodle Ned", rarity = "Common", rate = 2, price = 100, color = { 255, 214, 130 }, size = 3.6 },
	{ key = "dancing_dumpling", displayName = "Dancing Dumpling", rarity = "Rare", rate = 5, price = 300, color = { 255, 240, 200 }, size = 3.9 },
	{ key = "turbo_taco", displayName = "Turbo Taco", rarity = "Rare", rate = 8, price = 500, color = { 255, 170, 40 }, size = 4.2 },
	{ key = "lord_lasagna", displayName = "Lord Lasagna", rarity = "Epic", rate = 15, price = 1500, color = { 230, 120, 60 }, size = 4.5 },
	{ key = "queen_queso", displayName = "Queen Queso", rarity = "Epic", rate = 20, price = 2500, color = { 255, 215, 0 }, size = 4.8 },
	{ key = "king_kebab", displayName = "King Kebab", rarity = "Legendary", rate = 40, price = 6000, color = { 180, 60, 60 }, size = 5.1 },
	{ key = "baron_burger", displayName = "Baron Burger", rarity = "Legendary", rate = 60, price = 10000, color = { 150, 90, 40 }, size = 5.4 },
	{ key = "eternal_ramen", displayName = "The Eternal Ramen", rarity = "Mythic", rate = 120, price = 25000, color = { 255, 80, 80 }, size = 6.0 },
} :: { SnackDef }

Config.RARITY_COLORS = {
	Common = { 180, 180, 180 },
	Rare = { 80, 170, 255 },
	Epic = { 180, 90, 255 },
	Legendary = { 255, 170, 0 },
	Mythic = { 255, 60, 120 },
} :: { [string]: { number } }

-- Spawn weights per rarity (out of 100).
Config.RARITY_WEIGHTS = {
	Common = 46,
	Rare = 28,
	Epic = 15,
	Legendary = 8,
	Mythic = 3,
} :: { [string]: number }

-- Rarity roll order used by pickRarity.
Config.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic" } :: { string }

export type VariantDef = {
	name: string,
	mult: number, -- income multiplier
	chance: number, -- cumulative upper bound of a 0..1 roll
}

-- Rolled in order; the first entry whose `chance` covers the roll wins.
Config.VARIANTS = {
	{ name = "Rainbow", mult = 10, chance = 0.01 },
	{ name = "Diamond", mult = 5, chance = 0.06 },
	{ name = "Golden", mult = 2, chance = 0.21 },
	{ name = "None", mult = 1, chance = 1.0 },
} :: { VariantDef }

Config.WEATHERS = { "Sunny", "Rain", "Storm", "Fog", "Snow" } :: { string }

-- Base platform centres (top of each platform is y = 1). Four platforms
-- north of the belt (z = -22) and four south (z = 22).
Config.BASE_CENTERS = {
	Vector3.new(-54, 1, -22),
	Vector3.new(-18, 1, -22),
	Vector3.new(18, 1, -22),
	Vector3.new(54, 1, -22),
	Vector3.new(-54, 1, 22),
	Vector3.new(-18, 1, 22),
	Vector3.new(18, 1, 22),
	Vector3.new(54, 1, 22),
} :: { Vector3 }

-- ------------------------------------------------------------------ lookups
function Config.lookupSnack(snackKey: string): SnackDef?
	for _, def in ipairs(Config.SNACKS) do
		if def.key == snackKey then
			return def
		end
	end
	return nil
end

function Config.snacksOfRarity(rarity: string): { SnackDef }
	local out = {}
	for _, def in ipairs(Config.SNACKS) do
		if def.rarity == rarity then
			table.insert(out, def)
		end
	end
	return out
end

function Config.rarityColor(rarity: string): { number }
	local c = Config.RARITY_COLORS[rarity]
	if c then
		return c
	end
	return { 180, 180, 180 }
end

function Config.variantFor(variantName: string): VariantDef
	for _, v in ipairs(Config.VARIANTS) do
		if v.name == variantName then
			return v
		end
	end
	return Config.VARIANTS[4] -- "None"
end

-- ------------------------------------------------------------------ rolls
-- Deterministic, testable rolls: pass a number in [0, 1).
-- pickRarity: weights Common 46 / Rare 28 / Epic 15 / Legendary 8 / Mythic 3.
function Config.pickRarity(roll: number): string
	local acc = 0
	for _, rarity in ipairs(Config.RARITY_ORDER) do
		acc += Config.RARITY_WEIGHTS[rarity]
		if roll * 100 < acc then
			return rarity
		end
	end
	return "Mythic"
end

-- pickVariant: Rainbow 1% / Diamond 5% / Golden 15% / None otherwise.
function Config.pickVariant(roll: number): VariantDef
	for _, v in ipairs(Config.VARIANTS) do
		if roll < v.chance then
			return v
		end
	end
	return Config.VARIANTS[4]
end

-- Pick a random snack of a given rarity using a 0..1 roll.
function Config.pickSnackOfRarity(rarity: string, roll: number): SnackDef
	local pool = Config.snacksOfRarity(rarity)
	local index = math.floor(roll * #pool) + 1
	if index > #pool then
		index = #pool
	end
	return pool[index]
end

-- ------------------------------------------------------------------ economy
-- Rebirth cost grows with each rebirth: base * (rebirths + 1).
function Config.rebirthPrice(rebirths: number): number
	return Config.REBIRTH_BASE_COST * (rebirths + 1)
end

-- Permanent income multiplier from rebirths: 1 + 0.25 per rebirth.
function Config.incomeBoost(rebirths: number): number
	return 1 + rebirths * Config.REBIRTH_MULTIPLIER_STEP
end

return Config
