--!strict
-- Steal a Snack v2 — Weather: rotating sky conditions.
-- Five weathers rotate on a 150-180s cycle with a 4s fade. `settingsFor`
-- is pure data (headless-testable); `applyTo` pushes one weather onto a
-- Lighting instance; `begin` runs the rotation loop on the server.
--
-- PUBLIC API:
--   settingsFor(name) -> WeatherSettings  (pure table, no instances)
--   applyTo(lighting, name) -> ()         (sets Lighting + Atmosphere)
--   current() -> string                   (name of the active weather)
--   begin(lighting, onChange, minStretch?, maxStretch?, fadeSeconds?) -> ()
--       starts the rotation loop; onChange(name) fires per change.
--       Stretch/fade default to 150s / 180s / 4s; init passes Config values.

local Weather = {}

local WEATHER_NAMES = { "Sunny", "Rain", "Storm", "Fog", "Snow" } :: { string }

export type WeatherSettings = {
	brightness: number,
	clockTime: number,
	ambient: { number },
	outdoorAmbient: { number },
	fogEnd: number,
	atmosphereDensity: number,
	atmosphereOffset: number,
}

Weather.SETTINGS = {
	Sunny = {
		brightness = 2.6,
		clockTime = 13.5,
		ambient = { 150, 140, 128 },
		outdoorAmbient = { 158, 173, 199 },
		fogEnd = 1200,
		atmosphereDensity = 0.28,
		atmosphereOffset = 0.25,
	},
	Rain = {
		brightness = 1.6,
		clockTime = 12.5,
		ambient = { 100, 105, 115 },
		outdoorAmbient = { 115, 122, 138 },
		fogEnd = 500,
		atmosphereDensity = 0.4,
		atmosphereOffset = 0.2,
	},
	Storm = {
		brightness = 1.1,
		clockTime = 17.5,
		ambient = { 70, 72, 88 },
		outdoorAmbient = { 82, 84, 104 },
		fogEnd = 260,
		atmosphereDensity = 0.55,
		atmosphereOffset = 0.1,
	},
	Fog = {
		brightness = 1.35,
		clockTime = 10.5,
		ambient = { 135, 134, 138 },
		outdoorAmbient = { 146, 146, 150 },
		fogEnd = 160,
		atmosphereDensity = 0.65,
		atmosphereOffset = 0.4,
	},
	Snow = {
		brightness = 2.0,
		clockTime = 12,
		ambient = { 155, 160, 175 },
		outdoorAmbient = { 175, 180, 195 },
		fogEnd = 450,
		atmosphereDensity = 0.35,
		atmosphereOffset = 0.3,
	},
} :: { [string]: WeatherSettings }

local currentName = "Sunny"
local currentIndex = 1

function Weather.settingsFor(name: string): WeatherSettings
	local found = Weather.SETTINGS[name]
	if found then
		return found
	end
	return Weather.SETTINGS.Sunny
end

function Weather.applyTo(lighting: Lighting, name: string): ()
	local s = Weather.settingsFor(name)
	lighting.Brightness = s.brightness
	lighting.ClockTime = s.clockTime
	lighting.Ambient = Color3.fromRGB(s.ambient[1], s.ambient[2], s.ambient[3])
	lighting.OutdoorAmbient = Color3.fromRGB(s.outdoorAmbient[1], s.outdoorAmbient[2], s.outdoorAmbient[3])
	lighting.FogEnd = s.fogEnd
	local atmosphere = lighting:FindFirstChild("Atmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		atmosphere.Density = s.atmosphereDensity
		atmosphere.Offset = s.atmosphereOffset
	end
	currentName = name
end

function Weather.current(): string
	return currentName
end

function Weather.begin(
	lighting: Lighting,
	onChange: (string) -> (),
	minStretch: number?,
	maxStretch: number?,
	fadeSeconds: number?
): ()
	local minS = minStretch or 150
	local maxS = maxStretch or 180
	local fadeS = fadeSeconds or 4
	Weather.applyTo(lighting, "Sunny")
	task.spawn(function()
		while true do
			local stretch = minS + math.random() * (maxS - minS)
			task.wait(stretch)
			currentIndex = currentIndex % #WEATHER_NAMES + 1
			local nextName = WEATHER_NAMES[currentIndex]
			-- Fade: step the lighting in small increments.
			local from = Weather.settingsFor(currentName)
			local to = Weather.settingsFor(nextName)
			local steps = 20
			for step = 1, steps do
				local t = step / steps
				lighting.Brightness = from.brightness + (to.brightness - from.brightness) * t
				lighting.FogEnd = from.fogEnd + (to.fogEnd - from.fogEnd) * t
				task.wait(fadeS / steps)
			end
			Weather.applyTo(lighting, nextName)
			onChange(nextName)
		end
	end)
end

return Weather
