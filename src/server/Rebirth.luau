--!strict
-- Steal a Snack v2 — Rebirth: reset for a permanent income multiplier.
-- Cost grows per rebirth (Config.rebirthPrice). On success the player's
-- cash resets to START_CASH, their base is emptied, and rebirths +1.
--
-- PUBLIC API:
--   attempt(player) -> (boolean, string)

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent:WaitForChild("State"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local Economy = require(script.Parent:WaitForChild("Economy"))

local Rebirth = {}

function Rebirth.attempt(player: Player): (boolean, string)
	local session = State.fetch(player)
	if not session then
		return false, "Player not ready yet."
	end
	local cost = Config.rebirthPrice(session.rebirths)
	if not Economy.canAfford(session, cost) then
		return false, "Rebirth costs $" .. tostring(cost) .. " — you have $" .. tostring(math.floor(session.cash)) .. "."
	end
	Economy.charge(session, cost)
	local baseIndex = Bases.indexOf(player)
	if baseIndex ~= 0 then
		Bases.clearAll(baseIndex)
	end
	session.cash = Config.START_CASH
	session.rebirths += 1
	return true, "Rebirth #" .. tostring(session.rebirths) .. "! Income is now x" .. tostring(Config.incomeBoost(session.rebirths)) .. "."
end

return Rebirth
