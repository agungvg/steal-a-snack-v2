--!strict
-- Steal a Snack v2 — Saves: versioned DataStore persistence.
-- Save on a timer + on leave + on shutdown (wired in init). Every DataStore
-- call is pcall-wrapped: a failed read keeps a fresh session instead of
-- wiping progress, and a failed write is reported, never retried blindly.
--
-- PUBLIC API:
--   pack(session, snackRows) -> table   session -> storable table (v1)
--   unpack(data) -> {cash, rebirths}?  nil when the data is unusable
--   load(player) -> table?             raw stored table, nil on failure
--   save(player, data) -> boolean      true when the write succeeded

local DataStoreService = game:GetService("DataStoreService")

local Saves = {}
local store = DataStoreService:GetDataStore("StealASnackV2")

export type SnackRow = {
	snackKey: string,
	variant: string,
	slot: number,
}

function Saves.pack(cash: number, rebirths: number, snackRows: { SnackRow }): { [string]: any }
	return {
		version = 1,
		cash = cash,
		rebirths = rebirths,
		snacks = snackRows,
		savedAt = os.time(),
	}
end

function Saves.unpack(data: { [string]: any }): { cash: number, rebirths: number }?
	if typeof(data) ~= "table" then
		return nil
	end
	if data.version ~= 1 then
		return nil
	end
	if typeof(data.cash) ~= "number" or typeof(data.rebirths) ~= "number" then
		return nil
	end
	return { cash = data.cash, rebirths = data.rebirths }
end

function Saves.load(player: Player): { [string]: any }?
	local ok, result = pcall(function()
		return store:GetAsync("player_" .. tostring(player.UserId))
	end)
	if not ok then
		warn("[Saves] load failed for " .. player.Name .. ": " .. tostring(result))
		return nil
	end
	if typeof(result) ~= "table" then
		return nil
	end
	return result
end

function Saves.save(player: Player, data: { [string]: any }): boolean
	local ok, err = pcall(function()
		store:SetAsync("player_" .. tostring(player.UserId), data)
	end)
	if not ok then
		warn("[Saves] save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

return Saves
