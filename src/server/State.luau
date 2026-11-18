--!strict
-- Steal a Snack v2 — State: per-player session data (server only).
-- One session per joined player: cash, rebirths, lock/steal timers, base.
-- Snacks themselves live in Bases (placement + models); this module owns
-- the numbers only.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local State = {}

export type Session = {
	cash: number,
	rebirths: number,
	lockUntil: number, -- os.time() until which the base is locked (0 = open)
	lockReadyAt: number, -- os.time() when the player may lock again
	lastStealAt: number, -- os.time() of the last steal attempt
	baseIndex: number, -- 0 = no base assigned yet
}

local sessions: { [Player]: Session } = {}

function State.open(player: Player): Session
	local session: Session = {
		cash = Config.START_CASH,
		rebirths = 0,
		lockUntil = 0,
		lockReadyAt = 0,
		lastStealAt = 0,
		baseIndex = 0,
	}
	sessions[player] = session
	return session
end

function State.fetch(player: Player): Session?
	return sessions[player]
end

function State.close(player: Player): ()
	sessions[player] = nil
end

function State.all(): { [Player]: Session }
	return sessions
end

function State.isLocked(session: Session): boolean
	return os.time() < session.lockUntil
end

function State.lockSecondsLeft(session: Session): number
	local left = session.lockUntil - os.time()
	if left < 0 then
		return 0
	end
	return left
end

return State
