--!strict
-- Steal a Snack v2 — Economy: pure cash math over a State session.
-- No Roblox services here; every function takes plain data so the rules
-- are easy to reason about and test by hand.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent:WaitForChild("State"))

local Economy = {}

export type OwnedSnack = {
	rate: number,
	mult: number,
}

-- Cash per second from a player's owned snacks, before the wave bonus.
-- `snacks` is a list of {rate, mult}; `rebirths` applies the permanent boost.
function Economy.ratePerSecond(snacks: { OwnedSnack }, rebirths: number): number
	local base = 0
	for _, snack in ipairs(snacks) do
		base += snack.rate * snack.mult
	end
	return base * Config.incomeBoost(rebirths)
end

-- One income tick: add rate * dt seconds of income to the session.
function Economy.tick(session: State.Session, snacks: { OwnedSnack }, dt: number, waveActive: boolean): number
	local earned = Economy.ratePerSecond(snacks, session.rebirths) * dt
	if waveActive then
		earned *= Config.WAVE_INCOME_MULT
	end
	session.cash += earned
	return earned
end

function Economy.canAfford(session: State.Session, price: number): boolean
	return session.cash >= price
end

-- Deducts when affordable; returns false and changes nothing otherwise.
function Economy.charge(session: State.Session, price: number): boolean
	if session.cash < price then
		return false
	end
	session.cash -= price
	return true
end

function Economy.grant(session: State.Session, amount: number): ()
	session.cash += amount
end

return Economy
