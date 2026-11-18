--!strict
-- Steal a Snack v2 — RateLimit: tiny per-key call budget.
-- Usage: local limiter = RateLimit.new(5, 1)  -- 5 calls per 1 second
--        if not limiter:allow(tostring(player.UserId)) then return end

local RateLimit = {}
RateLimit.__index = RateLimit

export type Limiter = {
	maxCalls: number,
	windowSeconds: number,
	history: { [string]: { number } },
	allow: (self: Limiter, key: string) -> boolean,
}

function RateLimit.new(maxCalls: number, windowSeconds: number): Limiter
	local self = setmetatable({}, RateLimit) :: Limiter
	self.maxCalls = maxCalls
	self.windowSeconds = windowSeconds
	self.history = {}
	return self
end

function RateLimit.allow(self: Limiter, key: string): boolean
	local now = os.clock()
	local stamps = self.history[key]
	if not stamps then
		stamps = {}
		self.history[key] = stamps
	end
	-- Drop stamps outside the window.
	local kept = {}
	for _, t in ipairs(stamps) do
		if now - t < self.windowSeconds then
			table.insert(kept, t)
		end
	end
	self.history[key] = kept
	if #kept >= self.maxCalls then
		return false
	end
	table.insert(kept, now)
	return true
end

return RateLimit
