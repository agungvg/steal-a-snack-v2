--!strict
-- Steal a Snack v2 — Wave: periodic snack surge event.
-- Every WAVE_PERIOD seconds a wave is warned (WAVE_WARN ahead), then runs
-- for WAVE_DURATION seconds. While active, the Spawner spawns twice as fast
-- and income is doubled (see Economy.WAVE_INCOME_MULT).
--
-- PUBLIC API:
--   begin(onWarn, onStart, onEnd) -> ()  starts the loop; callbacks take no args
--   isActive() -> boolean
--   secondsToNext() -> number            (approx; 0 while a wave is active)

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Wave = {}

local active = false
local nextAt = os.clock() + Config.WAVE_PERIOD

function Wave.isActive(): boolean
	return active
end

function Wave.secondsToNext(): number
	if active then
		return 0
	end
	local left = nextAt - os.clock()
	if left < 0 then
		return 0
	end
	return left
end

function Wave.begin(onWarn: () -> (), onStart: () -> (), onEnd: () -> ()): ()
	task.spawn(function()
		while true do
			task.wait(math.max(0, nextAt - os.clock() - Config.WAVE_WARN))
			onWarn()
			task.wait(Config.WAVE_WARN)
			active = true
			onStart()
			task.wait(Config.WAVE_DURATION)
			active = false
			onEnd()
			nextAt = os.clock() + Config.WAVE_PERIOD
		end
	end)
end

return Wave
