-- Steal a Snack v2 — headless tests.
-- Run: tests/run.sh  (assembles mock + real sources into one chunk, then
-- runs it with the luau interpreter). The assembled modules are provided
-- by tests/assemble.py, so there are no require lines here: Config,
-- CharacterFactory, Weather and the mock globals are already in scope.

local passed = 0
local failed = 0
local failures = {}

local function check(name, ok, detail)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		table.insert(failures, name .. (detail and (" — " .. tostring(detail)) or ""))
		print("FAIL " .. name .. (detail and (" — " .. tostring(detail)) or ""))
	end
end

local function approx(a, b)
	return math.abs(a - b) < 0.001
end

-- ------------------------------------------------------------------ Config
check("config: 9 snacks", #Config.SNACKS == 9, "got " .. tostring(#Config.SNACKS))

local expected = {
	soggy_fry = { "Common", 1, 50, 3.3, { 255, 196, 66 } },
	noodle_ned = { "Common", 2, 100, 3.6, { 255, 214, 130 } },
	dancing_dumpling = { "Rare", 5, 300, 3.9, { 255, 240, 200 } },
	turbo_taco = { "Rare", 8, 500, 4.2, { 255, 170, 40 } },
	lord_lasagna = { "Epic", 15, 1500, 4.5, { 230, 120, 60 } },
	queen_queso = { "Epic", 20, 2500, 4.8, { 255, 215, 0 } },
	king_kebab = { "Legendary", 40, 6000, 5.1, { 180, 60, 60 } },
	baron_burger = { "Legendary", 60, 10000, 5.4, { 150, 90, 40 } },
	eternal_ramen = { "Mythic", 120, 25000, 6.0, { 255, 80, 80 } },
}
local seenKeys = {}
for _, def in ipairs(Config.SNACKS) do
	local exp = expected[def.key]
	check("config: snack " .. def.key .. " exists in spec", exp ~= nil)
	if exp then
		check("config: " .. def.key .. " rarity", def.rarity == exp[1], def.rarity)
		check("config: " .. def.key .. " rate", def.rate == exp[2], tostring(def.rate))
		check("config: " .. def.key .. " price", def.price == exp[3], tostring(def.price))
		check("config: " .. def.key .. " size", approx(def.size, exp[4]), tostring(def.size))
		check(
			"config: " .. def.key .. " color",
			def.color[1] == exp[5][1] and def.color[2] == exp[5][2] and def.color[3] == exp[5][3],
			table.concat(def.color, ",")
		)
	end
	check("config: key unique " .. def.key, seenKeys[def.key] == nil)
	seenKeys[def.key] = true
	check("config: lookup " .. def.key, Config.lookupSnack(def.key) == def)
end
check("config: lookup unknown -> nil", Config.lookupSnack("nope") == nil)

local weightSum = 0
for _, w in pairs(Config.RARITY_WEIGHTS) do
	weightSum += w
end
check("config: rarity weights sum to 100", weightSum == 100, tostring(weightSum))

-- Rarity roll boundaries (weights 46/28/15/8/3).
local rarityCases = {
	{ 0.0, "Common" },
	{ 0.459, "Common" },
	{ 0.46, "Rare" },
	{ 0.739, "Rare" },
	{ 0.74, "Epic" },
	{ 0.889, "Epic" },
	{ 0.89, "Legendary" },
	{ 0.969, "Legendary" },
	{ 0.97, "Mythic" },
	{ 0.999, "Mythic" },
}
for _, c in ipairs(rarityCases) do
	check("config: pickRarity " .. tostring(c[1]), Config.pickRarity(c[1]) == c[2], Config.pickRarity(c[1]))
end

-- Mutation roll boundaries (Rainbow 1% / Diamond 5% / Golden 15% / None).
local variantCases = {
	{ 0.0, "Rainbow", 10 },
	{ 0.009, "Rainbow", 10 },
	{ 0.01, "Diamond", 5 },
	{ 0.059, "Diamond", 5 },
	{ 0.06, "Golden", 2 },
	{ 0.20, "Golden", 2 },
	{ 0.21, "None", 1 },
	{ 0.99, "None", 1 },
}
for _, c in ipairs(variantCases) do
	local v = Config.pickVariant(c[1])
	check("config: pickVariant " .. tostring(c[1]) .. " name", v.name == c[2], v.name)
	check("config: pickVariant " .. tostring(c[1]) .. " mult", v.mult == c[3], tostring(v.mult))
end
check("config: variantFor Golden mult", Config.variantFor("Golden").mult == 2)
check("config: variantFor unknown -> None", Config.variantFor("???").name == "None")

-- Economy helpers.
check("config: rebirthPrice 0", Config.rebirthPrice(0) == 25000)
check("config: rebirthPrice 1", Config.rebirthPrice(1) == 50000)
check("config: rebirthPrice 3", Config.rebirthPrice(3) == 100000)
check("config: incomeBoost 0", approx(Config.incomeBoost(0), 1))
check("config: incomeBoost 1", approx(Config.incomeBoost(1), 1.25))
check("config: incomeBoost 4", approx(Config.incomeBoost(4), 2))

-- Constants.
check("config: START_CASH 100", Config.START_CASH == 100)
check("config: MAX_SLOTS_PER_BASE 6", Config.MAX_SLOTS_PER_BASE == 6)
check("config: MAX_BASES 8", Config.MAX_BASES == 8)
check("config: LOCK_DURATION 20", Config.LOCK_DURATION == 20)
check("config: LOCK_COOLDOWN 60", Config.LOCK_COOLDOWN == 60)
check("config: STEAL_COOLDOWN 5", Config.STEAL_COOLDOWN == 5)
check("config: WAVE_PERIOD 90", Config.WAVE_PERIOD == 90)
check("config: WAVE_WARN 10", Config.WAVE_WARN == 10)
check("config: WAVE_DURATION 10", Config.WAVE_DURATION == 10)
check("config: BELT_MIN_X -64", Config.BELT_MIN_X == -64)
check("config: BELT_MAX_X 64", Config.BELT_MAX_X == 64)
check("config: BELT_TOP_Y 2", Config.BELT_TOP_Y == 2)
check("config: SPAWN_INTERVAL 7", Config.SPAWN_INTERVAL == 7)
check("config: MAX_WALKERS 10", Config.MAX_WALKERS == 10)
check("config: ACTION_RANGE 40", Config.ACTION_RANGE == 40)
check("config: 8 base centres", #Config.BASE_CENTERS == 8)
local centreSeen = {}
local centresDistinct = true
for _, c in ipairs(Config.BASE_CENTERS) do
	local k = tostring(c.X) .. "," .. tostring(c.Z)
	if centreSeen[k] then
		centresDistinct = false
	end
	centreSeen[k] = true
end
check("config: base centres distinct", centresDistinct)
check("config: 5 weathers", #Config.WEATHERS == 5)
check("config: weathers include Sunny first", Config.WEATHERS[1] == "Sunny")

-- ------------------------------------------------------- CharacterFactory
local world = Instance.new("Folder")
world.Name = "World"

for _, def in ipairs(Config.SNACKS) do
	local ground = Vector3.new(10, 2, -5)
	local model = CharacterFactory.buildSnack(def, "None", ground, 0, world)
	check("factory: " .. def.key .. " builds", model ~= nil)
	check("factory: " .. def.key .. " PrimaryPart set", model.PrimaryPart ~= nil)
	local root = model.PrimaryPart
	check("factory: " .. def.key .. " root invisible", root.Transparency == 1, tostring(root.Transparency))
	check("factory: " .. def.key .. " root anchored", root.Anchored == true)
	check(
		"factory: " .. def.key .. " root at ground point",
		math.abs(root.Position.X - ground.X) < 0.05
			and math.abs(root.Position.Y - ground.Y) < 0.05
			and math.abs(root.Position.Z - ground.Z) < 0.05
	)
	local parts = CharacterFactory.countParts(model)
	check("factory: " .. def.key .. " part count <= 60", parts <= 60, tostring(parts))
	check("factory: " .. def.key .. " part count >= 8", parts >= 8, tostring(parts))
	-- Every part sits on or above the ground point.
	-- NOTE: for a Cylinder, Size.Y is the DIAMETER, not the vertical
	-- extent — the length rides on Size.X. The vertical half-extent is
	-- min(Size.X, Size.Y)/2, exact for an upright cylinder whose length
	-- is the smaller side (discs, bowls, buns) and a safe under-estimate
	-- for a long thin one (the skewer: its true bottom is the ground).
	local allAbove = true
	local lowest = 1e9
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local halfY = d.Size.Y / 2
			if d.Shape == Enum.PartType.Cylinder then
				halfY = math.min(d.Size.X, d.Size.Y) / 2
			end
			local bottom = d.Position.Y - halfY
			if bottom < lowest then
				lowest = bottom
			end
			if bottom < ground.Y - 0.01 then
				allAbove = false
			end
		end
	end
	check("factory: " .. def.key .. " all parts on/above ground", allAbove, "lowest bottom=" .. tostring(lowest))
	-- Face points along forward (+Z when heading is 0).
	local eyeL = model:FindFirstChild("EyeL")
	local eyeR = model:FindFirstChild("EyeR")
	check("factory: " .. def.key .. " has eyes", eyeL ~= nil and eyeR ~= nil)
	if eyeL and eyeR then
		check("factory: " .. def.key .. " face forward (+Z)", eyeL.Position.Z > ground.Z and eyeR.Position.Z > ground.Z)
	end
	check("factory: " .. def.key .. " has disc", model:FindFirstChild("Disc") ~= nil)
	check("factory: " .. def.key .. " has caption", model:FindFirstChild("Caption") ~= nil)
	check("factory: " .. def.key .. " tag SnackKey", model:GetAttribute("SnackKey") == def.key)
	check("factory: " .. def.key .. " tag Variant", model:GetAttribute("Variant") == "None")
	-- FOOD-FIRST: no generic humanoid core anywhere.
	check("factory: " .. def.key .. " no Head", model:FindFirstChild("Head") == nil)
	check("factory: " .. def.key .. " no ArmL", model:FindFirstChild("ArmL") == nil)
	check("factory: " .. def.key .. " no LegL", model:FindFirstChild("LegL") == nil)
	check("factory: " .. def.key .. " no ShoeL", model:FindFirstChild("ShoeL") == nil)
	-- The food IS the body: a part named "Body" is the main mass.
	local bodyPart = model:FindFirstChild("Body")
	check("factory: " .. def.key .. " has Body (food mass)", bodyPart ~= nil)
	-- Signature food part per snack.
	local signature = {
		soggy_fry = "FryStick1",
		noodle_ned = "NoodleSwirl1",
		dancing_dumpling = "Pleat1",
		turbo_taco = "Lettuce1",
		lord_lasagna = "SauceLayer",
		queen_queso = "CheeseHole1",
		king_kebab = "Skewer",
		baron_burger = "Sesame1",
		eternal_ramen = "Egg",
	}
	local sig = signature[def.key]
	if sig then
		check("factory: " .. def.key .. " signature part " .. sig, model:FindFirstChild(sig) ~= nil)
	end
	-- Queen Queso's body must be YELLOW (cheese), never green.
	if def.key == "queen_queso" and bodyPart ~= nil then
		local c = bodyPart.Color
		check("factory: queen_queso Body is yellow", c.R > 0.8 and c.G > 0.7 and c.B < 0.3, tostring(c.R) .. "," .. tostring(c.G) .. "," .. tostring(c.B))
	end
	-- FACE RELIEF (brown-box fix): the eye whites must be bold googly
	-- relief, not a thin decal. Old code protruded only ~0.015*s (eye
	-- whites ~0.05 studs, invisible at game distance / z-fighting); the
	-- new face sits ~0.05*s proud of the body front. Heading is 0 here,
	-- so forward is +Z: the eye front must clear the Body front.
	if eyeL ~= nil and bodyPart ~= nil then
		local eyeFront = eyeL.Position.Z + eyeL.Size.Z / 2
		local bodyFront = bodyPart.Position.Z + bodyPart.Size.Z / 2
		local protrusion = eyeFront - bodyFront
		-- Lasagna's face sits on the pasta layer, but the cheese-top
		-- Body overhangs it by 0.025u, so its bar is lower.
		local bar = 0.03 * def.size
		if def.key == "lord_lasagna" then
			bar = 0.015 * def.size
		end
		check("factory: " .. def.key .. " eye protrudes past body", protrusion >= bar, "protrusion=" .. tostring(protrusion) .. " bar=" .. tostring(bar))
		check("factory: " .. def.key .. " eye is deep (googly, not decal)", eyeL.Size.Z >= 0.10 * def.size, "eyeZ=" .. tostring(eyeL.Size.Z))
	end
	-- RARITY DISC is a ROUND cylinder (radius 0.85u, height 0.06u),
	-- like the preview — not the old square box that read as a flat
	-- "pink platform".
	local disc = model:FindFirstChild("Disc")
	if disc ~= nil then
		check("factory: " .. def.key .. " disc is a cylinder", disc.Shape == Enum.PartType.Cylinder)
		check("factory: " .. def.key .. " disc height 0.06u", math.abs(disc.Size.X - 0.06 * def.size) < 0.01, "discX=" .. tostring(disc.Size.X))
		check("factory: " .. def.key .. " disc diameter 1.70u", math.abs(disc.Size.Y - 1.70 * def.size) < 0.01, "discY=" .. tostring(disc.Size.Y))
	end
end

-- CYLINDER U-SCALE (brown-box fix): addCyl used to build cylinders at
-- 0.05-1.45 STUDS instead of 0.05u-1.45u, so bowls/buns were microscopic
-- in Roblox while the preview showed them u-scaled. Assert the real
-- u-scaled sizes.
local ramenDef = Config.lookupSnack("eternal_ramen")
local ramenModel = CharacterFactory.buildSnack(ramenDef, "None", Vector3.new(0, 2, 0), 0, world)
local ramenBody = ramenModel:FindFirstChild("Body")
check("factory: ramen bowl length 0.60u", ramenBody ~= nil and math.abs(ramenBody.Size.X - 0.60 * ramenDef.size) < 0.01, ramenBody and tostring(ramenBody.Size.X) or "no body")
check("factory: ramen bowl diameter 1.05u", ramenBody ~= nil and math.abs(ramenBody.Size.Y - 1.05 * ramenDef.size) < 0.01, ramenBody and tostring(ramenBody.Size.Y) or "no body")
local burgerDef = Config.lookupSnack("baron_burger")
local burgerModel = CharacterFactory.buildSnack(burgerDef, "None", Vector3.new(0, 2, 0), 0, world)
local patty = burgerModel:FindFirstChild("Patty")
check("factory: burger patty diameter 1.00u", patty ~= nil and math.abs(patty.Size.Y - 1.00 * burgerDef.size) < 0.01, patty and tostring(patty.Size.Y) or "no patty")
local kebabDef = Config.lookupSnack("king_kebab")
local kebabModel = CharacterFactory.buildSnack(kebabDef, "None", Vector3.new(0, 2, 0), 0, world)
local skewer = kebabModel:FindFirstChild("Skewer")
check("factory: kebab skewer length 1.45u", skewer ~= nil and math.abs(skewer.Size.X - 1.45 * kebabDef.size) < 0.01, skewer and tostring(skewer.Size.X) or "no skewer")

-- Heading: with heading PI/2 the face should point along +X.
local ramen = Config.lookupSnack("eternal_ramen")
local turned = CharacterFactory.buildSnack(ramen, "None", Vector3.new(0, 2, 0), math.pi / 2, world)
local turnedEye = turned:FindFirstChild("EyeL")
check("factory: heading PI/2 face points +X", turnedEye ~= nil and turnedEye.Position.X > 0, turnedEye and tostring(turnedEye.Position.X) or "no eye")

-- Variants build and tint the body.
for _, variant in ipairs({ "Golden", "Diamond", "Rainbow" }) do
	local m = CharacterFactory.buildSnack(ramen, variant, Vector3.new(0, 2, 0), 0, world)
	check("factory: variant " .. variant .. " builds", m ~= nil and CharacterFactory.countParts(m) <= 60)
	check("factory: variant " .. variant .. " tagged", m:GetAttribute("Variant") == variant)
end

-- Click wiring + caption rewrite.
local fry = Config.lookupSnack("soggy_fry")
local clickModel = CharacterFactory.buildSnack(fry, "None", Vector3.new(0, 2, 0), 0, world)
local clickedWith = nil
local detector = CharacterFactory.attachClick(clickModel, 40, function(p)
	clickedWith = p
end)
check("factory: attachClick returns detector", detector ~= nil and detector.ClassName == "ClickDetector")
check("factory: click reach 40", detector.MaxActivationDistance == 40)
check("factory: detector parented to Body", detector.Parent == clickModel:FindFirstChild("Body"))
if detector._clickCb then
	detector._clickCb("FakePlayer")
	check("factory: click handler fires", clickedWith == "FakePlayer")
else
	check("factory: click handler fires", false, "no stored callback in mock")
end
CharacterFactory.setCaption(clickModel, "Hello", "$5/s")
local board = clickModel:FindFirstChild("Caption")
local nameLine = board and board:FindFirstChild("NameLine")
local infoLine = board and board:FindFirstChild("InfoLine")
check("factory: setCaption line1", nameLine ~= nil and nameLine.Text == "Hello")
check("factory: setCaption line2", infoLine ~= nil and infoLine.Text == "$5/s")

-- Label stagger: labelTier 0/1/2 lifts the caption by 0/1.6/3.2 studs,
-- so walkers bunched up on the belt keep readable labels.
local function captionY(tier)
	local m = CharacterFactory.buildSnack(fry, "None", Vector3.new(0, 2, 0), 0, world, tier)
	local b = m:FindFirstChild("Caption")
	return b ~= nil and b.StudsOffsetWorldSpace.Y or -1
end
local y0 = captionY(0)
local y1 = captionY(1)
local y2 = captionY(2)
check("factory: labelTier 0 baseline", y0 > 0, tostring(y0))
check("factory: labelTier 1 is +1.6", approx(y1 - y0, 1.6), tostring(y1 - y0))
check("factory: labelTier 2 is +3.2", approx(y2 - y0, 3.2), tostring(y2 - y0))
check("factory: labelTier omitted is tier 0", approx(captionY(nil) - y0, 0))

-- ------------------------------------------------------------------ Weather
check("weather: 5 settings", Weather.SETTINGS.Sunny ~= nil and Weather.SETTINGS.Rain ~= nil and Weather.SETTINGS.Storm ~= nil and Weather.SETTINGS.Fog ~= nil and Weather.SETTINGS.Snow ~= nil)
check("weather: Sunny brightness 2.6", Weather.settingsFor("Sunny").brightness == 2.6)
check("weather: Storm brightness 1.1", approx(Weather.settingsFor("Storm").brightness, 1.1))
check("weather: Fog fogEnd 160", Weather.settingsFor("Fog").fogEnd == 160)
check("weather: Rain fogEnd 500", Weather.settingsFor("Rain").fogEnd == 500)
check("weather: Snow clockTime 12", Weather.settingsFor("Snow").clockTime == 12)
check("weather: unknown falls back to Sunny", Weather.settingsFor("???").brightness == 2.6)
check("weather: current starts Sunny", Weather.current() == "Sunny")

-- applyTo pushes values onto a Lighting-like table.
local fakeLighting = {
	Brightness = 0,
	ClockTime = 0,
	Ambient = nil,
	OutdoorAmbient = nil,
	FogEnd = 0,
	FindFirstChild = function(_self, _name)
		return nil
	end,
}
Weather.applyTo(fakeLighting, "Storm")
check("weather: applyTo Storm brightness", approx(fakeLighting.Brightness, 1.1))
check("weather: applyTo Storm fogEnd", fakeLighting.FogEnd == 260)
check("weather: applyTo Storm clockTime", fakeLighting.ClockTime == 17.5)
check("weather: current after applyTo", Weather.current() == "Storm")

-- ------------------------------------------------------------------- Bases
-- Environment build (Bases.build / buildBase) runs in the mock harness:
-- a mock Folder stands in for Workspace, so game:GetService is never hit.
local envWorld = Instance.new("Folder")
envWorld.Name = "Workspace"

local function countDesc(root, pred)
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if pred(d) then
			n += 1
		end
	end
	return n
end
local function hasDesc(root, name)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name then
			return true
		end
	end
	return false
end

-- Slot geometry contract unchanged.
check("bases: platformCenter base 1", Bases.platformCenter(1) == Config.BASE_CENTERS[1])
check("bases: slotWorldPos base 1 slot 1", Bases.slotWorldPos(1, 1) == Config.BASE_CENTERS[1] + Vector3.new(-6, 0, -3.5))
check("bases: slotWorldPos base 8 slot 6", Bases.slotWorldPos(8, 6) == Config.BASE_CENTERS[8] + Vector3.new(6, 0, 3.5))

-- One base: cool dressing present, floor top still y = 1.
local baseModel = Bases.buildBase(1, envWorld)
check("bases: buildBase returns Base1Env", baseModel ~= nil and baseModel.Name == "Base1Env")
check("bases: base has neon front glow", hasDesc(baseModel, "FrontGlow"))
check("bases: base has entrance arch bar", hasDesc(baseModel, "ArchBar"))
check("bases: base has arch posts", hasDesc(baseModel, "ArchPost-1") and hasDesc(baseModel, "ArchPost1"))
check("bases: base has arch orbs", hasDesc(baseModel, "ArchOrb-1"))
check("bases: base has wall crown", hasDesc(baseModel, "WallCrown"))
check("bases: base has pilaster caps", hasDesc(baseModel, "PilasterCap-1"))
check("bases: base has runner", hasDesc(baseModel, "Runner"))
check("bases: base has neon runner edges", hasDesc(baseModel, "RunnerEdge-1"))
local floorBoard = baseModel:FindFirstChild("FloorBoard1")
check("bases: floor top still y=1", floorBoard ~= nil and approx(floorBoard.Position.Y + 0.15, 1.0))
local frontGlow = nil
for _, d in ipairs(baseModel:GetDescendants()) do
	if d.Name == "FrontGlow" then
		frontGlow = d
	end
end
check("bases: front glow is Neon", frontGlow ~= nil and frontGlow.Material == Enum.Material.Neon)
-- Base SHAPE (not just trim): stepped gable peak, splayed wing walls,
-- and a pergola roof with slats — slots stay visible (back row sits in
-- a slat gap; front two-thirds fully open).
check("bases: base has gable peak", hasDesc(baseModel, "GableStep1") and hasDesc(baseModel, "GableStep3"))
check("bases: base has wing walls", hasDesc(baseModel, "WingWall-1") and hasDesc(baseModel, "WingWall1"))
check("bases: base has pergola roof", hasDesc(baseModel, "RoofSlat1") and hasDesc(baseModel, "RoofSlat3"))
check("bases: base has roof front beam", hasDesc(baseModel, "RoofBeamFront"))
check("bases: base has roof neon front", hasDesc(baseModel, "RoofNeonFront"))
check("bases: base has roof posts", hasDesc(baseModel, "RoofPost-1") and hasDesc(baseModel, "RoofPost1"))
check("bases: stall has canopy roof", hasDesc(baseModel, "StallCanopy"))

-- Full build: 8 bases + plaza lights + ground life.
local envFolder = Bases.build(envWorld)
check("bases: build returns BasesEnv folder", envFolder ~= nil and envFolder.Name == "BasesEnv")
check("bases: build parents folder to workspace", envFolder.Parent == envWorld)
check("bases: 8 base models", countDesc(envFolder, function(d) return d.ClassName == "Model" and string.sub(d.Name, 1, 4) == "Base" end) == 8)
check("bases: 6 plaza lamp posts", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 13) == "PlazaLampPole" end) == 6)
check("bases: 6 plaza lamp lights", countDesc(envFolder, function(d) return d.ClassName == "PointLight" and string.sub(d.Name, 1, 14) == "PlazaLampLight" end) == 6)
check("bases: string bulbs 28", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 10) == "StringBulb" end) == 28)
check("bases: string wires 32", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 10) == "StringWire" end) == 32)
check("bases: total PointLights <= 20", countDesc(envFolder, function(d) return d.ClassName == "PointLight" end) <= 20)
check("bases: 12 layered trees", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 9) == "TreeTrunk" end) == 12)
check("bases: fountain present", hasDesc(envFolder, "FountainBasin"))
check("bases: pond present", hasDesc(envFolder, "PondWater"))
check("bases: belt flower beds 4", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 13) == "BeltFlowerBed" end) == 4)
check("bases: rocks present", hasDesc(envFolder, "Rock1_1"))
check("bases: feature paths present", hasDesc(envFolder, "FountainPath1") and hasDesc(envFolder, "PondPath1"))
-- Belt unmissable: cream lane, gold Neon side edges, sign gates, grass
-- chevrons, cobble promenade, round belt bushes (Balls, never Blocks).
check("bases: belt lane present", hasDesc(envFolder, "BeltLane"))
check("bases: belt neon edges", hasDesc(envFolder, "BeltEdgeNorth") and hasDesc(envFolder, "BeltEdgeSouth"))
check("bases: belt sign gates", hasDesc(envFolder, "BeltSignWest") and hasDesc(envFolder, "BeltSignEast"))
check("bases: belt arrows 10", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 9) == "BeltArrow" end) == 10)
check("bases: promenade panels 16", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 14) == "PromenadePanel" end) == 16)
check("bases: belt bushes 4", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 9) == "BeltBushA" end) == 4)
-- Carnival landmarks: ferris wheel (west) + tower (east), background.
check("bases: ferris wheel present", hasDesc(envFolder, "FerrisHub") and hasDesc(envFolder, "FerrisPlatform"))
check("bases: ferris rim 12", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 9) == "FerrisRim" end) == 12)
check("bases: ferris bulbs 12", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 10) == "FerrisBulb" end) == 12)
check("bases: ferris cabins 8", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 11) == "FerrisCabin" and string.find(d.Name, "Bulb") == nil end) == 8)
check("bases: tower present", hasDesc(envFolder, "TowerTier1") and hasDesc(envFolder, "TowerTier3"))
check("bases: tower trim 3", countDesc(envFolder, function(d) return string.sub(d.Name, 1, 9) == "TowerTrim" end) == 3)
check("bases: tower beacon present", hasDesc(envFolder, "TowerBeacon"))
-- Light budget: 6 plaza + 8 stall + 1 fountain + 1 tower beacon = 16.
check("bases: total PointLights 16", countDesc(envFolder, function(d) return d.ClassName == "PointLight" end) == 16)
-- Rebuild is idempotent (old folder destroyed, one folder left).
local envFolder2 = Bases.build(envWorld)
check("bases: rebuild idempotent", envFolder2 ~= nil and countDesc(envWorld, function(d) return d.Name == "BasesEnv" end) == 1)

-- ------------------------------------------------------------------- result
print("--------------------------------------------------")
print("RESULT: passed=" .. tostring(passed) .. " failed=" .. tostring(failed))
if failed > 0 then
	print("FAILURES:")
	for _, f in ipairs(failures) do
		print("  - " .. f)
	end
end
