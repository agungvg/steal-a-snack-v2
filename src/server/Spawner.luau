--!strict
-- Steal a Snack v2 — Spawner: walkers on the conveyor belt.
-- Walkers spawn at BELT_MIN_X, walk +X at CONVEYOR_SPEED and despawn past
-- BELT_MAX_X. Each walker is a CharacterFactory snack with a click wired to
-- the buy callback supplied by init. During a wave, spawns run twice as fast.
--
-- PUBLIC API:
--   begin(walkersParent, onBuy) -> ()
--       onBuy(player, walker) runs when a player clicks a walker.
--   setBoost(on: boolean) -> ()     wave mode: halve the spawn interval
--   count() -> number
--   removeWalker(walker) -> ()      despawn one walker (after a buy)
--
-- Walker = { model: Model, snackKey: string, variant: string,
--            def: Config.SnackDef, mult: number, x: number }

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))

local Spawner = {}

export type Walker = {
	model: Model,
	snackKey: string,
	variant: string,
	def: Config.SnackDef,
	mult: number,
	x: number,
}

local walkers: { Walker } = {}
local boosted = false
local running = false
local spawnCounter = 0 -- rotates the caption label tier (0/1/2) so
-- adjacent walkers' name labels sit at different heights.

local function rollWalker(parent: Instance): Walker?
	if #walkers >= Config.MAX_WALKERS then
		return nil
	end
	local rarity = Config.pickRarity(math.random())
	local def = Config.pickSnackOfRarity(rarity, math.random())
	local variant = Config.pickVariant(math.random())
	local groundPos = Vector3.new(Config.BELT_MIN_X, Config.BELT_TOP_Y, Config.BELT_Z)
	local labelTier = spawnCounter % 3
	spawnCounter += 1
	local model = CharacterFactory.buildSnack(def, variant.name, groundPos, math.pi / 2, parent, labelTier)
	local walker: Walker = {
		model = model,
		snackKey = def.key,
		variant = variant.name,
		def = def,
		mult = variant.mult,
		x = Config.BELT_MIN_X,
	}
	table.insert(walkers, walker)
	return walker
end

function Spawner.setBoost(on: boolean): ()
	boosted = on
end

function Spawner.count(): number
	return #walkers
end

function Spawner.removeWalker(walker: Walker): ()
	for i, w in ipairs(walkers) do
		if w == walker then
			table.remove(walkers, i)
			break
		end
	end
	if walker.model then
		walker.model:Destroy()
	end
end

function Spawner.begin(walkersParent: Instance, onBuy: (Player, Walker) -> ()): ()
	if running then
		return
	end
	running = true
	-- Spawn loop.
	task.spawn(function()
		while true do
			local interval = Config.SPAWN_INTERVAL
			if boosted then
				interval /= 2
			end
			task.wait(interval)
			local walker = rollWalker(walkersParent)
			if walker then
				CharacterFactory.attachClick(walker.model, Config.ACTION_RANGE, function(player: Player)
					onBuy(player, walker)
				end)
			end
		end
	end)
	-- Movement loop: 10 steps per second, cheap and smooth enough.
	task.spawn(function()
		while true do
			task.wait(0.1)
			local dt = 0.1
			for i = #walkers, 1, -1 do
				local walker = walkers[i]
				walker.x += Config.CONVEYOR_SPEED * dt
				if walker.x > Config.BELT_MAX_X then
					Spawner.removeWalker(walker)
				elseif walker.model and walker.model.PrimaryPart then
					walker.model:PivotTo(
						CFrame.new(walker.x, Config.BELT_TOP_Y, Config.BELT_Z) * CFrame.Angles(0, math.pi / 2, 0)
					)
				end
			end
		end
	end)
end

return Spawner
