--!strict
-- Steal a Snack v2 — CharacterFactory (FOOD-FIRST rebuild).
-- The food IS the body: each snack's main mass and silhouette is the food
-- itself (fry box, noodle bowl, dumpling, taco shell, lasagna stack,
-- cheese wedge, kebab skewer, burger stack, ramen bowl). The face sits ON
-- the food's front surface. There is NO generic humanoid core — no head,
-- no arms, no legs, no shoes — so every character reads as its snack at
-- game distance, the way the genre (Steal a Brainrot) does it. Food
-- colours are the food's own true colours (cheese is YELLOW).
--
-- PUBLIC API (contract — signatures kept exactly):
--   buildSnack(def, variantName, groundPos, headingRad, parent) -> Model
--   attachClick(model, reach, handler) -> ClickDetector
--   setCaption(model, line1, line2) -> ()
--   countParts(model) -> number
--
-- Guarantees: PrimaryPart is an invisible anchored Root plate whose
-- bottom sits exactly on groundPos; every part Anchored + CanCollide
-- false; no part dips below groundPos.Y; rarity Neon Disc (0.35
-- transparency) under the feet; BillboardGui "Caption" with NameLine +
-- InfoLine, adored by the part named "Body" (the food's main mass);
-- attributes SnackKey / Variant / Rarity; <= 60 parts/snack.
--
-- Geometry note: all offsets are in units of `u = def.size` (the food
-- diameter), so every snack scales cleanly from 3.3 (Fry) to 6.0 (Ramen).
-- Heading: forward = (sin h, 0, cos h), right = (cos h, 0, -sin h);
-- the face sits on the +forward side. The face is parameterized by its
-- centre (fwd = front-surface depth at eye height, up = eye-line height)
-- and scale s; its local pattern is measured from that centre, so it
-- lands on any food front.

local CharacterFactory = {}

export type SnackDef = {
	key: string,
	displayName: string,
	rarity: string,
	rate: number,
	price: number,
	color: { number },
	size: number,
}

-- Rarity tint for the ground disc + chest gem (0-255 RGB, mirrors
-- Config.RARITY_COLORS). Never used as a body colour.
local RARITY_TINT = {
	Common = { 180, 180, 180 },
	Rare = { 80, 170, 255 },
	Epic = { 180, 90, 255 },
	Legendary = { 255, 170, 0 },
	Mythic = { 255, 60, 120 },
}

-- TRUE food colour of the main mass, per snack (0-255 RGB). This is the
-- colour the variant tint applies to; the face skin is this colour too.
-- Cheese is yellow, the fry box is red, the bowls are red lacquer — the
-- food's own colour, never the old humanoid body colour.
local FOOD_COLOR = {
	soggy_fry = { 210, 40, 40 },
	noodle_ned = { 205, 60, 55 },
	dancing_dumpling = { 255, 240, 200 },
	turbo_taco = { 235, 160, 40 },
	lord_lasagna = { 245, 200, 70 },
	queen_queso = { 255, 215, 0 },
	king_kebab = { 165, 90, 55 },
	baron_burger = { 215, 155, 80 },
	eternal_ramen = { 160, 40, 40 },
}

-- Iris colour per snack (the food's own accent, not the rarity colour).
local IRIS_COLOR = {
	soggy_fry = { 90, 55, 20 },
	noodle_ned = { 70, 45, 25 },
	dancing_dumpling = { 40, 80, 160 },
	turbo_taco = { 50, 120, 50 },
	lord_lasagna = { 110, 60, 20 },
	queen_queso = { 120, 60, 160 },
	king_kebab = { 170, 110, 20 },
	baron_burger = { 80, 50, 25 },
	eternal_ramen = { 160, 40, 30 },
}

-- Mouth style per snack: "smile" (default), "smirk" (Taco),
-- "open" (Dumpling: open mouth + tongue).
local MOUTH_STYLE = {
	dancing_dumpling = "open",
	turbo_taco = "smirk",
}

-- ------------------------------------------------------------------ colour
local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

-- Shade a Color3: f > 0 lightens toward white, f < 0 darkens toward
-- black. The 3-step ramp per part is hi (f = +0.28) / mid (0) / lo
-- (f = -0.30); whites are capped at 235, blacks lifted to >= 25.
local function shade(c: Color3, f: number): Color3
	local function adj(v: number): number
		local out: number
		if f >= 0 then
			out = v + (1 - v) * f
		else
			out = v * (1 + f)
		end
		return math.floor(math.clamp(out * 255, 25, 235) + 0.5)
	end
	return Color3.fromRGB(adj(c.R), adj(c.G), adj(c.B))
end

local function lighten(triple: { number }, amount: number): Color3
	local function lift(v: number): number
		return math.min(235, math.floor(v + (255 - v) * amount))
	end
	return Color3.fromRGB(lift(triple[1]), lift(triple[2]), lift(triple[3]))
end

-- Material by name, falling back to SmoothPlastic when the name is not
-- in the runtime's Enum (the headless mock only ships a subset).
-- Materials follow roblox-realism: Fabric for cloth / bread / dough,
-- Metal for crowns / skewers, SmoothPlastic only for glossy food,
-- Neon only for emitters (disc + gem).
local function mat(name: string): Enum.Material
	local m = (Enum.Material :: any)[name]
	if m ~= nil then
		return m
	end
	return Enum.Material.SmoothPlastic
end

-- Position a point relative to the ground point using heading vectors.
-- forward = (sin h, 0, cos h); right = (cos h, 0, -sin h).
local function at(groundPos: Vector3, headingRad: number, fwd: number, up: number, right: number): Vector3
	local s = math.sin(headingRad)
	local c = math.cos(headingRad)
	return groundPos
		+ Vector3.new(s, 0, c) * fwd
		+ Vector3.new(0, 1, 0) * up
		+ Vector3.new(c, 0, -s) * right
end

-- One part, fully dressed. `rot` is {rx, ry, rz} applied after the
-- heading yaw, so a cylinder can be aimed along the limb it belongs to.
-- The CFrame keeps the given position exactly (rotation is about the
-- part's own centre), so the ground check (Position.Y - Size.Y/2) is
-- governed by the position we pass, never by the rotation.
local function addPart(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	position: Vector3,
	headingRad: number,
	rx: number,
	ry: number,
	rz: number
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.Material = material
	-- Set Position explicitly as well as CFrame: the headless mock's
	-- CFrame does not drive Position, and the tests read Position.
	part.Position = position
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, headingRad, 0) * CFrame.Angles(rx, ry, rz)
	part.Parent = model
	return part
end

local function addBall(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	position: Vector3,
	headingRad: number,
	rx: number,
	ry: number,
	rz: number
): Part
	return addPart(model, name, Enum.PartType.Ball, size, color, material, transparency, position, headingRad, rx, ry, rz)
end

local function addBox(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	position: Vector3,
	headingRad: number,
	rx: number,
	ry: number,
	rz: number
): Part
	return addPart(model, name, Enum.PartType.Block, size, color, material, transparency, position, headingRad, rx, ry, rz)
end

-- Cylinder: Roblox cylinders run along X. axis "Y" stands it upright,
-- axis "Z" points it forward; extra tilt rides on top.
local function addCyl(
	model: Model,
	name: string,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	position: Vector3,
	headingRad: number,
	axis: string,
	tilt: number
): Part
	local size = Vector3.new(length, diameter, diameter)
	if axis == "Y" then
		return addPart(model, name, Enum.PartType.Cylinder, size, color, material, transparency, position, headingRad, 0, 0, math.pi / 2 + tilt)
	elseif axis == "Z" then
		return addPart(model, name, Enum.PartType.Cylinder, size, color, material, transparency, position, headingRad, 0, -math.pi / 2 + tilt, 0)
	else
		return addPart(model, name, Enum.PartType.Cylinder, size, color, material, transparency, position, headingRad, 0, 0, tilt)
	end
end

-- ------------------------------------------------------------------ build context
type Ctx = {
	model: Model,
	def: SnackDef,
	u: number, -- def.size: every offset is a multiple of this
	groundPos: Vector3,
	heading: number,
	body: Color3, -- variant-tinted main-mass (food) colour
	bodyHi: Color3,
	bodyLo: Color3,
	bodyTransp: number,
	rarity: Color3,
	iris: Color3,
}

local function makeCtx(
	model: Model,
	def: SnackDef,
	variantName: string,
	groundPos: Vector3,
	headingRad: number
): Ctx
	local foodTriple = FOOD_COLOR[def.key] or def.color
	local bodyColor: Color3 = rgb(foodTriple)
	local bodyTransparency = 0
	if variantName == "Golden" then
		bodyColor = lighten(foodTriple, 0.45)
	elseif variantName == "Diamond" then
		bodyColor = Color3.fromRGB(185, 225, 255)
		bodyTransparency = 0.25
	elseif variantName == "Rainbow" then
		bodyColor = Color3.fromRGB(255, 90, 200)
	end
	local tint = RARITY_TINT[def.rarity] or RARITY_TINT.Common
	local irisTriple = IRIS_COLOR[def.key] or { 80, 50, 25 }
	return {
		model = model,
		def = def,
		u = def.size,
		groundPos = groundPos,
		heading = headingRad,
		body = bodyColor,
		bodyHi = shade(bodyColor, 0.28),
		bodyLo = shade(bodyColor, -0.30),
		bodyTransp = bodyTransparency,
		rarity = rgb(tint),
		iris = rgb(irisTriple),
	}
end

-- Shortcuts: position helpers bound to this snack's ground + heading.
local function P(ctx: Ctx, fwd: number, up: number, right: number): Vector3
	return at(ctx.groundPos, ctx.heading, fwd * ctx.u, up * ctx.u, right * ctx.u)
end

local function S(ctx: Ctx, x: number, y: number, z: number): Vector3
	return Vector3.new(x * ctx.u, y * ctx.u, z * ctx.u)
end

-- ------------------------------------------------------------------ face
-- The face is a stepped relief measured from its centre (fwd = the food's
-- front-surface depth at eye height, up = the eye-line height, s = scale).
-- Local pattern (fwd/up/right, in u, before the s factor):
--   eyes: white at fwd -0.03, outline -0.005, iris +0.005, pupil +0.025,
--   glint +0.04 — each layer steps a touch further out, so the eye reads
--   even on a curved food front. Brows, nose, blush and mouth follow the
--   same centre. `skin` is the food-front colour (the lid and nose blend
--   into it); `skinLo` is its darker shade for the nose bridge.
local function addFace(ctx: Ctx, fwd: number, up: number, s: number, skin: Color3, skinLo: Color3)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	local transp = ctx.bodyTransp
	-- Tapered brows, thicker at the inner end; the left brow sits a touch
	-- higher than the right — asymmetry = life.
	addBall(model, "BrowL", S(ctx, 0.17 * s, 0.04 * s, 0.05 * s), Color3.fromRGB(60, 35, 20), fabric, 0, P(ctx, fwd - 0.01 * s, up + 0.21 * s, -0.20 * s), ctx.heading, 0, 0, 0.16)
	addBall(model, "BrowR", S(ctx, 0.17 * s, 0.04 * s, 0.05 * s), Color3.fromRGB(60, 35, 20), fabric, 0, P(ctx, fwd - 0.01 * s, up + 0.19 * s, 0.20 * s), ctx.heading, 0, 0, -0.08)
	for _, side in ipairs({ -1, 1 }) do
		local name = if side < 0 then "EyeL" else "EyeR"
		local x = side * 0.20 * s
		-- White: tall, almost straight-sided oval.
		addBall(model, name, S(ctx, 0.20 * s, 0.27 * s, 0.09 * s), Color3.fromRGB(235, 235, 230), plastic, 0, P(ctx, fwd - 0.03 * s, up + 0.05 * s, x), ctx.heading, 0, 0, 0)
		-- Dark outline ring, slightly larger than the iris, behind it.
		addBall(model, name .. "Outline", S(ctx, 0.15 * s, 0.21 * s, 0.04 * s), Color3.fromRGB(25, 25, 30), plastic, 0, P(ctx, fwd - 0.005 * s, up + 0.04 * s, x), ctx.heading, 0, 0, 0)
		-- Iris: tall oval with the food's own accent colour.
		addBall(model, name .. "Iris", S(ctx, 0.13 * s, 0.19 * s, 0.05 * s), ctx.iris, plastic, 0, P(ctx, fwd + 0.005 * s, up + 0.04 * s, x), ctx.heading, 0, 0, 0)
		-- Pupil.
		addBall(model, name .. "Pupil", S(ctx, 0.065 * s, 0.09 * s, 0.04 * s), Color3.fromRGB(20, 20, 25), plastic, 0, P(ctx, fwd + 0.025 * s, up + 0.04 * s, x), ctx.heading, 0, 0, 0)
		-- One highlight, upper-outer corner of the iris.
		addBall(model, name .. "Glint", S(ctx, 0.04 * s, 0.05 * s, 0.03 * s), Color3.fromRGB(235, 235, 235), plastic, 0, P(ctx, fwd + 0.04 * s, up + 0.10 * s, x + side * 0.035 * s), ctx.heading, 0, 0, 0)
		-- Upper lid: food colour, covering the top of the iris.
		addBall(model, name .. "Lid", S(ctx, 0.22 * s, 0.09 * s, 0.05 * s), skin, fabric, transp, P(ctx, fwd + 0.00 * s, up + 0.15 * s, x), ctx.heading, 0, 0, 0)
	end
	-- Modelled nose: a short bridge stepping out of the face, then a
	-- rounded tip — the side view gets real relief, no flat plate.
	addBox(model, "NoseBridge", S(ctx, 0.05 * s, 0.12 * s, 0.05 * s), skinLo, fabric, transp, P(ctx, fwd + 0.015 * s, up - 0.02 * s, 0), ctx.heading, 0, 0, 0)
	addBall(model, "NoseTip", S(ctx, 0.09 * s, 0.07 * s, 0.08 * s), skin, fabric, transp, P(ctx, fwd + 0.035 * s, up - 0.08 * s, 0), ctx.heading, 0, 0, 0)
	-- Blush: two soft rose cheek steps under the outer eye corners.
	for _, side in ipairs({ -1, 1 }) do
		addBall(
			model,
			if side < 0 then "BlushL" else "BlushR",
			S(ctx, 0.10 * s, 0.07 * s, 0.04 * s),
			Color3.fromRGB(235, 120, 130),
			plastic,
			0,
			P(ctx, fwd - 0.01 * s, up - 0.09 * s, side * 0.27 * s),
			ctx.heading,
			0,
			0,
			0
		)
	end
	-- Mouth, per character.
	local style = MOUTH_STYLE[ctx.def.key] or "smile"
	local mouthColor = Color3.fromRGB(90, 30, 30)
	if style == "open" then
		-- Open mouth: dark oval + pink tongue peeking out below.
		addBall(model, "Mouth", S(ctx, 0.16 * s, 0.12 * s, 0.05 * s), Color3.fromRGB(70, 20, 25), plastic, 0, P(ctx, fwd + 0.01 * s, up - 0.20 * s, 0), ctx.heading, 0, 0, 0)
		addBall(model, "Tongue", S(ctx, 0.09 * s, 0.06 * s, 0.04 * s), Color3.fromRGB(235, 120, 140), plastic, 0, P(ctx, fwd + 0.025 * s, up - 0.24 * s, 0), ctx.heading, 0, 0, 0)
	elseif style == "smirk" then
		-- Smirk: thin bar tilted up on one side, corners uneven.
		addBall(model, "Mouth", S(ctx, 0.15 * s, 0.035 * s, 0.04 * s), mouthColor, plastic, 0, P(ctx, fwd + 0.015 * s, up - 0.19 * s, 0), ctx.heading, 0, 0, 0.18)
		addBall(model, "MouthCornerL", S(ctx, 0.04 * s, 0.04 * s, 0.04 * s), mouthColor, plastic, 0, P(ctx, fwd + 0.01 * s, up - 0.16 * s, -0.085 * s), ctx.heading, 0, 0, 0)
		addBall(model, "MouthCornerR", S(ctx, 0.04 * s, 0.04 * s, 0.04 * s), mouthColor, plastic, 0, P(ctx, fwd + 0.01 * s, up - 0.21 * s, 0.085 * s), ctx.heading, 0, 0, 0)
	else
		-- Thin smile: centre bar + two corners lifted a touch.
		addBall(model, "Mouth", S(ctx, 0.15 * s, 0.035 * s, 0.04 * s), mouthColor, plastic, 0, P(ctx, fwd + 0.015 * s, up - 0.19 * s, 0), ctx.heading, 0, 0, 0)
		addBall(model, "MouthCornerL", S(ctx, 0.04 * s, 0.04 * s, 0.04 * s), mouthColor, plastic, 0, P(ctx, fwd + 0.01 * s, up - 0.175 * s, -0.085 * s), ctx.heading, 0, 0, 0)
		addBall(model, "MouthCornerR", S(ctx, 0.04 * s, 0.04 * s, 0.04 * s), mouthColor, plastic, 0, P(ctx, fwd + 0.01 * s, up - 0.175 * s, 0.085 * s), ctx.heading, 0, 0, 0)
	end
end

-- Small rarity gem on the food front, just below the face. The disc
-- carries the rarity colour too; the gem is the second read.
local function addGem(ctx: Ctx, fwd: number, up: number)
	addBall(ctx.model, "Gem", S(ctx, 0.10, 0.10, 0.06), ctx.rarity, mat("Neon"), 0, P(ctx, fwd, up, 0), ctx.heading, 0, 0, 0)
end

-- ------------------------------------------------------------------ food bodies
-- One builder per snack. The food IS the body: its main mass is the part
-- named "Body" (the caption billboard adores it). Each builder finishes
-- by placing the face on the food's front surface.

local function foodFry(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Red fry box — the body. Front at fwd 0.275.
	addBox(model, "Body", S(ctx, 0.85, 0.70, 0.55), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.35, 0), ctx.heading, 0, 0, 0)
	-- White stripe band around the lower box.
	addBox(model, "FryStripe", S(ctx, 0.87, 0.10, 0.57), Color3.fromRGB(240, 240, 235), fabric, 0, P(ctx, 0, 0.12, 0), ctx.heading, 0, 0, 0)
	-- Five yellow fries fanning out of the top.
	for i, x in ipairs({ -0.28, -0.14, 0, 0.14, 0.28 }) do
		local tilt = (i - 3) * 0.22
		addBox(model, "FryStick" .. tostring(i), S(ctx, 0.09, 0.55, 0.05), Color3.fromRGB(240, 210, 90), fabric, 0, P(ctx, 0, 0.95, x), ctx.heading, 0, 0, tilt)
	end
	-- Ketchup drips on the box front, clear of the face.
	addBall(model, "Ketchup1", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(220, 40, 40), plastic, 0, P(ctx, 0.29, 0.60, -0.28), ctx.heading, 0, 0, 0)
	addBall(model, "Ketchup2", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(220, 40, 40), plastic, 0, P(ctx, 0.29, 0.58, 0.30), ctx.heading, 0, 0, 0)
	addFace(ctx, 0.275, 0.48, 0.85, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.29, 0.22)
end

local function foodNed(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Noodle bowl — the body. Front at fwd 0.475.
	addCyl(model, "Body", 0.55, 0.95, ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.30, 0), ctx.heading, "Y", 0)
	-- White rim + golden broth surface.
	addCyl(model, "BowlRim", 0.08, 0.98, Color3.fromRGB(245, 245, 240), fabric, 0, P(ctx, 0, 0.56, 0), ctx.heading, "Y", 0)
	addCyl(model, "Broth", 0.05, 0.82, Color3.fromRGB(240, 180, 80), plastic, 0, P(ctx, 0, 0.58, 0), ctx.heading, "Y", 0)
	-- Noodle swirls piled on the broth.
	addBall(model, "NoodleSwirl1", S(ctx, 0.38, 0.12, 0.38), Color3.fromRGB(250, 220, 150), fabric, 0, P(ctx, 0.12, 0.66, -0.15), ctx.heading, 0, 0, 0)
	addBall(model, "NoodleSwirl2", S(ctx, 0.38, 0.12, 0.38), Color3.fromRGB(235, 200, 120), fabric, 0, P(ctx, -0.10, 0.67, 0.15), ctx.heading, 0, 0, 0)
	addBall(model, "NoodleSwirl3", S(ctx, 0.34, 0.12, 0.34), Color3.fromRGB(250, 220, 150), fabric, 0, P(ctx, 0.05, 0.66, 0.28), ctx.heading, 0, 0, 0)
	-- Chopsticks crossed above the bowl.
	addCyl(model, "ChopstickL", 0.85, 0.04, Color3.fromRGB(170, 120, 70), fabric, 0, P(ctx, 0.05, 0.95, -0.05), ctx.heading, "X", 0.25)
	addCyl(model, "ChopstickR", 0.85, 0.04, Color3.fromRGB(170, 120, 70), fabric, 0, P(ctx, 0.05, 0.95, 0.05), ctx.heading, "X", -0.25)
	-- Steam wisps off the hot noodles.
	addBall(model, "Steam1", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.15, -0.08), ctx.heading, 0, 0, 0)
	addBall(model, "Steam2", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.30, 0.08), ctx.heading, 0, 0, 0)
	addFace(ctx, 0.475, 0.32, 0.80, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.49, 0.12)
end

local function foodDumpling(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	-- Crescent dumpling, wider than tall — the body, tilted a touch.
	addBall(model, "Body", S(ctx, 1.05, 0.55, 0.60), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.30, 0), ctx.heading, 0, 0, 0.06)
	-- Pleated ridge along the top edge.
	for i, x in ipairs({ -0.35, -0.175, 0, 0.175, 0.35 }) do
		addBall(model, "Pleat" .. tostring(i), S(ctx, 0.10, 0.09, 0.09), Color3.fromRGB(240, 220, 170), fabric, 0, P(ctx, 0.06, 0.54, x), ctx.heading, 0, 0, 0)
	end
	-- Two chive bits on the ridge for a colour pop.
	addBall(model, "Chive1", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(90, 170, 70), fabric, 0, P(ctx, 0.08, 0.56, -0.26), ctx.heading, 0, 0, 0)
	addBall(model, "Chive2", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(90, 170, 70), fabric, 0, P(ctx, 0.08, 0.56, 0.26), ctx.heading, 0, 0, 0)
	addFace(ctx, 0.28, 0.31, 0.85, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.22, 0.10)
end

local function foodTaco(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Hard taco shell, wide flat half-moon — the body. Front at fwd ~0.24.
	addBall(model, "Body", S(ctx, 1.08, 0.62, 0.48), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.35, 0), ctx.heading, 0, 0, 0)
	-- Filling mounded along the top edge, spilling over the front.
	for i, x in ipairs({ -0.30, 0, 0.30 }) do
		addBall(model, "Lettuce" .. tostring(i), S(ctx, 0.18, 0.11, 0.15), Color3.fromRGB(90, 180, 70), fabric, 0, P(ctx, 0.04, 0.64, x), ctx.heading, 0, 0, 0)
	end
	addBall(model, "Tomato1", S(ctx, 0.15, 0.15, 0.15), Color3.fromRGB(220, 60, 40), plastic, 0, P(ctx, 0.08, 0.62, -0.15), ctx.heading, 0, 0, 0)
	addBall(model, "Tomato2", S(ctx, 0.15, 0.15, 0.15), Color3.fromRGB(220, 60, 40), plastic, 0, P(ctx, 0.08, 0.62, 0.15), ctx.heading, 0, 0, 0)
	addBox(model, "CheeseShred1", S(ctx, 0.22, 0.04, 0.06), Color3.fromRGB(250, 200, 60), plastic, 0, P(ctx, 0.06, 0.66, -0.22), ctx.heading, 0, 0, 0.3)
	addBox(model, "CheeseShred2", S(ctx, 0.22, 0.04, 0.06), Color3.fromRGB(250, 200, 60), plastic, 0, P(ctx, 0.06, 0.66, 0.22), ctx.heading, 0, 0, -0.3)
	-- Filling peeking over the front upper edge.
	addBall(model, "LettuceFront1", S(ctx, 0.12, 0.08, 0.10), Color3.fromRGB(90, 180, 70), fabric, 0, P(ctx, 0.18, 0.58, -0.28), ctx.heading, 0, 0, 0)
	addBall(model, "LettuceFront2", S(ctx, 0.12, 0.08, 0.10), Color3.fromRGB(90, 180, 70), fabric, 0, P(ctx, 0.18, 0.58, 0.28), ctx.heading, 0, 0, 0)
	-- Hot-sauce drip on the shell front, clear of the face.
	addBall(model, "SauceDrip", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(200, 40, 25), plastic, 0, P(ctx, 0.16, 0.52, -0.32), ctx.heading, 0, 0, 0)
	addFace(ctx, 0.23, 0.36, 0.85, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.20, 0.13)
end

local function foodLasagna(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Stacked layers: pasta / sauce / pasta / cheese. Front plane fwd 0.30.
	addBox(model, "PastaLayer1", S(ctx, 0.90, 0.16, 0.60), Color3.fromRGB(235, 210, 150), fabric, 0, P(ctx, 0, 0.08, 0), ctx.heading, 0, 0, 0)
	addBox(model, "SauceLayer", S(ctx, 0.90, 0.16, 0.60), Color3.fromRGB(200, 60, 35), plastic, 0, P(ctx, 0, 0.24, 0), ctx.heading, 0, 0, 0)
	addBox(model, "PastaLayer2", S(ctx, 0.90, 0.16, 0.60), Color3.fromRGB(235, 210, 150), fabric, 0, P(ctx, 0, 0.40, 0), ctx.heading, 0, 0, 0)
	-- Cheese top — the main mass ("Body"), slightly wider than the stack.
	addBox(model, "Body", S(ctx, 0.95, 0.16, 0.65), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.56, 0), ctx.heading, 0, 0, 0)
	-- Cheese drips down the front, clear of the face.
	addBall(model, "CheeseDrip1", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(245, 200, 70), plastic, 0, P(ctx, 0.31, 0.50, -0.32), ctx.heading, 0, 0, 0)
	addBall(model, "CheeseDrip2", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(245, 200, 70), plastic, 0, P(ctx, 0.31, 0.20, 0.32), ctx.heading, 0, 0, 0)
	-- One black olive + a basil leaf on top.
	addBall(model, "Olive", S(ctx, 0.08, 0.08, 0.08), Color3.fromRGB(40, 40, 45), plastic, 0, P(ctx, 0, 0.68, -0.25), ctx.heading, 0, 0, 0)
	addBall(model, "Basil", S(ctx, 0.10, 0.06, 0.10), Color3.fromRGB(70, 150, 70), fabric, 0, P(ctx, 0.05, 0.67, 0.22), ctx.heading, 0, 0, 0)
	-- Face sits on the pasta layer at its height: skin is pasta, not cheese.
	local pasta = Color3.fromRGB(235, 210, 150)
	addFace(ctx, 0.30, 0.40, 0.90, pasta, shade(pasta, -0.30))
	addGem(ctx, 0.31, 0.10)
end

local function foodQueso(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local metal = mat("Metal")
	local plastic = mat("SmoothPlastic")
	-- YELLOW cheese wedge — the body. Front at fwd 0.30.
	addBox(model, "Body", S(ctx, 0.80, 0.60, 0.60), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.32, 0), ctx.heading, 0, 0, 0)
	-- Sloped top: high at the back, low at the front — the wedge cut.
	addBox(model, "WedgeTop", S(ctx, 0.80, 0.16, 0.60), ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, -0.05, 0.66, 0), ctx.heading, -0.30, 0, 0)
	-- Cheese holes: darker orange, on the front corners (clear of the
	-- face) and one on the side.
	local holeColor = Color3.fromRGB(230, 150, 0)
	addBall(model, "CheeseHole1", S(ctx, 0.10, 0.08, 0.04), holeColor, plastic, 0, P(ctx, 0.31, 0.10, -0.30), ctx.heading, 0, 0, 0)
	addBall(model, "CheeseHole2", S(ctx, 0.10, 0.08, 0.04), holeColor, plastic, 0, P(ctx, 0.31, 0.58, 0.30), ctx.heading, 0, 0, 0)
	addBall(model, "CheeseHole3", S(ctx, 0.10, 0.08, 0.04), holeColor, plastic, 0, P(ctx, 0.31, 0.08, 0.30), ctx.heading, 0, 0, 0)
	addBall(model, "CheeseHole4", S(ctx, 0.10, 0.08, 0.04), holeColor, plastic, 0, P(ctx, 0.31, 0.60, -0.30), ctx.heading, 0, 0, 0)
	addBall(model, "CheeseHoleSide", S(ctx, 0.04, 0.10, 0.10), holeColor, plastic, 0, P(ctx, 0, 0.35, 0.41), ctx.heading, 0, 0, 0)
	-- Small gold crown on top (the queen), kept small so the cheese read wins.
	addCyl(model, "CrownBand", 0.08, 0.50, Color3.fromRGB(230, 190, 80), metal, 0, P(ctx, -0.05, 0.78, 0), ctx.heading, "Y", 0)
	for i, x in ipairs({ -0.15, 0, 0.15 }) do
		addBall(model, "CrownSpike" .. tostring(i), S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(230, 190, 80), metal, 0, P(ctx, -0.05, 0.86, x), ctx.heading, 0, 0, 0)
	end
	addFace(ctx, 0.30, 0.34, 0.90, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.31, 0.10)
end

local function foodKebab(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	local metal = mat("Metal")
	-- Metal skewer through the whole stack.
	addCyl(model, "Skewer", 1.45, 0.06, Color3.fromRGB(180, 180, 180), metal, 0, P(ctx, 0, 0.725, 0), ctx.heading, "Y", 0)
	addBall(model, "SkewerTip", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(180, 180, 180), metal, 0, P(ctx, 0, 1.48, 0), ctx.heading, 0, 0, 0)
	-- Chunks on the skewer: meat / tomato / BIG MEAT / onion.
	addBox(model, "MeatChunk1", S(ctx, 0.58, 0.30, 0.58), Color3.fromRGB(150, 80, 50), fabric, 0, P(ctx, 0, 0.15, 0), ctx.heading, 0, 0, 0)
	addBox(model, "TomatoChunk", S(ctx, 0.58, 0.30, 0.58), Color3.fromRGB(220, 60, 40), plastic, 0, P(ctx, 0, 0.47, 0), ctx.heading, 0, 0, 0)
	-- Biggest meat chunk — the main mass ("Body"). Face sits on its front.
	addBox(model, "Body", S(ctx, 0.62, 0.40, 0.62), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.79, 0), ctx.heading, 0, 0, 0)
	addBox(model, "OnionChunk", S(ctx, 0.58, 0.30, 0.58), Color3.fromRGB(240, 240, 235), fabric, 0, P(ctx, 0, 1.15, 0), ctx.heading, 0, 0, 0)
	-- Grill marks on the side of the big chunk + a pepper slice on top.
	addBox(model, "GrillMark1", S(ctx, 0.03, 0.18, 0.04), Color3.fromRGB(90, 50, 30), fabric, 0, P(ctx, 0, 0.79, 0.32), ctx.heading, 0, 0, 0.2)
	addBox(model, "GrillMark2", S(ctx, 0.03, 0.18, 0.04), Color3.fromRGB(90, 50, 30), fabric, 0, P(ctx, 0, 0.79, -0.32), ctx.heading, 0, 0, -0.2)
	addBall(model, "PepperSlice", S(ctx, 0.12, 0.12, 0.12), Color3.fromRGB(90, 170, 70), plastic, 0, P(ctx, 0, 1.38, 0.15), ctx.heading, 0, 0, 0)
	addFace(ctx, 0.31, 0.79, 0.85, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.32, 0.62)
end

local function foodBurger(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- The stack, bottom to top: bun / patty / cheese / lettuce / tomato /
	-- TOP BUN (the main mass, "Body"). Face sits on the top bun's front.
	addCyl(model, "BottomBun", 0.16, 0.95, Color3.fromRGB(205, 140, 70), fabric, 0, P(ctx, 0, 0.10, 0), ctx.heading, "Y", 0)
	addCyl(model, "Patty", 0.18, 1.00, Color3.fromRGB(120, 70, 40), fabric, 0, P(ctx, 0, 0.27, 0), ctx.heading, "Y", 0)
	addBox(model, "CheeseSlice", S(ctx, 1.05, 0.08, 1.05), Color3.fromRGB(250, 200, 50), plastic, 0, P(ctx, 0, 0.40, 0), ctx.heading, 0, 0.785, 0)
	addBall(model, "Lettuce", S(ctx, 1.00, 0.10, 1.00), Color3.fromRGB(90, 180, 70), fabric, 0, P(ctx, 0, 0.48, 0), ctx.heading, 0, 0, 0)
	addCyl(model, "TomatoSlice", 0.10, 0.90, Color3.fromRGB(220, 60, 40), plastic, 0, P(ctx, 0, 0.56, 0), ctx.heading, "Y", 0)
	addBall(model, "Body", S(ctx, 0.95, 0.45, 0.95), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.80, 0), ctx.heading, 0, 0, 0)
	-- Sesame seeds on the dome.
	addBall(model, "Sesame1", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(240, 235, 200), plastic, 0, P(ctx, 0.10, 1.00, -0.20), ctx.heading, 0, 0, 0)
	addBall(model, "Sesame2", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(240, 235, 200), plastic, 0, P(ctx, -0.05, 1.02, 0.05), ctx.heading, 0, 0, 0)
	addBall(model, "Sesame3", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(240, 235, 200), plastic, 0, P(ctx, 0.15, 0.98, 0.22), ctx.heading, 0, 0, 0)
	addBall(model, "Sesame4", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(240, 235, 200), plastic, 0, P(ctx, -0.15, 0.99, -0.05), ctx.heading, 0, 0, 0)
	addFace(ctx, 0.46, 0.80, 0.80, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.47, 0.60)
end

local function foodRamen(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Ramen bowl — the body. Front at fwd 0.525.
	addCyl(model, "Body", 0.60, 1.05, ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.32, 0), ctx.heading, "Y", 0)
	-- Gold rim + golden broth surface.
	addCyl(model, "BowlRim", 0.08, 1.08, Color3.fromRGB(230, 190, 80), mat("Metal"), 0, P(ctx, 0, 0.60, 0), ctx.heading, "Y", 0)
	addCyl(model, "Broth", 0.05, 0.90, Color3.fromRGB(240, 180, 80), plastic, 0, P(ctx, 0, 0.62, 0), ctx.heading, "Y", 0)
	-- Noodle swirls on the broth.
	addBall(model, "NoodleSwirl1", S(ctx, 0.38, 0.12, 0.38), Color3.fromRGB(250, 220, 150), fabric, 0, P(ctx, 0.12, 0.70, -0.15), ctx.heading, 0, 0, 0)
	addBall(model, "NoodleSwirl2", S(ctx, 0.38, 0.12, 0.38), Color3.fromRGB(235, 200, 120), fabric, 0, P(ctx, -0.12, 0.70, 0.15), ctx.heading, 0, 0, 0)
	addBall(model, "NoodleSwirl3", S(ctx, 0.34, 0.12, 0.34), Color3.fromRGB(250, 220, 150), fabric, 0, P(ctx, 0.05, 0.70, 0.30), ctx.heading, 0, 0, 0)
	-- Soft egg (white + yolk) and narutomaki (white + pink swirl).
	addBall(model, "Egg", S(ctx, 0.24, 0.18, 0.24), Color3.fromRGB(245, 245, 240), plastic, 0, P(ctx, -0.05, 0.72, 0.28), ctx.heading, 0, 0, 0)
	addBall(model, "EggYolk", S(ctx, 0.11, 0.11, 0.11), Color3.fromRGB(250, 180, 40), plastic, 0, P(ctx, 0.06, 0.76, 0.28), ctx.heading, 0, 0, 0)
	addCyl(model, "Narutomaki", 0.06, 0.20, Color3.fromRGB(245, 245, 240), plastic, 0, P(ctx, 0.10, 0.70, -0.30), ctx.heading, "Y", 0)
	addBall(model, "NarutoSwirl", S(ctx, 0.07, 0.07, 0.07), Color3.fromRGB(250, 150, 180), plastic, 0, P(ctx, 0.10, 0.74, -0.30), ctx.heading, 0, 0, 0)
	-- Nori sheet at the back + chopsticks crossed above.
	addBox(model, "Nori", S(ctx, 0.25, 0.32, 0.03), Color3.fromRGB(30, 60, 35), fabric, 0, P(ctx, -0.28, 0.80, 0.05), ctx.heading, 0, 0, 0.1)
	addCyl(model, "ChopstickL", 0.90, 0.04, Color3.fromRGB(170, 120, 70), fabric, 0, P(ctx, 0.05, 1.05, -0.05), ctx.heading, "X", 0.25)
	addCyl(model, "ChopstickR", 0.90, 0.04, Color3.fromRGB(170, 120, 70), fabric, 0, P(ctx, 0.05, 1.05, 0.05), ctx.heading, "X", -0.25)
	-- Steam wisps off the hot broth.
	addBall(model, "Steam1", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.25, -0.08), ctx.heading, 0, 0, 0)
	addBall(model, "Steam2", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.40, 0.08), ctx.heading, 0, 0, 0)
	addFace(ctx, 0.525, 0.34, 0.85, ctx.body, ctx.bodyLo)
	addGem(ctx, 0.54, 0.12)
end

local FOOD: { [string]: (Ctx) -> () } = {
	soggy_fry = foodFry,
	noodle_ned = foodNed,
	dancing_dumpling = foodDumpling,
	turbo_taco = foodTaco,
	lord_lasagna = foodLasagna,
	queen_queso = foodQueso,
	king_kebab = foodKebab,
	baron_burger = foodBurger,
	eternal_ramen = foodRamen,
}

-- ------------------------------------------------------------------ public API
function CharacterFactory.buildSnack(
	def: SnackDef,
	variantName: string,
	groundPos: Vector3,
	headingRad: number,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = def.displayName .. "_" .. variantName

	-- Root: invisible anchor plate; bottom sits exactly on the ground,
	-- centre at the ground point (the model's PrimaryPart).
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.5, 0.05, 0.5)
	root.Color = Color3.fromRGB(0, 0, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Material = Enum.Material.SmoothPlastic
	root.Position = groundPos + Vector3.new(0, 0.025, 0)
	root.CFrame = CFrame.new(groundPos) * CFrame.Angles(0, headingRad, 0)
	root.Parent = model
	model.PrimaryPart = root

	local ctx = makeCtx(model, def, variantName, groundPos, headingRad)
	local build = FOOD[def.key]
	assert(build ~= nil, "CharacterFactory.buildSnack: no food builder for " .. def.key)
	build(ctx)

	-- Rarity disc under the feet (Neon, 0.35 transparency).
	local disc = Instance.new("Part")
	disc.Name = "Disc"
	disc.Size = Vector3.new(def.size * 1.25, 0.12, def.size * 1.25)
	disc.Color = ctx.rarity
	disc.Transparency = 0.35
	disc.Anchored = true
	disc.CanCollide = false
	disc.Material = Enum.Material.Neon
	disc.Position = groundPos + Vector3.new(0, 0.07, 0)
	disc.Parent = model

	-- Floating label above the snack.
	local body = model:FindFirstChild("Body")
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Caption"
	billboard.Adornee = body
	billboard.Size = UDim2.new(0, 150, 0, 56)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, def.size * 0.9, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLine"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = def.displayName
	nameLabel.Parent = billboard

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLine"
	infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	infoLabel.TextStrokeTransparency = 0.2
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.Text = "$" .. tostring(def.price) .. "  •  $" .. tostring(def.rate) .. "/s"
	infoLabel.Parent = billboard

	-- Tags other systems read back (no extra parts needed).
	model:SetAttribute("SnackKey", def.key)
	model:SetAttribute("Variant", variantName)
	model:SetAttribute("Rarity", def.rarity)

	model.Parent = parent
	return model
end

function CharacterFactory.attachClick(model: Model, reach: number, handler: (Player) -> ()): ClickDetector
	local root = model.PrimaryPart
	assert(root ~= nil, "CharacterFactory.attachClick: model has no PrimaryPart")
	-- Parent the detector to the visible food body ("Body", the food's main
	-- mass), NOT to the invisible Root plate: a ClickDetector only fires
	-- when its own parent part is clicked, and the Root is a tiny invisible
	-- 0.5x0.05x0.5 plate at the ground — so clicking the snack itself did
	-- nothing and buying felt broken.
	local target = model:FindFirstChild("Body")
	if not target or not target:IsA("BasePart") then
		target = root
	end
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = reach
	detector.Parent = target
	detector.MouseClick:Connect(function(player: Player)
		handler(player)
	end)
	return detector
end

function CharacterFactory.setCaption(model: Model, line1: string, line2: string): ()
	local board = model:FindFirstChild("Caption")
	if board and board:IsA("BillboardGui") then
		local nameLine = board:FindFirstChild("NameLine")
		local infoLine = board:FindFirstChild("InfoLine")
		if nameLine and nameLine:IsA("TextLabel") then
			nameLine.Text = line1
		end
		if infoLine and infoLine:IsA("TextLabel") then
			infoLine.Text = line2
		end
	end
end

function CharacterFactory.countParts(model: Model): number
	local count = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return CharacterFactory
