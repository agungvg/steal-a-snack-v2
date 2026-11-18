--!strict
-- Steal a Snack v2 — Steal: moving a snack from one base to another.
-- Every check is server-side: different players, victim not locked, thief
-- off cooldown, thief within ACTION_RANGE of the victim's base, victim
-- actually has a snack in that slot, thief has a free slot.
--
-- PUBLIC API:
--   attempt(thief, victim, slot, thiefPos) -> (boolean, string)
--       On success the snack record + model move to the thief's base and
--       the thief's steal cooldown restarts. Returns ok + a human message.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent:WaitForChild("State"))
local Bases = require(script.Parent:WaitForChild("Bases"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))

local Steal = {}

function Steal.attempt(thief: Player, victim: Player, slot: number, thiefPos: Vector3): (boolean, string)
	if thief == victim then
		return false, "That's your own snack — click it to sell it instead."
	end
	local thiefSession = State.fetch(thief)
	local victimSession = State.fetch(victim)
	if not thiefSession or not victimSession then
		return false, "Player not ready yet."
	end
	if State.isLocked(victimSession) then
		return false, victim.DisplayName .. "'s base is locked!"
	end
	if os.time() - thiefSession.lastStealAt < Config.STEAL_COOLDOWN then
		return false, "Steal is on cooldown — wait a few seconds."
	end
	local victimBase = Bases.indexOf(victim)
	local thiefBase = Bases.indexOf(thief)
	if victimBase == 0 or thiefBase == 0 then
		return false, "No base to steal from."
	end
	local centre = Bases.platformCenter(victimBase)
	if (thiefPos - centre).Magnitude > Config.ACTION_RANGE then
		return false, "Too far from that base to steal."
	end
	local record = Bases.remove(victimBase, slot)
	if not record then
		return false, "Nothing in that slot."
	end
	local freeSlot = Bases.firstEmpty(thiefBase)
	if not freeSlot then
		-- Put it back: the steal did not happen.
		Bases.place(victimBase, slot, record)
		return false, "Your base is full — no room for a stolen snack."
	end
	thiefSession.lastStealAt = os.time()
	-- Move the model to the thief's slot and retag it so its click handler
	-- (which reads OwnerId/Slot attributes) follows the new owner.
	local groundPos = Bases.slotWorldPos(thiefBase, freeSlot)
	if record.model and record.model.PrimaryPart then
		record.model:PivotTo(CFrame.new(groundPos) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	end
	record.model:SetAttribute("OwnerId", thief.UserId)
	record.model:SetAttribute("Slot", freeSlot)
	Bases.place(thiefBase, freeSlot, record)
	CharacterFactory.setCaption(record.model, record.model.Name, "Stolen! $" .. tostring(record.rate) .. "/s")
	return true, "Stole a snack from " .. victim.DisplayName .. "!"
end

return Steal
