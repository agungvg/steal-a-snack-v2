--!strict
-- Steal a Snack v2 — server entry point. Wires every system together:
-- joins/leaves + saves, income ticks, walker buying, owned-snack clicks
-- (sell your own, steal someone else's), base locking, rebirth, waves,
-- weather, leaderboard, and the GameSync broadcast the HUD renders.
--
-- Remotes (ReplicatedStorage, defined in default.project.json):
--   GameSync (server -> client): full HUD state, every CASH_TICK
--   WaveAlert (server -> client): {kind = "warn"|"start"|"end"}
--   LockBase (client -> server): no args, rate-limited
--   RequestRebirth (client -> server): no args, rate-limited

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent:WaitForChild("State"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local Spawner = require(script.Parent:WaitForChild("Spawner"))
local Steal = require(script.Parent:WaitForChild("Steal"))
local Rebirth = require(script.Parent:WaitForChild("Rebirth"))
local Wave = require(script.Parent:WaitForChild("Wave"))
local Weather = require(script.Parent:WaitForChild("Weather"))
local Leaderboard = require(script.Parent:WaitForChild("Leaderboard"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Saves = require(script.Parent:WaitForChild("Saves"))
local RateLimit = require(script.Parent:WaitForChild("RateLimit"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))

local GameSync = ReplicatedStorage:WaitForChild("GameSync") :: RemoteEvent
local WaveAlert = ReplicatedStorage:WaitForChild("WaveAlert") :: RemoteEvent
local LockBase = ReplicatedStorage:WaitForChild("LockBase") :: RemoteEvent
local RequestRebirth = ReplicatedStorage:WaitForChild("RequestRebirth") :: RemoteEvent

local walkersFolder = Workspace:WaitForChild("Walkers") :: Folder
local lockLimiter = RateLimit.new(2, 5) -- 2 lock presses per 5s per player
local rebirthLimiter = RateLimit.new(2, 5)

-- ------------------------------------------------------------------ helpers
local function ownedRates(player: Player): { Economy.OwnedSnack }
	local out = {}
	local baseIndex = Bases.indexOf(player)
	if baseIndex ~= 0 then
		for _, record in ipairs(Bases.list(baseIndex)) do
			table.insert(out, { rate = record.rate, mult = record.mult })
		end
	end
	return out
end

local function buildSyncPayload(player: Player): { [string]: any }
	local session = State.fetch(player)
	local rows = {}
	for otherPlayer, otherSession in pairs(State.all()) do
		table.insert(rows, {
			name = otherPlayer.DisplayName,
			cash = otherSession.cash,
			rebirths = otherSession.rebirths,
		})
	end
	local top = Leaderboard.top(rows, 5)
	local topRows = {}
	for _, row in ipairs(top) do
		table.insert(topRows, { name = row.name, cash = math.floor(row.cash) })
	end
	return {
		cash = if session then math.floor(session.cash) else 0,
		owned = Bases.count(Bases.indexOf(player)),
		rate = if session
			then math.floor(Economy.ratePerSecond(ownedRates(player), session.rebirths) * 100) / 100
			else 0,
		rebirths = if session then session.rebirths else 0,
		rebirthCost = if session then Config.rebirthPrice(session.rebirths) else Config.REBIRTH_BASE_COST,
		weather = Weather.current(),
		waveActive = Wave.isActive(),
		waveIn = math.floor(Wave.secondsToNext()),
		lockLeft = if session then State.lockSecondsLeft(session) else 0,
		top = topRows,
	}
end

local function syncPlayer(player: Player): ()
	GameSync:FireClient(player, buildSyncPayload(player))
end

-- Click handler for a snack standing on a base. Reads the model's OwnerId /
-- Slot attributes, so it keeps working after a steal moves the snack.
local function onOwnedSnackClicked(clicker: Player, model: Model): ()
	local ownerId = model:GetAttribute("OwnerId")
	local slot = model:GetAttribute("Slot")
	if typeof(ownerId) ~= "number" or typeof(slot) ~= "number" then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner then
		return
	end
	local ownerBase = Bases.indexOf(owner)
	if ownerBase == 0 then
		return
	end
	if clicker == owner then
		-- Sell your own snack for half its price.
		local record = Bases.remove(ownerBase, slot)
		if not record then
			return
		end
		local def = Config.lookupSnack(record.snackKey)
		local refund = if def then math.floor(def.price * Config.SELL_REFUND) else 0
		local session = State.fetch(clicker)
		if session then
			Economy.grant(session, refund)
		end
		model:Destroy()
		syncPlayer(clicker)
		return
	end
	-- Steal from someone else.
	local root = clicker.Character and clicker.Character:FindFirstChild("HumanoidRootPart")
	local thiefPos = if root and root:IsA("BasePart")
		then (root :: BasePart).Position
		else Bases.platformCenter(Bases.indexOf(clicker))
	local ok, message = Steal.attempt(clicker, owner, slot, thiefPos)
	if ok then
		Effects.pop(walkersFolder, model:GetPivot().Position, Config.rarityColor(model:GetAttribute("Rarity") :: string))
	end
	-- Surface the result through the next sync tick; the message itself is
	-- visible in the wave banner area via a one-off alert.
	if message ~= "" then
		WaveAlert:FireClient(clicker, { kind = "note", text = message })
	end
end

local function placeOwnedSnack(player: Player, snackKey: string, variant: string): boolean
	local def = Config.lookupSnack(snackKey)
	if not def then
		return false
	end
	local baseIndex = Bases.indexOf(player)
	if baseIndex == 0 then
		return false
	end
	local slot = Bases.firstEmpty(baseIndex)
	if not slot then
		return false
	end
	local variantDef = Config.variantFor(variant)
	local groundPos = Bases.slotWorldPos(baseIndex, slot)
	local model = CharacterFactory.buildSnack(def, variant, groundPos, math.random() * math.pi * 2, walkersFolder)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Slot", slot)
	CharacterFactory.attachClick(model, Config.ACTION_RANGE, function(clicker: Player)
		onOwnedSnackClicked(clicker, model)
	end)
	Bases.place(baseIndex, slot, {
		snackKey = snackKey,
		variant = variant,
		rate = def.rate,
		mult = variantDef.mult,
		model = model,
	})
	return true
end

local function buyWalker(player: Player, walker: Spawner.Walker): ()
	local session = State.fetch(player)
	if not session then
		return
	end
	local baseIndex = Bases.indexOf(player)
	if baseIndex == 0 then
		return
	end
	if Bases.firstEmpty(baseIndex) == nil then
		WaveAlert:FireClient(player, { kind = "note", text = "Your base is full!" })
		return
	end
	if not Economy.charge(session, walker.def.price) then
		WaveAlert:FireClient(player, { kind = "note", text = "Not enough cash for " .. walker.def.displayName .. "!" })
		return
	end
	Spawner.removeWalker(walker)
	if placeOwnedSnack(player, walker.snackKey, walker.variant) then
		Effects.pop(walkersFolder, Bases.platformCenter(baseIndex), Config.rarityColor(walker.def.rarity))
	end
	syncPlayer(player)
end

-- ------------------------------------------------------------------ saves
local function savePlayer(player: Player): ()
	local session = State.fetch(player)
	if not session then
		return
	end
	local rows = {}
	local baseIndex = Bases.indexOf(player)
	if baseIndex ~= 0 then
		for slot = 1, Config.MAX_SLOTS_PER_BASE do
			local record = Bases.peek(baseIndex, slot)
			if record then
				table.insert(rows, { snackKey = record.snackKey, variant = record.variant, slot = slot })
			end
		end
	end
	Saves.save(player, Saves.pack(session.cash, session.rebirths, rows))
end

local function restoreSnacks(player: Player, data: { [string]: any }): ()
	local savedSnacks = data.snacks
	if typeof(savedSnacks) ~= "table" then
		return
	end
	for _, row in ipairs(savedSnacks) do
		if typeof(row) == "table" and typeof(row.snackKey) == "string" and typeof(row.variant) == "string" then
			placeOwnedSnack(player, row.snackKey, row.variant)
		end
	end
end

-- ------------------------------------------------------------------ players
local function onPlayerAdded(player: Player): ()
	local session = State.open(player)
	local baseIndex = Bases.claim(player)
	if baseIndex == 0 then
		warn("[init] No free base for " .. player.Name)
	end
	local data = Saves.load(player)
	if data then
		local restored = Saves.unpack(data)
		if restored then
			session.cash = math.max(0, restored.cash)
			session.rebirths = math.max(0, restored.rebirths)
			restoreSnacks(player, data)
		end
	end
	syncPlayer(player)
end

local function onPlayerRemoving(player: Player): ()
	savePlayer(player)
	Bases.drop(player)
	State.close(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, _ in pairs(State.all()) do
		savePlayer(player)
	end
end)

-- ------------------------------------------------------------------ remotes
LockBase.OnServerEvent:Connect(function(player: Player)
	if not lockLimiter:allow(tostring(player.UserId)) then
		return
	end
	local session = State.fetch(player)
	if not session then
		return
	end
	local now = os.time()
	if now < session.lockReadyAt then
		WaveAlert:FireClient(player, {
			kind = "note",
			text = "Lock recharging — " .. tostring(session.lockReadyAt - now) .. "s left.",
		})
		return
	end
	session.lockUntil = now + Config.LOCK_DURATION
	session.lockReadyAt = now + Config.LOCK_COOLDOWN
	WaveAlert:FireClient(player, { kind = "note", text = "Base locked for " .. tostring(Config.LOCK_DURATION) .. "s!" })
	syncPlayer(player)
end)

RequestRebirth.OnServerEvent:Connect(function(player: Player)
	if not rebirthLimiter:allow(tostring(player.UserId)) then
		return
	end
	local ok, message = Rebirth.attempt(player)
	WaveAlert:FireClient(player, { kind = "note", text = message })
	if ok then
		syncPlayer(player)
	end
end)

-- ------------------------------------------------------------------ loops
-- Income + HUD sync, once per CASH_TICK.
task.spawn(function()
	while true do
		task.wait(Config.CASH_TICK)
		local waveActive = Wave.isActive()
		for player, session in pairs(State.all()) do
			Economy.tick(session, ownedRates(player), Config.CASH_TICK, waveActive)
			syncPlayer(player)
		end
	end
end)

-- Autosave every 60s.
task.spawn(function()
	while true do
		task.wait(60)
		for player, _ in pairs(State.all()) do
			savePlayer(player)
		end
	end
end)

-- World systems.
-- Build the realistic bases + plaza dressing once at boot (Bases.build
-- parents its folder to Workspace; the old Base1-8 slabs were removed
-- from default.project.json so there is no double geometry).
Bases.build()
Spawner.begin(walkersFolder, buyWalker)
Weather.begin(Lighting, function(_name: string) end, Config.WEATHER_MIN, Config.WEATHER_MAX, Config.WEATHER_FADE)
Wave.begin(
	function()
		WaveAlert:FireAllClients({ kind = "warn", seconds = Config.WAVE_WARN })
	end,
	function()
		Spawner.setBoost(true)
		WaveAlert:FireAllClients({ kind = "start" })
	end,
	function()
		Spawner.setBoost(false)
		WaveAlert:FireAllClients({ kind = "end" })
	end
)

print("[Steal a Snack v2] Server ready — belt, bases, spawner, weather, waves live.")
