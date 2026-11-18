--!strict
-- Steal a Snack v2 — client HUD.
-- Builds the whole interface from code (no pre-made GUI objects) and renders
-- whatever the server sends on GameSync. The client never computes cash:
-- every number on screen comes from the server payload.
--
-- GameSync payload (table):
--   cash, owned, rate, rebirths, rebirthCost, weather (string),
--   waveActive (bool), waveIn (seconds), lockLeft (seconds),
--   top = {{name, cash}, ...} (richest first)
-- WaveAlert payload: {kind = "warn"|"start"|"end"|"note", seconds?, text?}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSync = ReplicatedStorage:WaitForChild("GameSync") :: RemoteEvent
local WaveAlert = ReplicatedStorage:WaitForChild("WaveAlert") :: RemoteEvent
local LockBase = ReplicatedStorage:WaitForChild("LockBase") :: RemoteEvent
local RequestRebirth = ReplicatedStorage:WaitForChild("RequestRebirth") :: RemoteEvent

local player = Players.LocalPlayer

local function money(n: number): string
	return "$" .. tostring(math.floor(n))
end

-- ------------------------------------------------------------------ build UI
local gui = Instance.new("ScreenGui")
gui.Name = "SnackHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	textSize: number,
	color: Color3,
	parent: Instance
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	l.BackgroundTransparency = 0.25
	l.BorderSizePixel = 0
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = false
	l.TextSize = textSize
	l.Font = Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = l
	return l
end

local function button(
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	parent: Instance,
	onTap: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextSize = 18
	b.Font = Enum.Font.GothamBold
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	b.MouseButton1Click:Connect(onTap)
	return b
end

-- Top bar: cash, income, owned snacks, rebirths.
local cashLabel = label("Cash", "Cash: $100", UDim2.new(0, 220, 0, 44), UDim2.new(0, 12, 0, 12), 22, Color3.fromRGB(255, 230, 120), gui)
local rateLabel = label("Rate", "+$0/s", UDim2.new(0, 160, 0, 44), UDim2.new(0, 240, 0, 12), 20, Color3.fromRGB(140, 255, 140), gui)
local ownedLabel = label("Owned", "Snacks: 0/6", UDim2.new(0, 160, 0, 44), UDim2.new(0, 408, 0, 12), 20, Color3.fromRGB(255, 255, 255), gui)
local weatherLabel = label("Weather", "Sunny", UDim2.new(0, 160, 0, 44), UDim2.new(0, 576, 0, 12), 20, Color3.fromRGB(160, 210, 255), gui)

-- Wave banner (centre top, hidden unless a wave is near/active).
local banner = label("WaveBanner", "", UDim2.new(0, 420, 0, 40), UDim2.new(0.5, -210, 0, 64), 20, Color3.fromRGB(255, 170, 60), gui)
banner.TextXAlignment = Enum.TextXAlignment.Center
banner.Visible = false

-- Note line under the banner for one-off messages (steals, locks, errors).
local noteLabel = label("Note", "", UDim2.new(0, 420, 0, 32), UDim2.new(0.5, -210, 0, 110), 16, Color3.fromRGB(255, 255, 255), gui)
noteLabel.TextXAlignment = Enum.TextXAlignment.Center
noteLabel.Visible = false

-- Leaderboard (top right).
local board = Instance.new("Frame")
board.Name = "Leaderboard"
board.Size = UDim2.new(0, 220, 0, 190)
board.Position = UDim2.new(1, -232, 0, 12)
board.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
board.BackgroundTransparency = 0.25
board.BorderSizePixel = 0
board.Parent = gui
local boardCorner = Instance.new("UICorner")
boardCorner.CornerRadius = UDim.new(0, 10)
boardCorner.Parent = board

local boardTitle = Instance.new("TextLabel")
boardTitle.Name = "Title"
boardTitle.Size = UDim2.new(1, 0, 0, 30)
boardTitle.BackgroundTransparency = 1
boardTitle.Text = "🏆 Richest Players"
boardTitle.TextColor3 = Color3.fromRGB(255, 210, 80)
boardTitle.TextSize = 18
boardTitle.Font = Enum.Font.GothamBold
boardTitle.Parent = board

local boardRows: { TextLabel } = {}
for i = 1, 5 do
	local row = Instance.new("TextLabel")
	row.Name = "Row" .. tostring(i)
	row.Size = UDim2.new(1, -16, 0, 28)
	row.Position = UDim2.new(0, 8, 0, 28 + (i - 1) * 30)
	row.BackgroundTransparency = 1
	row.Text = ""
	row.TextColor3 = Color3.fromRGB(255, 255, 255)
	row.TextSize = 16
	row.Font = Enum.Font.Gotham
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Parent = board
	table.insert(boardRows, row)
end

-- Action buttons (bottom left).
local lockButton = button("LockBase", "🔒 Lock Base (20s)", UDim2.new(0, 220, 0, 48), UDim2.new(0, 12, 1, -116), Color3.fromRGB(70, 110, 220), gui, function()
	LockBase:FireServer()
end)
local rebirthButton = button("Rebirth", "✨ Rebirth", UDim2.new(0, 220, 0, 48), UDim2.new(0, 12, 1, -60), Color3.fromRGB(150, 70, 220), gui, function()
	RequestRebirth:FireServer()
end)

-- How-to line (bottom centre).
local helpLabel = label(
	"Help",
	"Click a walker on the belt to BUY it • Click a snack on your base to SELL it • Click a snack on another base to STEAL it",
	UDim2.new(0, 640, 0, 30),
	UDim2.new(0.5, -320, 1, -42),
	14,
	Color3.fromRGB(230, 230, 230),
	gui
)
helpLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ------------------------------------------------------------------ updates
local noteToken = 0
local function showNote(text: string, seconds: number): ()
	noteToken += 1
	local token = noteToken
	noteLabel.Text = text
	noteLabel.Visible = true
	task.delay(seconds, function()
		if token == noteToken then
			noteLabel.Visible = false
		end
	end)
end

GameSync.OnClientEvent:Connect(function(payload: { [string]: any })
	cashLabel.Text = "Cash: " .. money(payload.cash)
	rateLabel.Text = "+" .. money(payload.rate) .. "/s"
	ownedLabel.Text = "Snacks: " .. tostring(payload.owned) .. "/6"
	weatherLabel.Text = tostring(payload.weather)
	rebirthButton.Text = "✨ Rebirth ($" .. tostring(payload.rebirthCost) .. ") • x" .. tostring(payload.rebirths)
	if payload.lockLeft > 0 then
		lockButton.Text = "🔒 Locked (" .. tostring(payload.lockLeft) .. "s)"
	else
		lockButton.Text = "🔒 Lock Base (20s)"
	end
	if payload.waveActive then
		banner.Text = "🌊 SNACK WAVE — 2x income!"
		banner.Visible = true
	elseif payload.waveIn <= 10 then
		banner.Text = "🌊 Wave in " .. tostring(payload.waveIn) .. "s — get ready!"
		banner.Visible = true
	else
		banner.Visible = false
	end
	local top = payload.top
	if typeof(top) == "table" then
		for i, rowLabel in ipairs(boardRows) do
			local row = top[i]
			if row then
				rowLabel.Text = tostring(i) .. ". " .. tostring(row.name) .. " — " .. money(row.cash)
			else
				rowLabel.Text = ""
			end
		end
	end
end)

WaveAlert.OnClientEvent:Connect(function(payload: { [string]: any })
	local kind = payload.kind
	if kind == "warn" then
		banner.Text = "🌊 Wave in " .. tostring(payload.seconds or 10) .. "s — rare snacks incoming!"
		banner.Visible = true
	elseif kind == "start" then
		banner.Text = "🌊 SNACK WAVE — 2x income!"
		banner.Visible = true
	elseif kind == "end" then
		banner.Text = ""
		banner.Visible = false
	elseif kind == "note" then
		showNote(tostring(payload.text or ""), 4)
	end
end)
