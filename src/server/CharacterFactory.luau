--!strict
-- Steal a Snack v2 — CharacterFactory (REALISTIC builder, v2-chars pass).
-- Written fresh for the v2 project. Every snack is a small chibi figure:
-- an oval sculpted head (never a box) sitting on an oval food body, with
-- stepped face relief (brow, modelled nose bridge + tip, cheek/blush),
-- properly proportioned eyes (white + dark outline + tall-oval iris +
-- pupil + highlight, upper lid covering the iris top), tapered brows,
-- a thin smile / smirk / open mouth, tapered bent limbs, and hands with
-- a palm, three fingers and a thumb. One signature sculpted prop set per
-- snack keeps each food's identity; the rarity colour lives ONLY on the
-- ground disc, the chest gem and small trim, never on the body.
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
-- InfoLine; attributes SnackKey / Variant / Rarity; <= 60 parts/snack.
--
-- Geometry note: all offsets are in units of `u = def.size` (the body
-- diameter), so every snack scales cleanly from 3.3 (Fry) to 6.0 (Ramen).
-- Heading: forward = (sin h, 0, cos h), right = (cos h, 0, -sin h);
-- the face sits on the +forward side. Head centre is the eye line
-- (half the head height); eyes are ~0.25 of the face width with one
-- eye width between them.

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
-- Metal for crowns / gold, SmoothPlastic only for glossy food,
-- Leather for shoes, Neon only for emitters (disc + gem).
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
	body: Color3, -- variant-tinted body colour
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
	local bodyColor: Color3 = rgb(def.color)
	local bodyTransparency = 0
	if variantName == "Golden" then
		bodyColor = lighten(def.color, 0.45)
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
-- Eye line sits at the head centre (half the head height). Each eye is
-- ~0.25 of the face width, one eye width apart. Per eye, front to back:
-- highlight, pupil, tall-oval iris, dark outline ring, white — with the
-- upper lid (head colour) overlapping the iris top.
local EYE_Y = 1.00 -- head centre height, in u
local EYE_W = 0.20 -- eye width, in u (0.25 of the 0.80u face width)
local EYE_X = 0.20 -- eye centre offset from the midline, in u

local function addEye(ctx: Ctx, side: number)
	local model = ctx.model
	local name = if side < 0 then "EyeL" else "EyeR"
	local x = side * EYE_X
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- White: tall, almost straight-sided oval. Carries the bare "EyeL" /
	-- "EyeR" name the harness looks up; the rest of the eye is layered
	-- in front of it under the same prefix.
	addBall(model, name, S(ctx, EYE_W, 0.27, 0.09), Color3.fromRGB(235, 235, 230), plastic, 0, P(ctx, 0.27, EYE_Y, x), ctx.heading, 0, 0, 0)
	-- Dark outline ring, slightly larger than the iris, behind it.
	addBall(model, name .. "Outline", S(ctx, 0.15, 0.21, 0.04), Color3.fromRGB(25, 25, 30), plastic, 0, P(ctx, 0.295, EYE_Y - 0.01, x), ctx.heading, 0, 0, 0)
	-- Iris: tall oval with the food's own accent colour.
	addBall(model, name .. "Iris", S(ctx, 0.13, 0.19, 0.05), ctx.iris, plastic, 0, P(ctx, 0.305, EYE_Y - 0.01, x), ctx.heading, 0, 0, 0)
	-- Pupil.
	addBall(model, name .. "Pupil", S(ctx, 0.065, 0.09, 0.04), Color3.fromRGB(20, 20, 25), plastic, 0, P(ctx, 0.325, EYE_Y - 0.01, x), ctx.heading, 0, 0, 0)
	-- One highlight, upper-outer corner of the iris.
	addBall(model, name .. "Glint", S(ctx, 0.04, 0.05, 0.03), Color3.fromRGB(235, 235, 235), plastic, 0, P(ctx, 0.34, EYE_Y + 0.05, x + side * 0.035), ctx.heading, 0, 0, 0)
	-- Upper lid: head colour, covering the top of the iris.
	addBall(model, name .. "Lid", S(ctx, 0.22, 0.09, 0.05), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0.30, EYE_Y + 0.10, x), ctx.heading, 0, 0, 0)
end

local function addFace(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Tapered brows, thicker at the inner end (flattened balls, tilted);
	-- the left brow sits a touch higher than the right — asymmetry = life.
	addBall(model, "BrowL", S(ctx, 0.17, 0.04, 0.05), Color3.fromRGB(60, 35, 20), fabric, 0, P(ctx, 0.29, 1.16, -0.20), ctx.heading, 0, 0, 0.16)
	addBall(model, "BrowR", S(ctx, 0.17, 0.04, 0.05), Color3.fromRGB(60, 35, 20), fabric, 0, P(ctx, 0.29, 1.14, 0.20), ctx.heading, 0, 0, -0.08)
	for _, side in ipairs({ -1, 1 }) do
		addEye(ctx, side)
	end
	-- Modelled nose: a short bridge stepping out of the face, then a
	-- rounded tip — the side view gets real relief, no flat plate.
	addBox(model, "NoseBridge", S(ctx, 0.05, 0.12, 0.05), ctx.bodyLo, fabric, ctx.bodyTransp, P(ctx, 0.315, 0.93, 0), ctx.heading, 0, 0, 0)
	addBall(model, "NoseTip", S(ctx, 0.09, 0.07, 0.08), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0.335, 0.87, 0), ctx.heading, 0, 0, 0)
	-- Blush: two soft rose cheek steps under the outer eye corners.
	for _, side in ipairs({ -1, 1 }) do
		addBall(
			model,
			if side < 0 then "BlushL" else "BlushR",
			S(ctx, 0.10, 0.07, 0.04),
			Color3.fromRGB(235, 120, 130),
			plastic,
			0,
			P(ctx, 0.29, 0.86, side * 0.27),
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
		addBall(model, "Mouth", S(ctx, 0.16, 0.12, 0.05), Color3.fromRGB(70, 20, 25), plastic, 0, P(ctx, 0.31, 0.75, 0), ctx.heading, 0, 0, 0)
		addBall(model, "Tongue", S(ctx, 0.09, 0.06, 0.04), Color3.fromRGB(235, 120, 140), plastic, 0, P(ctx, 0.325, 0.71, 0), ctx.heading, 0, 0, 0)
	elseif style == "smirk" then
		-- Smirk: thin bar tilted up on one side, corners uneven.
		addBall(model, "Mouth", S(ctx, 0.15, 0.035, 0.04), mouthColor, plastic, 0, P(ctx, 0.315, 0.76, 0), ctx.heading, 0, 0, 0.18)
		addBall(model, "MouthCornerL", S(ctx, 0.04, 0.04, 0.04), mouthColor, plastic, 0, P(ctx, 0.31, 0.79, -0.085), ctx.heading, 0, 0, 0)
		addBall(model, "MouthCornerR", S(ctx, 0.04, 0.04, 0.04), mouthColor, plastic, 0, P(ctx, 0.31, 0.74, 0.085), ctx.heading, 0, 0, 0)
	else
		-- Thin smile: centre bar + two corners lifted a touch.
		addBall(model, "Mouth", S(ctx, 0.15, 0.035, 0.04), mouthColor, plastic, 0, P(ctx, 0.315, 0.76, 0), ctx.heading, 0, 0, 0)
		addBall(model, "MouthCornerL", S(ctx, 0.04, 0.04, 0.04), mouthColor, plastic, 0, P(ctx, 0.31, 0.775, -0.085), ctx.heading, 0, 0, 0)
		addBall(model, "MouthCornerR", S(ctx, 0.04, 0.04, 0.04), mouthColor, plastic, 0, P(ctx, 0.31, 0.775, 0.085), ctx.heading, 0, 0, 0)
	end
end

-- ------------------------------------------------------------------ core body
-- Oval head + oval body + jaw step, tapered bent arms, hands with palm +
-- 3 fingers + thumb, legs + shoes. `armsUp` raises both arms (Dumpling's
-- dance pose); otherwise the arms hang with a slight bend and the left
-- shoulder drops a touch lower than the right.
local function addCore(ctx: Ctx, armsUp: boolean)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	local leather = mat("Leather")
	-- Body: wide oval ball, warm mid tone; the food's own colour.
	addBall(model, "Body", S(ctx, 0.98, 0.66, 0.76), ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.56, 0), ctx.heading, 0, 0, 0)
	-- Head: oval ball, slightly tilted for life, overlapping the body so
	-- the jaw reads as a step in the side view.
	addBall(model, "Head", S(ctx, 0.80, 0.64, 0.64), ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, 0.02, 1.00, 0), ctx.heading, -0.02, 0, 0.05)
	-- Jaw / chin step under the head.
	addBall(model, "Jaw", S(ctx, 0.50, 0.22, 0.50), ctx.bodyLo, fabric, ctx.bodyTransp, P(ctx, 0.05, 0.72, 0), ctx.heading, 0, 0, 0)
	-- Rarity gem on the chest: the only rarity-coloured body detail.
	addBall(model, "Gem", S(ctx, 0.10, 0.10, 0.06), ctx.rarity, mat("Neon"), 0, P(ctx, 0.33, 0.52, 0), ctx.heading, 0, 0, 0)

	addFace(ctx)

	-- Legs: tapered look via a slimmer shin + wider shoe; shoes are
	-- flattened dark balls, bottoms exactly on the ground.
	for _, side in ipairs({ -1, 1 }) do
		local legName = if side < 0 then "LegL" else "LegR"
		local shoeName = if side < 0 then "ShoeL" else "ShoeR"
		addCyl(model, legName, 0.24, 0.17, ctx.bodyLo, fabric, ctx.bodyTransp, P(ctx, 0, 0.20, side * 0.20), ctx.heading, "Y", 0)
		addBall(model, shoeName, S(ctx, 0.20, 0.14, 0.30), Color3.fromRGB(40, 35, 30), leather, 0, P(ctx, 0.03, 0.07, side * 0.20), ctx.heading, 0, 0, 0)
	end

	-- Arms + hands.
	for _, side in ipairs({ -1, 1 }) do
		local armName = if side < 0 then "ArmL" else "ArmR"
		local foreName = if side < 0 then "ForeL" else "ForeR"
		local handName = if side < 0 then "HandL" else "HandR"
		local handX = side * 0.70
		local handY: number
		local handFwd: number
		if armsUp then
			-- Raised: upper arm up-and-out, forearm up, hand overhead.
			addCyl(model, armName, 0.30, 0.15, ctx.body, fabric, ctx.bodyTransp, P(ctx, 0, 0.90, side * 0.60), ctx.heading, "X", side * 1.0)
			addPart(model, foreName, Enum.PartType.Cylinder, S(ctx, 0.28, 0.12, 0.12), ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, 0.06, 1.10, side * 0.70), ctx.heading, 0, -0.3, side * 0.6)
			handY = 1.24
			handFwd = 0.10
		else
			-- Hanging, bent at the elbow toward the front; the left arm
			-- drops a touch lower than the right (shoulder drop).
			local drop = if side < 0 then 0.02 else 0
			addCyl(model, armName, 0.30, 0.15, ctx.body, fabric, ctx.bodyTransp, P(ctx, 0.02, 0.625 - drop, side * 0.585), ctx.heading, "X", -side * 0.35)
			addPart(model, foreName, Enum.PartType.Cylinder, S(ctx, 0.28, 0.12, 0.12), ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, 0.13, 0.42 - drop, side * 0.685), ctx.heading, 0, -0.45, -side * 0.15)
			handY = 0.33 - drop
			handFwd = 0.24
		end
		-- Palm.
		addBall(model, handName, S(ctx, 0.13, 0.13, 0.10), ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, handFwd, handY, handX), ctx.heading, 0, 0, 0)
		-- Three fingers + a thumb — no mitten blobs.
		for i = -1, 1 do
			local fingerName = handName .. "Finger" .. tostring(i + 2)
			if armsUp then
				addCyl(model, fingerName, 0.10, 0.045, ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, handFwd, handY + 0.10, handX + i * 0.045), ctx.heading, "Y", 0)
			else
				addCyl(model, fingerName, 0.10, 0.045, ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, handFwd + 0.06, handY - 0.02, handX + i * 0.045), ctx.heading, "Z", 0)
			end
		end
		local thumbName = handName .. "Thumb"
		if armsUp then
			addCyl(model, thumbName, 0.09, 0.05, ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, handFwd, handY + 0.02, handX - side * 0.08), ctx.heading, "Y", side * 0.5)
		else
			addCyl(model, thumbName, 0.09, 0.05, ctx.bodyHi, fabric, ctx.bodyTransp, P(ctx, handFwd + 0.02, handY + 0.02, handX - side * 0.075), ctx.heading, "Z", side * 0.6)
		end
	end
end

-- ------------------------------------------------------------------ signature props
-- One sculpted set per snack. Colours come from the food itself; the
-- rarity colour is never used here (disc + gem only).

local function decorFry(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Three fry sticks fanning out of the head, each tilted differently.
	for i, x in ipairs({ -0.18, 0, 0.18 }) do
		local tilt = (i - 2) * 0.18
		addBox(model, "FryStick" .. tostring(i), S(ctx, 0.09, 0.55, 0.05), Color3.fromRGB(235, 210, 90), fabric, 0, P(ctx, -0.05, 1.45, x), ctx.heading, 0, 0, tilt)
	end
	-- Ketchup drips: one on the head, one running down the body.
	addBall(model, "KetchupHead", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(220, 40, 40), plastic, 0, P(ctx, 0.28, 1.28, 0.12), ctx.heading, 0, 0, 0)
	addBall(model, "KetchupBody", S(ctx, 0.07, 0.07, 0.07), Color3.fromRGB(220, 40, 40), plastic, 0, P(ctx, 0.36, 0.80, -0.15), ctx.heading, 0, 0, 0)
	-- Cardboard box hugging the lower body, red with a white front panel.
	addBox(model, "FryBox", S(ctx, 0.85, 0.35, 0.65), Color3.fromRGB(205, 150, 100), fabric, 0, P(ctx, 0, 0.30, 0), ctx.heading, 0, 0, 0)
	addBox(model, "FryBoxFront", S(ctx, 0.50, 0.20, 0.03), Color3.fromRGB(235, 235, 230), fabric, 0, P(ctx, 0.34, 0.32, 0), ctx.heading, 0, 0, 0)
end

local function decorNed(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Noodle nest cap: two flattened swirls crowning the head.
	addBall(model, "NoodleSwirlL", S(ctx, 0.45, 0.12, 0.45), Color3.fromRGB(235, 200, 120), fabric, 0, P(ctx, 0, 1.32, -0.12), ctx.heading, 0, 0, 0)
	addBall(model, "NoodleSwirlR", S(ctx, 0.45, 0.12, 0.45), Color3.fromRGB(255, 220, 150), fabric, 0, P(ctx, 0.02, 1.34, 0.14), ctx.heading, 0, 0, 0)
	-- Chilli flakes scattered on the nest.
	addBall(model, "Chilli1", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(200, 30, 30), plastic, 0, P(ctx, 0.15, 1.36, -0.20), ctx.heading, 0, 0, 0)
	addBall(model, "Chilli2", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(200, 30, 30), plastic, 0, P(ctx, 0.15, 1.37, 0.20), ctx.heading, 0, 0, 0)
	-- Steam wisps rising off the hot noodles.
	addBall(model, "Steam1", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.55, -0.08), ctx.heading, 0, 0, 0)
	addBall(model, "Steam2", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.70, 0.08), ctx.heading, 0, 0, 0)
end

local function decorDumpling(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local metal = mat("Metal")
	-- Pleated ridge along the top of the head, three folds.
	for i, x in ipairs({ -0.20, 0, 0.20 }) do
		addBall(model, "Pleat" .. tostring(i), S(ctx, 0.10, 0.08, 0.08), Color3.fromRGB(235, 245, 220), fabric, 0, P(ctx, 0.05, 1.33, x), ctx.heading, 0, 0, 0)
	end
	-- Gold earrings, one per side.
	for _, side in ipairs({ -1, 1 }) do
		addBall(model, if side < 0 then "EarringL" else "EarringR", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(230, 190, 80), metal, 0, P(ctx, 0.10, 0.95, side * 0.42), ctx.heading, 0, 0, 0)
	end
	-- Tutu: wide ruffled skirt + a front ruffle fold at the waist.
	addBall(model, "Tutu", S(ctx, 1.05, 0.12, 0.85), Color3.fromRGB(235, 220, 230), fabric, 0, P(ctx, 0, 0.34, 0), ctx.heading, 0, 0, 0)
	addBall(model, "TutuRuffle", S(ctx, 0.50, 0.08, 0.40), Color3.fromRGB(255, 235, 240), fabric, 0, P(ctx, 0.15, 0.30, 0), ctx.heading, 0, 0, 0)
end

local function decorTaco(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Crunchy shell dome cradling the head from behind.
	addBall(model, "ShellDome", S(ctx, 0.85, 0.70, 0.55), Color3.fromRGB(230, 140, 30), fabric, 0, P(ctx, -0.12, 1.05, 0), ctx.heading, 0, 0, 0)
	-- Hot-sauce drips on the shell edge and the body.
	addBall(model, "SauceDrip1", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(200, 40, 25), plastic, 0, P(ctx, 0.30, 1.30, -0.20), ctx.heading, 0, 0, 0)
	addBall(model, "SauceDrip2", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(200, 40, 25), plastic, 0, P(ctx, 0.37, 0.78, 0.18), ctx.heading, 0, 0, 0)
	-- Lime wedge tucked by the shell, sour-cream dollop on the other side.
	addBall(model, "Lime", S(ctx, 0.16, 0.10, 0.06), Color3.fromRGB(140, 200, 60), plastic, 0, P(ctx, 0.20, 1.30, 0.25), ctx.heading, 0, 0, 0.4)
	addBall(model, "SourCream", S(ctx, 0.14, 0.08, 0.10), Color3.fromRGB(235, 235, 230), plastic, 0, P(ctx, 0.10, 1.28, -0.22), ctx.heading, 0, 0, 0)
end

local function decorLasagna(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Pleated chef hat: brim ring + two pleat folds + tall dome.
	addCyl(model, "HatBrim", 0.12, 0.62, Color3.fromRGB(235, 235, 230), fabric, 0, P(ctx, 0, 1.34, 0), ctx.heading, "Y", 0)
	addBall(model, "HatPleatL", S(ctx, 0.16, 0.16, 0.16), Color3.fromRGB(235, 235, 230), fabric, 0, P(ctx, 0, 1.44, -0.15), ctx.heading, 0, 0, 0)
	addBall(model, "HatPleatR", S(ctx, 0.16, 0.16, 0.16), Color3.fromRGB(235, 235, 230), fabric, 0, P(ctx, 0, 1.44, 0.15), ctx.heading, 0, 0, 0)
	addBall(model, "HatDome", S(ctx, 0.55, 0.35, 0.55), Color3.fromRGB(235, 235, 230), fabric, 0, P(ctx, 0, 1.52, 0), ctx.heading, 0, 0, 0)
	-- One black olive on the chest, two cheese drips running down it.
	addBall(model, "Olive", S(ctx, 0.07, 0.07, 0.07), Color3.fromRGB(40, 40, 45), plastic, 0, P(ctx, 0.37, 0.85, 0.18), ctx.heading, 0, 0, 0)
	addBall(model, "CheeseDrip1", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(235, 200, 60), plastic, 0, P(ctx, 0.36, 0.95, -0.20), ctx.heading, 0, 0, 0)
	addBall(model, "CheeseDrip2", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(235, 200, 60), plastic, 0, P(ctx, 0.37, 0.70, 0.10), ctx.heading, 0, 0, 0)
end

local function decorQueso(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local metal = mat("Metal")
	local plastic = mat("SmoothPlastic")
	-- Gold crown: band ring + three spikes.
	addCyl(model, "CrownBand", 0.10, 0.55, Color3.fromRGB(230, 190, 80), metal, 0, P(ctx, 0, 1.36, 0), ctx.heading, "Y", 0)
	for i, x in ipairs({ -0.18, 0, 0.18 }) do
		addBall(model, "CrownSpike" .. tostring(i), S(ctx, 0.07, 0.07, 0.07), Color3.fromRGB(230, 190, 80), metal, 0, P(ctx, 0, 1.46, x), ctx.heading, 0, 0, 0)
	end
	-- Red cape draped behind the body.
	addBox(model, "Cape", S(ctx, 0.85, 0.75, 0.06), Color3.fromRGB(180, 30, 40), fabric, 0, P(ctx, -0.38, 0.75, 0), ctx.heading, 0, 0, 0)
	-- Gold necklace ring around the neck.
	addCyl(model, "Necklace", 0.05, 0.50, Color3.fromRGB(230, 190, 80), metal, 0, P(ctx, 0, 0.88, 0), ctx.heading, "Y", 0)
	-- Ruby earrings.
	for _, side in ipairs({ -1, 1 }) do
		addBall(model, if side < 0 then "EarringL" else "EarringR", S(ctx, 0.05, 0.05, 0.05), Color3.fromRGB(200, 30, 50), plastic, 0, P(ctx, 0.10, 0.95, side * 0.42), ctx.heading, 0, 0, 0)
	end
end

local function decorKebab(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	local metal = mat("Metal")
	-- Flatbread wrap: a wide band ringing the body.
	addCyl(model, "Wrap", 0.10, 1.00, Color3.fromRGB(220, 180, 120), fabric, 0, P(ctx, 0, 0.56, 0), ctx.heading, "Y", 0)
	-- Grill marks seared across the wrap front.
	addBox(model, "GrillMarkL", S(ctx, 0.04, 0.20, 0.03), Color3.fromRGB(90, 50, 30), fabric, 0, P(ctx, 0.38, 0.60, -0.12), ctx.heading, 0, 0, 0.15)
	addBox(model, "GrillMarkR", S(ctx, 0.04, 0.20, 0.03), Color3.fromRGB(90, 50, 30), fabric, 0, P(ctx, 0.38, 0.60, 0.12), ctx.heading, 0, 0, -0.15)
	-- Smoke wisps curling off the grill.
	addBall(model, "Smoke1", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(200, 200, 200), plastic, 0.5, P(ctx, 0, 1.55, -0.06), ctx.heading, 0, 0, 0)
	addBall(model, "Smoke2", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(200, 200, 200), plastic, 0.5, P(ctx, 0, 1.68, 0.06), ctx.heading, 0, 0, 0)
	-- Skewer pin through the top of the head.
	addCyl(model, "Skewer", 0.70, 0.04, Color3.fromRGB(180, 180, 180), metal, 0, P(ctx, 0, 1.50, 0), ctx.heading, "Y", 0)
end

local function decorBurger(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Bun dome crowning the head.
	addBall(model, "BunDome", S(ctx, 0.82, 0.35, 0.66), Color3.fromRGB(200, 130, 60), fabric, 0, P(ctx, 0.02, 1.30, 0), ctx.heading, 0, 0, 0)
	-- Sesame seeds on the dome.
	for i, x in ipairs({ -0.15, 0, 0.15 }) do
		addBall(model, "Sesame" .. tostring(i), S(ctx, 0.04, 0.04, 0.04), Color3.fromRGB(235, 230, 190), plastic, 0, P(ctx, 0.15, 1.45, x), ctx.heading, 0, 0, 0)
	end
	-- Pickle slice on one side of the dome, onion slice on the other.
	addCyl(model, "Pickle", 0.04, 0.18, Color3.fromRGB(90, 160, 60), plastic, 0, P(ctx, 0.28, 1.38, 0.28), ctx.heading, "Y", 0.4)
	addBall(model, "Onion", S(ctx, 0.12, 0.04, 0.12), Color3.fromRGB(235, 235, 230), plastic, 0, P(ctx, 0.25, 1.36, -0.28), ctx.heading, 0, 0, 0)
	-- Mustard drip on the body.
	addBall(model, "MustardDrip", S(ctx, 0.06, 0.06, 0.06), Color3.fromRGB(235, 210, 40), plastic, 0, P(ctx, 0.37, 0.88, 0.15), ctx.heading, 0, 0, 0)
end

local function decorRamen(ctx: Ctx)
	local model = ctx.model
	local fabric = mat("Fabric")
	local plastic = mat("SmoothPlastic")
	-- Nori sheet pinned to the side of the head.
	addBox(model, "Nori", S(ctx, 0.25, 0.30, 0.03), Color3.fromRGB(30, 60, 35), fabric, 0, P(ctx, 0.30, 1.05, -0.30), ctx.heading, 0, 0.4, 0)
	-- Chashu pork slice on the chest.
	addCyl(model, "Chashu", 0.05, 0.28, Color3.fromRGB(235, 190, 180), plastic, 0, P(ctx, 0.37, 0.55, 0), ctx.heading, "Z", 0)
	-- Chopsticks crossed above the head.
	addCyl(model, "ChopstickL", 0.80, 0.035, Color3.fromRGB(170, 120, 70), fabric, 0, P(ctx, 0.05, 1.55, -0.05), ctx.heading, "X", 0.25)
	addCyl(model, "ChopstickR", 0.80, 0.035, Color3.fromRGB(170, 120, 70), fabric, 0, P(ctx, 0.05, 1.55, 0.05), ctx.heading, "X", -0.25)
	-- Steam wisps off the hot broth.
	addBall(model, "Steam1", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.60, -0.08), ctx.heading, 0, 0, 0)
	addBall(model, "Steam2", S(ctx, 0.09, 0.09, 0.09), Color3.fromRGB(235, 235, 235), plastic, 0.5, P(ctx, 0.05, 1.75, 0.08), ctx.heading, 0, 0, 0)
	-- Chilli-oil swirl on the body.
	addBall(model, "ChilliSwirl", S(ctx, 0.16, 0.05, 0.16), Color3.fromRGB(220, 60, 20), plastic, 0, P(ctx, 0.36, 0.86, -0.18), ctx.heading, 0, 0, 0)
end

local DECOR: { [string]: (Ctx) -> () } = {
	soggy_fry = decorFry,
	noodle_ned = decorNed,
	dancing_dumpling = decorDumpling,
	turbo_taco = decorTaco,
	lord_lasagna = decorLasagna,
	queen_queso = decorQueso,
	king_kebab = decorKebab,
	baron_burger = decorBurger,
	eternal_ramen = decorRamen,
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
	addCore(ctx, def.key == "dancing_dumpling")
	local decor = DECOR[def.key]
	if decor then
		decor(ctx)
	end

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
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = reach
	detector.Parent = root
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
