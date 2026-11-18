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
	local allAbove = true
	local lowest = 1e9
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local bottom = d.Position.Y - d.Size.Y / 2
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
end

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
check("factory: detector parented to root", detector.Parent == clickModel.PrimaryPart)
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

-- ------------------------------------------------------------------- result
print("--------------------------------------------------")
print("RESULT: passed=" .. tostring(passed) .. " failed=" .. tostring(failed))
if failed > 0 then
	print("FAILURES:")
	for _, f in ipairs(failures) do
		print("  - " .. f)
	end
end
