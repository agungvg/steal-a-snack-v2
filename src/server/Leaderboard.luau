--!strict
-- Steal a Snack v2 — Leaderboard: richest players, sorted.
-- Pure sorting over plain rows; the server builds the rows from State and
-- sends them to clients inside the GameSync payload.
--
-- PUBLIC API:
--   ranked(rows) -> {Row}   rows sorted richest-first (input not mutated)
--   top(rows, n) -> {Row}   first n of the ranked list
--
-- Row = { name: string, cash: number, rebirths: number }

local Leaderboard = {}

export type Row = {
	name: string,
	cash: number,
	rebirths: number,
}

function Leaderboard.ranked(rows: { Row }): { Row }
	local sorted = table.clone(rows)
	table.sort(sorted, function(a: Row, b: Row): boolean
		return a.cash > b.cash
	end)
	return sorted
end

function Leaderboard.top(rows: { Row }, n: number): { Row }
	local sorted = Leaderboard.ranked(rows)
	local out = {}
	for i = 1, math.min(n, #sorted) do
		table.insert(out, sorted[i])
	end
	return out
end

return Leaderboard
